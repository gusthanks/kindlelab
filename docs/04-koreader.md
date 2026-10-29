# 04 · KOReader with a simple home screen

> Tested on PW3, FW 5.16.2.1.1: KOReader v2026.07.1, SimpleUI 3.0.1.

## Which package

From [KOReader releases](https://github.com/koreader/koreader/releases), per the
[KOReader wiki](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices):
`kindlehf` for **any** Kindle on FW ≥ 5.16.3; **`kindlepw2`** for touch Kindles from the PW2 on with
FW ≤ 5.16.2 (PW2, KV, KT2, **PW3**, KOA, KT3, KOA2, PW4, KT4, KOA3, PW5, KS).

KOReader **cannot open `.kfx`**: Amazon purchases *and* Send-to-Kindle documents keep opening in the
stock reader. KOReader is for EPUB, PDF, CBZ, FB2... copied to the device.

## Install over SSH with verification

```bash
Z=koreader-kindlepw2-v2026.07.1.zip
echo "<sha256 from the release page>  $Z" | sha256sum -c
mkdir stage && unzip -q $Z -d stage
(cd stage && find . -type f | sed 's|^\./||' | sort | xargs -d '\n' sha256sum) > koreader.sha256
scp -q $Z kindle:/mnt/us/ && ssh kindle "cd /mnt/us && unzip -o -q $Z && rm $Z && sync"
scp -q koreader.sha256 kindle:/tmp/ && ssh kindle 'cd /mnt/us && sha256sum -c /tmp/koreader.sha256 | grep -vc ": OK$"'   # expect 0
```

The zip only contains `koreader/` and `extensions/koreader/` (the KUAL menu entry).

## Configure (from the PC)

`scripts/build-koreader-config.py` writes a staging tree that mirrors `/mnt/us` plus a manifest.
**KOReader must be closed** on the Kindle (`ssh kindle 'ps | grep -c "[r]eader.lua"'` → 0).
Our configuration:

```bash
scp kindle:/mnt/us/koreader/settings.reader.lua settings.reader.lua.bak   # back it up first
scripts/build-koreader-config.py --settings settings.reader.lua.bak --out staging \
  --lang pt_BR --wikipedia pt,en \
  --home-dir /mnt/us/documents --download-dir "/mnt/us/documents/Livros baixados" \
  --highlights-dir /mnt/us/destaques \
  --opds koreader-config/opds.lua \
  --news-dir "/mnt/us/documents/Notícias/" --feeds koreader-config/feeds-pt-BR.lua \
  --plugin-zip simpleui.koplugin.zip \
  --dict-zip dict-pt-pt.zip --dict-name reader.dict-pt
rsync -rt --modify-window=1 --no-perms --no-owner --no-group \
  --rsync-path=/mnt/us/usbnet/bin/rsync staging/ kindle:/mnt/us/
scp staging.sha256 kindle:/tmp/m.sha256 && ssh kindle 'cd /mnt/us && sha256sum -c /tmp/m.sha256 | grep -vc ": OK$"'
```

(`rsync` on the Kindle comes with USBNetwork; the storage is FAT, hence the flags.)

| Piece | Source | Notes |
|---|---|---|
| SimpleUI | [doctorhetfield-cmd/simpleui.koplugin](https://github.com/doctorhetfield-cmd/simpleui.koplugin/releases) | Home screen + bottom bar; needs KOReader ≥ 2026.03 and the bundled CoverBrowser; has pt_BR. Use one UI plugin only (ZenOS / Project: Title conflict). |
| Dictionary | [reader-dict.com](https://www.reader-dict.com/) StarDict (Wiktionary, CC BY-SA) | Goes to `koreader/data/dict/<name>/` |
| OPDS | `koreader-config/opds.lua` | See the file for which catalogs still worked in 2026-10 |
| News | `koreader-config/feeds-pt-BR.lua` | Becomes EPUBs in the news folder |
| Highlights | KOReader → *Exportar destaques* (Markdown) | Then `scripts/pull-highlights.py` on the PC |

Useful keys in `settings.reader.lua`: `language`, `wikipedia_languages`, `home_dir`,
`download_dir` (OPDS downloads otherwise go to the *last folder visited*, which was KOReader's
help folder on a fresh install), `exporter.clipping_dir`, `exporter.markdown.enabled`.
The translation target follows the interface language unless `translator_to_language` is set.

## One-tap tile on the Amazon home screen

Copy [`kindle-files/documents/KOReader.sh`](../kindle-files/documents/KOReader.sh) to
`/mnt/us/documents/`. Scriptlet support (Universal Hotfix) indexes any `.sh` in `documents/` as a
"book"; header lines set its name, author and icon
([format](https://kindlemodding.org/kindle-dev/scriptlets.html)).

## Test without touching the device

```bash
ssh kindle 'cd /mnt/us/koreader && (setsid nohup ./koreader.sh --kual --asap >/dev/null 2>&1 &)'
sleep 30; scripts/kindle-screenshot.sh          # look at the PNG
ssh kindle 'grep -iE "ERROR|WARN" /mnt/us/koreader/crash.log | tail'
```

## Customizing further

Prefer KOReader *user patches* (`koreader/patches/*.lua`) over editing plugin sources: SimpleUI
checks for updates by itself and an update would overwrite edited files.

KindleLab's own patches and plugin (Amazon books in the same library, a tidy list, the sleep screen,
automatic organization of new books) are described, with install steps, in
[koreader-config/README.md](../koreader-config/README.md).

## Known issue: clock one hour ahead in KOReader

On our PW3 the Amazon UI shows the right time but KOReader and the shell are one hour ahead:
`/var/local/system/tz` (zone `America/Sao_Paulo`) is 2018 time-zone data that still applies the
Brazilian daylight saving time abolished in 2019. `scripts/kindle-status.sh` shows it as a
different UTC offset. Replacing that file with current zoneinfo should fix it: **untested**.
