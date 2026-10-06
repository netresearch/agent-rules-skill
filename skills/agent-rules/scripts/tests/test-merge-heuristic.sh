#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# The "Merging PRs" heuristic in a generated AGENTS.md is guessed from git
# history. When the repository's settings are known, the advice never names a
# merge method they do not allow, and when they allow exactly one, that one is
# the advice. Without settings (no gh login, not GitHub), the history guess
# stands as before.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
GENERATE="$SCRIPTS_DIR/generate-agents.sh"

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

eval "$(awk '/^build_workflow_info\(\) \{/,/^\}/' "$GENERATE")"

pr_line() { # pr_line <history strategy> <settings json>
    build_workflow_info "{\"merge_strategy\":{\"strategy\":\"$1\"}}" "$2" | grep '^- PRs:' || true
}
expect() { # expect <history> <settings> <wanted line or empty>
    local got
    got="$(pr_line "$1" "$2")"
    [ "$got" = "$3" ] || fail "history=$1 settings=$2: want '$3', got '$got'"
}

expect squash-and-merge '{"merge_strategies":["merge"]}' '- PRs: Create merge commits'
expect squash-and-merge '{"merge_strategies":["rebase"]}' '- PRs: Rebase and merge'
expect merge-commits '{"merge_strategies":["squash","rebase"]}' ''
expect mixed '{"merge_strategies":["merge"]}' '- PRs: Create merge commits'
pass "a merge method the settings do not allow is never advised"

expect squash-and-merge '{"merge_strategies":["squash","merge"]}' '- PRs: Squash and merge'
expect squash-and-merge '{}' '- PRs: Squash and merge'
expect merge-commits '{}' '- PRs: Create merge commits'
expect mixed '{}' ''
pass "without settings, or when they allow it, the history guess stands"

echo ""
echo "All merge heuristic tests passed."
