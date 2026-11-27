#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# verify-commands.sh finds the same commands whatever form the project path
# takes, reports input it cannot read, tells an empty inventory apart from
# verified commands, finds commands in fenced shell blocks and repo-local
# scripts (also run through sh/bash), follows a cd inside a fenced block,
# reads make -j/-l and here-strings correctly, and never runs a command it
# took from a fenced example, with the smoke-test run reaching its summary.
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
printf 'wipe:\n\t+rm -f build/keep\n\ntest:\n\techo test\n' > "$FX/Makefile"
mkdir -p "$FX/sub"
printf 'build:\n\techo build\n' > "$FX/sub/Makefile"
cat > "$FX/AGENTS.md" <<'AGENTS'
# Fixture

- Check the interpreter: `python3 --version`
- Run `scripts/check.sh --fast` before a commit, or `SF_BASE=origin/main scripts/check.sh --diff`.
- Documented but gone: `scripts/gone.sh --check`.
- Build it: `make test`.
- Entry point `src/main.ts`; helpers in `tools/run.py`.

| Path | Purpose |
|------|---------|
| `src/` | sources |
| `docs/` | documentation |
| `tools/run.py` | helper |

## Verify it

```bash
ls docs                 # list the documentation
$ composer --working-dir=app ci:test
python3 wipe.py
make wipe
CI=1 make test
make -C sub build
cat > config.py <<'EOF'
from app import settings
EOF
```

~~~sh
python3 -V
~~~

```bash title="listing"
ls src
```

```console
$ python3 --help
tests/test_gone.py .... [100%]
```

````markdown
```bash
make nested-example
```
````
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
         'scripts/gone.sh --check' 'ls docs' 'composer --working-dir=app ci:test' 'python3 wipe.py' \
         'CI=1 make test' 'make -C sub build' 'python3 -V' 'ls src' 'python3 --help'; do
    grep -qxF -- "$c" <<<"$INV_ABS" || fail "'$c' is missing from the inventory: $INV_ABS"
done
pass "inline, repo-local, env-prefixed and fenced commands are found"

# 3. A directory table holds paths, not commands; comments and prompts are cut.
for c in 'src/' 'docs/' 'ls docs                 # list the documentation' '$ composer --working-dir=app ci:test' \
         'src/main.ts' 'tools/run.py' 'from app import settings' 'EOF' 'tests/test_gone.py .... [100%]' \
         'make nested-example'; do
    grep -qxF -- "$c" <<<"$INV_ABS" && fail "'$c' was taken for a command: $INV_ABS"
done
pass "paths are not commands; comments, prompts, console output, heredoc bodies and nested examples are dropped"

# 4. Sources are recorded, a missing repo-local script fails the run.
[[ "$(jq -r '.inventory[] | select(.cmd == "python3 wipe.py") | .source' <<<"$ABS")" = fenced ]] \
    || fail "the fenced command is not marked as fenced (output was: $ABS)"
[[ "$(jq -r '.summary.failed' <<<"$ABS")" -ge 1 ]] || fail "the missing scripts/gone.sh did not fail (output was: $ABS)"
OUT="$(cd "$WORK" && DRY_RUN=true bash "$VERIFY" "$FX" 2>&1)"; rc=$?
[[ "$rc" -eq 1 ]] || fail "a missing repo-local script exits $rc, expected 1"
grep -q "repo-local command not found: scripts/gone.sh" <<<"$OUT" || fail "no diagnostic for scripts/gone.sh (output was: $OUT)"
grep -q "repo-local command exists: scripts/check.sh" <<<"$OUT" || fail "scripts/check.sh not verified (output was: $OUT)"
grep -q "composer script exists: ci:test" <<<"$OUT" || fail "--working-dir composer script not found (output was: $OUT)"
grep -q "make target exists: test" <<<"$OUT" || fail "an env-prefixed make target was not found (output was: $OUT)"
grep -q "make target exists: build" <<<"$OUT" || fail "make -C sub build was not looked up in sub/ (output was: $OUT)"
pass "a missing repo-local script fails; --working-dir is honoured"

# 5. A fenced example is never executed, even with SMOKE_TEST=true, and the
# smoke-test run reaches its summary: a run that dies early (as the make smoke
# test once did) cannot reach the fenced "make wipe" and would prove nothing.
OUT="$(cd "$WORK" && SMOKE_TEST=true DRY_RUN=true bash "$VERIFY" "$FX" 2>&1)"; rc=$?
[[ -e "$FX/build/keep" ]] || fail "a fenced example was executed (build/keep is gone)"
grep -q "Verification Summary" <<<"$OUT" || fail "the smoke-test run stopped before its summary (output was: $OUT)"
grep -q "unbound variable" <<<"$OUT" && fail "the smoke-test run hit an unbound variable (output was: $OUT)"
[[ "$rc" -eq 1 ]] || fail "the smoke-test run exits $rc, expected 1 for the missing scripts/gone.sh (output was: $OUT)"
grep -q "make target works: test" <<<"$OUT" || fail "the inline make test was not smoke-tested (output was: $OUT)"
OUT="$(cd "$WORK" && SMOKE_TEST=true DRY_RUN=true bash "$VERIFY" "$FX" --json 2>/dev/null)"
[[ "$(jq -r '.commands[] | select(.cmd == "make test") | .detail.runs' <<<"$OUT")" = true ]] \
    || fail "the make smoke result is not filed under the documented command (output was: $OUT)"
[[ "$(jq -r '[.commands[] | select(.cmd | startswith("make -n"))] | length' <<<"$OUT")" = 0 ]] \
    || fail "the internal make -n command appears in commands[] (output was: $OUT)"
pass "fenced examples are not executed by the smoke test, and the run reaches its summary"

# 5c. A smoke test run under another command line (phpunit --help) is filed
# under the documented command.
VB="$WORK/vendorbin"
mkdir -p "$VB/vendor/bin"
printf '#!/bin/sh\nexit 0\n' > "$VB/vendor/bin/phpunit"
chmod +x "$VB/vendor/bin/phpunit"
# shellcheck disable=SC2016  # backticks are markdown, not substitution
printf '# x\n\n- Tests: `vendor/bin/phpunit --testsuite unit`\n' > "$VB/AGENTS.md"
OUT="$(SMOKE_TEST=true DRY_RUN=true bash "$VERIFY" "$VB" --json 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "a smoke-tested phpunit exits $rc (output was: $OUT)"
[[ "$(jq -r '.commands[] | select(.cmd == "vendor/bin/phpunit --testsuite unit") | .detail.runs' <<<"$OUT")" = true ]] \
    || fail "the phpunit smoke result is not filed under the documented command (output was: $OUT)"
[[ "$(jq -r '[.commands[] | select(.cmd == "vendor/bin/phpunit --help")] | length' <<<"$OUT")" = 0 ]] \
    || fail "the internal phpunit --help command appears in commands[] (output was: $OUT)"
pass "a smoke test under another command line is filed under the documented command"

# 5b. A CRLF AGENTS.md loses no fenced command.
CRLF="$WORK/crlf"
mkdir -p "$CRLF"
# shellcheck disable=SC2016  # backticks are markdown, not substitution
printf '# x\r\n\r\n```bash\r\npython3 --version\r\n```\r\n' > "$CRLF/AGENTS.md"
OUT="$(DRY_RUN=true bash "$VERIFY" "$CRLF" --json 2>/dev/null)"
[[ "$(jq -r '.found' <<<"$OUT")" = 1 ]] || fail "a CRLF fenced command was lost (output was: $OUT)"
pass "a CRLF AGENTS.md keeps its fenced commands"

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

# 8. A script run through sh or bash is looked up: a missing one fails.
SHB="$WORK/shbash"
mkdir -p "$SHB/scripts"
printf '#!/bin/sh\nexit 0\n' > "$SHB/scripts/ok.sh"
cat > "$SHB/AGENTS.md" <<'AGENTS'
# x

```bash
bash scripts/gone.sh --check
sh scripts/gone.sh
bash scripts/ok.sh
```
AGENTS
OUT="$(DRY_RUN=true bash "$VERIFY" "$SHB" --json 2>/dev/null)"; rc=$?
[[ "$rc" -eq 1 ]] || fail "a missing script run through sh/bash exits $rc, expected 1 (output was: $OUT)"
[[ "$(jq -r '.summary.failed' <<<"$OUT")" = 2 ]] || fail "both missing sh/bash scripts must fail (output was: $OUT)"
[[ "$(jq -r '.summary.passed' <<<"$OUT")" = 1 ]] || fail "bash scripts/ok.sh was not verified (output was: $OUT)"
pass "a missing script run through sh or bash fails the run"

# 9. A cd inside a fenced block moves the lines after it: they are checked
# in that directory (monorepo), and a cd this check cannot follow leaves the
# rest of the block unchecked, never failed.
MONO="$WORK/mono"
mkdir -p "$MONO/web/scripts"
printf '#!/bin/sh\nexit 0\n' > "$MONO/web/scripts/build.sh"
chmod +x "$MONO/web/scripts/build.sh"
printf '{"scripts": {"lint": "eslint ."}}\n' > "$MONO/web/package.json"
cat > "$MONO/AGENTS.md" <<'AGENTS'
# x

```bash
cd web
./scripts/build.sh
npm run lint
```

```bash
cd ../elsewhere
./scripts/not-here.sh
```
AGENTS
OUT="$(DRY_RUN=true bash "$VERIFY" "$MONO" --json 2>/dev/null)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "commands after cd web fail the run: exit $rc (output was: $OUT)"
[[ "$(jq -r '.summary.failed' <<<"$OUT")" = 0 ]] || fail "a command after cd web failed (output was: $OUT)"
[[ "$(jq -r '[.inventory[] | select(.cmd == "npm run lint" and .dir == "web")] | length' <<<"$OUT")" = 1 ]] \
    || fail "npm run lint is not recorded in web/ (output was: $OUT)"
[[ "$(jq -r '[.inventory[] | select(.cmd == "./scripts/not-here.sh" and has("dir") and .dir == null)] | length' <<<"$OUT")" = 1 ]] \
    || fail "a line after an unresolvable cd is not recorded without a directory (output was: $OUT)"
OUT="$(DRY_RUN=true bash "$VERIFY" "$MONO" 2>&1)"
grep -q "repo-local command exists: ./scripts/build.sh" <<<"$OUT" || fail "./scripts/build.sh was not found in web/ (output was: $OUT)"
grep -q "npm script exists: lint" <<<"$OUT" || fail "npm run lint was not looked up in web/ (output was: $OUT)"
grep -q "Not checked.*./scripts/not-here.sh" <<<"$OUT" || fail "a line after an unresolvable cd was not reported as unchecked (output was: $OUT)"
MISS="$WORK/mono-missing"
mkdir -p "$MISS/web"
cat > "$MISS/AGENTS.md" <<'AGENTS'
# x

```bash
cd web
./scripts/gone.sh
```
AGENTS
OUT="$(DRY_RUN=true bash "$VERIFY" "$MISS" 2>&1)"; rc=$?
[[ "$rc" -eq 1 ]] || fail "a missing script after cd web exits $rc, expected 1 (output was: $OUT)"
grep -q "repo-local command not found: ./scripts/gone.sh" <<<"$OUT" || fail "no diagnostic for web/scripts/gone.sh (output was: $OUT)"
pass "a cd in a fenced block is followed; an unresolvable cd leaves the rest unchecked"

# 10. A numeric argument of -j/-l is not the make target.
MJ="$WORK/make-jobs"
mkdir -p "$MJ"
printf 'test:\n\techo test\n' > "$MJ/Makefile"
# shellcheck disable=SC2016  # backticks are markdown, not substitution
printf '# x\n\n- `make -j 4 test`\n- `make -j test`\n- `make --jobs 2 --load-average 1.5 test`\n' > "$MJ/AGENTS.md"
OUT="$(DRY_RUN=true bash "$VERIFY" "$MJ" --json 2>/dev/null)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "make with -j/-l exits $rc (output was: $OUT)"
[[ "$(jq -r '.summary.passed' <<<"$OUT")" = 3 ]] || fail "not every make -j/-l form found target test (output was: $OUT)"
pass "a numeric -j/-l argument is not taken for the make target"

# 12. A run whose commands were all skipped still emits its JSON document.
PH="$WORK/placeholder"
mkdir -p "$PH"
# shellcheck disable=SC2016  # backticks are markdown, not substitution
printf '# x\n\n- `make <target>`\n' > "$PH/AGENTS.md"
OUT="$(DRY_RUN=true bash "$VERIFY" "$PH" --json 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "a run with only skipped commands exits $rc (output was: $OUT)"
[[ "$(jq -r '.summary.skipped' <<<"$OUT")" = 1 ]] || fail "a run with only skipped commands emits no JSON (output was: $OUT)"
pass "a run with only skipped commands emits its JSON document"

# 11. A here-string is no heredoc: the lines after it are still read.
HS="$WORK/herestring"
mkdir -p "$HS"
cat > "$HS/AGENTS.md" <<'AGENTS'
# x

```bash
grep -c x <<< hello
./scripts/gone.sh
```
AGENTS
OUT="$(DRY_RUN=true bash "$VERIFY" "$HS" --json 2>/dev/null)"; rc=$?
grep -qxF './scripts/gone.sh' <<<"$(inventory "$OUT")" || fail "a line after a here-string was dropped (output was: $OUT)"
[[ "$rc" -eq 1 ]] || fail "a missing script after a here-string exits $rc, expected 1 (output was: $OUT)"
pass "a here-string does not start a heredoc"

# 13. A cd into a plain directory that does not exist fails the run; the lines
# after it cannot be checked and carry no directory.
MD="$WORK/missing-dir"
mkdir -p "$MD"
cat > "$MD/AGENTS.md" <<'AGENTS'
# x

```bash
cd frontend
npm run lint
./scripts/build.sh
```
AGENTS
OUT="$(DRY_RUN=true bash "$VERIFY" "$MD" 2>&1)"; rc=$?
[[ "$rc" -eq 1 ]] || fail "a cd into a missing directory exits $rc, expected 1 (output was: $OUT)"
grep -q "directory not found: frontend" <<<"$OUT" || fail "no diagnostic for the missing cd directory (output was: $OUT)"
grep -q "Not checked.*./scripts/build.sh" <<<"$OUT" || fail "a line after the missing directory was not reported as unchecked (output was: $OUT)"
OUT="$(DRY_RUN=true bash "$VERIFY" "$MD" --json 2>/dev/null)"
[[ "$(jq -r '.summary.failed' <<<"$OUT")" = 1 ]] || fail "the missing cd directory is not one failure (output was: $OUT)"
[[ "$(jq -r '[.inventory[] | select(.cmd == "npm run lint" and has("dir") and .dir == null)] | length' <<<"$OUT")" = 1 ]] \
    || fail "a line after a missing cd directory keeps a directory in the inventory (output was: $OUT)"
pass "a cd into a missing directory fails; the lines after it are not checked"

# 14. A cd through a symlink that leads out of the project is not followed.
OP="$WORK/outside-link/proj"
mkdir -p "$OP" "$WORK/outside-link/elsewhere/scripts"
printf '#!/bin/sh\nexit 0\n' > "$WORK/outside-link/elsewhere/scripts/x.sh"
chmod +x "$WORK/outside-link/elsewhere/scripts/x.sh"
ln -s ../elsewhere "$OP/link"
cat > "$OP/AGENTS.md" <<'AGENTS'
# x

```bash
cd link
./scripts/x.sh
```
AGENTS
OUT="$(DRY_RUN=true bash "$VERIFY" "$OP" 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "a cd through an outside symlink exits $rc (output was: $OUT)"
grep -q "Not checked.*./scripts/x.sh" <<<"$OUT" || fail "a line after a cd out of the project was checked (output was: $OUT)"
OUT="$(DRY_RUN=true bash "$VERIFY" "$OP" --json 2>/dev/null)"
[[ "$(jq -r '[.inventory[] | select(.cmd == "./scripts/x.sh" and has("dir") and .dir == null)] | length' <<<"$OUT")" = 1 ]] \
    || fail "a line after a cd out of the project keeps a directory in the inventory (output was: $OUT)"
pass "a cd out of the project is not followed"

# 15. Once a cd cannot be followed, a later cd in the same block does not
# make the lines after it checkable again.
ST="$WORK/sticky"
# A directory literally named "?" makes a non-sticky "?/web" resolvable, so
# only the sticky rule keeps the line after it unchecked.
mkdir -p "$ST/web" "$ST/?/web"
cat > "$ST/AGENTS.md" <<'AGENTS'
# x

```bash
cd ../somewhere
cd web
./scripts/gone.sh
```
AGENTS
OUT="$(DRY_RUN=true bash "$VERIFY" "$ST" 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "a cd after an unfollowable cd was followed: exit $rc (output was: $OUT)"
grep -q "Not checked.*./scripts/gone.sh" <<<"$OUT" || fail "a line after an unfollowable cd was checked (output was: $OUT)"
pass "an unfollowable cd leaves the rest of its block unchecked"

# 16. npm and composer smoke tests that run another command line file the
# result under the documented command.
NC="$WORK/npm-composer"
mkdir -p "$NC"
printf '{"scripts": {"test": "echo t"}}\n' > "$NC/package.json"
printf '{}\n' > "$NC/composer.json"
# shellcheck disable=SC2016  # backticks are markdown, not substitution
printf '# x\n\n- `npm test`\n- `composer install`\n' > "$NC/AGENTS.md"
OUT="$(SMOKE_TEST=true DRY_RUN=true bash "$VERIFY" "$NC" --json 2>/dev/null)"
for c in 'npm test' 'composer install'; do
    [[ "$(jq -r --arg c "$c" '[.commands[] | select(.cmd == $c)] | length' <<<"$OUT")" = 1 ]] \
        || fail "the smoke result of '$c' is not filed under it (output was: $OUT)"
done
[[ "$(jq -r '[.commands[] | select(.cmd | test("\\|\\|"))] | length' <<<"$OUT")" = 0 ]] \
    || fail "an internal smoke command line appears in commands[] (output was: $OUT)"
pass "npm and composer smoke results are filed under the documented command"

# 17. A documented command that equals another check's internal command line
# keeps its own result.
PR="$WORK/prior"
mkdir -p "$PR/vendor/bin"
printf '#!/bin/sh\nexit 0\n' > "$PR/vendor/bin/phpunit"
chmod +x "$PR/vendor/bin/phpunit"
# shellcheck disable=SC2016  # backticks are markdown, not substitution
printf '# x\n\n- `vendor/bin/phpunit --help`\n- `vendor/bin/phpunit --testsuite unit`\n' > "$PR/AGENTS.md"
OUT="$(SMOKE_TEST=true DRY_RUN=true bash "$VERIFY" "$PR" --json 2>/dev/null)"
for c in 'vendor/bin/phpunit --help' 'vendor/bin/phpunit --testsuite unit'; do
    [[ "$(jq -r --arg c "$c" '.commands[] | select(.cmd == $c) | .detail.runs' <<<"$OUT")" = true ]] \
        || fail "'$c' lost its result (output was: $OUT)"
done
pass "a documented command equal to an internal command line keeps its result"

# 18. The same command at the root and after a cd is two inventory entries.
DD="$WORK/dedup"
mkdir -p "$DD/web"
printf '{"scripts": {"lint": "x"}}\n' > "$DD/package.json"
printf '{"scripts": {"lint": "x"}}\n' > "$DD/web/package.json"
cat > "$DD/AGENTS.md" <<'AGENTS'
# x

- Lint: `npm run lint`

```bash
cd web
npm run lint
```
AGENTS
OUT="$(DRY_RUN=true bash "$VERIFY" "$DD" --json 2>/dev/null)"
[[ "$(jq -r '[.inventory[] | select(.cmd == "npm run lint")] | length' <<<"$OUT")" = 2 ]] \
    || fail "the same command at the root and in web/ is not two inventory entries (output was: $OUT)"
pass "the same command in two directories is two inventory entries"

# 19. After a line checked in a cd directory, the next line is checked at the
# project root again.
BK="$WORK/back-to-root"
mkdir -p "$BK/web/scripts" "$BK/scripts"
printf '#!/bin/sh\nexit 0\n' > "$BK/web/scripts/build.sh"
printf '#!/bin/sh\nexit 0\n' > "$BK/scripts/root-only.sh"
chmod +x "$BK/web/scripts/build.sh" "$BK/scripts/root-only.sh"
cat > "$BK/AGENTS.md" <<'AGENTS'
# x

```bash
cd web
./scripts/build.sh
```

```bash
./scripts/root-only.sh
```
AGENTS
OUT="$(DRY_RUN=true bash "$VERIFY" "$BK" 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "a root line after a cd-directory line was not checked at the root: exit $rc (output was: $OUT)"
pass "the check returns to the project root after a line in a cd directory"

echo ""
echo "All inventory tests passed."
