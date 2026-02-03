#!/usr/bin/env bash
# Template rendering helper functions

# Render template with placeholder replacement
# Supports multi-line values using bash string replacement
render_template() {
    local template_file="$1"
    local output_file="$2"
    local -n template_vars=$3

    local content
    content=$(cat "$template_file")

    # Replace all placeholders using bash parameter expansion
    # This handles multi-line values correctly
    for key in "${!template_vars[@]}"; do
        local value="${template_vars[$key]}"
        content="${content//"{{$key}}"/$value}"
    done

    # Handle remaining unfilled placeholders
    # Delete table rows containing unresolved placeholders
    content=$(echo "$content" | sed '/^|.*{{[A-Z_]*}}.*|$/d')

    # Delete bullet points with only unresolved placeholders
    content=$(echo "$content" | sed '/^[[:space:]]*[-*][[:space:]]*{{[A-Z_][A-Z0-9_]*}}[[:space:]]*$/d')

    # Delete lines that are ONLY a placeholder (prevents blank lines in tables)
    content=$(echo "$content" | sed '/^{{[A-Z_][A-Z0-9_]*}}$/d')
    # Also handle placeholders with leading/trailing whitespace
    content=$(echo "$content" | sed '/^[[:space:]]*{{[A-Z_][A-Z0-9_]*}}[[:space:]]*$/d')

    # Remove any remaining inline placeholders (better than "(not configured)" noise)
    content=$(echo "$content" | sed 's/{{[A-Z_][A-Z0-9_]*}}//g')

    # Remove empty lines that appear after table rows but before non-table content
    # This fixes broken tables when placeholders were replaced with empty content
    content=$(echo "$content" | awk '
        /^\|.*\|$/ {
            # Print any pending empty lines first if we are continuing a table
            if (prev_was_table && pending_empty) {
                # Skip the pending empty - it was between table rows with no data
            }
            print
            prev_was_table=1
            pending_empty=0
            next
        }
        /^[[:space:]]*$/ {
            if (prev_was_table) {
                pending_empty=1  # Hold empty line, might be inside table
            } else {
                print  # Normal empty line outside table
            }
            next
        }
        {
            # Non-table line - do not print pending empty from table section
            pending_empty=0
            prev_was_table=0
            print
        }
    ')

    # Clean up multiple consecutive empty lines
    content=$(echo "$content" | cat -s)

    # Write output
    printf '%s\n' "$content" > "$output_file"
}

# Validate rendered content has no remaining placeholders
# Returns 0 if valid, 1 if placeholders found
validate_no_placeholders() {
    local file="$1"
    local strict="${2:-false}"

    if grep -qE '\{\{[A-Z][A-Z0-9_]*\}\}' "$file"; then
        local placeholders
        placeholders=$(grep -oE '\{\{[A-Z][A-Z0-9_]*\}\}' "$file" | sort -u | tr '\n' ' ')

        if [ "$strict" = "true" ]; then
            echo "[ERROR] Unresolved placeholders in $file: $placeholders" >&2
            return 1
        else
            echo "[WARN] Unresolved placeholders in $file: $placeholders" >&2
            return 0
        fi
    fi
    return 0
}

# Generate timestamp
get_timestamp() {
    date +%Y-%m-%d
}

# Build scope index for root template
build_scope_index() {
    local scopes_json="$1"
    local index=""

    local count=$(echo "$scopes_json" | jq '.scopes | length')
    if [ "$count" -eq 0 ]; then
        echo "- (No scoped AGENTS.md files yet)"
        return
    fi

    while read -r scope; do
        local path=$(echo "$scope" | jq -r '.path')
        local type=$(echo "$scope" | jq -r '.type')
        local description=$(get_scope_description "$type")

        index="$index- \`./$path/AGENTS.md\` — $description\n"
    done < <(echo "$scopes_json" | jq -c '.scopes[]')

    echo -e "$index"
}

# Get description for scope type
get_scope_description() {
    local type="$1"

    case "$type" in
        "backend-go") echo "Backend services (Go)" ;;
        "backend-php") echo "Backend services (PHP)" ;;
        "backend-typescript") echo "Backend services (TypeScript/Node.js)" ;;
        "backend-python") echo "Backend services (Python)" ;;
        "frontend-typescript") echo "Frontend application (TypeScript/React/Vue)" ;;
        "cli") echo "Command-line interface tools and entry points" ;;
        "testing") echo "Test suites, fixtures, and testing utilities" ;;
        "documentation") echo "Project documentation, guides, and reference materials" ;;
        "examples") echo "Example applications, usage patterns, and sample code" ;;
        "resources") echo "Static resources, assets, templates, and configuration files" ;;
        "docker") echo "Container/Docker configuration for building and deploying images" ;;
        "claude-code-skill") echo "Claude Code skill/plugin providing AI agent capabilities" ;;
        "typo3") echo "TYPO3 extension following TYPO3 CGL and PSR-12" ;;
        "oro") echo "Oro bundle following Oro Architecture and Symfony best practices" ;;
        *) echo "$type" ;;
    esac
}

# Get language-specific conventions text
get_language_conventions() {
    local language="$1"
    local version="$2"

    case "$language" in
        "go")
            echo "- Follow Go $version conventions and idioms"
            ;;
        "php")
            echo "- Follow PSR-12 coding standards and PHP $version features"
            ;;
        "typescript")
            echo "- Use TypeScript strict mode with proper type annotations"
            ;;
        "python")
            echo "- Follow PEP 8 style guide and Python $version features"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Format command with fallback text
format_command() {
    local cmd="$1"
    local fallback="$2"

    if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
        echo "$cmd"
    else
        echo "$fallback"
    fi
}

# Check if file has generated section markers
has_generated_markers() {
    local file="$1"
    grep -q 'AGENTS-GENERATED:START' "$file" 2>/dev/null
}

# Extract section names from file
get_section_names() {
    local file="$1"
    grep -oE 'AGENTS-GENERATED:START [a-z0-9-]+' "$file" 2>/dev/null | sed 's/AGENTS-GENERATED:START //' | sort -u
}

# Extract content between markers for a section
get_section_content() {
    local file="$1"
    local section="$2"

    sed -n "/AGENTS-GENERATED:START $section/,/AGENTS-GENERATED:END $section/p" "$file" 2>/dev/null | \
        sed '1d;$d'  # Remove the marker lines themselves
}

# Update only generated sections in an existing file
# Preserves all content outside markers
update_generated_sections() {
    local template_file="$1"
    local existing_file="$2"
    local output_file="$3"
    local -n update_vars=$4

    # First render the template to get new content
    local temp_rendered
    temp_rendered=$(mktemp)
    render_template "$template_file" "$temp_rendered" update_vars

    # If existing file doesn't have markers, just overwrite
    if ! has_generated_markers "$existing_file"; then
        mv "$temp_rendered" "$output_file"
        return 0
    fi

    # Get all section names from the rendered template
    local sections
    sections=$(get_section_names "$temp_rendered")

    # Start with the existing file content
    local result
    result=$(cat "$existing_file")

    # Replace each generated section
    for section in $sections; do
        local new_content
        new_content=$(get_section_content "$temp_rendered" "$section")

        if [ -n "$new_content" ]; then
            # Create a sed-safe version of the new content
            # Use awk for multi-line replacement
            result=$(echo "$result" | awk -v section="$section" -v newcontent="$new_content" '
                BEGIN { in_section = 0 }
                /AGENTS-GENERATED:START / && $0 ~ section {
                    print
                    in_section = 1
                    next
                }
                /AGENTS-GENERATED:END / && $0 ~ section {
                    print newcontent
                    print
                    in_section = 0
                    next
                }
                !in_section { print }
            ')
        fi
    done

    # Update timestamp
    local today
    today=$(date +%Y-%m-%d)
    result=$(echo "$result" | sed "s/Last updated: [0-9-]*/Last updated: $today/")

    # Write result
    echo "$result" > "$output_file"

    # Clean up
    rm -f "$temp_rendered"
}

# Render template - respects update mode
# If update_mode=true and file exists with markers, only updates generated sections
render_template_smart() {
    local template_file="$1"
    local output_file="$2"
    local -n smart_vars=$3
    local update_mode="${4:-false}"

    if [ "$update_mode" = "true" ] && [ -f "$output_file" ] && has_generated_markers "$output_file"; then
        # Update mode - preserve human edits
        update_generated_sections "$template_file" "$output_file" "$output_file" smart_vars
    else
        # Normal mode - full render
        render_template "$template_file" "$output_file" smart_vars
    fi
}
