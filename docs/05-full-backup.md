# 05 · Full backup

> Tested on PW3 (`muscat_wario`), FW 5.16.2.1.1. The script refuses unusual layouts and asks for
> `--force` on untested models. It never writes to the Kindle.

## PW3 eMMC layout (512-byte sectors, from `/sys/block/mmcblk0`)

| Partition | Start sector | Size | Use |
|---|---|---|---|
| (raw area) | 0 | 32 MiB | MBR + bootloader/kernel area |
| `mmcblk0p1` | 65536 | 450 MiB | root filesystem (ext3, mounted read-only) |
| `mmcblk0p2` | 987136 | 64 MiB | ext3, mounted at `/usr/share/nh` |
| `mmcblk0p3` | 1118208 | 64 MiB | `/var/local` (ext3: content catalog, preferences, time zone) |
| `mmcblk0p4` | 1249280 | 3118 MiB | user storage (FAT, seen over USB and at `/mnt/us`) |
| `mmcblk0boot0/1` | | 2 MiB each | eMMC hardware boot partitions |

## Run it

```bash
scripts/full-backup.sh --test     # 2 MiB dry run: proves the hash check works
scripts/full-backup.sh            # real run, about 3 minutes over USB on a PW3
```

What it does:

1. Images the **system area** (everything before the largest partition: 610 MiB on the PW3) and
   both boot partitions with `dd`, streamed over SSH into `zstd`. On the Kindle a `mkfifo` + `tee`
   hashes exactly the bytes being sent; the PC decompresses and compares. Mismatch = abort.
2. Copies `/mnt/us` file by file with `rsync --link-dest` to the previous snapshot: unchanged
   files become hardlinks and take no space.
3. Writes a manifest, the partition layout and a README next to the data.

Our first run: 610 MiB → 281 MB compressed. The raw user partition is not imaged (several GB,
mostly free space); its files are.

**The backup contains account tokens, Wi-Fi credentials and your books.** Keep it local and private.

## Inspect it safely

```bash
zstd -d image/mmcblk0-system-0-610MiB.img.zst
udisksctl loop-setup -r -f mmcblk0-system-0-610MiB.img    # -r: read-only
```

Quick sanity check: the MBR ends with `55aa`, and each ext3 partition has the magic `53ef` at
byte 1080 from its start. The image is also the input for offline analysis
([docs/06](06-android-and-custom-os.md)).

Writing an image back to a Kindle is a recovery procedure for when something is already broken:
plan it, don't improvise.
