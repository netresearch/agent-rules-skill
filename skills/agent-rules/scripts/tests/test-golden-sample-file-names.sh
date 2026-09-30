#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# Regression test: the golden-sample lookup in generate-agents.sh must treat
# the target project's file names as data.
#
# It counted lines with `xargs -I{} sh -c 'wc -l "{}" ...'`, which pastes each
# file name into a shell command string, so a file named `a$(touch X).go`
# ran `touch X`. The file names now reach `wc` as arguments.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
GENERATE="$SCRIPTS_DIR/generate-agents.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# A Go module whose internal/ directory holds enough files to become a scope,
# so the golden-sample lookup runs for it.
FX="$WORK/proj"
mkdir -p "$FX/internal/foo" "$FX/internal/bar"
printf 'module example.com/fixture\n\ngo 1.22\n' > "$FX/go.mod"
for i in $(seq 1 13); do
    printf 'package foo\n\nfunc F%d() {}\n' "$i" > "$FX/internal/foo/f$i.go"
    printf 'package bar\n\nfunc B%d() {}\n' "$i" > "$FX/internal/bar/b$i.go"
done
# The largest file, so the lookup has one clear answer.
{ printf 'package foo\n\n'; for i in $(seq 1 40); do printf 'func Big%d() {}\n' "$i"; done; } \
    > "$FX/internal/foo/big.go"
# shellcheck disable=SC2016  # the literal $( in the file name is the test input
touch "$FX/internal/foo/"'a$(touch PWNED).go'
git -C "$FX" init -q
git -C "$FX" -c user.email=t@t.t -c user.name=t add -A
git -C "$FX" -c user.email=t@t.t -c user.name=t commit -qm init

(cd "$WORK" && bash "$GENERATE" "$FX" --no-symlinks >/dev/null 2>&1) \
    || fail "generate-agents.sh errored"

[ -f "$FX/internal/AGENTS.md" ] \
    || fail "internal/ did not become a scope, so the lookup never ran"

if [ -e "$FX/PWNED" ] || [ -e "$WORK/PWNED" ] || [ -e "$FX/internal/PWNED" ]; then
    fail "a file name from the target project was executed as shell code"
fi
pass "file names from the target project are not executed"

grep -qF 'internal/foo/big.go' "$FX/internal/AGENTS.md" \
    || fail "the golden sample is not the largest file (internal/foo/big.go)"
pass "the largest file is still chosen as the golden sample"

echo "All golden-sample file-name tests passed."
