# KindleLab

**Turn a jailbroken Kindle into a reader that is pleasant every day and safe to maintain: one library
for all your books, new books that organize themselves, reading settings that suit each kind of book, and
a Linux toolbox that checks every step. No DRM removal, no risky shortcuts.**

> **Tested on exactly one device:** Kindle Paperwhite 3 (7th gen, `muscat_wario`), firmware
> **5.16.2.1.1**. Everything else is either *community-reported* (with a link) or *untested*.
> Check [docs/compatibility.md](docs/compatibility.md) before following anything on another model.

## Para que serve (em português)

Desbloquear o Kindle é só o começo. Logo aparecem as dúvidas. Como acessar o aparelho pelo PC sem deixar
uma porta aberta? Como evitar que uma atualização desfaça tudo? Dá para usar o KOReader sem perder os
livros comprados na Amazon? Por que a biblioteca mostra pastas do sistema? O KindleLab reúne as respostas
que testamos num aparelho real, com tudo conferido.

### O que muda no dia a dia

| Sem o KindleLab | Com o KindleLab |
|---|---|
| Duas bibliotecas: as compras da Amazon no leitor do Kindle, o resto no KOReader | **Uma biblioteca só.** Os livros da Amazon aparecem no KOReader com capa, título e autor, e abrem no leitor do Kindle com um toque. O DRM não é tocado. |
| Dicionários, scripts e pastas vazias misturados aos livros | **Só livros na lista.** Os dicionários continuam funcionando, só ficam escondidos. |
| Livro novo chega sem tipo e, às vezes, sem autor ou capa | **Organização automática:** cada livro novo ganha a etiqueta de tipo (Livro, PDF, Escaneado, Quadrinho, Amazon), e o PC avisa o que está faltando. |
| PDF escaneado com margens enormes; quadrinho com o "fantasma" da página anterior | **Ajuste certo na primeira abertura:** margens cortadas e mais contraste no escaneado; página inteira e tela limpa a cada página no quadrinho. |
| Tela de descanso genérica | **A capa do livro que você está lendo** na tela de descanso. |
| KOReader escondido no menu do KUAL | **Ícone de um toque na tela inicial do Kindle**, com galeria de ícones e troca pelo próprio KOReader. |
| Guias espalhados em fóruns e medo de travar o aparelho | **Passo a passo testado**, com backup completo antes e cada cópia conferida por SHA-256 no próprio Kindle. |
| Acesso pelo PC com senha, só pelo cabo | **SSH só com chave**, pelo cabo USB ou pelo Wi-Fi, e o bloqueio de atualização automática conferido. |

Também vem: KOReader em português com tela inicial simples (SimpleUI), dicionário, Wikipédia, catálogos
de livros gratuitos, notícias e exportação dos seus destaques para Markdown.

### Para quem é

- Quem já tem um Kindle desbloqueado, ou vai desbloquear pelo guia oficial do
  [kindlemodding.org](https://kindlemodding.org/).
- Quem usa um PC com Linux para os scripts. As peças do KOReader são arquivos comuns, copiados para o
  Kindle.
- Quem quer o KOReader com cara de produto pronto, sem passar semanas lendo fóruns.

### O que ele não faz

- **Não desbloqueia o Kindle.** Para isso, siga o guia oficial do kindlemodding.org.
- **Não remove DRM nem baixa livros de fontes piratas.** Livro comprado continua abrindo no leitor da
  Amazon.
- **Não troca o sistema do Kindle.** A análise de Android e "sistemas novos" está em
  [docs/06](docs/06-android-and-custom-os.md). Resumo: não recomendamos.
- **Não garante outros modelos.** Só testamos um aparelho. A tabela de
  [compatibilidade](docs/compatibility.md) separa o que foi testado do que foi relatado pela
  comunidade. Tem outro modelo? Abra um [relato de teste](../../issues/new/choose).

### Estado atual

- **Pronto e testado** no Paperwhite 3: tudo o que está na tabela acima.
- **Instalação ainda manual:** cada peça do KOReader é copiada seguindo o
  [koreader-config/README.md](koreader-config/README.md).
- **Em andamento:** um pacote de instalação com toda esta configuração como padrão.

## Why KindleLab

Jailbreaking is only the first step. Then the questions start: how do I reach the Kindle from my PC
without leaving a door open, keep an update from undoing everything, use KOReader without losing my
Amazon books, and stop system folders from cluttering the library? KindleLab collects answers that were
tested on a real device, step by step.

| Without KindleLab | With KindleLab |
|---|---|
| Two libraries: Amazon purchases in the stock reader, everything else in KOReader | **One library.** Amazon books show up in KOReader with cover, title and author and open in the Kindle's own reader with one tap. DRM is never touched. |
| Dictionaries, scripts and empty folders mixed with books | **Only books are listed.** Dictionaries keep working, just hidden. |
| New books arrive untyped, sometimes without author or cover | **Automatic organization:** each new book gets a type tag (Livro, PDF, Escaneado, Quadrinho, Amazon) and the PC tells you what is missing. |
| Scanned PDFs with huge margins; comics with ghosting | **The right settings on first opening:** cropped margins and more contrast for scans; whole page and a clean refresh on every page for comics. |
| Generic sleep screen | **The cover of the book you are reading** on the sleep screen. |
| KOReader hidden in the KUAL menu | **One-tap tile on the Kindle home screen**, with an icon gallery and a switcher inside KOReader. |
| Scattered forum guides, fear of bricking | **Tested steps**, a full backup first, every copy verified with SHA-256 on the device. |
| PC access with a password, cable only | **Key-only SSH** over USB or Wi-Fi, and a verified block of automatic updates. |

Plus: KOReader in Portuguese with a simple home screen (SimpleUI), dictionary, Wikipedia, free-book
catalogs, news, and highlight export to Markdown.

**Who it is for:** owners of a jailbroken Kindle (or about to jailbreak one with the official
[kindlemodding.org](https://kindlemodding.org/) guide) who use a Linux PC for the scripts. The KOReader
pieces are plain files copied to the Kindle.

**What it is not:** not a jailbreak, not a DRM remover or a piracy tool, not a replacement OS
([docs/06](docs/06-android-and-custom-os.md)), and not tested beyond one device.

**Status:** everything above works and was tested on the PW3. Installing the KOReader pieces is still
manual ([koreader-config/README.md](koreader-config/README.md)). A one-step package with this setup as
the default is in progress.

## What's here

| Path | What it is |
|---|---|
| [`docs/`](docs/) | Step-by-step guides, in the order we did them, plus troubleshooting and compatibility |
| [`scripts/`](scripts/) | PC-side tools (bash/python). All read-only on the Kindle unless stated |
| [`koreader-config/`](koreader-config/) | KOReader user patches, the KindleLab plugin, OPDS catalog and news-feed templates |
| [`kindle-files/`](kindle-files/) | Small files to copy to the Kindle (e.g. the one-tap KOReader tile and its icons) |
| [`systemd/`](systemd/) | Optional user timer that checks new books on the Kindle (see docs/07) |
| [`tests/`](tests/) | Unit tests: `tests/run.sh` (Lua) and `python3 -m unittest discover -s tests` |

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
| `kindle-new-books.py` | Report on books added since the last check (title, author, cover, type tag, table of contents, scanned PDF / comic hints); `--notify` for the systemd timer | no |
| `kindle-inventory.lua` | Read-only library listing run on the Kindle by `kindle-new-books.py` (KOReader's LuaJIT) | no |
| `check-privacy.sh` | Pre-commit hook that blocks serials, MACs, IPs, e-mails, home paths and your own denylist | — |

## Start here

1. [docs/00-safety.md](docs/00-safety.md): the rules that keep the device alive.
2. Already jailbroken but unsure what state it is in? [docs/01-diagnose.md](docs/01-diagnose.md).
3. Then, in order: [KUAL, MRPI and OTA block](docs/02-kual-mrpi-ota.md) →
   [USBNetwork / SSH](docs/03-usbnetwork-ssh.md) → [KOReader](docs/04-koreader.md) →
   [full backup](docs/05-full-backup.md).
4. The KindleLab reading experience (one library, tidy list, sleep screen, automatic organization):
   [koreader-config/README.md](koreader-config/README.md), then
   [docs/07-reading-quality.md](docs/07-reading-quality.md).
5. Curious about Android or a "new OS"? [docs/06-android-and-custom-os.md](docs/06-android-and-custom-os.md).
6. Something odd? [docs/troubleshooting.md](docs/troubleshooting.md).

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
