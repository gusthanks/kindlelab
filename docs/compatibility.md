# Compatibility

KindleLab has been run on **one** device. This table keeps three levels apart so nobody mistakes a
guess for a test:

- ✅ **Tested here:** Kindle Paperwhite 3 (7th gen, `muscat_wario`), FW **5.16.2.1.1**, ad-free,
  WinterBreak 1.7.0 + Universal Hotfix 2.3.2.
- 📚 **Community-reported:** someone else documented it (link). We did not verify it.
- ❓ **Untested:** nobody has reported yet. Your [test report](../../../issues/new/choose) helps.

| Step / tool | PW3 · 5.16.2.1.1 | Other models / firmware |
|---|---|---|
| WinterBreak + Universal Hotfix | ✅ (logs checked, see [01](01-diagnose.md)) | 📚 [kindlemodding.org](https://kindlemodding.org/jailbreaking/) lists the method per firmware |
| KUAL (PEKI) + MRPI khf | ✅ | 📚 khf MRPI: FW below 5.16.3 ([guide](https://kindlemodding.org/jailbreaking/Legacy/post-jailbreak/installing-kual-mrpi/)) |
| OTA block (renameotabin) + check | ✅ verified over SSH | 📚 [guide](https://kindlemodding.org/jailbreaking/Legacy/post-jailbreak/disable-ota.html) for FW ≥ 5.11 |
| USBNetwork 0.22.N + SSH with keys | ✅ | 📚 FW ≥ 5.16.3: [kindle-usbnetlite](https://github.com/notmarek/kindle-usbnetlite) |
| `usbnet-connect.sh` (NetworkManager) | ✅ Arch-based Linux | ❓ other distros; manual `ip` commands printed without nmcli |
| Kindle Wi-Fi on a `192.168.15.x` LAN while USBNetwork is on (after [moving `KINDLE_IP`](03-usbnetwork-ssh.md#kindle-wi-fi-fails-on-a-19216815x-lan-move-kindle_ip)) | ✅ failed before, connects after | ❓ |
| SSH over Wi-Fi, keys only (`USE_WIFI` + dropbear `-s`, [03](03-usbnetwork-ssh.md#ssh-over-wi-fi-keys-only)) | ✅ key works over Wi-Fi and cable, passwords refused; boot autostart enabled, reboot not yet tested | ❓ |
| KOReader 2026.07.1 (`kindlepw2`) via SSH | ✅ | 📚 [KOReader wiki](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices): `kindlehf` on FW ≥ 5.16.3 |
| KOReader via KPM (`;kpm install koreader`) | not tried | 📚 reported failing on PW3 5.16.2.1.1: [WinterBreak#63](https://github.com/KindleModding/WinterBreak/issues/63), [Winterbreak2#5](https://github.com/KindleModding/Winterbreak2/issues/5) |
| SimpleUI 3.0.1 | ✅ | 📚 needs KOReader ≥ 2026.03 ([README](https://github.com/doctorhetfield-cmd/simpleui.koplugin)) |
| Home-screen tile (`KOReader.sh`) | ✅ | 📚 needs scriptlet support ([format](https://kindlemodding.org/kindle-dev/scriptlets.html)) |
| Amazon books in KOReader (`2-kindlelab-store-books.lua`) | ✅ listed with covers; a KFX opened in the stock reader (the path must be percent-encoded) | ❓ relies on the stock catalog `cc.db` and `com.lab126.booklet.reader` |
| Tidy library (`2-kindlelab-library.lua`) and sleep screen (`2-kindlelab-sleepscreen.lua`) | ✅ | ❓ |
| KindleLab plugin: type tags, first-opening profiles, comic toggle, icon switcher | ✅ on-device test with book copies; menu actions run through their own functions; icon swap tested on a copy of the launcher | ❓ |
| `kindle-new-books.py` + systemd user timer | ✅ Arch-based Linux | ❓ other distros (needs Python 3, poppler for PDFs) |
| *Where am I?* page (`checker/`) | ✅ legacy-path results checked against two real states of our PW3 (stuck at KUAL, and finished); page tested in Chrome | ❓ modern-path signs (`documents/JAILBROKEN.txt`, `jb.sh.log`) come from KindleModding's `jb.sh` source, not from a device; MTP Kindles: choose a copy of the drive; Firefox/Safari use the classic folder dialog |
| Offline add-on installer (`installer/`) | ✅ install/reinstall/undo on Linux with copies of real PW3 settings; payload hashes and Lua tests verified in an isolated folder on the PW3, without replacing the active setup | ❓ other Kindle models; desktop filesystem tests run in the Installer workflow (Windows/macOS/Linux). Python 3.11+ and a mounted USB drive required; MTP unsupported. This is not a jailbreak or KOReader installer. |
| `kindle-status.sh`, `kindle-screenshot.sh` | ✅ | ❓ need USBNetwork tools (`fbgrab`, `lipc-*`) |
| `full-backup.sh` | ✅ | ❓ refuses unknown layouts, `--force` on untested models |
| `pull-highlights.py` | ✅ clippings in PT, EN, FR | ❓ ES / DE / IT keywords included, untested |
| Android (CrackDroid) | ❌ not tried, not recommended ([06](06-android-and-custom-os.md)) | 📚 PW2, PW3, KV, KT2, KT3, KOA1 ([guide](https://github.com/Ooonana/Guide-to-installing-android-on-kindle)) |

Hardware notes for the PW3: no Bluetooth and no audio (audio/Bluetooth homebrew does not apply),
2.4 GHz Wi-Fi only, soft-float userland on 5.16.2.x (hard-float-only homebrew does not run).
