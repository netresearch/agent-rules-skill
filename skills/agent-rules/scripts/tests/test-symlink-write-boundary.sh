#!/usr/bin/env bash
# Regression test for the CLAUDE.md/GEMINI.md write boundary (issues #102, #103).
#
# Two defects, both in generate-agents.sh:
#   #102  --no-symlinks was documented in --help but dropped by the parser, so
#         the symlinks were created regardless of the flag.
#   #103  an existing CLAUDE.md that is itself a symlink was treated like a
#         missing file and repointed to AGENTS.md — no --force, no message —
#         because the guard tested "[ -L ] || [ ! -e ]".
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
GENERATE="$SCRIPTS_DIR/generate-agents.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# Minimal JS fixture: enough for a root AGENTS.md, no scopes needed.
make_fixture() {
    local fx="$1"
    mkdir -p "$fx/src"
    cat > "$fx/package.json" <<'JSON'
{ "name": "fixture", "version": "1.0.0", "scripts": { "test": "echo t" } }
JSON
    for i in 1 2 3 4 5; do printf 'export const c%s = %s\n' "$i" "$i" > "$fx/src/c$i.js"; done
    git -C "$fx" init -q
    git -C "$fx" -c user.email=t@t.t -c user.name=t add -A
    git -C "$fx" -c user.email=t@t.t -c user.name=t commit -qm init
}

# --- Test 1 (#102): --no-symlinks suppresses both compatibility files
FX="$WORK/no-symlinks"
make_fixture "$FX"
bash "$GENERATE" "$FX" --no-symlinks >/dev/null 2>&1 || fail "generate-agents.sh errored"
[ -f "$FX/AGENTS.md" ] || fail "--no-symlinks suppressed AGENTS.md itself"
[ -e "$FX/CLAUDE.md" ] && fail "--no-symlinks still created CLAUDE.md"
[ -e "$FX/GEMINI.md" ] && fail "--no-symlinks still created GEMINI.md"
pass "--no-symlinks creates AGENTS.md and no compatibility files"

# --- Test 2: the default still creates them (companion to test 1)
FX="$WORK/default"
make_fixture "$FX"
bash "$GENERATE" "$FX" >/dev/null 2>&1 || fail "generate-agents.sh errored"
[ -L "$FX/CLAUDE.md" ] || fail "default run did not symlink CLAUDE.md"
[ "$(readlink "$FX/CLAUDE.md")" = "AGENTS.md" ] || fail "CLAUDE.md points elsewhere"
pass "default run symlinks CLAUDE.md → AGENTS.md"

# --- Test 3 (#103): a foreign symlink is kept, and the user is told
FX="$WORK/foreign-link"
make_fixture "$FX"
mkdir -p "$WORK/shared"
printf '# curated rules\n' > "$WORK/shared/CLAUDE.md"
ln -s ../shared/CLAUDE.md "$FX/CLAUDE.md"
OUT="$(bash "$GENERATE" "$FX" 2>&1)" || fail "generate-agents.sh errored"
[ "$(readlink "$FX/CLAUDE.md")" = "../shared/CLAUDE.md" ] \
    || fail "foreign CLAUDE.md symlink was repointed without --force"
grep -q "Kept: " <<<"$OUT" || fail "no notice printed for the kept file (output was: $OUT)"
pass "foreign CLAUDE.md symlink kept, notice printed"

# --- Test 4: a regular foreign file is kept too, and reported
FX="$WORK/foreign-file"
make_fixture "$FX"
printf '# my own rules\n' > "$FX/GEMINI.md"
OUT="$(bash "$GENERATE" "$FX" 2>&1)" || fail "generate-agents.sh errored"
grep -qx '# my own rules' "$FX/GEMINI.md" || fail "regular GEMINI.md was overwritten"
grep -q "Kept: GEMINI.md" <<<"$OUT" || fail "no notice printed for kept GEMINI.md (output was: $OUT)"
pass "regular GEMINI.md kept, notice printed"

# --- Test 5: --force replaces a foreign symlink, --dry-run --force does not
FX="$WORK/force"
make_fixture "$FX"
ln -s ../shared/CLAUDE.md "$FX/CLAUDE.md"
bash "$GENERATE" "$FX" --force --dry-run >/dev/null 2>&1 || fail "generate-agents.sh errored"
[ "$(readlink "$FX/CLAUDE.md")" = "../shared/CLAUDE.md" ] \
    || fail "--dry-run --force modified the tree"
bash "$GENERATE" "$FX" --force >/dev/null 2>&1 || fail "generate-agents.sh errored"
[ "$(readlink "$FX/CLAUDE.md")" = "AGENTS.md" ] || fail "--force did not replace the foreign symlink"
pass "--force replaces, --dry-run --force does not"

# --- Test 6: a second run over our own symlink is a no-op, not a "Kept" notice
FX="$WORK/idempotent"
make_fixture "$FX"
bash "$GENERATE" "$FX" >/dev/null 2>&1 || fail "generate-agents.sh errored"
OUT="$(bash "$GENERATE" "$FX" 2>&1)" || fail "generate-agents.sh errored on second run"
grep -q "Kept: CLAUDE.md" <<<"$OUT" && fail "our own symlink was reported as a foreign file"
[ "$(readlink "$FX/CLAUDE.md")" = "AGENTS.md" ] || fail "second run broke CLAUDE.md"
pass "re-running keeps our own symlink without a notice"

echo ""
echo "All symlink write-boundary tests passed."
