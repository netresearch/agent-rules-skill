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

# A partial clone fetches a missing object from its promisor remote on demand,
# running the transport command the project's config names.
fx="$WORK/partial"
mkdir -p "$fx/src"
printf 'package main\n' > "$fx/src/main.go"
# An old "Last updated" date makes check-freshness.sh list the commits since.
printf '<!-- Last updated: 2000-01-01 -->\n# AGENTS.md\n' > "$fx/AGENTS.md"
git -C "$fx" init -q
git -C "$fx" add -A
git -C "$fx" -c user.email=t@t.t -c user.name=t commit -qm init
echo 'package util' > "$fx/src/util.go"
git -C "$fx" add -A
git -C "$fx" -c user.email=t@t.t -c user.name=t commit -qm second
tree="$(git -C "$fx" rev-parse 'HEAD~1^{tree}')"
rm -f "$fx/.git/objects/${tree:0:2}/${tree:2}"
git -C "$fx" config core.repositoryformatversion 1
git -C "$fx" config extensions.partialClone origin
git -C "$fx" config remote.origin.url ssh://example.invalid/x.git
git -C "$fx" config remote.origin.promisor true
git -C "$fx" config core.sshCommand "touch $WORK/transport.ran; false"
for script in analyze-git-history.sh check-freshness.sh; do
    (cd "$fx" && timeout 60 bash "$SCRIPTS_DIR/$script" "$fx" >/dev/null 2>&1)
    [ $? -eq 124 ] && fail "$script timed out"
    [ -e "$WORK/transport.ran" ] && fail "$script ran the promisor remote's transport command"
done
pass "no script fetches a missing object from the analysed project's remote"

# Run from a git hook, GIT_DIR and GIT_INDEX_FILE point at the calling
# repository; the scripts still answer for the analysed project.
fx="$WORK/located"
mkdir -p "$fx/src"
printf 'package main\n' > "$fx/src/main.go"
git -C "$fx" init -q
git -C "$fx" add -A
git init -q "$WORK/caller"
out="$(cd "$fx" && GIT_DIR="$WORK/caller/.git" GIT_INDEX_FILE="$WORK/caller/.git/index" \
    timeout 60 bash "$SCRIPTS_DIR/generate-file-map.sh" "$fx" 2>/dev/null)"
grep -q 'src/' <<<"$out" || fail "generate-file-map.sh listed another repository's files (output: $out)"
pass "inherited GIT_DIR and GIT_INDEX_FILE do not redirect the scripts"

echo ""
echo "All untrusted git config tests passed."
