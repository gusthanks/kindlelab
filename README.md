# KindleLab

Verified notes and small, careful scripts for living with a **jailbroken Kindle** from a Linux PC:
SSH over USB and Wi-Fi (keys only), auto-update (OTA) blocking, KOReader with a simple home screen, full backups,
and highlight export to Markdown.

> **Tested on exactly one device:** Kindle Paperwhite 3 (7th gen, `muscat_wario`), firmware
> **5.16.2.1.1**. Everything else is either *community-reported* (with a link) or *untested*.
> Check [docs/compatibility.md](docs/compatibility.md) before following anything on another model.

## Resumo em português

O KindleLab reúne o que aprendemos personalizando um Kindle Paperwhite 3 desbloqueado (firmware
5.16.2.1.1), com scripts para Linux que **conferem tudo por hash** e **nunca mudam nada no Kindle
sem você mandar**:

- **Acesso direto por SSH pelo cabo USB** (USBNetwork), inclusive a armadilha do roteador que usa a
  mesma faixa de IP `192.168.15.x`, que também impede o Wi-Fi do Kindle de conectar, e como resolver.
- **Acesso pelo Wi-Fi só com chave**: nenhuma senha funciona, e o cabo continua como plano B.
- **Bloqueio de atualização automática** (OTA) e como confirmar que ele está ativo.
- **KOReader** com tela inicial simples (SimpleUI), dicionário em português, catálogos de livros
  gratuitos, notícias e um atalho de um toque na tela inicial do Kindle.
- **Backup completo** (cópia bit a bit do sistema, conferida pelo próprio Kindle) e **exportação de
  destaques** para Markdown.
- Avaliação honesta de **Android e "sistemas novos"** para o Kindle.

Só testamos em **um** aparelho. A tabela de [compatibilidade](docs/compatibility.md) separa o que
foi testado do que foi relatado pela comunidade. Tem outro modelo? Abra um
[relato de teste](../../issues/new/choose): é assim que a tabela cresce.

## What's here

| Path | What it is |
|---|---|
| [`docs/`](docs/) | Step-by-step guides, in the order we did them, plus troubleshooting and compatibility |
| [`scripts/`](scripts/) | PC-side tools (bash/python). All read-only on the Kindle unless stated |
| [`koreader-config/`](koreader-config/) | OPDS catalog and news-feed templates for KOReader |
| [`kindle-files/`](kindle-files/) | Small files to copy to the Kindle (e.g. the one-tap KOReader tile) |

### Scripts

| Script | Purpose | Writes to the Kindle? |
|---|---|---|
| `usbnet-connect.sh` | Configure the PC side of USBNetwork (NetworkManager), handle subnet clashes | no |
| `kindle-find-wifi.sh` | Find the Kindle's Wi-Fi address on your LAN by its MAC (for SSH over Wi-Fi) | no |
| `kindle-status.sh` | Health panel: firmware, OTA block, hotfix, battery, Wi-Fi, clock, space, SSH mode | no |
| `kindle-screenshot.sh` | Screenshot of the e-ink screen (via `fbgrab`) | `/tmp` only |
| `full-backup.sh` | Bit-exact image of the system area + boot partitions, hash-checked on the device, plus incremental file copy | no |
| `pull-highlights.py` | `My Clippings.txt` (stock reader) + KOReader exports → one Markdown file per book | no |
| `build-koreader-config.py` | Build a KOReader config (language, dictionary, OPDS, news, plugins) as a staging tree + manifest | no (you push it) |
| `check-privacy.sh` | Pre-commit hook that blocks serials, MACs, IPs, e-mails, home paths and your own denylist | — |

## Start here

1. [docs/00-safety.md](docs/00-safety.md): the rules that keep the device alive.
2. Already jailbroken but unsure what state it is in? [docs/01-diagnose.md](docs/01-diagnose.md).
3. Then, in order: [KUAL, MRPI and OTA block](docs/02-kual-mrpi-ota.md) →
   [USBNetwork / SSH](docs/03-usbnetwork-ssh.md) → [KOReader](docs/04-koreader.md) →
   [full backup](docs/05-full-backup.md).
4. Curious about Android or a "new OS"? [docs/06-android-and-custom-os.md](docs/06-android-and-custom-os.md).
5. Something odd? [docs/troubleshooting.md](docs/troubleshooting.md).

**This repo does not explain how to jailbreak.** Follow the official guides at
[kindlemodding.org](https://kindlemodding.org/): they are maintained for every model and firmware.

## Ground rules

- Back up first. One change at a time. Verify every copy with SHA-256 **on the device**.
- Keep airplane mode on until the OTA block is verified.
- Never factory-reset, deregister or update firmware "to fix something".
- **No DRM removal, no piracy sources.** Purchased books stay in the stock reader.

## Contributing

Test reports from other models and firmwares are the most valuable contribution:
use the *Test report* issue form. Please remove serial numbers, MAC addresses, Wi-Fi names and
e-mails from logs. Before committing, enable the privacy hook:

```bash
ln -s ../../scripts/check-privacy.sh .git/hooks/pre-commit
```

## License and credits

Scripts and docs: [MIT](LICENSE). Nothing third-party is redistributed here; follow the links instead:
[KindleModding](https://kindlemodding.org/) (WinterBreak, Universal Hotfix, guides),
NiLuJe (USBNetwork, MRPI, KUAL tooling, [MobileRead](https://www.mobileread.com/forums/showthread.php?t=225030)),
[KindleTweaks/PEKI](https://github.com/KindleTweaks/PEKI),
[KOReader](https://github.com/koreader/koreader) (AGPL-3.0),
[SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin) (GPL-3.0),
[reader-dict](https://www.reader-dict.com/) (Wiktionary dictionaries, CC BY-SA),
[notmarek's scriptlets](https://scriptlets.notmarek.com/).
