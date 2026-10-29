# Reading quality: inspect first, adjust without rewriting

KindleLab separates **library metadata**, **reading preferences**, and **book contents**. A tidy library
is not proof that every edition, translation, table of contents, or page layout has been checked.

## What is working now

- Per-book `custom_metadata.lua` provides display titles, authors and tags without rewriting the book.
- Per-book `cover.jpg` provides a library/sleep-screen cover without replacing the cover inside an EPUB.
- The library patch indexes new books at startup. This is **not** an automatic content-quality audit.
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

## Proposed automatic intake — not installed yet

A future intake workflow should:

1. Watch only the book library, excluding dictionaries, system files and sidecar folders.
2. Wait until a new transfer finishes, hash the file, and inspect it once per content version.
3. Extract reliable title, author, language, cover and navigation. Flag missing or uncertain data instead
   of inventing it or using an author guessed from a file name.
4. Choose a visual profile on **first opening**, without overwriting settings of books already adjusted.
5. Keep heavy OCR, conversion, CSS cleanup and navigation repairs on a backed-up PC copy, with preview and
   approval before replacement. Do not send book contents to a cloud AI without explicit consent.
6. Retain an undo path. Keep audit output private and local.

KOReader's built-in **Profiles** plugin already supports auto-execution on book opening, conditions based
on document properties/path/collections, and a new-document restriction. These are useful building blocks,
not an automatic semantic classifier or a content-repair service. Suggested profile families are flowing
text, textual PDFs, image PDFs, and comics. Fine-tune them with the reader before enabling defaults.

## Primary references

- [KOReader User Guide](https://koreader.rocks/user_guide/): Profiles, Profile auto-execution, and
  Optimizing EPUB/PDF documents.
- [Calibre conversion manual](https://manual.calibre-ebook.com/conversion.html): PDF limitations and
  structure detection.

Device test claims above refer only to PW3 5.16.2.1.1 with KOReader v2026.07.1. Other hardware needs testing.
