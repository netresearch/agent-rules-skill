#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# The scripts read the analysed project's history and file list with git. The
# project's .git/config is input like any other file, so a command it names in
# core.fsmonitor, a hook or the signature program does not run. lib/git.sh
# holds the one wrapper all of them use.
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
    [ $? -eq 124 ] && fail "$script timed out"
    [ -e "$WORK/$script.ran" ] && fail "$script ran a command from the project's git config"
done
pass "no script runs the core.fsmonitor command of the analysed project"

# log.showSignature makes git log verify every signed commit with the
# signature program the project's config names.
if command -v ssh-keygen >/dev/null 2>&1; then
    fx="$WORK/signed"
    git init -q "$fx"
    echo a > "$fx/a"
    git -C "$fx" add a
    ssh-keygen -q -t ed25519 -N '' -f "$WORK/key"
    git -C "$fx" -c user.email=t@t.t -c user.name=t -c gpg.format=ssh \
        -c user.signingkey="$WORK/key" commit -q -S -m init
    echo "t@t.t $(cat "$WORK/key.pub")" > "$fx/.allowed"
    printf '#!/bin/sh\ntouch %s/signature.ran\nexit 1\n' "$WORK" > "$WORK/fake-ssh-keygen"
    chmod +x "$WORK/fake-ssh-keygen"
    git -C "$fx" config gpg.format ssh
    git -C "$fx" config gpg.ssh.program "$WORK/fake-ssh-keygen"
    git -C "$fx" config gpg.ssh.allowedSignersFile .allowed
    git -C "$fx" config log.showSignature true
    for script in analyze-git-history.sh check-freshness.sh detect-golden-samples.sh; do
        (cd "$fx" && timeout 60 bash "$SCRIPTS_DIR/$script" "$fx" >/dev/null 2>&1)
        [ $? -eq 124 ] && fail "$script timed out"
        [ -e "$WORK/signature.ran" ] && fail "$script ran the signature program of the project's git config"
    done
    pass "no script runs the signature program of the analysed project"
else
    echo "⚠️  SKIP: ssh-keygen not found, signature program case not run"
fi

echo ""
echo "All untrusted git config tests passed."
