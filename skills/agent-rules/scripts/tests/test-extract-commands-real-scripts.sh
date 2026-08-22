#!/usr/bin/env bash
# Regression test: extract-commands.sh must emit the composer script that the
# project actually defines, never the first name it happened to look for.
#
# The bug: the PHP branch accepted `.scripts.format // .scripts["cs:fix"]` as
# evidence and then printed `composer run format` unconditionally. A project
# defining only `cs:fix` therefore had `composer run format` written into its
# AGENTS.md — a command that does not exist, presented to agents as fact.
# The same shape applied to `lint` (via `cs:check`) and `phpstan` (via `stan`).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT="$(dirname "$SCRIPT_DIR")/extract-commands.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# A PHP project whose scripts use the alternate names only.
mkdir -p "$WORK/alt"
cat > "$WORK/alt/composer.json" <<'JSON'
{
  "name": "acme/alt-names",
  "require": {"php": "^8.2"},
  "scripts": {
    "cs:fix": "php-cs-fixer fix",
    "cs:check": "php-cs-fixer fix --dry-run",
    "stan": "phpstan analyse"
  }
}
JSON

OUT=$(bash "$EXTRACT" "$WORK/alt" 2>/dev/null)

for pair in "format:cs:fix" "lint:cs:check" "typecheck:stan"; do
    field="${pair%%:*}"
    want="composer run ${pair#*:}"
    got=$(printf '%s' "$OUT" | jq -r --arg f "$field" '.[$f] // ""')
    [ "$got" = "$want" ] || fail "$field: expected '$want', got '$got'"
done
pass "alternate script names are emitted as themselves"

# Every emitted `composer run X` must name a script the project defines.
# This is the invariant the bug violated, stated independently of which
# names the extractor happens to prefer today.
while read -r key; do
    [ -n "$key" ] || continue
    jq -e --arg k "$key" '.scripts[$k]' "$WORK/alt/composer.json" >/dev/null 2>&1 \
        || fail "extractor emitted 'composer run $key', which composer.json does not define"
done < <(printf '%s' "$OUT" | jq -r '.[] | select(type == "string") | select(startswith("composer run ")) | sub("composer run ";"")')
pass "every emitted composer command exists in composer.json"

# The preferred names still win when they are present.
mkdir -p "$WORK/std"
cat > "$WORK/std/composer.json" <<'JSON'
{
  "name": "acme/standard-names",
  "require": {"php": "^8.2"},
  "scripts": {"format": "php-cs-fixer fix", "cs:fix": "should not be chosen"}
}
JSON
got=$(bash "$EXTRACT" "$WORK/std" 2>/dev/null | jq -r '.format')
[ "$got" = "composer run format" ] || fail "preferred name not chosen: got '$got'"
pass "the preferred script name still wins when defined"

echo "All extract-commands script-name regression tests passed."
