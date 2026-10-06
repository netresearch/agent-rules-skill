#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# generate-agents.sh writes AGENTS.md files inside the project only. A symlink
# at a root or scoped AGENTS.md counts as an existing file (kept without
# --force, like a regular one), and --force or --update replaces the link with
# the generated file instead of writing through it.
# test-symlink-write-boundary.sh covers the same rule for CLAUDE.md/GEMINI.md.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
GENERATE="$SCRIPTS_DIR/generate-agents.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# A Go module whose internal/ directory becomes a scope.
make_fixture() {
    local fx="$1" i
    mkdir -p "$fx/internal/foo"
    printf 'module example.com/fixture\n\ngo 1.22\n' > "$fx/go.mod"
    for i in $(seq 1 13); do
        printf 'package foo\n\nfunc F%d() {}\n' "$i" > "$fx/internal/foo/f$i.go"
    done
    git -C "$fx" init -q
    git -C "$fx" -c user.email=t@t.t -c user.name=t add -A
    git -C "$fx" -c user.email=t@t.t -c user.name=t commit -qm init
}
generate() { (cd "$WORK" && bash "$GENERATE" "$@" --no-symlinks >/dev/null 2>&1); }
is_regular() { [ -f "$1" ] && [ ! -L "$1" ]; }

mkdir -p "$WORK/outside"

# --- Test 1: a dangling root symlink is kept, and --force replaces it
FX="$WORK/root-dangling"
make_fixture "$FX"
ln -s ../outside/AGENTS.md "$FX/AGENTS.md"
generate "$FX" || fail "generate-agents.sh errored"
[ -e "$WORK/outside/AGENTS.md" ] && fail "the root AGENTS.md was written through a dangling symlink"
[ "$(readlink "$FX/AGENTS.md")" = ../outside/AGENTS.md ] || fail "the symlink was changed without --force"
generate "$FX" --force || fail "generate-agents.sh --force errored"
[ -e "$WORK/outside/AGENTS.md" ] && fail "--force wrote the root AGENTS.md through the symlink"
is_regular "$FX/AGENTS.md" || fail "--force did not replace the symlink with the generated file"
pass "a dangling root symlink is kept, and --force replaces it"

# --- Test 2: --force does not write through a root symlink to an existing file
FX="$WORK/root-live"
make_fixture "$FX"
printf 'shared\n' > "$WORK/outside/shared.md"
ln -s ../outside/shared.md "$FX/AGENTS.md"
generate "$FX" --force || fail "generate-agents.sh errored"
[ "$(cat "$WORK/outside/shared.md")" = shared ] || fail "--force overwrote the symlink's target"
is_regular "$FX/AGENTS.md" || fail "--force did not replace the symlink"
pass "--force replaces a root symlink instead of overwriting its target"

# --- Test 3: the same for a scoped AGENTS.md
FX="$WORK/scope-live"
make_fixture "$FX"
printf 'scoped\n' > "$WORK/outside/scoped.md"
ln -s ../../outside/scoped.md "$FX/internal/AGENTS.md"
generate "$FX" || fail "generate-agents.sh errored"
[ "$(cat "$WORK/outside/scoped.md")" = scoped ] || fail "the scoped symlink was written through without --force"
generate "$FX" --force || fail "generate-agents.sh --force errored"
[ "$(cat "$WORK/outside/scoped.md")" = scoped ] || fail "--force overwrote the scoped symlink's target"
is_regular "$FX/internal/AGENTS.md" || fail "--force did not replace the scoped symlink"
pass "a scoped symlink is kept, and --force replaces it instead of writing through"

# --- Test 4: --update does not write through a symlink either
FX="$WORK/update"
make_fixture "$FX"
generate "$FX" || fail "generate-agents.sh errored"
cp "$FX/AGENTS.md" "$WORK/outside/generated.md"
cp "$WORK/outside/generated.md" "$WORK/outside/generated.orig"
rm "$FX/AGENTS.md"
ln -s ../outside/generated.md "$FX/AGENTS.md"
generate "$FX" --update || fail "generate-agents.sh --update errored"
cmp -s "$WORK/outside/generated.md" "$WORK/outside/generated.orig" || fail "--update wrote through the symlink"
is_regular "$FX/AGENTS.md" || fail "--update did not replace the symlink"
pass "--update replaces a symlink instead of writing through it"

# --- Test 5: a generated file gets the usual permissions, not a temp file's
FX="$WORK/mode"
make_fixture "$FX"
(umask 022 && generate "$FX") || fail "generate-agents.sh errored"
[ "$(stat -c %a "$FX/AGENTS.md" 2>/dev/null || stat -f %Lp "$FX/AGENTS.md")" = 644 ] \
    || fail "AGENTS.md is not mode 644 under umask 022"
pass "a generated AGENTS.md follows the umask"

echo ""
echo "All AGENTS.md write-boundary tests passed."
