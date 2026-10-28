# Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Kindle charges but the PC sees nothing | Charge-only USB cable | Try another cable (it happened to us) |
| Kindle shows up as a drive after toggling USBNetwork | Toggled while plugged in / USB-drive screen shown | Unplug, toggle in KUAL, check `** USBNetwork Status **`, plug in |
| `ssh: ... No route to host` while `0525:a4a2` is listed | USB interface renamed; NetworkManager put a link-local profile on it | `scripts/usbnet-connect.sh` |
| `Destination Host Unreachable` from your LAN address | Home LAN is also `192.168.15.0/24` | `/32` + host route (the script does it) |
| MRPI says *Not enough space left to process ...* | Under 150 MB free (storage filled on purpose against updates) | Free space to 220 MB+ **with airplane mode on** |
| `KPPMainAppV2_*crash*.txt` files after running the hotfix | The hotfix restarting the GUI (signal 15) | Nothing to fix; check for `Hotfix Complete!` |
| KUAL entry does nothing / script won't run | Kindle is in USB-drive mode | Unplug first |
| KOReader cannot open a book from Send to Kindle or the store | `.kfx` (and DRM) is not supported by KOReader | Read it in the stock reader |
| KOReader changes are lost | Settings edited while KOReader was running | Close KOReader, edit, verify, relaunch |
| OPDS download lands in a strange folder | `download_dir` unset: KOReader uses the last folder visited | Set `download_dir` ([04](04-koreader.md)) |
| Clock one hour ahead in KOReader only | Outdated time-zone data in `/var/local/system/tz` | See [04](04-koreader.md#known-issue-clock-one-hour-ahead-in-koreader) |
| Kindle does not join a Wi-Fi network ("Error connecting to Wi-Fi") | Kindles released before 2021 support neither 5 GHz nor WPA3 ([Amazon](https://www.amazon.com/gp/help/customer/display.html?nodeId=G5HYWUVWRXFSCH7E)); WPA2/WPA3 mixed mode with PMF required, MAC filtering or "ax only" modes can also block a PW3; or simply a wrong/old saved password | Read the reason in the Kindle's own log: `ssh kindle 'showlog \| grep -iE "wpa\|wifid\|assoc\|handshake\|reason" \| tail -60'`. A failed 4-way handshake points to the password; an association reject points to the security mode. Use a 2.4 GHz network with WPA2-PSK (AES) |
| SSH over Wi-Fi does not answer | Not enabled, different network, or the Kindle is asleep (Wi-Fi off) | [03](03-usbnetwork-ssh.md#ssh-over-wi-fi-not-done-yet-read-before-enabling) |
