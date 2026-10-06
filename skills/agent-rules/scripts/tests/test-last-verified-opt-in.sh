#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# verify-commands.sh checks AGENTS.md; it changes the file only when asked.
# A plain run leaves AGENTS.md byte for byte as it was, so running the check
# (in CI, as a local gate) never leaves a modified file behind. With
# --update-verified, a successful run records the date in the "Last verified"
# marker.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
VERIFY="$SCRIPTS_DIR/verify-commands.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

FX="$WORK/project"
mkdir -p "$FX"
# shellcheck disable=SC2016  # backticks are markdown, not substitution
printf '<!-- Last updated: 2026-01-01 | Last verified: never -->\n# Fixture\n\n## Commands\n\n| Command | Purpose |\n|---|---|\n| `ls -la` | list |\n' > "$FX/AGENTS.md"
cp "$FX/AGENTS.md" "$WORK/before.md"

(cd "$FX" && bash "$VERIFY" . >/dev/null 2>&1) || fail "verify-commands.sh errored"
cmp -s "$FX/AGENTS.md" "$WORK/before.md" || fail "a plain run modified AGENTS.md"
pass "a plain run leaves AGENTS.md unchanged"

(cd "$FX" && bash "$VERIFY" . --update-verified >/dev/null 2>&1) || fail "verify-commands.sh --update-verified errored"
grep -q "Last verified: $(date +%Y-%m-%d) -->" "$FX/AGENTS.md" \
    || fail "--update-verified did not record today's date (file: $(head -1 "$FX/AGENTS.md"))"
pass "--update-verified records the date in the Last verified marker"

echo ""
echo "All Last verified tests passed."
