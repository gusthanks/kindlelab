# Instalar o KindleLab

[English](INSTALL.md) · **Português**

Este instalador coloca os **complementos do KindleLab**. Ele não desbloqueia o aparelho nem instala KOReader
ou SimpleUI. Se o KOReader ainda não funciona, comece pelo
[guia de desbloqueio](https://github.com/gusthanks/kindlelab/blob/main/docs/jailbreak-guide.pt-BR.md).

## O caminho curto

1. Baixe o ZIP do instalador em [Releases](https://github.com/gusthanks/kindlelab/releases) e descompacte
   **no computador**, não no Kindle. É preciso **Python 3.11 ou mais novo**; a janela também usa Tk
   (vem no instalador padrão do Python para Windows/macOS; algumas distribuições Linux têm um pacote separado).
   Download oficial do Python: <https://www.python.org/downloads/>. Não precisa instalar pacotes pelo pip.
2. **Saia do KOReader**, ligue o modo avião e conecte o Kindle como **drive USB**. Faça backup dos livros e
   arquivos pessoais antes. O backup do instalador cobre somente os arquivos que ele substitui.
3. Abra **Install-Windows.cmd** no Windows, **Install-macOS.command** no Mac, ou rode
   `python3 install.py` no Linux. Os scripts de macOS/Linux podem pedir permissão para executar; o comando
   do Python funciona sem essa permissão. Escolha English ou Português na janela.
4. Escolha a **pasta principal do Kindle**, a que tem `documents`, `system` e `koreader`. Selecione seu
   modelo, confirme que saiu do KOReader e ligou o modo avião e clique em **Instalar**. A janela mostra
   a lista de arquivos antes de pedir a confirmação.
5. Espere aparecer **SHA-256 conferido**, ejete o drive com segurança, tire o cabo e abra o KOReader.

**Esta primeira versão não funciona por MTP.** Kindles mais novos (11ª geração em diante) não aparecem
como drive USB comum. Instalar numa cópia no computador é um teste, não instala no Kindle. As instruções
manuais continuam no
[koreader-config](https://github.com/gusthanks/kindlelab/blob/main/koreader-config/README.md) (em inglês).

## O que ele instala

- Patches do KindleLab para biblioteca limpa e livros Amazon na lista (continuam abrindo no leitor
  nativo, sem remover DRM).
- Plugin KindleLab: etiquetas de tipo, perfis para escaneados/quadrinhos novos, botão de quadrinho e
  seletor de ícones.
- Padrões de primeira execução: **só os ajustes que ainda não existem** recebem um valor (biblioteca e
  downloads em `/mnt/us/documents`, ordem por título e limite da navegação à pasta inicial).
- Três ícones do KOReader e uma imagem de descanso para quando não houver livro aberto. Os padrões da tela
  de descanso também só preenchem preferências ausentes, sem substituir escolhas existentes.
- Atalho do KOReader na tela inicial, **só se `documents/KOReader.sh` ainda não existir**. Seu atalho e ícone
  personalizados são preservados exatamente como estavam.

O instalador não altera `settings.reader.lua`, os ajustes do SimpleUI, seu mascote, histórico, fonte,
idioma, livros, chaves SSH, rede, bloqueio de atualizações nem firmware. Na **próxima abertura do KOReader**,
os patches instalados preenchem ajustes ausentes, e o plugin acrescenta perfis e etiquetas nos metadados.
Esses ajustes e etiquetas posteriores não são revertidos pelo botão Desfazer. Os bytes dos livros não são
reescritos.

**Não inclui:** KOReader, SimpleUI, dicionários, notícias nem o monitor de livros do PC. São instalações
opcionais separadas; nenhum executável de terceiros é baixado ou redistribuído. As etiquetas `Tipo: …` e os
nomes de perfis continuam em português mesmo na interface em inglês, por compatibilidade com bibliotecas
existentes.

## Backup, desfazer e recuperar

Cada arquivo substituído é copiado e conferido por hash, com um recibo em
`.kindlelab-installer/transactions/<identificador>/`, no Kindle. Guarde essa pasta oculta; pode copiar para o
PC também. Reinstalar os mesmos arquivos não substitui nada sem necessidade.

**Desfazer:** saia do KOReader, conecte em modo drive USB, escolha o mesmo drive no instalador e clique em
**Desfazer última instalação**. Ele restaura os bytes anteriores ou remove os arquivos que aquela instalação
adicionou. Confere tudo antes: se você editou algum arquivo instalado depois, ele para em vez de sobrescrever
sua edição. Pastas vazias podem ficar. Não remove o desbloqueio, o KOReader nem metadados de leitura criados
quando você abriu o KOReader depois da instalação.

**Instalação interrompida:** mantenha o modo avião ligado, reconecte o mesmo drive e use Desfazer com o
identificador de backup mostrado no erro. Uma falha normal de gravação tenta restaurar automaticamente se
o drive ainda estiver acessível. Se tirar o cabo ou matar o programa, pode não dar para terminar a restauração
na hora. Uma nova instalação se recusa a passar por cima de uma transação incompleta. Se a falha foi só
na preparação do backup, nenhum complemento foi alterado ainda: uma pasta em `.kindlelab-installer/preparing/`
não é uma transação publicada, e dá para tentar de novo depois que o instalador parar.

**Limite em falta de energia:** reler arquivos e conferir hashes não prova que o controlador USB gravou
fisicamente cada byte. O sistema de arquivos e o aparelho podem manter dados em cache. Não fizemos teste
destrutivo de queda de energia ou retirada do cabo; não presuma que a restauração terminou com o drive
desconectado. Guarde um backup independente no PC e sempre ejete com segurança. Em sistemas POSIX, o
instalador sincroniza também as entradas das pastas; no Windows, descarrega os arquivos, mas não tem um
jeito portátil e sem privilégios de sincronizar as entradas das pastas. Erros de sincronização interrompem
a conclusão, não são ignorados. Esta é uma prévia, não um substituto para backup.

Se aparecer erro de trava (*lock*), confirme primeiro que **nenhum outro instalador está rodando**. Depois
remova somente a pasta vazia `.kindlelab-installer/lock` (não apague as transações) e rode Desfazer.
Se um backup ou arquivo instalado falhar na conferência de hash, guarde tudo e peça ajuda: não existe botão
de "forçar sobrescrita", de propósito. Não restaure de fábrica, cancele o registro nem atualize para tentar
consertar o instalador.

## Pelo terminal

Na pasta descompactada (troque `<drive>` pelo caminho do Kindle):

```sh
python3 install.py --target "<drive>" --model pw3 --dry-run
python3 install.py --target "<drive>" --model pw3 --yes --closed
python3 install.py --target "<drive>" --undo --yes --closed
python3 install.py --target "<drive>" --undo <identificador> --yes --closed
```

No Windows, use `py -3` no lugar de `python3`. `--closed` confirma que saiu do KOReader e ligou o modo avião.
`--lang pt` troca a interface do instalador, não o idioma do seu KOReader. Não usa conexão de rede.

Só **Paperwhite 3 / firmware 5.16.2.1.1 / KOReader v2026.07.1** tem validação no aparelho. Versões diferentes
ou não identificadas do KOReader também exigem a permissão de teste. Não dá para identificar o modelo pelos
arquivos USB; você o escolhe. Outras combinações exigem `--allow-untested` (ou a caixa da janela). Essa
permissão não torna um Kindle incompatível compatível. Os resultados dos testes nos sistemas de PC aparecem
no workflow Installer do repositório; eles não substituem testes em aparelhos reais.

O `.sha256` ao lado do ZIP confere a integridade do download. O manifesto interno detecta arquivos
corrompidos, não a identidade de quem publicou: baixe somente de `gusthanks/kindlelab`.
