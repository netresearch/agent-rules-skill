#!/usr/bin/env bash
# Regression test for CLAUDE.md import-file handling (issue #82).
#
# The TYPO3 docs renderer lists Documentation/ via Flysystem, which aborts on
# any symbolic link, so a CLAUDE.md -> AGENTS.md symlink there breaks docs CI.
# generate-agents.sh must emit a regular "@AGENTS.md" import file for
# Documentation/ scopes, and validate-structure.sh must accept that file as
# fully valid, while still warning on other regular CLAUDE.md files.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
GENERATE="$SCRIPTS_DIR/generate-agents.sh"
VALIDATE="$SCRIPTS_DIR/validate-structure.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# PHP fixture with a Documentation/ scope (>=3 RST files) and enough source
# files that generate-agents.sh emits a root plus scoped files.
FX="$WORK/php-docs"
mkdir -p "$FX/src" "$FX/Documentation"
cat > "$FX/composer.json" <<'JSON'
{ "name": "acme/fixture", "require": { "php": "^8.2" }, "scripts": { "test": "phpunit" } }
JSON
# detect-scopes.sh needs MIN_FILES=5 source files for an src scope.
for i in 1 2 3 4 5; do printf '<?php\nclass C%s {}\n' "$i" > "$FX/src/C$i.php"; done
for i in 1 2 3; do printf 'Chapter %s\n=========\n' "$i" > "$FX/Documentation/Ch$i.rst"; done
git -C "$FX" init -q
git -C "$FX" -c user.email=t@t.t -c user.name=t add -A
git -C "$FX" -c user.email=t@t.t -c user.name=t commit -qm init

# --- Test 1: generator emits an import FILE, not a symlink, in Documentation/
bash "$GENERATE" "$FX" --style=thin >/dev/null 2>&1 || fail "generate-agents.sh errored"
[ -f "$FX/Documentation/AGENTS.md" ] \
    || fail "fixture did not produce a scoped Documentation/AGENTS.md (scope not detected; fix the fixture)"
[ -e "$FX/Documentation/CLAUDE.md" ] || fail "no Documentation/CLAUDE.md generated"
if [ -L "$FX/Documentation/CLAUDE.md" ]; then
    fail "Documentation/CLAUDE.md is a symlink -- breaks TYPO3 docs rendering (#82)"
fi
grep -qE '^@AGENTS\.md[[:space:]]*$' "$FX/Documentation/CLAUDE.md" \
    || fail "Documentation/CLAUDE.md lacks the @AGENTS.md import line"
pass "generator emits @AGENTS.md import file in Documentation/"

# Non-hostile scope dirs must still get symlinks.
[ -e "$FX/src/CLAUDE.md" ] || fail "no src/CLAUDE.md generated (src scope not detected; fixture needs >=5 source files)"
[ -L "$FX/src/CLAUDE.md" ] || fail "src/CLAUDE.md should still be a symlink"
pass "non-hostile scope dirs still get symlinks"

# --- Test 2: validator accepts the import file without a warning -------------
out=$(bash "$VALIDATE" "$FX" 2>&1)
if echo "$out" | grep -q "CLAUDE.md is a regular file"; then
    fail "validate-structure.sh still warns about the @AGENTS.md import file"
fi
pass "validator accepts the @AGENTS.md import file"

# --- Test 3: a regular CLAUDE.md without the import still warns --------------
printf 'unrelated content\n' > "$FX/Documentation/CLAUDE.md"
out=$(bash "$VALIDATE" "$FX" 2>&1)
if ! echo "$out" | grep -q "CLAUDE.md is a regular file"; then
    fail "validate-structure.sh no longer warns about a non-import regular CLAUDE.md"
fi
pass "non-import regular CLAUDE.md still warns"

echo "All CLAUDE.md import-file regression tests passed."
