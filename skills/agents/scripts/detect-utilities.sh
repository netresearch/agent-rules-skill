#!/usr/bin/env bash
# Detect utility files and libraries to prevent reinvention
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

# Common utility directory names
UTIL_DIRS=("utils" "util" "helpers" "helper" "lib" "shared" "common" "pkg")

# Find utility directories
find_util_dirs() {
    for dir in "${UTIL_DIRS[@]}"; do
        [ -d "$dir" ] && echo "$dir"
        [ -d "src/$dir" ] && echo "src/$dir"
        [ -d "internal/$dir" ] && echo "internal/$dir"
    done
}

# Extract exports from TypeScript index file
extract_ts_exports() {
    local file="$1"
    grep -oE "export \{ [^}]+ \}" "$file" 2>/dev/null | \
        sed 's/export { //; s/ }//; s/,/\n/g' | \
        tr -d ' ' | head -10
}

# Extract function names from Go file
extract_go_exports() {
    local dir="$1"
    find "$dir" -name "*.go" -type f 2>/dev/null | while read -r file; do
        grep -oE "^func [A-Z][a-zA-Z0-9_]*" "$file" 2>/dev/null | \
            sed 's/func //' | head -5
    done | sort -u | head -10
}

# Extract function names from Python file
extract_py_exports() {
    local dir="$1"
    find "$dir" -name "*.py" ! -name "__*" -type f 2>/dev/null | while read -r file; do
        grep -oE "^def [a-z_][a-z0-9_]*" "$file" 2>/dev/null | \
            sed 's/def //' | head -5
    done | sort -u | head -10
}

# Infer utility purpose from name
infer_purpose() {
    local name="$1"
    case "$name" in
        *date*|*time*|*format*Date*) echo "date/time formatting" ;;
        *http*|*fetch*|*api*|*client*) echo "HTTP requests" ;;
        *log*|*logger*) echo "logging" ;;
        *valid*|*check*) echo "validation" ;;
        *parse*) echo "parsing" ;;
        *format*) echo "formatting" ;;
        *error*) echo "error handling" ;;
        *auth*|*token*) echo "authentication" ;;
        *cache*) echo "caching" ;;
        *config*) echo "configuration" ;;
        *string*|*str*) echo "string manipulation" ;;
        *file*|*path*) echo "file operations" ;;
        *) echo "utility" ;;
    esac
}

# Generate output
output=""

while IFS= read -r dir; do
    [ -z "$dir" ] && continue

    case "$LANGUAGE" in
        "typescript")
            # Check for index.ts barrel export
            if [ -f "$dir/index.ts" ]; then
                while IFS= read -r export; do
                    [ -z "$export" ] && continue
                    purpose=$(infer_purpose "$export")
                    output="$output| $purpose | \`$export\` | \`$dir/\` |\n"
                done < <(extract_ts_exports "$dir/index.ts")
            fi
            ;;

        "go")
            while IFS= read -r func; do
                [ -z "$func" ] && continue
                purpose=$(infer_purpose "$func")
                output="$output| $purpose | \`$func\` | \`$dir/\` |\n"
            done < <(extract_go_exports "$dir")
            ;;

        "python")
            while IFS= read -r func; do
                [ -z "$func" ] && continue
                purpose=$(infer_purpose "$func")
                output="$output| $purpose | \`$func\` | \`$dir/\` |\n"
            done < <(extract_py_exports "$dir")
            ;;

        "php")
            # List PHP utility classes
            find "$dir" -name "*.php" -type f 2>/dev/null | while read -r file; do
                class=$(grep -oE "class [A-Z][a-zA-Z0-9_]+" "$file" 2>/dev/null | head -1 | sed 's/class //')
                [ -n "$class" ] && {
                    purpose=$(infer_purpose "$class")
                    relpath="${file#./}"
                    echo "| $purpose | \`$class\` | \`$relpath\` |"
                }
            done | head -10
            ;;
    esac
done < <(find_util_dirs)

# Check for common utility files at root or src
for util_file in "utils.ts" "utils.js" "helpers.ts" "helpers.js" "utils.py" "helpers.py"; do
    for prefix in "" "src/"; do
        file="${prefix}${util_file}"
        [ -f "$file" ] && output="$output| utilities | \`$file\` | \`$file\` |\n"
    done
done

# Output (remove duplicates)
echo -e "$output" | sort -u | head -15
