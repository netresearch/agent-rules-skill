#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# Regression test for import-file handling in Documentation/ (issue #82) and
# for the rule that AGENTS.md is the only instruction file.
#
# The TYPO3 docs renderer lists Documentation/ via Flysystem, which aborts on
# any symbolic link, so a GEMINI.md -> AGENTS.md symlink there breaks docs CI.
# generate-agents.sh must emit a regular "@AGENTS.md" import file for
# Documentation/ scopes, create no CLAUDE.md anywhere, and validate-structure.sh
# must report a CLAUDE.md beside an AGENTS.md for removal.
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
[ -e "$FX/Documentation/GEMINI.md" ] || fail "no Documentation/GEMINI.md generated"
if [[ -L "$FX/Documentation/GEMINI.md" ]]; then
    fail "Documentation/GEMINI.md is a symlink -- breaks TYPO3 docs rendering (#82)"
fi
grep -qE '^@AGENTS\.md[[:space:]]*$' "$FX/Documentation/GEMINI.md" \
    || fail "Documentation/GEMINI.md lacks the @AGENTS.md import line"
pass "generator emits @AGENTS.md import file in Documentation/"

# Non-hostile scope dirs still get a GEMINI.md symlink; no CLAUDE.md anywhere.
[ -L "$FX/src/GEMINI.md" ] || fail "src/GEMINI.md should be a symlink (src scope needs >=5 source files)"
for d in . src Documentation; do
    { [[ -e "$FX/$d/CLAUDE.md" ]] || [[ -L "$FX/$d/CLAUDE.md" ]]; } && fail "a CLAUDE.md was created in $d"
done
pass "non-hostile scope dirs get GEMINI.md symlinks, and no CLAUDE.md is created"

# --- Test 2: the validator is quiet without a CLAUDE.md --------------------
out=$(bash "$VALIDATE" "$FX" 2>&1)
grep -q "Remove CLAUDE.md" <<<"$out" && fail "validate-structure.sh warns although no CLAUDE.md exists"
pass "validator accepts AGENTS.md without a CLAUDE.md"

# --- Test 3: a CLAUDE.md beside an AGENTS.md is reported for removal -------
for kind in import symlink; do
    rm -f "$FX/Documentation/CLAUDE.md"
    case "$kind" in
        import) printf '@AGENTS.md\n' > "$FX/Documentation/CLAUDE.md" ;;
        symlink) ln -s AGENTS.md "$FX/Documentation/CLAUDE.md" ;;
        *) fail "unknown kind: $kind" ;;
    esac
    out=$(bash "$VALIDATE" "$FX" 2>&1)
    grep -q "Remove CLAUDE.md.*Documentation" <<<"$out" \
        || fail "validate-structure.sh does not report a CLAUDE.md ($kind) for removal (output was: $out)"
done
rm -f "$FX/Documentation/CLAUDE.md"
printf '# my notes\n' > "$FX/CLAUDE.local.md"
out=$(bash "$VALIDATE" "$FX" 2>&1)
grep -q "Remove CLAUDE.local.md" <<<"$out" \
    || fail "validate-structure.sh does not report a CLAUDE.local.md (output was: $out)"
rm -f "$FX/CLAUDE.local.md"
pass "a CLAUDE.md beside an AGENTS.md, import or symlink, and a CLAUDE.local.md are reported for removal"

echo "All import-file and no-CLAUDE.md regression tests passed."
