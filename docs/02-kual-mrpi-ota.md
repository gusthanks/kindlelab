# 02 · KUAL, MRPI and the OTA block

> Tested on PW3, FW 5.16.2.1.1, jailbroken with WinterBreak 1.7.0 + Universal Hotfix 2.3.2.
> Official guide: <https://kindlemodding.org/jailbreaking/Legacy/post-jailbreak/installing-kual-mrpi/>

The newer "hdnext" jailbreak stack ships a package manager (KPM) and calls KUAL obsolete. On this
firmware the KUAL + MRPI route worked, and KPM has two reported failures on the same model and
firmware ([WinterBreak#63](https://github.com/KindleModding/WinterBreak/issues/63),
[Winterbreak2#5](https://github.com/KindleModding/Winterbreak2/issues/5)), so we used KUAL + MRPI.

## Install (USB-drive mode, airplane mode ON)

| Package | Source | Goes to |
|---|---|---|
| KUAL via PEKI | <https://github.com/KindleTweaks/PEKI/releases/latest/download/PEKI.zip> | `documents/KUAL.sh` + `documents/KUAL.jar` |
| MRPI (khf) | `kual-mrinstaller-khf.zip` from the guide above | `extensions/MRInstaller/` + empty `mrpackages/` |
| renameotabin | <https://kindlemodding.org/jailbreaking/Legacy/post-jailbreak/renameotabin.zip> | `extensions/renameotabin/` |

The khf MRPI zip includes PW2-class soft-float binaries and works on FW below 5.16.3.

## On the Kindle (cable unplugged)

1. Open **KUAL** from the library. If it opens, the jailbreak is alive (and `extensions/KUAL.cfg`
   appears). If it does not, run **Run Hotfix** from the library and try again.
2. KUAL → **Rename OTA binaries** → **Rename**. The device restarts.

Scripts on the storage **cannot run while the Kindle shows the USB-drive screen**: always unplug
before tapping.

## Verify the block

As soon as SSH works ([docs/03](03-usbnetwork-ssh.md)), `scripts/kindle-status.sh` prints
`OTA updates: blocked (otaupd.bck / otav3.bck)`. By hand:

```bash
ssh kindle 'ls /usr/bin | grep -i ota'    # expect only otaupd.bck and otav3.bck
```

Without SSH, the *Check OTA Status* scriptlet from <https://scriptlets.notmarek.com/> does the same.
Only then turn Wi-Fi on. Send to Kindle kept working afterwards (documents arrive as `.kfx`).
