#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# analyze-git-history.sh counts matches with grep -c. grep prints 0 and exits 1
# when nothing matches, so a count written as `$(... | grep -c ... || echo 0)`
# held "0" followed by a second "0", and the arithmetic that read it failed. A
# repository whose tags match neither semver nor a leading v, and whose
# branches or commit subjects match none of the patterns, must still produce
# the JSON with those counts at 0.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

export GIT_CONFIG_GLOBAL=/dev/null
git_t() { git -C "$1" -c user.email=t@t.t -c user.name=t -c commit.gpgsign=false -c tag.gpgsign=false "${@:2}"; }

# One commit, one annotated tag that is neither semver, calver nor v-prefixed.
fx="$WORK/no-match"
git init -q "$fx"
echo a > "$fx/a"
git_t "$fx" add a
git_t "$fx" commit -qm "initial commit"
git_t "$fx" tag -a fixture-1.0.0 -m fixture

out="$(bash "$SCRIPTS_DIR/analyze-git-history.sh" "$fx" 2>"$WORK/err")"
rc=$?
[ "$rc" -eq 0 ] || fail "exit $rc on a repository without a pattern match: $(cat "$WORK/err")"
[ ! -s "$WORK/err" ] || fail "stderr not empty: $(cat "$WORK/err")"
jq -e . <<<"$out" >/dev/null || fail "output is not JSON"
pass "no pattern matches: exit 0, clean stderr, JSON output"

pattern="$(jq -r '.release_tagging.pattern // .releases.pattern // empty' <<<"$out")"
[ "$pattern" = custom ] || fail "tag pattern is '$pattern', expected custom: $out"
pass "unmatched tag is reported as a custom pattern"

# A branch on the remote side that matches nothing in the branch patterns.
remote="$WORK/remote"
git init -q --bare "$remote"
git_t "$fx" remote add origin "$remote"
git_t "$fx" push -q origin HEAD:refs/heads/feature/x
git_t "$fx" fetch -q origin
out="$(bash "$SCRIPTS_DIR/analyze-git-history.sh" "$fx" 2>"$WORK/err")"
rc=$?
[ "$rc" -eq 0 ] || fail "exit $rc with a remote branch: $(cat "$WORK/err")"
[ ! -s "$WORK/err" ] || fail "stderr not empty with a remote branch: $(cat "$WORK/err")"
jq -e . <<<"$out" >/dev/null || fail "output with a remote branch is not JSON"
pass "remote branch without a pattern match: exit 0, clean stderr, JSON output"

# generate-agents.sh counts the table rows of its generated sections the same
# way before it prunes an AGENTS.md over the byte budget. A section without a
# table row (grep -c prints 0 and exits 1) must read as 0 rows, not as "0\n0".
# The function is taken from the script itself; replace_file is the only helper
# it needs besides log.
fn_file="$WORK/enforce_byte_budget.sh"
awk '/^enforce_byte_budget\(\) \{/ { f = 1 } f { print } f && /^}/ { exit }' \
    "$SCRIPTS_DIR/generate-agents.sh" > "$fn_file"
[ -s "$fn_file" ] || fail "enforce_byte_budget not found in generate-agents.sh"
budget_file="$WORK/AGENTS.md"
{
    for section in golden-samples heuristics utilities; do
        echo "<!-- AGENTS-GENERATED:START $section -->"
        echo "no table rows in this section"
        echo "<!-- AGENTS-GENERATED:END $section -->"
    done
    printf 'filler line to exceed the budget\n%.0s' 1 2 3 4 5 6 7 8 9 10
} > "$budget_file"
err="$(bash -c '
    set -euo pipefail
    log() { :; }
    replace_file() { cat > "$1"; }
    source "$1"
    enforce_byte_budget "$2" 10
' _ "$fn_file" "$budget_file" 2>&1 >/dev/null)" || fail "enforce_byte_budget failed: $err"
[ -z "$err" ] || fail "enforce_byte_budget wrote to stderr: $err"
pass "sections without table rows count as 0 rows in enforce_byte_budget"
