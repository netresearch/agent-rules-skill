#!/usr/bin/env bash
# Extract GitHub repository settings via gh CLI
# Returns {} silently if gh unavailable, not authenticated, or not a GitHub repo
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Silent exit with empty JSON if prerequisites not met
bail() { echo "{}"; exit 0; }

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

# Fetch repo settings
REPO_INFO=$(gh api "repos/$OWNER_REPO" 2>/dev/null) || bail

# Extract merge strategies
ALLOW_SQUASH=$(echo "$REPO_INFO" | jq -r '.allow_squash_merge // false')
ALLOW_MERGE=$(echo "$REPO_INFO" | jq -r '.allow_merge_commit // false')
ALLOW_REBASE=$(echo "$REPO_INFO" | jq -r '.allow_rebase_merge // false')
DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.default_branch // "main"')
DELETE_BRANCH=$(echo "$REPO_INFO" | jq -r '.delete_branch_on_merge // false')

# Build merge strategies array
STRATEGIES="[]"
[ "$ALLOW_SQUASH" = "true" ] && STRATEGIES=$(echo "$STRATEGIES" | jq '. + ["squash"]')
[ "$ALLOW_MERGE" = "true" ] && STRATEGIES=$(echo "$STRATEGIES" | jq '. + ["merge"]')
[ "$ALLOW_REBASE" = "true" ] && STRATEGIES=$(echo "$STRATEGIES" | jq '. + ["rebase"]')

# Fetch branch protection (may fail if not configured or no access)
# Note: gh api returns error JSON to stdout on 404, so we check for error message
PROTECTION=$(gh api "repos/$OWNER_REPO/branches/$DEFAULT_BRANCH/protection" 2>/dev/null || true)
if echo "$PROTECTION" | jq -e '.message' &>/dev/null; then
    # API returned an error (e.g., "Branch not protected")
    PROTECTION="{}"
fi

# Extract protection settings
REQUIRED_APPROVALS=0
REQUIRED_CHECKS="[]"
REQUIRE_UP_TO_DATE=false
DISMISS_STALE=false

if [ "$PROTECTION" != "{}" ]; then
    # Required approving reviews
    REQUIRED_APPROVALS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
    DISMISS_STALE=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')

    # Required status checks
    REQUIRED_CHECKS=$(echo "$PROTECTION" | jq -r '.required_status_checks.contexts // []')

    # Require up-to-date branch
    REQUIRE_UP_TO_DATE=$(echo "$PROTECTION" | jq -r '.required_status_checks.strict // false')
fi

# Output JSON
jq -n \
    --arg default_branch "$DEFAULT_BRANCH" \
    --argjson merge_strategies "$STRATEGIES" \
    --argjson required_approvals "$REQUIRED_APPROVALS" \
    --argjson required_checks "$REQUIRED_CHECKS" \
    --argjson require_up_to_date "$REQUIRE_UP_TO_DATE" \
    --argjson dismiss_stale "$DISMISS_STALE" \
    --argjson delete_branch "$DELETE_BRANCH" \
    '{
        available: true,
        default_branch: $default_branch,
        merge_strategies: $merge_strategies,
        required_approvals: $required_approvals,
        required_checks: $required_checks,
        require_up_to_date: $require_up_to_date,
        dismiss_stale_reviews: $dismiss_stale,
        delete_branch_on_merge: $delete_branch
    }'
