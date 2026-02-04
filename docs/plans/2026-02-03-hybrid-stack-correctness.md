# Hybrid Stack Correctness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate cross-contamination between language stacks (PHP/Node/Go/Python) in hybrid repos by making scope metadata and commands stack-specific.

**Architecture:** Stack-aware extraction where each scope type (frontend-typescript, backend-php, etc.) gets its own config root detection, metadata extraction, and command set. No more root version/framework leaking into scopes.

**Tech Stack:** Bash 4.3+, jq, shell scripts

---

## Priority Order (from code review)

| Priority | Issue | Impact |
|----------|-------|--------|
| P0 | Scope metadata leaks root language/version/framework | Wrong Node version: ^8.2 (PHP version) |
| P0 | Command extraction mixes ecosystems | composer + pnpm commands in same scope |
| P0 | Scoped command extraction is too naive | Falls back to root when no local config |
| P1 | TSX files not supported in file maps | Empty "Key Files" for frontend scopes |
| P1 | Template assertions not verified | "TypeScript strict mode" when not true |
| P2 | Empty sections shown as blank tables | Noise, wasted tokens |
| P2 | No byte budget for scoped files | Large monorepo scopes |
| P2 | Command source misleading in hybrid repos | Says "package.json" but mixed sources |

---

## Task 1: Add Stack-Aware Command Extraction

**Files:**
- Modify: `skills/agents/scripts/extract-commands.sh`

**Step 1: Write test fixture for hybrid PHP+Node repo**

Create fixture: `skills/agents/references/examples/php-with-frontend/`

```bash
# Directory structure
mkdir -p skills/agents/references/examples/php-with-frontend/{src,web/src}

# PHP config at root
cat > skills/agents/references/examples/php-with-frontend/composer.json << 'EOF'
{
    "name": "test/php-with-frontend",
    "require": { "php": "^8.2" },
    "scripts": {
        "test": "vendor/bin/phpunit",
        "phpstan": "vendor/bin/phpstan analyze"
    }
}
EOF

# Node config at root (for frontend in web/)
cat > skills/agents/references/examples/php-with-frontend/package.json << 'EOF'
{
    "name": "frontend",
    "scripts": {
        "dev": "vite",
        "build": "vite build",
        "lint": "eslint src",
        "test": "vitest run"
    },
    "devDependencies": {
        "react": "^18.0.0",
        "vite": "^5.0.0",
        "vitest": "^1.0.0"
    }
}
EOF

# Create lockfile to indicate pnpm
touch skills/agents/references/examples/php-with-frontend/pnpm-lock.yaml

# PHP source
cat > skills/agents/references/examples/php-with-frontend/src/Controller.php << 'EOF'
<?php
namespace App;
class Controller {}
EOF

# React source (TSX)
cat > skills/agents/references/examples/php-with-frontend/web/src/App.tsx << 'EOF'
export default function App() {
    return <div>Hello</div>;
}
EOF
cat > skills/agents/references/examples/php-with-frontend/web/src/main.tsx << 'EOF'
import React from 'react';
import App from './App';
export { App };
EOF
```

**Step 2: Add --stack flag to extract-commands.sh**

At the top of extract-commands.sh after `set -euo pipefail`, add:

```bash
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
```

**Step 3: Gate extraction functions by stack filter**

Wrap existing extraction calls:

```bash
# Run extraction (stack-filtered)
extract_from_makefile  # Always extract Makefile (cross-stack)
should_extract_node && extract_from_package_json
should_extract_php && extract_from_composer_json
should_extract_python && extract_from_pyproject

# Only set language defaults if matching stack or auto
case "$STACK_FILTER" in
    "auto") set_language_defaults ;;
    "node") [ "$LANGUAGE" = "typescript" ] && set_language_defaults ;;
    "php") [ "$LANGUAGE" = "php" ] && set_language_defaults ;;
    "go") [ "$LANGUAGE" = "go" ] && set_language_defaults ;;
    "python") [ "$LANGUAGE" = "python" ] && set_language_defaults ;;
esac
```

**Step 4: Test stack-filtered extraction**

```bash
# Test PHP-only extraction
bash skills/agents/scripts/extract-commands.sh \
    skills/agents/references/examples/php-with-frontend php | jq .
# Expected: composer commands only, no pnpm

# Test Node-only extraction
bash skills/agents/scripts/extract-commands.sh \
    skills/agents/references/examples/php-with-frontend node | jq .
# Expected: pnpm commands only, no composer

# Test auto (current behavior for comparison)
bash skills/agents/scripts/extract-commands.sh \
    skills/agents/references/examples/php-with-frontend | jq .
# Expected: mixed (this is what we're fixing)
```

**Step 5: Commit**

```bash
git add skills/agents/scripts/extract-commands.sh \
        skills/agents/references/examples/php-with-frontend/
git commit -S -m "feat(extract-commands): add --stack filter for ecosystem isolation

Adds stack parameter (node|php|go|python|auto) to prevent command
cross-contamination in hybrid repos. Default 'auto' preserves backward
compatibility."
```

---

## Task 2: Add Nearest Config Root Detection

**Files:**
- Create: `skills/agents/scripts/lib/config-root.sh`

**Step 1: Create config root detection library**

```bash
cat > skills/agents/scripts/lib/config-root.sh << 'LIBEOF'
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
        version=$(cat "$config_root/.nvmrc" | tr -d '[:space:]')
        [[ -n "$version" ]] && echo "$version" && return 0
    fi

    # Try .node-version
    if [[ -f "$config_root/.node-version" ]]; then
        version=$(cat "$config_root/.node-version" | tr -d '[:space:]')
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
LIBEOF
chmod +x skills/agents/scripts/lib/config-root.sh
```

**Step 2: Test the library functions**

```bash
# Source and test
source skills/agents/scripts/lib/config-root.sh

# Test Node config root from web/src
cd skills/agents/references/examples/php-with-frontend
find_node_config_root "web/src"
# Expected: . (root has package.json)

# Test framework detection
get_js_framework "."
# Expected: react
```

**Step 3: Commit**

```bash
git add skills/agents/scripts/lib/config-root.sh
git commit -S -m "feat(lib): add config-root.sh for nearest config detection

Provides find_*_config_root() functions that walk up from scope directory
to find the correct config file (package.json, composer.json, etc.).
Also extracts Node version and JS framework from package.json."
```

---

## Task 3: Update Frontend-TypeScript Scope Generation

**Files:**
- Modify: `skills/agents/scripts/generate-agents.sh` (lines ~1350-1435)

**Step 1: Source the new library at top of generate-agents.sh**

After line 21 (`source "$SCRIPT_DIR/lib/summary.sh"`), add:

```bash
source "$SCRIPT_DIR/lib/config-root.sh"
```

**Step 2: Replace frontend-typescript scope variable assignment**

Find the `"frontend-typescript"` case (around line 1354-1434). Replace the version/framework extraction with stack-specific detection:

```bash
            "frontend-typescript")
                # CRITICAL: Get Node version and framework from nearest package.json,
                # NOT from root PROJECT_INFO (which may be PHP/Go/Python)
                local node_config_root
                node_config_root=$(find_node_config_root "$SCOPE_PATH") || node_config_root="."

                # Extract Node-specific metadata from correct config root
                local node_version
                node_version=$(get_node_version "$node_config_root") || node_version=""
                scope_vars[NODE_VERSION]="$node_version"

                local js_framework
                js_framework=$(get_js_framework "$node_config_root") || js_framework=""
                scope_vars[FRAMEWORK]="$js_framework"

                # Package manager from scope's config root
                scope_vars[PACKAGE_MANAGER]=$(detect_node_package_manager "$SCOPE_PATH")
                scope_vars[ENV_VARS]="See .env.example"

                # Extract commands using Node-specific extraction from config root
                local node_commands
                node_commands=$("$SCRIPT_DIR/extract-commands.sh" "$node_config_root" node)

                scope_vars[INSTALL_CMD]=$(echo "$node_commands" | jq -r '.install // empty')
                scope_vars[TYPECHECK_CMD]=$(echo "$node_commands" | jq -r '.typecheck // empty')
                scope_vars[LINT_CMD]=$(echo "$node_commands" | jq -r '.lint // empty')
                scope_vars[FORMAT_CMD]=$(echo "$node_commands" | jq -r '.format // empty')
                scope_vars[TEST_CMD]=$(echo "$node_commands" | jq -r '.test // empty')
                scope_vars[BUILD_CMD]=$(echo "$node_commands" | jq -r '.build // empty')
                scope_vars[DEV_CMD]=$(echo "$node_commands" | jq -r '.dev // empty')

                # TypeScript strict mode - check, don't assume
                local ts_strict
                ts_strict=$(get_ts_strict_mode "$node_config_root") || ts_strict=""
                scope_vars[TS_STRICT]="$ts_strict"

                # CSS approach detection (keep existing logic)
                scope_vars[CSS_APPROACH]="CSS Modules"

                # ... rest of setup lines remain the same ...
```

**Step 3: Update backend-typescript similarly**

Find the `"backend-typescript"` case (around line 1301-1351) and apply the same pattern:

```bash
            "backend-typescript")
                local node_config_root
                node_config_root=$(find_node_config_root "$SCOPE_PATH") || node_config_root="."

                local node_version
                node_version=$(get_node_version "$node_config_root") || node_version=""
                scope_vars[NODE_VERSION]="$node_version"

                scope_vars[PACKAGE_MANAGER]=$(detect_node_package_manager "$SCOPE_PATH")
                scope_vars[ENV_VARS]="See .env or .env.example"

                # Extract commands with Node stack filter
                local node_commands
                node_commands=$("$SCRIPT_DIR/extract-commands.sh" "$node_config_root" node)

                scope_vars[INSTALL_CMD]=$(echo "$node_commands" | jq -r '.install // empty')
                scope_vars[TYPECHECK_CMD]=$(echo "$node_commands" | jq -r '.typecheck // empty')
                scope_vars[LINT_CMD]=$(echo "$node_commands" | jq -r '.lint // empty')
                scope_vars[FORMAT_CMD]=$(echo "$node_commands" | jq -r '.format // empty')
                scope_vars[TEST_CMD]=$(echo "$node_commands" | jq -r '.test // empty')
                scope_vars[BUILD_CMD]=$(echo "$node_commands" | jq -r '.build // empty')
                scope_vars[DEV_CMD]=$(echo "$node_commands" | jq -r '.dev // empty')

                # ... rest of setup lines ...
```

**Step 4: Run generator on hybrid fixture**

```bash
bash skills/agents/scripts/generate-agents.sh \
    skills/agents/references/examples/php-with-frontend --force --verbose

# Verify no PHP version in frontend scope
grep -r "Node version" skills/agents/references/examples/php-with-frontend/
# Should NOT show ^8.2

# Verify framework is react, not symfony
grep -r "Framework:" skills/agents/references/examples/php-with-frontend/
# Should show react for web/ scope
```

**Step 5: Commit**

```bash
git add skills/agents/scripts/generate-agents.sh
git commit -S -m "fix(generate): use stack-specific metadata for TypeScript scopes

Frontend/backend TypeScript scopes now:
- Find nearest package.json for Node version (not root PROJECT_INFO)
- Extract JS framework from correct dependencies
- Use --stack=node for command extraction
- Check actual tsconfig.json for strict mode

Fixes P0: scope metadata leaking root language/version."
```

---

## Task 4: Add TSX Support for File Maps and Golden Samples

**Files:**
- Modify: `skills/agents/scripts/generate-file-map.sh`
- Modify: `skills/agents/scripts/detect-golden-samples.sh`
- Modify: `skills/agents/scripts/generate-agents.sh` (scope_file_map calls)

**Step 1: Update generate_scope_file_map to accept multiple extensions**

In generate-agents.sh, find the `generate_scope_file_map()` function and update it:

```bash
# Generate file map for a scope directory
# Usage: generate_scope_file_map <path> <extension1> [extension2] [extension3]
generate_scope_file_map() {
    local scope_path="$1"
    shift
    local extensions=("$@")

    [[ ! -d "$scope_path" ]] && return

    local find_args=()
    for ext in "${extensions[@]}"; do
        if [[ ${#find_args[@]} -gt 0 ]]; then
            find_args+=("-o")
        fi
        find_args+=("-name" "*.$ext")
    done

    local files
    files=$(find "$scope_path" -type f \( "${find_args[@]}" \) 2>/dev/null | head -20)
    [[ -z "$files" ]] && return

    local output="| File | Purpose |\n|------|---------|"
    while IFS= read -r file; do
        local relative_path="${file#$scope_path/}"
        local purpose
        purpose=$(infer_file_purpose "$relative_path")
        output+="\n| \`$relative_path\` | $purpose |"
    done <<< "$files"

    echo -e "$output"
}
```

**Step 2: Update frontend-typescript scope to use ts AND tsx**

In the frontend-typescript case, change:

```bash
# OLD:
scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "ts")
scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "ts")

# NEW:
scope_vars[SCOPE_FILE_MAP]=$(generate_scope_file_map "$SCOPE_PATH" "ts" "tsx")
scope_vars[SCOPE_GOLDEN_SAMPLES]=$(generate_scope_golden_samples "$SCOPE_PATH" "ts" "tsx")
```

**Step 3: Update detect-golden-samples.sh for multiple extensions**

Find the extension handling and make it accept multiple:

```bash
# After parsing arguments, build find pattern
build_find_pattern() {
    local extensions=("$@")
    local pattern=""
    for ext in "${extensions[@]}"; do
        [[ -n "$pattern" ]] && pattern+=" -o "
        pattern+="-name '*.$ext'"
    done
    echo "$pattern"
}
```

**Step 4: Test TSX file detection**

```bash
# Verify TSX files are found in hybrid fixture
bash skills/agents/scripts/generate-agents.sh \
    skills/agents/references/examples/php-with-frontend --force

# Check the generated AGENTS.md for web/ scope
cat skills/agents/references/examples/php-with-frontend/web/AGENTS.md 2>/dev/null || \
    grep -A10 "Key Files" skills/agents/references/examples/php-with-frontend/AGENTS.md

# Should show App.tsx and main.tsx
```

**Step 5: Commit**

```bash
git add skills/agents/scripts/generate-agents.sh \
        skills/agents/scripts/detect-golden-samples.sh
git commit -S -m "fix(file-map): support TSX files in frontend scopes

generate_scope_file_map() and detect_golden_samples() now accept
multiple extensions. Frontend scopes search for both .ts and .tsx.

Fixes P1: empty Key Files in frontend scopes with TSX."
```

---

## Task 5: Update Template to Conditionally Assert Facts

**Files:**
- Modify: `skills/agents/assets/scoped/frontend-typescript.md`

**Step 1: Replace hardcoded assertions with conditional placeholders**

Update the template:

```markdown
<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
{{TS_STRICT_LINE}}
{{COMPONENT_STYLE_LINE}}
- Naming: `camelCase` for variables/functions, `PascalCase` for components
- File naming: `ComponentName.tsx`, `utilityName.ts`
- Imports: group and sort (external, internal, types)
{{CSS_APPROACH_LINE}}
{{FRAMEWORK_CONVENTIONS}}
<!-- AGENTS-GENERATED:END code-style -->
```

**Step 2: Add placeholder generation in generate-agents.sh**

In the frontend-typescript case, add:

```bash
# Conditional lines based on detected config
if [[ "${scope_vars[TS_STRICT]}" == "true" ]]; then
    scope_vars[TS_STRICT_LINE]="- TypeScript strict mode enabled (verified from tsconfig.json)"
else
    scope_vars[TS_STRICT_LINE]="- Follow tsconfig.json compiler options"
fi

# Framework-specific component style
case "${scope_vars[FRAMEWORK]}" in
    "react"|"next.js")
        scope_vars[COMPONENT_STYLE_LINE]="- Use functional components with hooks"
        ;;
    "vue")
        scope_vars[COMPONENT_STYLE_LINE]="- Use Composition API with script setup"
        ;;
    "svelte")
        scope_vars[COMPONENT_STYLE_LINE]="- Use Svelte component syntax"
        ;;
    *)
        scope_vars[COMPONENT_STYLE_LINE]=""
        ;;
esac

# CSS approach line
[[ -n "${scope_vars[CSS_APPROACH]:-}" ]] && \
    scope_vars[CSS_APPROACH_LINE]="- CSS: ${scope_vars[CSS_APPROACH]}"
```

**Step 3: Verify no more false assertions**

```bash
# Generate and check output
bash skills/agents/scripts/generate-agents.sh \
    skills/agents/references/examples/express-api-ts --force

# Check - should NOT assert strict mode unless tsconfig has it
grep -i "strict" skills/agents/references/examples/express-api-ts/AGENTS.md
```

**Step 4: Commit**

```bash
git add skills/agents/assets/scoped/frontend-typescript.md \
        skills/agents/scripts/generate-agents.sh
git commit -S -m "fix(template): conditional assertions based on actual config

Replace hardcoded 'TypeScript strict mode enabled' with conditional
{{TS_STRICT_LINE}} that checks tsconfig.json. Same for React-specific
'functional components with hooks' - now framework-aware.

Fixes P1: template assertions not verified."
```

---

## Task 6: Hide Empty Sections

**Files:**
- Modify: `skills/agents/scripts/lib/template.sh`

**Step 1: Add empty section detection to cleanup**

In the `cleanup_unresolved_placeholders()` function, add logic to remove empty sections:

```bash
# Remove sections that are entirely empty (only header + whitespace)
remove_empty_sections() {
    local content="$1"

    # Pattern: ## Header followed by only empty lines until next ## or EOF
    # Use awk to detect and remove these
    echo "$content" | awk '
        /^## / {
            if (header != "" && body == "") {
                # Previous section was empty, skip printing header
            } else if (header != "") {
                print header
                print body
            }
            header = $0
            body = ""
            next
        }
        /^[[:space:]]*$/ {
            # Blank line - only add to body if body has content
            if (body != "") body = body "\n" $0
            next
        }
        {
            body = body (body == "" ? "" : "\n") $0
        }
        END {
            if (header != "" && body != "") {
                print header
                print body
            }
        }
    '
}
```

**Step 2: Update cleanup flow to use this**

In `render_template()`, call `remove_empty_sections()` as part of the pipeline.

**Step 3: Test empty section removal**

```bash
# Create test template with empty section
echo '## Section 1
Content here

## Section 2

## Section 3
More content' | awk '
    # (inline test of the awk logic)
'
# Expected: Section 2 removed
```

**Step 4: Commit**

```bash
git add skills/agents/scripts/lib/template.sh
git commit -S -m "fix(template): hide empty sections instead of blank tables

Sections with only header and whitespace are now removed during
template cleanup. Reduces noise in generated AGENTS.md.

Fixes P2: empty sections shown as blank tables."
```

---

## Task 7: Add Regression Test Fixtures

**Files:**
- Create: `skills/agents/references/examples/go-with-internal-web-tsx/`
- Update: `.github/workflows/validate-agents.yml`

**Step 1: Create Go+Frontend fixture**

```bash
mkdir -p skills/agents/references/examples/go-with-internal-web-tsx/internal/web/src

# Go config at root
cat > skills/agents/references/examples/go-with-internal-web-tsx/go.mod << 'EOF'
module example.com/go-app
go 1.22
EOF

# Node config at root (for frontend)
cat > skills/agents/references/examples/go-with-internal-web-tsx/package.json << 'EOF'
{
    "name": "frontend",
    "scripts": { "build": "vite build", "test": "vitest" },
    "devDependencies": { "react": "^18.0.0" }
}
EOF

# Go source
cat > skills/agents/references/examples/go-with-internal-web-tsx/main.go << 'EOF'
package main
func main() {}
EOF

# TSX source
cat > skills/agents/references/examples/go-with-internal-web-tsx/internal/web/src/App.tsx << 'EOF'
export default function App() { return <div>App</div>; }
EOF
```

**Step 2: Add invariant checks to CI**

In `.github/workflows/validate-agents.yml`, add after existing regression tests:

```yaml
            # Regression test 4: No cross-stack contamination
            # In hybrid repos, frontend scopes should NOT have PHP/Go versions
            if [[ "$fixture" == *"php-with-frontend"* ]] || [[ "$fixture" == *"go-with-internal-web"* ]]; then
              # Find frontend scope AGENTS.md
              frontend_agents=$(find "$fixture" -path "*web*AGENTS.md" -o -path "*frontend*AGENTS.md" | head -1)
              if [[ -n "$frontend_agents" ]]; then
                # Should NOT contain PHP version pattern
                if grep -qE 'PHP version|Go version' "$frontend_agents"; then
                  echo "ERROR: Cross-stack contamination in $frontend_agents"
                  grep -E 'PHP version|Go version' "$frontend_agents"
                  exit 1
                fi
                echo "  ✓ No cross-stack contamination in frontend scope"
              fi
            fi

            # Regression test 5: Frontend scopes with TSX should have files in Key Files
            if [[ -d "$fixture" ]] && find "$fixture" -name "*.tsx" | grep -q .; then
              # Has TSX files - check if AGENTS.md has them
              if grep -q "Key Files" "$fixture/AGENTS.md"; then
                if ! grep -qE '\.tsx' "$fixture/AGENTS.md"; then
                  echo "WARNING: TSX files exist but not in Key Files section"
                fi
              fi
            fi
```

**Step 3: Commit**

```bash
git add skills/agents/references/examples/go-with-internal-web-tsx/ \
        skills/agents/references/examples/php-with-frontend/ \
        .github/workflows/validate-agents.yml
git commit -S -m "test: add hybrid repo fixtures with regression checks

- go-with-internal-web-tsx: Go backend + React frontend in internal/web/
- php-with-frontend: PHP backend + React frontend in web/

CI now checks:
- No PHP/Go version leaking into frontend scopes
- TSX files appear in Key Files section

Prevents regression of P0 cross-contamination bug."
```

---

## Task 8: Add Byte Budget for Scoped Files

**Files:**
- Modify: `skills/agents/scripts/generate-agents.sh`

**Step 1: Apply enforce_byte_budget to scoped files**

Find the scoped file generation loop (around line 1670+) and add budget enforcement:

```bash
        # Render the scoped AGENTS.md
        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Would create: $output_file"
        else
            render_template_smart "$template_file" "$output_file" scope_vars "$UPDATE_ONLY"
            echo "✅ Generated: $output_file"

            # Enforce byte budget for scoped files (use half of root budget)
            local scope_budget=$((BYTE_BUDGET / 2))
            enforce_byte_budget "$output_file" "$scope_budget"
        fi
```

**Step 2: Test budget enforcement**

```bash
# Generate with small budget to trigger pruning
BYTE_BUDGET=4096 bash skills/agents/scripts/generate-agents.sh \
    skills/agents/references/examples/ldap-selfservice --force --verbose

# Check if pruning message appeared
```

**Step 3: Commit**

```bash
git add skills/agents/scripts/generate-agents.sh
git commit -S -m "feat(generate): enforce byte budget on scoped AGENTS.md

Scoped files now use half the root byte budget (default: 16KB per scope).
Prevents large monorepo scopes from exceeding agent context limits.

Fixes P2: no byte budget for scoped files."
```

---

## Summary Checklist

After all tasks, verify:

- [ ] `extract-commands.sh --stack=node` returns only Node commands
- [ ] `extract-commands.sh --stack=php` returns only PHP commands
- [ ] Frontend scopes show correct Node version (from package.json engines)
- [ ] Frontend scopes show correct JS framework (from dependencies)
- [ ] TSX files appear in Key Files section
- [ ] No "TypeScript strict mode" unless tsconfig.json has strict:true
- [ ] Empty sections are removed
- [ ] CI passes with new regression tests

Run full validation:

```bash
# Run all fixtures
for f in skills/agents/references/examples/*/; do
    echo "=== $f ==="
    bash skills/agents/scripts/generate-agents.sh "$f" --force
done

# Run CI locally
act -j test-generator  # if using act
```

---

## Release

After all tasks pass:

```bash
# Update version
jq '.version = "2.7.0"' .claude-plugin/plugin.json > tmp.json && mv tmp.json .claude-plugin/plugin.json

git add .claude-plugin/plugin.json
git commit -S -m "chore: bump version to 2.7.0"

git tag -s v2.7.0 -m "v2.7.0 - Hybrid Stack Correctness"
git push && git push origin v2.7.0

gh release create v2.7.0 --title "v2.7.0 - Hybrid Stack Correctness" --notes "..."
```
