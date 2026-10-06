#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# verify-commands.sh looks up documented `make <target>` commands by reading the
# makefile and the files it includes. It does not run make for that: even
# `make -n` expands $(shell ...) while it parses, so checking whether a target
# exists would run the project's commands.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
VERIFY="$SCRIPTS_DIR/verify-commands.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

FX="$WORK/project"
mkdir -p "$FX/Make"
# Recipe lines start with a tab. The $(shell ...) is literal makefile text.
# shellcheck disable=SC2016
printf 'STAMP := $(shell touch %s/parsed)\ninclude Make/*.mk\n-include missing.mk\n\nbuild: deps\n\techo build\n\ndeps:\n\techo deps\n\nVERSION := 1\n' \
    "$WORK" > "$FX/Makefile"
printf 'lint test-unit:: \n\techo lint\n\nplan-%%:\n\techo $*\n\n.PHONY: lint docs-only\n' > "$FX/Make/quality.mk"
cat > "$FX/AGENTS.md" <<'AGENTS'
# Fixture

## Commands

| Task | Command |
|------|---------|
| Build | `make build` |
| Lint | `make lint` |
| Unit | `make test-unit` |
| Plan | `make plan-prod` |
| Phony | `make docs-only` |
| Missing | `make release` |
| Variable | `make VERSION` |
AGENTS

OUT="$(cd "$FX" && DRY_RUN=true bash "$VERIFY" . 2>&1)" || true

[ -e "$WORK/parsed" ] && fail "the makefile was evaluated while looking up targets"
pass "looking up targets does not evaluate the makefile"

for t in build lint test-unit plan-prod docs-only; do
    grep -q "make target exists: $t" <<<"$OUT" || fail "target '$t' was not found (output was: $OUT)"
done
pass "targets, .PHONY names and pattern rules in the makefile and its includes are found"

grep -q "make target not found: release" <<<"$OUT" || fail "a missing target was not reported (output was: $OUT)"
grep -q "make target not found: VERSION" <<<"$OUT" || fail "a variable assignment was taken for a target (output was: $OUT)"
pass "a missing target and a variable are reported as not found"

echo ""
echo "All make target lookup tests passed."
