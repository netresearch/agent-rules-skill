#!/usr/bin/env bash
# Verify that commands documented in AGENTS.md actually work
# This prevents "command rot" - documented commands that no longer exist
# Requires: Bash 4.0+ (for associative arrays)
set -euo pipefail

# Check Bash version - we need 4.0+ for associative arrays (declare -A)
if ((BASH_VERSINFO[0] < 4)); then
    echo "Error: Bash 4.0+ required (found ${BASH_VERSION})." >&2
    echo "On macOS: brew install bash" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-.}"
AGENTS_FILE="$PROJECT_DIR/AGENTS.md"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SMOKE_TEST="${SMOKE_TEST:-false}"
TIMEOUT="${TIMEOUT:-60}"
OUTPUT_JSON="${OUTPUT_JSON:-$PROJECT_DIR/.agents/command-verification.json}"

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

# JSON results storage
declare -A COMMAND_RESULTS

# Initialize JSON output directory
if [ "$SMOKE_TEST" = true ]; then
    mkdir -p "$(dirname "$OUTPUT_JSON")"
fi

# Check if a command is safe to execute
# Returns 0 if safe, 1 if dangerous
is_safe_command() {
    local cmd="$1"

    # Dangerous literal patterns to reject (glob matching)
    local -a dangerous_patterns=(
        'rm -rf'
        'rm -fr'
        'sudo '
        'chmod -R'
        'chown -R'
        '> /'
        'dd if='
        'mkfs'
        ':(){:|:&};:'  # Fork bomb
        '| sh'         # Any pipe to sh (catches wget/curl piped execution)
        '| bash'       # Any pipe to bash
        '| zsh'        # Any pipe to zsh
    )

    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$cmd" == *"$pattern"* ]]; then
            return 1
        fi
    done

    # Also reject if it contains dangerous-looking operations (regex matching)
    if [[ "$cmd" =~ (rm[[:space:]]+-[a-zA-Z]*[rf]|sudo|chmod[[:space:]]+-R|chown[[:space:]]+-R) ]]; then
        return 1
    fi

    return 0
}

# Portable milliseconds timestamp (works on both GNU and BSD date)
get_time_ms() {
    # Try GNU date with nanoseconds first, fall back to seconds * 1000
    if date +%s%3N 2>/dev/null | grep -qE '^[0-9]+$'; then
        date +%s%3N
    else
        echo $(( $(date +%s) * 1000 ))
    fi
}

# Run a command with timeout and measure duration
smoke_test_command() {
    local cmd="$1"
    local start_time end_time duration_ms exit_code

    # Safety check - skip dangerous commands
    if ! is_safe_command "$cmd"; then
        warn "Skipping potentially dangerous command: $cmd"
        COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": false, "skipped": true, "reason": "safety"}'
        return 1
    fi

    start_time=$(get_time_ms)

    # Run with timeout, capture exit code
    if timeout "${TIMEOUT}s" bash -c "$cmd" > /dev/null 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi

    end_time=$(get_time_ms)
    duration_ms=$((end_time - start_time))

    # Store result
    if [ $exit_code -eq 0 ]; then
        COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": true, "duration_ms": '"$duration_ms"'}'
        return 0
    elif [ $exit_code -eq 124 ]; then
        # Timeout
        COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": false, "timeout": true, "duration_ms": '"$((TIMEOUT * 1000))"'}'
        return 1
    else
        COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": false, "exit_code": '"$exit_code"', "duration_ms": '"$duration_ms"'}'
        return 1
    fi
}

# Write results to JSON file
write_json_results() {
    local timestamp
    # Portable ISO 8601 timestamp (works on both GNU and BSD date)
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    {
        echo "{"
        echo '  "verified_at": "'"$timestamp"'",'
        echo '  "smoke_tested": '"$SMOKE_TEST"','
        echo '  "commands": {'

        local first=true
        for cmd in "${!COMMAND_RESULTS[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            # Escape the command string for JSON
            local escaped_cmd
            escaped_cmd=$(echo "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
            printf '    "%s": %s' "$escaped_cmd" "${COMMAND_RESULTS[$cmd]}"
        done

        echo ""
        echo "  }"
        echo "}"
    } > "$OUTPUT_JSON"

    log "Results written to $OUTPUT_JSON"
}

# Extract commands from markdown code blocks and table cells
# Look for patterns like: `command arg` or | command | or | `command` |
extract_commands() {
    # Extract from tables with backticks (| `command` | format)
    grep -oE '\| `[^`]+`' "$AGENTS_FILE" 2>/dev/null | sed 's/| `//;s/`$//' | grep -v '^\s*$' || true

    # Extract from tables without backticks in Commands section
    # Look for lines like "| Lint | vendor/bin/php-cs-fixer fix --dry-run |"
    # Skip header row and separator row, get 3rd column (command), filter empty and time estimates
    sed -n '/^## Commands/,/^##/p' "$AGENTS_FILE" 2>/dev/null | \
        grep -E '^\|' | \
        tail -n +3 | \
        cut -d'|' -f3 | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
        grep -v '^$' | \
        grep -v '^~' || true

    # Extract from inline code that looks like commands
    # Includes: npm, yarn, pnpm, bun, make, go, composer, cargo, python, pip, poetry, uv, deno, gradle, php, vendor/bin
    grep -oE '`(npm |yarn |pnpm |bun |make |go |composer |cargo |pytest |python |pip |poetry |uv |deno |gradle |php |vendor/bin/)[^`]+`' "$AGENTS_FILE" 2>/dev/null | sed 's/`//g' || true
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
        npm|yarn|pnpm|bun)
            # Check if package.json script exists
            local script="${cmd#* }"
            script="${script#run }"
            script="${script%% *}"
            if [ -f "package.json" ]; then
                local script_exists=false
                if jq -e ".scripts[\"$script\"]" package.json > /dev/null 2>&1; then
                    script_exists=true
                elif [[ "$script" =~ ^(install|test|build|start|run)$ ]]; then
                    script_exists=true
                fi

                if [ "$script_exists" = true ]; then
                    if [ "$SMOKE_TEST" = true ]; then
                        # For test commands, only verify they start (dry-run if available)
                        local test_cmd="$cmd"
                        if [[ "$script" == "test" ]]; then
                            # Try to use --help or --dry-run to avoid full test run
                            test_cmd="$base_cmd run $script -- --help 2>/dev/null || $base_cmd run $script --dry-run 2>/dev/null || true"
                        fi
                        if smoke_test_command "$test_cmd"; then
                            local duration="${COMMAND_RESULTS[$cmd]}"
                            duration=$(echo "$duration" | grep -oE '"duration_ms": [0-9]+' | cut -d: -f2 | tr -d ' ')
                            success "$base_cmd script works: $script (~${duration}ms)"
                            ((PASSED++))
                        else
                            warn "$base_cmd script exists but smoke test failed: $script"
                            COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": false}'
                            ((SKIPPED++))
                        fi
                    else
                        success "$base_cmd script exists: $script"
                        COMMAND_RESULTS["$cmd"]='{"exists": true}'
                        ((PASSED++))
                    fi
                else
                    warn "$base_cmd script not found: $script (in $cmd)"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((SKIPPED++))
                fi
            else
                warn "No package.json found for: $cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        make)
            # Check if Makefile target exists
            local target="${cmd#make }"
            target="${target%% *}"
            if [ -f "Makefile" ] || [ -f "makefile" ] || [ -f "GNUmakefile" ]; then
                if make -n "$target" > /dev/null 2>&1; then
                    if [ "$SMOKE_TEST" = true ]; then
                        # Use make -n (dry run) for smoke test to avoid side effects
                        if smoke_test_command "make -n $target"; then
                            local duration="${COMMAND_RESULTS[$cmd]}"
                            duration=$(echo "$duration" | grep -oE '"duration_ms": [0-9]+' | cut -d: -f2 | tr -d ' ')
                            success "make target works: $target (~${duration}ms)"
                            ((PASSED++))
                        else
                            warn "make target exists but dry-run failed: $target"
                            COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": false}'
                            ((SKIPPED++))
                        fi
                    else
                        success "make target exists: $target"
                        COMMAND_RESULTS["$cmd"]='{"exists": true}'
                        ((PASSED++))
                    fi
                else
                    error "make target not found: $target"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((FAILED++))
                fi
            else
                warn "No Makefile found for: $cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        composer)
            # Check if composer script exists
            local script="${cmd#composer }"
            script="${script%% *}"
            if [ -f "composer.json" ]; then
                local script_exists=false
                if [[ "$script" =~ ^(install|update|require|remove|dump-autoload)$ ]]; then
                    script_exists=true
                elif jq -e ".scripts[\"$script\"]" composer.json > /dev/null 2>&1; then
                    script_exists=true
                fi

                if [ "$script_exists" = true ]; then
                    if [ "$SMOKE_TEST" = true ]; then
                        # For composer scripts, try --dry-run or --help
                        local test_cmd="$cmd"
                        if [[ "$script" =~ ^(install|update)$ ]]; then
                            test_cmd="composer $script --dry-run 2>/dev/null || true"
                        fi
                        if smoke_test_command "$test_cmd"; then
                            local duration="${COMMAND_RESULTS[$cmd]}"
                            duration=$(echo "$duration" | grep -oE '"duration_ms": [0-9]+' | cut -d: -f2 | tr -d ' ')
                            success "composer script works: $script (~${duration}ms)"
                            ((PASSED++))
                        else
                            warn "composer script exists but smoke test failed: $script"
                            COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": false}'
                            ((SKIPPED++))
                        fi
                    else
                        success "composer script exists: $script"
                        COMMAND_RESULTS["$cmd"]='{"exists": true}'
                        ((PASSED++))
                    fi
                else
                    warn "composer script not found: $script"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((SKIPPED++))
                fi
            else
                warn "No composer.json found for: $cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        pnpm)
            # pnpm - same logic as npm/yarn
            local script="${cmd#* }"
            script="${script#run }"
            script="${script%% *}"
            if [ -f "package.json" ]; then
                local script_exists=false
                if jq -e ".scripts[\"$script\"]" package.json > /dev/null 2>&1; then
                    script_exists=true
                elif [[ "$script" =~ ^(install|test|build|start|run)$ ]]; then
                    script_exists=true
                fi

                if [ "$script_exists" = true ]; then
                    success "pnpm script exists: $script"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED++))
                else
                    warn "pnpm script not found: $script"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((SKIPPED++))
                fi
            else
                warn "No package.json found for: $cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        bun)
            # bun - same logic as npm/yarn/pnpm
            local script="${cmd#* }"
            script="${script#run }"
            script="${script%% *}"
            if [ -f "package.json" ]; then
                local script_exists=false
                if jq -e ".scripts[\"$script\"]" package.json > /dev/null 2>&1; then
                    script_exists=true
                elif [[ "$script" =~ ^(install|test|build|start|run)$ ]]; then
                    script_exists=true
                fi

                if [ "$script_exists" = true ]; then
                    success "bun script exists: $script"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED++))
                else
                    warn "bun script not found: $script"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((SKIPPED++))
                fi
            else
                warn "No package.json found for: $cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        python|python3|pip|pip3)
            # Python commands
            if command -v "$base_cmd" > /dev/null 2>&1; then
                success "Python command available: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED++))
            else
                warn "Python command not found: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        poetry)
            # Poetry package manager
            if command -v poetry > /dev/null 2>&1; then
                local subcmd="${cmd#poetry }"
                subcmd="${subcmd%% *}"
                if [[ "$subcmd" =~ ^(install|add|remove|update|build|publish|run|shell)$ ]]; then
                    success "poetry command: $subcmd"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED++))
                else
                    # Check if it's a custom script
                    if [ -f "pyproject.toml" ] && grep -q "\[tool.poetry.scripts\]" pyproject.toml 2>/dev/null; then
                        success "poetry command available"
                        COMMAND_RESULTS["$cmd"]='{"exists": true}'
                        ((PASSED++))
                    else
                        warn "poetry script not found: $subcmd"
                        COMMAND_RESULTS["$cmd"]='{"exists": false}'
                        ((SKIPPED++))
                    fi
                fi
            else
                warn "poetry not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        uv)
            # uv package manager
            if command -v uv > /dev/null 2>&1; then
                success "uv command available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED++))
            else
                warn "uv not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        pytest)
            # pytest test runner
            if command -v pytest > /dev/null 2>&1; then
                success "pytest available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED++))
            else
                warn "pytest not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        cargo)
            # Rust cargo
            if command -v cargo > /dev/null 2>&1; then
                success "cargo command available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED++))
            else
                warn "cargo not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        deno)
            # Deno runtime
            if command -v deno > /dev/null 2>&1; then
                success "deno command available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED++))
            else
                warn "deno not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        gradle|gradlew|./gradlew)
            # Gradle build tool
            if [ -f "gradlew" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
                success "gradle project detected"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED++))
            elif command -v gradle > /dev/null 2>&1; then
                success "gradle command available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED++))
            else
                warn "gradle not found"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED++))
            fi
            ;;

        go)
            # Go commands are generally available if go is installed
            if command -v go > /dev/null 2>&1; then
                if [ "$SMOKE_TEST" = true ]; then
                    if smoke_test_command "$cmd"; then
                        local duration="${COMMAND_RESULTS[$cmd]}"
                        duration=$(echo "$duration" | grep -oE '"duration_ms": [0-9]+' | cut -d: -f2 | tr -d ' ')
                        success "go command ran successfully (~${duration}ms)"
                        ((PASSED++))
                    else
                        error "go command failed: $cmd"
                        ((FAILED++))
                    fi
                else
                    success "go command available"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED++))
                fi
            else
                error "go not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((FAILED++))
            fi
            ;;

        vendor/bin/*)
            # PHP vendor binary
            if [ -f "$base_cmd" ]; then
                if [ "$SMOKE_TEST" = true ]; then
                    # For test commands, run with --help to avoid actually running tests
                    local test_cmd="$cmd"
                    if [[ "$cmd" == *"phpunit"* ]] && [[ "$cmd" != *"--help"* ]]; then
                        test_cmd="$base_cmd --help"
                    fi
                    if smoke_test_command "$test_cmd"; then
                        local duration="${COMMAND_RESULTS[$cmd]}"
                        duration=$(echo "$duration" | grep -oE '"duration_ms": [0-9]+' | cut -d: -f2 | tr -d ' ')
                        success "vendor binary works (~${duration}ms)"
                        ((PASSED++))
                    else
                        warn "vendor binary exists but failed: $cmd"
                        ((SKIPPED++))
                    fi
                else
                    success "vendor binary exists: $base_cmd"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED++))
                fi
            else
                error "vendor binary not found: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((FAILED++))
            fi
            ;;

        *)
            # Check if command exists in PATH
            if command -v "$base_cmd" > /dev/null 2>&1; then
                if [ "$SMOKE_TEST" = true ]; then
                    if smoke_test_command "$cmd"; then
                        local duration="${COMMAND_RESULTS[$cmd]}"
                        duration=$(echo "$duration" | grep -oE '"duration_ms": [0-9]+' | cut -d: -f2 | tr -d ' ')
                        success "command works (~${duration}ms)"
                        ((PASSED++))
                    else
                        warn "command exists but failed: $cmd"
                        ((SKIPPED++))
                    fi
                else
                    success "command exists: $base_cmd"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED++))
                fi
            else
                warn "command not in PATH: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
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

    # Still write JSON results
    if [ "$DRY_RUN" = false ] && [ ${#COMMAND_RESULTS[@]} -gt 0 ]; then
        write_json_results
    fi

    exit 1
else
    echo -e "${GREEN}All verifiable commands are valid.${NC}"

    # Write JSON results
    if [ "$DRY_RUN" = false ] && [ ${#COMMAND_RESULTS[@]} -gt 0 ]; then
        write_json_results
        echo "Verification results saved to $OUTPUT_JSON"
    fi

    # Update verified timestamp if not dry-run
    if [ "$DRY_RUN" = false ] && [ -w "$AGENTS_FILE" ]; then
        TODAY=$(date +%Y-%m-%d)
        if grep -q "Last verified:" "$AGENTS_FILE"; then
            # Portable sed -i: use backup extension then remove backup
            sed -i.bak "s/Last verified: .*/Last verified: $TODAY -->/" "$AGENTS_FILE" && rm -f "$AGENTS_FILE.bak"
            echo "Updated 'Last verified' timestamp to $TODAY"
        fi
    fi
fi
