#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# verify-commands.sh finds the same commands whatever form the project path
# takes, reports input it cannot read, tells an empty inventory apart from
# verified commands, finds commands in fenced shell blocks and repo-local
# scripts, and never runs a command it took from a fenced example.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
VERIFY="$SCRIPTS_DIR/verify-commands.sh"

WORK="$(mktemp -d)"
trap 'chmod -R u+rwx "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

FX="$WORK/parent/child"
mkdir -p "$FX/scripts" "$FX/src" "$FX/docs" "$FX/app" "$FX/build"
printf '#!/bin/sh\nexit 0\n' > "$FX/scripts/check.sh"
chmod +x "$FX/scripts/check.sh"
printf '{"scripts": {"ci:test": "echo ok"}}\n' > "$FX/app/composer.json"
touch "$FX/build/keep"
# A fenced example that deletes the sentinel when run.
printf 'import os\nos.remove("build/keep")\n' > "$FX/wipe.py"
# make -n still runs a "+" recipe line: a smoke test of "make wipe" deletes it.
printf 'wipe:\n\t+rm -f build/keep\n' > "$FX/Makefile"
cat > "$FX/AGENTS.md" <<'AGENTS'
# Fixture

- Check the interpreter: `python3 --version`
- Run `scripts/check.sh --fast` before a commit, or `SF_BASE=origin/main scripts/check.sh --diff`.
- Documented but gone: `scripts/gone.sh`.

| Path | Purpose |
|------|---------|
| `src/` | sources |
| `docs/` | documentation |

## Verify it

```bash
ls docs                 # list the documentation
$ composer --working-dir=app ci:test
python3 wipe.py
make wipe
```
AGENTS

inventory() {
    local json="$1"
    jq -r '.inventory[].cmd' <<<"$json" | LC_ALL=C sort
}

# 1. The same inventory from a relative path, an absolute path and the root.
REL="$(cd "$WORK/parent" && DRY_RUN=true bash "$VERIFY" child --json 2>/dev/null)"
ABS="$(cd "$WORK" && DRY_RUN=true bash "$VERIFY" "$FX" --json 2>/dev/null)"
ROOT="$(cd "$FX" && DRY_RUN=true bash "$VERIFY" . --json 2>/dev/null)"
INV_ABS="$(inventory "$ABS")" || fail "no JSON from the absolute path (output was: $ABS)"
[[ -n "$INV_ABS" ]] || fail "the absolute path found no commands (output was: $ABS)"
[[ "$(inventory "$REL")" = "$INV_ABS" ]] || fail "a relative path found other commands: $(inventory "$REL") vs $INV_ABS"
[[ "$(inventory "$ROOT")" = "$INV_ABS" ]] || fail "the project root found other commands: $(inventory "$ROOT") vs $INV_ABS"
pass "relative, absolute and root paths find the same commands"

# 1b. The sidecar of a relative path lands in the project, not below it.
(cd "$WORK/parent" && bash "$VERIFY" child >/dev/null 2>&1) || true
[[ -f "$FX/.agents/command-verification.json" ]] || fail "the sidecar of a relative path is not in the project"
[[ ! -e "$FX/child" ]] || fail "a relative path was resolved twice (child/child exists)"
rm -rf "$FX/.agents"
UPD="$WORK/upd/proj"
mkdir -p "$UPD"
# shellcheck disable=SC2016  # backticks are markdown, not substitution
printf '<!-- Last verified: 2000-01-01 -->\n# x\n\n- `python3 --version`\n' > "$UPD/AGENTS.md"
(cd "$WORK/upd" && bash "$VERIFY" proj --update-verified >/dev/null 2>&1) || fail "the --update-verified run failed"
grep -q "Last verified: 2000-01-01" "$UPD/AGENTS.md" && fail "--update-verified with a relative path did not reach AGENTS.md"
pass "a relative path is resolved once"

# 2. Inline, repo-local, env-prefixed and fenced commands are found.
for c in 'python3 --version' 'scripts/check.sh --fast' 'SF_BASE=origin/main scripts/check.sh --diff' \
         'scripts/gone.sh' 'ls docs' 'composer --working-dir=app ci:test' 'python3 wipe.py'; do
    grep -qxF -- "$c" <<<"$INV_ABS" || fail "'$c' is missing from the inventory: $INV_ABS"
done
pass "inline, repo-local, env-prefixed and fenced commands are found"

# 3. A directory table holds paths, not commands; comments and prompts are cut.
for c in 'src/' 'docs/' 'ls docs                 # list the documentation' '$ composer --working-dir=app ci:test'; do
    grep -qxF -- "$c" <<<"$INV_ABS" && fail "'$c' was taken for a command: $INV_ABS"
done
pass "paths in a table are not commands; comments and prompts are removed"

# 4. Sources are recorded, a missing repo-local script fails the run.
[[ "$(jq -r '.inventory[] | select(.cmd == "python3 wipe.py") | .source' <<<"$ABS")" = fenced ]] \
    || fail "the fenced command is not marked as fenced (output was: $ABS)"
[[ "$(jq -r '.summary.failed' <<<"$ABS")" -ge 1 ]] || fail "the missing scripts/gone.sh did not fail (output was: $ABS)"
OUT="$(cd "$WORK" && DRY_RUN=true bash "$VERIFY" "$FX" 2>&1)"; rc=$?
[[ "$rc" -eq 1 ]] || fail "a missing repo-local script exits $rc, expected 1"
grep -q "repo-local command not found: scripts/gone.sh" <<<"$OUT" || fail "no diagnostic for scripts/gone.sh (output was: $OUT)"
grep -q "repo-local command exists: scripts/check.sh" <<<"$OUT" || fail "scripts/check.sh not verified (output was: $OUT)"
grep -q "composer script exists: ci:test" <<<"$OUT" || fail "--working-dir composer script not found (output was: $OUT)"
pass "a missing repo-local script fails; --working-dir is honoured"

# 5. A fenced example is never executed, even with SMOKE_TEST=true.
(cd "$WORK" && SMOKE_TEST=true DRY_RUN=true bash "$VERIFY" "$FX" >/dev/null 2>&1) || true
[[ -e "$FX/build/keep" ]] || fail "a fenced example was executed (build/keep is gone)"
pass "fenced examples are not executed by the smoke test"

# 6. A missing directory and an unreadable AGENTS.md are diagnostics, not success.
OUT="$(bash "$VERIFY" "$WORK/does-not-exist" 2>&1)"; rc=$?
[[ "$rc" -ne 0 ]] || fail "a missing project directory exits 0"
grep -qi "not found\|no such\|does not exist" <<<"$OUT" || fail "no diagnostic for a missing directory (output was: $OUT)"
if [[ "$(id -u)" -ne 0 ]]; then
    UNR="$WORK/unreadable"
    mkdir -p "$UNR"
    # shellcheck disable=SC2016  # backticks are markdown, not substitution
    printf '# x\n\n- `python3 --version`\n' > "$UNR/AGENTS.md"
    chmod 000 "$UNR/AGENTS.md"
    OUT="$(bash "$VERIFY" "$UNR" 2>&1)"; rc=$?
    [[ "$rc" -ne 0 ]] || fail "an unreadable AGENTS.md exits 0 (output was: $OUT)"
    grep -qi "cannot read\|not readable" <<<"$OUT" || fail "no diagnostic for an unreadable AGENTS.md (output was: $OUT)"
    pass "a missing directory and an unreadable AGENTS.md exit non-zero with a diagnostic"
else
    pass "a missing directory exits non-zero (unreadable file not testable as root)"
fi

# 7. An empty inventory is not a verified one.
EMPTY="$WORK/empty"
mkdir -p "$EMPTY"
printf '# Prose only\n\nNothing to run here.\n' > "$EMPTY/AGENTS.md"
OUT="$(DRY_RUN=true bash "$VERIFY" "$EMPTY" --json 2>/dev/null)"; rc=$?
[[ "$rc" -eq 3 ]] || fail "an empty inventory exits $rc, expected 3 (output was: $OUT)"
[[ "$(jq -r '.status' <<<"$OUT")" = empty ]] || fail "an empty inventory is not reported as empty (output was: $OUT)"
DRY_RUN=true bash "$VERIFY" "$EMPTY" --allow-empty >/dev/null 2>&1 || fail "--allow-empty does not accept an empty inventory"
OK="$WORK/ok"
mkdir -p "$OK"
# shellcheck disable=SC2016  # backticks are markdown, not substitution
printf '# x\n\n- `python3 --version`\n' > "$OK/AGENTS.md"
OUT="$(DRY_RUN=true bash "$VERIFY" "$OK" --json 2>/dev/null)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "a verified inventory exits $rc (output was: $OUT)"
[[ "$(jq -r '.status' <<<"$OUT")" = verified ]] || fail "a verified inventory is not reported as verified (output was: $OUT)"
[[ "$(jq -r '.found' <<<"$OUT")" = 1 ]] || fail "found count is wrong (output was: $OUT)"
pass "an empty inventory exits 3 with status empty; verified commands exit 0 with status verified"

echo ""
echo "All inventory tests passed."
