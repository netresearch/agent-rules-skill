#!/usr/bin/env bash
# Detect directories that should have scoped AGENTS.md files
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

MIN_FILES=5  # Minimum files to warrant scoped AGENTS.md

# Get project info
PROJECT_INFO=$(bash "$(dirname "$0")/detect-project.sh" "$PROJECT_DIR")
LANGUAGE=$(echo "$PROJECT_INFO" | jq -r '.language')

scopes=()

# Function to count source files in a directory
count_source_files() {
    local dir="$1"
    local pattern="$2"
    find "$dir" -maxdepth 3 -type f -name "$pattern" 2>/dev/null | wc -l
}

# Function to add scope
add_scope() {
    local path="$1"
    local type="$2"
    local count="$3"

    scopes+=("{\"path\": \"$path\", \"type\": \"$type\", \"files\": $count}")
}

# Language-specific scope detection
case "$LANGUAGE" in
    "go")
        # Check common Go directories
        [ -d "internal" ] && {
            count=$(count_source_files "internal" "*.go")
            [ "$count" -ge "$MIN_FILES" ] && add_scope "internal" "backend-go" "$count"
        }

        [ -d "pkg" ] && {
            count=$(count_source_files "pkg" "*.go")
            [ "$count" -ge "$MIN_FILES" ] && add_scope "pkg" "backend-go" "$count"
        }

        [ -d "cmd" ] && {
            count=$(count_source_files "cmd" "*.go")
            [ "$count" -ge 3 ] && add_scope "cmd" "cli" "$count"
        }

        [ -d "examples" ] && {
            count=$(count_source_files "examples" "*.go")
            [ "$count" -ge 3 ] && add_scope "examples" "examples" "$count"
        }

        [ -d "testutil" ] && {
            count=$(count_source_files "testutil" "*.go")
            [ "$count" -ge 3 ] && add_scope "testutil" "testing" "$count"
        }

        [ -d "docs" ] && {
            count=$(find docs -type f \( -name "*.md" -o -name "*.rst" \) | wc -l)
            [ "$count" -ge 3 ] && add_scope "docs" "documentation" "$count"
        }
        ;;

    "php")
        # Determine PHP backend type based on framework
        FRAMEWORK=$(echo "$PROJECT_INFO" | jq -r '.framework')
        PROJECT_TYPE=$(echo "$PROJECT_INFO" | jq -r '.type')

        # Select appropriate backend template
        if [ "$FRAMEWORK" = "typo3" ] || [ "$PROJECT_TYPE" = "php-typo3-extension" ]; then
            PHP_BACKEND_TYPE="typo3"
        elif [ "$FRAMEWORK" = "oro" ] || [ "$PROJECT_TYPE" = "php-oro" ] || [ "$PROJECT_TYPE" = "php-oro-bundle" ]; then
            PHP_BACKEND_TYPE="oro"
        else
            PHP_BACKEND_TYPE="backend-php"
        fi

        # Check common PHP directories
        [ -d "Classes" ] && {
            count=$(count_source_files "Classes" "*.php")
            [ "$count" -ge "$MIN_FILES" ] && add_scope "Classes" "$PHP_BACKEND_TYPE" "$count"
        }

        [ -d "src" ] && {
            count=$(count_source_files "src" "*.php")
            [ "$count" -ge "$MIN_FILES" ] && add_scope "src" "$PHP_BACKEND_TYPE" "$count"
        }

        [ -d "Tests" ] && {
            count=$(count_source_files "Tests" "*.php")
            [ "$count" -ge 3 ] && add_scope "Tests" "testing" "$count"
        }

        [ -d "tests" ] && {
            count=$(count_source_files "tests" "*.php")
            [ "$count" -ge 3 ] && add_scope "tests" "testing" "$count"
        }

        [ -d "Documentation" ] && {
            count=$(find Documentation -type f \( -name "*.rst" -o -name "*.md" \) | wc -l)
            [ "$count" -ge 3 ] && add_scope "Documentation" "documentation" "$count"
        }

        [ -d "Resources" ] && {
            count=$(find Resources -type f | wc -l)
            [ "$count" -ge 5 ] && add_scope "Resources" "resources" "$count"
        }

        # Oro-specific: check for Bundle directories
        if [ "$FRAMEWORK" = "oro" ]; then
            for bundle_dir in src/*/Bundle/*/; do
                [ -d "$bundle_dir" ] && {
                    count=$(count_source_files "$bundle_dir" "*.php")
                    [ "$count" -ge "$MIN_FILES" ] && add_scope "${bundle_dir%/}" "oro" "$count"
                }
            done
        fi
        ;;

    "typescript")
        # Check common TypeScript/JavaScript directories
        [ -d "src" ] && {
            count=$(count_source_files "src" "*.ts")
            ts_count=$count
            count=$(count_source_files "src" "*.tsx")
            tsx_count=$count

            if [ "$tsx_count" -ge "$MIN_FILES" ]; then
                add_scope "src" "frontend-typescript" "$tsx_count"
            elif [ "$ts_count" -ge "$MIN_FILES" ]; then
                add_scope "src" "backend-typescript" "$ts_count"
            fi
        }

        [ -d "components" ] && {
            count=$(count_source_files "components" "*.tsx")
            [ "$count" -ge "$MIN_FILES" ] && add_scope "components" "frontend-typescript" "$count"
        }

        [ -d "pages" ] && {
            count=$(count_source_files "pages" "*.tsx")
            [ "$count" -ge 3 ] && add_scope "pages" "frontend-typescript" "$count"
        }

        [ -d "app" ] && {
            count=$(count_source_files "app" "*.tsx")
            [ "$count" -ge 3 ] && add_scope "app" "frontend-typescript" "$count"
        }

        if [ -d "server" ] || [ -d "backend" ]; then
            dir=$([ -d "server" ] && echo "server" || echo "backend")
            count=$(count_source_files "$dir" "*.ts")
            [ "$count" -ge "$MIN_FILES" ] && add_scope "$dir" "backend-typescript" "$count"
        fi

        if [ -d "__tests__" ] || [ -d "tests" ]; then
            dir=$([ -d "__tests__" ] && echo "__tests__" || echo "tests")
            count=$(count_source_files "$dir" "*.test.ts")
            [ "$count" -ge 3 ] && add_scope "$dir" "testing" "$count"
        fi
        ;;

    "python")
        # Check common Python directories
        [ -d "src" ] && {
            count=$(count_source_files "src" "*.py")
            [ "$count" -ge "$MIN_FILES" ] && add_scope "src" "backend-python" "$count"
        }

        [ -d "tests" ] && {
            count=$(count_source_files "tests" "*.py")
            [ "$count" -ge 3 ] && add_scope "tests" "testing" "$count"
        }

        [ -d "scripts" ] && {
            count=$(count_source_files "scripts" "*.py")
            [ "$count" -ge 3 ] && add_scope "scripts" "cli" "$count"
        }

        [ -d "docs" ] && {
            count=$(find docs -type f \( -name "*.md" -o -name "*.rst" \) | wc -l)
            [ "$count" -ge 3 ] && add_scope "docs" "documentation" "$count"
        }
        ;;
esac

# Check for web subdirectories (cross-language)
# IMPORTANT: Only create frontend-typescript scopes if Node toolchain exists
# Either: package.json in scope dir, package.json at root, or lockfile at root
has_node_toolchain() {
    local scope_dir="$1"
    [ -f "$scope_dir/package.json" ] || \
    [ -f "package.json" ] || \
    [ -f "pnpm-lock.yaml" ] || \
    [ -f "yarn.lock" ] || \
    [ -f "bun.lockb" ] || \
    [ -f "package-lock.json" ]
}

for web_dir in internal/web web frontend client ui; do
    if [ -d "$web_dir" ]; then
        count=$(find "$web_dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) 2>/dev/null | wc -l)
        if [ "$count" -ge "$MIN_FILES" ] && has_node_toolchain "$web_dir"; then
            add_scope "$web_dir" "frontend-typescript" "$count"
        fi
    fi
done

# Output JSON
if [ ${#scopes[@]} -eq 0 ]; then
    echo '{"scopes": []}'
else
    echo "{\"scopes\": [$(IFS=,; echo "${scopes[*]}")]}"
fi
