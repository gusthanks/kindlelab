#!/usr/bin/env bash
# Refuse to commit personal data. Install as a git pre-commit hook:
#     ln -s ../../scripts/check-privacy.sh .git/hooks/pre-commit
# or run by hand on every tracked file:  scripts/check-privacy.sh --all
#
# Generic patterns: Kindle serial numbers, MAC addresses, IPv4 addresses (except the
# USBNetwork defaults and documentation ranges), e-mail addresses, home-directory paths,
# private keys, 32-hex device ids.
# Your own literals (Wi-Fi names, public IPs, names, book titles...) go in a file that is
# NOT in the repo: ${KINDLELAB_DENYLIST:-~/.config/kindlelab/privacy-denylist}
# (one per line, case-insensitive, lines starting with # ignored).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
DENY=${KINDLELAB_DENYLIST:-$HOME/.config/kindlelab/privacy-denylist}

if [ "${1:-}" = "--all" ]; then
  mapfile -t FILES < <(git ls-files)
  show() { cat -- "$1"; }
else
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACMR)
  show() { git show ":$1"; }
fi

ALLOWED_IP='^(192\.168\.15\.(0|1|201|244|255)|127\.0\.0\.1|0\.0\.0\.0|255\.255\.255\.[0-9]+|169\.254\.[0-9]+\.[0-9]+|192\.0\.2\.[0-9]+|198\.51\.100\.[0-9]+|203\.0\.113\.[0-9]+)$'
PATTERNS=(
  'serial|\b(G0|B0|90)[0-9A-Z]{14}\b'
  'MAC address|\b([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b'
  'e-mail|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
  'home path|/(home|Users)/[a-z_][a-z0-9_-]*/|/run/media/[a-z_][a-z0-9_-]*/'
  'private key|PRIVATE KEY-----'
  'device id|\b[0-9A-F]{32}\b'
)
fail=0
report() { echo "privacy: $1: $2"; fail=1; }

for f in "${FILES[@]}"; do
  [ -n "$f" ] || continue
  [ "$f" = "scripts/check-privacy.sh" ] && continue        # holds the patterns themselves
  content=$(show "$f" 2>/dev/null) || continue
  printf '%s' "$content" | grep -qI . || continue           # skip binary files
  for entry in "${PATTERNS[@]}"; do
    name=${entry%%|*}; rx=${entry#*|}
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      case $name in
        e-mail) printf '%s' "$hit" | grep -qE '@(users\.noreply\.github\.com|example\.(com|org)|openssh\.com)' && continue;;
        "home path") printf '%s' "$hit" | grep -qE '/(home|Users|run/media)/(user|you|USER|\$USER)/' && continue;;
      esac
      report "$f" "$name -> $hit"
    done < <(printf '%s\n' "$content" | grep -noE "$rx" | head -5)
  done
  while IFS= read -r hit; do
    ip=${hit#*:}
    printf '%s' "$ip" | grep -qE "$ALLOWED_IP" || report "$f" "IPv4 -> $hit"
  # (?<![0-9.]) / (?!\.?[0-9]): skip version numbers such as firmware 5.16.2.1.1
  done < <(printf '%s\n' "$content" | grep -noP '(?<![0-9.])([0-9]{1,3}\.){3}[0-9]{1,3}(?!\.?[0-9])' | head -20)
  if [ -f "$DENY" ]; then
    while IFS= read -r hit; do
      [ -n "$hit" ] && report "$f" "denylisted text on line ${hit%%:*}"
    done < <(printf '%s\n' "$content" | grep -niF -f <(grep -v '^\s*#' "$DENY" | grep -v '^\s*$') | cut -d: -f1 | head -5)
  fi
done

if [ $fail = 1 ]; then
  echo "privacy: commit blocked. Remove the data above (or fix a false positive) and try again."
  exit 1
fi
[ -f "$DENY" ] || echo "privacy: note: no denylist at $DENY (only generic patterns checked)"
exit 0
