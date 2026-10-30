# Install KindleLab

**English** · [Português](INSTALL.pt-BR.md)

This installs the **KindleLab add-ons**, not a jailbreak, KOReader or SimpleUI. Start with the
[jailbreak guide](https://github.com/gusthanks/kindlelab/blob/main/docs/jailbreak-guide.md) if KOReader is not
already working on your Kindle.

## The short version

1. Download the installer ZIP from [Releases](https://github.com/gusthanks/kindlelab/releases), and extract
   it **on your computer**, not on the Kindle. You need **Python 3.11 or newer**; the window also needs Tk
   (included with the standard Python installers for Windows/macOS; some Linux distributions package it separately).
   Official Python downloads: <https://www.python.org/downloads/>. No pip packages are required.
2. **Exit KOReader**, turn airplane mode on, and connect the Kindle as a **USB drive**. Back up your books
   and other personal files first. This installer's own backup covers only the files it replaces.
3. Open **Install-Windows.cmd** on Windows, **Install-macOS.command** on macOS, or run
   `python3 install.py` on Linux. The macOS/Linux scripts may need permission to execute; the Python command
   works without that permission. Choose English or Português in the window.
4. Choose the Kindle's **main folder**, the one containing `documents`, `system` and `koreader`.
   Select your model, confirm you exited KOReader and turned airplane mode on, then click **Install**.
   The window shows the list of files before asking you to confirm.
5. Wait for **SHA-256 verified**, safely eject the drive, disconnect the cable and open KOReader.

**Do not use this on an MTP connection.** Newer Kindles (11th generation and later) do not expose a normal
USB drive. They are not supported by this first installer. Installing on a PC copy is a test, not an
installation on the Kindle. Manual instructions remain in
[koreader-config](https://github.com/gusthanks/kindlelab/blob/main/koreader-config/README.md).

## What is installed

- KindleLab's tidy-library and Amazon-book-listing patches (Amazon books still open in the native reader,
  without DRM removal).
- The KindleLab plugin: type tags, new-book reading profiles for scans/comics, comic toggle and icon picker.
- A first-run-defaults patch: **only missing preferences** are filled in (library at `/mnt/us/documents`,
  downloads there too, title sorting and a home-folder lock).
- Three KOReader tile icons and a fallback sleep-screen image. Sleep-screen defaults also only fill
  missing preferences: an existing choice is never replaced.
- The KOReader home-screen launcher, **only if `documents/KOReader.sh` does not exist**. A customized launcher
  or icon is kept exactly as it was.

The installer does not change `settings.reader.lua`, SimpleUI's settings, your mascot, reading history,
fonts, language, books, SSH keys, network settings, update blocking or firmware. On the **next KOReader
start**, the installed patches fill missing settings and the plugin adds its profiles and metadata tags.
Those later settings/tags are not rolled back by Undo. Existing book bytes are not rewritten.

**Not included:** KOReader, SimpleUI, dictionaries, news feeds or a PC monitoring timer. These are separate
optional installations; no third-party executable is downloaded or redistributed. The plugin's existing
`Tipo: …` tags and profile names are currently in Portuguese in both UI languages, to remain compatible
with existing libraries.

## Backup, undo and recovery

A verified copy of each replaced file, its hashes and a receipt are saved on the Kindle under
`.kindlelab-installer/transactions/<backup-id>/`. Keep this hidden folder; optionally copy it to your PC.
Installing again with the same files does not replace anything unnecessarily.

**Undo:** exit KOReader, reconnect in USB-drive mode, choose the same drive in the installer and click
**Undo last installation**. It restores the previous bytes or removes files that this installation added.
It checks every relevant file before changing anything: if you edited an installed file since then, it
stops instead of overwriting your edit. Empty folders can remain. It does **not** remove the jailbreak,
KOReader or reading metadata created after you started KOReader.

**Interrupted install:** keep airplane mode on, reconnect the same drive, and use Undo with the backup id
shown in the error. An ordinary write failure triggers automatic rollback when the drive is still reachable.
If the cable is unplugged or the process is killed, it may not be possible to finish the rollback immediately.
A new install refuses to run over an unfinished transaction. If only backup preparation was interrupted,
no target add-on file has changed yet; a leftover `.kindlelab-installer/preparing/` folder is not a published
transaction, and retrying after the installer has stopped is allowed.

**Power-loss limits:** rereading files and checking hashes is not proof that a USB controller has physically
saved every byte. Filesystems and devices can cache writes. No destructive power-loss/cable-removal test has
been performed; do not assume rollback completed while the drive was disconnected. Keep an independent
PC backup and always safely eject. POSIX directory entries are explicitly synchronized; Windows regular
files are flushed, but this installer has no portable unprivileged way to flush Windows directory entries.
Filesystem synchronization errors stop completion rather than being ignored. The installer is a preview,
not a replacement for a backup.

If it reports an installer lock, first make certain that **no other installer is running**. Then remove only
the empty `.kindlelab-installer/lock` directory (do not delete the transactions), and run Undo. If a backup or
installed file fails a hash check, keep all files and ask for help; there is deliberately no "force overwrite"
switch. Do not reset, deregister or update the Kindle to fix the installer.

## Command line

From the extracted folder (replace `<drive>` with your Kindle's drive path):

```sh
python3 install.py --target "<drive>" --model pw3 --dry-run
python3 install.py --target "<drive>" --model pw3 --yes --closed
python3 install.py --target "<drive>" --undo --yes --closed
python3 install.py --target "<drive>" --undo <backup-id> --yes --closed
```

On Windows use `py -3` instead of `python3`. `--closed` confirms KOReader is closed and airplane mode is on.
`--lang pt` changes the interface, not your KOReader language. No network connection is used.

Only **Paperwhite 3 / firmware 5.16.2.1.1 / KOReader v2026.07.1** has device validation. Other or unreadable
KOReader revisions also require the explicit untested override. The model cannot be detected from the USB
files; you must select it yourself. Other combinations require an explicit `--allow-untested` (or the window's
untested checkbox). That override does not make an unsupported Kindle supported. Desktop platform test
results are published in the repository's Installer workflow; they do not replace tests on real devices.

The ZIP's adjacent `.sha256` verifies download integrity. The internal manifest checks payload corruption,
not the identity of the publisher: only download releases from `gusthanks/kindlelab`.
