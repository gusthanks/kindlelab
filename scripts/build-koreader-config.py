#!/usr/bin/env python3
"""Build a KOReader configuration for a Kindle as a staging tree that mirrors /mnt/us,
plus a SHA-256 manifest (<out>.sha256) to verify the copy ON the Kindle. Touches nothing on
the Kindle: push it yourself (see docs/04-koreader.md).

Every feature is optional; pass only what you want:
  --lang pt_BR                 KOReader interface language (also the translation target)
  --wikipedia pt,en            Wikipedia lookup languages
  --home-dir DIR               folder the file browser opens in (Kindle default: /mnt/us)
  --download-dir DIR           where OPDS downloads go (default: last folder visited!)
  --highlights-dir DIR         Markdown highlight export folder (enables the Markdown exporter)
  --opds FILE                  OPDS catalog list (Lua, see koreader-config/)
  --news-dir DIR --feeds FILE  news (RSS) download folder + feed list (Lua, see koreader-config/)
  --plugin-zip ZIP             KOReader plugin zip containing <name>.koplugin/ (repeatable)
  --dict-zip ZIP --dict-name N StarDict dictionary zip, unpacked to koreader/data/dict/N/

Usage: build-koreader-config.py --settings <copy of koreader/settings.reader.lua> --out <dir> [options]
Edit settings only while KOReader is CLOSED on the Kindle (it rewrites them on exit).
"""
import argparse, hashlib, os, re, shutil, subprocess, sys, zipfile

US = "/mnt/us/"


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def set_top_key(src, key, lua_value):
    """Set a top-level key of KOReader's settings table (replace if present, else append)."""
    pat = re.compile(r'^    \["%s"\] = .*?(?=^    \["|^\}\s*$)' % re.escape(key), re.S | re.M)
    line = f'    ["{key}"] = {lua_value},\n'
    if pat.search(src):
        return pat.sub(line.replace("\\", "\\\\"), src, count=1)
    body = src.rstrip()
    assert body.endswith("}"), "unexpected settings.reader.lua format"
    return body[:-1] + line + "}\n"


def enable_markdown_export(src, clip_dir):
    old = '    ["exporter"] = {\n'
    if old not in src:
        return set_top_key(src, "exporter", '{\n        ["clipping_dir"] = %s,\n        ["markdown"] = {\n'
                           '            ["enabled"] = true,\n        },\n    }' % lua_str(clip_dir))
    src = re.sub(r'\n        \["clipping_dir"\] = [^\n]*', "", src)
    src = src.replace(old, old + f'        ["clipping_dir"] = {lua_str(clip_dir)},\n', 1)
    if '        ["markdown"] = {\n' in src:
        src = re.sub(r'\n            \["enabled"\] = (true|false),', "", src, count=1)
        src = src.replace('        ["markdown"] = {\n', '        ["markdown"] = {\n            ["enabled"] = true,\n', 1)
    else:
        src = src.replace(old, old + '        ["markdown"] = {\n            ["enabled"] = true,\n        },\n', 1)
    return src


def rel(path):
    assert path.startswith(US), f"{path} must be under {US}"
    return path[len(US):]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--settings", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--lang")
    ap.add_argument("--wikipedia")
    ap.add_argument("--home-dir")
    ap.add_argument("--download-dir")
    ap.add_argument("--highlights-dir")
    ap.add_argument("--opds")
    ap.add_argument("--news-dir")
    ap.add_argument("--feeds")
    ap.add_argument("--plugin-zip", action="append", default=[])
    ap.add_argument("--dict-zip")
    ap.add_argument("--dict-name")
    a = ap.parse_args()
    if bool(a.news_dir) != bool(a.feeds):
        sys.exit("--news-dir and --feeds go together")
    if bool(a.dict_zip) != bool(a.dict_name):
        sys.exit("--dict-zip and --dict-name go together")

    out = a.out.rstrip("/")
    if os.path.exists(out):
        shutil.rmtree(out)
    ko = os.path.join(out, "koreader")
    os.makedirs(os.path.join(ko, "settings"))
    texts = {}

    s = open(a.settings, encoding="utf-8").read()
    if a.lang:
        s = set_top_key(s, "language", lua_str(a.lang))
    if a.wikipedia:
        langs = [l.strip() for l in a.wikipedia.split(",") if l.strip()]
        s = set_top_key(s, "wikipedia_languages", "{\n" + "".join(
            f"        [{i}] = {lua_str(l)},\n" for i, l in enumerate(langs, 1)) + "    }")
    for key, val in (("home_dir", a.home_dir), ("download_dir", a.download_dir)):
        if val:
            s = set_top_key(s, key, lua_str(val.rstrip("/")))
            os.makedirs(os.path.join(out, rel(val.rstrip("/") + "/")), exist_ok=True)
    if a.home_dir:  # don't reopen whatever was last viewed (e.g. the bundled help file)
        s = set_top_key(s, "lastdir", lua_str(a.home_dir.rstrip("/")))
        s = re.sub(r'^    \["lastfile"\] = [^\n]*\n', "", s, flags=re.M)
    if a.highlights_dir:
        s = enable_markdown_export(s, a.highlights_dir.rstrip("/"))
        os.makedirs(os.path.join(out, rel(a.highlights_dir.rstrip("/") + "/")), exist_ok=True)
    texts["koreader/settings.reader.lua"] = s

    if a.opds:
        texts["koreader/settings/opds.lua"] = open(a.opds, encoding="utf-8").read()
    if a.news_dir:
        nd = a.news_dir.rstrip("/") + "/"
        texts["koreader/settings/news_settings.lua"] = (
            "-- KindleLab: folder for downloaded news\nreturn {\n"
            f'    ["custom_dl_dir"] = {lua_str(nd)},\n}}\n')
        texts[rel(nd) + "feed_config.lua"] = open(a.feeds, encoding="utf-8").read()

    for r, t in texts.items():
        p = os.path.join(out, r)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            f.write(t)
        chk = subprocess.run(["luajit", "-e", f"assert(type(dofile([[{p}]]))=='table')"],
                             capture_output=True, text=True)
        if chk.returncode:
            sys.exit(f"invalid Lua in {r}: {chk.stderr.strip()}")

    for z in a.plugin_zip:
        with zipfile.ZipFile(z) as zf:
            tops = {n.split("/")[0] for n in zf.namelist()}
            if not all(t.endswith(".koplugin") for t in tops):
                sys.exit(f"{z}: expected only <name>.koplugin/ at the top, found {sorted(tops)}")
            zf.extractall(os.path.join(ko, "plugins"))
    if a.dict_zip:
        with zipfile.ZipFile(a.dict_zip) as zf:
            zf.extractall(os.path.join(ko, "data", "dict", a.dict_name))

    lines = []
    for root, _, names in os.walk(out):
        for n in names:
            p = os.path.join(root, n)
            with open(p, "rb") as f:
                lines.append(f"{hashlib.sha256(f.read()).hexdigest()}  {os.path.relpath(p, out)}")
    lines.sort(key=lambda l: l.split("  ", 1)[1])
    with open(out + ".sha256", "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"OK: {len(lines)} files in {out} (manifest: {out}.sha256)")


if __name__ == "__main__":
    main()
