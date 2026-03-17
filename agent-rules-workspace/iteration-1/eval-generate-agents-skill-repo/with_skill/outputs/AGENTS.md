<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Managed by agent: keep sections and order; edit content, not structure -->
<!-- Last updated: 2026-03-17 | Last verified: 2026-03-17 -->

# AGENTS.md

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Commands (verified)
> Source: .github/workflows/lint.yml, scripts/ — CI-sourced commands are most reliable

<!-- AGENTS-GENERATED:START commands -->
| Task | Command | ~Time |
|------|---------|-------|
| Lint (Markdown) | `markdownlint-cli2` | ~5s |
| Lint (YAML) | `yamllint .` | ~3s |
| Lint (Shell) | `shellcheck -x skills/cli-tools/scripts/**/*.sh` | ~5s |
| Validate (Skill) | CI only (reusable workflow `netresearch/skill-repo-skill/.github/workflows/validate.yml`) | ~30s |
| Install tool | `skills/cli-tools/scripts/install_tool.sh <tool> install` | ~10s |
| Audit environment | `skills/cli-tools/scripts/check_environment.sh audit .` | ~15s |
| Detect project type | `skills/cli-tools/scripts/detect_project_type.sh .` | ~2s |
| Batch update tools | `skills/cli-tools/scripts/auto_update.sh` | ~60s |
| Detect missing tool | `python3 scripts/detect_missing_tool.py < <(echo '{"output":"bash: rg: command not found"}')` | ~1s |
<!-- AGENTS-GENERATED:END commands -->

> If commands fail, verify against the scripts or CI workflows, or ask user to update.

## Workflow
1. **Before coding**: Read nearest `AGENTS.md` + check Golden Samples for the area you're touching
2. **After each change**: Run the smallest relevant check (shellcheck on changed .sh files)
3. **Before committing**: Run linters if changes affect >2 files or touch shared code
4. **Before claiming done**: Run verification and **show output as evidence** -- never say "try again" or "should work now" without proof

## File Map
<!-- AGENTS-GENERATED:START filemap -->
```
.claude-plugin/plugin.json -> Skill plugin metadata (name, version 1.4.6, skills array)
.github/workflows/          -> CI: lint.yml (markdown, yaml, shell, skill validation), release.yml (tag-triggered), auto-merge-deps.yml
Build/Scripts/              -> Build helpers: check-plugin-version.sh (pre-push tag/version validation)
Build/hooks/                -> Git hooks: pre-push (delegates to check-plugin-version.sh)
catalog/                    -> 74+ JSON tool definitions (one file per tool: name, install_method, binary_name, available_methods)
hooks/hooks.json            -> Claude Code PostToolUse hook config (triggers detect_missing_tool.py on Bash output)
scripts/detect_missing_tool.py -> Python hook: parses Bash output for "command not found" patterns, emits system-reminder
skills/cli-tools/SKILL.md  -> Skill definition: triggers, capabilities, workflows, script/reference index
skills/cli-tools/scripts/   -> Core scripts: install_tool.sh, auto_update.sh, check_environment.sh, detect_project_type.sh, install_composer.sh
skills/cli-tools/scripts/installers/ -> Method-specific installers: github_release_binary.sh, npm_global.sh, uv_tool.sh, package_manager.sh, etc.
skills/cli-tools/scripts/lib/       -> Shared libraries: reconcile.sh, catalog.sh, common.sh, dependency.sh, policy.sh, etc.
skills/cli-tools/references/ -> Docs: binary_to_tool_map.md, project_type_requirements.md, preferred-tools.md, resolution-workflow.md, troubleshooting.md
composer.json               -> Composer package metadata (type: ai-agent-skill, requires composer-agent-skill-plugin)
renovate.json               -> Renovate bot config (extends config:recommended)
```
<!-- AGENTS-GENERATED:END filemap -->

## Golden Samples (follow these patterns)
<!-- AGENTS-GENERATED:START golden-samples -->
| For | Reference | Key patterns |
|-----|-----------|--------------|
| Tool catalog entry | `catalog/ripgrep.json` | JSON with name, install_method, binary_name, available_methods array with priority, github_repo |
| Simple catalog entry | `catalog/ruff.json` | Minimal JSON for pip-installed tools |
| Installer script | `skills/cli-tools/scripts/installers/github_release_binary.sh` | Downloads from GitHub releases, extracts, installs to ~/.local/bin |
| Main orchestrator | `skills/cli-tools/scripts/install_tool.sh` | Sources lib/reconcile.sh, reads catalog JSON, delegates to installer |
| Hook script | `scripts/detect_missing_tool.py` | Reads stdin JSON, regex matches error patterns, emits `<system-reminder>` |
<!-- AGENTS-GENERATED:END golden-samples -->

## Utilities (check before creating new)
<!-- AGENTS-GENERATED:START utilities -->
| Need | Use | Location |
|------|-----|----------|
| Install a tool | `install_tool.sh <tool> [install\|update\|uninstall\|status]` | `skills/cli-tools/scripts/install_tool.sh` |
| Reconcile install method | `reconcile.sh` (sourced by install_tool.sh) | `skills/cli-tools/scripts/lib/reconcile.sh` |
| Detect current install method | `detect_install_method()` in reconcile.sh | `skills/cli-tools/scripts/lib/reconcile.sh` |
| Read catalog JSON | `jq` on `catalog/<tool>.json` | `catalog/` |
| Check tool binary name | `binary_to_tool_map.md` | `skills/cli-tools/references/binary_to_tool_map.md` |
| Project type requirements | `project_type_requirements.md` | `skills/cli-tools/references/project_type_requirements.md` |
| Shared shell helpers | `common.sh`, `path_check.sh`, `policy.sh` | `skills/cli-tools/scripts/lib/` |
<!-- AGENTS-GENERATED:END utilities -->

## Heuristics (quick decisions)
<!-- AGENTS-GENERATED:START heuristics -->
| When | Do |
|------|-----|
| Adding a new tool | Create `catalog/<tool>.json` with name, install_method, binary_name, available_methods |
| Binary name differs from tool name | Update `references/binary_to_tool_map.md` |
| Tool has GitHub releases | Set `install_method: "auto"` with `github_release_binary` as priority 1 |
| Tool is Python-only | Use `uv_tool` or `pip` installer method |
| Tool is Node-only | Use `npm_global` installer method |
| Adding installer | Create `skills/cli-tools/scripts/installers/<method>.sh`, make executable |
| Modifying shared lib | Check all scripts that source it via `. "$DIR/lib/<file>.sh"` |
| Adding dependency | Ask first -- we minimize deps |
| Unsure about pattern | Check Golden Samples above |
<!-- AGENTS-GENERATED:END heuristics -->

## Repository Settings
<!-- AGENTS-GENERATED:START repo-settings -->
- **Default branch:** `main`
- **License:** MIT (code) + CC-BY-SA-4.0 (content)
- **Entity name:** Netresearch DTT GmbH
- **CI:** GitHub Actions (lint.yml, release.yml, auto-merge-deps.yml)
- **Release:** Tag-triggered via `netresearch/skill-repo-skill` reusable workflow
- **Dependency updates:** Renovate (config:recommended)
- **Git hooks:** pre-push validates plugin.json version matches tag
- **Plugin version:** 1.4.6 (in `.claude-plugin/plugin.json`)
<!-- AGENTS-GENERATED:END repo-settings -->

## Boundaries

### Always Do
- Run shellcheck on changed `.sh` files before committing
- Test `install_tool.sh <tool> install` after modifying catalog entries or installers
- Use `set -euo pipefail` in all bash scripts
- Use conventional commit format: `type(scope): subject`
- **Show test output as evidence before claiming work is complete**
- Keep catalog JSON valid (test with `jq . catalog/<tool>.json`)
- Ensure new scripts are executable (`chmod +x`)

### Ask First
- Adding new dependencies
- Modifying CI/CD configuration
- Changing the hook detection patterns in `detect_missing_tool.py`
- Adding new installer methods
- Changing install priority order in existing catalog entries
- Repo-wide refactoring or rewrites

### Never Do
- Commit secrets, credentials, or sensitive data
- Modify vendor/, node_modules/, or generated files
- Push directly to main/master branch
- Use "Netresearch GmbH & Co. KG" (old name) -- always "Netresearch DTT GmbH"
- Hardcode absolute paths in scripts (use `$DIR` relative to script location)
- Remove existing catalog entries without explicit request

## Codebase State
<!-- AGENTS-GENERATED:START codebase-state -->
- 74+ tool definitions in `catalog/` (core CLI, languages, package managers, DevOps, linters, security, git tools)
- 9 installer methods in `skills/cli-tools/scripts/installers/`
- 8 shared libraries in `skills/cli-tools/scripts/lib/`
- PostToolUse hook auto-detects "command not found" errors via Python script
- Reconciliation system (`install_method: "auto"`) tries methods by priority until one succeeds
<!-- AGENTS-GENERATED:END codebase-state -->

## Terminology
| Term | Means |
|------|-------|
| Catalog | JSON definitions in `catalog/` describing how to install each tool |
| Reconciliation | Auto-detection of best install method by trying available_methods in priority order |
| binary_name | The actual executable name (e.g., `rg` for ripgrep, `fd` for fd-find) |
| install_method | Either `"auto"` (use reconciliation) or a specific installer name |
| PostToolUse hook | Claude Code hook that runs after every Bash tool call to detect missing tools |
| Skill | Agent Skills specification package -- portable AI agent knowledge |

## When instructions conflict
The nearest `AGENTS.md` wins. Explicit user prompts override files.
- For shell script patterns, defer to ShellCheck recommendations and existing script conventions in `skills/cli-tools/scripts/lib/`
