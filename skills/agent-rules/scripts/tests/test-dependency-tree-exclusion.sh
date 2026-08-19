#!/usr/bin/env bash
# Regression test for dependency-tree exclusion in validate-structure.sh (issue #84).
#
# The CLAUDE.md-symlink scan excludes vendor/ and node_modules/, but the scoped
# AGENTS.md scan did not — so third-party AGENTS.md files shipped inside an
# installed composer vendor/ tree were validated as if they were the project's
# own, reporting their missing sections as project errors. TYPO3 extensions
# install dependencies under .Build/vendor/, so that path must be excluded too.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
VALIDATE="$SCRIPTS_DIR/validate-structure.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# A minimal project whose OWN files are valid, plus third-party AGENTS.md files
# in the three dependency trees. Only the dependency files are non-conforming.
FX="$WORK/proj"
mkdir -p "$FX/vendor/acme/lib" "$FX/node_modules/pkg" "$FX/.Build/vendor/acme/ext"

cat > "$FX/AGENTS.md" <<'MD'
<!-- Managed by agent: keep sections and order; edit content, not structure -->

# AGENTS.md

**Precedence:** The **closest AGENTS.md** to changed files wins. Root holds global defaults only.

## Index of scoped AGENTS.md

- nothing scoped yet
MD
ln -s AGENTS.md "$FX/CLAUDE.md"

for d in vendor/acme/lib node_modules/pkg .Build/vendor/acme/ext; do
    printf '# Third-party AGENTS.md\n\nNo managed header, no required sections.\n' > "$FX/$d/AGENTS.md"
done

out=$(bash "$VALIDATE" "$FX" 2>&1); rc=$?

for d in vendor node_modules .Build; do
    if grep -q "/$d/" <<<"$out"; then
        echo "$out" | grep "/$d/" | head -3
        fail "validate-structure.sh scanned the $d/ dependency tree (#84)"
    fi
done
pass "dependency trees (vendor, node_modules, .Build) are not scanned"

if [ "$rc" -ne 0 ]; then
    echo "$out"
    fail "a project that is valid on its own files exited non-zero"
fi
pass "project with valid own files passes despite third-party AGENTS.md files"

# The project's own scoped files must still be validated.
mkdir -p "$FX/src"
printf '# AGENTS.md -- src\n\nNo managed header, no required sections.\n' > "$FX/src/AGENTS.md"
out=$(bash "$VALIDATE" "$FX" 2>&1)
grep -q "src/AGENTS.md" <<<"$out" || fail "the project's own scoped AGENTS.md was skipped"
pass "the project's own scoped files are still validated"

echo "All dependency-tree exclusion tests passed."
