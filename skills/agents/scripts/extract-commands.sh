#!/usr/bin/env bash
# Extract build commands from various build tool files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Stack filter: node, php, go, python, or auto (default)
STACK_FILTER="${2:-auto}"

# Skip extraction functions based on stack
should_extract_node() {
    [[ "$STACK_FILTER" == "auto" || "$STACK_FILTER" == "node" ]]
}

should_extract_php() {
    [[ "$STACK_FILTER" == "auto" || "$STACK_FILTER" == "php" ]]
}

should_extract_go() {
    [[ "$STACK_FILTER" == "auto" || "$STACK_FILTER" == "go" ]]
}

should_extract_python() {
    [[ "$STACK_FILTER" == "auto" || "$STACK_FILTER" == "python" ]]
}

# Get project info (use . since we already cd'd to PROJECT_DIR)
PROJECT_INFO=$(bash "$SCRIPT_DIR/detect-project.sh" ".")
LANGUAGE=$(echo "$PROJECT_INFO" | jq -r '.language')
# shellcheck disable=SC2034  # BUILD_TOOL reserved for future build-tool-specific detection
BUILD_TOOL=$(echo "$PROJECT_INFO" | jq -r '.build_tool')

# Initialize command variables
INSTALL_CMD=""
TYPECHECK_CMD=""
LINT_CMD=""
FORMAT_CMD=""
TEST_CMD=""
TEST_SINGLE_CMD=""
BUILD_CMD=""
DEV_CMD=""

# Detect package manager for Node.js projects
PACKAGE_MANAGER="npm"
detect_package_manager() {
    if [ -f "pnpm-lock.yaml" ]; then
        PACKAGE_MANAGER="pnpm"
    elif [ -f "yarn.lock" ]; then
        PACKAGE_MANAGER="yarn"
    elif [ -f "bun.lockb" ]; then
        PACKAGE_MANAGER="bun"
    elif [ -f "package.json" ]; then
        # Check packageManager field
        local pm_field
        pm_field=$(jq -r '.packageManager // empty' package.json 2>/dev/null | cut -d@ -f1)
        if [ -n "$pm_field" ]; then
            PACKAGE_MANAGER="$pm_field"
        fi
    fi
}

# Get the run command for package manager
get_pm_run() {
    case "$PACKAGE_MANAGER" in
        pnpm) echo "pnpm" ;;
        yarn) echo "yarn" ;;
        bun) echo "bun run" ;;
        *) echo "npm run" ;;
    esac
}

# Get the npx-equivalent for package manager
get_pm_dlx() {
    case "$PACKAGE_MANAGER" in
        pnpm) echo "pnpm dlx" ;;
        yarn) echo "yarn dlx" ;;
        bun) echo "bunx" ;;
        *) echo "npx" ;;
    esac
}

# Extract from Makefile
extract_from_makefile() {
    [ ! -f "Makefile" ] && return 0

    # Extract targets with ## comments
    while IFS= read -r line; do
        if [[ $line =~ ^([a-zA-Z_-]+):.*\#\#(.*)$ ]]; then
            target="${BASH_REMATCH[1]}"
            # description captured but not yet used (for future enhanced output)
            # description="${BASH_REMATCH[2]}"

            case "$target" in
                lint|check) LINT_CMD="make $target" ;;
                format|fmt) FORMAT_CMD="make $target" ;;
                test|tests) TEST_CMD="make $target" ;;
                build) BUILD_CMD="make $target" ;;
                typecheck|types) TYPECHECK_CMD="make $target" ;;
                dev|serve) DEV_CMD="make $target" ;;
            esac
        fi
    done < Makefile
}

# Extract from package.json
extract_from_package_json() {
    [ ! -f "package.json" ] && return 0

    # Detect package manager first
    detect_package_manager

    local pm_run pm_dlx
    pm_run=$(get_pm_run)
    pm_dlx=$(get_pm_dlx)

    # Set install command based on package manager
    INSTALL_CMD="$PACKAGE_MANAGER install"

    local has_typecheck has_lint has_format has_test has_build has_dev
    has_typecheck=$(jq -r '.scripts.typecheck // .scripts["type-check"] // empty' package.json 2>/dev/null)
    has_lint=$(jq -r '.scripts.lint // empty' package.json 2>/dev/null)
    has_format=$(jq -r '.scripts.format // empty' package.json 2>/dev/null)
    has_test=$(jq -r '.scripts.test // empty' package.json 2>/dev/null)
    has_build=$(jq -r '.scripts.build // empty' package.json 2>/dev/null)
    has_dev=$(jq -r '.scripts.dev // .scripts.start // empty' package.json 2>/dev/null)

    if [ -n "$has_typecheck" ]; then
        TYPECHECK_CMD="$pm_run typecheck"
    else
        TYPECHECK_CMD="$pm_dlx tsc --noEmit"
    fi

    if [ -n "$has_lint" ]; then
        LINT_CMD="$pm_run lint"
    else
        LINT_CMD="$pm_dlx eslint ."
    fi

    if [ -n "$has_format" ]; then
        FORMAT_CMD="$pm_run format"
    else
        FORMAT_CMD="$pm_dlx prettier --write ."
    fi

    if [ -n "$has_test" ]; then
        TEST_CMD="$PACKAGE_MANAGER test"
        # Single file test command
        if grep -q 'vitest' package.json 2>/dev/null; then
            TEST_SINGLE_CMD="$pm_dlx vitest run"
        elif grep -q 'jest' package.json 2>/dev/null; then
            TEST_SINGLE_CMD="$pm_dlx jest"
        else
            TEST_SINGLE_CMD="$PACKAGE_MANAGER test --"
        fi
    fi

    if [ -n "$has_build" ]; then
        BUILD_CMD="$pm_run build"
    fi

    if [ -n "$has_dev" ]; then
        DEV_CMD="$pm_run dev"
    fi
}

# Extract from composer.json
extract_from_composer_json() {
    [ ! -f "composer.json" ] && return 0

    local has_lint has_format has_test has_phpstan
    has_lint=$(jq -r '.scripts.lint // .scripts["cs:check"] // empty' composer.json 2>/dev/null)
    has_format=$(jq -r '.scripts.format // .scripts["cs:fix"] // empty' composer.json 2>/dev/null)
    has_test=$(jq -r '.scripts.test // empty' composer.json 2>/dev/null)
    has_phpstan=$(jq -r '.scripts.phpstan // .scripts["stan"] // empty' composer.json 2>/dev/null)

    if [ -n "$has_lint" ]; then
        LINT_CMD="composer run lint"
    fi

    if [ -n "$has_format" ]; then
        FORMAT_CMD="composer run format"
    fi

    if [ -n "$has_test" ]; then
        TEST_CMD="composer run test"
    else
        TEST_CMD="vendor/bin/phpunit"
    fi

    if [ -n "$has_phpstan" ]; then
        TYPECHECK_CMD="composer run phpstan"
    elif [ -f "phpstan.neon" ] || [ -f "Build/phpstan.neon" ]; then
        TYPECHECK_CMD="vendor/bin/phpstan analyze"
    fi
}

# Extract from pyproject.toml
extract_from_pyproject() {
    [ ! -f "pyproject.toml" ] && return 0

    # Check for ruff
    if grep -q '\[tool.ruff\]' pyproject.toml; then
        LINT_CMD="ruff check ."
        FORMAT_CMD="ruff format ."
    fi

    # Check for black
    if grep -q 'black' pyproject.toml; then
        FORMAT_CMD="black ."
    fi

    # Check for mypy
    if grep -q 'mypy' pyproject.toml; then
        TYPECHECK_CMD="mypy ."
    fi

    # Check for pytest
    if grep -q 'pytest' pyproject.toml; then
        TEST_CMD="pytest"
    fi
}

# Language-specific defaults
set_language_defaults() {
    case "$LANGUAGE" in
        "go")
            : "${INSTALL_CMD:=go mod download}"
            : "${TYPECHECK_CMD:=go build -v ./...}"
            if [ -z "$LINT_CMD" ]; then
                if [ -f ".golangci.yml" ] || [ -f ".golangci.yaml" ]; then
                    LINT_CMD="golangci-lint run ./..."
                fi
            fi
            : "${FORMAT_CMD:=gofmt -w .}"
            : "${TEST_CMD:=go test -v -race -short ./...}"
            : "${TEST_SINGLE_CMD:=go test -v -race}"
            : "${BUILD_CMD:=go build -v ./...}"
            ;;

        "php")
            : "${INSTALL_CMD:=composer install}"
            if [ -z "$TYPECHECK_CMD" ]; then
                if [ -f "phpstan.neon" ] || [ -f "Build/phpstan.neon" ]; then
                    TYPECHECK_CMD="vendor/bin/phpstan analyze"
                fi
            fi
            : "${LINT_CMD:=vendor/bin/php-cs-fixer fix --dry-run}"
            : "${FORMAT_CMD:=vendor/bin/php-cs-fixer fix}"
            : "${TEST_CMD:=vendor/bin/phpunit}"
            : "${TEST_SINGLE_CMD:=vendor/bin/phpunit}"
            ;;

        "typescript")
            local pm_dlx
            pm_dlx=$(get_pm_dlx)
            : "${INSTALL_CMD:=$PACKAGE_MANAGER install}"
            : "${TYPECHECK_CMD:=$pm_dlx tsc --noEmit}"
            : "${LINT_CMD:=$pm_dlx eslint .}"
            : "${FORMAT_CMD:=$pm_dlx prettier --write .}"
            if [ -z "$TEST_CMD" ]; then
                if [ -f "jest.config.js" ] || [ -f "jest.config.ts" ]; then
                    TEST_CMD="$PACKAGE_MANAGER test"
                    TEST_SINGLE_CMD="$pm_dlx jest"
                elif grep -q 'vitest' package.json 2>/dev/null; then
                    TEST_CMD="$pm_dlx vitest run"
                    TEST_SINGLE_CMD="$pm_dlx vitest run"
                fi
            fi
            ;;

        "python")
            if [ -f "pyproject.toml" ]; then
                if grep -q '\[tool.poetry\]' pyproject.toml 2>/dev/null; then
                    INSTALL_CMD="poetry install"
                elif grep -q '\[tool.uv\]' pyproject.toml 2>/dev/null; then
                    INSTALL_CMD="uv sync"
                else
                    INSTALL_CMD="pip install -e ."
                fi
            else
                INSTALL_CMD="pip install -r requirements.txt"
            fi
            : "${LINT_CMD:=ruff check .}"
            : "${FORMAT_CMD:=ruff format .}"
            : "${TYPECHECK_CMD:=mypy .}"
            : "${TEST_CMD:=pytest}"
            : "${TEST_SINGLE_CMD:=pytest}"
            ;;
    esac
}

# Run extraction (stack-filtered)
extract_from_makefile  # Always extract Makefile (cross-stack)
should_extract_node && extract_from_package_json
should_extract_php && extract_from_composer_json
should_extract_python && extract_from_pyproject

# Only set language defaults if matching stack or auto
case "$STACK_FILTER" in
    "auto") set_language_defaults ;;
    "node") [[ "$LANGUAGE" == "typescript" || "$LANGUAGE" == "javascript" ]] && set_language_defaults ;;
    "php") [[ "$LANGUAGE" == "php" ]] && set_language_defaults ;;
    "go") [[ "$LANGUAGE" == "go" ]] && set_language_defaults ;;
    "python") [[ "$LANGUAGE" == "python" ]] && set_language_defaults ;;
    *)
        echo "ERROR: Invalid STACK_FILTER value: $STACK_FILTER" >&2
        echo "Valid options: auto, node, php, go, python" >&2
        exit 1
        ;;
esac

# Output JSON
jq -n \
    --arg install "$INSTALL_CMD" \
    --arg typecheck "$TYPECHECK_CMD" \
    --arg lint "$LINT_CMD" \
    --arg format "$FORMAT_CMD" \
    --arg test "$TEST_CMD" \
    --arg test_single "$TEST_SINGLE_CMD" \
    --arg build "$BUILD_CMD" \
    --arg dev "$DEV_CMD" \
    --arg package_manager "$PACKAGE_MANAGER" \
    '{
        install: $install,
        typecheck: $typecheck,
        lint: $lint,
        format: $format,
        test: $test,
        test_single: $test_single,
        build: $build,
        dev: $dev,
        package_manager: $package_manager
    }'
