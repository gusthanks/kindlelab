#!/usr/bin/env python3
"""Look at the books newly added to a KindleLab Kindle and write a short report (read-only).

How it works
  * lists the Kindle's documents folder with KOReader's LuaJIT (scripts/kindle-inventory.lua, over SSH);
  * reads KOReader's cover-browser cache with sqlite3 in read-only mode (title, authors, cover, tags);
  * compares with the books seen last time (a small JSON state file on the PC);
  * for each NEW book: MOBI/AZW header and EPUB metadata/table of contents are read; PDFs are checked for a
    text layer (six sample pages, poppler's pdftotext). Store/DRM books are not opened at all.
Nothing is written to the Kindle. The report lists what is missing (title, author, cover, type tag, table
of contents) and hints (scanned PDF, maybe a comic); fixes are made later, only if the reader agrees.

Examples
  kindle-new-books.py --lang pt                      # check now, print a summary
  kindle-new-books.py --lang pt --notify --quiet     # for a timer: desktop notification, silent otherwise
  kindle-new-books.py --init                         # remember the current library without reporting it
"""

import argparse
import html
import json
import os
import pathlib
import posixpath
import re
import shlex
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.parse
import xml.etree.ElementTree as ET
import zipfile
from datetime import datetime

HERE = pathlib.Path(__file__).resolve().parent
INVENTORY_LUA = HERE / "kindle-inventory.lua"
CACHE_DB = "/mnt/us/koreader/settings/bookinfo_cache.sqlite3"
NATIVE_FORMATS = {"kfx", "azw1", "azw3", "azw4"}
MOBI_FORMATS = {"mobi", "azw", "prc"}
INFO_KEYS = {"native_reader", "scanned", "not_indexed"}  # information, not something to fix
CACHE_COLUMNS = ["path", "has_cover", "language", "pages", "unsupported", "title", "authors", "keywords"]
CACHE_SQL = """SELECT directory||filename, coalesce(has_cover,''), coalesce(language,''), coalesce(pages,''),
  coalesce(unsupported,''), replace(coalesce(title,''),char(10),char(30)),
  replace(coalesce(authors,''),char(10),char(30)), replace(coalesce(keywords,''),char(10),char(30))
FROM bookinfo WHERE directory LIKE '/mnt/us/documents/%';
"""

MESSAGES = {
    "pt": {
        "not_indexed": "o KOReader ainda não leu este livro (abra a Biblioteca uma vez)",
        "no_title": "sem título (aparece o nome do arquivo)",
        "no_author": "sem autor",
        "no_cover": "sem capa",
        "no_type_tag": "sem etiqueta “Tipo:” (o KOReader coloca sozinho quando a Biblioteca abrir)",
        "native_reader": "abre no leitor do Kindle (livro da Amazon)",
        "weak_toc": "sumário com {toc} item(ns) para {spine} partes do livro",
        "scanned": "PDF escaneado: na 1ª abertura, margens cortadas e mais contraste",
        "maybe_comic": "parece quadrinho: se for, no KOReader toque em Ferramentas → KindleLab → "
                       "Este livro é um quadrinho",
        "embedded": "no próprio arquivo: {what}",
        "title": "título “{v}”", "author": "autor “{v}”",
        "heading": "Livros novos no Kindle — {date}",
        "summary": "{n} livro(s) novo(s) · {m} precisa(m) de atenção",
        "all_good": "tudo certo",
        "none": "Nenhum livro novo no Kindle.",
        "unreachable": "Kindle fora de alcance (dormindo ou desconectado).",
        "baseline": "Biblioteca registrada: {n} livros. Só os próximos serão verificados.",
        "notify_title": "KindleLab: {n} livro(s) novo(s)",
        "report": "Relatório: {path}",
    },
    "en": {
        "not_indexed": "KOReader has not read this book yet (open the Library once)",
        "no_title": "no title (the file name is shown)",
        "no_author": "no author",
        "no_cover": "no cover",
        "no_type_tag": "no “Tipo:” tag yet (KOReader adds it when the Library opens)",
        "native_reader": "opens in the Kindle's own reader (store book)",
        "weak_toc": "table of contents with {toc} entry(ies) for {spine} parts",
        "scanned": "scanned PDF: margins cropped and more contrast on first opening",
        "maybe_comic": "looks like a comic: if so, in KOReader tap Tools → KindleLab → This book is a comic",
        "embedded": "inside the file: {what}",
        "title": "title “{v}”", "author": "author “{v}”",
        "heading": "New books on the Kindle — {date}",
        "summary": "{n} new book(s) · {m} need(s) attention",
        "all_good": "all good",
        "none": "No new books on the Kindle.",
        "unreachable": "Kindle not reachable (asleep or disconnected).",
        "baseline": "Library recorded: {n} books. Only books added from now on will be checked.",
        "notify_title": "KindleLab: {n} new book(s)",
        "report": "Report: {path}",
    },
}


# ---------------------------------------------------------------- library state

def new_or_changed(inventory, state):
    """Books whose path is unknown or whose size/modification time changed since the last check."""
    out = []
    for book in inventory:
        known = state.get(book["path"])
        if not known or known.get("bytes") != book["bytes"] or known.get("mtime") != book["mtime"]:
            out.append(book)
    return out


def parse_cache(text):
    """Rows of the cache query: unit separator (0x1f) between columns, 0x1e instead of newlines in text."""
    rows = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        fields = line.split("\x1f")
        fields += [""] * (len(CACHE_COLUMNS) - len(fields))
        row = {k: v.replace("\x1e", "\n") for k, v in zip(CACHE_COLUMNS, fields)}
        rows[row["path"]] = row
    return rows


# ---------------------------------------------------------------- file analysis

def mobi_info(data):
    """Metadata from the first bytes of a MOBI/AZW file (PalmDB + MOBI + EXTH headers), or None."""
    if len(data) < 86 or data[60:68] != b"BOOKMOBI":
        return None
    info: dict = {"title": None, "author": None, "language": None, "has_cover": False,
                  "encryption": None, "text_bytes": None, "image_records": None}
    records = struct.unpack_from(">H", data, 76)[0]
    r0 = struct.unpack_from(">I", data, 78)[0]
    if len(data) < r0 + 16 + 0x74:
        return info
    info["text_bytes"] = struct.unpack_from(">I", data, r0 + 4)[0]
    info["encryption"] = struct.unpack_from(">H", data, r0 + 12)[0]
    m = r0 + 16
    if data[m:m + 4] != b"MOBI":
        return info
    header_len = struct.unpack_from(">I", data, m + 4)[0]
    codec = "utf-8" if struct.unpack_from(">I", data, m + 0x0C)[0] == 65001 else "cp1252"
    name_off, name_len = struct.unpack_from(">II", data, m + 0x44)
    first_image = struct.unpack_from(">I", data, m + 0x5C)[0]
    if 0 < first_image < records:
        info["image_records"] = records - first_image
    titles, authors = [], []
    if struct.unpack_from(">I", data, m + 0x70)[0] & 0x40:
        e = m + header_len
        if data[e:e + 4] == b"EXTH" and len(data) >= e + 12:
            count = struct.unpack_from(">I", data, e + 8)[0]
            p = e + 12
            for _ in range(count):
                if p + 8 > len(data):
                    break
                rtype, rlen = struct.unpack_from(">II", data, p)
                if rlen < 8:
                    break
                value = data[p + 8:p + rlen]
                if rtype == 100:
                    authors.append(value.decode(codec, "replace").strip())
                elif rtype == 503:
                    titles.append(value.decode(codec, "replace").strip())
                elif rtype == 524:
                    info["language"] = value.decode(codec, "replace").strip() or None
                elif rtype == 201:
                    info["has_cover"] = True
                p += rlen
    name = data[r0 + name_off:r0 + name_off + name_len].decode(codec, "replace").strip()
    info["title"] = next((t for t in titles if t), None) or name or None
    info["author"] = "; ".join(a for a in authors if a) or None
    return info


def _local(tag):
    return tag.rsplit("}", 1)[-1]


def epub_info(path):
    """Title/author/language, table of contents size, spine size, images, cover and letters of an EPUB."""
    info: dict = {"title": None, "author": None, "language": None, "toc_entries": 0, "spine": 0,
                  "images": 0, "has_cover": False, "letters": 0}
    with zipfile.ZipFile(path) as z:
        names = set(z.namelist())
        container = ET.fromstring(z.read("META-INF/container.xml"))
        opf_path = next(e.attrib["full-path"] for e in container.iter() if _local(e.tag) == "rootfile")
        base = posixpath.dirname(opf_path)
        opf = ET.fromstring(z.read(opf_path))

        def first(tag):
            for e in opf.iter():
                text = (e.text or "").strip()
                if _local(e.tag) == tag and text:
                    return text
            return None

        def inside(href):
            return posixpath.normpath(posixpath.join(base, urllib.parse.unquote(href.split("#")[0])))

        info["title"], info["author"], info["language"] = first("title"), first("creator"), first("language")
        items = {e.attrib.get("id"): e.attrib for e in opf.iter() if _local(e.tag) == "item"}
        spine = [e.attrib.get("idref") for e in opf.iter() if _local(e.tag) == "itemref"]
        info["spine"] = len(spine)
        info["images"] = sum(1 for a in items.values() if a.get("media-type", "").startswith("image/"))
        info["has_cover"] = any("cover-image" in a.get("properties", "").split() for a in items.values()) or any(
            _local(e.tag) == "meta" and e.attrib.get("name") == "cover" for e in opf.iter())
        ncx_entries = nav_entries = 0
        for a in items.values():
            href = inside(a.get("href", ""))
            if href not in names:
                continue
            if a.get("media-type") == "application/x-dtbncx+xml":
                ncx = ET.fromstring(z.read(href))
                ncx_entries = sum(1 for e in ncx.iter() if _local(e.tag) == "navPoint")
            elif "nav" in a.get("properties", "").split():
                nav_doc = ET.fromstring(z.read(href))
                for nav in (e for e in nav_doc.iter() if _local(e.tag) == "nav"):
                    kind = next((v for k, v in nav.attrib.items() if k.endswith("type")), "toc")
                    if kind == "toc":
                        nav_entries = max(nav_entries, sum(1 for e in nav.iter() if _local(e.tag) == "a"))
        info["toc_entries"] = max(ncx_entries, nav_entries)
        for idref in spine:
            a = items.get(idref)
            href = a and inside(a.get("href", ""))
            if href in names:
                text = html.unescape(re.sub(r"<[^>]+>", " ", z.read(href).decode("utf-8", "replace")))
                info["letters"] += sum(ch.isalpha() for ch in text)
    return info


def sample_pages(n, maximum):
    """Same page sample as the Kindle plugin (kindlelab_types.samplePages)."""
    if not n or n < 1:
        return []
    if n <= maximum:
        return list(range(1, n + 1))
    pages = []
    for i in range(1, maximum + 1):
        p = int((i - 0.5) * n / maximum) + 1
        if not pages or pages[-1] != p:
            pages.append(p)
    return pages


def is_scanned(letter_counts):
    """Same rule as the Kindle plugin: fewer than 30 % of the sampled pages have 50+ letters."""
    if not letter_counts:
        return None
    with_text = sum(1 for c in letter_counts if c >= 50)
    return with_text * 10 < len(letter_counts) * 3


def pdf_info(path):
    """Pages, title/author and the scanned-or-not verdict of a PDF (needs poppler's pdfinfo/pdftotext)."""
    info: dict = {"pages": None, "title": None, "author": None, "scanned": None}
    if not (shutil.which("pdfinfo") and shutil.which("pdftotext")):
        return info
    out = subprocess.run(["pdfinfo", str(path)], capture_output=True, text=True, errors="replace").stdout
    fields = dict(line.split(":", 1) for line in out.splitlines() if ":" in line)
    info["pages"] = int(fields.get("Pages", "0").strip() or 0)
    info["title"] = fields.get("Title", "").strip() or None
    info["author"] = fields.get("Author", "").strip() or None
    counts = []
    for page in sample_pages(info["pages"], 6):
        text = subprocess.run(["pdftotext", "-f", str(page), "-l", str(page), str(path), "-"],
                              capture_output=True, text=True, errors="replace").stdout
        counts.append(sum(ch.isalpha() for ch in text))
    info["scanned"] = is_scanned(counts)
    return info


# ---------------------------------------------------------------- findings

def looks_like_file_name(title):
    """Titles such as "Livro-Manual-de-Campo_1", "book.pdf" or "x (z-lib.org)" are file names, not titles."""
    if " " not in title and ("-" in title or "_" in title):
        return True
    return bool(re.search(r"\.(pdf|epub|mobi|azw\d?)$|cdeKey|z-lib", title, re.IGNORECASE))


def picture_book(analysis):
    """Many images and little text: EPUB letters per image, or MOBI text bytes (markup included) per image."""
    if analysis.get("images"):
        return analysis["images"] >= 20 and (analysis.get("letters") or 0) < 100 * analysis["images"]
    images = analysis.get("image_records") or 0
    return images >= 20 and (analysis.get("text_bytes") or 0) < 1000 * images


def issue_keys(book, cache, analysis):
    """Findings for one book (keys of MESSAGES). cache: its cover-browser row or None."""
    keys = []
    custom = book.get("custom") or {}
    row = cache or {}
    if cache is None:
        keys.append("not_indexed")
    title = (custom.get("title") or row.get("title") or "").strip()
    authors = (custom.get("authors") or row.get("authors") or "").strip()
    keywords = custom.get("keywords") or row.get("keywords") or ""
    if cache is not None or custom:
        if not title or looks_like_file_name(title):
            keys.append("no_title")
        if not authors:
            keys.append("no_author")
        if not book.get("custom_cover") and row.get("has_cover") != "Y":
            keys.append("no_cover")
        if "Tipo:" not in keywords:
            keys.append("no_type_tag")
    a = analysis or {}
    if book["ext"] in NATIVE_FORMATS or (a.get("encryption") or 0) != 0:
        keys.append("native_reader")
        return keys
    comic = "Tipo: Quadrinho" in keywords
    if book["ext"] == "epub" and a.get("spine", 0) >= 4 and a.get("toc_entries", 0) <= 1:
        keys.append("weak_toc")
    if a.get("scanned") and not comic:
        keys.append("scanned")
    if not comic and (a.get("scanned") or picture_book(a)):
        keys.append("maybe_comic")
    return keys


def problem_count(keys):
    return sum(1 for k in keys if k not in INFO_KEYS)


# ---------------------------------------------------------------- Kindle access

def ssh(host, command, **kwargs):
    return subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", host, command], **kwargs)


def reachable(host):
    try:
        return ssh(host, "true", capture_output=True, timeout=20).returncode == 0
    except subprocess.TimeoutExpired:
        return False


def read_inventory(host):
    with open(INVENTORY_LUA, "rb") as script:
        out = ssh(host, "cd /mnt/us/koreader && ./luajit -", stdin=script, capture_output=True, check=True)
    return json.loads(out.stdout.decode("utf-8"))


def read_cache(host):
    command = "sqlite3 -separator \"$(printf '\\037')\" 'file:%s?mode=ro'" % CACHE_DB
    out = ssh(host, command, input=CACHE_SQL.encode(), capture_output=True, check=True)
    return parse_cache(out.stdout.decode("utf-8", "replace"))


def fetch(host, remote_path, local_path, head_bytes=None):
    quoted = shlex.quote(remote_path)
    command = f"dd if={quoted} bs={head_bytes} count=1 2>/dev/null" if head_bytes else f"cat {quoted}"
    with open(local_path, "wb") as out:
        ssh(host, command, stdout=out, check=True)
    return local_path


def analyze(host, book, tmp):
    ext = book["ext"]
    try:
        if ext in NATIVE_FORMATS:
            return None
        if ext in MOBI_FORMATS:
            head = fetch(host, book["path"], pathlib.Path(tmp) / "head.bin", head_bytes=262144)
            return mobi_info(head.read_bytes())
        if ext == "epub":
            return epub_info(fetch(host, book["path"], pathlib.Path(tmp) / "book.epub"))
        if ext == "pdf":
            return pdf_info(fetch(host, book["path"], pathlib.Path(tmp) / "book.pdf"))
    except (subprocess.CalledProcessError, zipfile.BadZipFile, ET.ParseError, KeyError, StopIteration,
            struct.error, OSError) as err:
        return {"error": str(err)}
    finally:
        for leftover in pathlib.Path(tmp).iterdir():
            leftover.unlink()
    return None


# ---------------------------------------------------------------- report

def describe(book, cache, analysis, keys, msg):
    custom = book.get("custom") or {}
    row = cache or {}
    title = custom.get("title") or row.get("title") or pathlib.PurePosixPath(book["path"]).name
    authors = (custom.get("authors") or row.get("authors") or "").replace("\n", "; ")
    lines = [f"## {title}" + (f" — {authors}" if authors else "") + f" ({book['ext'].upper()})", ""]
    a = analysis or {}
    for key in keys:
        lines.append("- " + msg[key].format(toc=a.get("toc_entries"), spine=a.get("spine")))
    found = []
    if "no_title" in keys and a.get("title"):
        found.append(msg["title"].format(v=a["title"]))
    if "no_author" in keys and a.get("author"):
        found.append(msg["author"].format(v=a["author"]))
    if found:
        lines.append("- " + msg["embedded"].format(what=", ".join(found)))
    if not keys:
        lines.append("- " + msg["all_good"])
    lines.append("")
    return lines


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="kindle", help="SSH host alias of the Kindle (default: kindle)")
    parser.add_argument("--lang", choices=sorted(MESSAGES), default="en")
    xdg_state = os.environ.get("XDG_STATE_HOME", "~/.local/state")
    xdg_data = os.environ.get("XDG_DATA_HOME", "~/.local/share")
    parser.add_argument("--state", default=f"{xdg_state}/kindlelab/new-books.json")
    parser.add_argument("--reports-dir", default=f"{xdg_data}/kindlelab/reports")
    parser.add_argument("--init", action="store_true", help="record the current library without reporting it")
    parser.add_argument("--notify", action="store_true", help="desktop notification when new books are found")
    parser.add_argument("--quiet", action="store_true", help="print nothing when there is nothing new")
    args = parser.parse_args(argv)
    msg = MESSAGES[args.lang]
    state_path = pathlib.Path(args.state).expanduser()
    state = json.loads(state_path.read_text()) if state_path.exists() else {}

    if not reachable(args.host):
        if not args.quiet:
            print(msg["unreachable"])
        return 0
    inventory = read_inventory(args.host)
    current = {b["path"]: {"bytes": b["bytes"], "mtime": b["mtime"]} for b in inventory}
    if args.init:
        state_path.parent.mkdir(parents=True, exist_ok=True)
        state_path.write_text(json.dumps(current, ensure_ascii=False, indent=1))
        print(msg["baseline"].format(n=len(current)))
        return 0
    new = new_or_changed(inventory, state)
    if not new:
        if not args.quiet:
            print(msg["none"])
        if set(state) - set(current):  # forget deleted books
            state_path.write_text(json.dumps(current, ensure_ascii=False, indent=1))
        return 0

    cache = read_cache(args.host)
    results = []
    with tempfile.TemporaryDirectory(prefix="kindle-new-books-") as tmp:
        for book in new:
            analysis = analyze(args.host, book, tmp)
            results.append((book, cache.get(book["path"]), analysis))
    attention = 0
    lines = [f"# {msg['heading'].format(date=datetime.now().strftime('%d/%m/%Y %H:%M'))}", ""]
    body = []
    for book, row, analysis in results:
        keys = issue_keys(book, row, analysis)
        attention += 1 if problem_count(keys) else 0
        body += describe(book, row, analysis, keys, msg)
    summary = msg["summary"].format(n=len(results), m=attention)
    lines += [summary, ""] + body
    reports = pathlib.Path(args.reports_dir).expanduser()
    reports.mkdir(parents=True, exist_ok=True)
    report = reports / f"new-books-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md"
    report.write_text("\n".join(lines), encoding="utf-8")
    print(summary)
    print(msg["report"].format(path=report))
    if args.notify and shutil.which("notify-send"):
        subprocess.run(["notify-send", "-a", "KindleLab", msg["notify_title"].format(n=len(results)),
                        summary + "\n" + msg["report"].format(path=report)], check=False)
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(current, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
