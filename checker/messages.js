// Every word the checker shows, in English and Portuguese. Text only, no logic.

const REPO = 'https://github.com/gusthanks/kindlelab/blob/main/';
const GUIDE = { en: 'docs/jailbreak-guide.md', pt: 'docs/jailbreak-guide.pt-BR.md' };
const ANCHORS = {
  en: {
    1: 'step-1-turn-on-airplane-mode', 2: 'step-2-back-up-your-books',
    3: 'step-3-block-updates-by-filling-the-storage', 4: 'step-4-find-the-right-jailbreak-for-your-kindle',
    5: 'step-5-jailbreak', 6: 'step-6-finish-the-jailbreak', '6a': '6a-modern-path-whats-next',
    '6b': '6b-legacy-path-post-jailbreak', 7: 'step-7-install-koreader', 8: 'step-8-make-it-yours-optional',
    help: 'getting-help', stop: 'stop-signs',
  },
  pt: {
    1: 'passo-1-ative-o-modo-avião', 2: 'passo-2-faça-backup-dos-seus-livros',
    3: 'passo-3-bloqueie-as-atualizações-enchendo-a-memória', 4: 'passo-4-descubra-o-desbloqueio-certo-para-o-seu-kindle',
    5: 'passo-5-desbloqueie', 6: 'passo-6-termine-o-desbloqueio', '6a': '6a-caminho-moderno-whats-next',
    '6b': '6b-caminho-antigo-post-jailbreak', 7: 'passo-7-instale-o-koreader', 8: 'passo-8-deixe-do-seu-jeito-opcional',
    help: 'onde-pedir-ajuda', stop: 'sinais-de-parada',
  },
};

export function guideUrl(lang, key) {
  return `${REPO}${GUIDE[lang]}#${ANCHORS[lang][key]}`;
}
export const REPO_URL = 'https://github.com/gusthanks/kindlelab';

export const MESSAGES = {
  en: {
    lang: 'English',
    title: 'Where am I?',
    subtitle: 'A KindleLab helper for the jailbreak guide',
    intro: 'Plug your Kindle into this computer and choose its drive. This page looks at a few file names to tell you which step of the jailbreak guide you are on, and what to do next.',
    privacy: 'Everything stays on your computer. The page only reads file names and three small text files, and its security settings block every network connection, so nothing can be sent anywhere.',
    pick: 'Choose the Kindle drive',
    pickOther: 'Try another way',
    pickAgain: 'Check again',
    mtp: 'Newer Kindles (11th generation and later) do not show up as a drive. Copy all their folders to your computer first (step 2 of the guide), then choose that copy.',
    reading: 'Reading…',
    cancelled: 'No folder chosen.',
    error: 'Could not read this folder: {error}',
    you: 'You are here',
    openGuide: 'Open this step in the guide',
    steps: {
      1: 'Airplane mode', 2: 'Back up your books', 3: 'Fill the storage', 4: 'Find your jailbreak',
      5: 'Jailbreak', 6: 'Finish the jailbreak', 7: 'Install KOReader', 8: 'Make it yours',
    },
    status: { done: 'done', now: 'you are here', warn: 'needs attention', todo: 'to do', optional: 'optional' },
    firmware: 'Firmware {version}, as written on the Kindle. Confirm it on the Kindle: Settings → Device Options → Device Info.',
    noFirmware: 'Firmware version not found in the files. See it on the Kindle: Settings → Device Options → Device Info.',
    method: {
      modern: 'Jailbreak found: modern method{version}.',
      legacy: 'Jailbreak found: legacy method (hotfix).',
    },
    kind: {
      'not-kindle': 'This folder does not look like a Kindle. Choose the Kindle drive itself: the one that contains the documents folder.',
      subfolder: 'This looks like the documents folder. Go one level up and choose the Kindle drive itself.',
    },
    next: {
      start: { anchor: 1, title: 'Start at step 1', text: 'Nothing from a jailbreak was found on this Kindle yet. Turn on airplane mode, back up your books, then fill the storage (steps 1 to 3).' },
      wizard: { anchor: 4, title: 'Next: find your jailbreak (step 4)', text: 'The storage is filled. Write down the firmware version and the start of the serial number, then use the official wizard.' },
      'run-jailbreak': { anchor: 5, title: 'Next: run the jailbreak (step 5)', text: 'The WinterBreak files are on the Kindle but have not run yet. Eject the Kindle and continue the official page from where you stopped.' },
      'jb-failed': { anchor: 5, title: 'The jailbreak did not finish (step 5)', text: 'See the note below before you try again.' },
      'modern-cleanup': { anchor: '6a', title: 'Jailbroken! Next: clean up (step 6A)', text: 'With the modern method, updates are already blocked. Delete the filler files and any update file, then install KOReader.' },
      'free-space-kual': { anchor: '6b', title: 'Stuck at KUAL (step 6B)', text: 'With airplane mode on, delete part of the filler files until about 220 MB are free, then install KUAL and MRPI again.' },
      'install-kual': { anchor: '6b', title: 'Jailbroken! Next: KUAL and MRPI (step 6B)', text: 'Keep airplane mode on and install KUAL and MRPI, as the official page explains.' },
      'block-updates': { anchor: '6b', title: 'Next: block updates for good (step 6B)', text: 'In KUAL, choose Rename OTA binaries → Rename. Keep airplane mode on until this is done.' },
      'install-koreader': { anchor: 7, title: 'Next: install KOReader (step 7)', text: 'The jailbreak is finished. Now install the reading app.' },
      kindlelab: { anchor: 8, title: 'KOReader is installed. Optional: make it yours (step 8)', text: 'One library with your Amazon books, a tidy list, the book cover on the sleep screen and more.' },
      'all-done': { anchor: 8, title: 'All done!', text: 'Jailbreak, KOReader and the KindleLab pieces are in place. Enjoy your reading.' },
    },
    notes: {
      'update-file': 'An update file is waiting in the main folder of the Kindle ({files}). Delete it now and keep airplane mode on: it is an update waiting to install.',
      'check-free-space': 'Filler files found. On the Kindle, check Settings → Device Options → Device Info: only about 50 to 90 MB should be free.',
      'wb-too-new': 'The official WinterBreak page says it does not work on firmware 5.18.1 or newer, and this Kindle has {version}. Run the official wizard again before you continue.',
      'mrpi-no-space': 'The installer log says it ran out of space and skipped KUAL. This is exactly where our own Kindle got stuck.',
      'jb-failed': 'The jailbreak script left its log (jb.sh.log), but not the file that marks success (documents/JAILBROKEN.txt). Start the official page again from the top. If it fails again, ask for help.',
      'check-ota': 'Updates should be blocked by renameotabin. Check it now and then with the Check OTA Status scriptlet, and keep airplane mode on whenever you are unsure.',
      'legacy-filler': 'Filler files are still there. Once Check OTA Status says updates are blocked, you can delete the fill_disk folder to get the space back.',
    },
    footer: 'Read the full guide',
    source: 'Source code',
  },
  pt: {
    lang: 'Português',
    title: 'Onde estou?',
    subtitle: 'Um ajudante do KindleLab para o guia de desbloqueio',
    intro: 'Ligue o Kindle neste computador e escolha o drive dele. Esta página olha alguns nomes de arquivos para dizer em que passo do guia de desbloqueio você está e o que fazer em seguida.',
    privacy: 'Tudo fica no seu computador. A página só lê nomes de arquivos e três arquivos de texto pequenos, e as configurações de segurança dela bloqueiam qualquer conexão de rede, então nada pode ser enviado.',
    pick: 'Escolher o drive do Kindle',
    pickOther: 'Tentar de outro jeito',
    pickAgain: 'Conferir de novo',
    mtp: 'Kindles mais novos (11ª geração em diante) não aparecem como drive. Copie antes todas as pastas dele para o computador (passo 2 do guia) e escolha essa cópia.',
    reading: 'Lendo…',
    cancelled: 'Nenhuma pasta escolhida.',
    error: 'Não deu para ler esta pasta: {error}',
    you: 'Você está aqui',
    openGuide: 'Abrir este passo no guia',
    steps: {
      1: 'Modo avião', 2: 'Backup dos livros', 3: 'Encher a memória', 4: 'Descobrir o desbloqueio',
      5: 'Desbloquear', 6: 'Terminar o desbloqueio', 7: 'Instalar o KOReader', 8: 'Deixar do seu jeito',
    },
    status: { done: 'feito', now: 'você está aqui', warn: 'precisa de atenção', todo: 'a fazer', optional: 'opcional' },
    firmware: 'Firmware {version}, segundo os arquivos do Kindle. Confirme no Kindle: Configurações → Opções do dispositivo → Informações do dispositivo.',
    noFirmware: 'A versão do firmware não está nos arquivos. Veja no Kindle: Configurações → Opções do dispositivo → Informações do dispositivo.',
    method: {
      modern: 'Desbloqueio encontrado: método moderno{version}.',
      legacy: 'Desbloqueio encontrado: método antigo (hotfix).',
    },
    kind: {
      'not-kindle': 'Esta pasta não parece um Kindle. Escolha o próprio drive do Kindle: o que tem a pasta documents.',
      subfolder: 'Isto parece a pasta documents. Volte um nível e escolha o próprio drive do Kindle.',
    },
    next: {
      start: { anchor: 1, title: 'Comece pelo passo 1', text: 'Ainda não há nada de desbloqueio neste Kindle. Ligue o modo avião, faça o backup dos livros e depois encha a memória (passos 1 a 3).' },
      wizard: { anchor: 4, title: 'Próximo: descobrir o desbloqueio (passo 4)', text: 'A memória está cheia. Anote a versão do firmware e o começo do número de série e use o assistente oficial.' },
      'run-jailbreak': { anchor: 5, title: 'Próximo: rodar o desbloqueio (passo 5)', text: 'Os arquivos do WinterBreak estão no Kindle, mas ainda não rodaram. Ejete o Kindle e continue a página oficial de onde parou.' },
      'jb-failed': { anchor: 5, title: 'O desbloqueio não terminou (passo 5)', text: 'Leia o aviso abaixo antes de tentar de novo.' },
      'modern-cleanup': { anchor: '6a', title: 'Desbloqueado! Próximo: limpar (passo 6A)', text: 'No método moderno, as atualizações já ficam bloqueadas. Apague os arquivos de enchimento e qualquer arquivo de atualização, depois instale o KOReader.' },
      'free-space-kual': { anchor: '6b', title: 'Travado no KUAL (passo 6B)', text: 'Com o modo avião ligado, apague parte dos arquivos de enchimento até ficarem uns 220 MB livres e instale o KUAL e o MRPI de novo.' },
      'install-kual': { anchor: '6b', title: 'Desbloqueado! Próximo: KUAL e MRPI (passo 6B)', text: 'Mantenha o modo avião ligado e instale o KUAL e o MRPI, como a página oficial explica.' },
      'block-updates': { anchor: '6b', title: 'Próximo: bloquear as atualizações de vez (passo 6B)', text: 'No KUAL, escolha Rename OTA binaries → Rename. Mantenha o modo avião ligado até terminar.' },
      'install-koreader': { anchor: 7, title: 'Próximo: instalar o KOReader (passo 7)', text: 'O desbloqueio terminou. Agora instale o aplicativo de leitura.' },
      kindlelab: { anchor: 8, title: 'O KOReader está instalado. Opcional: deixe do seu jeito (passo 8)', text: 'Uma biblioteca só com seus livros da Amazon, lista limpa, a capa do livro na tela de descanso e mais.' },
      'all-done': { anchor: 8, title: 'Tudo pronto!', text: 'Desbloqueio, KOReader e as peças do KindleLab estão no lugar. Boa leitura.' },
    },
    notes: {
      'update-file': 'Há um arquivo de atualização esperando na pasta principal do Kindle ({files}). Apague agora e mantenha o modo avião ligado: é uma atualização esperando para ser instalada.',
      'check-free-space': 'Arquivos de enchimento encontrados. No Kindle, confira em Configurações → Opções do dispositivo → Informações do dispositivo: só uns 50 a 90 MB devem estar livres.',
      'wb-too-new': 'A página oficial do WinterBreak diz que ele não funciona no firmware 5.18.1 ou mais novo, e este Kindle está no {version}. Rode o assistente oficial de novo antes de continuar.',
      'mrpi-no-space': 'O registro do instalador diz que faltou espaço e ele pulou o KUAL. Foi exatamente aqui que o nosso Kindle travou.',
      'jb-failed': 'O programa de desbloqueio deixou o registro dele (jb.sh.log), mas não o arquivo que marca o sucesso (documents/JAILBROKEN.txt). Comece a página oficial de novo, do início. Se falhar de novo, peça ajuda.',
      'check-ota': 'As atualizações devem estar bloqueadas pelo renameotabin. Confira de vez em quando com o scriptlet Check OTA Status e mantenha o modo avião ligado sempre que tiver dúvida.',
      'legacy-filler': 'Os arquivos de enchimento ainda estão lá. Quando o Check OTA Status disser que as atualizações estão bloqueadas, pode apagar a pasta fill_disk para recuperar o espaço.',
    },
    footer: 'Ler o guia completo',
    source: 'Código-fonte',
  },
};
