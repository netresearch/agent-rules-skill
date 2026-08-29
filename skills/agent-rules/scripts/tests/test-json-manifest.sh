#!/usr/bin/env bash
# Test for the generate-agents.sh write manifest (issue #107).
#
# generate-agents.sh is the only script in the skill that writes, and was the
# only one without --json. The manifest lists one entry per path the run
# touches, so a caller can review exactly what would change (--dry-run) or what
# did change (without it) instead of parsing nine different prose lines.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
GENERATE="$SCRIPTS_DIR/generate-agents.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

make_fixture() {
    local fx="$1"
    mkdir -p "$fx/src"
    cat > "$fx/package.json" <<'JSON'
{ "name": "fixture", "version": "1.0.0", "scripts": { "test": "echo t" } }
JSON
    for i in 1 2 3 4 5 6; do printf 'export const c%s = %s\n' "$i" "$i" > "$fx/src/c$i.js"; done
    git -C "$fx" init -q
    git -C "$fx" -c user.email=t@t.t -c user.name=t add -A
    git -C "$fx" -c user.email=t@t.t -c user.name=t commit -qm init
}

# --- Test 1: --dry-run --json is valid JSON, carries the schema, writes nothing
FX="$WORK/plan"
make_fixture "$FX"
printf '# my own rules\n' > "$FX/GEMINI.md"
OUT="$(bash "$GENERATE" "$FX" --dry-run --json 2>/dev/null)" || fail "generate-agents.sh errored"
jq -e . >/dev/null 2>&1 <<<"$OUT" || fail "output is not valid JSON: $OUT"
[ "$(jq -r '.script' <<<"$OUT")" = "generate-agents" ] || fail "wrong script field"
[ "$(jq -r '.schema' <<<"$OUT")" = "1" ] || fail "wrong schema field"
[ "$(jq -r '.dry_run' <<<"$OUT")" = "true" ] || fail "dry_run not true under --dry-run"
[ -e "$FX/AGENTS.md" ] && fail "--dry-run --json wrote AGENTS.md"
[ -e "$FX/CLAUDE.md" ] && fail "--dry-run --json created a symlink"
pass "--dry-run --json emits a valid manifest and writes nothing"

# --- Test 2: human output is suppressed, so stdout is parseable
grep -q '✅' <<<"$OUT" && fail "human output leaked into the JSON stream"
pass "--json suppresses the prose output"

# --- Test 3: every operation kind appears, with the fields it needs
[ "$(jq -r '[.operations[] | select(.op=="write" and .path=="AGENTS.md")] | length' <<<"$OUT")" = "1" ] \
    || fail "root AGENTS.md missing from the manifest"
[ "$(jq -r '.operations[] | select(.path=="CLAUDE.md") | .target' <<<"$OUT")" = "AGENTS.md" ] \
    || fail "symlink entry has no target"
[ "$(jq -r '.operations[] | select(.path=="GEMINI.md") | .op' <<<"$OUT")" = "keep" ] \
    || fail "the kept regular file is not recorded as keep"
jq -e '.operations[] | select(.path=="GEMINI.md") | .reason' >/dev/null <<<"$OUT" \
    || fail "keep entry carries no reason"
pass "write, symlink and keep entries carry their fields"

# --- Test 4: paths are relative to the project root, never absolute
jq -e '[.operations[].path | select(startswith("/"))] | length == 0' >/dev/null <<<"$OUT" \
    || fail "manifest contains absolute paths"
pass "paths are relative to the project root"

# --- Test 5: the summary counts what the operations list holds
for op in write symlink keep; do
    want="$(jq -r --arg op "$op" '[.operations[] | select(.op==$op)] | length' <<<"$OUT")"
    got="$(jq -r --arg op "$op" '.summary[$op] // 0' <<<"$OUT")"
    [ "$want" = "$got" ] || fail "summary.$op says $got, operations hold $want"
done
pass "summary matches the operations list"

# --- Test 6: without --dry-run the same manifest is a receipt of real writes
FX="$WORK/receipt"
make_fixture "$FX"
OUT="$(bash "$GENERATE" "$FX" --json 2>/dev/null)" || fail "generate-agents.sh errored"
[ "$(jq -r '.dry_run' <<<"$OUT")" = "false" ] || fail "dry_run not false on a real run"
[ -f "$FX/AGENTS.md" ] || fail "real run wrote no AGENTS.md"
while read -r p; do
    [ -e "$FX/$p" ] || fail "manifest claims $p but it does not exist"
done < <(jq -r '.operations[] | select(.op!="keep") | .path' <<<"$OUT")
pass "every non-keep path in the receipt exists on disk"

# --- Test 7: the prose output still works without --json (companion)
FX="$WORK/prose"
make_fixture "$FX"
OUT="$(bash "$GENERATE" "$FX" --dry-run 2>/dev/null)" || fail "generate-agents.sh errored"
grep -q 'DRY-RUN' <<<"$OUT" || fail "prose output lost its DRY-RUN lines"
jq -e . >/dev/null 2>&1 <<<"$OUT" && fail "prose run emitted JSON"
pass "the default output is unchanged"

# --- Test 8: a file left alone is recorded, not merely absent from the list
# Without this, a consumer cannot tell "AGENTS.md was skipped because it exists"
# from "AGENTS.md was never considered" — both look like a missing entry.
FX="$WORK/second-run"
make_fixture "$FX"
bash "$GENERATE" "$FX" >/dev/null 2>&1 || fail "generate-agents.sh errored"
OUT="$(bash "$GENERATE" "$FX" --dry-run --json 2>/dev/null)" || fail "generate-agents.sh errored"
[ "$(jq -r '.operations[] | select(.path=="AGENTS.md") | .op' <<<"$OUT")" = "keep" ] \
    || fail "an existing AGENTS.md is not recorded as keep on a second run"
[ "$(jq -r '.operations[] | select(.path=="AGENTS.md") | .reason' <<<"$OUT")" = "already exists" ] \
    || fail "the keep entry for AGENTS.md carries no reason"
pass "an existing AGENTS.md is recorded as keep, with its reason"

# --- Test 9: --update writes, and the manifest says so
OUT="$(bash "$GENERATE" "$FX" --update --json 2>/dev/null)" || fail "generate-agents.sh errored"
[ "$(jq -r '.operations[] | select(.path=="AGENTS.md") | .op' <<<"$OUT")" = "write" ] \
    || fail "--update rewrote AGENTS.md without recording it as a write"
pass "--update records the rewrite it performs"

echo ""
echo "All JSON manifest tests passed."
