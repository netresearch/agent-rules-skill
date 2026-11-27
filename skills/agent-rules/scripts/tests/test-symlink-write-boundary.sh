#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# Regression test for the GEMINI.md write boundary (issues #102, #103) and
# the removal of CLAUDE.md (AGENTS.md is the only instruction file).
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

# --- Test 2: the default creates GEMINI.md and no CLAUDE.md
FX="$WORK/default"
make_fixture "$FX"
bash "$GENERATE" "$FX" >/dev/null 2>&1 || fail "generate-agents.sh errored"
[ -L "$FX/GEMINI.md" ] || fail "default run did not symlink GEMINI.md"
[[ "$(readlink "$FX/GEMINI.md")" = "AGENTS.md" ]] || fail "GEMINI.md points elsewhere"
[[ -e "$FX/CLAUDE.md" ]] || [[ -L "$FX/CLAUDE.md" ]] && fail "default run created a CLAUDE.md"
pass "default run symlinks GEMINI.md → AGENTS.md and creates no CLAUDE.md"

# --- Test 3 (#103): a foreign symlink is kept, and the user is told
FX="$WORK/foreign-link"
make_fixture "$FX"
mkdir -p "$WORK/shared"
printf '# curated rules\n' > "$WORK/shared/GEMINI.md"
ln -s ../shared/GEMINI.md "$FX/GEMINI.md"
OUT="$(bash "$GENERATE" "$FX" 2>&1)" || fail "generate-agents.sh errored"
[[ "$(readlink "$FX/GEMINI.md")" = "../shared/GEMINI.md" ]] \
    || fail "foreign GEMINI.md symlink was repointed without --force"
grep -q "Kept: " <<<"$OUT" || fail "no notice printed for the kept file (output was: $OUT)"
pass "foreign GEMINI.md symlink kept, notice printed"

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
ln -s ../shared/GEMINI.md "$FX/GEMINI.md"
bash "$GENERATE" "$FX" --force --dry-run >/dev/null 2>&1 || fail "generate-agents.sh errored"
[[ "$(readlink "$FX/GEMINI.md")" = "../shared/GEMINI.md" ]] \
    || fail "--dry-run --force modified the tree"
bash "$GENERATE" "$FX" --force >/dev/null 2>&1 || fail "generate-agents.sh errored"
[[ "$(readlink "$FX/GEMINI.md")" = "AGENTS.md" ]] || fail "--force did not replace the foreign symlink"
pass "--force replaces, --dry-run --force does not"

# --- Test 6: a second run over our own symlink is a no-op, not a "Kept" notice
FX="$WORK/idempotent"
make_fixture "$FX"
bash "$GENERATE" "$FX" >/dev/null 2>&1 || fail "generate-agents.sh errored"
OUT="$(bash "$GENERATE" "$FX" 2>&1)" || fail "generate-agents.sh errored on second run"
grep -q "Kept: GEMINI.md" <<<"$OUT" && fail "our own symlink was reported as a foreign file"
[[ "$(readlink "$FX/GEMINI.md")" = "AGENTS.md" ]] || fail "second run broke GEMINI.md"
pass "re-running keeps our own symlink without a notice"

# --- Test 7: AGENTS.md is the only instruction file. A CLAUDE.md the
# generator made earlier (symlink, @AGENTS.md import, old shim) is removed,
# also with --no-symlinks, and --dry-run only reports it.
for kind in symlink import shim; do
    FX="$WORK/own-claude-$kind"
    make_fixture "$FX"
    case "$kind" in
        symlink) ln -s AGENTS.md "$FX/CLAUDE.md" ;;
        import) printf '@AGENTS.md\n' > "$FX/CLAUDE.md" ;;
        shim) printf '<!-- Auto-generated shim for Claude Code compatibility -->\n\n@import AGENTS.md\n' > "$FX/CLAUDE.md" ;;
        *) fail "unknown kind: $kind" ;;
    esac
    bash "$GENERATE" "$FX" --no-symlinks --dry-run >/dev/null 2>&1 || fail "generate-agents.sh errored"
    { [[ -e "$FX/CLAUDE.md" ]] || [[ -L "$FX/CLAUDE.md" ]]; } || fail "--dry-run removed our own CLAUDE.md ($kind)"
    bash "$GENERATE" "$FX" --no-symlinks >/dev/null 2>&1 || fail "generate-agents.sh errored"
    { [[ -e "$FX/CLAUDE.md" ]] || [[ -L "$FX/CLAUDE.md" ]]; } && fail "our own CLAUDE.md ($kind) was not removed"
done
pass "a CLAUDE.md the generator made (symlink, import, shim) is removed; --dry-run keeps it"

# --- Test 8: a CLAUDE.md of the user's own is kept and reported, also with
# --force while it holds rules. --force removes a CLAUDE.md symlink only when
# it points to the AGENTS.md of its directory; a symlink to any other target
# is kept, named in the report, and never written through.
FX="$WORK/user-claude"
make_fixture "$FX"
printf '# my own rules\n' > "$FX/CLAUDE.md"
OUT="$(bash "$GENERATE" "$FX" 2>&1)" || fail "generate-agents.sh errored"
grep -qx '# my own rules' "$FX/CLAUDE.md" || fail "a user CLAUDE.md was changed without --force"
grep -q "Kept: CLAUDE.md" <<<"$OUT" || fail "a kept user CLAUDE.md was not reported (output was: $OUT)"
grep -q "move its rules into AGENTS.md" <<<"$OUT" || fail "the kept CLAUDE.md report does not say to move its rules first (output was: $OUT)"
OUT="$(bash "$GENERATE" "$FX" --force 2>&1)" || fail "generate-agents.sh errored"
grep -qx '# my own rules' "$FX/CLAUDE.md" || fail "--force deleted a user CLAUDE.md that holds rules"
FX="$WORK/dangling-claude"
make_fixture "$FX"
mkdir -p "$WORK/claude-target"
ln -s ../claude-target/CLAUDE.md "$FX/CLAUDE.md"
bash "$GENERATE" "$FX" >/dev/null 2>&1 || fail "generate-agents.sh errored"
[[ "$(readlink "$FX/CLAUDE.md")" = "../claude-target/CLAUDE.md" ]] || fail "a foreign CLAUDE.md symlink was removed without --force"
OUT="$(bash "$GENERATE" "$FX" --force 2>&1)" || fail "generate-agents.sh errored"
[[ "$(readlink "$FX/CLAUDE.md")" = "../claude-target/CLAUDE.md" ]] || fail "--force removed a CLAUDE.md symlink to another target"
grep -q "Kept: CLAUDE.md despite --force" <<<"$OUT" || fail "--force did not report the kept CLAUDE.md symlink (output was: $OUT)"
grep -qF "../claude-target/CLAUDE.md" <<<"$OUT" || fail "the report does not name the symlink target (output was: $OUT)"
[[ -e "$WORK/claude-target/CLAUDE.md" ]] && fail "a file was written through the CLAUDE.md symlink"
FX2="$WORK/own-claude-link-force"
make_fixture "$FX2"
ln -s AGENTS.md "$FX2/CLAUDE.md"
bash "$GENERATE" "$FX2" --force >/dev/null 2>&1 || fail "generate-agents.sh errored"
[[ -L "$FX2/CLAUDE.md" ]] && fail "--force did not remove a CLAUDE.md symlink to the AGENTS.md of its directory"
FX="$WORK/claude-shim"
make_fixture "$FX"
OUT="$(bash "$GENERATE" "$FX" --claude-shim 2>&1)" || fail "generate-agents.sh errored with --claude-shim"
{ [[ -e "$FX/CLAUDE.md" ]] || [[ -L "$FX/CLAUDE.md" ]]; } && fail "--claude-shim created a CLAUDE.md"
grep -q -- "--claude-shim is ignored" <<<"$OUT" || fail "--claude-shim gave no notice (output was: $OUT)"
pass "a user CLAUDE.md is kept and reported (also with --force); --force removes a symlink to AGENTS.md but keeps one to another target; --claude-shim creates none"

# --- Test 9: a user's CLAUDE.md that also imports AGENTS.md is still theirs
FX="$WORK/user-claude-import"
make_fixture "$FX"
printf '# My team rules\n\nNever push to main.\n\n@AGENTS.md\n' > "$FX/CLAUDE.md"
OUT="$(bash "$GENERATE" "$FX" 2>&1)" || fail "generate-agents.sh errored"
grep -qx 'Never push to main.' "$FX/CLAUDE.md" || fail "a user CLAUDE.md with an @AGENTS.md line was removed without --force"
grep -q "Kept: CLAUDE.md" <<<"$OUT" || fail "the kept user CLAUDE.md was not reported (output was: $OUT)"
# --force does not delete a CLAUDE.md whose body is more than the import line,
# and says why; --dry-run --force plans to keep it.
OUT="$(bash "$GENERATE" "$FX" --dry-run --force --json 2>/dev/null)" || fail "generate-agents.sh errored"
[[ "$(jq -r '[.operations[] | select(.op == "remove" and .path == "CLAUDE.md")] | length' <<<"$OUT")" = 0 ]] \
    || fail "--dry-run --force plans to remove a user CLAUDE.md with rules (output was: $OUT)"
[[ "$(jq -r '[.operations[] | select(.op == "keep" and .path == "CLAUDE.md")] | length' <<<"$OUT")" = 1 ]] \
    || fail "--dry-run --force does not plan to keep a user CLAUDE.md with rules (output was: $OUT)"
OUT="$(bash "$GENERATE" "$FX" --force 2>&1)" || fail "generate-agents.sh errored"
grep -qx 'Never push to main.' "$FX/CLAUDE.md" || fail "--force deleted a user CLAUDE.md with rules beside its @AGENTS.md line"
grep -q "Kept: CLAUDE.md despite --force" <<<"$OUT" || fail "--force did not report why it kept CLAUDE.md (output was: $OUT)"
grep -q "move its rules into AGENTS.md" <<<"$OUT" || fail "--force did not say to move the rules first (output was: $OUT)"
pass "a user CLAUDE.md with its own rules and an @AGENTS.md line is kept, also with --force"

# --- Test 10: CLAUDE.md files the old generator left beside existing scoped
# AGENTS.md files are removed on a default run, and --dry-run --json plans it
FX="$WORK/migrate"
make_fixture "$FX"
bash "$GENERATE" "$FX" --no-symlinks >/dev/null 2>&1 || fail "generate-agents.sh errored"
mkdir -p "$FX/lib" "$FX/Documentation"
printf '# lib\n' > "$FX/lib/AGENTS.md"
ln -s AGENTS.md "$FX/lib/CLAUDE.md"
printf '# docs\n' > "$FX/Documentation/AGENTS.md"
printf '<!-- Regular file, not a symlink -->\n\n@AGENTS.md\n' > "$FX/Documentation/CLAUDE.md"
OUT="$(bash "$GENERATE" "$FX" --dry-run --json 2>/dev/null)" || fail "generate-agents.sh errored"
for p in lib/CLAUDE.md Documentation/CLAUDE.md; do
    [[ "$(jq -r --arg p "$p" '[.operations[] | select(.op == "remove" and .path == $p)] | length' <<<"$OUT")" = 1 ]] \
        || fail "--dry-run --json does not plan the removal of $p (output was: $OUT)"
    { [[ -e "$FX/$p" ]] || [[ -L "$FX/$p" ]]; } || fail "--dry-run removed $p"
done
bash "$GENERATE" "$FX" >/dev/null 2>&1 || fail "generate-agents.sh errored"
for p in lib/CLAUDE.md Documentation/CLAUDE.md; do
    { [[ -e "$FX/$p" ]] || [[ -L "$FX/$p" ]]; } && fail "a default run left the generated $p"
done
pass "generated CLAUDE.md files beside existing AGENTS.md files are removed, and planned under --dry-run"

echo ""
echo "All symlink write-boundary tests passed."
