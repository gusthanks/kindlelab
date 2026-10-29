# Where am I?

**Open it: <https://gusthanks.github.io/kindlelab/>** (Portuguese: <https://gusthanks.github.io/kindlelab/?lang=pt>)

A small page for the [jailbreak guide](../docs/jailbreak-guide.md). Plug in the Kindle, choose its drive, and
the page tells you which step you are on and what to do next, with a link to that step of the guide.

## Privacy

- It runs entirely in your browser. There is no server and no analytics.
- Its Content-Security-Policy blocks every network connection (`connect-src 'none'`), so nothing can be sent.
- It reads only the **names** of the entries at the top of the drive and in `documents`, `extensions`,
  `apps`, `koreader`, `koreader/patches` and `koreader/plugins`, plus three small text files:
  `system/version.txt`, `extensions/MRInstaller/log/mrinstaller.log` (last 64 KB) and
  `documents/JAILBROKEN.txt`. Book contents are never opened.

## What it looks at

| Sign on the drive | Meaning |
|---|---|
| `update….bin` or `update.bin.tmp.partial` in the root | An update is waiting to install: delete it (always shown first) |
| `fill_disk` folder | Storage filled (step 3); check the free space on the Kindle |
| `mesquito` or `apps/…winterbreak` without a jailbreak sign | WinterBreak copied but not run (step 5); warns on firmware 5.18.1+ |
| `jb.sh.log` without `documents/JAILBROKEN.txt` | A modern jailbreak started but did not finish |
| `documents/JAILBROKEN.txt` | Modern jailbreak done: updates blocked, clean up the filler (step 6A) |
| `documents/*.run_hotfix` | Legacy jailbreak done (step 6B) |
| `KUAL…` in documents, `extensions/MRInstaller`, `extensions/renameotabin` | Legacy path: KUAL, MRPI, update block |
| "Not enough space" in the MRPI log | Stuck like we were: free about 220 MB with airplane mode on |
| `koreader/reader.lua` | KOReader installed (step 7) |
| `2-kindlelab-*.lua` patches or `kindlelab.koplugin` | KindleLab pieces installed (step 8) |

It cannot see airplane mode, the free space, or whether updates are really blocked: the page asks you to check
those on the Kindle.

**Newer Kindles** (11th generation and later) connect as a media device (MTP), which browsers can't open.
Copy their folders to the computer first (step 2 of the guide) and choose the copy.

## Command line

```bash
node checker/cli.js /path/to/the/Kindle --lang en   # or --lang pt, or --json
```

## Tests

```bash
node --test tests/checker*.test.mjs
```

The tests cover every result, both languages, and check that every link into the guide points at a heading
that exists. The analysis was also checked against two real states of our Kindle: stuck at KUAL (a backup
from before this project) and finished (today).

Changes to `checker/` are tested and published by [.github/workflows/checker.yml](../.github/workflows/checker.yml).
`window.kindlelabCheck(snapshot)` renders a snapshot without the folder dialog, for automated checks.
