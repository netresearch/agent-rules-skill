#!/usr/bin/env bash
# Extract Architectural Decision Records (ADRs) from common locations
# Returns JSON with ADR metadata for AGENTS.md generation
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Common ADR directory locations
ADR_DIRS=(
    "docs/adr" "docs/adrs" "docs/decisions" "docs/architecture/decisions"
    "Documentation/ADR" "Documentation/Decisions"
    "adr" "ADR"
)

# Find the first existing ADR directory
ADR_DIR=""
for dir in "${ADR_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        ADR_DIR="$dir"
        break
    fi
done

# If no ADR directory found, check for standalone ADR files in docs/
if [ -z "$ADR_DIR" ]; then
    # Look for ADR-named files anywhere in docs/
    if [ -d "docs" ]; then
        adr_file=$(find docs -maxdepth 2 -type f \( -name "ADR-*.md" -o -name "adr-*.md" -o -name "*-adr-*.md" -o -name "ADR*.rst" \) 2>/dev/null | head -1)
        if [ -n "$adr_file" ]; then
            ADR_DIR=$(dirname "$adr_file")
        fi
    fi
fi

# No ADRs found
if [ -z "$ADR_DIR" ]; then
    jq -n '{adr_count: 0, adr_directory: null, adrs: []}'
    exit 0
fi

# Collect ADR files
ADR_FILES=()
while IFS= read -r -d '' file; do
    ADR_FILES+=("$file")
done < <(find "$ADR_DIR" -maxdepth 1 -type f \( -name "ADR-*.md" -o -name "adr-*.md" -o -name "*-adr-*.md" -o -name "ADR*.rst" -o -name "adr*.rst" -o -name "*.md" \) -print0 2>/dev/null | sort -z)

# Deduplicate and filter — only include files that look like ADRs
FILTERED_FILES=()
for file in "${ADR_FILES[@]}"; do
    basename=$(basename "$file")
    # Accept files with ADR in the name, or numbered files (common ADR pattern like 0001-*.md)
    if [[ "$basename" =~ ^[Aa][Dd][Rr][-_] ]] || [[ "$basename" =~ ^[0-9]{3,4}[-_] ]] || [[ "$basename" =~ -[Aa][Dd][Rr][-_] ]]; then
        FILTERED_FILES+=("$file")
    fi
done

if [ ${#FILTERED_FILES[@]} -eq 0 ]; then
    jq -n --arg dir "$ADR_DIR" '{adr_count: 0, adr_directory: $dir, adrs: []}'
    exit 0
fi

# Extract metadata from each ADR
ADRS_JSON="[]"
for file in "${FILTERED_FILES[@]}"; do
    filename=$(basename "$file")

    # Read file content
    content=$(cat "$file" 2>/dev/null) || continue
    [ -z "$content" ] && continue

    # Extract title: first heading (# or ##)
    title=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^#{1,2}[[:space:]]+(.*) ]]; then
            title="${BASH_REMATCH[1]}"
            # Strip leading ADR number prefix like "ADR-001:" or "ADR 1:"
            title=$(echo "$title" | sed -E 's/^ADR[-_ ]?[0-9]+:?\s*//i')
            break
        fi
    done <<< "$content"
    [ -z "$title" ] && title="$filename"

    # Extract status: look for "Status:" line or **Status** pattern
    status="Unknown"
    while IFS= read -r line; do
        # Match patterns like "## Status", then read next non-empty line
        if [[ "$line" =~ ^#{1,3}[[:space:]]+[Ss]tatus ]]; then
            # Read lines after the status heading to find the actual status
            found_heading=false
            while IFS= read -r sline; do
                if [ "$found_heading" = false ]; then
                    found_heading=true
                    continue
                fi
                # Skip empty lines
                [[ -z "${sline// /}" ]] && continue
                # Extract the status value
                sline=$(echo "$sline" | sed -E 's/^\*\*//;s/\*\*.*$//;s/^- //;s/^`//;s/`$//')
                if [[ "$sline" =~ ^(Accepted|Proposed|Deprecated|Superseded|Rejected|Draft|Approved) ]]; then
                    status="${BASH_REMATCH[1]}"
                fi
                break
            done
            break
        fi
        # Match inline patterns: "**Status**: Accepted", "**Status:** Accepted", "Status: Accepted"
        if [[ "$line" =~ \*?\*?[Ss]tatus\*?\*?:?[[:space:]]*(Accepted|Proposed|Deprecated|Superseded|Rejected|Draft|Approved) ]]; then
            status="${BASH_REMATCH[1]}"
            break
        fi
    done <<< "$content"

    # Extract summary: first paragraph after Context heading, or first paragraph after title
    summary=""
    # Try "Context" section first
    in_context=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^#{1,3}[[:space:]]+(Context|Background) ]]; then
            in_context=true
            continue
        fi
        if [ "$in_context" = true ]; then
            [[ -z "${line// /}" ]] && continue
            # Stop at next heading
            [[ "$line" =~ ^# ]] && break
            # Take the first non-empty, non-heading line
            summary=$(echo "$line" | sed -E 's/^\*\*//;s/\*\*$//;s/^- //')
            # Truncate to ~120 chars
            if [ ${#summary} -gt 120 ]; then
                summary="${summary:0:117}..."
            fi
            break
        fi
    done <<< "$content"

    # Fallback: first paragraph after title
    if [ -z "$summary" ]; then
        past_title=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^# ]] && [ "$past_title" = false ]; then
                past_title=true
                continue
            fi
            if [ "$past_title" = true ]; then
                [[ -z "${line// /}" ]] && continue
                [[ "$line" =~ ^# ]] && break
                [[ "$line" =~ ^[*-][[:space:]] ]] && continue
                summary=$(echo "$line" | sed -E 's/^\*\*//;s/\*\*$//;s/^- //')
                if [ ${#summary} -gt 120 ]; then
                    summary="${summary:0:117}..."
                fi
                break
            fi
        done <<< "$content"
    fi

    # Extract decision: look for "Decision" section
    decision=""
    in_decision=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^#{1,3}[[:space:]]+(Decision|Resolution) ]]; then
            in_decision=true
            continue
        fi
        if [ "$in_decision" = true ]; then
            [[ -z "${line// /}" ]] && continue
            [[ "$line" =~ ^# ]] && break
            [[ "$line" =~ ^\`\`\` ]] && break
            decision=$(echo "$line" | sed -E 's/^\*\*//;s/\*\*$//;s/^- //')
            if [ ${#decision} -gt 150 ]; then
                decision="${decision:0:147}..."
            fi
            break
        fi
    done <<< "$content"

    # Build JSON entry
    ADRS_JSON=$(echo "$ADRS_JSON" | jq \
        --arg file "$filename" \
        --arg title "$title" \
        --arg status "$status" \
        --arg summary "$summary" \
        --arg decision "$decision" \
        '. + [{file: $file, title: $title, status: $status, summary: $summary, decision: $decision}]')
done

# Output final JSON
ADR_COUNT=$(echo "$ADRS_JSON" | jq 'length')
jq -n \
    --argjson count "$ADR_COUNT" \
    --arg dir "$ADR_DIR" \
    --argjson adrs "$ADRS_JSON" \
    '{adr_count: $count, adr_directory: $dir, adrs: $adrs}'
