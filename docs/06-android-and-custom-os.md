# 06 · Android, "a new OS", and offline analysis

## Can a PW3 run Android?

Yes. **CrackDroid** by ygjsz installs Android 4.4.2 (5.1 on the Kindle 8th gen) next to the Kindle
system (dual boot) on PW2, PW3, Voyage, Kindle 7th/8th gen, Oasis 1 and a China-only model.
Sources: [English guide](https://github.com/Ooonana/Guide-to-installing-android-on-kindle),
[XDA thread](https://xdaforums.com/t/guide-installing-android-on-your-aging-kindle-e-reader.4450117/),
[MobileRead](https://www.mobileread.com/forums/showthread.php?t=349937).

We **did not** install it. Our reasons:

- The flashing tools are closed-source Windows executables from an unofficial site; the guide
  tells you to whitelist them in your antivirus.
- It wipes and repartitions the Kindle side, so jailbreak, SSH and KOReader must be redone. XDA has
  reports of devices that stopped booting mid-process.
- Android 4.4 is from 2013: no Play Store, most current apps refuse to install, many HTTPS sites fail
  on its old certificate store, and there are no security updates. The PW3 also has 512 MB of RAM
  and no audio, so video runs slowly and silently, as the guide itself warns.
- For reading it adds nothing: the best Android reader for e-ink is KOReader, which runs natively.

Other options: Alpine Linux in a chroot ([schuhumi/alpine_kindle](https://github.com/schuhumi/alpine_kindle)).
We found no real postmarketOS port for the PW3.

## What we do instead: KOReader as the everyday "system"

KOReader + SimpleUI gives a simple home screen and library. The tile from
[docs/04](04-koreader.md) opens it in one tap from the Amazon home screen. Purchased books still
open in the stock reader. Everything lives under `/mnt/us`, so undoing it means deleting a folder.
Starting KOReader at boot would need an upstart job in the root filesystem (a system-level change
that needs a full backup and an escape hatch first); not done yet.

## Offline analysis

The system image from [docs/05](05-full-backup.md) can be studied on the PC without any risk to
the device: mount it read-only, or use a reverse-engineering toolkit such as
[REA](https://github.com/morluto/rea) (an MCP server for Ghidra/Hopper/IDA, Binwalk/Unblob).
REA analyzes; it does not build or install systems.
