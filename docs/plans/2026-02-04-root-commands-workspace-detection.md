# Root Commands & Workspace Detection Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix P0 bugs where multi-stack repos show wrong commands in root AGENTS.md and package manager detection fails for workspaces.

**Architecture:** Use the existing `--stack` filter in `extract-commands.sh` for root AGENTS.md generation (currently only used for scoped files). Add workspace-aware lockfile detection that walks up to find workspace root.

**Tech Stack:** Bash 4.3+, jq, existing detection libraries

---

## Task 1: Fix Root Commands Using Primary Language Stack Filter

**Files:**
- Modify: `skills/agents/scripts/generate-agents.sh:306-309`

**Problem:** Line 308 calls `extract-commands.sh "$PROJECT_DIR"` without a stack filter, so it uses `auto` mode which picks up Node.js commands from `package.json` even in a Go project with a frontend subfolder.

**Step 1: Read current implementation**

Read lines 306-320 of generate-agents.sh to understand the current command extraction.

**Step 2: Modify command extraction to use stack filter**

Change line 308 from:
```bash
COMMANDS=$("$SCRIPT_DIR/extract-commands.sh" "$PROJECT_DIR")
```

To use the detected primary language as stack filter:
```bash
# Map detected language to stack filter
get_stack_filter() {
    case "$1" in
        "go") echo "go" ;;
        "php") echo "php" ;;
        "python") echo "python" ;;
        "typescript"|"javascript") echo "node" ;;
        *) echo "auto" ;;  # Fallback for claude-code-plugin, docker, bash, etc.
    esac
}
PRIMARY_STACK=$(get_stack_filter "$LANGUAGE")
COMMANDS=$("$SCRIPT_DIR/extract-commands.sh" "$PROJECT_DIR" "$PRIMARY_STACK")
```

**Step 3: Run test on go-with-internal-web-tsx fixture**

Run:
```bash
bash skills/agents/scripts/generate-agents.sh skills/agents/references/examples/go-with-internal-web-tsx --force --verbose
```

Expected: Root AGENTS.md should show Go commands (go test, go build) NOT Node.js commands.

**Step 4: Verify output**

```bash
grep -E "Typecheck|Lint|Test" skills/agents/references/examples/go-with-internal-web-tsx/AGENTS.md
```

Expected output should contain `go test`, `go build`, `golangci-lint`, NOT `npx`, `npm`.

**Step 5: Commit**

```bash
git add skills/agents/scripts/generate-agents.sh
git commit -S -m "fix(generate): use primary language stack filter for root commands

Root AGENTS.md now uses --stack filter matching detected language.
Go projects show Go commands, not Node.js from subfolder package.json."
```

---

## Task 2: Add Workspace-Aware Package Manager Detection

**Files:**
- Modify: `skills/agents/scripts/lib/config-root.sh`
- Modify: `skills/agents/scripts/generate-agents.sh:117-156` (detect_node_package_manager function)

**Problem:** `detect_node_package_manager()` walks up from scope dir to find `package.json` with lockfile, but stops at the first `package.json`. In a workspace, the lockfile is at the workspace root (e.g., `/root/pnpm-lock.yaml`) but individual packages have their own `package.json` without lockfiles.

**Step 1: Write failing test fixture**

Create `skills/agents/references/examples/pnpm-workspace/` with:
- Root: `pnpm-workspace.yaml`, `pnpm-lock.yaml`, `package.json`
- Package: `packages/web/package.json` (no lockfile)

**Step 2: Add find_node_workspace_root() to config-root.sh**

```bash
# Find workspace root for Node.js projects
# Walks up to find workspace marker files (pnpm-workspace.yaml, lerna.json, etc.)
# Returns: workspace root directory or empty if not in a workspace
find_node_workspace_root() {
    local start_dir="$1"
    local search_dir="$start_dir"

    while [[ "$search_dir" != "." && "$search_dir" != "/" ]]; do
        # pnpm workspace
        [[ -f "$search_dir/pnpm-workspace.yaml" ]] && echo "$search_dir" && return 0
        # npm/yarn workspace (check package.json for workspaces field)
        if [[ -f "$search_dir/package.json" ]]; then
            if jq -e '.workspaces' "$search_dir/package.json" &>/dev/null; then
                echo "$search_dir"
                return 0
            fi
        fi
        # Lerna monorepo
        [[ -f "$search_dir/lerna.json" ]] && echo "$search_dir" && return 0
        # Nx workspace
        [[ -f "$search_dir/nx.json" ]] && echo "$search_dir" && return 0

        search_dir=$(dirname "$search_dir")
    done

    return 1
}
```

**Step 3: Update detect_node_package_manager() to check workspace root**

Modify the function to:
1. First check for workspace root
2. If in workspace, look for lockfile at workspace root
3. Fall back to existing logic

**Step 4: Run test**

```bash
bash skills/agents/scripts/generate-agents.sh skills/agents/references/examples/pnpm-workspace --force --verbose
```

Verify package manager is correctly detected as `pnpm`.

**Step 5: Commit**

```bash
git add skills/agents/scripts/lib/config-root.sh skills/agents/scripts/generate-agents.sh
git commit -S -m "fix(detect): workspace-aware package manager detection

Adds find_node_workspace_root() to detect pnpm-workspace.yaml, npm/yarn
workspaces field, lerna.json, and nx.json. detect_node_package_manager()
now checks workspace root for lockfiles before falling back to local search."
```

---

## Task 3: Fix CI Command Extraction for Multiline YAML Blocks

**Files:**
- Modify: `skills/agents/scripts/extract-ci-commands.sh:44-55`

**Problem:** Current regex `run:[[:space:]]*(.+)` skips multiline blocks (`run: |`) and then only reads single-line commands. Multiline commands are never captured.

**Step 1: Understand the current parser**

Lines 44-55 currently:
```bash
while IFS= read -r line; do
    if [[ "$line" =~ run:[[:space:]]*(.+) ]]; then
        local cmd="${BASH_REMATCH[1]}"
        # Skip if it's a multi-line indicator
        [[ "$cmd" == "|" ]] && continue
        [[ "$cmd" == "|-" ]] && continue
        # Clean and add
        cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        [ -n "$cmd" ] && all_commands+=("$cmd")
    fi
done < "$f"
```

**Step 2: Rewrite to handle multiline blocks**

```bash
# Extract run commands (including multiline blocks)
local in_multiline=false
local multiline_indent=0
local multiline_cmd=""

while IFS= read -r line; do
    if $in_multiline; then
        # Check if still in multiline block (more indented than run:)
        local line_indent=${#line}
        line_indent=$((line_indent - ${#line##*([[:space:]])}))

        if [[ $line_indent -gt $multiline_indent && -n "${line// /}" ]]; then
            # Still in multiline, accumulate (just first meaningful line)
            if [[ -z "$multiline_cmd" ]]; then
                multiline_cmd=$(echo "$line" | sed 's/^[[:space:]]*//')
            fi
        else
            # End of multiline block
            in_multiline=false
            [[ -n "$multiline_cmd" ]] && all_commands+=("$multiline_cmd")
            multiline_cmd=""
        fi
    fi

    if [[ "$line" =~ ^([[:space:]]*)run:[[:space:]]*(.*)$ ]]; then
        local indent="${BASH_REMATCH[1]}"
        local cmd="${BASH_REMATCH[2]}"

        if [[ "$cmd" == "|" || "$cmd" == "|-" || "$cmd" == "|+" ]]; then
            # Start multiline block
            in_multiline=true
            multiline_indent=${#indent}
            multiline_cmd=""
        elif [[ -n "$cmd" ]]; then
            # Single-line command
            cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            all_commands+=("$cmd")
        fi
    fi
done < "$f"
# Don't forget to capture last multiline if file ends in one
[[ -n "$multiline_cmd" ]] && all_commands+=("$multiline_cmd")
```

**Step 3: Test with fixture that has multiline run blocks**

Create test workflow file and verify extraction.

**Step 4: Commit**

```bash
git add skills/agents/scripts/extract-ci-commands.sh
git commit -S -m "fix(ci-extract): parse multiline YAML run blocks

Handles run: | and run: |- blocks by tracking indent level.
Captures first meaningful command line from multiline blocks."
```

---

## Task 4: Create Regression Test Fixture for Multi-Stack Root Commands

**Files:**
- Create: `skills/agents/references/examples/go-api-with-react-admin/`

**Purpose:** Verify root commands use Go stack, not the React admin frontend.

**Step 1: Create fixture structure**

```
go-api-with-react-admin/
├── go.mod              # go 1.22
├── main.go             # package main
├── cmd/
│   └── api/main.go     # API entrypoint
├── admin/
│   ├── package.json    # React admin dashboard
│   └── src/App.tsx
└── .scopes             # admin:frontend-typescript
```

**Step 2: Generate AGENTS.md**

```bash
bash skills/agents/scripts/generate-agents.sh skills/agents/references/examples/go-api-with-react-admin --force
```

**Step 3: Add CI check for correct commands**

In `.github/workflows/validate-agents.yml`, add:

```yaml
# Regression test 6: Go root should NOT have Node commands
if [[ "$fixture" == *"go-api-with-react-admin"* ]] || [[ "$fixture" == *"go-with-internal-web"* ]]; then
    if grep -E 'npm run|npx|yarn|pnpm' "$fixture/AGENTS.md" | grep -v "node_modules" | head -5; then
        echo "ERROR: Go project root has Node.js commands in Commands table"
        exit 1
    fi
    echo "  ✓ Go root has correct stack commands"
fi
```

**Step 4: Commit**

```bash
git add skills/agents/references/examples/go-api-with-react-admin/ .github/workflows/validate-agents.yml
git commit -S -m "test(fixtures): add go-api-with-react-admin for root command verification"
```

---

## Task 5: Verify All Fixes with Full Test Run

**Step 1: Run generator on all fixtures**

```bash
for fixture in skills/agents/references/examples/*/; do
    echo "=== Testing: $fixture ==="
    bash skills/agents/scripts/generate-agents.sh "$fixture" --force || echo "FAILED: $fixture"
done
```

**Step 2: Run CI workflow locally (if act available)**

```bash
act -j test-generator
```

Or manually verify each regression test passes.

**Step 3: Manual verification checklist**

- [ ] `go-with-internal-web-tsx/AGENTS.md` shows Go commands in root
- [ ] `go-api-with-react-admin/AGENTS.md` shows Go commands in root
- [ ] `pnpm-workspace/AGENTS.md` shows pnpm as package manager
- [ ] PHP fixtures still show PHP commands
- [ ] TypeScript fixtures still show Node commands

---

## Task 6: Bump Version and Create Release

**Files:**
- Modify: `.claude-plugin/plugin.json`

**Step 1: Bump version to 2.8.0**

**Step 2: Create signed tag and release**

```bash
git tag -s v2.8.0 -m "v2.8.0: Fix multi-stack root commands and workspace detection"
git push origin v2.8.0
gh release create v2.8.0 --title "v2.8.0" --notes "..."
```

---

## Summary of Changes

| File | Change |
|------|--------|
| `generate-agents.sh` | Use primary language as `--stack` filter for root commands |
| `lib/config-root.sh` | Add `find_node_workspace_root()` |
| `generate-agents.sh` | Update `detect_node_package_manager()` to use workspace root |
| `extract-ci-commands.sh` | Handle multiline `run: \|` YAML blocks |
| `validate-agents.yml` | Add regression test for Go root commands |
| New fixture | `go-api-with-react-admin/` |
| New fixture | `pnpm-workspace/` (optional, for workspace test) |
