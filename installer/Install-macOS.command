#!/bin/sh
cd -- "$(dirname -- "$0")" || exit 1
python3 ./install.py "$@"
result=$?
if [ "$result" -ne 0 ]; then
    printf '\nPython 3.11+ is required. See INSTALL.md / INSTALL.pt-BR.md.\n'
    printf 'Press Enter / Aperte Enter: '
    read -r answer
fi
exit "$result"
