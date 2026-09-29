#!/usr/bin/env bash
# Regression test for dependency-tree exclusion in verify-content.sh and
# check-freshness.sh.
#
# Both scripts inspected every AGENTS.md below the project root, including
# third-party ones shipped in vendor/, node_modules/ and a TYPO3 extension's
# .Build/. verify-content.sh then reported those packages' own file references
# as "File documented in ... does not exist" errors against the project (12
# errors on a TYPO3 extension once `composer install` had run), and
# check-freshness.sh rated their freshness. validate-structure.sh already
# excludes the same trees (#84).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
VERIFY="$SCRIPTS_DIR/verify-content.sh"
FRESHNESS="$SCRIPTS_DIR/check-freshness.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

# A minimal project whose own AGENTS.md is correct, plus third-party AGENTS.md
# files in the three dependency trees that name files absent from the project.
FX="$WORK/proj"
mkdir -p "$FX/vendor/acme/lib" "$FX/node_modules/pkg" "$FX/.Build/vendor/acme/ext" \
    "$FX/.Build/public/typo3conf/ext/acme"
printf '# AGENTS.md\n\nNo commands documented.\n' > "$FX/AGENTS.md"
# .Build/public/... is outside any vendor/ directory, so only the .Build
# exclusion keeps it out; .Build/vendor/... is also covered by */vendor/*.
for d in vendor/acme/lib node_modules/pkg .Build/vendor/acme/ext .Build/public/typo3conf/ext/acme; do
    # shellcheck disable=SC2016  # Literal backticks are markdown code spans
    printf '# Third-party\n\nSee `AcmeWidgetService.php` and `build-acme.sh`.\n' > "$FX/$d/AGENTS.md"
done

out=$(cd "$FX" && bash "$VERIFY" . 2>&1); rc=$?

for d in vendor node_modules .Build; do
    if grep -q "/$d/" <<<"$out"; then
        echo "$out" | grep "/$d/" | head -3
        fail "verify-content.sh scanned the $d/ dependency tree"
    fi
done
pass "dependency trees (vendor, node_modules, .Build) are not scanned"

if [ "$rc" -ne 0 ]; then
    echo "$out"
    fail "a project that is correct on its own files exited non-zero"
fi
pass "project with correct own files passes despite third-party AGENTS.md files"

# check-freshness.sh needs a git repository; it lists every file it checks.
git -C "$FX" init -q
out=$(bash "$FRESHNESS" "$FX" 2>&1)
grep -q "Checking: AGENTS.md" <<<"$out" \
    || { echo "$out"; fail "check-freshness.sh did not check the project's own AGENTS.md"; }
for d in vendor node_modules .Build; do
    if grep -q "$d/" <<<"$out"; then
        echo "$out" | grep "$d/" | head -3
        fail "check-freshness.sh checked the $d/ dependency tree"
    fi
done
pass "check-freshness.sh skips dependency trees and still checks the project's own file"

# The project's own scoped files must still be verified, and a real defect
# there must still be reported.
mkdir -p "$FX/src"
# shellcheck disable=SC2016  # Literal backticks are markdown code spans
printf '# AGENTS.md -- src\n\nEntry point: `MissingEntryPoint.php`.\n' > "$FX/src/AGENTS.md"
out=$(cd "$FX" && bash "$VERIFY" . 2>&1); rc=$?
grep -q "src/AGENTS.md does not exist: MissingEntryPoint.php" <<<"$out" \
    || { echo "$out"; fail "a missing file documented in the project's own src/AGENTS.md was not reported"; }
[ "$rc" -ne 0 ] || fail "a real defect in the project's own scoped file did not fail the run"
pass "the project's own scoped files are still verified"

# A file that exists only inside a dependency tree is not a project file, so
# naming it in the project's own AGENTS.md must still be reported. The lookup
# for documented files uses the same three exclusions as the scan above.
touch "$FX/vendor/acme/lib/OnlyInVendor.php" \
    "$FX/node_modules/pkg/OnlyInNodeModules.js" \
    "$FX/.Build/public/typo3conf/ext/acme/OnlyInBuild.php"
# shellcheck disable=SC2016  # Literal backticks are markdown code spans
printf '# AGENTS.md -- src\n\nSee `OnlyInVendor.php`, `OnlyInNodeModules.js` and `OnlyInBuild.php`.\n' > "$FX/src/AGENTS.md"
out=$(cd "$FX" && bash "$VERIFY" . 2>&1)
for f in OnlyInVendor.php OnlyInNodeModules.js OnlyInBuild.php; do
    grep -q "src/AGENTS.md does not exist: $f" <<<"$out" \
        || { echo "$out"; fail "$f exists only in a dependency tree but was accepted as a project file"; }
done
pass "files that exist only in a dependency tree do not count as documented project files"

echo "All verify-content.sh dependency-tree tests passed."
