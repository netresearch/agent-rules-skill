#!/usr/bin/env bash
# Find nearest config root for a given stack type

# Find nearest directory containing package.json (for Node scopes)
# Usage: find_node_config_root "/path/to/scope"
# Returns: directory path or empty string
find_node_config_root() {
    local start_dir="$1"
    local search_dir="$start_dir"

    while [[ "$search_dir" != "." && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/package.json" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir=$(dirname "$search_dir")
    done

    # Check project root as fallback
    if [[ -f "package.json" ]]; then
        echo "."
        return 0
    fi

    return 1
}

# Find nearest directory containing composer.json (for PHP scopes)
find_php_config_root() {
    local start_dir="$1"
    local search_dir="$start_dir"

    while [[ "$search_dir" != "." && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/composer.json" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir=$(dirname "$search_dir")
    done

    if [[ -f "composer.json" ]]; then
        echo "."
        return 0
    fi

    return 1
}

# Find nearest directory containing go.mod (for Go scopes)
find_go_config_root() {
    local start_dir="$1"
    local search_dir="$start_dir"

    while [[ "$search_dir" != "." && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/go.mod" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir=$(dirname "$search_dir")
    done

    if [[ -f "go.mod" ]]; then
        echo "."
        return 0
    fi

    return 1
}

# Find nearest directory containing pyproject.toml or setup.py (for Python scopes)
find_python_config_root() {
    local start_dir="$1"
    local search_dir="$start_dir"

    while [[ "$search_dir" != "." && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/pyproject.toml" || -f "$search_dir/setup.py" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir=$(dirname "$search_dir")
    done

    if [[ -f "pyproject.toml" || -f "setup.py" ]]; then
        echo "."
        return 0
    fi

    return 1
}

# Extract Node version from nearest config
# Priority: package.json engines.node > .nvmrc > .node-version > .tool-versions
get_node_version() {
    local config_root="$1"
    local version=""

    # Try package.json engines.node
    if [[ -f "$config_root/package.json" ]]; then
        version=$(jq -r '.engines.node // empty' "$config_root/package.json" 2>/dev/null)
        [[ -n "$version" ]] && echo "$version" && return 0
    fi

    # Try .nvmrc
    if [[ -f "$config_root/.nvmrc" ]]; then
        version=$(tr -d '[:space:]' < "$config_root/.nvmrc")
        [[ -n "$version" ]] && echo "$version" && return 0
    fi

    # Try .node-version
    if [[ -f "$config_root/.node-version" ]]; then
        version=$(tr -d '[:space:]' < "$config_root/.node-version")
        [[ -n "$version" ]] && echo "$version" && return 0
    fi

    # Try .tool-versions (asdf)
    if [[ -f "$config_root/.tool-versions" ]]; then
        version=$(grep '^nodejs ' "$config_root/.tool-versions" 2>/dev/null | awk '{print $2}')
        [[ -n "$version" ]] && echo "$version" && return 0
    fi

    return 1
}

# Extract JS framework from package.json dependencies
get_js_framework() {
    local config_root="$1"

    [[ ! -f "$config_root/package.json" ]] && return 1

    local deps
    deps=$(jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys[]' \
           "$config_root/package.json" 2>/dev/null)

    # Check in priority order (more specific first)
    echo "$deps" | grep -qw 'next' && echo "next.js" && return 0
    echo "$deps" | grep -qw 'nuxt' && echo "nuxt" && return 0
    echo "$deps" | grep -qw 'svelte' && echo "svelte" && return 0
    echo "$deps" | grep -qw 'vue' && echo "vue" && return 0
    echo "$deps" | grep -qw 'react' && echo "react" && return 0
    echo "$deps" | grep -qw 'express' && echo "express" && return 0

    return 1
}

# Check if TypeScript strict mode is enabled
get_ts_strict_mode() {
    local config_root="$1"

    [[ ! -f "$config_root/tsconfig.json" ]] && return 1

    local strict
    strict=$(jq -r '.compilerOptions.strict // false' "$config_root/tsconfig.json" 2>/dev/null)

    [[ "$strict" == "true" ]] && echo "true" && return 0
    return 1
}
