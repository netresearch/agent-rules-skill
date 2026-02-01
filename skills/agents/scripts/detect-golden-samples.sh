#!/usr/bin/env bash
# Detect golden sample files (canonical patterns to follow)
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Check if git is available
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo ""
    exit 0
fi

# Get project language
PROJECT_INFO=$(bash "$(dirname "$0")/detect-project.sh" "$PROJECT_DIR" 2>/dev/null || echo '{"language":"unknown"}')
LANGUAGE=$(echo "$PROJECT_INFO" | jq -r '.language')

# Find high-churn files (frequently modified = important)
get_high_churn_files() {
    git log --name-only --pretty=format: --since="6 months ago" 2>/dev/null | \
        grep -v '^$' | \
        sort | uniq -c | sort -rn | head -20
}

# Find entrypoint files
find_entrypoints() {
    case "$LANGUAGE" in
        "go")
            find . -name "main.go" -type f 2>/dev/null | head -5
            ;;
        "typescript")
            for f in src/index.ts src/index.tsx src/main.ts src/main.tsx app/page.tsx pages/index.tsx; do
                [ -f "$f" ] && echo "$f"
            done
            ;;
        "php")
            for f in public/index.php src/Kernel.php ext_localconf.php; do
                [ -f "$f" ] && echo "$f"
            done
            ;;
        "python")
            for f in src/main.py main.py app/main.py __main__.py; do
                [ -f "$f" ] && echo "$f"
            done
            ;;
    esac
}

# Find component/model examples
find_examples() {
    case "$LANGUAGE" in
        "go")
            # Find a service or handler file
            find . -path ./vendor -prune -o -name "*_service.go" -type f -print 2>/dev/null | head -1
            find . -path ./vendor -prune -o -name "*_handler.go" -type f -print 2>/dev/null | head -1
            ;;
        "typescript")
            # Find a component
            find . -path ./node_modules -prune -o -name "*.tsx" -type f -print 2>/dev/null | \
                grep -E "(Button|Card|Modal|Form)" | head -1
            # Find an API route
            find . -path ./node_modules -prune -o -path "*/api/*" -name "*.ts" -type f -print 2>/dev/null | head -1
            ;;
        "php")
            # Find a controller
            find . -path ./vendor -prune -o -name "*Controller.php" -type f -print 2>/dev/null | head -1
            # Find a service
            find . -path ./vendor -prune -o -name "*Service.php" -type f -print 2>/dev/null | head -1
            ;;
        "python")
            # Find a service or model
            find . -path ./.venv -prune -o -name "*_service.py" -type f -print 2>/dev/null | head -1
            find . -path ./.venv -prune -o -name "models.py" -type f -print 2>/dev/null | head -1
            ;;
    esac
}

# Find test examples
find_test_examples() {
    case "$LANGUAGE" in
        "go")
            find . -path ./vendor -prune -o -name "*_test.go" -type f -print 2>/dev/null | head -1
            ;;
        "typescript")
            find . -path ./node_modules -prune -o -name "*.test.ts" -o -name "*.test.tsx" -type f -print 2>/dev/null | head -1
            ;;
        "php")
            find . -path ./vendor -prune -o -name "*Test.php" -type f -print 2>/dev/null | head -1
            ;;
        "python")
            find . -path ./.venv -prune -o -name "test_*.py" -type f -print 2>/dev/null | head -1
            ;;
    esac
}

# Describe file based on name/path
describe_file() {
    local file="$1"
    case "$file" in
        *main.go|*main.ts|*main.py|*/index.ts*) echo "Entrypoint" ;;
        *Controller*) echo "Controller" ;;
        *Service*|*_service*) echo "Service" ;;
        *Handler*|*_handler*) echo "Handler" ;;
        *Model*|*models*) echo "Model" ;;
        *Test*|*test*|*_test*) echo "Test" ;;
        *Button*|*Card*|*Modal*) echo "Component" ;;
        */api/*) echo "API route" ;;
        *) echo "Reference" ;;
    esac
}

# Describe key patterns in file
describe_patterns() {
    local file="$1"
    local patterns=""

    if [ -f "$file" ]; then
        # Check for common patterns
        grep -l "interface" "$file" > /dev/null 2>&1 && patterns="$patterns, interface"
        grep -l "async" "$file" > /dev/null 2>&1 && patterns="$patterns, async"
        grep -l "class" "$file" > /dev/null 2>&1 && patterns="$patterns, class"
        grep -l "test\|describe\|it(" "$file" > /dev/null 2>&1 && patterns="$patterns, tests"
        grep -l "func.*error" "$file" > /dev/null 2>&1 && patterns="$patterns, error handling"
    fi

    # Remove leading ", "
    echo "${patterns#, }"
}

# Generate output in table row format
output=""

# Add entrypoints
while IFS= read -r file; do
    [ -z "$file" ] && continue
    file="${file#./}"
    desc=$(describe_file "$file")
    patterns=$(describe_patterns "$file")
    [ -n "$patterns" ] && patterns=" ($patterns)"
    output="$output| $desc | \`$file\` | ${patterns:-standard patterns} |\n"
done < <(find_entrypoints)

# Add examples
while IFS= read -r file; do
    [ -z "$file" ] && continue
    file="${file#./}"
    desc=$(describe_file "$file")
    patterns=$(describe_patterns "$file")
    [ -n "$patterns" ] && patterns=" ($patterns)"
    output="$output| $desc | \`$file\` | ${patterns:-standard patterns} |\n"
done < <(find_examples)

# Add test example
while IFS= read -r file; do
    [ -z "$file" ] && continue
    file="${file#./}"
    output="$output| Test | \`$file\` | test structure |\n"
done < <(find_test_examples)

# Output (remove trailing newline and duplicates)
echo -e "$output" | sort -u | head -10
