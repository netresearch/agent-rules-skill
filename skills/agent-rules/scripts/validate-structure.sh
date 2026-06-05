#!/usr/bin/env bash
# Validate AGENTS.md structure compliance and optionally check freshness
# Note: -e intentionally omitted - we accumulate errors and report at end
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default options
PROJECT_DIR=""
CHECK_FRESHNESS=false
VERBOSE=false
JSON=false

# Parse flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --check-freshness|-f)
            CHECK_FRESHNESS=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --json)
            JSON=true
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: validate-structure.sh [PROJECT_DIR] [OPTIONS]

Validate AGENTS.md structure compliance and optionally check freshness.

Options:
  --check-freshness, -f  Also check if files are up to date with git commits
  --verbose, -v          Show detailed output
  --json                 Emit machine-readable JSON on stdout (structure only)
  --help, -h             Show this help message

Examples:
  validate-structure.sh .                      # Structure check only
  validate-structure.sh . --check-freshness    # Structure + freshness check
  validate-structure.sh . -f -v                # Full check with details
EOF
            exit 0
            ;;
        *)
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

PROJECT_DIR="${PROJECT_DIR:-.}"
cd "$PROJECT_DIR" || exit 1

ERRORS=0
WARNINGS=0

# --json state: each helper records the outcome of the just-run check so that
# record_check can attach it to a per-file record. Default-path output is unchanged.
LAST_STATUS=""
LAST_DETAIL=""
declare -A FILE_CHECKS_JSON=()
declare -A FILE_ROLE=()

error() {
    echo "❌ ERROR: $*"
    ((ERRORS+=1))
    LAST_STATUS="fail"; LAST_DETAIL="$*"
}

warning() {
    echo "⚠️  WARNING: $*"
    ((WARNINGS+=1))
    LAST_STATUS="warn"; LAST_DETAIL="$*"
}

success() {
    echo "✅ $*"
    LAST_STATUS="pass"; LAST_DETAIL="$*"
}

info() {
    echo "ℹ️  $*"
    LAST_STATUS="pass"; LAST_DETAIL="$*"
}

# Record the just-run check (LAST_STATUS/LAST_DETAIL) under a relative file path.
# No-op unless --json; never writes to stdout.
record_check() {
    [[ "$JSON" = true ]] || return 0
    local path="$1" name="$2" obj
    obj=$(jq -nc --arg name "$name" --arg status "$LAST_STATUS" --arg detail "$LAST_DETAIL" \
        '{name:$name,status:$status,detail:$detail}')
    FILE_CHECKS_JSON["$path"]="${FILE_CHECKS_JSON["$path"]:-}${obj}"$'\n'
}

# Check if file has managed header
check_managed_header() {
    local file="$1"

    if grep -q "^<!-- Managed by agent:" "$file"; then
        success "Managed header present: $file"
        return 0
    else
        warning "Missing managed header: $file"
        return 1
    fi
}

# Check if root is thin (≤50 lines or has scope index)
check_root_is_thin() {
    local file="$1"
    local line_count
    line_count=$(wc -l < "$file")

    if [ "$line_count" -le 50 ]; then
        success "Root is thin: $line_count lines"
        return 0
    elif grep -q "## Index of scoped AGENTS.md" "$file"; then
        success "Root has scope index (verbose style acceptable)"
        return 0
    else
        error "Root is bloated: $line_count lines and no scope index"
        return 1
    fi
}

# Check if root has precedence statement
check_precedence_statement() {
    local file="$1"

    if grep -qi "precedence" "$file" && grep -qi "closest.*AGENTS.md.*wins" "$file"; then
        success "Precedence statement present"
        return 0
    else
        error "Missing precedence statement in root"
        return 1
    fi
}

# Check if scoped file has all required sections (with alternatives)
check_scoped_sections() {
    local file="$1"

    # Each entry: "Display Name|pattern1|pattern2|..."
    local section_patterns=(
        "Overview|## Overview"
        "Setup|## Setup|## Environment|## Prerequisites|## Getting Started|## Workflow files"
        "Build/Tests|## Build|## Tests|## Running|## Commands|## Common patterns"
        "Code style|## Code style|## Style|## Conventions|## Workflow conventions"
        "Security|## Security"
        "Checklist|## PR|## Commit|## Checklist"
        "Examples|## Good vs|## Examples|## Bad examples|## Patterns to Follow"
        "When stuck|## When stuck|## Help|## Resources|## Troubleshooting"
    )

    local missing=()

    for entry in "${section_patterns[@]}"; do
        local name="${entry%%|*}"
        local patterns="${entry#*|}"
        local found=false

        # Try each pattern
        IFS='|' read -ra pattern_array <<< "$patterns"
        for pattern in "${pattern_array[@]}"; do
            if grep -qi "^$pattern" "$file"; then
                found=true
                break
            fi
        done

        if [ "$found" = false ]; then
            missing+=("$name")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        success "All required sections present: $file"
        return 0
    else
        error "Missing sections in $file: ${missing[*]}"
        return 1
    fi
}

# Check if scope index links work
check_scope_links() {
    local root_file="$1"

    if ! grep -q "## Index of scoped AGENTS.md" "$root_file"; then
        return 0  # No index, skip check
    fi

    # Extract links from scope index
    local links
    links=$(sed -n '/## Index of scoped AGENTS.md/,/^##/p' "$root_file" | grep -o '\./[^)]*AGENTS.md' || true)

    if [ -z "$links" ]; then
        # Empty scope index with AGENTS-GENERATED markers is valid (placeholder)
        if grep -q "<!-- AGENTS-GENERATED:START scope-index -->" "$root_file" && \
           grep -q "<!-- AGENTS-GENERATED:END scope-index -->" "$root_file"; then
            info "Scope index is empty (placeholder)"
            return 0
        fi
        warning "Scope index present but no links found"
        return 1
    fi

    local broken=()
    while read -r link; do
        # Remove leading ./
        local clean_link="${link#./}"
        local full_path="$PROJECT_DIR/$clean_link"

        if [ ! -f "$full_path" ]; then
            broken+=("$link")
        fi
    done <<< "$links"

    if [ ${#broken[@]} -eq 0 ]; then
        success "All scope index links work"
        return 0
    else
        error "Broken scope index links: ${broken[*]}"
        return 1
    fi
}

# Check CLAUDE.md symlink exists alongside an AGENTS.md file
check_claude_symlink() {
    local agents_file="$1"
    local dir
    dir=$(dirname "$agents_file")
    local claude_file="$dir/CLAUDE.md"
    local rel_dir="${dir#"$PROJECT_DIR"}"
    [ -z "$rel_dir" ] && rel_dir="(root)"

    if [ -L "$claude_file" ]; then
        local target
        target=$(readlink "$claude_file")
        if [ "$target" = "AGENTS.md" ]; then
            success "CLAUDE.md symlink correct: $rel_dir"
            return 0
        else
            error "CLAUDE.md symlink points to '$target', expected 'AGENTS.md': $rel_dir"
            return 1
        fi
    elif [ -f "$claude_file" ]; then
        warning "CLAUDE.md is a regular file, not a symlink to AGENTS.md: $rel_dir"
        return 1
    else
        error "Missing CLAUDE.md symlink to AGENTS.md: $rel_dir (Claude Code won't read AGENTS.md without it)"
        return 1
    fi
}

# In JSON mode, route all human-readable output to /dev/null and reserve the
# original stdout (fd 3) for the single JSON document emitted at the end.
if [[ "$JSON" = true ]]; then
    exec 3>&1 1>/dev/null
fi

# Main validation
echo "Validating AGENTS.md structure in: $PROJECT_DIR"
echo ""

# Check root AGENTS.md
ROOT_FILE="$PROJECT_DIR/AGENTS.md"

if [ ! -f "$ROOT_FILE" ]; then
    error "Root AGENTS.md not found"
else
    echo "=== Root AGENTS.md ==="
    FILE_ROLE["AGENTS.md"]="root"
    check_managed_header "$ROOT_FILE"; record_check "AGENTS.md" "managed_header"
    check_root_is_thin "$ROOT_FILE"; record_check "AGENTS.md" "root_is_thin"
    check_precedence_statement "$ROOT_FILE"; record_check "AGENTS.md" "precedence"
    check_scope_links "$ROOT_FILE"; record_check "AGENTS.md" "scope_links"
    echo ""
fi

# Check CLAUDE.md symlinks
echo "=== CLAUDE.md Symlinks ==="
ALL_AGENTS_FILES=$(find "$PROJECT_DIR" -name "AGENTS.md" \
    -not -path "*/references/examples/*" \
    -not -path "*/examples/*" \
    -not -path "*/.git/*" \
    -not -path "*/vendor/*" \
    -not -path "*/node_modules/*" \
    2>/dev/null || true)

if [ -n "$ALL_AGENTS_FILES" ]; then
    while read -r file; do
        check_claude_symlink "$file"
        sym_rel="${file#"$PROJECT_DIR"/}"; sym_rel="${sym_rel#./}"
        record_check "$sym_rel" "claude_symlink"
    done <<< "$ALL_AGENTS_FILES"
fi
echo ""

# Check scoped AGENTS.md files (exclude reference examples)
SCOPED_FILES=$(find "$PROJECT_DIR" -name "AGENTS.md" \
    -not -path "$ROOT_FILE" \
    -not -path "*/references/examples/*" \
    -not -path "*/examples/*" \
    -not -path "*/.git/*" \
    2>/dev/null || true)

if [ -n "$SCOPED_FILES" ]; then
    echo "=== Scoped AGENTS.md Files ==="
    while read -r file; do
        rel_path="${file#"$PROJECT_DIR"/}"
        echo "Checking: $rel_path"
        json_key="${rel_path#./}"
        FILE_ROLE["$json_key"]="scoped"
        check_managed_header "$file"; record_check "$json_key" "managed_header"
        check_scoped_sections "$file"; record_check "$json_key" "required_sections"
        echo ""
    done <<< "$SCOPED_FILES"
fi

# Emit JSON document and exit before the human summary. JSON mode is structure-only
# and deliberately does NOT run the --check-freshness shell-out below (score-agents
# calls check-freshness.sh --json itself), keeping the two signals decoupled.
if [[ "$JSON" = true ]]; then
    json_files=()
    if [[ "${#FILE_CHECKS_JSON[@]}" -gt 0 ]]; then
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            checks_json=$(printf '%s' "${FILE_CHECKS_JSON[$path]}" | jq -s '.')
            json_files+=("$(jq -nc \
                --arg path "$path" \
                --arg role "${FILE_ROLE[$path]:-scoped}" \
                --argjson checks "$checks_json" \
                '{path:$path,role:$role,
                  errors:($checks|map(select(.status=="fail"))|length),
                  warnings:($checks|map(select(.status=="warn"))|length),
                  checks:$checks}')")
        done < <(printf '%s\n' "${!FILE_CHECKS_JSON[@]}" | sort)
    fi
    if [[ "${#json_files[@]}" -eq 0 ]]; then
        files_json='[]'
    else
        files_json=$(printf '%s\n' "${json_files[@]}" | jq -s '.')
    fi
    jq -nc \
        --argjson files "$files_json" \
        --argjson e "$ERRORS" \
        --argjson w "$WARNINGS" \
        '{script:"validate-structure",schema:1,summary:{errors:$e,warnings:$w},files:$files}' >&3
    if [[ "$ERRORS" -eq 0 ]]; then exit 0; else exit 1; fi
fi

# Summary
echo "=== Structure Validation Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All structure checks passed!"
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Structure validation passed with $WARNINGS warning(s)"
else
    echo "❌ Structure validation failed with $ERRORS error(s) and $WARNINGS warning(s)"
fi

# Run freshness check if requested
if [ "$CHECK_FRESHNESS" = true ]; then
    echo ""
    echo "=== Freshness Check ==="
    FRESHNESS_ARGS=""
    [ "$VERBOSE" = true ] && FRESHNESS_ARGS="--verbose"

    if "$SCRIPT_DIR/check-freshness.sh" "$PROJECT_DIR" $FRESHNESS_ARGS; then
        echo "✅ All files are up to date!"
    else
        # Freshness issues are warnings, not errors
        ((WARNINGS+=1))
    fi
fi

echo ""
echo "=== Final Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All checks passed!"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Passed with $WARNINGS warning(s)"
    exit 0
else
    echo "❌ Failed with $ERRORS error(s) and $WARNINGS warning(s)"
    exit 1
fi
