# Scripts Guide

Complete reference for all AGENTS.md generator scripts.

## Generating AGENTS.md Files

```bash
scripts/generate-agents.sh /path/to/project
```

Options:
- `--dry-run` - Preview changes without writing files
- `--verbose` - Show detailed output
- `--style=thin` - Use thin root template (~30 lines, default)
- `--style=verbose` - Use verbose root template (~100-200 lines)
- `--update` - Update existing files only (preserves human edits outside generated markers)
- `--claude-shim` - Generate CLAUDE.md that imports AGENTS.md for Claude Code compatibility
- `--force` - Regenerate even if files exist

## Validating Structure

```bash
scripts/validate-structure.sh /path/to/project
```

Options:
- `--check-freshness, -f` - Also check if files are up to date with git commits
- `--verbose, -v` - Show detailed output

## Checking Freshness

```bash
scripts/check-freshness.sh /path/to/project
```

This script:
- Extracts the "Last updated" date from the AGENTS.md header
- Checks git commits since that date for files in the relevant scope
- Reports if there are commits that might require AGENTS.md updates

Options:
- `--verbose, -v` - Show commit details and changed files
- `--threshold=DAYS` - Days threshold to consider stale (default: 7)

Example with full validation:
```bash
scripts/validate-structure.sh /path/to/project --check-freshness --verbose
```

## Detecting Project Type

```bash
scripts/detect-project.sh /path/to/project
```

Detects project language, version, and build tools.

## Detecting Scopes

```bash
scripts/detect-scopes.sh /path/to/project
```

Identifies directories that should have scoped AGENTS.md files.

## Extracting Commands

```bash
scripts/extract-commands.sh /path/to/project
```

Extracts build commands from Makefile, package.json, composer.json, or go.mod.

## Extracting Documentation

```bash
scripts/extract-documentation.sh /path/to/project
```

Extracts information from README.md, CONTRIBUTING.md, SECURITY.md, and other documentation.

## Extracting Platform Files

```bash
scripts/extract-platform-files.sh /path/to/project
```

Extracts information from .github/, .gitlab/, CODEOWNERS, dependabot.yml, etc.

## Extracting IDE Settings

```bash
scripts/extract-ide-settings.sh /path/to/project
```

Extracts information from .editorconfig, .vscode/, .idea/, etc.

## Extracting AI Agent Configs

```bash
scripts/extract-agent-configs.sh /path/to/project
```

Extracts information from .cursor/, .claude/, copilot-instructions.md, etc.

## Verifying Content Accuracy

**CRITICAL: Always run this before considering AGENTS.md files complete.**

```bash
scripts/verify-content.sh /path/to/project
```

This script:
- Checks if documented files actually exist
- Verifies Makefile targets are real
- Compares module/script counts against actual files
- Reports undocumented files that should be added
- Reports documented files that don't exist

Options:
- `--verbose, -v` - Show detailed verification output
- `--fix` - Suggest fixes for common issues

**This verification step is MANDATORY when updating existing AGENTS.md files.**

## Verifying Commands Work

To prevent "command rot" (documented commands that no longer work):

```bash
scripts/verify-commands.sh /path/to/project
```

This script:
- Extracts commands from AGENTS.md tables and code blocks
- Verifies npm/yarn scripts exist in package.json
- Verifies make targets exist in Makefile
- Verifies composer scripts exist in composer.json
- Updates "Last verified" timestamp on success

Options:
- `VERBOSE=true` - Show detailed output
- `DRY_RUN=true` - Don't update timestamp

**Why this matters:** Research shows broken commands waste 500+ tokens as agents debug non-existent commands. Verified commands enable confident execution.

## Post-Generation Validation Checklist

**After generating AGENTS.md files, ALWAYS validate the output:**

```bash
# 1. Run structure validation
scripts/validate-structure.sh /path/to/project --verbose

# 2. Verify content accuracy
scripts/verify-content.sh /path/to/project

# 3. Verify commands work
scripts/verify-commands.sh /path/to/project
```

**Validation criteria:**

| Check | Pass Criteria | Common Issues |
|-------|---------------|---------------|
| **Thin root** | Root AGENTS.md <= 80 lines | Duplicated scope content in root |
| **All scopes covered** | Every major directory has AGENTS.md | Missing `Tests/`, `Configuration/` |
| **No duplication** | Content appears in ONE location | Commands duplicated in root + scope |
| **Commands verified** | All documented commands execute | Typos, renamed targets |
| **Files exist** | All referenced files are real | Hallucinated paths |
| **Links valid** | All cross-references resolve | Broken relative paths |

**Never consider generation complete until all checks pass.**
