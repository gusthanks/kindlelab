#!/usr/bin/env bash
# Read-only health panel for a jailbroken Kindle reachable over SSH.
# Shows: firmware/model, OTA (auto-update) block, hotfix, battery, Wi-Fi, clock, uptime,
# free space, KOReader, and how the USBNetwork SSH server is configured.
#
# Usage: kindle-status.sh [-v]      (-v also prints the Wi-Fi network name)
# Env:   KINDLE_HOST (ssh host/alias, default "kindle")
set -uo pipefail
HOST=${KINDLE_HOST:-kindle}
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1

if ! ssh -o ConnectTimeout=6 -o BatchMode=yes "$HOST" true 2>/dev/null; then
  echo "Kindle not reachable over SSH ($HOST)."
  found=0
  for d in /sys/bus/usb/devices/*; do
    [ -f "$d/idVendor" ] || continue
    case "$(cat "$d/idVendor"):$(cat "$d/idProduct")" in
      1949:*)    echo "  USB: USB-DRIVE mode. For SSH, toggle USBNetwork in KUAL with the cable unplugged."; found=1;;
      0525:a4a2) echo "  USB: NETWORK mode (USBNetwork). Run usbnet-connect.sh on the PC."; found=1;;
    esac
  done
  [ $found = 0 ] && echo "  No Kindle on USB (unplugged, charge-only cable, or asleep)."
  exit 1
fi

ssh "$HOST" "PC_EPOCH=$(date +%s) PC_TIME='$(date '+%H:%M %z')' VERBOSE=$VERBOSE sh -s" <<'EOF'
p() { printf '%-18s %s\n' "$1" "$2"; }
fw=$(sed 's/ *(~~.*//' /etc/prettyversion.txt 2>/dev/null | head -1)
board=$(sed -n 's/.*_\([a-z]*_[a-z]*\)-[0-9]*$/\1/p' /etc/version.txt 2>/dev/null | head -1)
p "Firmware:" "${fw:-?} (${board:-?})"
if [ -e /usr/bin/otaupd ] || [ -e /usr/bin/otav3 ]; then p "OTA updates:" "WARNING: ENABLED - the Kindle may update itself (turn on airplane mode!)"
elif [ -e /usr/bin/otaupd.bck ]; then p "OTA updates:" "blocked (otaupd.bck / otav3.bck)"
else p "OTA updates:" "unknown"; fi
hf=$(grep -a -o 'v[0-9]\.[0-9][0-9.]*' "/mnt/us/documents/Run Hotfix.run_hotfix" 2>/dev/null | head -1)
p "Hotfix:" "${hf:-?}"
p "Battery:" "$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null)% (charging: $(lipc-get-prop com.lab126.powerd isCharging 2>/dev/null))"
ws=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)
ssid=$(wpa_cli -i wlan0 status 2>/dev/null | sed -n 's/^ssid=//p')
wip=$(wpa_cli -i wlan0 status 2>/dev/null | sed -n 's/^ip_address=//p')
[ "$VERBOSE" = 1 ] && net=" network \"$ssid\"" || net=""
p "Wi-Fi:" "${ws:-?}${net}${wip:+, IP $wip}"
drift=$(( ($(date +%s) - PC_EPOCH) / 60 ))
p "Clock:" "Kindle $(date '+%H:%M %z') vs PC $PC_TIME (internal clock off by ${drift} min)"
p "Uptime:" "$(uptime | sed 's/.*up *//; s/, *[0-9]* users*.*//; s/,  load.*//')"
p "Free space:" "$(df -h /mnt/us | awk 'NR==2{print $4" of "$2" (user storage)"}'), $(df -h /var/local | awk 'NR==2{print $4" in /var/local"}')"
p "KOReader:" "$(ps | grep -q '[r]eader.lua' && echo running || echo 'not running') ($(cat /mnt/us/koreader/git-rev 2>/dev/null || echo 'not installed'))"
c=/mnt/us/usbnet/etc/config
if [ -f "$c" ]; then
  uw=$(sed -n 's/^USE_WIFI="\(.*\)"/\1/p' $c); so=$(sed -n 's/^USE_WIFI_SSHD_ONLY="\(.*\)"/\1/p' $c)
  args=$(for x in $(pidof dropbear); do tr '\0' ' ' < /proc/$x/cmdline; echo; done | sort -u | head -1)
  case "$args" in *" -n"*) pw="ANY password accepted (fine over USB only)";; *" -s"*) pw="keys only";; *) pw="passwords checked";; esac
  p "SSH (USBNetwork):" "USE_WIFI=$uw, SSHD_ONLY=$so, $pw, autostart=$([ -e /mnt/us/usbnet/auto ] && echo yes || echo no)"
fi
EOF
