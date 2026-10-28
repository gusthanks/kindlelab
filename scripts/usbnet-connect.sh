#!/usr/bin/env bash
# PC side of USBNetwork: find the Kindle's USB network interface, give the PC an address
# plus a host route to the Kindle (NetworkManager/nmcli, no sudo needed), then ping it.
# Changes nothing on the Kindle.
#
# Usage: usbnet-connect.sh [wait_seconds]
# Env:   KINDLE_IP (default 192.168.15.244)  PC_IP (default 192.168.15.201/32)
#        NM_CONNECTION (default kindle-usbnet)
# Per-machine overrides (KEY=value lines, env wins): ~/.config/kindlelab/usbnet.conf
set -euo pipefail
CONF=${KINDLELAB_USBNET_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/kindlelab/usbnet.conf}
if [ -f "$CONF" ]; then
  while IFS='=' read -r k v; do
    [ -z "${!k:-}" ] && printf -v "$k" '%s' "$v"
  done < <(grep -E '^(KINDLE_IP|PC_IP|NM_CONNECTION)=[0-9A-Za-z./_-]+$' "$CONF")
fi
KINDLE_IP=${KINDLE_IP:-192.168.15.244}
# /32 + host route instead of a /24: if your home LAN is also 192.168.15.0/24 (common on
# some ISP routers), a /24 here loses to the LAN route and the Kindle becomes unreachable.
PC_IP=${PC_IP:-192.168.15.201/32}
CON=${NM_CONNECTION:-kindle-usbnet}
WAIT=${1:-120}

warn_subnet_clash() {
  # The Kindle's own side has no such trick: USBNetwork gives usb0 a classful /24, so if the
  # PC's LAN is that same /24, the Kindle sends traffic for the LAN (router, DNS) down the USB
  # cable and its Wi-Fi fails on that LAN ("Error connecting to Wi-Fi") while USBNetwork is on.
  local ifname=$1 lan
  lan=$(ip -4 route show match "$KINDLE_IP" 2>/dev/null | grep -v '^default' | grep -v " dev $ifname " \
        | awk '$1 ~ /\// && $1 !~ /\/32$/ {print $1" (dev "$3")"; exit}') || true   # no match = no clash
  [ -z "$lan" ] && return 0
  echo "WARNING: this PC's LAN $lan contains KINDLE_IP $KINDLE_IP."
  echo "  The Kindle's Wi-Fi will fail on this LAN while USBNetwork is on. Fix: move KINDLE_IP to an unused"
  echo "  subnet in /mnt/us/usbnet/etc/config (e.g. 192.168.244.244) and set KINDLE_IP / PC_IP in $CONF"
  echo "  (see docs/troubleshooting.md)."
}

if ! command -v nmcli >/dev/null; then
  echo "nmcli (NetworkManager) not found. Configure the interface by hand, as root:"
  echo "  ip addr add ${PC_IP} dev <iface> && ip link set <iface> up && ip route add ${KINDLE_IP}/32 dev <iface>"
  exit 2
fi

find_if() {
  # Network interface whose USB parent is the Kindle: Amazon (1949:*) or, in USBNetwork
  # mode, the Linux USB Ethernet/RNDIS gadget (0525:a4a2).
  for n in /sys/class/net/*; do
    d=$(readlink -f "$n/device" 2>/dev/null) || continue
    while [ "$d" != "/" ] && [ -n "$d" ]; do
      if [ -f "$d/idVendor" ]; then
        v=$(cat "$d/idVendor"); p=$(cat "$d/idProduct")
        { [ "$v" = 1949 ] || [ "$v:$p" = 0525:a4a2 ]; } && { basename "$n"; return 0; }
        break
      fi
      d=$(dirname "$d")
    done
  done
  return 1
}

echo "Waiting for the Kindle's USB network interface (up to ${WAIT}s)..."
IF=""
for _ in $(seq "$WAIT"); do IF=$(find_if || true); [ -n "$IF" ] && break; sleep 1; done
if [ -z "$IF" ]; then
  echo "No interface. Is USBNetwork on (toggle it in KUAL with the cable UNPLUGGED) and the cable connected?"
  exit 1
fi
echo "Interface: $IF"
warn_subnet_clash "$IF"

# The interface name can change between enumerations (e.g. enp0s26u1u2i1 vs enp0s26u1u2) and
# NetworkManager then auto-creates a useless "Wired connection N" on it: re-bind ours every time.
if nmcli -t -f NAME con show | grep -qx "$CON"; then
  nmcli con modify "$CON" connection.interface-name "$IF" ipv4.addresses "$PC_IP" ipv4.routes "$KINDLE_IP/32" >/dev/null
else
  nmcli con add type ethernet con-name "$CON" ifname "$IF" \
    ipv4.method manual ipv4.addresses "$PC_IP" ipv4.routes "$KINDLE_IP/32" ipv4.never-default yes \
    ipv6.method disabled connection.autoconnect yes >/dev/null
fi
nmcli con up "$CON" >/dev/null
echo "PC configured as $PC_IP. Pinging $KINDLE_IP..."
ping -c 3 -W 2 "$KINDLE_IP" && echo "OK: the Kindle answers. Log in with: ssh root@$KINDLE_IP (or your ssh alias)"
