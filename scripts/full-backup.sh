#!/usr/bin/env bash
# Full backup of a jailbroken Kindle over SSH — READ-ONLY on the Kindle.
#
#   image/  bit-exact copy of the eMMC "system area" (everything before the user-storage
#           partition: MBR, bootloader/kernel area, rootfs, /var/local, ...) and of the eMMC
#           hardware boot partitions, zstd-compressed. The SHA-256 of the raw bytes is computed
#           ON THE KINDLE while they are read (mkfifo + tee) and compared on the PC.
#   files/  file-level copy of the user storage (/mnt/us), incremental: files unchanged since
#           the previous snapshot become hardlinks and take no extra space.
#   info/   partition table, versions, mounts, file manifest.
# The raw user-storage partition is NOT imaged (several GB, mostly free space).
#
# Tested on: Kindle Paperwhite 3 (muscat_wario), FW 5.16.2.1.1. Other models: the script
# refuses unusual partition layouts and asks for --force on untested models.
#
# Usage: full-backup.sh [--test] [--force]
#   --test   dump only mmcblk0boot1 (2 MiB) to a temp dir, verify the hash, delete it
#   --force  run on a model that has not been tested
# Env: KINDLE_HOST (default "kindle"), KINDLE_BACKUP_DIR (default ~/Backups/Kindle)
# Images contain account tokens and Wi-Fi credentials: keep them private, never upload them.
set -euo pipefail
HOST=${KINDLE_HOST:-kindle}
SSH=(ssh -c chacha20-poly1305@openssh.com -o ConnectTimeout=10 "$HOST")
DEST_ROOT=${KINDLE_BACKUP_DIR:-$HOME/Backups/Kindle}
TEST=0; FORCE=0
for a in "$@"; do case $a in --test) TEST=1;; --force) FORCE=1;; *) echo "unknown option $a"; exit 2;; esac; done
MIN_FREE_MB=1500
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

"${SSH[@]}" true || { echo "Kindle not reachable over SSH ($HOST)"; exit 1; }
mkdir -p "$DEST_ROOT"
free_mb() { df -Pm "$DEST_ROOT" | awk 'NR==2{print $4}'; }

# --- model guard --------------------------------------------------------------
board=$("${SSH[@]}" "sed -n 's/.*_\([a-z]*_[a-z]*\)-[0-9]*\$/\1/p' /etc/version.txt | head -1")
if [ "$board" != "muscat_wario" ] && [ $FORCE = 0 ]; then
  echo "This model ($board) has not been tested with this script (tested: muscat_wario = PW3)."
  echo "It is read-only, but check the partition layout it prints first. Re-run with --force."; exit 3
fi

# --- partition layout: system area = everything before the largest (= user storage) partition
layout=$("${SSH[@]}" 'for p in /sys/block/mmcblk0/mmcblk0p*; do echo "$(basename $p) $(cat $p/start) $(cat $p/size)"; done')
echo "$layout" | awk '{printf "  %-10s start=%-9s size=%s MiB\n", $1, $2, int($3/2048)}'
read -r upart ustart <<<"$(echo "$layout" | sort -k3 -n | tail -1 | awk '{print $1, $2}')"
lastpart=$(echo "$layout" | sort -k2 -n | tail -1 | awk '{print $1}')
[ "$upart" = "$lastpart" ] || { echo "Unusual layout: largest partition ($upart) is not the last one ($lastpart). Stopping."; exit 4; }
[ $((ustart % 2048)) -eq 0 ] || { echo "User partition start not MiB-aligned ($ustart). Stopping."; exit 4; }
MIB=$((ustart / 2048))
log "system area: first $MIB MiB (everything before $upart, the user storage)"

if [ $TEST = 1 ]; then
  D=$(mktemp -d "${TMPDIR:-/tmp}/kindle-backup-test.XXXXXX")
else
  [ "$(free_mb)" -gt $((MIN_FREE_MB + MIB)) ] || { echo "Not enough free space on the PC: $(free_mb) MB"; exit 1; }
  D="$DEST_ROOT/$(date +%Y%m%d-%H%M%S)-full"
fi
mkdir -p "$D"/{image,files,info} && chmod 700 "$D"
log "destination: $D (free: $(free_mb) MB)"

# --- bit-exact dumps, hash computed on the Kindle --------------------------------
dump() { # $1=device $2=name $3=count in MiB (empty = whole device)
  local dev=$1 name=$2 cnt=${3:+count=$3}
  "${SSH[@]}" "sync; rm -f /tmp/kl.fifo /tmp/kl.sha; mkfifo /tmp/kl.fifo; (sha256sum < /tmp/kl.fifo | cut -d' ' -f1 > /tmp/kl.sha &); dd if=$dev bs=1M $cnt 2>/dev/null | tee /tmp/kl.fifo" \
    | zstd -T0 -12 -q -o "$D/image/$name.img.zst"
  sleep 1
  local kh ph
  kh=$("${SSH[@]}" 'cat /tmp/kl.sha; rm -f /tmp/kl.fifo /tmp/kl.sha')
  ph=$(zstd -dc "$D/image/$name.img.zst" | sha256sum | cut -d' ' -f1)
  [ -n "$kh" ] && [ "$kh" = "$ph" ] || { echo "HASH MISMATCH for $name: kindle=$kh pc=$ph"; exit 1; }
  echo "$ph  $name.img" >> "$D/image/SHA256SUMS"
  log "$name OK ($(du -h "$D/image/$name.img.zst" | cut -f1) compressed, sha256 ${ph:0:16}...)"
}

if [ $TEST = 1 ]; then
  dump /dev/mmcblk0boot1 mmcblk0boot1
  rm -rf "$D"; log "TEST OK: hash computed on the Kindle matches the PC copy. Nothing kept."
  exit 0
fi

"${SSH[@]}" 'cat /proc/partitions; echo; mount; echo; df -h; echo; cat /etc/version.txt; uname -a' > "$D/info/system.txt" 2>&1 || true
echo "$layout" > "$D/info/layout.txt"
for b in mmcblk0boot0 mmcblk0boot1; do "${SSH[@]}" "[ -e /dev/$b ]" && dump "/dev/$b" "$b"; done
dump /dev/mmcblk0 "mmcblk0-system-0-${MIB}MiB" "$MIB"

# --- user files (incremental snapshot) ----------------------------------------------
PREV=$(ls -d "$DEST_ROOT"/*/files "$DEST_ROOT"/*/arquivos 2>/dev/null | grep -v "^$D/" | sort | tail -1 || true)
log "files: rsync of /mnt/us (hardlink base: ${PREV:-none})"
rsync -rt --modify-window=1 --no-perms --no-owner --no-group \
  -e "ssh -c chacha20-poly1305@openssh.com" --rsync-path=/mnt/us/usbnet/bin/rsync \
  ${PREV:+--link-dest="$PREV"} "$HOST":/mnt/us/ "$D/files/"
(cd "$D/files" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$D/info/MANIFEST-files.sha256"
log "files OK: $(wc -l < "$D/info/MANIFEST-files.sha256") files"

cat > "$D/README.txt" <<EOF
Kindle full backup ($board) - $(date)
CONTAINS PERSONAL DATA (Amazon account tokens, Wi-Fi credentials, books). Do not share or upload.

image/mmcblk0-system-0-${MIB}MiB.img.zst : first $MIB MiB of the eMMC (MBR, bootloader/kernel area,
    rootfs, /var/local, ...). Mounted read-write partitions were copied live.
image/mmcblk0boot0/1.img.zst : eMMC hardware boot partitions.
image/SHA256SUMS : hashes of the UNCOMPRESSED data, computed on the Kindle while reading.
files/ : contents of /mnt/us. Manifest: info/MANIFEST-files.sha256

Inspect safely on the PC: zstd -d image/mmcblk0-system-*.img.zst
  then: udisksctl loop-setup -r -f mmcblk0-system-*.img   (-r = read-only)
Writing anything back to a Kindle is a recovery procedure: plan it, never improvise.
EOF
log "DONE. Size on disk: $(du -sh "$D" | cut -f1) | free on PC: $(free_mb) MB"
