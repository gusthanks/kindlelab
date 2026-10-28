#!/usr/bin/env bash
# Screenshot of the Kindle's screen (fbgrab ships with USBNetwork). Read-only.
# Usage: kindle-screenshot.sh [name]   -> prints the path of the PNG
# Env:   KINDLE_HOST (default "kindle"), KINDLE_SCREENSHOT_DIR (default ~/KindleLab/screenshots)
# Screenshots can show your library/books: they are personal, keep them out of git.
set -euo pipefail
HOST=${KINDLE_HOST:-kindle}
DIR=${KINDLE_SCREENSHOT_DIR:-$HOME/KindleLab/screenshots}
mkdir -p "$DIR"
OUT="$DIR/${1:-screen}-$(date +%Y%m%d-%H%M%S).png"
ssh "$HOST" '/mnt/us/usbnet/bin/fbgrab /tmp/kl-screen.png >/dev/null 2>&1 && cat /tmp/kl-screen.png; rm -f /tmp/kl-screen.png' > "$OUT"
if ! file "$OUT" | grep -q 'PNG image'; then
  rm -f "$OUT"; echo "Failed (Kindle reachable? USBNetwork installed?)" >&2; exit 1
fi
echo "$OUT"
