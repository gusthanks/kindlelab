#!/usr/bin/env bash
# Find the Kindle on the Wi-Fi LAN by its Wi-Fi MAC address and print its IP address.
# The Kindle's firewall ignores ping, but it still answers ARP, so a quick ping sweep fills
# the PC's neighbour table. Changes nothing on the Kindle or in the PC's configuration.
#
# Usage: kindle-find-wifi.sh
# Needs KINDLE_WIFI_MAC (environment, or a "KINDLE_WIFI_MAC=<the MAC>" line in
# ~/.config/kindlelab/usbnet.conf). Read it once over SSH: cat /sys/class/net/wlan0/address
# Keep the MAC out of the repository.
set -euo pipefail
CONF=${KINDLELAB_USBNET_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/kindlelab/usbnet.conf}
MAC=${KINDLE_WIFI_MAC:-}
if [ -z "$MAC" ] && [ -f "$CONF" ]; then
  MAC=$(sed -n 's/^KINDLE_WIFI_MAC=\([0-9A-Fa-f:]\{17\}\)$/\1/p' "$CONF" | tail -1)
fi
if [ -z "$MAC" ]; then
  echo "Set KINDLE_WIFI_MAC in $CONF (on the Kindle: cat /sys/class/net/wlan0/address)" >&2
  exit 2
fi
MAC=$(printf '%s' "$MAC" | tr 'A-F' 'a-f')

lookup() {
  ip -4 neigh show | awk -v m="lladdr $MAC" 'index($0, m) && $NF != "FAILED" {print $1; exit}'
}

ip=$(lookup || true)
if [ -z "$ip" ]; then
  # Sweep the /24 of the PC's LAN address (the address on the default route's interface).
  dev=$(ip -4 route show default 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "dev") {print $(i + 1); exit}}')
  src=$( [ -n "$dev" ] && ip -4 -o addr show dev "$dev" | awk '{split($4, a, "/"); print a[1]; exit}')
  if [ -z "$src" ]; then
    echo "This PC has no LAN address." >&2
    exit 1
  fi
  net=${src%.*}
  echo "Not in the neighbour table yet; sweeping $net.0/24 ..." >&2
  for i in $(seq 1 254); do ping -c1 -W1 "$net.$i" >/dev/null 2>&1 & done
  wait
  ip=$(lookup || true)
fi
if [ -z "$ip" ]; then
  echo "Kindle not found on this LAN. Is it awake, with Wi-Fi on, on the same network?" >&2
  exit 1
fi
echo "$ip"
if timeout 3 bash -c "</dev/tcp/$ip/22" 2>/dev/null; then
  echo "SSH answers on $ip. If ~/.ssh/config has another HostName for the Wi-Fi alias, update it." >&2
else
  echo "Found $ip, but SSH does not answer there (USBNetwork off, or SSH over Wi-Fi not enabled)." >&2
fi
