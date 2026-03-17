#!/usr/bin/env bash
# Extract GitHub repository rulesets (newer API, not just branch protection)
# Returns JSON with ruleset details for AGENTS.md generation
# Falls back gracefully if unavailable (no auth, not GitHub, no rulesets)
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Silent exit with empty JSON if prerequisites not met
bail() {
    jq -n '{rulesets: [], merge_queue: false, required_checks: [], signed_commits: false}'
    exit 0
}

# Check gh CLI available
command -v gh &>/dev/null || bail

# Check authenticated
gh auth status &>/dev/null 2>&1 || bail

# Check this is a git repo with a remote
REMOTE_URL=$(git remote get-url origin 2>/dev/null) || bail

# Check it's a GitHub repo
[[ "$REMOTE_URL" =~ github\.com ]] || bail

# Extract owner/repo from URL (handles both HTTPS and SSH)
OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/.]+)(\.git)?.*|\1|')
[[ -n "$OWNER_REPO" ]] || bail

# Fetch rulesets — may fail if no permission or no rulesets
RULESETS_RAW=$(gh api "repos/$OWNER_REPO/rulesets" 2>/dev/null) || bail

# Check if response is a valid array
echo "$RULESETS_RAW" | jq -e 'type == "array"' &>/dev/null || bail

RULESET_COUNT=$(echo "$RULESETS_RAW" | jq 'length')
if [ "$RULESET_COUNT" -eq 0 ]; then
    bail
fi

# Track aggregate settings
HAS_MERGE_QUEUE=false
HAS_SIGNED_COMMITS=false
ALL_REQUIRED_CHECKS="[]"
RULESETS_JSON="[]"

for i in $(seq 0 $((RULESET_COUNT - 1))); do
    RULESET_ID=$(echo "$RULESETS_RAW" | jq -r ".[$i].id")
    RULESET_NAME=$(echo "$RULESETS_RAW" | jq -r ".[$i].name // \"unnamed\"")
    RULESET_TARGET=$(echo "$RULESETS_RAW" | jq -r ".[$i].target // \"branch\"")
    RULESET_ENFORCEMENT=$(echo "$RULESETS_RAW" | jq -r ".[$i].enforcement // \"disabled\"")

    # Skip disabled rulesets
    [ "$RULESET_ENFORCEMENT" = "disabled" ] && continue

    # Fetch detailed ruleset info (includes rules array)
    DETAIL=$(gh api "repos/$OWNER_REPO/rulesets/$RULESET_ID" 2>/dev/null) || continue

    # Extract rule types from the rules array
    RULE_TYPES=$(echo "$DETAIL" | jq -r '[.rules[]?.type // empty] | unique' 2>/dev/null) || RULE_TYPES="[]"

    # Check for specific rule types
    if echo "$RULE_TYPES" | jq -e 'index("merge_queue")' &>/dev/null; then
        HAS_MERGE_QUEUE=true
    fi
    if echo "$RULE_TYPES" | jq -e 'index("required_signatures")' &>/dev/null; then
        HAS_SIGNED_COMMITS=true
    fi

    # Extract required status checks
    STATUS_CHECKS=$(echo "$DETAIL" | jq -r '
        [.rules[]? | select(.type == "required_status_checks") |
         .parameters.required_status_checks[]?.context // empty] | unique' 2>/dev/null) || STATUS_CHECKS="[]"

    if [ "$STATUS_CHECKS" != "[]" ] && [ "$STATUS_CHECKS" != "null" ]; then
        ALL_REQUIRED_CHECKS=$(echo "$ALL_REQUIRED_CHECKS" "$STATUS_CHECKS" | jq -s 'add | unique')
    fi

    # Add to rulesets array
    RULESETS_JSON=$(echo "$RULESETS_JSON" | jq \
        --arg name "$RULESET_NAME" \
        --arg target "$RULESET_TARGET" \
        --arg enforcement "$RULESET_ENFORCEMENT" \
        --argjson rules "$RULE_TYPES" \
        '. + [{name: $name, target: $target, enforcement: $enforcement, rules: $rules}]')
done

# Output final JSON
jq -n \
    --argjson rulesets "$RULESETS_JSON" \
    --argjson merge_queue "$HAS_MERGE_QUEUE" \
    --argjson required_checks "$ALL_REQUIRED_CHECKS" \
    --argjson signed_commits "$HAS_SIGNED_COMMITS" \
    '{rulesets: $rulesets, merge_queue: $merge_queue, required_checks: $required_checks, signed_commits: $signed_commits}'
