#!/usr/bin/env bash
# Regression test: a directory that already carries an AGENTS.md must appear in
# the root scope index, even when detect-scopes.sh has no rule for that
# directory name.
#
# The bug: the index was built purely from detected scopes. detect-scopes.sh
# knows a fixed set of directory names, so a hand-authored scoped file
# elsewhere (TYPO3 `Configuration/`, for one) was silently dropped from the
# root index on `--update`. An agent reading the root then never learns the
# file exists, which defeats the precedence rule the index exists to serve —
# and nothing reports the omission.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
DETECT="$SCRIPTS_DIR/detect-scopes.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# A PHP project with a scoped AGENTS.md in a directory the detector has no
# rule for, plus one it does recognise.
mkdir -p "$WORK/proj/Configuration" "$WORK/proj/Classes"
cat > "$WORK/proj/composer.json" <<'JSON'
{"name": "acme/thing", "require": {"php": "^8.2"}}
JSON
for i in 1 2 3 4 5 6; do
    echo "<?php" > "$WORK/proj/Classes/File$i.php"
    echo "services:" > "$WORK/proj/Configuration/Services$i.yaml"
done
cat > "$WORK/proj/Configuration/AGENTS.md" <<'MD'
# Configuration

## Overview
DI services, TCA and backend routes for this extension.
MD
echo "# root" > "$WORK/proj/AGENTS.md"

SCOPES=$(cd "$WORK/proj" && bash "$DETECT" . 2>/dev/null)

printf '%s' "$SCOPES" | jq -e '.scopes[] | select(.path == "Configuration")' >/dev/null 2>&1 \
    || fail "a directory with its own AGENTS.md was not reported as a scope"
pass "an existing scoped AGENTS.md is reported even without a detection rule"

# The root file itself must never be listed as a scope of itself.
if printf '%s' "$SCOPES" | jq -e '.scopes[] | select(.path == "." or .path == "AGENTS.md")' >/dev/null 2>&1; then
    fail "the root AGENTS.md was reported as its own scope"
fi
pass "the root AGENTS.md is not listed as a scope"

# A recognised directory keeps its specific type rather than being relabelled.
got=$(printf '%s' "$SCOPES" | jq -r '.scopes[] | select(.path == "Classes") | .type')
[ "$got" != "existing" ] && [ -n "$got" ] \
    || fail "a detected scope lost its type (got '$got')"
pass "a detected scope keeps its own type"

echo "All scope-index existing-file regression tests passed."
