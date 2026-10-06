#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# verify-commands.sh records its results in .agents/command-verification.json
# inside the analysed project. The file is valid JSON whatever the documented
# commands contain, and it is written inside the project only: a symlinked
# sidecar file is replaced, a symlinked .agents directory is not written to.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
VERIFY="$SCRIPTS_DIR/verify-commands.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# Two documented commands that exist on any host: one plain, one carrying a
# tab and double quotes.
write_agents() {
    # shellcheck disable=SC2016  # backticks are markdown, not substitution
    printf '# Fixture\n\n## Commands\n\n| Command | Purpose |\n|---|---|\n| `ls -la` | list |\n| `ls\t"a b"` | quoted |\n' > "$1/AGENTS.md"
}

# --- Test 1: the sidecar is valid JSON and names both commands
FX="$WORK/plain"
mkdir -p "$FX"
write_agents "$FX"
(cd "$FX" && bash "$VERIFY" . >/dev/null 2>&1) || fail "verify-commands.sh errored"
jq -e . "$FX/.agents/command-verification.json" >/dev/null 2>&1 \
    || fail "the sidecar is not valid JSON: $(cat "$FX/.agents/command-verification.json")"
jq -e '.commands | has("ls -la") and has("ls\t\"a b\"")' "$FX/.agents/command-verification.json" >/dev/null \
    || fail "the sidecar does not hold both commands"
pass "the sidecar is valid JSON for a command with a tab and quotes"

# --- Test 2: a symlinked sidecar file is replaced, its target left alone
FX="$WORK/file-link"
mkdir -p "$FX/.agents"
write_agents "$FX"
printf 'keep\n' > "$WORK/outside.txt"
ln -s ../../outside.txt "$FX/.agents/command-verification.json"
(cd "$FX" && bash "$VERIFY" . >/dev/null 2>&1) || fail "verify-commands.sh errored"
[ "$(cat "$WORK/outside.txt")" = keep ] || fail "the sidecar was written through a symlink"
{ [ -f "$FX/.agents/command-verification.json" ] && [ ! -L "$FX/.agents/command-verification.json" ]; } \
    || fail "the symlinked sidecar was not replaced by a regular file"
pass "a symlinked sidecar is replaced, not written through"

# --- Test 3: a symlinked .agents directory is not written to
FX="$WORK/dir-link"
mkdir -p "$FX" "$WORK/outside-dir"
write_agents "$FX"
ln -s ../outside-dir "$FX/.agents"
(cd "$FX" && bash "$VERIFY" . >/dev/null 2>&1) || fail "verify-commands.sh errored"
[ -z "$(ls -A "$WORK/outside-dir")" ] || fail "a file was written into the symlinked .agents directory"
pass "nothing is written through a symlinked .agents directory"

echo ""
echo "All verification sidecar tests passed."
