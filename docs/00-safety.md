# 00 · Safety first

Rules we followed on every step. They exist because each one has a way to brick, wipe or
silently update a jailbroken Kindle.

1. **Back up before any write.** At minimum copy every USB-visible file
   (`rsync -rt` + a SHA-256 manifest). Once SSH works, run `scripts/full-backup.sh`.
2. **One change at a time, verified on the device.** Hash on the PC, hash again on the Kindle
   (`sha256sum -c`), compare. "The copy finished" is not verification.
3. **Airplane mode stays on until the OTA block is verified.** WinterBreak's `jb.sh` restores the
   OTA binaries so the hotfix can apply, so auto-update is live again after jailbreaking until
   *Rename OTA binaries* runs. Free space plus Wi-Fi means an update can download.
4. **Never factory-reset, deregister, "unjailbreak" or update the firmware to fix a component.**
   Deregistering also wipes `documents/` (the KUAL launcher lives there). If an update or reset is
   ever truly needed, first restore the OTA binaries (KUAL → *Rename OTA binaries* → *Restore*)
   and have a written plan.
5. **Only official packages**, from the links in the guides, checked against published hashes
   when they exist. Record the hash of everything you install.
6. **Edit KOReader settings only while KOReader is closed.** It rewrites them on exit.
7. **SSH over Wi-Fi only with keys.** USBNetwork's default (Wi-Fi off) starts dropbear with `-n`:
   *any* password works. That is acceptable over a USB cable, never over Wi-Fi.
8. **One agent or person writes to the device at a time.**
9. **No DRM removal and no piracy sources.** Some plugins open Amazon purchases in KOReader by
   extracting the DRM keys. They are deliberately not covered here; circumventing technical
   protection is unlawful in many countries (e.g. Brazil, Lei 9.610/98 art. 107).
10. **Privacy.** Logs and backups contain the serial number, MAC addresses, Wi-Fi names, account
    tokens and your library. Redact before sharing; keep images local.
