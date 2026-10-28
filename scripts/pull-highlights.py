#!/usr/bin/env python3
"""Pull Kindle highlights to the PC as Markdown (one file per book). Read-only on the Kindle.

Sources:
  1. Stock reader:  /mnt/us/documents/My Clippings.txt   -> <dest>/kindle/<book>.md
  2. KOReader:      /mnt/us/destaques/*.md  (KOReader > Export highlights, if configured
                    with build-koreader-config.py)          -> <dest>/koreader/
Access: Kindle mounted as a USB drive (auto-detected) or SSH (USBNetwork).

Usage: pull-highlights.py [--dest DIR] [--lang en|pt] [--host kindle] [--koreader-dir destaques]
"""
import argparse, getpass, glob, os, re, shutil, subprocess, sys, tempfile

CLIP = "documents/My Clippings.txt"

# Header keywords of each clipping. The device language may have changed over time, so a
# single file can mix languages. Tested: pt, en, fr. es/de/it: best effort, untested.
KINDS = [
    ("bookmark", r"marcador|bookmark|signet|lesezeichen|segnalibro"),
    ("note", r"\bnota\b|\bnote\b|notiz"),
    ("highlight", r"destaque|highlight|surlignement|subrayado|markierung|evidenziazione"),
]
LABELS = {
    "en": {"author": "Author", "source": "Source: Kindle stock reader (My Clippings.txt)",
           "items": "items", "note": "Note"},
    "pt": {"author": "Autor", "source": "Fonte: leitor nativo do Kindle (My Clippings.txt)",
           "items": "itens", "note": "Nota"},
}


def usb_mount():
    user = getpass.getuser()
    for pat in (f"/run/media/{user}/*", f"/media/{user}/*", "/media/*", "/mnt/*"):
        for m in glob.glob(pat):
            if os.path.exists(os.path.join(m, CLIP)):
                return m
    return None


def fetch(tmp, host, ko_dir):
    m = usb_mount()
    if m:
        shutil.copy2(os.path.join(m, CLIP), tmp)
        if os.path.isdir(os.path.join(m, ko_dir)):
            shutil.copytree(os.path.join(m, ko_dir), os.path.join(tmp, "ko"), dirs_exist_ok=True)
        return f"USB drive ({m})"
    if subprocess.run(["ssh", "-o", "ConnectTimeout=8", host, "true"], capture_output=True).returncode:
        sys.exit("Kindle not found: mount it as a USB drive, or turn on USBNetwork and run usbnet-connect.sh")
    subprocess.run(["scp", "-q", f"{host}:/mnt/us/{CLIP.replace(' ', chr(92) + ' ')}", tmp], check=True)
    os.makedirs(os.path.join(tmp, "ko"), exist_ok=True)
    subprocess.run(["scp", "-q", "-r", f"{host}:/mnt/us/{ko_dir}/.", os.path.join(tmp, "ko")],
                   capture_output=True)  # the folder may be empty or missing
    return f"SSH ({host})"


def safe_name(s):
    s = re.sub(r'[\\/:*?"<>|]+', " ", s).strip()
    return re.sub(r"\s+", " ", s)[:120] or "Untitled"


def convert(path, dest, lang):
    L = LABELS[lang]
    text = open(path, encoding="utf-8-sig", errors="replace").read()
    books = {}
    for block in text.split("=========="):
        lines = [l.rstrip() for l in block.strip().splitlines()]
        if len(lines) < 2:
            continue
        head, meta, body = lines[0].strip(), lines[1].strip(), "\n".join(lines[2:]).strip()
        kind = next((k for k, rx in KINDS if re.search(rx, meta, re.I)), "highlight")
        if kind == "bookmark" or not body:
            continue
        m = re.match(r"^(.*?)\s*\(([^()]*)\)\s*$", head)
        title, author = (m.group(1), m.group(2)) if m else (head, "")
        parts = [p.strip(" -") for p in meta.split("|")]
        book = books.setdefault(title, {"author": author, "items": [], "seen": set()})
        if body in book["seen"]:
            continue  # the Kindle appends a new clipping when a highlight is edited
        book["seen"].add(body)
        book["items"].append((kind, parts[0], parts[-1] if len(parts) > 1 else "", body))
    os.makedirs(dest, exist_ok=True)
    for title, b in sorted(books.items()):
        md = [f"# {title}", ""]
        if b["author"]:
            md += [f"**{L['author']}:** {b['author']}  ", ""]
        md += [f"_{L['source']} — {len(b['items'])} {L['items']}._", ""]
        for kind, where, when, body in b["items"]:
            md += [f"> 📝 **{L['note']}:** {body}", ""] if kind == "note" else ["> " + body.replace("\n", "\n> "), ""]
            md += [f"<sub>{where} · {when}</sub>", "", "---", ""]
        with open(os.path.join(dest, safe_name(title) + ".md"), "w", encoding="utf-8") as f:
            f.write("\n".join(md))
    return len(books), sum(len(b["items"]) for b in books.values())


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dest", default=os.path.expanduser("~/KindleLab/highlights"))
    ap.add_argument("--lang", choices=sorted(LABELS), default="en", help="language of the Markdown labels")
    ap.add_argument("--host", default=os.environ.get("KINDLE_HOST", "kindle"))
    ap.add_argument("--koreader-dir", default="destaques", help="KOReader export folder under /mnt/us")
    a = ap.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        how = fetch(tmp, a.host, a.koreader_dir)
        raw = os.path.join(a.dest, "_raw")
        os.makedirs(raw, exist_ok=True)
        clip = os.path.join(tmp, os.path.basename(CLIP))
        shutil.copy2(clip, raw)
        n_books, n_items = convert(clip, os.path.join(a.dest, "kindle"), a.lang)
        ko_src, ko_dst = os.path.join(tmp, "ko"), os.path.join(a.dest, "koreader")
        os.makedirs(ko_dst, exist_ok=True)
        n_ko = 0
        if os.path.isdir(ko_src):
            for n in os.listdir(ko_src):
                if n.lower().endswith(".md"):
                    shutil.copy2(os.path.join(ko_src, n), ko_dst)
                    n_ko += 1
    print(f"Via {how}: {n_items} highlights/notes from {n_books} books (stock reader) "
          f"+ {n_ko} KOReader export files -> {a.dest}")


if __name__ == "__main__":
    main()
