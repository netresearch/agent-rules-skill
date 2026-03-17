#!/usr/bin/env bash
# Extract CI workflow rules that agents need to follow:
# version matrices, quality gates, coverage thresholds, security workflows, linter configs, pinned actions
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Collect unique values into a bash array via a nameref
# Usage: collect_unique arr_name "value"
collect_unique() {
    local -n _arr="$1"
    local val="$2"
    for existing in "${_arr[@]+"${_arr[@]}"}"; do
        [[ "$existing" == "$val" ]] && return
    done
    _arr+=("$val")
}

# Turn a bash array into a JSON array via jq
arr_to_json() {
    local -n _a="$1"
    if [[ ${#_a[@]} -eq 0 ]]; then
        echo "[]"
    else
        printf '%s\n' "${_a[@]}" | jq -R . | jq -s .
    fi
}

# Try yq first, fall back to grep/sed parsing
has_yq() { command -v yq &>/dev/null; }

# ---------------------------------------------------------------------------
# GitHub Actions parsing
# ---------------------------------------------------------------------------
parse_github_actions() {
    local wf_dir=".github/workflows"
    [[ -d "$wf_dir" ]] || { echo "{}"; return; }

    local php_versions=()
    local node_versions=()
    local go_version=""
    local python_versions=()
    local quality_gates=()
    local required_checks=()
    local linter_configs=()
    local security_workflows=()
    local coverage_threshold=""
    local pinned_actions=true
    local permissions=()

    for wf in "$wf_dir"/*.yml "$wf_dir"/*.yaml; do
        [[ -f "$wf" ]] || continue
        local basename
        basename=$(basename "$wf")

        # --- Security workflows ---
        case "$basename" in
            codeql*|scorecard*|dependency-review*|trivy*|snyk*|semgrep*)
                collect_unique security_workflows "$basename"
                ;;
        esac

        local content
        content=$(<"$wf")

        # --- Pinned actions check ---
        # SHA-pinned: uses: foo/bar@<40-hex-chars>  (may have # vX.Y.Z comment)
        # NOT pinned: uses: foo/bar@v1.2.3 or @main
        # Exclude reusable workflow calls (.github/workflows/) — those often can't be SHA-pinned
        # Strategy: find all uses: lines, exclude reusable workflows, then check if any lack a 40-char hex SHA
        local unpinned_count
        unpinned_count=$(echo "$content" \
            | grep -E '^[[:space:]]*uses:' \
            | grep -vE '\.github/workflows/' \
            | { grep -vE '@[0-9a-f]{40}' || true; } \
            | wc -l)
        if [[ "$unpinned_count" -gt 0 ]]; then
            pinned_actions=false
        fi

        # --- Permissions block ---
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]+(contents|pull-requests|security-events|id-token|packages|actions|checks|issues|statuses|deployments):[[:space:]]+(read|write|none) ]]; then
                local perm="${BASH_REMATCH[1]}: ${BASH_REMATCH[2]}"
                collect_unique permissions "$perm"
            fi
        done <<< "$content"

        # --- PHP version matrix ---
        # Matches patterns like: php: ['8.2', '8.3'] or php-version: ['8.2']
        # Also matrix entries like php: [8.2, 8.3]
        while IFS= read -r ver; do
            ver=$(echo "$ver" | tr -d "\"' ")
            [[ -n "$ver" ]] && collect_unique php_versions "$ver"
        done < <(echo "$content" | grep -E '(php|php-version|php_version).*\[' | grep -oE "[0-9]+\.[0-9]+" || true)

        # Single php-version value
        while IFS= read -r ver; do
            ver=$(echo "$ver" | tr -d "\"' ")
            [[ -n "$ver" ]] && collect_unique php_versions "$ver"
        done < <(echo "$content" | grep -E 'php-version:[[:space:]]*[0-9]' | grep -oE "[0-9]+\.[0-9]+" || true)

        # --- Node version matrix ---
        while IFS= read -r ver; do
            ver=$(echo "$ver" | tr -d "\"' ")
            [[ -n "$ver" ]] && collect_unique node_versions "$ver"
        done < <(echo "$content" | grep -E '(node|node-version|node_version).*\[' | grep -oE "[0-9]+" || true)

        while IFS= read -r ver; do
            ver=$(echo "$ver" | tr -d "\"' ")
            [[ -n "$ver" ]] && collect_unique node_versions "$ver"
        done < <(echo "$content" | grep -E 'node-version:[[:space:]]*[0-9]' | grep -oE "[0-9]+" || true)

        # --- Go version ---
        # go-version-file: go.mod  →  read from go.mod
        if echo "$content" | grep -qE 'go-version-file:'; then
            if [[ -f "go.mod" ]]; then
                local gv
                gv=$(grep -E '^go ' go.mod | head -1 | awk '{print $2}')
                [[ -n "$gv" ]] && go_version="$gv"
            fi
        fi
        # Explicit go-version: 1.x
        while IFS= read -r ver; do
            ver=$(echo "$ver" | tr -d "\"' ")
            [[ -n "$ver" ]] && go_version="$ver"
        done < <(echo "$content" | grep -E 'go-version:[[:space:]]*[0-9]' | grep -oE "[0-9]+\.[0-9]+[0-9.]*" | head -1 || true)

        # --- Python version matrix ---
        while IFS= read -r ver; do
            ver=$(echo "$ver" | tr -d "\"' ")
            [[ -n "$ver" ]] && collect_unique python_versions "$ver"
        done < <(echo "$content" | grep -E '(python|python-version).*\[' | grep -oE "[0-9]+\.[0-9]+" || true)

        while IFS= read -r ver; do
            ver=$(echo "$ver" | tr -d "\"' ")
            [[ -n "$ver" ]] && collect_unique python_versions "$ver"
        done < <(echo "$content" | grep -E 'python-version:[[:space:]]*[0-9]' | grep -oE "[0-9]+\.[0-9]+" || true)

        # --- Quality gates (detect from job names and run commands) ---
        # PHPStan
        if echo "$content" | grep -qiE 'phpstan|phpstan\.neon'; then
            # Try to extract level from the command line
            local phpstan_level
            phpstan_level=$(echo "$content" | grep -oE 'phpstan[[:space:]]+analyse.*--level[=[:space:]]*[0-9]+' | grep -oE '[0-9]+$' | head -1 || true)
            if [[ -z "$phpstan_level" ]] && [[ -f "phpstan.neon" || -f "phpstan.neon.dist" || -f "phpstan.dist.neon" ]]; then
                local neon_file
                for neon_file in phpstan.neon phpstan.neon.dist phpstan.dist.neon; do
                    [[ -f "$neon_file" ]] || continue
                    phpstan_level=$(grep -E '^[[:space:]]*level:' "$neon_file" | head -1 | grep -oE '[0-9]+' || true)
                    [[ -n "$phpstan_level" ]] && break
                done
            fi
            if [[ -n "$phpstan_level" ]]; then
                collect_unique quality_gates "phpstan-level-${phpstan_level}"
            else
                collect_unique quality_gates "phpstan"
            fi
        fi

        # PHPUnit / phpunit
        echo "$content" | grep -qiE 'phpunit|ci:test:php:unit' && collect_unique quality_gates "phpunit"

        # Rector
        echo "$content" | grep -qiE 'rector.*--dry-run|ci:test:php:rector' && collect_unique quality_gates "rector-dry-run"

        # PHP-CS-Fixer
        echo "$content" | grep -qiE 'php-cs-fixer|ci:test:php:cgl' && collect_unique quality_gates "php-cs-fixer"

        # golangci-lint
        echo "$content" | grep -qiE 'golangci-lint' && collect_unique quality_gates "golangci-lint"

        # ESLint
        echo "$content" | grep -qiE 'eslint' && collect_unique quality_gates "eslint"

        # Jest / Vitest
        echo "$content" | grep -qiE '\bjest\b|\bvitest\b' && collect_unique quality_gates "jest"

        # pytest
        echo "$content" | grep -qiE '\bpytest\b' && collect_unique quality_gates "pytest"

        # go test
        echo "$content" | grep -qE 'go test' && collect_unique quality_gates "go-test"

        # go vet
        echo "$content" | grep -qE 'go vet' && collect_unique quality_gates "go-vet"

        # govulncheck
        echo "$content" | grep -qiE 'govulncheck' && collect_unique quality_gates "govulncheck"

        # fuzz tests
        echo "$content" | grep -qE '\-fuzz=' && collect_unique quality_gates "fuzz-tests"

        # mutation testing
        echo "$content" | grep -qiE 'mutation|infection' && collect_unique quality_gates "mutation-testing"

        # CodeQL (also a security workflow)
        if echo "$content" | grep -qiE 'codeql'; then
            collect_unique quality_gates "codeql"
            collect_unique security_workflows "$basename"
        fi

        # Trivy
        if echo "$content" | grep -qiE 'trivy'; then
            collect_unique quality_gates "trivy"
            collect_unique security_workflows "$basename"
        fi

        # --- Coverage threshold ---
        # Patterns: THRESHOLD=60, --min-coverage=80, coverage-threshold: 80, fail_ci_if_error
        local threshold
        threshold=$(echo "$content" | grep -oE 'THRESHOLD=[0-9]+\.?[0-9]*' | head -1 | grep -oE '[0-9]+\.?[0-9]*' || true)
        [[ -n "$threshold" && -z "$coverage_threshold" ]] && coverage_threshold="${threshold}%"

        threshold=$(echo "$content" | grep -oE '(--min-coverage|coverage-threshold|minimum_coverage)[=:[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+' || true)
        [[ -n "$threshold" && -z "$coverage_threshold" ]] && coverage_threshold="${threshold}%"

        # --- Required checks (from workflow names) ---
        local wf_name
        wf_name=$(echo "$content" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')
        [[ -n "$wf_name" ]] && collect_unique required_checks "$wf_name"

        # --- Linter config references ---
        for cfg in .php-cs-fixer.php .php-cs-fixer.dist.php phpstan.neon phpstan.neon.dist phpstan.dist.neon \
                   .eslintrc .eslintrc.js .eslintrc.json eslint.config.js eslint.config.mjs \
                   .golangci.yml .golangci.yaml .prettierrc .prettierrc.json \
                   ruff.toml .flake8 .pylintrc mypy.ini .mypy.ini \
                   .markdownlint.json .markdownlint-cli2.jsonc .yamllint.yml; do
            if [[ -f "$cfg" ]]; then
                collect_unique linter_configs "$cfg"
            fi
        done
    done

    # Build JSON
    local php_json node_json python_json gates_json checks_json linters_json security_json perms_json
    php_json=$(arr_to_json php_versions)
    node_json=$(arr_to_json node_versions)
    python_json=$(arr_to_json python_versions)
    gates_json=$(arr_to_json quality_gates)
    checks_json=$(arr_to_json required_checks)
    linters_json=$(arr_to_json linter_configs)
    security_json=$(arr_to_json security_workflows)
    perms_json=$(arr_to_json permissions)

    jq -n \
        --arg ci_platform "github-actions" \
        --argjson php_versions "$php_json" \
        --argjson node_versions "$node_json" \
        --arg go_version "$go_version" \
        --argjson python_versions "$python_json" \
        --argjson quality_gates "$gates_json" \
        --arg coverage_threshold "$coverage_threshold" \
        --argjson required_checks "$checks_json" \
        --argjson pinned_actions "$pinned_actions" \
        --argjson linter_configs "$linters_json" \
        --argjson security_workflows "$security_json" \
        --argjson permissions "$perms_json" \
        '{
            ci_platform: $ci_platform,
            php_versions: $php_versions,
            node_versions: $node_versions,
            go_version: $go_version,
            python_versions: $python_versions,
            quality_gates: $quality_gates,
            coverage_threshold: $coverage_threshold,
            required_checks: $required_checks,
            pinned_actions: $pinned_actions,
            linter_configs: $linter_configs,
            security_workflows: $security_workflows,
            permissions: $permissions
        } | with_entries(select(.value != "" and .value != [] and .value != null))'
}

# ---------------------------------------------------------------------------
# GitLab CI parsing
# ---------------------------------------------------------------------------
parse_gitlab_ci() {
    [[ -f ".gitlab-ci.yml" ]] || { echo "{}"; return; }

    local content
    content=$(<".gitlab-ci.yml")

    local quality_gates=()
    local stages=()

    # Extract stages
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.+) ]]; then
            local stage="${BASH_REMATCH[1]}"
            stage=$(echo "$stage" | tr -d "\"' ")
            collect_unique stages "$stage"
        fi
    done < <(sed -n '/^stages:/,/^[^[:space:]-]/p' ".gitlab-ci.yml" | tail -n +2)

    # Detect quality gates from script blocks
    echo "$content" | grep -qiE 'phpstan' && collect_unique quality_gates "phpstan"
    echo "$content" | grep -qiE 'phpunit' && collect_unique quality_gates "phpunit"
    echo "$content" | grep -qiE 'eslint' && collect_unique quality_gates "eslint"
    echo "$content" | grep -qiE 'jest|vitest' && collect_unique quality_gates "jest"
    echo "$content" | grep -qiE 'pytest' && collect_unique quality_gates "pytest"
    echo "$content" | grep -qiE 'golangci-lint' && collect_unique quality_gates "golangci-lint"
    echo "$content" | grep -qE 'go test' && collect_unique quality_gates "go-test"

    local stages_json gates_json
    stages_json=$(arr_to_json stages)
    gates_json=$(arr_to_json quality_gates)

    jq -n \
        --arg ci_platform "gitlab-ci" \
        --argjson stages "$stages_json" \
        --argjson quality_gates "$gates_json" \
        '{
            ci_platform: $ci_platform,
            stages: $stages,
            quality_gates: $quality_gates
        } | with_entries(select(.value != "" and .value != [] and .value != null))'
}

# ---------------------------------------------------------------------------
# Concourse CI parsing
# ---------------------------------------------------------------------------
parse_concourse() {
    local pipeline_file=""
    for f in ci/pipeline.yml ci/pipeline.yaml pipeline.yml pipeline.yaml ci/*.yml; do
        [[ -f "$f" ]] && pipeline_file="$f" && break
    done
    [[ -z "$pipeline_file" ]] && { echo "{}"; return; }

    local content
    content=$(<"$pipeline_file")

    local resource_types=()
    local jobs=()

    # Extract resource types
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+) ]]; then
            collect_unique resource_types "${BASH_REMATCH[1]}"
        fi
    done < <(sed -n '/^resource_types:/,/^[a-z]/p' "$pipeline_file" | tail -n +2)

    # Extract job names
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+) ]]; then
            collect_unique jobs "${BASH_REMATCH[1]}"
        fi
    done < <(sed -n '/^jobs:/,/^[a-z]/p' "$pipeline_file" | tail -n +2)

    local rt_json jobs_json
    rt_json=$(arr_to_json resource_types)
    jobs_json=$(arr_to_json jobs)

    jq -n \
        --arg ci_platform "concourse" \
        --arg pipeline_file "$pipeline_file" \
        --argjson resource_types "$rt_json" \
        --argjson jobs "$jobs_json" \
        '{
            ci_platform: $ci_platform,
            pipeline_file: $pipeline_file,
            resource_types: $resource_types,
            jobs: $jobs
        } | with_entries(select(.value != "" and .value != [] and .value != null))'
}

# ---------------------------------------------------------------------------
# Detect CI platform and parse
# ---------------------------------------------------------------------------
if [[ -d ".github/workflows" ]]; then
    parse_github_actions
elif [[ -f ".gitlab-ci.yml" ]]; then
    parse_gitlab_ci
elif [[ -f "ci/pipeline.yml" || -f "ci/pipeline.yaml" || -f "pipeline.yml" || -f "pipeline.yaml" ]]; then
    parse_concourse
else
    # No CI detected
    echo '{}'
fi
