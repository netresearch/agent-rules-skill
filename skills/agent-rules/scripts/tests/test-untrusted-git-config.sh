#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# The scripts read the analysed project's history and file list with git. The
# project's .git/config is input like any other file, so a command it names in
# core.fsmonitor or a hook does not run. lib/git.sh holds the one wrapper all
# of them use.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

export GIT_CONFIG_GLOBAL=/dev/null
for script in generate-file-map.sh analyze-git-history.sh check-freshness.sh \
              detect-golden-samples.sh detect-utilities.sh \
              extract-github-settings.sh extract-github-rulesets.sh; do
    fx="$WORK/$script"
    mkdir -p "$fx/src"
    printf 'package main\n' > "$fx/src/main.go"
    printf '# AGENTS.md\n' > "$fx/AGENTS.md"
    git -C "$fx" init -q
    git -C "$fx" -c user.email=t@t.t -c user.name=t add -A
    git -C "$fx" -c user.email=t@t.t -c user.name=t commit -qm init
    git -C "$fx" config core.fsmonitor "touch $WORK/$script.ran; false"
    # A modified file makes git refresh the index, which is when it asks the
    # fsmonitor command.
    echo changed >> "$fx/src/main.go"
    (cd "$fx" && timeout 60 bash "$SCRIPTS_DIR/$script" "$fx" >/dev/null 2>&1)
    [ -e "$WORK/$script.ran" ] && fail "$script ran a command from the project's git config"
done
pass "no script runs a command named in the analysed project's git config"

echo ""
echo "All untrusted git config tests passed."
