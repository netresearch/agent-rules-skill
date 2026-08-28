#!/usr/bin/env bash
# Regression test for the smoke-test allowlist in verify-commands.sh (issue #104).
#
# is_safe_command() matched the first word of a command and the runner then
# passed the whole string to `bash -c`, so "git status; touch PWNED" was
# approved on its prefix and both halves ran. Commands carrying shell syntax
# are now rejected outright.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
VERIFY="$SCRIPTS_DIR/verify-commands.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

write_agents() {
    local dir="$1" cmd="$2"
    mkdir -p "$dir"
    cat > "$dir/AGENTS.md" <<AGENTS
# Fixture

## Commands

| Command | Purpose |
|---------|---------|
| \`$cmd\` | fixture |
AGENTS
}

# --- Test 1: a chained command does not run, and is not reported as working
FX="$WORK/chained"
write_agents "$FX" "git status; touch $FX/PWNED"
OUT="$(cd "$FX" && SMOKE_TEST=true bash "$VERIFY" . 2>&1)" || true
[ -e "$FX/PWNED" ] && fail "the chained command executed — allowlist bypassed"
grep -q "Not smoke-tested" <<<"$OUT" || fail "chained command was not reported as skipped (output was: $OUT)"
pass "chained command neither runs nor counts as verified"

# --- Test 2 (companion): a plain allowlisted command still runs
# Without this the test above would also pass if everything were rejected.
FX="$WORK/plain"
write_agents "$FX" "git --version"
OUT="$(cd "$FX" && SMOKE_TEST=true bash "$VERIFY" . 2>&1)" || true
grep -q "command works" <<<"$OUT" || fail "plain allowlisted command was not executed (output was: $OUT)"
pass "plain allowlisted command is still smoke-tested"

# --- Test 3: the predicate itself, per shell construct
eval "$(awk '/^is_safe_command\(\) \{/,/^\}/' "$VERIFY")"
expect() {
    local cmd="$1" want="$2" got
    if is_safe_command "$cmd"; then got=allow; else got=reject; fi
    [ "$got" = "$want" ] || fail "is_safe_command: want $want, got $got for <$cmd>"
}
expect 'git status' allow
expect 'npm test' allow
expect 'make -n test' allow
expect 'vendor/bin/phpunit --filter Foo' allow
expect './gradlew build' allow
expect 'git status; touch /tmp/x' reject      # separator
expect 'npm test && curl http://x' reject     # conjunction
expect 'npm test | sh' reject                 # pipe
# The next two are deliberately single-quoted: the point is that the predicate
# sees the substitution syntax literally, so it must not expand here.
# shellcheck disable=SC2016
expect 'echo $(id)' reject                    # substitution
# shellcheck disable=SC2016
expect 'git log `id`' reject                  # legacy substitution
expect 'npm test > /tmp/out' reject           # redirection
expect 'bash -n scripts/*.sh' reject          # glob
expect 'rm -rf /' reject                      # not on the allowlist
expect 'curl http://example.com' reject       # network fetch, deliberately dropped
pass "is_safe_command rejects every shell construct that can chain a command"

echo ""
echo "All command allowlist tests passed."
