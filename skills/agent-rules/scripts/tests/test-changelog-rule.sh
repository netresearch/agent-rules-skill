#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# The generated root AGENTS.md carries a "**Changelog:**" entry under Always Do
# (checkpoint AG-32). It names only what the tree shows: the changelog file and
# its format, a changelog.d/ fragment directory and its README, or a
# Documentation changelog page. Who writes the entry is not in the tree, so it
# stays a TODO for the agent, and a repository without any changelog gets a
# TODO instead of an invented location.
# shellcheck disable=SC2016  # the backticks in the expected text are markdown code spans
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE="$(dirname "$SCRIPT_DIR")/generate-agents.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# fixture NAME STYLE: a minimal Node project; the caller adds changelog files.
fixture() {
    local dir="$WORK/$1"
    mkdir -p "$dir"
    echo '{ "name": "fixture", "version": "1.0.0", "scripts": { "test": "vitest" } }' > "$dir/package.json"
    git -C "$dir" init -q
    echo "$dir"
}

# changelog_line DIR STYLE: generate, then print the entry (exactly one expected).
changelog_line() {
    bash "$GENERATE" "$1" --style="$2" >/dev/null 2>&1 || fail "generate-agents.sh errored for $1 ($2)"
    local n
    n=$(grep -c '^- \*\*Changelog:\*\* ' "$1/AGENTS.md" || true)
    [ "$n" = "1" ] || fail "$1 ($2): expected one **Changelog:** entry, found $n"
    grep '^- \*\*Changelog:\*\* ' "$1/AGENTS.md"
}

for style in thin verbose; do
    # Keep a Changelog file
    d=$(fixture "kac-$style")
    printf '# Changelog\n\nThe format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).\n\n## [Unreleased]\n' > "$d/CHANGELOG.md"
    line=$(changelog_line "$d" "$style")
    [[ "$line" == *'[`CHANGELOG.md`](CHANGELOG.md) (Keep a Changelog)'* ]] || fail "$style: file and format not named: $line"
    [[ "$line" == *'TODO: name which pull request writes the entry'* ]] || fail "$style: who-writes TODO missing: $line"
    pass "$style: CHANGELOG.md in Keep a Changelog format is named"

    # Fragment directory with a README
    d=$(fixture "frag-$style")
    printf '# Changelog\n' > "$d/CHANGELOG.md"
    mkdir -p "$d/changelog.d" && printf '# Fragments\n' > "$d/changelog.d/README.md"
    line=$(changelog_line "$d" "$style")
    [[ "$line" == *'fragment under `changelog.d/` (format: [`changelog.d/README.md`](changelog.d/README.md))'* ]] \
        || fail "$style: fragment directory not named: $line"
    [[ "$line" != *'(Keep a Changelog)'* ]] || fail "$style: format claimed for a file without the marker: $line"
    pass "$style: changelog.d/ and its README are named"

    # Only a Documentation changelog page
    d=$(fixture "docs-$style")
    mkdir -p "$d/Documentation/Changelog" && printf 'Changelog\n=========\n' > "$d/Documentation/Changelog/Index.rst"
    line=$(changelog_line "$d" "$style")
    [[ "$line" == *'[`Documentation/Changelog/Index.rst`](Documentation/Changelog/Index.rst)'* ]] \
        || fail "$style: docs page not named: $line"
    pass "$style: a Documentation changelog page counts when there is no file"

    # Nothing at all
    d=$(fixture "none-$style")
    line=$(changelog_line "$d" "$style")
    [[ "$line" == *'TODO: no changelog file found'* ]] || fail "$style: missing changelog not flagged: $line"
    pass "$style: no changelog is flagged, not invented"
done
