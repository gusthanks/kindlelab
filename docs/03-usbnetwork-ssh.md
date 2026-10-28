# 03 · USBNetwork: SSH over the USB cable

> Tested on PW3, FW 5.16.2.1.1, USBNetwork 0.22.N r19297, dropbear 2020.81.
> For FW 5.16.3 and newer (hard-float) use [kindle-usbnetlite](https://github.com/notmarek/kindle-usbnetlite) instead.

## Install

1. Download `kindle-usbnet-0.22.N-r19297.tar.xz` (NiLuJe's snapshots: first post of
   [MobileRead t=225030](https://www.mobileread.com/forums/showthread.php?t=225030), direct link,
   no login). It contains `Update_usbnet_0.22.N_install_pw2_and_up.bin`.
2. Copy the `.bin` to `mrpackages/`, eject, unplug.
3. KUAL → **Helper** → **Install MR Packages** (or type `;log mrpi` in the home search bar).
   `extensions/MRInstaller/log/mrinstaller.log` should end with `usbnet:install::done` and `Success! :)`.

## Switch to network mode

**With the cable unplugged:** KUAL → **USBNetwork** → `* Toggle USBNetwork *`, then
`** USBNetwork Status **` to confirm it says USBNet. Only then plug the cable in. If you toggle
while the Kindle shows the USB-drive screen, it simply comes back as a drive.

The PC now sees `0525:a4a2 RNDIS/Ethernet Gadget` instead of `1949:0004`.

## PC side

```bash
scripts/usbnet-connect.sh      # finds the interface, sets 192.168.15.201/32 + route, pings
```

Defaults: Kindle `192.168.15.244`, PC `192.168.15.201`. Override them with the `KINDLE_IP` / `PC_IP`
environment variables or in `~/.config/kindlelab/usbnet.conf` (`KEY=value` lines). Two traps the script handles:

- **Subnet clash (PC side).** If your home router also uses `192.168.15.0/24` (many ISP routers do), a normal
  `/24` on the USB interface loses to the LAN route and you get *Destination Host Unreachable*
  from your LAN address. Use a `/32` plus a host route to `192.168.15.244`. This fixes only the PC side:
  the Kindle's own Wi-Fi still fails on that LAN. The script warns about it; see
  [the fix below](#kindle-wi-fi-fails-on-a-19216815x-lan-move-kindle_ip).
- **Interface renamed.** The interface name can change between plug-ins (`enp0s26u1u2i1` →
  `enp0s26u1u2`) and NetworkManager then auto-creates a "Wired connection N" with a link-local
  `169.254.x.x` address. Symptom: `No route to host` although the gadget is listed. Re-run the script.

## First login and keys

With Wi-Fi SSH off (the default `USE_WIFI="false"`), USBNetwork starts dropbear with `-n`:
**any password is accepted**. Use that once to install a key:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/kindle_ed25519 -C kindle
ssh root@192.168.15.244 'cat >> /mnt/us/usbnet/etc/authorized_keys; chmod 600 /mnt/us/usbnet/etc/authorized_keys' < ~/.ssh/kindle_ed25519.pub
```

An `~/.ssh/config` entry keeps it short:

```
Host kindle
    HostName 192.168.15.244
    User root
    IdentityFile ~/.ssh/kindle_ed25519
    UserKnownHostsFile ~/.ssh/known_hosts_kindle
    LogLevel ERROR
```

To log in non-interactively before a key exists, feed any password through `SSH_ASKPASS`
(`SSH_ASKPASS_REQUIRE=force`). Throughput over the cable: about 6.7 MB/s with
`-c chacha20-poly1305@openssh.com`, 4.2 MB/s with `aes128-ctr`.

## Kindle Wi-Fi fails on a 192.168.15.x LAN: move KINDLE_IP

**Symptom:** with USBNetwork on, the Kindle shows *Error connecting to Wi-Fi* on a LAN that uses
`192.168.15.0/24`. The password is right, and the same Kindle joins other networks.

**Cause.** The Kindle's logs on PW3 5.16.2.1.1 show that the association, the password and DHCP all
succeed (`spectator:conn-assoc-done`, `conn-ip-ok`). Then the connectivity check cannot reach the LAN's
DNS (`dns-nw-fail`, `netm:route-setup-fail:reason=dns-failure:checkNetwork failed`).

USBNetwork runs `ifconfig usb0 $KINDLE_IP` without a netmask. So `usb0` gets the classful `/24` and
the route `192.168.15.0/24 dev usb0`, which takes priority over the same route on `wlan0`. Packets for
the router and its DNS therefore go down the USB cable. To confirm, run `ip route get 192.168.15.1`
on the Kindle: it answers `dev usb0`.

**Quick workaround:** turn USBNetwork off before joining that Wi-Fi.

**Permanent fix:** give USBNetwork a `/24` that nobody uses. Stay inside `192.168.x.x`, because a
`10.x` address gets a classful `/8` and a `172.16–31.x` address gets a `/16`. We use
`192.168.244.244`. This sequence keeps the SSH session alive:

```bash
# Kindle: back up, change the config (it takes effect at the next USBNetwork start), add the new address live
ssh kindle 'cp -p /mnt/us/usbnet/etc/config /mnt/us/usbnet/etc/config.bak &&
  sed -i "s/^KINDLE_IP=.*/KINDLE_IP=192.168.244.244/" /mnt/us/usbnet/etc/config &&
  ip addr add 192.168.244.244/24 dev usb0'
# PC: switch to the new pair (usbnet-connect.sh reads this file)
mkdir -p ~/.config/kindlelab
printf 'KINDLE_IP=192.168.244.244\nPC_IP=192.168.244.201/32\n' > ~/.config/kindlelab/usbnet.conf
scripts/usbnet-connect.sh
# PC: set "HostName 192.168.244.244" in ~/.ssh/config. The host key does not change; compare fingerprints
ssh-keyscan -t ed25519 192.168.244.244 | ssh-keygen -lf -
# Kindle: only now remove the old address
ssh kindle 'ip addr del 192.168.15.244/24 dev usb0 && ip route'
```

The order matters. The PC must already talk *from* its new address before you remove the old one on
the Kindle. Otherwise the Kindle cannot answer and the session drops. It happened to us, and
`ssh -b 192.168.244.201 kindle` got us back in. `usbnet-connect.sh` prints a warning when your LAN
contains `KINDLE_IP`.

## SSH over Wi-Fi (not done yet: read before enabling)

What we learned from `/mnt/us/usbnet/bin/usbnetwork` (0.22.N):

- `USE_WIFI="true"` removes `-n` (passwords are checked) and adds
  `iptables -A INPUT -i wlan0 -p tcp --dport ssh -j ACCEPT` on start.
- The script sources `/mnt/us/usbnet/etc/config` **after** setting `SSH_DAEMON_OPTS`, so a line
  `SSH_DAEMON_OPTS="${SSH_DAEMON_OPTS} -s"` in the config disables password logins (dropbear `-s`).
  Do this: the root password of a Kindle can be derived from its serial number.
- `USE_WIFI_SSHD_ONLY="true"`: toggling only starts/stops the SSH server and USB stays a normal
  drive. Change it only after toggling the current USBNet session off.
- Boot autostart: rename `/mnt/us/usbnet/DISABLED_auto` to `auto`, only with a tested config.
- The PC and the Kindle must share a network. Wi-Fi turns off while the Kindle sleeps.
  The PW3 radio is 2.4 GHz only, so a 5 GHz-only network will not work.
- Tailscale on a Kindle exists ([jadehawk/koreader-tailscale](https://github.com/jadehawk/koreader-tailscale),
  tested on PW5/PW6; [Tailscale blog](https://tailscale.com/blog/jailbroken-kindle-proxy-tun-modes)).
  Our PW3 has no `/dev/net/tun` and a 3.0.35 kernel: untested here.
