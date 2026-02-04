# GitHub Repository Settings Feature

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract GitHub repository settings (merge strategies, required approvals, required checks) and display in AGENTS.md.

**Architecture:** New `extract-github-settings.sh` script that uses `gh` CLI to fetch repo and branch protection settings. Gracefully returns `{}` if unavailable. New "Repository Settings" section in root template.

**Tech Stack:** Bash, gh CLI, jq

---

## Task 1: Create extract-github-settings.sh

**Files:**
- Create: `skills/agents/scripts/extract-github-settings.sh`

**Implementation:**
```bash
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

# Build merge strategies array
STRATEGIES="[]"
[ "$ALLOW_SQUASH" = "true" ] && STRATEGIES=$(echo "$STRATEGIES" | jq '. + ["squash"]')
[ "$ALLOW_MERGE" = "true" ] && STRATEGIES=$(echo "$STRATEGIES" | jq '. + ["merge"]')
[ "$ALLOW_REBASE" = "true" ] && STRATEGIES=$(echo "$STRATEGIES" | jq '. + ["rebase"]')

# Fetch branch protection (may fail if not configured or no access)
PROTECTION=$(gh api "repos/$OWNER_REPO/branches/$DEFAULT_BRANCH/protection" 2>/dev/null || echo "{}")

# Extract protection settings
REQUIRED_APPROVALS=0
REQUIRED_CHECKS="[]"
REQUIRE_UP_TO_DATE=false

if [ "$PROTECTION" != "{}" ]; then
    # Required approving reviews
    REQUIRED_APPROVALS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')

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
    '{
        available: true,
        default_branch: $default_branch,
        merge_strategies: $merge_strategies,
        required_approvals: $required_approvals,
        required_checks: $required_checks,
        require_up_to_date: $require_up_to_date
    }'
```

**Test:**
```bash
chmod +x skills/agents/scripts/extract-github-settings.sh
bash skills/agents/scripts/extract-github-settings.sh .
```

**Commit:** `feat(extract): add extract-github-settings.sh for repo settings`

---

## Task 2: Add Repository Settings Section to Template

**Files:**
- Modify: `skills/agents/assets/root-thin.md`

**Add after "Heuristics" section, before "Boundaries":**
```markdown
## Repository Settings
<!-- AGENTS-GENERATED:START repo-settings -->
{{REPO_SETTINGS}}
<!-- AGENTS-GENERATED:END repo-settings -->
```

**The content will be formatted as:**
```markdown
- **Default branch:** `main`
- **Merge strategy:** squash (preferred), merge
- **Required approvals:** 1
- **Required checks:** `test`, `lint`, `build`
- **Require up-to-date:** yes — rebase before merge
```

**Commit:** `feat(template): add Repository Settings section`

---

## Task 3: Integrate into generate-agents.sh

**Files:**
- Modify: `skills/agents/scripts/generate-agents.sh`

**Add extraction call (around line 355):**
```bash
# Extract GitHub settings
log "Extracting GitHub settings..."
GITHUB_SETTINGS=$("$SCRIPT_DIR/extract-github-settings.sh" "$PROJECT_DIR" 2>/dev/null || echo '{}')
[ "$VERBOSE" = true ] && echo "$GITHUB_SETTINGS" | jq . >&2
```

**Add template variable building (in vars section):**
```bash
# Build repository settings content
build_repo_settings() {
    local settings_json="$1"
    local available
    available=$(echo "$settings_json" | jq -r '.available // false')

    [ "$available" != "true" ] && return 0

    local content=""
    local default_branch merge_strategies required_approvals required_checks require_up_to_date

    default_branch=$(echo "$settings_json" | jq -r '.default_branch')
    merge_strategies=$(echo "$settings_json" | jq -r '.merge_strategies | join(", ")')
    required_approvals=$(echo "$settings_json" | jq -r '.required_approvals')
    required_checks=$(echo "$settings_json" | jq -r '.required_checks | map("`" + . + "`") | join(", ")')
    require_up_to_date=$(echo "$settings_json" | jq -r '.require_up_to_date')

    content="- **Default branch:** \`$default_branch\`\n"
    [ -n "$merge_strategies" ] && content="${content}- **Merge strategy:** $merge_strategies\n"
    [ "$required_approvals" != "0" ] && content="${content}- **Required approvals:** $required_approvals\n"
    [ -n "$required_checks" ] && [ "$required_checks" != "" ] && content="${content}- **Required checks:** $required_checks\n"
    [ "$require_up_to_date" = "true" ] && content="${content}- **Require up-to-date:** yes — rebase before merge\n"

    echo -e "$content"
}

vars[REPO_SETTINGS]=$(build_repo_settings "$GITHUB_SETTINGS")
```

**Test:**
```bash
bash skills/agents/scripts/generate-agents.sh . --force --verbose
grep -A10 "Repository Settings" AGENTS.md
```

**Commit:** `feat(generate): integrate GitHub settings into AGENTS.md`

---

## Task 4: Handle Empty Section

**Files:**
- Modify: `skills/agents/scripts/lib/template.sh`

The existing `remove_empty_sections()` function should handle this, but verify the `repo-settings` section is removed when `{{REPO_SETTINGS}}` is empty.

**Test:**
```bash
# Test with a non-GitHub repo or when gh is not authenticated
cd /tmp && mkdir test-repo && cd test-repo && git init
bash /path/to/generate-agents.sh . --force
grep "Repository Settings" AGENTS.md  # Should not appear
```

**Commit:** (if changes needed) `fix(template): ensure empty repo-settings section is removed`

---

## Task 5: Test and Verify

**Run on agents-skill repo:**
```bash
bash skills/agents/scripts/generate-agents.sh . --force
cat AGENTS.md | grep -A10 "Repository Settings"
```

**Expected output:**
```markdown
## Repository Settings
- **Default branch:** `main`
- **Merge strategy:** squash, merge
- **Required approvals:** 1
- **Required checks:** `shellcheck`, `test-generator`, `validate`, `checkpoints`
```

**Commit:** `chore: regenerate AGENTS.md with repo settings`

---

## Task 6: Bump Version and Release

- Update `plugin.json` to `2.9.0`
- Create signed tag
- Push and create release

---

## Summary

| File | Change |
|------|--------|
| `extract-github-settings.sh` | New script - fetches repo settings via gh CLI |
| `root-thin.md` | Add Repository Settings section |
| `generate-agents.sh` | Call extractor, build content, set template var |
| `lib/template.sh` | Verify empty section removal works |
