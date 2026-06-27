#!/usr/bin/env bash
# Regression test for the scope-index heading contract between
# generate-agents.sh and validate-structure.sh (issue #55).
#
# generate-agents.sh emits the root scope index under the heading
#   "## Scoped AGENTS.md (MUST read when working in these directories)"
# while older output used the legacy heading
#   "## Index of scoped AGENTS.md".
# validate-structure.sh must accept BOTH so a freshly generated root does not
# fail the skill's own structure validation, while a bloated root without any
# scope index still fails.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
GENERATE="$SCRIPTS_DIR/generate-agents.sh"
VALIDATE="$SCRIPTS_DIR/validate-structure.sh"

NEW_HEADING='## Scoped AGENTS.md (MUST read when working in these directories)'
LEGACY_HEADING='## Index of scoped AGENTS.md'

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# Build a minimal repo with a scoped directory so the generated root exceeds
# 50 lines and includes a populated scope index.
build_fixture() {
    local dir="$1"
    rm -rf "$dir"
    mkdir -p "$dir/src" "$dir/.github/workflows"
    cat > "$dir/package.json" <<'JSON'
{ "name": "fixture", "version": "1.0.0", "scripts": { "test": "vitest", "build": "tsc" } }
JSON
    echo "console.log('hi')" > "$dir/src/index.ts"
    echo "name: ci" > "$dir/.github/workflows/ci.yml"
    git -C "$dir" init -q
    git -C "$dir" -c user.email=t@t.t -c user.name=t add -A
    git -C "$dir" -c user.email=t@t.t -c user.name=t commit -qm init
}

# --- Test 1: generated root (new heading) passes validation -----------------
FX1="$WORK/new-heading"
build_fixture "$FX1"
bash "$GENERATE" "$FX1" --style=thin >/dev/null 2>&1 || fail "generate-agents.sh errored"

grep -qF "$NEW_HEADING" "$FX1/AGENTS.md" \
    || fail "generator no longer emits the expected heading: $NEW_HEADING"
lines=$(wc -l < "$FX1/AGENTS.md")
[ "$lines" -gt 50 ] || fail "generated root is only $lines lines; expected >50 to exercise the scope-index path"

if bash "$VALIDATE" "$FX1" >/dev/null 2>&1; then
    pass "generated root ($lines lines, new heading) validates"
else
    fail "validate-structure.sh rejected a freshly generated root (#55 regression)"
fi

# --- Test 2: legacy heading still accepted (backward compatibility) ----------
FX2="$WORK/legacy-heading"
cp -r "$FX1" "$FX2"
# Rewrite only the heading line, keeping the rest of the generated root intact.
sed -i "s|^${NEW_HEADING}\$|${LEGACY_HEADING}|" "$FX2/AGENTS.md"
grep -qF "$LEGACY_HEADING" "$FX2/AGENTS.md" || fail "could not rewrite heading to legacy form"

if bash "$VALIDATE" "$FX2" >/dev/null 2>&1; then
    pass "root with legacy heading still validates (backward compatible)"
else
    fail "validate-structure.sh rejected the legacy scope-index heading"
fi

# --- Test 3: bloated root without any scope index still fails ----------------
FX3="$WORK/no-heading"
cp -r "$FX1" "$FX3"
# Drop the scope-index heading so the >50-line root has no index at all.
sed -i "/^${NEW_HEADING}\$/d" "$FX3/AGENTS.md"

if bash "$VALIDATE" "$FX3" >/dev/null 2>&1; then
    fail "validate-structure.sh accepted a bloated root with no scope index"
else
    pass "bloated root without a scope index is still rejected"
fi

echo "All scope-index heading regression tests passed."
