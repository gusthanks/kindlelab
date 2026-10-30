#!/usr/bin/env python3
"""Run with no arguments for the window, or --help for the command line. Offline, USB-drive only."""
import argparse
import locale
from pathlib import Path
import sys

import kindlelab_installer as core

TEXT = {
    'en': {
        'title': 'KindleLab installer', 'folder': 'Kindle drive', 'choose': 'Choose…',
        'intro': 'Close KOReader, connect the Kindle as a USB drive, then choose its main folder.\n'
                 'KOReader must already be installed. No jailbreak, firmware or book files are changed.',
        'model': 'Model (not detected automatically)', 'pw3': 'Paperwhite 3 / 7th generation', 'other': 'Other / unknown',
        'untested': 'I read compatibility and accept testing an untested model/firmware/KOReader.',
        'closed': 'I exited KOReader on the Kindle.',
        'airplane': 'Airplane mode is on. I backed up my personal files.',
        'preview': 'Preview', 'install': 'Install', 'undo': 'Undo last installation',
        'confirm': 'Back up the affected files and install the changes listed below?',
        'confirm_undo': 'Restore the previous files from the last backup? Edited files will not be overwritten.',
        'need_close': 'Exit KOReader, turn airplane mode on and confirm the checkboxes first.',
        'done': 'SHA-256 verified. Safely eject the Kindle, disconnect it and start KOReader.',
        'restored': 'Previous files restored and SHA-256 verified. The backup is kept.',
        'unchanged': 'Already installed: no payload files needed changing.',
        'backup': 'Backup id', 'error': 'Installation stopped', 'simulation': 'Preview (no files changed)',
        'summary': '{new} file(s) to write · {same} unchanged · {keep} preserved',
        'notice': 'Undo restores installed files, not settings/tags created later while reading. See INSTALL.md.',
        'warnings': {
            'model-not-auto-detected': 'Model is your selection; confirm it in the Kindle settings.',
            'ota-not-checked': 'The installer cannot verify the update block over USB. Keep airplane mode on.',
            'untested': 'Untested combination: device validation is PW3 / firmware 5.16.2.1.1 / KOReader v2026.07.1.',
            'simpleui-not-installed': 'SimpleUI not found. KindleLab does not install third-party software; its simple home screen is optional.',
        },
    },
    'pt': {
        'title': 'Instalador KindleLab', 'folder': 'Drive do Kindle', 'choose': 'Escolher…',
        'intro': 'Saia do KOReader, ligue o Kindle como drive USB e escolha a pasta principal dele.\n'
                 'O KOReader já precisa estar instalado. Não altera desbloqueio, firmware nem livros.',
        'model': 'Modelo (não é detectado automaticamente)', 'pw3': 'Paperwhite 3 / 7ª geração', 'other': 'Outro / não sei',
        'untested': 'Li a compatibilidade e aceito testar modelo/firmware/KOReader não testado.',
        'closed': 'Saí do KOReader no Kindle.',
        'airplane': 'O modo avião está ligado. Fiz backup dos meus arquivos pessoais.',
        'preview': 'Simular', 'install': 'Instalar', 'undo': 'Desfazer última instalação',
        'confirm': 'Fazer backup dos arquivos afetados e instalar as mudanças listadas abaixo?',
        'confirm_undo': 'Restaurar os arquivos anteriores do último backup? Arquivos editados não serão substituídos.',
        'need_close': 'Saia do KOReader, ligue o modo avião e confirme as caixas primeiro.',
        'done': 'SHA-256 conferido. Ejete o Kindle com segurança, tire o cabo e abra o KOReader.',
        'restored': 'Arquivos anteriores restaurados e SHA-256 conferido. O backup foi guardado.',
        'unchanged': 'Já instalado: nenhum arquivo do pacote precisou mudar.',
        'backup': 'Identificador do backup', 'error': 'Instalação interrompida',
        'simulation': 'Simulação (nenhum arquivo alterado)',
        'summary': '{new} arquivo(s) para gravar · {same} iguais · {keep} preservados',
        'notice': 'Desfazer restaura os arquivos instalados, não ajustes/etiquetas criados depois ao ler. Veja INSTALL.pt-BR.md.',
        'warnings': {
            'model-not-auto-detected': 'O modelo é o que você escolheu; confirme nas configurações do Kindle.',
            'ota-not-checked': 'Não dá para conferir o bloqueio de atualizações por USB. Mantenha o modo avião ligado.',
            'untested': 'Combinação não testada: a validação é PW3 / firmware 5.16.2.1.1 / KOReader v2026.07.1.',
            'simpleui-not-installed': 'SimpleUI não encontrado. O instalador não instala programas de terceiros; a tela inicial simples é opcional.',
        },
    },
}


def plan_text(plan, lang):
    s = TEXT[lang]
    lines = [s['simulation'], 'Firmware: ' + (plan['firmware'] or '?'), 'KOReader: ' + (plan['koreader'] or '?'),
             s['summary'].format(new=len(plan['changes']), same=len(plan['unchanged']), keep=len(plan['preserved'])), '']
    lines += ['+ ' + f['path'] for f in plan['changes']]
    lines += ['= ' + f for f in plan['unchanged']]
    lines += ['KEEP ' + f for f in plan['preserved']]
    lines += ['', *[s['warnings'][w] for w in plan['warnings']]]
    return '\n'.join(lines)


def result_text(result, lang):
    s = TEXT[lang]
    msg = s['unchanged'] if result['status'] == 'unchanged' else s['restored'] if result['status'] == 'restored' else s['done']
    if result.get('id'):
        msg += '\n' + s['backup'] + ': ' + result['id']
    return msg


def gui(lang, target=None):
    try:
        import tkinter as tk
        from tkinter import filedialog, messagebox, ttk
        window = tk.Tk()
    except Exception as e:
        raise core.InstallError('The window needs Python Tk support and a desktop session. Use --help for the CLI. ' + str(e)) from e
    window.title('KindleLab ' + core.VERSION)
    frame = ttk.Frame(window, padding=16)
    frame.grid(sticky='nsew')
    window.columnconfigure(0, weight=1)
    window.rowconfigure(0, weight=1)
    frame.columnconfigure(1, weight=1)
    frame.rowconfigure(10, weight=1)
    language = tk.StringVar(value=lang)
    folder = tk.StringVar(value=target or '')
    model = tk.StringVar(value='')
    closed, airplane, untested = (tk.BooleanVar(value=False) for _ in range(3))
    widgets = []
    def label(row, key):
        widget = ttk.Label(frame, wraplength=760)
        widget.grid(row=row, column=0, columnspan=3, sticky='w', pady=(0, 10))
        widgets.append((widget, key))
    combo = ttk.Combobox(frame, values=['en', 'pt'], textvariable=language, state='readonly', width=6)
    combo.grid(row=0, column=2, sticky='e')
    label(1, 'intro')
    choose_label = ttk.Label(frame)
    choose_label.grid(row=2, column=0, sticky='w', padx=(0, 8))
    widgets.append((choose_label, 'folder'))
    ttk.Entry(frame, textvariable=folder, width=65).grid(row=2, column=1, sticky='ew')
    def choose():
        chosen = filedialog.askdirectory(parent=window)
        if chosen:
            folder.set(chosen)
    chooser = ttk.Button(frame, command=choose)
    chooser.grid(row=2, column=2, padx=(8, 0))
    widgets.append((chooser, 'choose'))
    label(3, 'model')
    radios = ttk.Frame(frame)
    radios.grid(row=4, column=0, columnspan=3, sticky='w', pady=(0, 8))
    for value, key in (('pw3', 'pw3'), ('unknown', 'other')):
        radio = ttk.Radiobutton(radios, variable=model, value=value)
        radio.pack(side='left', padx=(0, 16))
        widgets.append((radio, key))
    for row, var, key in ((5, untested, 'untested'), (6, closed, 'closed'), (7, airplane, 'airplane')):
        box = ttk.Checkbutton(frame, variable=var)
        box.grid(row=row, column=0, columnspan=3, sticky='w', pady=2)
        widgets.append((box, key))
    buttons = ttk.Frame(frame)
    buttons.grid(row=8, column=0, columnspan=3, sticky='w', pady=10)
    output = tk.Text(frame, width=96, height=17, wrap='word', state='disabled')
    output.grid(row=10, column=0, columnspan=3, sticky='nsew')
    label(11, 'notice')
    def show(text):
        output.configure(state='normal')
        output.delete('1.0', 'end')
        output.insert('1.0', text)
        output.configure(state='disabled')
    def act(action):
        s = TEXT[language.get()]
        try:
            if not folder.get():
                raise core.InstallError(s['folder'] + '?')
            if action != 'preview' and not (closed.get() and airplane.get()):
                raise core.InstallError(s['need_close'])
            if action == 'undo':
                if messagebox.askyesno(s['title'], s['confirm_undo'], parent=window):
                    show(result_text(core.undo(folder.get(), closed=True), language.get()))
                return
            payload = core.load_payload(Path(__file__).resolve().parent)
            plan = core.make_plan(folder.get(), payload, model=model.get(), allow_untested=untested.get())
            show(plan_text(plan, language.get()))
            if action == 'install' and messagebox.askyesno(s['title'], s['confirm'], parent=window):
                result = core.install(folder.get(), payload, model=model.get(), allow_untested=untested.get(), closed=True)
                show(result_text(result, language.get()))
        except (core.InstallError, OSError, ValueError) as e:
            messagebox.showerror(s['error'], str(e), parent=window)
    for key in ('preview', 'install', 'undo'):
        button = ttk.Button(buttons, command=lambda a=key: act(a))
        button.pack(side='left', padx=(0, 8))
        widgets.append((button, key))
    def translate(_event=None):
        s = TEXT[language.get()]
        window.title(s['title'] + ' ' + core.VERSION)
        for widget, key in widgets:
            widget.configure(text=s[key])
    combo.bind('<<ComboboxSelected>>', translate)
    translate()
    window.mainloop()


def main(argv=None):
    default_lang = 'pt' if (locale.getlocale()[0] or '').lower().startswith('pt') else 'en'
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--target', help='Mounted Kindle drive (not a backup you want to keep unchanged).')
    ap.add_argument('--lang', choices=['en', 'pt'], default=default_lang)
    ap.add_argument('--model', choices=['pw3', 'unknown'], default='unknown')
    ap.add_argument('--allow-untested', action='store_true')
    ap.add_argument('--closed', action='store_true', help='I exited KOReader and turned airplane mode on.')
    ap.add_argument('--yes', action='store_true', help='Explicitly approve the listed install/undo writes.')
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument('--dry-run', action='store_true')
    mode.add_argument('--undo', nargs='?', const='latest', metavar='BACKUP_ID')
    ap.add_argument('--gui', action='store_true')
    a = ap.parse_args(argv)
    try:
        if a.gui or not a.target:
            gui(a.lang, a.target)
            return 0
        if a.undo is not None:
            if not a.yes:
                raise core.InstallError('Undo needs --yes and --closed; nothing changed.')
            result = core.undo(a.target, None if a.undo == 'latest' else a.undo, closed=a.closed)
        else:
            payload = core.load_payload(Path(__file__).resolve().parent)
            plan = core.make_plan(a.target, payload, model=a.model, allow_untested=a.allow_untested)
            print(plan_text(plan, a.lang))
            if a.dry_run:
                return 0
            if not a.yes:
                raise core.InstallError('Preview only. Use --yes --closed to approve installation, or use the window.')
            result = core.install(a.target, payload, model=a.model, allow_untested=a.allow_untested, closed=a.closed)
        print(result_text(result, a.lang))
        return 0
    except (core.InstallError, OSError, ValueError) as e:
        print(TEXT[a.lang]['error'] + ': ' + str(e), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
