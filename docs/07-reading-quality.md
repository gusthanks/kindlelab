# Reading quality: inspect first, adjust without rewriting

KindleLab separates **library metadata**, **reading preferences**, and **book contents**. A tidy library
is not proof that every edition, translation, table of contents, or page layout has been checked.

## What is working now

- Per-book `custom_metadata.lua` provides display titles, authors and tags without rewriting the book.
- Per-book `cover.jpg` provides a library/sleep-screen cover without replacing the cover inside an EPUB.
- The library patch indexes new books at startup, and the KindleLab plugin tags them by type (below).
  Neither is a full content-quality audit.
- Store books use the native Kindle reader; their protected contents are not inspected or converted.

Keep the original files and a fresh backup before changing sidecars or reader settings. Never publish a
reader's catalog, book files, sidecars, account data, or audit results in the project repository.

## Reading footer: leave some space below it

Tested on PW3 5.16.2.1.1 / KOReader v2026.07.1: changing
`footer.container_bottom_padding` from `1` to `12` moves the status/progress bar upward by 20 screen
pixels. Font, indicators, bar thickness, and text margins do not need to change.

Prefer the built-in Status bar configuration. If editing `settings.reader.lua` externally, close KOReader
first, back up the file, change only that field, verify the transfer hash, and reopen the book. Increasing
reserved footer space changes pagination; preserve the saved reading position, not a numeric page count.
Do not apply the value repeatedly over a reader's later manual choices.

## Safe inspection

Perform heavy inspection on the PC, not the low-power reader. Hash-check the copies against the originals.

| Format | Useful checks | Do not assume |
|---|---|---|
| EPUB | ZIP integrity, OPF resources, language, NCX/nav entries, links, cover, CSS, heading hierarchy | A valid ZIP is not a full EPUBCheck validation or a visual review |
| Unprotected MOBI/AZW | Header, embedded metadata, text/HTML extraction on a diagnostic copy, navigation | A Calibre conversion failure proves that the book is corrupt |
| Textual PDF | Text layer, page count, columns, margins, headings, tables and footnotes | Converting it to EPUB will preserve its layout |
| Image-only PDF | Image resolution, page crop, column layout, possible OCR | Empty extracted text means that the pages contain no content |
| Comics | Page ordering, margins, fit-to-width, double-page spreads, refresh interval | Text reflow or reading-direction reversal is always appropriate |
| Protected/native format | Display metadata and public cover only | KOReader settings affect the native Kindle reader |

For low-density pages, inspect a rendered page before recommending OCR. Covers, illustrations and comics
can legitimately contain little or no extractable text. Never reflow every PDF indiscriminately.

### Practical tool pitfalls

- The local Calibre installation must run with `/usr/bin` first in `PATH`, so its Python can find its modules.
- Calibre normalizes command-line file names to Unicode NFC. A decomposed (NFD) file name can therefore give
  `FileNotFoundError` even while Poppler and Python can open it. Inspect through an ASCII-named symlink on the
  PC; do not rename the book on the Kindle merely to satisfy this tool.
- Both `.pdf` and `.PDF` occur in real libraries. Discovery must be case-insensitive, including hash manifests.
- Some old unprotected MOBI files reach `AssertionError` at `guide is not None` in Calibre's `mobi6.py`.
  Keep the original. Test in the actual reader and investigate the conversion separately.

## Automatic intake (installed and tested)

Tested on PW3 5.16.2.1.1 / KOReader v2026.07.1 with copies of a scanned PDF, an image-only PDF comic and
an image MOBI comic, opened fresh. The book files are never changed.

**On the Kindle** — `koreader-config/plugins/kindlelab.koplugin` (Tools > KindleLab):

1. Some seconds after the library opens (45 s at start-up, 5 s when coming back from a book), books not
   seen before get a type tag in their custom metadata: `Tipo: Livro` (EPUB, DRM-free MOBI...),
   `Tipo: PDF`, `Tipo: Escaneado` (PDF without a text layer: fewer than 30 % of six sample pages have 50+
   letters), `Tipo: Quadrinho` (CBZ/CBR) or `Tipo: Amazon` (KFX, Topaz, DRM MOBI). Books that already
   have a type tag keep it; PDFs are analysed once to add the scanned tag. Seen books are remembered in
   `koreader/settings/kindlelab_intake.lua`, so a tag removed by the reader is not added back.
2. Two profiles are added once to Tools > Profiles and run the **first time** a book with the tag opens
   (auto-execution "on book opening" + "if book metadata contains" + "and if book is new"):
   * `KindleLab: Escaneado`: crop margins (auto) and contrast 1.5;
   * `KindleLab: Quadrinho`: zoom to the whole page, one page per screen, no cropping, contrast 1.0.
   Later changes in a book are never undone; readers can edit or delete the profiles.
3. While a `Tipo: Quadrinho` book is open, every page turn does a full e-ink refresh (no ghosting). It is
   set in memory only and restored when the book closes.
4. Comics cannot be told apart from scanned books automatically. In the reader, Tools > KindleLab >
   "Este livro é um quadrinho" swaps `Tipo: Escaneado` for `Tipo: Quadrinho` and applies the comic profile
   at once (tested: zoom page/full, page mode, no crop, contrast 1.0, refresh every page).

The kopt profiles only affect PDF/DjVu. In MOBI/EPUB comics the page layout is the file's own; the full
refresh still applies.

Defaults for new reflowable books are KOReader's own: set the font size you like with "Set as default" in
the bottom menu. Setting `text_lang_fallback` gives books without a language the right hyphenation.

**On the PC** — `scripts/kindle-new-books.py` (stdlib Python; poppler for PDFs) with the user units in
`systemd/`:

* every 15 minutes, if the Kindle answers over SSH, it lists the library (read-only) and compares it with
  the last check (`~/.local/state/kindlelab/new-books.json`);
* new books get a short report: missing title/author/cover/type tag, a weak table of contents, scanned
  PDFs and "looks like a comic" hints, plus the title/author written inside the file when the library
  lacks them; a desktop notification points to the report;
* nothing is written to the Kindle. Reports list book titles, so keep them out of any repository.

```bash
scripts/kindle-new-books.py --init            # remember the current library first
cp systemd/kindlelab-new-books.* ~/.config/systemd/user/   # adjust ExecStart paths/--lang first
systemctl --user daemon-reload && systemctl --user enable --now kindlelab-new-books.timer
```

Fixes (OCR, conversions, table-of-contents or CSS repairs) stay manual: on a backed-up copy, previewed and
approved before replacing anything. Do not send book contents to a cloud AI without explicit consent.

Tests: `tests/run.sh` (pure Lua, no KOReader needed) and `python3 -m unittest discover -s tests`.

## Primary references

- [KOReader User Guide](https://koreader.rocks/user_guide/): Profiles, Profile auto-execution, and
  Optimizing EPUB/PDF documents.
- [Calibre conversion manual](https://manual.calibre-ebook.com/conversion.html): PDF limitations and
  structure detection.

Device test claims above refer only to PW3 5.16.2.1.1 with KOReader v2026.07.1. Other hardware needs testing.
