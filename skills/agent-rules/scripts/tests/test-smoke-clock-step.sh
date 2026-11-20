#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# verify-commands.sh times each smoke test with the wall clock. When the clock
# steps back during a run, the measured duration is negative; the script must
# still report the command and finish, not exit without a word.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# A date stub whose millisecond clock runs backwards by 100 ms per call; every
# other date invocation goes to the real date.
mkdir -p "$WORK/bin" "$WORK/project"
REAL_DATE="$(command -v date)"
cat > "$WORK/bin/date" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "+%s%3N" ]; then
    n=\$(cat "$WORK/calls" 2>/dev/null || echo 0)
    echo \$((n + 1)) > "$WORK/calls"
    echo \$((1700000000000 - n * 100))
else
    exec "$REAL_DATE" "\$@"
fi
EOF
chmod +x "$WORK/bin/date"

cat > "$WORK/project/AGENTS.md" <<'AGENTS'
# Fixture

## Commands

| Command | Purpose |
|---------|---------|
| `git --version` | fixture |
AGENTS

OUT="$(cd "$WORK/project" && PATH="$WORK/bin:$PATH" SMOKE_TEST=true \
    bash "$SCRIPTS_DIR/verify-commands.sh" . 2>&1)"
rc=$?
[[ $rc -eq 0 ]] || fail "verify-commands.sh exited $rc when the clock stepped back (output was: $OUT)"
grep -q "command works" <<<"$OUT" || fail "the smoke-tested command was not reported (output was: $OUT)"
grep -q "Verification Summary" <<<"$OUT" || fail "the summary is missing (output was: $OUT)"
pass "a clock step back during a smoke test does not end the run"

echo ""
echo "All smoke-test clock tests passed."
