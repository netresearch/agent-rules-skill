#!/usr/bin/env bash
# Extract module boundary rules from architecture test frameworks
# Supports: phpat, deptrac, Go conventions, ESLint import rules, golangci-lint depguard
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Collect results into arrays/objects, then assemble JSON at the end
FRAMEWORK=""
RULES="[]"
INTERNAL_PACKAGES="[]"
LAYER_DEFINITIONS="{}"

# --- phpat (PHP Architecture Tester) ---
parse_phpat() {
    local found=false

    # Find phpat test files
    local phpat_files=()
    for dir in tests/Architecture Tests/Architecture tests/architecture; do
        if [ -d "$dir" ]; then
            while IFS= read -r f; do
                phpat_files+=("$f")
            done < <(find "$dir" -name "*.php" -type f 2>/dev/null)
        fi
    done

    # Also check phpat config files
    local phpat_config=""
    for f in phpat.yaml phpat.neon phpat.yml; do
        [ -f "$f" ] && phpat_config="$f" && break
    done

    if [ ${#phpat_files[@]} -eq 0 ] && [ -z "$phpat_config" ]; then
        return 1
    fi

    found=true
    FRAMEWORK="phpat"
    local rules_arr="[]"

    # Parse PHP test files for rule patterns
    for file in "${phpat_files[@]}"; do
        # Match shouldNotDependOn patterns
        # e.g. classesThat(Selector::haveClassName('*Controller*'))->shouldNotDependOn(Selector::haveClassName('*Repository*'))
        while IFS= read -r line; do
            local source=""
            local target=""

            # Extract source from classesThat / classesInNamespace / haveClassName
            if [[ "$line" =~ classesThat\(.*haveClassName\([\'\"]\*?([A-Za-z]+)\*?[\'\"]\) ]]; then
                source="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ classesInNamespace\([\'\"](.*)[\'\"]\) ]]; then
                source="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ classesThat\(.*classesInNamespace\([\'\"](.*)[\'\"]\) ]]; then
                source="${BASH_REMATCH[1]}"
            fi

            # Determine rule type and target
            local rule_type=""
            if [[ "$line" =~ shouldNotDependOn ]]; then
                rule_type="must_not_depend"
                if [[ "$line" =~ shouldNotDependOn\(.*haveClassName\([\'\"]\*?([A-Za-z]+)\*?[\'\"]\) ]]; then
                    target="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ shouldNotDependOn\(.*classesInNamespace\([\'\"](.*)[\'\"]\) ]]; then
                    target="${BASH_REMATCH[1]}"
                fi
            elif [[ "$line" =~ shouldOnlyDependOn ]]; then
                rule_type="must_only_depend"
                if [[ "$line" =~ shouldOnlyDependOn\(.*haveClassName\([\'\"]\*?([A-Za-z]+)\*?[\'\"]\) ]]; then
                    target="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ shouldOnlyDependOn\(.*classesInNamespace\([\'\"](.*)[\'\"]\) ]]; then
                    target="${BASH_REMATCH[1]}"
                fi
            elif [[ "$line" =~ mustNotDependOn ]]; then
                rule_type="must_not_depend"
                if [[ "$line" =~ mustNotDependOn\(.*haveClassName\([\'\"]\*?([A-Za-z]+)\*?[\'\"]\) ]]; then
                    target="${BASH_REMATCH[1]}"
                fi
            fi

            if [ -n "$source" ] && [ -n "$target" ] && [ -n "$rule_type" ]; then
                rules_arr=$(echo "$rules_arr" | jq \
                    --arg s "$source" --arg t "$target" --arg rt "$rule_type" \
                    '. + [{"source": $s, "target": $t, "type": $rt}]')
            fi
        done < <(grep -E 'shouldNotDependOn|shouldOnlyDependOn|mustNotDependOn' "$file" 2>/dev/null || true)

        # Match canOnlyBeAccessedBy patterns
        while IFS= read -r line; do
            local target=""
            local source=""

            if [[ "$line" =~ haveClassName\([\'\"]\*?([A-Za-z]+)\*?[\'\"]\).*canOnlyBeAccessedBy ]]; then
                target="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ canOnlyBeAccessedBy\(.*haveClassName\([\'\"]\*?([A-Za-z]+)\*?[\'\"]\) ]]; then
                source="${BASH_REMATCH[1]}"
            fi

            if [ -n "$source" ] && [ -n "$target" ]; then
                rules_arr=$(echo "$rules_arr" | jq \
                    --arg s "$source" --arg t "$target" \
                    '. + [{"source": $s, "target": $t, "type": "can_only_access"}]')
            fi
        done < <(grep -E 'canOnlyBeAccessedBy' "$file" 2>/dev/null || true)
    done

    # Parse phpat YAML/NEON config
    if [ -n "$phpat_config" ]; then
        # Extract rules from YAML config (simplified parsing)
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.+)[[:space:]]+should_not_depend_on[[:space:]]+(.+) ]]; then
                rules_arr=$(echo "$rules_arr" | jq \
                    --arg s "${BASH_REMATCH[1]}" --arg t "${BASH_REMATCH[2]}" \
                    '. + [{"source": $s, "target": $t, "type": "must_not_depend"}]')
            fi
        done < "$phpat_config"
    fi

    RULES="$rules_arr"
    return 0
}

# --- deptrac (PHP dependency checker) ---
parse_deptrac() {
    local config_file=""
    for f in deptrac.yaml depfile.yaml deptrac.yml depfile.yml; do
        [ -f "$f" ] && config_file="$f" && break
    done

    [ -z "$config_file" ] && return 1

    FRAMEWORK="deptrac"
    local rules_arr="[]"
    local layers_obj="{}"

    # Parse layer definitions
    local in_layers=false
    local current_layer=""
    local layer_collectors=()
    while IFS= read -r line; do
        # Detect layers section
        if [[ "$line" =~ ^layers: ]]; then
            in_layers=true
            continue
        fi

        # End of layers section (next top-level key)
        if $in_layers && [[ "$line" =~ ^[a-z] && ! "$line" =~ ^[[:space:]] ]]; then
            in_layers=false
            # Save last layer
            if [ -n "$current_layer" ] && [ ${#layer_collectors[@]} -gt 0 ]; then
                local collectors_json
                collectors_json=$(printf '%s\n' "${layer_collectors[@]}" | jq -R . | jq -s .)
                layers_obj=$(echo "$layers_obj" | jq --arg l "$current_layer" --argjson c "$collectors_json" '. + {($l): $c}')
            fi
            continue
        fi

        if $in_layers; then
            # Layer name
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+) ]]; then
                # Save previous layer
                if [ -n "$current_layer" ] && [ ${#layer_collectors[@]} -gt 0 ]; then
                    local collectors_json
                    collectors_json=$(printf '%s\n' "${layer_collectors[@]}" | jq -R . | jq -s .)
                    layers_obj=$(echo "$layers_obj" | jq --arg l "$current_layer" --argjson c "$collectors_json" '. + {($l): $c}')
                fi
                current_layer=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                layer_collectors=()
            fi
            # Collector value (directory or className)
            if [[ "$line" =~ value:[[:space:]]*(.+) ]]; then
                layer_collectors+=("$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
            fi
        fi
    done < "$config_file"

    # Save last layer
    if [ -n "$current_layer" ] && [ ${#layer_collectors[@]} -gt 0 ]; then
        local collectors_json
        collectors_json=$(printf '%s\n' "${layer_collectors[@]}" | jq -R . | jq -s .)
        layers_obj=$(echo "$layers_obj" | jq --arg l "$current_layer" --argjson c "$collectors_json" '. + {($l): $c}')
    fi

    LAYER_DEFINITIONS="$layers_obj"

    # Parse ruleset (which layers can depend on which)
    local in_ruleset=false
    local current_source=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^ruleset: ]]; then
            in_ruleset=true
            continue
        fi

        if $in_ruleset && [[ "$line" =~ ^[a-z] && ! "$line" =~ ^[[:space:]] ]]; then
            in_ruleset=false
            continue
        fi

        if $in_ruleset; then
            # Source layer
            if [[ "$line" =~ ^[[:space:]]+([A-Za-z_]+): ]]; then
                current_source="${BASH_REMATCH[1]}"
            fi
            # Allowed target
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*([A-Za-z_]+) ]] && [ -n "$current_source" ]; then
                local target="${BASH_REMATCH[1]}"
                if [ "$target" != "$current_source" ]; then
                    rules_arr=$(echo "$rules_arr" | jq \
                        --arg s "$current_source" --arg t "$target" \
                        '. + [{"source": $s, "target": $t, "type": "may_depend"}]')
                fi
            fi
        fi
    done < "$config_file"

    RULES="$rules_arr"
    return 0
}

# --- Go architecture conventions ---
parse_go_architecture() {
    # Only for Go projects
    [ ! -f "go.mod" ] && return 1

    local found_anything=false
    local internal_pkgs="[]"
    local rules_arr="[]"

    # Check for internal/ directories (Go compiler-enforced boundaries)
    if [ -d "internal" ]; then
        found_anything=true
        while IFS= read -r dir; do
            local rel_path="${dir#./}"
            internal_pkgs=$(echo "$internal_pkgs" | jq --arg p "$rel_path" '. + [$p]')
        done < <(find ./internal -mindepth 1 -maxdepth 2 -type d 2>/dev/null)

        # If no subdirs, just list internal itself
        if [ "$(echo "$internal_pkgs" | jq 'length')" = "0" ]; then
            internal_pkgs='["internal"]'
        fi
    fi

    # Check for depguard rules in golangci-lint config
    local golangci_config=""
    for f in .golangci.yml .golangci.yaml; do
        [ -f "$f" ] && golangci_config="$f" && break
    done

    if [ -n "$golangci_config" ]; then
        # Parse depguard deny rules
        local in_depguard=false
        local in_deny=false
        local current_pkg=""
        local current_desc=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*depguard: ]]; then
                in_depguard=true
                continue
            fi

            # Exit depguard section on next top-level setting
            if $in_depguard && [[ "$line" =~ ^[[:space:]]{4}[a-z] && ! "$line" =~ ^[[:space:]]{6} && ! "$line" =~ deny && ! "$line" =~ rules && ! "$line" =~ main ]]; then
                in_depguard=false
                in_deny=false
                continue
            fi

            if $in_depguard && [[ "$line" =~ deny: ]]; then
                in_deny=true
                continue
            fi

            if $in_depguard && $in_deny; then
                if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*pkg:[[:space:]]*(.+) ]]; then
                    current_pkg=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    found_anything=true
                fi
                if [[ "$line" =~ desc:[[:space:]]*(.+) ]]; then
                    current_desc=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [ -n "$current_pkg" ]; then
                        rules_arr=$(echo "$rules_arr" | jq \
                            --arg s "*" --arg t "$current_pkg" --arg rt "must_not_depend" --arg d "$current_desc" \
                            '. + [{"source": $s, "target": $t, "type": $rt, "reason": $d}]')
                        current_pkg=""
                        current_desc=""
                    fi
                fi
            fi
        done < "$golangci_config"

        # Parse gomodguard if present
        local in_gomodguard=false
        local in_blocked=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*gomodguard: ]]; then
                in_gomodguard=true
                continue
            fi

            if $in_gomodguard && [[ "$line" =~ blocked: ]]; then
                in_blocked=true
                continue
            fi

            if $in_gomodguard && $in_blocked; then
                if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*pkg:[[:space:]]*(.+) ]]; then
                    local blocked_pkg
                    blocked_pkg=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    rules_arr=$(echo "$rules_arr" | jq \
                        --arg s "*" --arg t "$blocked_pkg" --arg rt "must_not_depend" \
                        '. + [{"source": $s, "target": $t, "type": $rt}]')
                    found_anything=true
                fi
            fi

            # Exit gomodguard on next top-level setting
            if $in_gomodguard && [[ "$line" =~ ^[[:space:]]{4}[a-z] && ! "$line" =~ blocked && ! "$line" =~ modules && ! "$line" =~ versions ]]; then
                in_gomodguard=false
                in_blocked=false
            fi
        done < "$golangci_config"

        # Parse forbidigo patterns (banned function calls)
        local in_forbidigo=false
        local in_forbid=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*forbidigo: ]]; then
                in_forbidigo=true
                continue
            fi
            if $in_forbidigo && [[ "$line" =~ forbid: ]]; then
                in_forbid=true
                continue
            fi
            if $in_forbidigo && $in_forbid; then
                if [[ "$line" =~ pattern:[[:space:]]*(.+) ]]; then
                    local pattern
                    pattern=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[\^$]//g')
                    rules_arr=$(echo "$rules_arr" | jq \
                        --arg s "*" --arg t "$pattern" --arg rt "forbidden_call" \
                        '. + [{"source": $s, "target": $t, "type": $rt}]')
                    found_anything=true
                fi
            fi
            if $in_forbidigo && [[ "$line" =~ ^[[:space:]]{4}[a-z] && ! "$line" =~ forbid && ! "$line" =~ pattern ]]; then
                in_forbidigo=false
                in_forbid=false
            fi
        done < "$golangci_config"
    fi

    # Detect directory-based architecture patterns
    local arch_pattern=""
    if [ -d "ports" ] && [ -d "adapters" ]; then
        arch_pattern="hexagonal"
        found_anything=true
    elif [ -d "domain" ] && [ -d "infrastructure" ]; then
        arch_pattern="clean-architecture"
        found_anything=true
    elif [ -d "cmd" ] && [ -d "pkg" ]; then
        arch_pattern="go-standard-layout"
        found_anything=true
    fi

    if [ -n "$arch_pattern" ]; then
        LAYER_DEFINITIONS=$(echo "$LAYER_DEFINITIONS" | jq --arg p "$arch_pattern" '. + {"architecture_pattern": $p}')
    fi

    $found_anything || return 1

    [ -z "$FRAMEWORK" ] && FRAMEWORK="go-conventions"
    RULES="$rules_arr"
    INTERNAL_PACKAGES="$internal_pkgs"
    return 0
}

# --- ESLint import restrictions ---
parse_eslint_imports() {
    local config_file=""
    for f in eslint.config.js eslint.config.mjs .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml .eslintrc; do
        [ -f "$f" ] && config_file="$f" && break
    done

    [ -z "$config_file" ] && return 1

    local rules_arr="[]"
    local found=false

    # For JSON eslint configs, extract import/no-restricted-paths or no-restricted-imports
    if [[ "$config_file" == *.json ]] || [[ "$config_file" == .eslintrc ]]; then
        # Check for no-restricted-imports
        local restricted
        restricted=$(jq -r '.rules["no-restricted-imports"] // .rules["import/no-restricted-paths"] // empty' "$config_file" 2>/dev/null || echo "")
        if [ -n "$restricted" ] && [ "$restricted" != "null" ]; then
            found=true
            # Extract patterns from the restriction config
            local patterns
            patterns=$(echo "$restricted" | jq -r '
                if type == "array" then
                    .[1].patterns // .[1].zones // []
                elif type == "object" then
                    .patterns // .zones // []
                else [] end | .[] |
                if type == "object" then
                    "from=" + (.from // .target // "?") + " import=" + (.import // .message // "restricted")
                elif type == "string" then
                    "pattern=" + .
                else empty end
            ' 2>/dev/null || echo "")

            while IFS= read -r pat; do
                [ -z "$pat" ] && continue
                rules_arr=$(echo "$rules_arr" | jq \
                    --arg desc "$pat" \
                    '. + [{"source": "*", "target": $desc, "type": "import_restriction"}]')
            done <<< "$patterns"
        fi
    fi

    # For JS configs, do a best-effort grep for no-restricted-imports
    if [[ "$config_file" == *.js ]] || [[ "$config_file" == *.mjs ]] || [[ "$config_file" == *.cjs ]]; then
        if grep -q 'no-restricted-imports\|import/no-restricted-paths' "$config_file" 2>/dev/null; then
            found=true
            # Extract string patterns from the config (simplified)
            while IFS= read -r pattern; do
                [ -z "$pattern" ] && continue
                local clean_pattern
                clean_pattern=$(echo "$pattern" | sed "s/['\"]//g;s/,//g;s/^[[:space:]]*//" | head -c 100)
                [ -n "$clean_pattern" ] && rules_arr=$(echo "$rules_arr" | jq \
                    --arg t "$clean_pattern" \
                    '. + [{"source": "*", "target": $t, "type": "import_restriction"}]')
            done < <(grep -A1 'no-restricted-imports\|import/no-restricted-paths' "$config_file" 2>/dev/null | grep -oE "'[^']+'" | head -10)
        fi
    fi

    $found || return 1

    [ -z "$FRAMEWORK" ] && FRAMEWORK="eslint-imports"
    RULES="$rules_arr"
    return 0
}

# --- Detect architecture from directory conventions ---
parse_directory_architecture() {
    local rules_arr="[]"
    local layers_obj="{}"
    local found=false

    # Hexagonal / Ports & Adapters
    if [ -d "ports" ] && [ -d "adapters" ]; then
        found=true
        layers_obj=$(echo "$layers_obj" | jq '. + {"architecture_pattern": "hexagonal"}')
        rules_arr=$(echo "$rules_arr" | jq '. + [
            {"source": "adapters", "target": "ports", "type": "may_depend"},
            {"source": "ports", "target": "adapters", "type": "must_not_depend"}
        ]')
    fi

    # Clean Architecture
    if [ -d "domain" ] && { [ -d "infrastructure" ] || [ -d "application" ]; }; then
        found=true
        layers_obj=$(echo "$layers_obj" | jq '. + {"architecture_pattern": "clean-architecture"}')
        rules_arr=$(echo "$rules_arr" | jq '. + [
            {"source": "domain", "target": "infrastructure", "type": "must_not_depend"},
            {"source": "domain", "target": "application", "type": "must_not_depend"}
        ]')
    fi

    # Onion Architecture
    if [ -d "Domain" ] && [ -d "Application" ] && [ -d "Infrastructure" ]; then
        found=true
        layers_obj=$(echo "$layers_obj" | jq '. + {"architecture_pattern": "onion"}')
        rules_arr=$(echo "$rules_arr" | jq '. + [
            {"source": "Domain", "target": "Infrastructure", "type": "must_not_depend"},
            {"source": "Domain", "target": "Application", "type": "must_not_depend"},
            {"source": "Application", "target": "Infrastructure", "type": "must_not_depend"}
        ]')
    fi

    $found || return 1

    [ -z "$FRAMEWORK" ] && FRAMEWORK="directory-conventions"
    RULES="$rules_arr"
    LAYER_DEFINITIONS="$layers_obj"
    return 0
}

# --- Main: try each parser in priority order ---
# Try specific frameworks first, then fall back to conventions
parse_phpat || true
if [ "$FRAMEWORK" = "" ]; then
    parse_deptrac || true
fi
if [ "$FRAMEWORK" = "" ]; then
    parse_go_architecture || true
fi
if [ "$FRAMEWORK" = "" ]; then
    parse_eslint_imports || true
fi
if [ "$FRAMEWORK" = "" ]; then
    parse_directory_architecture || true
fi

# Output final JSON
jq -n \
    --arg framework "$FRAMEWORK" \
    --argjson rules "$RULES" \
    --argjson internal_packages "$INTERNAL_PACKAGES" \
    --argjson layer_definitions "$LAYER_DEFINITIONS" \
    '{
        framework: $framework,
        rules: $rules,
        internal_packages: $internal_packages,
        layer_definitions: $layer_definitions
    } | with_entries(select(
        .value != "" and .value != [] and .value != {} and .value != null
    ))'
