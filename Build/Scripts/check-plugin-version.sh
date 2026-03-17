#!/usr/bin/env bash
# check-plugin-version.sh — Verify version consistency across plugin.json,
# SKILL.md metadata, and (when present) git tags at HEAD.
set -euo pipefail

# --- Extract plugin.json version ---
PLUGIN_FILE=".claude-plugin/plugin.json"
if [[ ! -f "${PLUGIN_FILE}" ]]; then
    echo "ERROR: ${PLUGIN_FILE} not found" >&2
    exit 1
fi
PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('${PLUGIN_FILE}'))['version'])")
if [[ -z "${PLUGIN_VERSION}" ]]; then
    echo "ERROR: Could not extract version from ${PLUGIN_FILE}" >&2
    exit 1
fi
echo "plugin.json version: ${PLUGIN_VERSION}"

# --- Extract SKILL.md metadata.version ---
SKILL_FILE=""
if [[ -f "SKILL.md" ]]; then
    SKILL_FILE="SKILL.md"
else
    for f in skills/*/SKILL.md; do
        if [[ -f "$f" ]]; then
            SKILL_FILE="$f"
            break
        fi
    done
fi

if [[ -n "${SKILL_FILE}" ]]; then
    # Extract version from YAML frontmatter (metadata.version field)
    SKILL_VERSION=$(sed -n '/^---$/,/^---$/p' "${SKILL_FILE}" \
        | grep -E '^\s*version:' \
        | head -1 \
        | sed 's/.*version:[[:space:]]*//' \
        | tr -d '"'"'")
    if [[ -n "${SKILL_VERSION}" ]]; then
        echo "SKILL.md version:    ${SKILL_VERSION}"
        if [[ "${PLUGIN_VERSION}" != "${SKILL_VERSION}" ]]; then
            echo "ERROR: Version mismatch — plugin.json (${PLUGIN_VERSION}) != SKILL.md (${SKILL_VERSION})" >&2
            exit 1
        fi
        echo "OK: plugin.json and SKILL.md versions match"
    else
        echo "WARNING: Could not extract version from ${SKILL_FILE} frontmatter" >&2
    fi
else
    echo "WARNING: No SKILL.md found, skipping SKILL.md version check" >&2
fi

# --- Check git tag match (only when tags point at HEAD) ---
TAGS=$(git tag --points-at HEAD 2>/dev/null | sed -nE 's/^v?([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' || true)
if [[ -z "${TAGS}" ]]; then
    echo "No semver tags at HEAD, skipping tag check"
    exit 0
fi

echo "Semver tags at HEAD: ${TAGS}"
if ! echo "${TAGS}" | grep -qFx "${PLUGIN_VERSION}"; then
    echo "ERROR: plugin.json version (${PLUGIN_VERSION}) does not match any semver tag at HEAD." >&2
    echo "Tags found at HEAD:" >&2
    echo "${TAGS}" >&2
    exit 1
fi
echo "OK: plugin.json version matches tag at HEAD"
