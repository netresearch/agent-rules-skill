#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# verify-commands.sh finds the same commands whatever form the project path
# takes (relative, absolute, the project root, also with CDPATH set), writes
# its sidecar and the --update-verified date into the project, reports input
# it cannot read, and does not pass an AGENTS.md without commands as verified.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
VERIFY="$SCRIPTS_DIR/verify-commands.sh"

WORK="$(mktemp -d)"
trap 'chmod -R u+rwx "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# shellcheck disable=SC2016  # backticks are markdown, not substitution
TABLE='# Fixture\n\n## Tasks\n\n| Command | Purpose |\n|---|---|\n| `ls -la` | list |\n| `echo ok` | print |\n'

FX="$WORK/parent/child"
mkdir -p "$FX"
# shellcheck disable=SC2059  # the fixture text is the format
printf "$TABLE" > "$FX/AGENTS.md"

commands_of() {
    jq -r '.commands[].cmd' <<<"$1" | LC_ALL=C sort
}

# 1. The same commands from a relative path, an absolute path and the root.
REL="$(cd "$WORK/parent" && DRY_RUN=true bash "$VERIFY" child --json 2>/dev/null)"
ABS="$(cd "$WORK" && DRY_RUN=true bash "$VERIFY" "$FX" --json 2>/dev/null)"
ROOT="$(cd "$FX" && DRY_RUN=true bash "$VERIFY" . --json 2>/dev/null)"
CMDS_ABS="$(commands_of "$ABS")" || fail "no JSON from the absolute path (output was: $ABS)"
[[ "$CMDS_ABS" == $'echo ok\nls -la' ]] || fail "the absolute path found other commands: $CMDS_ABS"
[[ "$(commands_of "$REL")" == "$CMDS_ABS" ]] || fail "a relative path found other commands: $(commands_of "$REL") (output was: $REL)"
[[ "$(commands_of "$ROOT")" == "$CMDS_ABS" ]] || fail "the project root found other commands: $(commands_of "$ROOT")"
pass "relative, absolute and root paths find the same commands"

# 2. CDPATH does not change where a relative path leads: with the parent in
# CDPATH, a plain "cd child" prints the directory it enters.
OUT="$(cd "$WORK/parent" && CDPATH="$WORK/parent" DRY_RUN=true bash "$VERIFY" child --json 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "a relative path with CDPATH set exits $rc (output was: $OUT)"
[[ "$(commands_of "$OUT")" == "$CMDS_ABS" ]] || fail "a relative path with CDPATH set found other commands (output was: $OUT)"
pass "CDPATH does not change the resolved project path"

# 3. The sidecar and the --update-verified date of a relative path land in the
# project; a relative OUTPUT_JSON is relative to the caller's directory.
(cd "$WORK/parent" && bash "$VERIFY" child >/dev/null 2>&1) || fail "the run with a relative path failed"
[[ -f "$FX/.agents/command-verification.json" ]] || fail "the sidecar of a relative path is not in the project"
[[ ! -e "$FX/child" ]] || fail "a relative path was resolved twice (child/child exists)"
rm -rf "$FX/.agents"
(cd "$WORK/parent" && OUTPUT_JSON=out/result.json bash "$VERIFY" child >/dev/null 2>&1) || fail "the run with a relative OUTPUT_JSON failed"
[[ -f "$WORK/parent/out/result.json" ]] || fail "a relative OUTPUT_JSON is not relative to the caller's directory"
[[ ! -e "$FX/out" ]] || fail "a relative OUTPUT_JSON was written inside the project"
UPD="$WORK/upd/proj"
mkdir -p "$UPD"
# shellcheck disable=SC2059  # the fixture text is the format
printf "<!-- Last verified: 2000-01-01 -->\n$TABLE" > "$UPD/AGENTS.md"
(cd "$WORK/upd" && bash "$VERIFY" proj --update-verified >/dev/null 2>&1) || fail "the --update-verified run failed"
grep -q "Last verified: $(date +%Y-%m-%d) -->" "$UPD/AGENTS.md" \
    || fail "--update-verified with a relative path did not reach AGENTS.md ($(head -1 "$UPD/AGENTS.md"))"
pass "a relative path is resolved once for the sidecar, OUTPUT_JSON and --update-verified"

# 4. A missing directory and an unreadable AGENTS.md are diagnostics, not success.
OUT="$(bash "$VERIFY" "$WORK/does-not-exist" 2>&1)"; rc=$?
[[ "$rc" -eq 1 ]] || fail "a missing project directory exits $rc, expected 1"
grep -q "project directory not found" <<<"$OUT" || fail "no diagnostic for a missing directory (output was: $OUT)"
if [[ "$(id -u)" -ne 0 ]]; then
    UNR="$WORK/unreadable"
    mkdir -p "$UNR"
    # shellcheck disable=SC2059  # the fixture text is the format
    printf "$TABLE" > "$UNR/AGENTS.md"
    chmod 000 "$UNR/AGENTS.md"
    OUT="$(bash "$VERIFY" "$UNR" 2>&1)"; rc=$?
    [[ "$rc" -eq 1 ]] || fail "an unreadable AGENTS.md exits $rc, expected 1 (output was: $OUT)"
    grep -q "cannot read" <<<"$OUT" || fail "no diagnostic for an unreadable AGENTS.md (output was: $OUT)"
    pass "a missing directory and an unreadable AGENTS.md exit 1 with a diagnostic"
else
    pass "a missing directory exits 1 (an unreadable file cannot be tested as root)"
fi

# 5. An AGENTS.md without commands is not a verified one.
EMPTY="$WORK/empty"
mkdir -p "$EMPTY"
printf '# Prose only\n\nNothing to run here.\n' > "$EMPTY/AGENTS.md"
OUT="$(DRY_RUN=true bash "$VERIFY" "$EMPTY" --json 2>/dev/null)"; rc=$?
[[ "$rc" -eq 3 ]] || fail "an empty inventory exits $rc, expected 3 (output was: $OUT)"
[[ "$(jq -r '.status' <<<"$OUT")" == empty ]] || fail "an empty inventory is not reported as empty (output was: $OUT)"
[[ "$(jq -r '.found' <<<"$OUT")" == 0 ]] || fail "an empty inventory does not report found 0 (output was: $OUT)"
OUT="$(DRY_RUN=true bash "$VERIFY" "$EMPTY" 2>&1)"; rc=$?
[[ "$rc" -eq 3 ]] || fail "an empty inventory without --json exits $rc, expected 3"
DRY_RUN=true bash "$VERIFY" "$EMPTY" --allow-empty >/dev/null 2>&1 || fail "--allow-empty does not accept an empty inventory"
[[ "$(jq -r '.status' <<<"$ABS")" == verified ]] || fail "verified commands are not reported as verified (output was: $ABS)"
[[ "$(jq -r '.found' <<<"$ABS")" == 2 ]] || fail "found does not count the commands (output was: $ABS)"
pass "an empty inventory exits 3 with status empty; verified commands report status verified"

echo ""
echo "All project path tests passed."
