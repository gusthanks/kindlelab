# 01 · Diagnose an existing jailbreak (read-only)

Our device had been jailbroken a year earlier and "never finished". Before touching anything we
reconstructed what had happened **from a copy of the USB-visible files**, without running any
script from the device.

## 1. Find the device

`lsusb` is not always installed; sysfs is enough:

```bash
for d in /sys/bus/usb/devices/*; do [ -f $d/idVendor ] && echo "$(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/product 2>/dev/null)"; done
```

- `1949:0004 Amazon Kindle` = USB-drive mode. `0525:a4a2 RNDIS/Ethernet Gadget` = USBNetwork mode.
- Charging but nothing listed = **charge-only cable**. It happened to us; another cable fixed it.

## 2. Copy and fingerprint

```bash
TS=$(date +%Y%m%d-%H%M%S); mkdir -p ~/Backups/Kindle/$TS
rsync -rt /run/media/$USER/Kindle/ ~/Backups/Kindle/$TS/files/      # mount point may be KINDLE
(cd ~/Backups/Kindle/$TS/files && find . -type f -print0 | sort -z | xargs -0 sha256sum) > ~/Backups/Kindle/$TS/MANIFEST.sha256
```

## 3. Read the evidence

| File (on the USB storage) | Tells you |
|---|---|
| `winterbreak.log` | Each WinterBreak run; look for `Finished installing jailbreak!` |
| `documents/Run Hotfix.run_hotfix` | Universal Hotfix version (e.g. `v2.3.2`) |
| `documents/KPPMainAppV2_*crash*.txt` | Right after a hotfix run these are **the hotfix restarting the GUI** (`Hotfix Complete! Restarting GUI`, processes get signal 15), not failures |
| `extensions/MRInstaller/log/mrinstaller.log` | MRPI package installs; e.g. `Not enough space left to process ...` |
| `system/version.txt` | Firmware build |
| `mrpackages/` | Packages that were queued but never installed |

What we found: jailbreak and hotfix were fine. KUAL had never been installed because **MRPI
refuses to work with less than 150 MB free** (`enough_free_space()` in `mrinstaller.sh`), and the
storage had been filled on purpose (the "fill the device" step that prevents auto-updates). The
current guide asks for **220 MB free with airplane mode ON**.

When you print logs anywhere, redact 16-character serial numbers and MAC addresses.
