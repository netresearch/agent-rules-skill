#!/usr/bin/env bash
# Detect project type, language, version, and build tools
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config-root.sh"

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Initialize variables
LANGUAGE="unknown"
VERSION="unknown"
BUILD_TOOL="unknown"      # Deprecated: use package_manager or task_runner
PACKAGE_MANAGER="unknown" # Package manager: npm/yarn/pnpm/bun, composer, poetry/uv/pip, go
TASK_RUNNER="none"        # Task runner: make/just/mage/bazel, or none
FRAMEWORK="none"
PROJECT_TYPE="unknown"
QUALITY_TOOLS=()
TEST_FRAMEWORK="unknown"
HAS_DOCKER=false
CI="none"
IDE_CONFIGS=()
AGENT_CONFIGS=()
STACKS=()                 # Multi-stack detection: (go, php, python, typescript, docker)

# Detect language and version
detect_language() {
    if [ -f "go.mod" ]; then
        LANGUAGE="go"
        VERSION=$(grep '^go ' go.mod | awk '{print $2}' || echo "unknown")
        BUILD_TOOL="go"
        PACKAGE_MANAGER="go"
        TEST_FRAMEWORK="testing"

        # Detect Go project type
        if [ -d "cmd" ]; then
            PROJECT_TYPE="go-cli"
        elif grep -q "github.com/gofiber/fiber" go.mod 2>/dev/null; then
            PROJECT_TYPE="go-web-app"
            FRAMEWORK="fiber"
        elif grep -q "github.com/labstack/echo" go.mod 2>/dev/null; then
            PROJECT_TYPE="go-web-app"
            FRAMEWORK="echo"
        elif grep -q "github.com/gin-gonic/gin" go.mod 2>/dev/null; then
            PROJECT_TYPE="go-web-app"
            FRAMEWORK="gin"
        else
            PROJECT_TYPE="go-library"
        fi

        # Detect Go quality tools
        { [ -f ".golangci.yml" ] || [ -f ".golangci.yaml" ]; } && QUALITY_TOOLS+=("golangci-lint") || true
        command -v gofmt &>/dev/null && QUALITY_TOOLS+=("gofmt") || true

    elif [ -f "composer.json" ]; then
        # Check if this is actually a PHP project:
        # 1. Has PHP version requirement, OR
        # 2. Has PHP source files, OR
        # 3. Has PHP framework dependencies
        local has_php_requirement=false
        local has_php_files=false
        local has_php_deps=false

        # Check for PHP version requirement
        if jq -e '.require.php // .["require-dev"].php' composer.json &>/dev/null; then
            has_php_requirement=true
        fi

        # Check for PHP source files (common locations)
        if [ -d "src" ] && find src -name "*.php" -type f 2>/dev/null | head -1 | grep -q .; then
            has_php_files=true
        elif [ -d "Classes" ] && find Classes -name "*.php" -type f 2>/dev/null | head -1 | grep -q .; then
            has_php_files=true
        elif [ -d "lib" ] && find lib -name "*.php" -type f 2>/dev/null | head -1 | grep -q .; then
            has_php_files=true
        elif [ -f "ext_emconf.php" ]; then
            has_php_files=true
        elif find . -maxdepth 2 -name "*.php" -type f 2>/dev/null | head -1 | grep -q .; then
            has_php_files=true
        fi

        # Check for PHP framework dependencies
        if jq -e '.require."typo3/cms-core" // .require."laravel/framework" // .require."symfony/framework-bundle" // .require."oro/platform"' composer.json &>/dev/null; then
            has_php_deps=true
        fi

        # Only treat as PHP if we have evidence it's a PHP project
        if [ "$has_php_requirement" = true ] || [ "$has_php_files" = true ] || [ "$has_php_deps" = true ]; then
            LANGUAGE="php"
            VERSION=$(jq -r '.require.php // "unknown"' composer.json 2>/dev/null || echo "unknown")
            BUILD_TOOL="composer"
            PACKAGE_MANAGER="composer"
        else
            # composer.json exists but this isn't a PHP project
            # Continue to check other languages
            :
        fi

        # Detect PHP framework (only if we determined this is PHP)
        if [ "$LANGUAGE" = "php" ]; then
            # TYPO3 extension detection (ext_emconf.php is definitive)
            if [ -f "ext_emconf.php" ]; then
                PROJECT_TYPE="php-typo3-extension"
                FRAMEWORK="typo3"
            elif jq -e '.require."typo3/cms-core"' composer.json &>/dev/null; then
                PROJECT_TYPE="php-typo3"
                FRAMEWORK="typo3"
            # Oro detection (OroCommerce, OroPlatform, OroCRM)
            # Differentiate between full Oro project and standalone bundle
            elif jq -e '.require."oro/platform"' composer.json &>/dev/null || \
                 jq -e '.require."oro/commerce"' composer.json &>/dev/null || \
                 jq -e '.require."oro/crm"' composer.json &>/dev/null; then
                FRAMEWORK="oro"
                # Check if it's a standalone bundle (has type: oro-bundle, or no bin/console)
                composer_type=$(jq -r '.type // ""' composer.json 2>/dev/null)
                if [ "$composer_type" = "oro-bundle" ] || [ "$composer_type" = "symfony-bundle" ]; then
                    PROJECT_TYPE="php-oro-bundle"
                elif [ -f "bin/console" ] || [ -f "public/index.php" ]; then
                    PROJECT_TYPE="php-oro"
                else
                    # Likely a standalone bundle without explicit type
                    PROJECT_TYPE="php-oro-bundle"
                fi
            elif [ -f "config/oro/bundles.yml" ]; then
                PROJECT_TYPE="php-oro-bundle"
                FRAMEWORK="oro"
            elif jq -e '.require."laravel/framework"' composer.json &>/dev/null; then
                PROJECT_TYPE="php-laravel"
                FRAMEWORK="laravel"
            elif jq -e '.require."symfony/symfony"' composer.json &>/dev/null || \
                 jq -e '.require."symfony/framework-bundle"' composer.json &>/dev/null; then
                PROJECT_TYPE="php-symfony"
                FRAMEWORK="symfony"
            else
                PROJECT_TYPE="php-library"
            fi

            # Detect PHP quality tools
            jq -e '.require."phpstan/phpstan" // .["require-dev"]."phpstan/phpstan"' composer.json &>/dev/null && QUALITY_TOOLS+=("phpstan") || true
            jq -e '.require."friendsofphp/php-cs-fixer" // .["require-dev"]."friendsofphp/php-cs-fixer"' composer.json &>/dev/null && QUALITY_TOOLS+=("php-cs-fixer") || true
            { [ -f "phpunit.xml" ] || [ -f "phpunit.xml.dist" ]; } && TEST_FRAMEWORK="phpunit" || true
        fi
        # If composer.json exists but it's not a PHP project, fall through to other checks

    fi

    # Check for package.json (might also exist alongside composer.json)
    if [ "$LANGUAGE" = "unknown" ] && [ -f "package.json" ]; then
        LANGUAGE="typescript"
        VERSION=$(jq -r '.engines.node // "unknown"' package.json 2>/dev/null || echo "unknown")

        # Detect package manager from lockfile (workspace-aware, default npm)
        PACKAGE_MANAGER="npm"
        local ws_root
        ws_root=$(find_node_workspace_root "$(pwd)" || true)
        if [ -n "$ws_root" ]; then
            # Check workspace root for lockfiles
            [ -f "$ws_root/pnpm-lock.yaml" ] && PACKAGE_MANAGER="pnpm"
            [ -f "$ws_root/yarn.lock" ] && PACKAGE_MANAGER="yarn"
            [ -f "$ws_root/bun.lockb" ] && PACKAGE_MANAGER="bun"
            [ -f "$ws_root/package-lock.json" ] && PACKAGE_MANAGER="npm"
        else
            # Fallback to local lockfiles
            [ -f "yarn.lock" ] && PACKAGE_MANAGER="yarn"
            [ -f "pnpm-lock.yaml" ] && PACKAGE_MANAGER="pnpm"
            [ -f "bun.lockb" ] && PACKAGE_MANAGER="bun"
        fi
        BUILD_TOOL="$PACKAGE_MANAGER"

        # Detect JS/TS framework
        if jq -e '.dependencies."next"' package.json &>/dev/null; then
            PROJECT_TYPE="typescript-nextjs"
            FRAMEWORK="next.js"
        elif jq -e '.dependencies."react"' package.json &>/dev/null; then
            PROJECT_TYPE="typescript-react"
            FRAMEWORK="react"
        elif jq -e '.dependencies."vue"' package.json &>/dev/null; then
            PROJECT_TYPE="typescript-vue"
            FRAMEWORK="vue"
        elif jq -e '.dependencies."express"' package.json &>/dev/null; then
            PROJECT_TYPE="typescript-node"
            FRAMEWORK="express"
        else
            PROJECT_TYPE="typescript-library"
        fi

        # Detect quality tools
        jq -e '.devDependencies."eslint"' package.json &>/dev/null && QUALITY_TOOLS+=("eslint") || true
        jq -e '.devDependencies."prettier"' package.json &>/dev/null && QUALITY_TOOLS+=("prettier") || true
        jq -e '.devDependencies."typescript"' package.json &>/dev/null && QUALITY_TOOLS+=("tsc") || true

        # Detect test framework
        if jq -e '.devDependencies."jest"' package.json &>/dev/null; then
            TEST_FRAMEWORK="jest"
        elif jq -e '.devDependencies."vitest"' package.json &>/dev/null; then
            TEST_FRAMEWORK="vitest"
        fi || true

    fi

    # Check for pyproject.toml
    if [ "$LANGUAGE" = "unknown" ] && [ -f "pyproject.toml" ]; then
        LANGUAGE="python"
        VERSION=$(grep 'requires-python' pyproject.toml | cut -d'"' -f2 2>/dev/null || echo "unknown")

        # Detect Python package manager
        if grep -q '\[tool.poetry\]' pyproject.toml 2>/dev/null; then
            PACKAGE_MANAGER="poetry"
        elif grep -q '\[tool.uv\]' pyproject.toml 2>/dev/null || [ -f "uv.lock" ]; then
            PACKAGE_MANAGER="uv"
        elif grep -q '\[tool.hatch\]' pyproject.toml 2>/dev/null; then
            PACKAGE_MANAGER="hatch"
        else
            PACKAGE_MANAGER="pip"
        fi
        BUILD_TOOL="$PACKAGE_MANAGER"

        # Detect framework
        if grep -q 'django' pyproject.toml 2>/dev/null; then
            PROJECT_TYPE="python-django"
            FRAMEWORK="django"
        elif grep -q 'flask' pyproject.toml 2>/dev/null; then
            PROJECT_TYPE="python-flask"
            FRAMEWORK="flask"
        elif grep -q 'fastapi' pyproject.toml 2>/dev/null; then
            PROJECT_TYPE="python-fastapi"
            FRAMEWORK="fastapi"
        elif [ -d "scripts" ] && [ "$(find scripts -name '*.py' | wc -l)" -gt 3 ]; then
            PROJECT_TYPE="python-cli"
        else
            PROJECT_TYPE="python-library"
        fi

        # Detect quality tools
        grep -q 'ruff' pyproject.toml 2>/dev/null && QUALITY_TOOLS+=("ruff")
        grep -q 'black' pyproject.toml 2>/dev/null && QUALITY_TOOLS+=("black")
        grep -q 'mypy' pyproject.toml 2>/dev/null && QUALITY_TOOLS+=("mypy")
        grep -q 'pytest' pyproject.toml 2>/dev/null && TEST_FRAMEWORK="pytest"
    fi

    # Check for Claude Code plugin/skill repos
    # Can be: plugin-only, skill-only, plugin+skills, or any of these with bash
    if [ "$LANGUAGE" = "unknown" ]; then
        local has_plugin=false
        local has_skills=false
        local skill_count=0

        [ -f ".claude-plugin/plugin.json" ] && has_plugin=true
        [ -d "skills" ] && skill_count=$(find skills -maxdepth 2 -name "SKILL.md" -type f 2>/dev/null | wc -l)
        [ "$skill_count" -gt 0 ] && has_skills=true

        if [ "$has_plugin" = true ] || [ "$has_skills" = true ]; then
            FRAMEWORK="claude-code"
            PACKAGE_MANAGER="none"

            # Determine project type based on combination
            if [ "$has_plugin" = true ] && [ "$has_skills" = true ]; then
                if [ "$skill_count" -gt 1 ]; then
                    PROJECT_TYPE="claude-code-plugin-monorepo"
                else
                    PROJECT_TYPE="claude-code-plugin"
                fi
                LANGUAGE="claude-code-plugin"
            elif [ "$has_plugin" = true ]; then
                PROJECT_TYPE="claude-code-plugin"
                LANGUAGE="claude-code-plugin"
            else
                # Skills without plugin.json (standalone skill repo)
                if [ "$skill_count" -gt 1 ]; then
                    PROJECT_TYPE="claude-code-skill-monorepo"
                else
                    PROJECT_TYPE="claude-code-skill"
                fi
                LANGUAGE="claude-code-skill"
            fi

            # Check for shell scripts (common in skills)
            local sh_count
            sh_count=$(find . -maxdepth 5 -name "*.sh" -type f 2>/dev/null | wc -l)
            if [ "$sh_count" -gt 3 ]; then
                BUILD_TOOL="bash"
                [ -f ".shellcheckrc" ] && QUALITY_TOOLS+=("shellcheck") || true
            fi
        fi
    fi

    # Container-primary detection (Dockerfile-only repos)
    # Must come before bash fallback - some container repos have helper scripts
    if [ "$LANGUAGE" = "unknown" ]; then
        if [ -f "Dockerfile" ]; then
            # Check if this is primarily a container image project
            # Indicators: no source code, or only build scripts
            local has_source=false
            # Check for significant source files
            [ "$(find . -maxdepth 3 -name '*.go' -o -name '*.py' -o -name '*.php' -o -name '*.ts' -o -name '*.js' 2>/dev/null | head -5 | wc -l)" -gt 3 ] && has_source=true

            if [ "$has_source" = false ]; then
                LANGUAGE="docker"
                PROJECT_TYPE="container-image"
                BUILD_TOOL="docker"
                PACKAGE_MANAGER="none"
                FRAMEWORK="docker"

                # Detect if it's a compose-based project
                if [ -f "docker-compose.yml" ] || [ -f "compose.yml" ] || [ -f "compose.yaml" ]; then
                    PROJECT_TYPE="container-stack"
                fi
            fi
        fi
    fi

    # Fallback: Check for bash/shell projects
    if [ "$LANGUAGE" = "unknown" ]; then
        local sh_count
        sh_count=$(find . -maxdepth 5 -name "*.sh" -type f 2>/dev/null | wc -l)
        if [ "$sh_count" -gt 3 ]; then
            LANGUAGE="bash"
            PROJECT_TYPE="bash-scripts"
            BUILD_TOOL="bash"
            PACKAGE_MANAGER="none"
            # Check for shellcheck
            [ -f ".shellcheckrc" ] && QUALITY_TOOLS+=("shellcheck") || true
        fi
    fi
}

# Detect task runner (does NOT override package_manager)
if [ -f "Makefile" ]; then
    TASK_RUNNER="make"
elif [ -f "justfile" ] || [ -f "Justfile" ]; then
    TASK_RUNNER="just"
elif [ -f "Taskfile.yml" ] || [ -f "Taskfile.yaml" ]; then
    TASK_RUNNER="task"
fi

# Detect Docker (check both old and new compose naming)
[ -f "Dockerfile" ] || [ -f "docker-compose.yml" ] || [ -f "compose.yml" ] || [ -f "compose.yaml" ] && HAS_DOCKER=true

# Detect CI
if [ -d ".github/workflows" ]; then
    CI="github-actions"
elif [ -f ".gitlab-ci.yml" ]; then
    CI="gitlab-ci"
elif [ -f ".circleci/config.yml" ]; then
    CI="circleci"
fi

# Detect IDE configurations
[ -f ".editorconfig" ] && IDE_CONFIGS+=("editorconfig") || true
[ -d ".vscode" ] && IDE_CONFIGS+=("vscode") || true
[ -d ".idea" ] && IDE_CONFIGS+=("idea") || true
[ -d ".phpstorm" ] && IDE_CONFIGS+=("phpstorm") || true
[ -d ".fleet" ] && IDE_CONFIGS+=("fleet") || true
[ -f ".sublime-project" ] && IDE_CONFIGS+=("sublime") || true
{ [ -d ".vim" ] || [ -f ".vimrc" ]; } && IDE_CONFIGS+=("vim") || true
{ [ -d ".nvim" ] || [ -f ".nvimrc" ]; } && IDE_CONFIGS+=("neovim") || true

# Detect AI coding agent configurations
[ -d ".cursor" ] && AGENT_CONFIGS+=("cursor") || true
{ [ -d ".claude" ] || [ -f "CLAUDE.md" ] || [ -f ".claude/CLAUDE.md" ]; } && AGENT_CONFIGS+=("claude") || true
[ -d ".windsurf" ] && AGENT_CONFIGS+=("windsurf") || true
{ [ -d ".aider" ] || [ -f ".aider.conf.yml" ]; } && AGENT_CONFIGS+=("aider") || true
[ -d ".continue" ] && AGENT_CONFIGS+=("continue") || true
{ [ -f "copilot-instructions.md" ] || [ -f ".github/copilot-instructions.md" ]; } && AGENT_CONFIGS+=("copilot") || true
[ -d ".codeium" ] && AGENT_CONFIGS+=("codeium") || true
[ -d ".tabnine" ] && AGENT_CONFIGS+=("tabnine") || true
{ [ -d ".sourcegraph" ] || [ -f ".sourcegraph/cody.json" ]; } && AGENT_CONFIGS+=("cody") || true

# Run detection
detect_language

# Multi-stack detection: detect secondary languages/technologies
# STACKS array is populated here after primary language detection
detect_stacks() {
    # Always add primary language to stacks (if known)
    [ "$LANGUAGE" != "unknown" ] && STACKS+=("$LANGUAGE")

    # Detect Docker as secondary stack (if not already primary)
    if [ "$LANGUAGE" != "docker" ] && [ "$HAS_DOCKER" = true ]; then
        STACKS+=("docker")
    fi

    # Detect frontend stack in backend projects
    if [[ "$LANGUAGE" =~ ^(php|go|python)$ ]]; then
        # Check for Node.js frontend
        if [ -f "package.json" ]; then
            # Check what kind of frontend
            if jq -e '.dependencies."react" // .dependencies."next"' package.json &>/dev/null; then
                STACKS+=("react")
            elif jq -e '.dependencies."vue"' package.json &>/dev/null; then
                STACKS+=("vue")
            elif jq -e '.dependencies."svelte"' package.json &>/dev/null; then
                STACKS+=("svelte")
            else
                STACKS+=("typescript")
            fi
        fi
        # Check for frontend in subdirectories
        for frontend_dir in web frontend client ui internal/web; do
            if [ -d "$frontend_dir" ] && [ -f "$frontend_dir/package.json" ]; then
                if jq -e '.dependencies."react" // .dependencies."next"' "$frontend_dir/package.json" &>/dev/null; then
                    [[ ! " ${STACKS[*]} " =~ " react " ]] && STACKS+=("react")
                elif jq -e '.dependencies."vue"' "$frontend_dir/package.json" &>/dev/null; then
                    [[ ! " ${STACKS[*]} " =~ " vue " ]] && STACKS+=("vue")
                fi
            fi
        done
    fi

    # Detect backend in frontend projects (monorepo patterns)
    if [[ "$LANGUAGE" == "typescript" ]]; then
        # Check for Go backend
        if [ -f "go.mod" ] || [ -d "server" ] && [ -f "server/go.mod" ]; then
            STACKS+=("go")
        fi
        # Check for Python backend
        if [ -f "pyproject.toml" ] || { [ -d "server" ] && [ -f "server/pyproject.toml" ]; }; then
            STACKS+=("python")
        fi
        # Check for PHP backend
        if [ -f "composer.json" ] || { [ -d "api" ] && [ -f "api/composer.json" ]; }; then
            STACKS+=("php")
        fi
    fi
}

detect_stacks

# Output JSON
# Handle empty arrays
if [ ${#QUALITY_TOOLS[@]} -eq 0 ]; then
    TOOLS_JSON="[]"
else
    TOOLS_JSON="$(printf '%s\n' "${QUALITY_TOOLS[@]}" | jq -R . | jq -s .)"
fi

if [ ${#IDE_CONFIGS[@]} -eq 0 ]; then
    IDE_JSON="[]"
else
    IDE_JSON="$(printf '%s\n' "${IDE_CONFIGS[@]}" | jq -R . | jq -s .)"
fi

if [ ${#AGENT_CONFIGS[@]} -eq 0 ]; then
    AGENT_JSON="[]"
else
    AGENT_JSON="$(printf '%s\n' "${AGENT_CONFIGS[@]}" | jq -R . | jq -s .)"
fi

if [ ${#STACKS[@]} -eq 0 ]; then
    STACKS_JSON="[]"
else
    STACKS_JSON="$(printf '%s\n' "${STACKS[@]}" | jq -R . | jq -s .)"
fi

jq -n \
    --arg type "$PROJECT_TYPE" \
    --arg lang "$LANGUAGE" \
    --arg ver "$VERSION" \
    --arg build "$BUILD_TOOL" \
    --arg pkg_mgr "$PACKAGE_MANAGER" \
    --arg task_runner "$TASK_RUNNER" \
    --arg framework "$FRAMEWORK" \
    --argjson docker "$HAS_DOCKER" \
    --argjson tools "$TOOLS_JSON" \
    --arg test "$TEST_FRAMEWORK" \
    --arg ci "$CI" \
    --argjson ide_configs "$IDE_JSON" \
    --argjson agent_configs "$AGENT_JSON" \
    --argjson stacks "$STACKS_JSON" \
    '{
        type: $type,
        language: $lang,
        version: $ver,
        build_tool: $build,
        package_manager: $pkg_mgr,
        task_runner: $task_runner,
        framework: $framework,
        has_docker: $docker,
        quality_tools: $tools,
        test_framework: $test,
        ci: $ci,
        ide_configs: $ide_configs,
        agent_configs: $agent_configs,
        stacks: $stacks
    }'
