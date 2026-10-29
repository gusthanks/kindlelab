# KOReader pieces

Everything KindleLab adds to KOReader is a plain file in this folder. Nothing here edits KOReader or
SimpleUI themselves, so their updates do not undo it, and each piece can be removed on its own.

Tested on: Kindle Paperwhite 3 (FW 5.16.2.1.1), KOReader v2026.07.1, SimpleUI 3.0.1.

| File | Copy to | What it does |
|---|---|---|
| `patches/2-kindlelab-store-books.lua` | `koreader/patches/` | **One library.** Amazon books (KFX, Topaz `.azw1`, AZW3/AZW4, DRM MOBI) appear in KOReader with the Kindle's own cover, title and author. Tapping one closes KOReader and opens it in the Kindle's reader. It only reads the stock catalog and cover thumbnails, never the book contents. Keep these books in the main `documents` folder. |
| `patches/2-kindlelab-library.lua` | `koreader/patches/` | **Only books in the list.** Hides the dictionaries folder (they keep working in the stock reader), launcher scripts, `My Clippings.txt` and folders without books. Keeps the cover/tag cache in sync with the disk. |
| `patches/2-kindlelab-sleepscreen.lua` | `koreader/patches/` | **Sleep screen** = the cover of the book you are reading; in the library, one of the Kindle's own screensaver images (see step 2). Applied once: your later menu choices are kept. |
| `plugins/kindlelab.koplugin/` | `koreader/plugins/` | **Tools > KindleLab.** Type tags for new books, reading profiles for scanned PDFs and comics on first opening, "This book is a comic", and the Kindle home-screen icon switcher. Details: [docs/07](../docs/07-reading-quality.md) and [kindle-files/koreader-tile](../kindle-files/koreader-tile/README.md). |
| `opds.lua` | `koreader/settings/opds.lua` | Free-book catalogs (Project Gutenberg, filtered by language) |
| `feeds-pt-BR.lua` | `<news dir>/feed_config.lua` | News feeds (Brazilian Portuguese example) |

`opds.lua` and `feeds-pt-BR.lua` are used by [`scripts/build-koreader-config.py`](../scripts/build-koreader-config.py)
(see [docs/04](../docs/04-koreader.md)), which checks them with `luajit` before writing anything.

## Install

KOReader saves its settings when it exits and would overwrite changes made while it runs, so:

1. **Close KOReader**, then copy the files above (SSH is how we tested; USB drive mode works for plain
   files too). Keep the file names: the `2-` prefix makes the patches run after KOReader's settings load.
2. Sleep screen only, once, over SSH: copy the Kindle's own images:
   `mkdir -p /mnt/us/koreader/screensavers && cp /usr/share/blanket/screensaver/bg_ss*.png /mnt/us/koreader/screensavers/`
3. Compare `sha256sum` on the PC and on the Kindle, then start KOReader. The plugin tags new books about
   45 seconds after the library opens.

To remove a piece, delete its file (or the plugin folder) with KOReader closed.

Adding a feed for your language? Copy `feeds-pt-BR.lua` to `feeds-<lang>.lua` and open a pull
request. Prefer feeds that already carry the full article text.
