#!/usr/bin/env bash
# Check if AGENTS.md files are up to date with recent git commits
# Compares the "Last updated" date in each AGENTS.md with commits affecting that scope
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Options
VERBOSE=false
JSON=false
DAYS_THRESHOLD=7  # Warn if commits are older than this many days after last update (used below)

# Parse flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --json)
            JSON=true
            shift
            ;;
        --threshold=*)
            # shellcheck disable=SC2034  # Reserved for future threshold-based staleness check
            DAYS_THRESHOLD="${1#*=}"
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: check-freshness.sh [PROJECT_DIR] [OPTIONS]

Check if AGENTS.md files are up to date with recent git commits.

Options:
  --verbose, -v         Show detailed output including commit lists
  --json                Emit machine-readable JSON on stdout (human output suppressed)
  --threshold=DAYS      Days after last update to consider stale (default: 7)
  --help, -h            Show this help message

Examples:
  check-freshness.sh .                     # Check all AGENTS.md freshness
  check-freshness.sh . --verbose           # Show commit details
  check-freshness.sh . --threshold=14      # Use 14-day threshold
EOF
            exit 0
            ;;
        *)
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

# Ensure we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository"
    exit 1
fi

# In JSON mode, route all human-readable output to /dev/null and reserve the
# original stdout (fd 3) for the single JSON document emitted at the end. This
# keeps --json strictly additive: the default (no-flag) path is untouched.
JSON_FILES=()
if [ "$JSON" = true ]; then
    exec 3>&1 1>/dev/null
fi

STALE_COUNT=0
FRESH_COUNT=0
UNKNOWN_COUNT=0

log() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $*" >&2
    fi
}

# Extract the "Last updated" date from AGENTS.md header
# Format: <!-- Managed by agent: ... Last updated: YYYY-MM-DD -->
extract_last_updated() {
    local file="$1"
    local date_str

    # Try to extract date from header comment
    date_str=$(grep -o 'Last updated: [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$file" 2>/dev/null | head -1 | sed 's/Last updated: //')

    if [ -n "$date_str" ]; then
        echo "$date_str"
        return 0
    fi

    # Try alternative formats
    # "Created: YYYY-MM-DD" or "Updated: YYYY-MM-DD"
    date_str=$(grep -oE '(Created|Updated): [0-9]{4}-[0-9]{2}-[0-9]{2}' "$file" 2>/dev/null | head -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')

    if [ -n "$date_str" ]; then
        echo "$date_str"
        return 0
    fi

    return 1
}

# Get the scope directory for an AGENTS.md file
# Root AGENTS.md covers the whole repo, scoped files cover their directory
get_scope_path() {
    local agents_file="$1"
    local dir

    dir=$(dirname "$agents_file")

    if [ "$dir" = "." ]; then
        echo "."  # Root covers everything
    else
        echo "$dir"
    fi
}

# Count commits in a scope since a given date
count_commits_since() {
    local scope_path="$1"
    local since_date="$2"
    local count

    if [ "$scope_path" = "." ]; then
        # Root: check all commits except AGENTS.md files themselves
        count=$(git log --oneline --since="$since_date" -- . ':(exclude)**/AGENTS.md' 2>/dev/null | wc -l)
    else
        # Scoped: check commits in that directory
        count=$(git log --oneline --since="$since_date" -- "$scope_path" ':(exclude)**/AGENTS.md' 2>/dev/null | wc -l)
    fi

    echo "$count"
}

# Get commit summary for a scope since a given date
get_commits_since() {
    local scope_path="$1"
    local since_date="$2"

    if [ "$scope_path" = "." ]; then
        git log --oneline --since="$since_date" -- . ':(exclude)**/AGENTS.md' 2>/dev/null | head -10
    else
        git log --oneline --since="$since_date" -- "$scope_path" ':(exclude)**/AGENTS.md' 2>/dev/null | head -10
    fi
}

# Get files changed in a scope since a given date
get_changed_files_since() {
    local scope_path="$1"
    local since_date="$2"

    if [ "$scope_path" = "." ]; then
        git log --name-only --pretty=format: --since="$since_date" -- . ':(exclude)**/AGENTS.md' 2>/dev/null | sort -u | grep -v '^$' | head -20
    else
        git log --name-only --pretty=format: --since="$since_date" -- "$scope_path" ':(exclude)**/AGENTS.md' 2>/dev/null | sort -u | grep -v '^$' | head -20
    fi
}

# Check freshness of a single AGENTS.md file
check_file_freshness() {
    local agents_file="$1"
    local rel_path="${agents_file#"$PROJECT_DIR"/}"
    local last_updated
    local scope_path
    local commit_count

    echo "Checking: $rel_path"

    # Extract last updated date
    if ! last_updated=$(extract_last_updated "$agents_file"); then
        echo "  ⚠️  No 'Last updated' date found in header"
        ((UNKNOWN_COUNT++)) || true
        if [ "$JSON" = true ]; then
            JSON_FILES+=("$(jq -nc --arg path "$rel_path" \
                '{path:$path,status:"unknown",last_updated:null,commits_since:null}')")
        fi
        return 1
    fi

    log "  Last updated: $last_updated"

    # Get scope path
    scope_path=$(get_scope_path "$agents_file")
    log "  Scope: $scope_path"

    # Count commits since last update
    commit_count=$(count_commits_since "$scope_path" "$last_updated")

    if [ "$commit_count" -eq 0 ]; then
        echo "  ✅ Up to date (no commits since $last_updated)"
        ((FRESH_COUNT++)) || true
        if [ "$JSON" = true ]; then
            JSON_FILES+=("$(jq -nc --arg path "$rel_path" --arg lu "$last_updated" \
                '{path:$path,status:"fresh",last_updated:$lu,commits_since:0}')")
        fi
        return 0
    fi

    # Check if commits are significant
    echo "  ⚠️  Potentially stale: $commit_count commit(s) since $last_updated"
    ((STALE_COUNT++)) || true
    if [ "$JSON" = true ]; then
        JSON_FILES+=("$(jq -nc --arg path "$rel_path" --arg lu "$last_updated" --argjson cs "$commit_count" \
            '{path:$path,status:"stale",last_updated:$lu,commits_since:$cs}')")
    fi

    if [ "$VERBOSE" = true ]; then
        echo "  Recent commits:"
        get_commits_since "$scope_path" "$last_updated" | while read -r line; do
            echo "    - $line"
        done

        echo "  Changed files:"
        get_changed_files_since "$scope_path" "$last_updated" | while read -r line; do
            echo "    - $line"
        done
    fi

    return 1
}

# Main
echo "Checking AGENTS.md freshness in: $PROJECT_DIR"
echo ""

# Find all AGENTS.md files
AGENTS_FILES=$(find "$PROJECT_DIR" -name "AGENTS.md" -type f 2>/dev/null | sort)

if [ -z "$AGENTS_FILES" ]; then
    echo "No AGENTS.md files found"
    exit 0
fi

# Check each file.
# `|| true`: check_file_freshness returns non-zero for stale/unknown files; without
# this guard `set -e` aborts the loop on the first such file, processing only one
# file and defeating the summary below (and forcing the validate-structure caller to
# always warn). Tolerating the non-zero lets every file be counted.
while read -r file; do
    check_file_freshness "$file" || true
    echo ""
done <<< "$AGENTS_FILES"

# Emit JSON document (machine-readable) and exit before the human summary.
if [ "$JSON" = true ]; then
    if [ "${#JSON_FILES[@]}" -eq 0 ]; then
        files_json='[]'
    else
        files_json=$(printf '%s\n' "${JSON_FILES[@]}" | jq -s '.')
    fi
    jq -nc \
        --argjson files "$files_json" \
        --argjson fresh "$FRESH_COUNT" \
        --argjson stale "$STALE_COUNT" \
        --argjson unknown "$UNKNOWN_COUNT" \
        '{script:"check-freshness",schema:1,summary:{fresh:$fresh,stale:$stale,unknown:$unknown},files:$files}' >&3
    if [ "$STALE_COUNT" -gt 0 ]; then exit 1; fi
    exit 0
fi

# Summary
echo "=== Freshness Summary ==="
echo "✅ Up to date: $FRESH_COUNT"
echo "⚠️  Potentially stale: $STALE_COUNT"
[ "$UNKNOWN_COUNT" -gt 0 ] && echo "❓ Unknown (no date): $UNKNOWN_COUNT"

if [ "$STALE_COUNT" -gt 0 ]; then
    echo ""
    echo "Recommendation: Review the stale AGENTS.md files and update if needed."
    echo "Use --verbose to see which commits and files have changed."
    exit 1
fi

exit 0
