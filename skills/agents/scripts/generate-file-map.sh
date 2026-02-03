#!/usr/bin/env bash
# Generate file map (dir → purpose) for AGENTS.md
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Check if git is available
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "# Not a git repository - cannot generate file map" >&2
    echo ""
    exit 0
fi

# Map of known directory names to their purposes
declare -A DIR_PURPOSES=(
    # Source directories
    ["src"]="application source code"
    ["lib"]="library code"
    ["app"]="application code (routes, pages)"
    ["pkg"]="public packages"
    ["internal"]="internal packages (not exported)"

    # Language-specific
    ["cmd"]="CLI entrypoints"
    ["Classes"]="PHP classes (PSR-4)"
    ["Configuration"]="framework configuration"

    # Frontend
    ["components"]="UI components"
    ["pages"]="page components/routes"
    ["views"]="view templates"
    ["layouts"]="layout components"
    ["hooks"]="React/Vue hooks"
    ["stores"]="state management"
    ["styles"]="CSS/styling"
    ["assets"]="static assets (images, fonts)"
    ["public"]="public static files"

    # Backend
    ["api"]="API routes/handlers"
    ["routes"]="route definitions"
    ["controllers"]="request handlers"
    ["services"]="business logic"
    ["models"]="data models"
    ["entities"]="database entities"
    ["repositories"]="data access layer"
    ["middleware"]="request middleware"

    # Infrastructure
    ["scripts"]="automation scripts"
    ["bin"]="compiled binaries"
    ["build"]="build output"
    ["dist"]="distribution files"
    ["vendor"]="third-party dependencies (do not edit)"
    ["node_modules"]="npm dependencies (do not edit)"

    # Testing
    ["tests"]="test suites"
    ["test"]="test suites"
    ["Tests"]="test suites"
    ["__tests__"]="Jest test suites"
    ["testutil"]="test utilities"
    ["fixtures"]="test fixtures"
    ["mocks"]="test mocks"

    # Documentation
    ["docs"]="documentation"
    ["Documentation"]="documentation (RST/MD)"
    ["doc"]="documentation"

    # Configuration
    ["config"]="configuration files"
    ["configs"]="configuration files"
    [".github"]="GitHub Actions, templates"
    [".gitlab"]="GitLab CI configuration"

    # Data
    ["migrations"]="database migrations"
    ["seeds"]="database seeds"
    ["data"]="data files"
    ["Resources"]="templates and assets"

    # Examples
    ["examples"]="usage examples"
    ["example"]="usage examples"
    ["samples"]="sample code"
)

# Get top-level directories with file counts
get_directories() {
    git ls-files | cut -d/ -f1 | sort | uniq -c | sort -rn | while read -r count dir; do
        # Skip files (no directory)
        [[ "$dir" == *.* ]] && continue
        # Skip hidden except .github/.gitlab
        [[ "$dir" == .* ]] && [[ "$dir" != ".github" ]] && [[ "$dir" != ".gitlab" ]] && continue
        echo "$count $dir"
    done
}

# Infer purpose from directory contents if not in known list
infer_purpose() {
    local dir="$1"

    # Check for specific file patterns
    if ls "$dir"/*.go 2>/dev/null | head -1 > /dev/null; then
        echo "Go packages"
    elif ls "$dir"/*.py 2>/dev/null | head -1 > /dev/null; then
        echo "Python modules"
    elif ls "$dir"/*.php 2>/dev/null | head -1 > /dev/null; then
        echo "PHP classes"
    elif ls "$dir"/*.ts 2>/dev/null | head -1 > /dev/null; then
        echo "TypeScript modules"
    elif ls "$dir"/*.tsx 2>/dev/null | head -1 > /dev/null; then
        echo "React components"
    elif ls "$dir"/*.vue 2>/dev/null | head -1 > /dev/null; then
        echo "Vue components"
    elif ls "$dir"/*.sh 2>/dev/null | head -1 > /dev/null; then
        echo "shell scripts"
    elif ls "$dir"/*.md 2>/dev/null | head -1 > /dev/null; then
        echo "documentation"
    elif ls "$dir"/*.json 2>/dev/null | head -1 > /dev/null; then
        echo "configuration/data"
    else
        echo "project files"
    fi
}

# Generate the file map
generate_map() {
    local max_dirs=15  # Limit to top 15 directories

    while read -r count dir; do
        [ -z "$dir" ] && continue
        [ "$max_dirs" -le 0 ] && break

        local purpose=""
        if [ -n "${DIR_PURPOSES[$dir]:-}" ]; then
            purpose="${DIR_PURPOSES[$dir]}"
        else
            purpose=$(infer_purpose "$dir")
        fi

        # Format: dir/ → purpose
        # Pad directory name for alignment
        printf "%-16s → %s\n" "${dir}/" "$purpose"

        ((max_dirs--))
    done < <(get_directories)
}

# Output the file map
generate_map
