# KindleLab

**English** · [Português](README.pt-BR.md)

**Jailbreak your Kindle without getting lost, then turn it into a reader that is pleasant every day.**
One page walks you through the jailbreak in plain words, with the official link for every click. After
that: one library for all your books, new books that organize themselves, settings that suit each kind of
book, and tools that check every step. No DRM removal, no risky shortcuts.

> **Tested on exactly one device:** Kindle Paperwhite 3 (7th gen, `muscat_wario`), firmware
> **5.16.2.1.1**. Everything else is either *community-reported* (with a link) or *untested*.
> Check [docs/compatibility.md](docs/compatibility.md) before following anything on another model.

## Start here

| Your Kindle today | Go to |
|---|---|
| Not jailbroken yet | **[The jailbreak guide](docs/jailbreak-guide.md)**: the whole trip on one page |
| Somewhere in the middle | **[Where am I?](https://gusthanks.github.io/kindlelab/)**: plug in the Kindle and the page tells you your step (it runs in your browser; nothing is sent) |
| Jailbroken, but you're not sure what state it's in | [Diagnose an existing jailbreak](docs/01-diagnose.md) (read-only) |
| Jailbroken, with KOReader | [What KindleLab adds](#what-kindlelab-adds) |

## Why KindleLab

- **One map instead of many tabs.** The official [KindleModding](https://kindlemodding.org/) guides have
  every detail, spread over many pages. Our [jailbreak guide](docs/jailbreak-guide.md) puts the trip in
  order on one page: why each step matters, what to do, how you know it worked, when to stop and ask for
  help, and the words you will meet. For the exact clicks it links to the official page, so it never
  replaces them. Lost on the way? The [Where am I?](https://gusthanks.github.io/kindlelab/) page looks at
  your Kindle and tells you the step.
- **A finished reader, not just a jailbreak.** Most guides end at "install KOReader". KindleLab keeps going
  ([below](#what-kindlelab-adds)).
- **Safety you can check.** Backups first, every copy verified with SHA-256 on the device, read-only
  diagnostics, key-only SSH.
- **Honest about testing.** Everything is labeled tested, community-reported or untested.
- **In English and Portuguese**, and ready for [more languages](#languages).

## What KindleLab adds

| Without KindleLab | With KindleLab |
|---|---|
| Two libraries: Amazon purchases in the stock reader, everything else in KOReader | **One library.** Amazon books show up in KOReader with cover, title and author and open in the Kindle's own reader with one tap. DRM is never touched. |
| Dictionaries, scripts and empty folders mixed with books | **Only books are listed.** Dictionaries keep working, just hidden. |
| New books arrive untyped, sometimes without author or cover | **Automatic organization:** each new book gets a type tag (Livro, PDF, Escaneado, Quadrinho, Amazon) and the PC tells you what is missing. |
| Scanned PDFs with huge margins; comics with ghosting | **The right settings on first opening:** cropped margins and more contrast for scans; whole page and a clean refresh on every page for comics. |
| Generic sleep screen | **The cover of the book you are reading** on the sleep screen. |
| KOReader hidden in the KUAL menu | **One-tap tile on the Kindle home screen**, with an icon gallery and a switcher inside KOReader. |
| Scattered forum guides, fear of bricking | **Tested steps**, a full backup first, every copy verified with SHA-256 on the device. |
| PC access with a password, cable only | **Key-only SSH** over USB or Wi-Fi, and a verified block of automatic updates. |

Plus: KOReader with a simple home screen (SimpleUI), dictionary, Wikipedia, free-book catalogs, news, and
highlight export to Markdown.

**Who it is for:** anyone with a Kindle who wants KOReader without weeks of forum reading. The jailbreak
guide works with any computer. The [offline add-on installer](installer/INSTALL.md) targets a mounted USB
drive and needs Python 3.11+; other PC tools use Linux. Manual copying remains available.

**What it is not:** not a jailbreak tool (we don't host or change jailbreak files; the guide sends you to the
official ones), not a DRM remover or a piracy tool, not a replacement OS
([docs/06](docs/06-android-and-custom-os.md)), and not tested beyond one device.

**Status:** the reading setup was tested on the PW3. The **[offline installer preview](installer/INSTALL.md)**
now bundles KindleLab's own add-ons with a window, read-only preview, backup, SHA-256 checks and Undo.
It preserves existing settings and a customized launcher. Python 3.11+ and a normal USB-drive connection
are required; **MTP devices are not supported by this first installer**. KOReader, SimpleUI and dictionaries
remain separate installations. [Download releases](https://github.com/gusthanks/kindlelab/releases) ·
[manual installation](koreader-config/README.md).

## Guides

- **Jailbreak:** [the jailbreak guide](docs/jailbreak-guide.md) · [safety rules](docs/00-safety.md) ·
  [diagnose an existing jailbreak](docs/01-diagnose.md) ·
  [KUAL, MRPI and the OTA block](docs/02-kual-mrpi-ota.md) (legacy path)
- **After the jailbreak:** [USBNetwork and SSH](docs/03-usbnetwork-ssh.md) · [KOReader](docs/04-koreader.md) ·
  [full backup](docs/05-full-backup.md) · [the KindleLab reading setup](koreader-config/README.md) ·
  [reading quality and new books](docs/07-reading-quality.md)
- **Reference:** [troubleshooting](docs/troubleshooting.md) · [compatibility](docs/compatibility.md) ·
  [Android and "new OS" questions](docs/06-android-and-custom-os.md)

## What's here

| Path | What it is |
|---|---|
| [`docs/`](docs/) | The guides above |
| [`installer/`](installer/) | Offline add-on installer: window/CLI, backup, SHA-256 verification and Undo |
| [`checker/`](checker/) | The [Where am I?](https://gusthanks.github.io/kindlelab/) page (runs in the browser) and its command-line version |
| [`scripts/`](scripts/) | PC-side tools (bash/python). All read-only on the Kindle unless stated |
| [`koreader-config/`](koreader-config/) | KOReader user patches, the KindleLab plugin, OPDS catalog and news-feed templates |
| [`kindle-files/`](kindle-files/) | Small files to copy to the Kindle (e.g. the one-tap KOReader tile and its icons) |
| [`systemd/`](systemd/) | Optional user timer that checks new books on the Kindle (see docs/07) |
| [`tests/`](tests/) | Unit tests: `tests/run.sh` (Lua and the checker's Node tests) and `python3 -m unittest discover -s tests` |

### Scripts

| Script | Purpose | Writes to the Kindle? |
|---|---|---|
| `usbnet-connect.sh` | Configure the PC side of USBNetwork (NetworkManager), handle subnet clashes | no |
| `kindle-find-wifi.sh` | Find the Kindle's Wi-Fi address on your LAN by its MAC (for SSH over Wi-Fi) | no |
| `kindle-status.sh` | Health panel: firmware, OTA block, hotfix, battery, Wi-Fi, clock, space, SSH mode | no |
| `kindle-screenshot.sh` | Screenshot of the e-ink screen (via `fbgrab`) | `/tmp` only |
| `full-backup.sh` | Bit-exact image of the system area + boot partitions, hash-checked on the device, plus incremental file copy | no |
| `pull-highlights.py` | `My Clippings.txt` (stock reader) + KOReader exports → one Markdown file per book | no |
| `build-koreader-config.py` | Build a KOReader config (language, dictionary, OPDS, news, plugins) as a staging tree + manifest | no (you push it) |
| `kindle-new-books.py` | Report on books added since the last check (title, author, cover, type tag, table of contents, scanned PDF / comic hints); `--notify` for the systemd timer | no |
| `kindle-inventory.lua` | Read-only library listing run on the Kindle by `kindle-new-books.py` (KOReader's LuaJIT) | no |
| `check-privacy.sh` | Pre-commit hook that blocks serials, MACs, IPs, e-mails, home paths and your own denylist | — |

## Ground rules

- Back up first. One change at a time. Verify every copy with SHA-256 **on the device**.
- Keep airplane mode on until the OTA block is verified.
- Never factory-reset, deregister or update firmware "to fix something".
- **No DRM removal, no piracy sources.** Purchased books stay in the stock reader.

## Languages

English is the main language. In Portuguese (Brazil): this README ([README.pt-BR.md](README.pt-BR.md)) and
the [jailbreak guide](docs/jailbreak-guide.pt-BR.md). The other guides are in English.

Want the jailbreak guide in your language? Copy `docs/jailbreak-guide.md` to
`docs/jailbreak-guide.<language code>.md` (for example `jailbreak-guide.es.md`), translate it, add your
language to the links at the top of every version, and open a pull request.

## Contributing

Test reports from other models and firmwares are the most valuable contribution:
use the *Test report* issue form. Please remove serial numbers, MAC addresses, Wi-Fi names and
e-mails from logs. Before committing, enable the privacy hook:

```bash
ln -s ../../scripts/check-privacy.sh .git/hooks/pre-commit
```

## License and credits

Scripts and docs: [MIT](LICENSE). Nothing third-party is redistributed here; follow the links instead:
[KindleModding](https://kindlemodding.org/) (WinterBreak, Universal Hotfix, guides),
NiLuJe (USBNetwork, MRPI, KUAL tooling, [MobileRead](https://www.mobileread.com/forums/showthread.php?t=225030)),
[KindleTweaks/PEKI](https://github.com/KindleTweaks/PEKI),
[Kindle-Filler-Disk](https://github.com/iiroak/Kindle-Filler-Disk),
[KOReader](https://github.com/koreader/koreader) (AGPL-3.0),
[SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin) (GPL-3.0),
[reader-dict](https://www.reader-dict.com/) (Wiktionary dictionaries, CC BY-SA),
[notmarek's scriptlets](https://scriptlets.notmarek.com/).
