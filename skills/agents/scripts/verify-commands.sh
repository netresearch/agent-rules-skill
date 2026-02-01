#!/usr/bin/env bash
# Verify that commands documented in AGENTS.md actually work
# This prevents "command rot" - documented commands that no longer exist
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-.}"
AGENTS_FILE="$PROJECT_DIR/AGENTS.md"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "[INFO] $*" >&2
    fi
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Check if AGENTS.md exists
if [ ! -f "$AGENTS_FILE" ]; then
    error "AGENTS.md not found at $AGENTS_FILE"
    exit 1
fi

cd "$PROJECT_DIR"

echo "Verifying commands in $AGENTS_FILE..."
echo ""

FAILED=0
PASSED=0
SKIPPED=0

# Extract commands from markdown code blocks and table cells
# Look for patterns like: `command arg` or | `command` |
extract_commands() {
    # Extract from tables (| `command` | format)
    grep -oE '\| `[^`]+`' "$AGENTS_FILE" | sed 's/| `//;s/`$//' | grep -v '^\s*$' || true

    # Extract from inline code that looks like commands
    grep -oE '`(npm |yarn |pnpm |make |go |composer |cargo |pytest |php )[^`]+`' "$AGENTS_FILE" | sed 's/`//g' || true
}

# Verify a single command exists (not that it succeeds, just that it's callable)
verify_command() {
    local cmd="$1"
    local base_cmd

    # Extract the base command (first word)
    base_cmd=$(echo "$cmd" | awk '{print $1}')

    # Skip placeholders
    if [[ "$cmd" == *"<"* ]] || [[ "$cmd" == *"{{{"* ]]; then
        log "Skipping placeholder: $cmd"
        ((SKIPPED++))
        return 0
    fi

    # Skip if it's just a flag or option
    if [[ "$base_cmd" == -* ]]; then
        return 0
    fi

    log "Checking: $cmd"

    # Check different command types
    case "$base_cmd" in
        npm|yarn|pnpm)
            # Check if package.json script exists
            local script="${cmd#* }"
            script="${script#run }"
            script="${script%% *}"
            if [ -f "package.json" ]; then
                if jq -e ".scripts[\"$script\"]" package.json > /dev/null 2>&1; then
                    success "npm script exists: $script"
                    ((PASSED++))
                else
                    # Check if it's a direct npm command (install, test, etc.)
                    if [[ "$script" =~ ^(install|test|build|start|run)$ ]]; then
                        success "npm built-in: $script"
                        ((PASSED++))
                    else
                        warn "npm script not found: $script (in $cmd)"
                        ((SKIPPED++))
                    fi
                fi
            else
                warn "No package.json found for: $cmd"
                ((SKIPPED++))
            fi
            ;;

        make)
            # Check if Makefile target exists
            local target="${cmd#make }"
            target="${target%% *}"
            if [ -f "Makefile" ] || [ -f "makefile" ] || [ -f "GNUmakefile" ]; then
                if make -n "$target" > /dev/null 2>&1; then
                    success "make target exists: $target"
                    ((PASSED++))
                else
                    error "make target not found: $target"
                    ((FAILED++))
                fi
            else
                warn "No Makefile found for: $cmd"
                ((SKIPPED++))
            fi
            ;;

        composer)
            # Check if composer script exists
            local script="${cmd#composer }"
            script="${script%% *}"
            if [ -f "composer.json" ]; then
                if [[ "$script" =~ ^(install|update|require|remove|dump-autoload)$ ]]; then
                    success "composer built-in: $script"
                    ((PASSED++))
                elif jq -e ".scripts[\"$script\"]" composer.json > /dev/null 2>&1; then
                    success "composer script exists: $script"
                    ((PASSED++))
                else
                    warn "composer script not found: $script"
                    ((SKIPPED++))
                fi
            else
                warn "No composer.json found for: $cmd"
                ((SKIPPED++))
            fi
            ;;

        go)
            # Go commands are generally available if go is installed
            if command -v go > /dev/null 2>&1; then
                success "go command available"
                ((PASSED++))
            else
                error "go not installed"
                ((FAILED++))
            fi
            ;;

        *)
            # Check if command exists in PATH
            if command -v "$base_cmd" > /dev/null 2>&1; then
                success "command exists: $base_cmd"
                ((PASSED++))
            else
                warn "command not in PATH: $base_cmd"
                ((SKIPPED++))
            fi
            ;;
    esac
}

# Get unique commands
mapfile -t commands < <(extract_commands | sort -u)

if [ ${#commands[@]} -eq 0 ]; then
    warn "No commands found in AGENTS.md"
    exit 0
fi

echo "Found ${#commands[@]} unique commands to verify"
echo ""

for cmd in "${commands[@]}"; do
    [ -n "$cmd" ] && verify_command "$cmd"
done

echo ""
echo "======================================"
echo "Verification Summary"
echo "======================================"
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Some commands in AGENTS.md are invalid!${NC}"
    echo "Update AGENTS.md to fix broken command references."
    exit 1
else
    echo -e "${GREEN}All verifiable commands are valid.${NC}"

    # Update verified timestamp if not dry-run
    if [ "$DRY_RUN" = false ] && [ -w "$AGENTS_FILE" ]; then
        TODAY=$(date +%Y-%m-%d)
        if grep -q "Last verified:" "$AGENTS_FILE"; then
            sed -i "s/Last verified: .*/Last verified: $TODAY -->/" "$AGENTS_FILE"
            echo "Updated 'Last verified' timestamp to $TODAY"
        fi
    fi
fi
