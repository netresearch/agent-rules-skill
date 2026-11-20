#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
# extract-github-settings.sh reports delete_branch_on_merge as the API gives
# it. GET /repos/{owner}/{repo} returns the key to admins only, so a missing
# key is null (unknown), never false.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

export GIT_CONFIG_GLOBAL=/dev/null
fx="$WORK/repo"
git init -q "$fx"
git -C "$fx" remote add origin https://github.com/acme/widget.git
mkdir -p "$WORK/bin"

# settings <json>: a gh stub that is logged in and answers the repository
# settings with <json>; every other API call fails like a 404.
settings() {
    printf '%s' "$1" > "$WORK/settings.json"
    cat > "$WORK/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
    "auth status") exit 0 ;;
    "api repos/acme/widget") cat "$WORK/settings.json" ;;
    *) echo '{"message":"Not Found"}'; exit 1 ;;
esac
EOF
    chmod +x "$WORK/bin/gh"
}

delete_branch() {
    PATH="$WORK/bin:$PATH" bash "$SCRIPTS_DIR/extract-github-settings.sh" "$fx" \
        | jq -c '.delete_branch_on_merge'
}

settings '{"default_branch":"main","allow_merge_commit":true,"delete_branch_on_merge":true}'
[ "$(delete_branch)" = "true" ] || fail "delete_branch_on_merge true was not reported as true"
pass "delete_branch_on_merge true is reported as true"

settings '{"default_branch":"main","allow_merge_commit":true,"delete_branch_on_merge":false}'
[ "$(delete_branch)" = "false" ] || fail "delete_branch_on_merge false was not reported as false"
pass "delete_branch_on_merge false is reported as false"

settings '{"default_branch":"main","allow_merge_commit":true}'
got="$(delete_branch)"
[ "$got" = "null" ] || fail "a missing delete_branch_on_merge was reported as $got, not null"
pass "a missing delete_branch_on_merge (non-admin caller) is reported as null"

echo ""
echo "All extract-github-settings tests passed."
