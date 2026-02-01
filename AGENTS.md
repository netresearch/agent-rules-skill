<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Managed by agent: keep sections and order; edit content, not structure -->
<!-- Last updated: 2026-02-01 | Last verified: 2026-02-01 -->

# AGENTS.md

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Commands (verified ✓)
<!-- AGENTS-GENERATED:START commands -->
| Task | Command | ~Time |
|------|---------|-------|
| Generate AGENTS.md | `bash skills/agents/scripts/generate-agents.sh /path/to/project` | ~5s |
| Validate structure | `bash skills/agents/scripts/validate-structure.sh /path/to/project` | ~2s |
| Check freshness | `bash skills/agents/scripts/check-freshness.sh /path/to/project` | ~2s |
| Verify content | `bash skills/agents/scripts/verify-content.sh /path/to/project` | ~3s |
| Verify commands | `bash skills/agents/scripts/verify-commands.sh /path/to/project` | ~5s |
| Detect project | `bash skills/agents/scripts/detect-project.sh /path/to/project` | ~1s |
| Lint (shellcheck) | `shellcheck skills/agents/scripts/*.sh` | ~3s |
<!-- AGENTS-GENERATED:END commands -->

> If commands fail, check Bash version (4.3+ required). On macOS: `brew install bash`

## File Map
<!-- AGENTS-GENERATED:START filemap -->
```
skills/agents/           → Main skill directory
  SKILL.md               → Skill definition and documentation
  scripts/               → 19 Bash scripts for generation/validation
  assets/                → Templates (2 root, 10 scoped)
  references/            → Analysis, examples, coverage docs
.github/workflows/       → Release automation
.claude-plugin/          → Claude Code plugin manifest
composer.json            → Composer skill plugin integration
```
<!-- AGENTS-GENERATED:END filemap -->

## Golden Samples (follow these patterns)
<!-- AGENTS-GENERATED:START golden-samples -->
| For | Reference | Key patterns |
|-----|-----------|--------------|
| Bash version check | `scripts/generate-agents.sh:1-7` | BASH_VERSINFO check with helpful error |
| jq null handling | `scripts/generate-agents.sh:jq_safe()` | Filter null, "null", empty strings |
| Portable date | `scripts/verify-commands.sh:get_time_ms()` | BSD/GNU compatible with fallback |
| Portable sed -i | `scripts/verify-commands.sh` | Use `.bak` suffix for macOS compat |
| Safe command check | `scripts/verify-commands.sh:is_safe_command()` | Glob patterns, not regex |
<!-- AGENTS-GENERATED:END golden-samples -->

## Utilities (check before creating new)
<!-- AGENTS-GENERATED:START utilities -->
| Need | Use | Location |
|------|-----|----------|
| Project detection | `detect-project.sh` | Language, version, build tools |
| Scope detection | `detect-scopes.sh` | Find dirs needing scoped AGENTS.md |
| Command extraction | `extract-commands.sh` | From Makefile, package.json, composer.json |
| Doc extraction | `extract-documentation.sh` | From README, CONTRIBUTING, etc. |
| Platform extraction | `extract-platform-files.sh` | From .github/, .gitlab/, etc. |
| IDE extraction | `extract-ide-settings.sh` | From .editorconfig, .vscode/, etc. |
| Agent config extraction | `extract-agent-configs.sh` | From .cursor/, .claude/, etc. |
| Quality config extraction | `extract-quality-configs.sh` | PHPStan level, coverage %, etc. |
| CI command extraction | `extract-ci-commands.sh` | From CI workflow files |
| Git history analysis | `analyze-git-history.sh` | Recent commits, contributors |
| File map generation | `generate-file-map.sh` | Directory structure for AGENTS.md |
| Utility detection | `detect-utilities.sh` | Find reusable helpers |
| Golden sample detection | `detect-golden-samples.sh` | Find canonical pattern files |
| Heuristic detection | `detect-heuristics.sh` | Extract project-specific rules |
<!-- AGENTS-GENERATED:END utilities -->

## Heuristics (quick decisions)
<!-- AGENTS-GENERATED:START heuristics -->
| When | Do |
|------|-----|
| Adding new script | Put in `skills/agents/scripts/`, add Bash 4.x check if needed |
| Adding template | Put in `skills/agents/assets/`, use thin style by default |
| Modifying script | Test on both GNU (Linux) and BSD (macOS) |
| Using jq | Always handle null values with `jq_safe()` or `// empty` |
| Using sed -i | Always use `.bak` suffix for portability |
| Adding dependency | Ask first - we minimize deps (only bash, jq, git) |
| Unsure about pattern | Check Golden Samples above |
<!-- AGENTS-GENERATED:END heuristics -->

## Boundaries

### Always Do
- Check Bash version at script start (4.0+ for arrays, 4.3+ for namerefs)
- Handle both GNU and BSD command variants
- Validate PROJECT_DIR exists before processing
- Use conventional commit format: `type(scope): subject`
- Follow ShellCheck recommendations

### Ask First
- Adding new dependencies (beyond bash, jq, git)
- Modifying CI/CD configuration
- Changing script interfaces (flags, output format)
- Adding new template sections

### Never Do
- Commit secrets, credentials, or sensitive data
- Use GNU-only features without fallback (date +%s%3N, sed -i without .bak)
- Use regex in glob matching context
- Assume Bash 5.x features are available
- Push directly to main/master branch

## Codebase State
<!-- AGENTS-GENERATED:START codebase-state -->
- **Active development**: v2.x series, adding extraction and verification features
- **Cross-platform**: Must work on Linux (GNU) and macOS (BSD)
- **Minimal deps**: Only bash 4.3+, jq 1.5+, git 2.0+
- **No tests yet**: Scripts are manually tested; consider adding bats tests
<!-- AGENTS-GENERATED:END codebase-state -->

## Terminology
| Term | Means |
|------|-------|
| Thin style | Minimal AGENTS.md (~30 lines) with scope index |
| Verbose style | Detailed AGENTS.md (~100 lines) with examples |
| Scoped file | AGENTS.md in subdirectory (backend/, tests/, etc.) |
| Golden sample | Canonical file demonstrating correct patterns |
| Freshness | Whether AGENTS.md reflects recent git commits |
| Nameref | Bash 4.3+ `local -n` for pass-by-reference |

## Index of scoped AGENTS.md
<!-- AGENTS-GENERATED:START scope-index -->
- `skills/agents/` - Main skill with scripts, assets, references
<!-- AGENTS-GENERATED:END scope-index -->

## When instructions conflict
The nearest `AGENTS.md` wins. Explicit user prompts override files.
- For Bash patterns, prefer POSIX compatibility when possible
- For jq patterns, always handle null values explicitly
