#!/usr/bin/env bash
# Detect project heuristics (When X → Do Y decisions)
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Get project language
PROJECT_INFO=$(bash "$(dirname "$0")/detect-project.sh" "$PROJECT_DIR" 2>/dev/null || echo '{"language":"unknown"}')
LANGUAGE=$(echo "$PROJECT_INFO" | jq -r '.language')

output=""

# Check for env file patterns
if [ -f ".env.example" ] || [ -f ".env.sample" ]; then
    output="$output| Adding env var | Add to \`.env.example\` first |\n"
fi

# Check for TypeScript env types
if [ -f "src/env.d.ts" ] || [ -f "types/env.d.ts" ]; then
    output="$output| Adding env var | Also update \`types/env.d.ts\` |\n"
fi

# Check for Next.js App Router
if [ -d "app" ] && [ -f "next.config.js" -o -f "next.config.ts" -o -f "next.config.mjs" ]; then
    output="$output| Adding new page | Create in \`app/\` (App Router) |\n"
fi

# Check for old Next.js Pages Router
if [ -d "pages" ] && [ ! -d "app" ]; then
    output="$output| Adding new page | Create in \`pages/\` directory |\n"
fi

# Check for state management
if grep -q "zustand" package.json 2>/dev/null; then
    output="$output| Adding state | Use Zustand store in \`stores/\` |\n"
elif grep -q "redux" package.json 2>/dev/null; then
    output="$output| Adding state | Use Redux slice pattern |\n"
elif grep -q "mobx" package.json 2>/dev/null; then
    output="$output| Adding state | Use MobX observable pattern |\n"
fi

# Check for API directory patterns
if [ -d "src/api" ] || [ -d "api" ]; then
    api_dir=$([ -d "src/api" ] && echo "src/api" || echo "api")
    output="$output| Adding API endpoint | Create in \`$api_dir/\` |\n"
fi

# Check for test patterns
if [ -d "__tests__" ]; then
    output="$output| Adding tests | Create in \`__tests__/\` directory |\n"
elif [ -d "tests" ] || [ -d "test" ]; then
    test_dir=$([ -d "tests" ] && echo "tests" || echo "test")
    output="$output| Adding tests | Create in \`$test_dir/\` directory |\n"
fi

# Check for TYPO3
if [ -f "ext_emconf.php" ]; then
    output="$output| Adding controller | Create in \`Classes/Controller/\` |\n"
    output="$output| Adding service | Create in \`Classes/Service/\` |\n"
fi

# Check for Makefile
if [ -f "Makefile" ]; then
    output="$output| Running tasks | Check \`make help\` for available commands |\n"
fi

# Check for Docker
if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] || [ -f "compose.yml" ]; then
    output="$output| Running locally | Use \`docker compose up\` |\n"
fi

# Check for DDEV
if [ -d ".ddev" ]; then
    output="$output| Running locally | Use \`ddev start\` then \`ddev ssh\` |\n"
fi

# Language-specific heuristics
case "$LANGUAGE" in
    "go")
        output="$output| Adding package | Internal → \`internal/\`, Public → \`pkg/\` |\n"
        [ -f "go.work" ] && output="$output| Multi-module | Use \`go.work\` for workspace |\n"
        ;;
    "php")
        output="$output| Adding class | Follow PSR-4 in \`Classes/\` or \`src/\` |\n"
        ;;
    "python")
        [ -f "pyproject.toml" ] && output="$output| Adding dependency | Update \`pyproject.toml\` |\n"
        ;;
esac

# Output (remove empty lines, duplicates, limit to 10)
echo -e "$output" | sed '/^$/d' | sort -u | head -10
