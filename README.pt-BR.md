# KindleLab

[English](README.md) · **Português**

**Desbloqueie seu Kindle sem se perder e depois transforme ele num leitor gostoso de usar todo dia.**
Uma página leva você pelo desbloqueio em palavras simples, com o link oficial para cada clique. Depois disso:
uma biblioteca só para todos os seus livros, livros novos que se organizam sozinhos, ajustes certos para
cada tipo de livro e ferramentas que conferem cada passo. Sem remover DRM e sem atalhos arriscados.

> **Testado em um único aparelho:** Kindle Paperwhite 3 (7ª geração, `muscat_wario`), firmware
> **5.16.2.1.1**. O resto é *relato da comunidade* (com link) ou *não testado*. Confira a tabela de
> [compatibilidade](docs/compatibility.md) (em inglês) antes de seguir qualquer coisa em outro modelo.

## Comece aqui

| Seu Kindle hoje | Vá para |
|---|---|
| Ainda não desbloqueado | **[O guia de desbloqueio](docs/jailbreak-guide.pt-BR.md)**: a viagem inteira numa página só |
| Desbloqueado, mas você não sabe em que estado está | [Diagnóstico de um desbloqueio existente](docs/01-diagnose.md) (só leitura, em inglês) |
| Desbloqueado e com o KOReader | [O que o KindleLab acrescenta](#o-que-o-kindlelab-acrescenta) |

## Por que o KindleLab

- **Um mapa em vez de dezenas de abas.** Os guias oficiais do [KindleModding](https://kindlemodding.org/)
  têm todos os detalhes, espalhados por muitas páginas e em inglês. O nosso
  [guia de desbloqueio](docs/jailbreak-guide.pt-BR.md) põe a viagem em ordem numa página só: por que cada
  passo importa, o que fazer, como saber que deu certo, quando parar e pedir ajuda, e o que significa cada
  palavra nova. Para os cliques exatos, ele leva à página oficial, então nunca toma o lugar dela.
- **Um leitor pronto, não só um desbloqueio.** A maioria dos guias termina em "instale o KOReader". O
  KindleLab continua ([abaixo](#o-que-o-kindlelab-acrescenta)).
- **Segurança que dá para conferir.** Backup antes de tudo, cada cópia conferida por SHA-256 no próprio
  Kindle, diagnóstico que não mexe em nada, SSH só com chave.
- **Honesto sobre os testes.** Tudo vem marcado como testado, relatado pela comunidade ou não testado.
- **Em inglês e português**, e pronto para [outros idiomas](#idiomas).

## O que o KindleLab acrescenta

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

Também vem: KOReader com tela inicial simples (SimpleUI), dicionário, Wikipédia, catálogos de livros
gratuitos, notícias e exportação dos seus destaques para Markdown.

**Para quem é:** quem tem um Kindle e quer o KOReader sem passar semanas lendo fóruns. O guia de desbloqueio
funciona com qualquer computador; as ferramentas opcionais depois dele usam um PC com Linux, e as peças do
KOReader são arquivos comuns que você copia para o Kindle.

**O que ele não é:** não é uma ferramenta de desbloqueio (não hospedamos nem alteramos os arquivos de
desbloqueio; o guia leva você aos oficiais), não remove DRM nem baixa livros piratas, não troca o sistema do
Kindle ([docs/06](docs/06-android-and-custom-os.md), em inglês) e não foi testado além de um aparelho.

**Estado atual:** tudo o que está na tabela funciona e foi testado no Paperwhite 3. A instalação das peças
do KOReader ainda é manual ([koreader-config/README.md](koreader-config/README.md), em inglês). Um pacote de
instalação com esta configuração como padrão está em andamento.

## Guias

Em português: este README e o [guia de desbloqueio](docs/jailbreak-guide.pt-BR.md). Os outros guias estão em
inglês, e a maioria dos navegadores traduz a página (botão direito → **Traduzir**).

- **Desbloqueio:** [guia de desbloqueio](docs/jailbreak-guide.pt-BR.md) · [regras de segurança](docs/00-safety.md) ·
  [diagnóstico de um desbloqueio existente](docs/01-diagnose.md) ·
  [KUAL, MRPI e bloqueio de atualizações](docs/02-kual-mrpi-ota.md) (caminho antigo)
- **Depois do desbloqueio:** [USBNetwork e SSH](docs/03-usbnetwork-ssh.md) · [KOReader](docs/04-koreader.md) ·
  [backup completo](docs/05-full-backup.md) · [a configuração de leitura do KindleLab](koreader-config/README.md) ·
  [qualidade de leitura e livros novos](docs/07-reading-quality.md)
- **Consulta:** [solução de problemas](docs/troubleshooting.md) · [compatibilidade](docs/compatibility.md) ·
  [Android e "sistema novo"](docs/06-android-and-custom-os.md)

## O que tem aqui

| Pasta | O que é |
|---|---|
| [`docs/`](docs/) | Os guias acima |
| [`scripts/`](scripts/) | Ferramentas para o PC (bash/python). Só leem o Kindle, salvo quando indicado |
| [`koreader-config/`](koreader-config/) | Patches do KOReader, o plugin do KindleLab, modelos de catálogo OPDS e de notícias |
| [`kindle-files/`](kindle-files/) | Arquivos pequenos para copiar no Kindle (por exemplo, o ícone de um toque do KOReader) |
| [`systemd/`](systemd/) | Timer opcional que confere livros novos no Kindle (veja o docs/07) |
| [`tests/`](tests/) | Testes: `tests/run.sh` (Lua) e `python3 -m unittest discover -s tests` |

### Scripts

| Script | Para que serve | Escreve no Kindle? |
|---|---|---|
| `usbnet-connect.sh` | Configura o lado do PC da rede pelo cabo USB (NetworkManager) e resolve conflito de rede | não |
| `kindle-find-wifi.sh` | Acha o endereço Wi-Fi do Kindle na sua rede pelo MAC (para SSH pelo Wi-Fi) | não |
| `kindle-status.sh` | Painel de saúde: firmware, bloqueio de atualizações, hotfix, bateria, Wi-Fi, relógio, espaço, modo do SSH | não |
| `kindle-screenshot.sh` | Captura da tela do Kindle (com `fbgrab`) | só `/tmp` |
| `full-backup.sh` | Imagem exata da área do sistema e das partições de boot, conferida no próprio Kindle, mais cópia incremental dos arquivos | não |
| `pull-highlights.py` | `My Clippings.txt` (leitor do Kindle) + exportações do KOReader → um arquivo Markdown por livro | não |
| `build-koreader-config.py` | Monta uma configuração do KOReader (idioma, dicionário, OPDS, notícias, plugins) numa pasta de preparo com manifesto | não (você envia) |
| `kindle-new-books.py` | Relatório dos livros novos desde a última conferência (título, autor, capa, etiqueta de tipo, sumário, sinais de PDF escaneado ou quadrinho); `--notify` para o timer | não |
| `kindle-inventory.lua` | Lista da biblioteca, só leitura, rodada no Kindle pelo `kindle-new-books.py` (LuaJIT do KOReader) | não |
| `check-privacy.sh` | Trava de commit que bloqueia números de série, MACs, IPs, e-mails, caminhos pessoais e a sua lista própria | — |

## Regras básicas

- Backup primeiro. Uma mudança de cada vez. Confira cada cópia com SHA-256 **no próprio Kindle**.
- Mantenha o modo avião ligado até o bloqueio de atualizações estar conferido.
- Nunca restaure as configurações de fábrica, cancele o registro ou atualize o firmware "para consertar".
- **Sem remover DRM e sem fontes piratas.** Livro comprado continua no leitor do Kindle.

## Idiomas

O idioma principal é o inglês. Em português: este README e o [guia de desbloqueio](docs/jailbreak-guide.pt-BR.md).

Quer o guia de desbloqueio no seu idioma? Copie `docs/jailbreak-guide.md` para
`docs/jailbreak-guide.<código do idioma>.md` (por exemplo, `jailbreak-guide.es.md`), traduza, acrescente o
idioma nos links do topo de todas as versões e abra um *pull request*.

## Como contribuir

Relatos de teste com outros modelos e firmwares são a contribuição mais valiosa: use o formulário *Test
report* nos *issues*. Tire dos registros números de série, endereços MAC, nomes de rede Wi-Fi e e-mails.
Antes de fazer commit, ligue a trava de privacidade:

```bash
ln -s ../../scripts/check-privacy.sh .git/hooks/pre-commit
```

## Licença e créditos

Scripts e documentação: [MIT](LICENSE). Nada de terceiros é redistribuído aqui; siga os links:
[KindleModding](https://kindlemodding.org/) (WinterBreak, Universal Hotfix, guias),
NiLuJe (USBNetwork, MRPI, ferramentas do KUAL, [MobileRead](https://www.mobileread.com/forums/showthread.php?t=225030)),
[KindleTweaks/PEKI](https://github.com/KindleTweaks/PEKI),
[Kindle-Filler-Disk](https://github.com/iiroak/Kindle-Filler-Disk),
[KOReader](https://github.com/koreader/koreader) (AGPL-3.0),
[SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin) (GPL-3.0),
[reader-dict](https://www.reader-dict.com/) (dicionários do Wikcionário, CC BY-SA),
[scriptlets do notmarek](https://scriptlets.notmarek.com/).
