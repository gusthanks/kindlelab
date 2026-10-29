#!/usr/bin/env bash
# Runs the pure-Lua unit tests (no KOReader needed). Usage: tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
LUA=$(command -v luajit || command -v lua)
status=0
for spec in tests/*_spec.lua; do
    echo "== $spec"
    "$LUA" "$spec" || status=1
done
if command -v node >/dev/null; then
    echo "== checker (node --test)"
    node --test tests/checker*.test.mjs || status=1
fi
exit $status
