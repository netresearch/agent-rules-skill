#!/usr/bin/env bash
# Main AGENTS.md generator script
# Requires: Bash 4.3+ (for nameref variables)
set -euo pipefail

# Check Bash version - we need 4.3+ for nameref variables (local -n)
if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3))); then
    echo "Error: Bash 4.3+ required (found ${BASH_VERSION})." >&2
    echo "On macOS: brew install bash" >&2
    echo "Then run with: /opt/homebrew/bin/bash $0 $*" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$SKILL_DIR/assets"

# Source helper libraries
source "$SCRIPT_DIR/lib/template.sh"
source "$SCRIPT_DIR/lib/summary.sh"

# Default options
PROJECT_DIR="${1:-.}"
STYLE="${STYLE:-thin}"
DRY_RUN=false
UPDATE_ONLY=false
FORCE=false
VERBOSE=false
CLAUDE_SHIM=false

# Parse flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --style=*)
            STYLE="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --update)
            UPDATE_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --claude-shim)
            CLAUDE_SHIM=true
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: generate-agents.sh [PROJECT_DIR] [OPTIONS]

Generate AGENTS.md files for a project following the public agents.md convention.

Options:
  --style=thin|verbose    Template style (default: thin)
  --dry-run               Preview what will be created
  --update                Update existing files only
  --force                 Force regeneration of existing files
  --claude-shim           Generate CLAUDE.md that imports AGENTS.md
  --verbose, -v           Verbose output
  --help, -h              Show this help message

Examples:
  generate-agents.sh .                    # Generate thin root + scoped files
  generate-agents.sh . --dry-run          # Preview changes
  generate-agents.sh . --style=verbose    # Use verbose root template
  generate-agents.sh . --update           # Update existing files
  generate-agents.sh . --claude-shim      # Also generate CLAUDE.md shim
EOF
            exit 0
            ;;
        *)
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

# Validate PROJECT_DIR exists
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory not found: $PROJECT_DIR" >&2
    exit 1
fi

# Convert to absolute path before cd (so subsequent script calls work)
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
cd "$PROJECT_DIR"

# Initialize summary tracking
init_summary

log() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $*" >&2
    fi
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

# Detect Node.js package manager for a scope directory
# Walks up from scope dir to find package.json with lockfile
detect_node_package_manager() {
    local scope_dir="$1"
    local search_dir="$scope_dir"

    # Walk up to find package.json
    while [ "$search_dir" != "." ] && [ "$search_dir" != "/" ]; do
        if [ -f "$search_dir/package.json" ]; then
            # Found package.json, check for lockfiles
            [ -f "$search_dir/pnpm-lock.yaml" ] && echo "pnpm" && return
            [ -f "$search_dir/yarn.lock" ] && echo "yarn" && return
            [ -f "$search_dir/bun.lockb" ] && echo "bun" && return
            [ -f "$search_dir/package-lock.json" ] && echo "npm" && return
            # No lockfile, default to npm
            echo "npm"
            return
        fi
        search_dir=$(dirname "$search_dir")
    done

    # Check root as last resort
    if [ -f "package.json" ]; then
        [ -f "pnpm-lock.yaml" ] && echo "pnpm" && return
        [ -f "yarn.lock" ] && echo "yarn" && return
        [ -f "bun.lockb" ] && echo "bun" && return
        echo "npm"
        return
    fi

    # Fallback: use from PROJECT_INFO if available
    if [ -n "${PROJECT_INFO:-}" ]; then
        local pkg_mgr
        pkg_mgr=$(echo "$PROJECT_INFO" | jq -r '.package_manager // "unknown"')
        if [ "$pkg_mgr" != "unknown" ] && [ "$pkg_mgr" != "go" ] && [ "$pkg_mgr" != "composer" ]; then
            echo "$pkg_mgr"
            return
        fi
    fi

    echo "npm"  # Ultimate fallback
}

# Byte budget enforcement (OpenAI Codex default: 32 KiB for combined instructions)
BYTE_BUDGET="${BYTE_BUDGET:-32768}"

enforce_byte_budget() {
    local file="$1"
    local budget="$2"

    [ ! -f "$file" ] && return 0

    local size
    size=$(wc -c < "$file")

    if [ "$size" -le "$budget" ]; then
        log "File size: $size bytes (within $budget budget)"
        return 0
    fi

    log "File exceeds byte budget ($size > $budget), pruning..."

    local content
    content=$(cat "$file")
    local pruned=false

    # Strategy 1: Reduce golden samples to 5
    if echo "$content" | grep -q "AGENTS-GENERATED:START golden-samples"; then
        local sample_count
        sample_count=$(echo "$content" | sed -n '/AGENTS-GENERATED:START golden-samples/,/AGENTS-GENERATED:END golden-samples/p' | grep -c "^|" || echo 0)
        if [ "$sample_count" -gt 7 ]; then  # header + separator + 5 data rows = 7
            content=$(echo "$content" | awk '
                /AGENTS-GENERATED:START golden-samples/ { in_section=1; count=0; print; next }
                /AGENTS-GENERATED:END golden-samples/ { in_section=0; print; next }
                in_section && /^\|/ { count++; if (count <= 7) print; next }
                { print }
            ')
            pruned=true
            log "  - Reduced golden samples to 5"
        fi
    fi

    # Strategy 2: Reduce heuristics to 5
    if echo "$content" | grep -q "AGENTS-GENERATED:START heuristics"; then
        local heuristic_count
        heuristic_count=$(echo "$content" | sed -n '/AGENTS-GENERATED:START heuristics/,/AGENTS-GENERATED:END heuristics/p' | grep -c "^|" || echo 0)
        if [ "$heuristic_count" -gt 7 ]; then  # header + separator + 5 data rows = 7
            content=$(echo "$content" | awk '
                /AGENTS-GENERATED:START heuristics/ { in_section=1; count=0; print; next }
                /AGENTS-GENERATED:END heuristics/ { in_section=0; print; next }
                in_section && /^\|/ { count++; if (count <= 7) print; next }
                { print }
            ')
            pruned=true
            log "  - Reduced heuristics to 5"
        fi
    fi

    # Strategy 3: Reduce utilities to 5
    if echo "$content" | grep -q "AGENTS-GENERATED:START utilities"; then
        local utility_count
        utility_count=$(echo "$content" | sed -n '/AGENTS-GENERATED:START utilities/,/AGENTS-GENERATED:END utilities/p' | grep -c "^|" || echo 0)
        if [ "$utility_count" -gt 7 ]; then  # header + separator + 5 data rows = 7
            content=$(echo "$content" | awk '
                /AGENTS-GENERATED:START utilities/ { in_section=1; count=0; print; next }
                /AGENTS-GENERATED:END utilities/ { in_section=0; print; next }
                in_section && /^\|/ { count++; if (count <= 7) print; next }
                { print }
            ')
            pruned=true
            log "  - Reduced utilities to 5"
        fi
    fi

    # Write pruned content
    if [ "$pruned" = true ]; then
        echo "$content" > "$file"
        local new_size
        new_size=$(wc -c < "$file")
        echo "⚠️  Pruned due to size budget ($size → $new_size bytes)"
    fi

    return 0
}

# Detect project
log "Detecting project type..."
PROJECT_INFO=$("$SCRIPT_DIR/detect-project.sh" "$PROJECT_DIR")
[ "$VERBOSE" = true ] && echo "$PROJECT_INFO" | jq . >&2

LANGUAGE=$(echo "$PROJECT_INFO" | jq -r '.language')
VERSION=$(echo "$PROJECT_INFO" | jq -r '.version')
PROJECT_TYPE=$(echo "$PROJECT_INFO" | jq -r '.type')

[ "$LANGUAGE" = "unknown" ] && error "Could not detect project language"

# Detect scopes
log "Detecting scopes..."
SCOPES_INFO=$("$SCRIPT_DIR/detect-scopes.sh" "$PROJECT_DIR")
[ "$VERBOSE" = true ] && echo "$SCOPES_INFO" | jq . >&2

# Extract commands
log "Extracting build commands..."
COMMANDS=$("$SCRIPT_DIR/extract-commands.sh" "$PROJECT_DIR")
[ "$VERBOSE" = true ] && echo "$COMMANDS" | jq . >&2

# Extract documentation (README, CONTRIBUTING, SECURITY, etc.)
log "Extracting documentation..."
DOCS_INFO=$("$SCRIPT_DIR/extract-documentation.sh" "$PROJECT_DIR")
[ "$VERBOSE" = true ] && echo "$DOCS_INFO" | jq . >&2

# Extract platform files (.github/, .gitlab/, etc.)
log "Extracting platform files..."
PLATFORM_INFO=$("$SCRIPT_DIR/extract-platform-files.sh" "$PROJECT_DIR")
[ "$VERBOSE" = true ] && echo "$PLATFORM_INFO" | jq . >&2

# Extract IDE settings (.editorconfig, .vscode/, etc.)
log "Extracting IDE settings..."
IDE_INFO=$("$SCRIPT_DIR/extract-ide-settings.sh" "$PROJECT_DIR")
[ "$VERBOSE" = true ] && echo "$IDE_INFO" | jq . >&2

# Extract AI agent configs (.cursor/, .claude/, etc.)
log "Extracting AI agent configs..."
AGENT_INFO=$("$SCRIPT_DIR/extract-agent-configs.sh" "$PROJECT_DIR")
[ "$VERBOSE" = true ] && echo "$AGENT_INFO" | jq . >&2

# Generate file map
log "Generating file map..."
FILE_MAP=$("$SCRIPT_DIR/generate-file-map.sh" "$PROJECT_DIR" 2>/dev/null || echo "")

# Detect golden samples
log "Detecting golden samples..."
GOLDEN_SAMPLES=$("$SCRIPT_DIR/detect-golden-samples.sh" "$PROJECT_DIR" 2>/dev/null || echo "")

# Detect utilities
log "Detecting utilities..."
UTILITIES_LIST=$("$SCRIPT_DIR/detect-utilities.sh" "$PROJECT_DIR" 2>/dev/null || echo "")

# Detect heuristics
log "Detecting heuristics..."
HEURISTICS=$("$SCRIPT_DIR/detect-heuristics.sh" "$PROJECT_DIR" 2>/dev/null || echo "")

# Extract quality configs (detailed linter/formatter settings)
log "Extracting quality configs..."
QUALITY_CONFIG=$("$SCRIPT_DIR/extract-quality-configs.sh" "$PROJECT_DIR" 2>/dev/null || echo '{}')
[ "$VERBOSE" = true ] && echo "$QUALITY_CONFIG" | jq . >&2

# Extract CI commands
log "Extracting CI commands..."
CI_INFO=$("$SCRIPT_DIR/extract-ci-commands.sh" "$PROJECT_DIR" 2>/dev/null || echo '{}')
[ "$VERBOSE" = true ] && echo "$CI_INFO" | jq . >&2

# Determine command source confidence
# Priority: CI > Makefile > package.json/composer.json > fallback defaults
get_command_source() {
    local ci_system
    ci_system=$(echo "$CI_INFO" | jq -r '.ci_system // "none"')

    if [ "$ci_system" != "none" ] && [ "$ci_system" != "null" ]; then
        local ci_commands
        ci_commands=$(echo "$CI_INFO" | jq -r '.github_actions.run_commands // .gitlab_ci.script_commands // [] | length')
        if [ "$ci_commands" -gt 0 ]; then
            echo "CI ($ci_system)"
            return 0
        fi
    fi

    if [ -f "Makefile" ]; then
        echo "Makefile"
        return 0
    fi

    case "$LANGUAGE" in
        "typescript"|"javascript")
            [ -f "package.json" ] && echo "package.json" && return 0
            ;;
        "php")
            [ -f "composer.json" ] && echo "composer.json" && return 0
            ;;
        "python")
            [ -f "pyproject.toml" ] && echo "pyproject.toml" && return 0
            [ -f "setup.py" ] && echo "setup.py" && return 0
            ;;
        "go")
            [ -f "go.mod" ] && echo "go.mod" && return 0
            ;;
    esac

    echo "defaults"
}

COMMAND_SOURCE=$(get_command_source)
log "Command source: $COMMAND_SOURCE"

# Analyze git history for conventions
log "Analyzing git history..."
GIT_HISTORY=$("$SCRIPT_DIR/analyze-git-history.sh" "$PROJECT_DIR" 2>/dev/null || echo '{}')
[ "$VERBOSE" = true ] && echo "$GIT_HISTORY" | jq . >&2

# Helper: Safe jq extraction that filters null values
# Usage: jq_safe "$json" '.path.to.value'
jq_safe() {
    local json="$1"
    local path="$2"
    local result
    result=$(echo "$json" | jq -r "$path // empty | select(. != null and . != \"null\" and . != \"\")")
    echo "$result"
}

# Helper: Build quality standards from quality config
build_quality_standards() {
    local quality_json="$1"
    local standards=""

    # Get detected tools
    local tools
    tools=$(echo "$quality_json" | jq -r '.detected_tools | if . and . != null then join(", ") else "" end | select(. != "")')
    [ -n "$tools" ] && standards="$standards- Quality tools: $tools\n"

    # PHPStan level
    local phpstan_level
    phpstan_level=$(jq_safe "$quality_json" '.phpstan.level')
    [ -n "$phpstan_level" ] && standards="$standards- PHPStan level: $phpstan_level (do not lower)\n"

    # TypeScript strict mode
    local ts_strict
    ts_strict=$(jq_safe "$quality_json" '.typescript.strict')
    [ "$ts_strict" = "true" ] && standards="$standards- TypeScript: strict mode enabled\n"

    # Line length settings
    local line_length
    line_length=$(jq_safe "$quality_json" '.golangci_lint.line_length // .prettier.print_width // .black.line_length // .ruff.line_length')
    [ -n "$line_length" ] && standards="$standards- Line length: $line_length\n"

    # ESLint extends
    local eslint_extends
    eslint_extends=$(jq_safe "$quality_json" '.eslint.extends')
    [ -n "$eslint_extends" ] && standards="$standards- ESLint: extends $eslint_extends\n"

    # PHP-CS-Fixer ruleset
    local php_cs_ruleset
    php_cs_ruleset=$(jq_safe "$quality_json" '.php_cs_fixer.rule_set')
    [ -n "$php_cs_ruleset" ] && standards="$standards- PHP-CS-Fixer: $php_cs_ruleset rules\n"

    # Mypy strict
    local mypy_strict
    mypy_strict=$(jq_safe "$quality_json" '.mypy.strict')
    [ "$mypy_strict" = "True" ] || [ "$mypy_strict" = "true" ] && standards="$standards- Mypy: strict mode enabled\n"

    # Ruff select rules
    local ruff_select
    ruff_select=$(jq_safe "$quality_json" '.ruff.select')
    [ -n "$ruff_select" ] && standards="$standards- Ruff: $ruff_select\n"

    # Default if nothing found
    [ -z "$standards" ] && standards="- Follow project linting and formatting rules\n- Write tests for new functionality\n- Keep functions focused and well-documented\n"

    echo -e "$standards"
}

# Helper: Build workflow section from git history
build_workflow_info() {
    local git_json="$1"
    local workflow=""

    # Commit convention
    local convention
    convention=$(echo "$git_json" | jq -r '.commit_convention.convention // "unknown" | select(. != null)')
    [ -z "$convention" ] && convention="unknown"
    local confidence
    confidence=$(echo "$git_json" | jq -r '.commit_convention.confidence // 0 | select(. != null)')
    [ -z "$confidence" ] && confidence=0

    if [ "$convention" != "unknown" ] && [ "$confidence" -gt 30 ]; then
        case "$convention" in
            "conventional-commits")
                workflow="$workflow- Commits: Use Conventional Commits (feat:, fix:, docs:, etc.)\n"
                ;;
            "tag-prefix")
                workflow="$workflow- Commits: Use [TAG] prefix style\n"
                ;;
            "emoji")
                workflow="$workflow- Commits: Use emoji prefixes\n"
                ;;
            "ticket-reference")
                workflow="$workflow- Commits: Include ticket references (JIRA-123, #123)\n"
                ;;
        esac
    fi

    # Merge strategy
    local merge_strategy
    merge_strategy=$(echo "$git_json" | jq -r '.merge_strategy.strategy // "unknown"')
    case "$merge_strategy" in
        "squash-and-merge")
            workflow="$workflow- PRs: Squash and merge\n"
            ;;
        "merge-commits")
            workflow="$workflow- PRs: Create merge commits\n"
            ;;
    esac

    # Branch naming
    local branch_pattern
    branch_pattern=$(echo "$git_json" | jq -r '.branch_naming.pattern // "unknown"')
    local uses_feature
    uses_feature=$(echo "$git_json" | jq -r '.branch_naming.uses_feature_branches // false')

    if [ "$uses_feature" = "true" ]; then
        workflow="$workflow- Branches: feature/, fix/, hotfix/ prefixes\n"
    elif [ "$branch_pattern" = "ticket-based" ]; then
        workflow="$workflow- Branches: Include ticket reference in name\n"
    fi

    # Release pattern
    local release_pattern
    release_pattern=$(echo "$git_json" | jq -r '.releases.pattern // "unknown"')
    local uses_v
    uses_v=$(echo "$git_json" | jq -r '.releases.uses_v_prefix // false')

    if [ "$release_pattern" = "semver" ]; then
        [ "$uses_v" = "true" ] && workflow="$workflow- Releases: Semantic versioning (vX.Y.Z)\n" || workflow="$workflow- Releases: Semantic versioning (X.Y.Z)\n"
    elif [ "$release_pattern" = "calver" ]; then
        workflow="$workflow- Releases: Calendar versioning (YYYY.MM.DD)\n"
    fi

    # Default branch
    local default_branch
    default_branch=$(echo "$git_json" | jq -r '.default_branch // "main"')
    [ -n "$default_branch" ] && [ "$default_branch" != "null" ] && workflow="$workflow- Default branch: $default_branch\n"

    echo -e "$workflow"
}

# Generate root AGENTS.md
ROOT_FILE="$PROJECT_DIR/AGENTS.md"

if [ -f "$ROOT_FILE" ] && [ "$FORCE" = false ] && [ "$UPDATE_ONLY" = false ]; then
    log "Root AGENTS.md already exists, skipping (use --force to regenerate)"
elif [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would create/update: $ROOT_FILE"
else
    log "Generating root AGENTS.md..."

    # Select template
    if [ "$STYLE" = "verbose" ]; then
        TEMPLATE="$TEMPLATE_DIR/root-verbose.md"
    else
        TEMPLATE="$TEMPLATE_DIR/root-thin.md"
    fi

    # Prepare template variables
    declare -A vars
    vars[TIMESTAMP]=$(get_timestamp)
    vars[VERIFIED_TIMESTAMP]="never"
    vars[COMMAND_SOURCE]="$COMMAND_SOURCE"
    vars[LANGUAGE_CONVENTIONS]=$(get_language_conventions "$LANGUAGE" "$VERSION")

    # Command extraction - only set if non-empty (leaves placeholder for row deletion)
    set_if_present() {
        local key="$1"
        local value="$2"
        if [ -n "$value" ] && [ "$value" != "null" ]; then
            vars[$key]="$value"
        fi
        return 0
    }
    set_if_present INSTALL_CMD "$(echo "$COMMANDS" | jq -r '.install // empty')"
    set_if_present TYPECHECK_CMD "$(echo "$COMMANDS" | jq -r '.typecheck // empty')"
    set_if_present LINT_CMD "$(echo "$COMMANDS" | jq -r '.lint // empty')"
    set_if_present FORMAT_CMD "$(echo "$COMMANDS" | jq -r '.format // empty')"
    set_if_present TEST_CMD "$(echo "$COMMANDS" | jq -r '.test // empty')"
    set_if_present TEST_SINGLE_CMD "$(echo "$COMMANDS" | jq -r '.test_single // empty')"
    set_if_present BUILD_CMD "$(echo "$COMMANDS" | jq -r '.build // empty')"

    # Time estimates - check verification JSON first, then use heuristics
    VERIFICATION_JSON="$PROJECT_DIR/.agents/command-verification.json"
    get_verified_time() {
        local pattern="$1"
        local default="$2"
        if [ -f "$VERIFICATION_JSON" ]; then
            local duration_ms
            # Try to find command in verification JSON using regex pattern
            duration_ms=$(jq -r --arg pattern "$pattern" '.commands | to_entries[] | select(.key | test($pattern; "i")) | .value.duration_ms // empty' "$VERIFICATION_JSON" 2>/dev/null | head -1)
            if [ -n "$duration_ms" ] && [ "$duration_ms" != "null" ] && [ "$duration_ms" -gt 0 ] 2>/dev/null; then
                # Convert ms to human-readable
                if [ "$duration_ms" -lt 1000 ]; then
                    echo "~${duration_ms}ms"
                elif [ "$duration_ms" -lt 60000 ]; then
                    echo "~$((duration_ms / 1000))s"
                else
                    echo "~$((duration_ms / 60000))m"
                fi
                return
            fi
        fi
        echo "$default"
    }

    # Check if we have verification data
    if [ -f "$VERIFICATION_JSON" ]; then
        verified_at=$(jq -r '.verified_at // empty' "$VERIFICATION_JSON" 2>/dev/null | cut -dT -f1)
        if [ -n "$verified_at" ]; then
            vars[VERIFIED_TIMESTAMP]="$verified_at"
            vars[VERIFIED_STATUS]=" (verified ✓)"
        else
            vars[VERIFIED_TIMESTAMP]="never"
            vars[VERIFIED_STATUS]=" (unverified)"
        fi
    else
        vars[VERIFIED_TIMESTAMP]="never"
        vars[VERIFIED_STATUS]=" (unverified)"
    fi

    vars[TYPECHECK_TIME]=$(get_verified_time "typecheck" "~15s")
    vars[LINT_TIME]=$(get_verified_time "lint|cs-fixer|eslint" "~10s")
    vars[FORMAT_TIME]=$(get_verified_time "format|prettier|black|cs-fixer fix$" "~5s")
    vars[TEST_TIME]=$(get_verified_time "test|phpunit|jest|pytest" "~30s")
    vars[BUILD_TIME]=$(get_verified_time "build" "~30s")

    # File map
    vars[FILE_MAP]="$FILE_MAP"

    # Golden samples, utilities, and heuristics from detection scripts
    vars[GOLDEN_SAMPLES]="$GOLDEN_SAMPLES"
    vars[UTILITIES_LIST]="$UTILITIES_LIST"

    # Add workflow conventions from git analysis to heuristics
    workflow_info=$(build_workflow_info "$GIT_HISTORY")
    workflow_heuristics=""
    # Convert workflow info to heuristic table rows
    if echo "$workflow_info" | grep -q "Commits:"; then
        commit_convention=$(echo "$workflow_info" | grep "Commits:" | sed 's/- Commits: //')
        workflow_heuristics="${workflow_heuristics}| Committing | $commit_convention |
"
    fi
    if echo "$workflow_info" | grep -q "PRs:"; then
        pr_strategy=$(echo "$workflow_info" | grep "PRs:" | sed 's/- PRs: //')
        workflow_heuristics="${workflow_heuristics}| Merging PRs | $pr_strategy |
"
    fi
    if echo "$workflow_info" | grep -q "Branches:"; then
        branch_convention=$(echo "$workflow_info" | grep "Branches:" | sed 's/- Branches: //')
        workflow_heuristics="${workflow_heuristics}| Creating branches | Use $branch_convention |
"
    fi

    # Combine detected heuristics with workflow heuristics
    # Ensure no trailing blank lines
    combined_heuristics=""
    if [ -n "$HEURISTICS" ]; then
        # Trim blank lines and trailing whitespace
        combined_heuristics=$(printf '%s' "$HEURISTICS" | sed '/^[[:space:]]*$/d')
    fi
    if [ -n "$workflow_heuristics" ]; then
        # Add newline separator only if both have content
        if [ -n "$combined_heuristics" ]; then
            combined_heuristics="${combined_heuristics}
${workflow_heuristics}"
        else
            combined_heuristics="$workflow_heuristics"
        fi
    fi
    # Remove any trailing newlines
    combined_heuristics=$(printf '%s' "$combined_heuristics" | sed '/^[[:space:]]*$/d')
    vars[HEURISTICS]="$combined_heuristics"

    # Codebase state - detect migrations, deprecations
    codebase_state=""
    [ -d "migrations" ] || [ -d "db/migrate" ] && codebase_state="$codebase_state\n- Database migrations present in migrations/"
    [ -d "prisma/migrations" ] && codebase_state="$codebase_state\n- Prisma migrations present"
    grep -rq "DEPRECATED\|@deprecated" --include="*.ts" --include="*.go" --include="*.php" --include="*.py" . 2>/dev/null && \
        codebase_state="$codebase_state\n- Contains deprecated code (grep for @deprecated)"
    [ -z "$codebase_state" ] && codebase_state="- No known migrations or tech debt documented"
    vars[CODEBASE_STATE]=$(echo -e "$codebase_state")

    # Terminology - leave empty for now, needs manual curation
    vars[TERMINOLOGY]=""

    # Scope index
    vars[SCOPE_INDEX]=$(build_scope_index "$SCOPES_INFO")

    # Verbose template additional vars
    if [ "$STYLE" = "verbose" ]; then
        # Use extracted documentation data where available
        readme_desc=$(echo "$DOCS_INFO" | jq -r '.readme.description // empty')
        if [ -n "$readme_desc" ]; then
            vars[PROJECT_DESCRIPTION]="$readme_desc"
        else
            vars[PROJECT_DESCRIPTION]="TODO: Add project description"
        fi

        vars[LANGUAGE]="$LANGUAGE"
        vars[VERSION]="$VERSION"
        vars[BUILD_TOOL]=$(echo "$PROJECT_INFO" | jq -r '.build_tool')
        vars[FRAMEWORK]=$(echo "$PROJECT_INFO" | jq -r '.framework')
        vars[PROJECT_TYPE]="$PROJECT_TYPE"
        vars[BUILD_CMD]=$(echo "$COMMANDS" | jq -r '.build')

        # Extract quality standards from contributing guidelines AND quality config
        contributing_rules=$(echo "$DOCS_INFO" | jq -r '.contributing.code_style // empty')
        quality_standards=$(build_quality_standards "$QUALITY_CONFIG")
        if [ -n "$contributing_rules" ] && [ "$contributing_rules" != "null" ]; then
            # Combine contributing rules with detected quality config
            vars[QUALITY_STANDARDS]="$contributing_rules
$quality_standards"
        else
            vars[QUALITY_STANDARDS]="$quality_standards"
        fi

        # Extract security guidelines
        security_policy=$(echo "$DOCS_INFO" | jq -r '.security.policy // empty')
        if [ -n "$security_policy" ] && [ "$security_policy" != "null" ]; then
            vars[SECURITY_SPECIFIC]="$security_policy"
        else
            vars[SECURITY_SPECIFIC]="- Report vulnerabilities via security@project or SECURITY.md
- Never commit secrets or credentials"
        fi

        vars[TEST_COVERAGE]="40"

        # Try to get test commands from CI info or fall back to detected commands
        test_cmd=$(echo "$COMMANDS" | jq -r '.test')
        ci_system=$(echo "$CI_INFO" | jq -r '.ci_system // "none"')

        # Look for specific test commands in CI
        ci_test_cmd=""
        case "$ci_system" in
            "github-actions")
                ci_test_cmd=$(echo "$CI_INFO" | jq -r '.github_actions.run_commands[]? | select(. | test("test|phpunit|jest|pytest|go test"; "i"))' 2>/dev/null | head -1)
                ;;
            "gitlab-ci")
                ci_test_cmd=$(echo "$CI_INFO" | jq -r '.gitlab_ci.script_commands[]? | select(. | test("test|phpunit|jest|pytest|go test"; "i"))' 2>/dev/null | head -1)
                ;;
        esac

        vars[TEST_FAST_CMD]="${test_cmd:-make test}"
        if [ -n "$ci_test_cmd" ]; then
            vars[TEST_FULL_CMD]="$ci_test_cmd"
        else
            vars[TEST_FULL_CMD]="${test_cmd:-make test}"
        fi

        # Check if docs exist
        [ -d "./docs" ] && vars[ARCHITECTURE_DOC]="./docs/architecture.md" || vars[ARCHITECTURE_DOC]="(not available)"
        [ -d "./docs" ] && vars[API_DOC]="./docs/api.md" || vars[API_DOC]="(not available)"

        # Use extracted contributing file path or default
        contrib_file=$(echo "$DOCS_INFO" | jq -r '.contributing.file // empty')
        if [ -n "$contrib_file" ] && [ "$contrib_file" != "null" ]; then
            vars[CONTRIBUTING_DOC]="./$contrib_file"
        else
            vars[CONTRIBUTING_DOC]="./CONTRIBUTING.md"
        fi
    fi

    # Language-specific conflict resolution, never-do rules, and code examples
    case "$LANGUAGE" in
        "go")
            vars[LANGUAGE_SPECIFIC_CONFLICT_RESOLUTION]="- For Go-specific patterns, defer to language idioms and standard library conventions"
            vars[LANGUAGE_SPECIFIC_NEVER]="- Commit go.sum without go.mod changes"
            vars[CODE_EXAMPLES]="**Good:** \`if err != nil { return fmt.Errorf(\"op failed: %w\", err) }\`
**Avoid:** \`if err != nil { panic(err) }\` or ignoring errors"
            vars[GOOD_EXAMPLE]="\`\`\`go
// Wrap errors with context
if err != nil {
    return fmt.Errorf(\"failed to process %s: %w\", item, err)
}

// Use structured logging
slog.Info(\"operation completed\", \"item\", item, \"duration\", elapsed)
\`\`\`"
            vars[BAD_EXAMPLE]="\`\`\`go
// Don't panic on recoverable errors
if err != nil {
    panic(err)  // Use return instead
}

// Don't use fmt.Println for logging
fmt.Println(\"something happened\")  // Use slog/log package
\`\`\`"
            ;;
        "php")
            vars[LANGUAGE_SPECIFIC_CONFLICT_RESOLUTION]="- For PHP-specific patterns, follow PSR standards"
            vars[LANGUAGE_SPECIFIC_NEVER]="- Commit composer.lock without composer.json changes
- Modify core framework files"
            vars[CODE_EXAMPLES]="**Good:** Constructor injection, typed properties, return types
**Avoid:** Service locator, untyped parameters, \`@var\` without types"
            vars[GOOD_EXAMPLE]="\`\`\`php
// Use constructor injection with typed properties
public function __construct(
    private readonly UserRepository \$userRepository,
    private readonly LoggerInterface \$logger,
) {}

// Always use return types and parameter types
public function findById(int \$id): ?User
{
    return \$this->userRepository->find(\$id);
}
\`\`\`"
            vars[BAD_EXAMPLE]="\`\`\`php
// Don't use service locator or globals
\$user = Container::get('user.repository')->find(\$id);

// Don't omit types
public function process(\$data)  // Missing types
{
    return \$data;  // Missing return type
}
\`\`\`"
            ;;
        "typescript")
            vars[LANGUAGE_SPECIFIC_CONFLICT_RESOLUTION]="- For TypeScript/JavaScript patterns, follow project eslint/prettier config"
            vars[LANGUAGE_SPECIFIC_NEVER]="- Commit package-lock.json without package.json changes
- Use any type without justification"
            vars[CODE_EXAMPLES]="**Good:** Strict types, async/await, destructuring
**Avoid:** \`any\` type, callback hell, mutable state in components"
            vars[GOOD_EXAMPLE]="\`\`\`typescript
// Use explicit types and async/await
async function fetchUser(id: string): Promise<User | null> {
  const response = await api.get<User>(\\\`/users/\\\${id}\\\`);
  return response.data;
}

// Use destructuring and const
const { name, email } = user;
\`\`\`"
            vars[BAD_EXAMPLE]="\`\`\`typescript
// Don't use 'any' without justification
function process(data: any): any {  // Type properly
  return data;
}

// Don't use var or nested callbacks
var result;  // Use const/let
fetchData(function(data) {  // Use async/await
  processData(data, function(result) { ... });
});
\`\`\`"
            ;;
        "python")
            vars[LANGUAGE_SPECIFIC_CONFLICT_RESOLUTION]="- For Python-specific patterns, follow PEP 8 and project tooling (ruff/black)"
            vars[LANGUAGE_SPECIFIC_NEVER]="- Commit requirements.txt without pyproject.toml changes
- Use print() for logging in production code"
            vars[CODE_EXAMPLES]="**Good:** Type hints, dataclasses, context managers
**Avoid:** Bare \`except:\`, mutable default args, \`print()\` for logging"
            vars[GOOD_EXAMPLE]="\`\`\`python
# Use type hints and dataclasses
from dataclasses import dataclass

@dataclass
class User:
    name: str
    email: str

def find_user(user_id: int) -> User | None:
    \"\"\"Find user by ID.\"\"\"
    return db.query(User).filter_by(id=user_id).first()
\`\`\`"
            vars[BAD_EXAMPLE]="\`\`\`python
# Don't use bare except or mutable defaults
def process(items=[]):  # Mutable default arg!
    try:
        return do_something(items)
    except:  # Too broad, catches KeyboardInterrupt
        pass

# Don't use print() for logging
print(f\"Processing {item}\")  # Use logging module
\`\`\`"
            ;;
        *)
            vars[LANGUAGE_SPECIFIC_CONFLICT_RESOLUTION]=""
            vars[LANGUAGE_SPECIFIC_NEVER]=""
            vars[CODE_EXAMPLES]=""
            vars[GOOD_EXAMPLE]="TODO: Add language-specific good patterns"
            vars[BAD_EXAMPLE]="TODO: Add language-specific anti-patterns"
            ;;
    esac

    # Render template (smart mode respects --update flag)
    render_template_smart "$TEMPLATE" "$ROOT_FILE" vars "$UPDATE_ONLY"

    # Enforce byte budget for agent instruction limits
    enforce_byte_budget "$ROOT_FILE" "$BYTE_BUDGET"

    if [ "$UPDATE_ONLY" = true ]; then
        echo "✅ Updated: $ROOT_FILE"
    else
        echo "✅ Created: $ROOT_FILE"
    fi
fi

# Generate CLAUDE.md shim if requested
if [ "$CLAUDE_SHIM" = true ]; then
    CLAUDE_FILE="$PROJECT_DIR/CLAUDE.md"
    if [ -f "$CLAUDE_FILE" ] && [ "$FORCE" = false ]; then
        log "CLAUDE.md already exists, skipping (use --force to regenerate)"
    elif [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would create: $CLAUDE_FILE"
    else
        cat > "$CLAUDE_FILE" << 'CLAUDESHIM'
<!-- Auto-generated shim for Claude Code compatibility -->
<!-- Source of truth: AGENTS.md -->
<!-- Re-generate with: generate-agents.sh --claude-shim -->

@import AGENTS.md

<!-- Add Claude-specific overrides below if needed -->
CLAUDESHIM
        echo "✅ Created: $CLAUDE_FILE (shim importing AGENTS.md)"
    fi
fi

# Generate scoped AGENTS.md files
SCOPE_COUNT=$(echo "$SCOPES_INFO" | jq '.scopes | length')

if [ "$SCOPE_COUNT" -eq 0 ]; then
    log "No scopes detected (no directories with sufficient source files)"
else
    log "Generating $SCOPE_COUNT scoped AGENTS.md files..."

    while read -r scope; do
        SCOPE_PATH=$(echo "$scope" | jq -r '.path')
        SCOPE_TYPE=$(echo "$scope" | jq -r '.type')
        SCOPE_FILE="$PROJECT_DIR/$SCOPE_PATH/AGENTS.md"

        if [ -f "$SCOPE_FILE" ] && [ "$FORCE" = false ] && [ "$UPDATE_ONLY" = false ]; then
            log "Scoped AGENTS.md already exists: $SCOPE_PATH, skipping"
            continue
        fi

        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Would create/update: $SCOPE_FILE"
            continue
        fi

        # Select template based on scope type
        SCOPE_TEMPLATE="$TEMPLATE_DIR/scoped/$SCOPE_TYPE.md"

        if [ ! -f "$SCOPE_TEMPLATE" ]; then
            log "No template for scope type: $SCOPE_TYPE, skipping $SCOPE_PATH"
            continue
        fi

        # Try to extract commands from scope directory (for monorepos)
        SCOPE_COMMANDS=""
        if [ -f "$SCOPE_PATH/package.json" ] || [ -f "$SCOPE_PATH/composer.json" ] || [ -f "$SCOPE_PATH/pyproject.toml" ] || [ -f "$SCOPE_PATH/go.mod" ]; then
            SCOPE_COMMANDS=$("$SCRIPT_DIR/extract-commands.sh" "$SCOPE_PATH" 2>/dev/null || echo '')
            log "Found scope-local config in $SCOPE_PATH"
        fi
        # Fall back to root commands if scope has no local config
        [ -z "$SCOPE_COMMANDS" ] && SCOPE_COMMANDS="$COMMANDS"

        # Prepare scoped template variables
        declare -A scope_vars
        scope_vars[TIMESTAMP]=$(get_timestamp)
        scope_vars[SCOPE_NAME]=$(basename "$SCOPE_PATH")
        scope_vars[SCOPE_DESCRIPTION]=$(get_scope_description "$SCOPE_TYPE")
        scope_vars[FILE_PATH]="<file>"
        scope_vars[HOUSE_RULES]=""

        # Helper to only set var if value is non-empty (leaves placeholder for row deletion)
        set_scope_if_present() {
            local key="$1"
            local value="$2"
            if [ -n "$value" ] && [ "$value" != "null" ]; then
                scope_vars[$key]="$value"
            fi
            return 0
        }

        # Generate scope-specific file map
        generate_scope_file_map() {
            local scope_path="$1"
            local file_ext="$2"
            local result=""

            # Find key files (most recently modified, largest, or entry points)
            local files
            files=$(find "$scope_path" -maxdepth 2 -name "*.$file_ext" -type f 2>/dev/null | head -5)

            if [ -n "$files" ]; then
                result="| File | Purpose |\n|------|---------|"
                while IFS= read -r file; do
                    local basename=$(basename "$file")
                    local rel_path="${file#$PROJECT_DIR/}"
                    # Try to extract purpose from first docblock or comment
                    local purpose=$(head -20 "$file" 2>/dev/null | grep -E '^\s*(//|#|\*|/\*\*)' | head -1 | sed 's/^[[:space:]]*[/*#]*[[:space:]]*//' | cut -c1-50)
                    [ -z "$purpose" ] && purpose="(add description)"
                    result="$result\n| \`$rel_path\` | $purpose |"
                done <<< "$files"
            fi
            echo -e "$result"
        }

        # Generate scope-specific golden samples
        generate_scope_golden_samples() {
            local scope_path="$1"
            local file_ext="$2"
            local result=""

            # Look for well-documented files with tests
            local sample
            sample=$(find "$scope_path" -maxdepth 2 -name "*.$file_ext" -type f 2>/dev/null | \
                     xargs -I{} sh -c 'wc -l "{}" | grep -v "^0"' 2>/dev/null | \
                     sort -rn | head -1 | awk '{print $2}')

            if [ -n "$sample" ] && [ -f "$sample" ]; then
                local rel_path="${sample#$PROJECT_DIR/}"
                result="| Pattern | Reference |\n|---------|-----------|"
                result="$result\n| Standard implementation | \`$rel_path\` |"
            fi
            echo -e "$result"
        }

        # Language-specific variables
        case "$SCOPE_TYPE" in
            "backend-go")
                scope_vars[GO_VERSION]="$VERSION"
                scope_vars[GO_MINOR_VERSION]=$(echo "$VERSION" | cut -d. -f2)
                scope_vars[GO_TOOLS]="golangci-lint, gofmt"
                scope_vars[ENV_VARS]="See .env.example"
                set_scope_if_present BUILD_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.build // empty')"

                # Build whole-line placeholders for setup section
                scope_vars[INSTALL_LINE]="- Install: \`go mod download\`"
                [ -n "${scope_vars[GO_VERSION]:-}" ] && [ "${scope_vars[GO_VERSION]}" != "unknown" ] && \
                    scope_vars[GO_VERSION_LINE]="- Go version: ${scope_vars[GO_VERSION]}"
                [ -n "${scope_vars[GO_TOOLS]:-}" ] && \
                    scope_vars[GO_TOOLS_LINE]="- Required tools: ${scope_vars[GO_TOOLS]}"
                [ -n "${scope_vars[ENV_VARS]:-}" ] && \
                    scope_vars[ENV_VARS_LINE]="- Environment variables: ${scope_vars[ENV_VARS]}"

                # Build whole-line placeholders for commands section
                scope_vars[VET_LINE]="- Vet (static analysis): \`go vet ./...\`"
                scope_vars[FORMAT_LINE]="- Format: \`gofmt -w .\`"
                scope_vars[LINT_LINE]="- Lint: \`golangci-lint run ./...\`"
                scope_vars[TEST_LINE]="- Test: \`go test -v -race ./...\`"
                scope_vars[TEST_SINGLE_LINE]="- Test specific: \`go test -v -race -run TestName ./...\`"
                [ -n "${scope_vars[BUILD_CMD]:-}" ] && \
                    scope_vars[BUILD_LINE]="- Build: \`${scope_vars[BUILD_CMD]}\`"

                # Build checklist lines
                scope_vars[TEST_CHECKLIST_LINE]="- [ ] Tests pass: \`go test -v -race ./...\`"
                scope_vars[LINT_CHECKLIST_LINE]="- [ ] Lint clean: \`golangci-lint run ./...\`"
                scope_vars[FORMAT_CHECKLIST_LINE]="- [ ] Formatted: \`gofmt -w .\`"

                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "go")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "go")
                ;;

            "backend-php")
                scope_vars[PHP_VERSION]="$VERSION"
                FRAMEWORK=$(echo "$PROJECT_INFO" | jq -r '.framework')
                scope_vars[FRAMEWORK]="$FRAMEWORK"
                scope_vars[PHP_EXTENSIONS]="json, mbstring, xml"
                scope_vars[ENV_VARS]="See .env.example"
                scope_vars[PHPSTAN_LEVEL]="10"
                set_scope_if_present BUILD_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.build // empty')"

                if [ "$FRAMEWORK" = "typo3" ]; then
                    scope_vars[FRAMEWORK_CONVENTIONS]="- TYPO3-specific: Use dependency injection, follow TYPO3 CGL"
                    scope_vars[FRAMEWORK_DOCS_LINE]="- TYPO3 documentation: https://docs.typo3.org"
                else
                    scope_vars[FRAMEWORK_CONVENTIONS]=""
                    scope_vars[FRAMEWORK_DOCS_LINE]=""
                fi

                # Build whole-line placeholders for setup section
                scope_vars[INSTALL_LINE]="- Install: \`composer install\`"
                [ -n "${scope_vars[PHP_VERSION]:-}" ] && [ "${scope_vars[PHP_VERSION]}" != "unknown" ] && \
                    scope_vars[PHP_VERSION_LINE]="- PHP version: ${scope_vars[PHP_VERSION]}"
                [ -n "${scope_vars[FRAMEWORK]:-}" ] && [ "${scope_vars[FRAMEWORK]}" != "none" ] && \
                    scope_vars[FRAMEWORK_LINE]="- Framework: ${scope_vars[FRAMEWORK]}"
                [ -n "${scope_vars[PHP_EXTENSIONS]:-}" ] && \
                    scope_vars[PHP_EXTENSIONS_LINE]="- Required extensions: ${scope_vars[PHP_EXTENSIONS]}"
                [ -n "${scope_vars[ENV_VARS]:-}" ] && \
                    scope_vars[ENV_VARS_LINE]="- Environment variables: ${scope_vars[ENV_VARS]}"

                # Build whole-line placeholders for commands section
                scope_vars[TYPECHECK_LINE]="- Typecheck: \`vendor/bin/phpstan analyze --level=${scope_vars[PHPSTAN_LEVEL]}\`"
                scope_vars[FORMAT_LINE]="- Format: \`vendor/bin/php-cs-fixer fix\`"
                scope_vars[LINT_LINE]="- Lint: \`php -l\`"
                scope_vars[TEST_LINE]="- Test: \`vendor/bin/phpunit\`"
                [ -n "${scope_vars[BUILD_CMD]:-}" ] && \
                    scope_vars[BUILD_LINE]="- Build: \`${scope_vars[BUILD_CMD]}\`"

                # Build checklist lines
                scope_vars[TEST_CHECKLIST_LINE]="- [ ] Tests pass: \`vendor/bin/phpunit\`"
                scope_vars[TYPECHECK_CHECKLIST_LINE]="- [ ] PHPStan Level ${scope_vars[PHPSTAN_LEVEL]} clean: \`vendor/bin/phpstan analyze\`"
                scope_vars[FORMAT_CHECKLIST_LINE]="- [ ] PSR-12 compliant: \`vendor/bin/php-cs-fixer fix --dry-run\`"

                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "php")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "php")
                ;;

            "typo3")
                scope_vars[PHP_VERSION]="$VERSION"
                TYPO3_VERSION=$(jq -r '.require."typo3/cms-core" // .["require-dev"]."typo3/cms-core" // "^12.4 || ^13.4"' composer.json 2>/dev/null || echo "^12.4 || ^13.4")
                scope_vars[TYPO3_VERSION]="$TYPO3_VERSION"
                scope_vars[PHPSTAN_LEVEL]="10"

                # Extract extension key and vendor from composer.json
                EXT_KEY=$(jq -r '.extra."typo3/cms"."extension-key" // empty' composer.json 2>/dev/null || echo "")
                if [ -z "$EXT_KEY" ]; then
                    EXT_KEY=$(basename "$PROJECT_DIR" | tr '-' '_')
                fi
                scope_vars[EXT_KEY]="$EXT_KEY"

                VENDOR=$(jq -r '.name // empty' composer.json 2>/dev/null | cut -d'/' -f1 || echo "Vendor")
                scope_vars[VENDOR]="$VENDOR"
                scope_vars[REQUIRED_EXTENSIONS]="See ext_emconf.php"
                scope_vars[HOUSE_RULES]=""

                # Build whole-line placeholders for setup section
                scope_vars[INSTALL_LINE]="- Install: \`composer install\` or via Extension Manager"
                [ -n "${scope_vars[PHP_VERSION]:-}" ] && [ "${scope_vars[PHP_VERSION]}" != "unknown" ] && \
                    scope_vars[PHP_VERSION_LINE]="- PHP version: ${scope_vars[PHP_VERSION]}"
                [ -n "${scope_vars[TYPO3_VERSION]:-}" ] && \
                    scope_vars[TYPO3_VERSION_LINE]="- TYPO3 version: ${scope_vars[TYPO3_VERSION]}"
                scope_vars[DEV_SETUP_LINE]="- Local dev: \`ddev start && ddev composer install\`"
                [ -n "${scope_vars[REQUIRED_EXTENSIONS]:-}" ] && \
                    scope_vars[REQUIRED_EXTENSIONS_LINE]="- Required extensions: ${scope_vars[REQUIRED_EXTENSIONS]}"

                # Build commands table
                scope_vars[COMMANDS_TABLE]="| Task | Command |
|------|---------|
| Lint | \`composer ci:php:lint\` |
| CS Fix | \`composer ci:php:cs-fixer\` |
| PHPStan | \`composer ci:php:stan\` |
| Unit tests | \`composer ci:tests:unit\` |
| Functional | \`composer ci:tests:functional\` |
| All CI | \`composer ci\` |"

                scope_vars[DDEV_ALTERNATIVE]="Alternative with ddev:
- \`ddev composer ci:tests:unit\`
- \`ddev exec vendor/bin/phpunit -c Tests/Build/UnitTests.xml\`"

                # Build checklist lines
                scope_vars[CI_CHECKLIST_LINE]="- [ ] \`composer ci\` passes (lint, cs-fixer, phpstan, tests)"
                scope_vars[PHPSTAN_CHECKLIST_LINE]="- [ ] PHPStan level ${scope_vars[PHPSTAN_LEVEL]} clean"
                scope_vars[TYPO3_VERSION_CHECKLIST_LINE]="- [ ] Tested on target TYPO3 versions (${scope_vars[TYPO3_VERSION]})"

                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "php")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "php")
                ;;

            "oro")
                scope_vars[PHP_VERSION]="$VERSION"
                ORO_VERSION=$(jq -r '.require."oro/platform" // .require."oro/commerce" // .require."oro/crm" // "^6.0"' composer.json 2>/dev/null || echo "^6.0")
                scope_vars[ORO_VERSION]="$ORO_VERSION"
                scope_vars[PHPSTAN_LEVEL]="8"
                scope_vars[HOUSE_RULES]=""

                # Build whole-line placeholders for setup section
                scope_vars[INSTALL_LINE]="- Install: \`composer install\`"
                [ -n "${scope_vars[PHP_VERSION]:-}" ] && [ "${scope_vars[PHP_VERSION]}" != "unknown" ] && \
                    scope_vars[PHP_VERSION_LINE]="- PHP version: ${scope_vars[PHP_VERSION]}"
                [ -n "${scope_vars[ORO_VERSION]:-}" ] && \
                    scope_vars[ORO_VERSION_LINE]="- Oro version: ${scope_vars[ORO_VERSION]}"
                scope_vars[DATABASE_LINE]="- Database: PostgreSQL (recommended) or MySQL"
                scope_vars[SETUP_COMMANDS]="- Required: \`bin/console oro:install\` for fresh setup
- Cache clear: \`bin/console cache:clear\`
- Assets: \`bin/console oro:assets:install\`"

                # Build commands table
                scope_vars[COMMANDS_TABLE]="| Task | Command |
|------|---------|
| Lint | \`bin/console lint:yaml src/\` |
| CS Fix | \`vendor/bin/php-cs-fixer fix\` |
| PHPStan | \`vendor/bin/phpstan analyse\` |
| Unit tests | \`vendor/bin/phpunit --testsuite=unit\` |
| Functional | \`vendor/bin/phpunit --testsuite=functional\` |
| Behat | \`vendor/bin/behat\` |
| Full CI | \`bin/console oro:test:all\` |"

                # Build checklist lines
                scope_vars[CACHE_CHECKLIST_LINE]="- [ ] \`bin/console cache:clear\` runs without errors"
                scope_vars[PHPSTAN_CHECKLIST_LINE]="- [ ] PHPStan passes at configured level"
                scope_vars[UNIT_TEST_CHECKLIST_LINE]="- [ ] Unit tests pass: \`vendor/bin/phpunit --testsuite=unit\`"

                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "php")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "php")
                ;;

            "backend-python")
                scope_vars[PYTHON_VERSION]="$VERSION"
                scope_vars[PACKAGE_MANAGER]=$(echo "$PROJECT_INFO" | jq -r '.package_manager')
                scope_vars[ENV_VARS]="See .env or .env.example"
                # Populate all command variables from scope-local extraction
                set_scope_if_present INSTALL_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.install // empty')"
                set_scope_if_present TYPECHECK_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.typecheck // empty')"
                set_scope_if_present LINT_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.lint // empty')"
                set_scope_if_present FORMAT_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.format // empty')"
                set_scope_if_present TEST_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.test // empty')"
                set_scope_if_present TEST_SINGLE_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.test_single // empty')"
                set_scope_if_present BUILD_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.build // empty')"
                set_scope_if_present DEV_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.dev // empty')"

                # Build whole-line placeholders for setup section
                [ -n "${scope_vars[INSTALL_CMD]:-}" ] && \
                    scope_vars[INSTALL_LINE]="- Install: \`${scope_vars[INSTALL_CMD]}\`"
                [ -n "${scope_vars[PYTHON_VERSION]:-}" ] && [ "${scope_vars[PYTHON_VERSION]}" != "unknown" ] && \
                    scope_vars[PYTHON_VERSION_LINE]="- Python version: ${scope_vars[PYTHON_VERSION]}"
                [ -n "${scope_vars[PACKAGE_MANAGER]:-}" ] && [ "${scope_vars[PACKAGE_MANAGER]}" != "unknown" ] && \
                    scope_vars[PACKAGE_MANAGER_LINE]="- Package manager: ${scope_vars[PACKAGE_MANAGER]}"
                [ -n "${scope_vars[ENV_VARS]:-}" ] && \
                    scope_vars[ENV_VARS_LINE]="- Environment variables: ${scope_vars[ENV_VARS]}"

                # Build whole-line placeholders for commands section
                [ -n "${scope_vars[TYPECHECK_CMD]:-}" ] && \
                    scope_vars[TYPECHECK_LINE]="- Typecheck: \`${scope_vars[TYPECHECK_CMD]}\`"
                [ -n "${scope_vars[FORMAT_CMD]:-}" ] && \
                    scope_vars[FORMAT_LINE]="- Format: \`${scope_vars[FORMAT_CMD]}\`"
                [ -n "${scope_vars[LINT_CMD]:-}" ] && \
                    scope_vars[LINT_LINE]="- Lint: \`${scope_vars[LINT_CMD]}\`"
                [ -n "${scope_vars[TEST_CMD]:-}" ] && \
                    scope_vars[TEST_LINE]="- Test: \`${scope_vars[TEST_CMD]}\`"
                [ -n "${scope_vars[BUILD_CMD]:-}" ] && \
                    scope_vars[BUILD_LINE]="- Build: \`${scope_vars[BUILD_CMD]}\`"

                # Build checklist lines
                [ -n "${scope_vars[TEST_CMD]:-}" ] && \
                    scope_vars[TEST_CHECKLIST_LINE]="- [ ] Tests pass: \`${scope_vars[TEST_CMD]}\`"
                [ -n "${scope_vars[TYPECHECK_CMD]:-}" ] && \
                    scope_vars[TYPECHECK_CHECKLIST_LINE]="- [ ] Type check clean: \`${scope_vars[TYPECHECK_CMD]}\`"
                [ -n "${scope_vars[LINT_CMD]:-}" ] && \
                    scope_vars[LINT_CHECKLIST_LINE]="- [ ] Lint clean: \`${scope_vars[LINT_CMD]}\`"
                [ -n "${scope_vars[FORMAT_CMD]:-}" ] && \
                    scope_vars[FORMAT_CHECKLIST_LINE]="- [ ] Formatted: \`${scope_vars[FORMAT_CMD]}\`"

                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "py")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "py")
                ;;

            "backend-typescript")
                scope_vars[NODE_VERSION]="$VERSION"
                # For cross-language scopes, detect package manager locally
                scope_vars[PACKAGE_MANAGER]=$(detect_node_package_manager "$SCOPE_PATH")
                scope_vars[ENV_VARS]="See .env or .env.example"
                # Populate all command variables from scope-local extraction
                set_scope_if_present INSTALL_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.install // empty')"
                set_scope_if_present TYPECHECK_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.typecheck // empty')"
                set_scope_if_present LINT_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.lint // empty')"
                set_scope_if_present FORMAT_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.format // empty')"
                set_scope_if_present TEST_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.test // empty')"
                set_scope_if_present TEST_SINGLE_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.test_single // empty')"
                set_scope_if_present BUILD_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.build // empty')"
                set_scope_if_present DEV_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.dev // empty')"

                # Build whole-line placeholders for setup section
                [ -n "${scope_vars[INSTALL_CMD]:-}" ] && \
                    scope_vars[INSTALL_LINE]="- Install: \`${scope_vars[INSTALL_CMD]}\`"
                [ -n "${scope_vars[NODE_VERSION]:-}" ] && [ "${scope_vars[NODE_VERSION]}" != "unknown" ] && \
                    scope_vars[NODE_VERSION_LINE]="- Node version: ${scope_vars[NODE_VERSION]}"
                [ -n "${scope_vars[PACKAGE_MANAGER]:-}" ] && [ "${scope_vars[PACKAGE_MANAGER]}" != "unknown" ] && \
                    scope_vars[PACKAGE_MANAGER_LINE]="- Package manager: ${scope_vars[PACKAGE_MANAGER]}"
                [ -n "${scope_vars[ENV_VARS]:-}" ] && \
                    scope_vars[ENV_VARS_LINE]="- Environment variables: ${scope_vars[ENV_VARS]}"

                # Build whole-line placeholders for commands section
                [ -n "${scope_vars[TYPECHECK_CMD]:-}" ] && \
                    scope_vars[TYPECHECK_LINE]="- Typecheck (project-wide): \`${scope_vars[TYPECHECK_CMD]}\`"
                [ -n "${scope_vars[FORMAT_CMD]:-}" ] && \
                    scope_vars[FORMAT_LINE]="- Format: \`${scope_vars[FORMAT_CMD]}\`"
                [ -n "${scope_vars[LINT_CMD]:-}" ] && \
                    scope_vars[LINT_LINE]="- Lint: \`${scope_vars[LINT_CMD]}\`"
                [ -n "${scope_vars[TEST_CMD]:-}" ] && \
                    scope_vars[TEST_LINE]="- Test: \`${scope_vars[TEST_CMD]}\`"
                [ -n "${scope_vars[BUILD_CMD]:-}" ] && \
                    scope_vars[BUILD_LINE]="- Build: \`${scope_vars[BUILD_CMD]}\`"
                [ -n "${scope_vars[DEV_CMD]:-}" ] && \
                    scope_vars[DEV_LINE]="- Dev server: \`${scope_vars[DEV_CMD]}\`"

                # Build checklist lines
                [ -n "${scope_vars[TEST_CMD]:-}" ] && \
                    scope_vars[TEST_CHECKLIST_LINE]="- [ ] Tests pass: \`${scope_vars[TEST_CMD]}\`"
                [ -n "${scope_vars[TYPECHECK_CMD]:-}" ] && \
                    scope_vars[TYPECHECK_CHECKLIST_LINE]="- [ ] Type check clean: \`${scope_vars[TYPECHECK_CMD]}\`"
                [ -n "${scope_vars[LINT_CMD]:-}" ] && \
                    scope_vars[LINT_CHECKLIST_LINE]="- [ ] Lint clean: \`${scope_vars[LINT_CMD]}\`"
                [ -n "${scope_vars[FORMAT_CMD]:-}" ] && \
                    scope_vars[FORMAT_CHECKLIST_LINE]="- [ ] Formatted: \`${scope_vars[FORMAT_CMD]}\`"

                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "ts")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "ts")
                ;;

            "frontend-typescript")
                scope_vars[NODE_VERSION]="$VERSION"
                FRAMEWORK=$(echo "$PROJECT_INFO" | jq -r '.framework')
                scope_vars[FRAMEWORK]="$FRAMEWORK"
                # For cross-language scopes, detect package manager locally
                scope_vars[PACKAGE_MANAGER]=$(detect_node_package_manager "$SCOPE_PATH")
                scope_vars[ENV_VARS]="See .env.example"
                # Populate all command variables from scope-local extraction
                set_scope_if_present INSTALL_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.install // empty')"
                set_scope_if_present TYPECHECK_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.typecheck // empty')"
                set_scope_if_present LINT_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.lint // empty')"
                set_scope_if_present FORMAT_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.format // empty')"
                set_scope_if_present TEST_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.test // empty')"
                set_scope_if_present BUILD_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.build // empty')"
                set_scope_if_present DEV_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.dev // empty')"
                scope_vars[CSS_APPROACH]="CSS Modules"

                case "$FRAMEWORK" in
                    "react")
                        scope_vars[FRAMEWORK_CONVENTIONS]="- Use functional components with hooks
- Avoid class components"
                        scope_vars[FRAMEWORK_DOCS]="https://react.dev"
                        scope_vars[FRAMEWORK_DOCS_LINE]="- Check React documentation: https://react.dev"
                        ;;
                    "next.js")
                        scope_vars[FRAMEWORK_CONVENTIONS]="- Use App Router (app/)
- Server Components by default"
                        scope_vars[FRAMEWORK_DOCS]="https://nextjs.org/docs"
                        scope_vars[FRAMEWORK_DOCS_LINE]="- Check Next.js documentation: https://nextjs.org/docs"
                        ;;
                    "vue")
                        scope_vars[FRAMEWORK_CONVENTIONS]="- Use Composition API
- Avoid Options API for new code"
                        scope_vars[FRAMEWORK_DOCS]="https://vuejs.org/guide"
                        scope_vars[FRAMEWORK_DOCS_LINE]="- Check Vue documentation: https://vuejs.org/guide"
                        ;;
                    *)
                        scope_vars[FRAMEWORK_CONVENTIONS]=""
                        scope_vars[FRAMEWORK_DOCS]=""
                        scope_vars[FRAMEWORK_DOCS_LINE]=""
                        ;;
                esac

                # Build whole-line placeholders (disappear cleanly when empty)
                [ -n "${scope_vars[NODE_VERSION]:-}" ] && [ "${scope_vars[NODE_VERSION]}" != "unknown" ] && \
                    scope_vars[NODE_VERSION_LINE]="- Node version: ${scope_vars[NODE_VERSION]}"
                [ -n "${scope_vars[FRAMEWORK]:-}" ] && [ "${scope_vars[FRAMEWORK]}" != "none" ] && \
                    scope_vars[FRAMEWORK_LINE]="- Framework: ${scope_vars[FRAMEWORK]}"
                [ -n "${scope_vars[PACKAGE_MANAGER]:-}" ] && [ "${scope_vars[PACKAGE_MANAGER]}" != "unknown" ] && \
                    scope_vars[PACKAGE_MANAGER_LINE]="- Package manager: ${scope_vars[PACKAGE_MANAGER]}"
                [ -n "${scope_vars[ENV_VARS]:-}" ] && \
                    scope_vars[ENV_VARS_LINE]="- Environment variables: ${scope_vars[ENV_VARS]}"

                # Build checklist lines (only when command exists)
                [ -n "${scope_vars[TEST_CMD]:-}" ] && \
                    scope_vars[TEST_CHECKLIST_LINE]="- [ ] Tests pass: \`${scope_vars[TEST_CMD]}\`"
                [ -n "${scope_vars[TYPECHECK_CMD]:-}" ] && \
                    scope_vars[TYPECHECK_CHECKLIST_LINE]="- [ ] TypeScript compiles: \`${scope_vars[TYPECHECK_CMD]}\`"
                [ -n "${scope_vars[LINT_CMD]:-}" ] && \
                    scope_vars[LINT_CHECKLIST_LINE]="- [ ] Lint clean: \`${scope_vars[LINT_CMD]}\`"
                [ -n "${scope_vars[FORMAT_CMD]:-}" ] && \
                    scope_vars[FORMAT_CHECKLIST_LINE]="- [ ] Formatted: \`${scope_vars[FORMAT_CMD]}\`"

                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "ts")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "ts")
                ;;

            "cli")
                scope_vars[LANGUAGE]="$LANGUAGE"
                CLI_FRAMEWORK="standard"
                [ -f "go.mod" ] && grep -q "github.com/spf13/cobra" go.mod 2>/dev/null && CLI_FRAMEWORK="cobra"
                [ -f "go.mod" ] && grep -q "github.com/urfave/cli" go.mod 2>/dev/null && CLI_FRAMEWORK="urfave/cli"
                scope_vars[CLI_FRAMEWORK]="$CLI_FRAMEWORK"
                scope_vars[BUILD_OUTPUT_PATH]="./bin/"
                build_cmd="$(echo "$SCOPE_COMMANDS" | jq -r '.build // empty')"
                [ -n "$build_cmd" ] && scope_vars[SETUP_INSTRUCTIONS]="- Build: \`$build_cmd\`"
                set_scope_if_present BUILD_CMD "$build_cmd"
                scope_vars[RUN_CMD]="./bin/$(basename "$PROJECT_DIR")"
                set_scope_if_present TEST_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.test // empty')"
                set_scope_if_present LINT_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.lint // empty')"

                # Build whole-line placeholders for setup section
                [ -n "${scope_vars[CLI_FRAMEWORK]:-}" ] && [ "${scope_vars[CLI_FRAMEWORK]}" != "standard" ] && \
                    scope_vars[CLI_FRAMEWORK_LINE]="- CLI framework: ${scope_vars[CLI_FRAMEWORK]}"
                [ -n "${scope_vars[BUILD_OUTPUT_PATH]:-}" ] && \
                    scope_vars[BUILD_OUTPUT_LINE]="- Build output: ${scope_vars[BUILD_OUTPUT_PATH]}"

                # Build whole-line placeholders for commands section
                [ -n "${scope_vars[BUILD_CMD]:-}" ] && \
                    scope_vars[BUILD_LINE]="- Build CLI: \`${scope_vars[BUILD_CMD]}\`"
                [ -n "${scope_vars[RUN_CMD]:-}" ] && \
                    scope_vars[RUN_LINE]="- Run CLI: \`${scope_vars[RUN_CMD]}\`"
                [ -n "${scope_vars[TEST_CMD]:-}" ] && \
                    scope_vars[TEST_LINE]="- Test: \`${scope_vars[TEST_CMD]}\`"
                [ -n "${scope_vars[LINT_CMD]:-}" ] && \
                    scope_vars[LINT_LINE]="- Lint: \`${scope_vars[LINT_CMD]}\`"

                # Build convention and help lines
                [ -n "${scope_vars[CLI_FRAMEWORK]:-}" ] && [ "${scope_vars[CLI_FRAMEWORK]}" != "standard" ] && \
                    scope_vars[CLI_FRAMEWORK_CONVENTION_LINE]="- Use flag parsing library consistently (${scope_vars[CLI_FRAMEWORK]})"
                [ -n "${scope_vars[CLI_FRAMEWORK]:-}" ] && [ "${scope_vars[CLI_FRAMEWORK]}" != "standard" ] && \
                    scope_vars[CLI_FRAMEWORK_DOCS_LINE]="- Review ${scope_vars[CLI_FRAMEWORK]} documentation"

                # Detect language for CLI scope
                cli_ext="go"
                [ -f "package.json" ] && cli_ext="ts"
                [ -f "setup.py" ] || [ -f "pyproject.toml" ] && cli_ext="py"
                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "$cli_ext")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "$cli_ext")
                ;;

            "testing")
                set_scope_if_present TEST_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.test // empty')"
                set_scope_if_present TEST_SINGLE_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.test_single // empty')"
                set_scope_if_present TEST_COVERAGE_CMD "$(echo "$SCOPE_COMMANDS" | jq -r '.test_coverage // empty')"

                # Build whole-line placeholders for commands section
                [ -n "${scope_vars[TEST_CMD]:-}" ] && \
                    scope_vars[TEST_LINE]="- Run all tests: \`${scope_vars[TEST_CMD]}\`"
                [ -n "${scope_vars[TEST_SINGLE_CMD]:-}" ] && \
                    scope_vars[TEST_SINGLE_LINE]="- Run specific test file: \`${scope_vars[TEST_SINGLE_CMD]}\`"
                [ -n "${scope_vars[TEST_COVERAGE_CMD]:-}" ] && \
                    scope_vars[TEST_COVERAGE_LINE]="- Run with coverage: \`${scope_vars[TEST_COVERAGE_CMD]}\`"

                # Detect test file extension
                test_ext="php"
                [ -f "go.mod" ] && test_ext="go"
                [ -f "package.json" ] && test_ext="ts"
                [ -f "pyproject.toml" ] && test_ext="py"
                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "$test_ext")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "$test_ext")
                ;;

            "documentation")
                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "md")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "md")
                ;;

            "examples")
                # Detect example file extension
                ex_ext="go"
                [ -f "package.json" ] && ex_ext="ts"
                [ -f "pyproject.toml" ] && ex_ext="py"
                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "$ex_ext")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "$ex_ext")
                ;;

            "resources")
                scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "*")
                scope_vars[SCOPE_GOLDEN_SAMPLES]=""
                ;;
        esac

        # Render template (smart mode respects --update flag)
        render_template_smart "$SCOPE_TEMPLATE" "$SCOPE_FILE" scope_vars "$UPDATE_ONLY"

        if [ "$UPDATE_ONLY" = true ]; then
            echo "✅ Updated: $SCOPE_FILE"
        else
            echo "✅ Created: $SCOPE_FILE"
        fi

    done < <(echo "$SCOPES_INFO" | jq -c '.scopes[]')
fi

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "[DRY-RUN] No files were modified. Remove --dry-run to apply changes."
fi

# Print extraction summary
if [ "$VERBOSE" = true ]; then
    print_summary "$PROJECT_INFO" "$SCOPES_INFO" "$COMMANDS" "$DOCS_INFO" "$PLATFORM_INFO" "$IDE_INFO" "$AGENT_INFO"
else
    echo ""
    print_compact_summary "$PROJECT_INFO" "$SCOPES_INFO"
fi

echo ""
echo "✅ AGENTS.md generation complete!"
[ "$SCOPE_COUNT" -gt 0 ] && echo "   Generated: 1 root + $SCOPE_COUNT scoped files" || true
