---
name: agents
description: "Agent Skill: Generate and maintain AGENTS.md files following the public agents.md convention. Use when creating AI agent documentation, onboarding guides, or standardizing agent patterns. By Netresearch."
---

# AGENTS.md Generator Skill

Generate and maintain AGENTS.md files following the [public agents.md convention](https://agents.md/).

> **AGENTS.md is FOR AGENTS, not humans.** Human readability is a convenient side effect, not a design goal. Every section, format choice, and word exists to maximize AI coding agent efficiency. If something helps humans but wastes agent tokens, remove it.

> **Spec Compliance:** This skill follows the official agents.md specification which has **no required fields** - all sections are recommendations based on [best practices from 2,500+ repositories](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/).

## Language Choice

**Default to English** - AI coding agents perform best with English instructions because:
- Programming keywords, libraries, and error messages are English
- Zero "semantic friction" between instruction and code (`Create user` → `createUser`)
- Most token-efficient encoding for technical instructions

**Exception: Match your code's naming language.** If your codebase uses non-English naming conventions (e.g., German class names like `Rechnungssteller`, French variables like `id_client`), write AGENTS.md in that language to prevent "naming hallucinations" where agents mix languages.

> **Rule:** The language of AGENTS.md must match the language used for domain naming in the code.

## When to Use This Skill

When creating new projects, use this skill to establish baseline AGENTS.md structure.

When standardizing existing projects, use this skill to generate consistent agent documentation.

When ensuring multi-repo consistency, use this skill to apply the same standards across repositories.

When checking if AGENTS.md files are up to date, use the freshness checking scripts to compare file timestamps with git commits.

## Prerequisites

The generator scripts require:

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Bash** | 4.3+ | Required for nameref variables (`local -n`) |
| **jq** | 1.5+ | JSON processing |
| **git** | 2.0+ | For git history analysis |

### macOS Users

macOS ships with Bash 3.2 (GPLv2 licensed). Install a newer version:

```bash
# Install Bash 4.4+ via Homebrew
brew install bash

# Run scripts with newer bash
/opt/homebrew/bin/bash scripts/generate-agents.sh /path/to/project

# Or add to PATH (optional)
export PATH="/opt/homebrew/bin:$PATH"
```

The scripts will detect incompatible Bash versions and exit with a helpful error message.

## CRITICAL: Full Verification Required

**NEVER trust existing AGENTS.md content as accurate.** Always verify documented information against the actual codebase:

### Mandatory Verification Steps

1. **Extract actual state from source files:**
   - List all modules/files with their actual docstrings
   - List all scripts and their actual purposes
   - Extract actual Makefile/package.json commands
   - List actual test files and structure

2. **Compare extracted state against documented state:**
   - Check if documented files actually exist
   - Check if documented commands actually work
   - Check if module descriptions match actual docstrings
   - Check if counts (modules, scripts, tests) are accurate

3. **Identify and fix discrepancies:**
   - Remove documentation for non-existent files
   - Add documentation for undocumented files
   - Correct inaccurate descriptions
   - Update outdated counts and references

4. **Preserve unverifiable content:**
   - Keep manually-written context that can't be extracted
   - Keep subjective guidance and best practices
   - Mark preserved content appropriately

### What to Verify

| Category | Verification Method |
|----------|---------------------|
| Module list | `ls <dir>/*.py` + read docstrings |
| Script list | `ls scripts/*.sh` + read headers |
| Commands | `grep` Makefile targets **AND run them** |
| Test files | `ls tests/*.py` |
| Data files | `ls *.json` in project root |
| Config files | Check actual existence |
| **File names** | **EXACT match required** (not just existence) |
| **Numeric values** | PHPStan level, coverage %, etc. from actual configs |

### Critical: Exact Name Matching

File names in AGENTS.md must match actual filenames **exactly**:

| Documented | Actual | Status |
|------------|--------|--------|
| `CowriterAjaxController.php` | `AjaxController.php` | **WRONG** - name mismatch |
| `AjaxController.php` | `AjaxController.php` | Correct |

**Real-world example from t3x-cowriter review:**
- AGENTS.md documented `Controller/CowriterAjaxController.php`
- Actual file was `Controller/AjaxController.php`
- This mismatch confused agents trying to find the file

### Critical: Command Verification

Commands documented in AGENTS.md must actually work when run:

```bash
# BAD: Document without testing
make test-mutation  # May not exist!

# GOOD: Verify before documenting
make -n test-mutation 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

**Real-world example from t3x-cowriter review:**
- AGENTS.md documented `make test-mutation` and `make phpstan`
- Neither target existed (actual was `make typecheck`)
- Agents failed when trying to run documented commands

### Example Verification Commands

```bash
# Extract actual module docstrings
for f in cli_audit/*.py; do head -20 "$f" | grep -A5 '"""'; done

# List actual scripts
ls scripts/*.sh

# Extract Makefile targets
grep -E '^[a-z_-]+:' Makefile*

# List actual test files
ls tests/*.py tests/**/*.py
```

### Anti-Patterns to Avoid

- **WRONG:** Updating only dates and counts based on git commits
- **WRONG:** Trusting that existing AGENTS.md was created correctly
- **WRONG:** Copying file lists without verifying they exist
- **WRONG:** Using extracted command output without running it
- **RIGHT:** Extract → Compare → Fix discrepancies → Validate

## Agent-Optimized Design

This skill generates AGENTS.md files optimized for AI coding agent efficiency based on:
- [Research showing 16.58% token reduction with good AGENTS.md](https://arxiv.org/html/2601.20404)
- [GitHub best practices from 2,500+ repositories](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/)
- Multi-agent collaborative design (Claude + Gemini discussion)

### Key Design Principles

1. **Structured over Prose** - Tables and maps parse faster than paragraphs
2. **Verified Commands** - Commands that don't work waste 500+ tokens debugging
3. **Pointer Principle** - Point to files, don't duplicate content
4. **Time Estimates** - Help agents choose appropriate test scope
5. **Golden Samples** - One example file beats pages of explanation
6. **Heuristics Tables** - Eliminate decision ambiguity

### Token-Saving Sections

| Section | Saves | How |
|---------|-------|-----|
| Commands (verified) | 500+ tokens | No debugging broken commands |
| File Map | 3-5 search cycles | Direct navigation |
| Golden Samples | Full rewrites | Correct patterns first time |
| Utilities List | Duplicate code | Reuse existing helpers |
| Heuristics | User correction cycles | Autonomous decisions |
| Codebase State | Breaking changes | Avoid legacy/migration code |

## Capabilities

- **Thin root files** (~50 lines) with precedence rules and agent-optimized tables
- **Scoped files** for subsystems (backend/, frontend/, internal/, cmd/)
- **Auto-extracted commands** from Makefile, package.json, composer.json, go.mod
- **Language-specific templates** for Go, PHP, TypeScript, Python, hybrid projects
- **Freshness checking** - Detects if AGENTS.md files are outdated by comparing their "Last updated" date with git commits
- **Automatic timestamps** - All generated files include creation/update dates in the header
- **Documentation extraction** - Parses README.md, CONTRIBUTING.md, SECURITY.md, CHANGELOG.md
- **Platform file extraction** - Parses .github/, .gitlab/ templates, CODEOWNERS, dependabot.yml
- **IDE settings extraction** - Parses .editorconfig, .vscode/, .idea/, .phpstorm/
- **AI agent config extraction** - Parses .cursor/, .claude/, .windsurf/, copilot-instructions.md
- **Extraction summary** - Verbose mode shows all detected settings and their sources

## Running Scripts

### Generating AGENTS.md Files

To generate AGENTS.md files for a project:

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

### Validating Structure

To validate AGENTS.md structure compliance:

```bash
scripts/validate-structure.sh /path/to/project
```

Options:
- `--check-freshness, -f` - Also check if files are up to date with git commits
- `--verbose, -v` - Show detailed output

### Checking Freshness

To check if AGENTS.md files are up to date with recent git commits:

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

### Detecting Project Type

To detect project language, version, and build tools:

```bash
scripts/detect-project.sh /path/to/project
```

### Detecting Scopes

To identify directories that should have scoped AGENTS.md files:

```bash
scripts/detect-scopes.sh /path/to/project
```

### Extracting Commands

To extract build commands from Makefile, package.json, composer.json, or go.mod:

```bash
scripts/extract-commands.sh /path/to/project
```

### Extracting Documentation

To extract information from README.md, CONTRIBUTING.md, SECURITY.md, and other documentation:

```bash
scripts/extract-documentation.sh /path/to/project
```

### Extracting Platform Files

To extract information from .github/, .gitlab/, CODEOWNERS, dependabot.yml, etc.:

```bash
scripts/extract-platform-files.sh /path/to/project
```

### Extracting IDE Settings

To extract information from .editorconfig, .vscode/, .idea/, etc.:

```bash
scripts/extract-ide-settings.sh /path/to/project
```

### Extracting AI Agent Configs

To extract information from .cursor/, .claude/, copilot-instructions.md, etc.:

```bash
scripts/extract-agent-configs.sh /path/to/project
```

### Verifying Content Accuracy

**CRITICAL: Always run this before considering AGENTS.md files complete.**

To verify that AGENTS.md content matches actual codebase state:

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

### Verifying Commands Work

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

## Using Reference Documentation

### AGENTS.md Analysis

When understanding best practices and patterns, consult `references/analysis.md` for analysis of 21 real-world AGENTS.md files.

### Directory Coverage

When determining which directories need AGENTS.md files, consult `references/directory-coverage.md` for guidance on PHP/TYPO3, Go, and TypeScript project structures.

### Real-World Examples

When needing concrete examples of AGENTS.md files, consult `references/examples/`:

| Project | Files | Description |
|---------|-------|-------------|
| `coding-agent-cli/` | Root + scripts scope | CLI tool example |
| `ldap-selfservice/` | Root + internal scopes | Go web app with multiple scopes |
| `simple-ldap-go/` | Root + examples scope | Go library example |
| `t3x-rte-ckeditor-image/` | Root + Classes scope | TYPO3 extension example |

## Using Asset Templates

### Root Templates

When generating root AGENTS.md files, the scripts use these templates:

- `assets/root-thin.md` - Minimal root template (~30 lines) with precedence rules and scope index
- `assets/root-verbose.md` - Detailed root template (~100 lines) with architecture overview and examples

### Scoped Templates

When generating scoped AGENTS.md files, the scripts use language-specific templates:

- `assets/scoped/backend-go.md` - Go backend patterns (packages, error handling, testing)
- `assets/scoped/backend-php.md` - PHP backend patterns (PSR, DI, security)
- `assets/scoped/backend-typo3.md` - TYPO3 extension patterns (TCA, Extbase, Fluid, TYPO3 CGL)
- `assets/scoped/backend-oro.md` - Oro bundle patterns (datagrids, workflows, ACL, message queue)
- `assets/scoped/cli.md` - CLI patterns (flags, output, error codes)
- `assets/scoped/frontend-typescript.md` - TypeScript frontend patterns (components, state, testing)

## Supported Project Types

| Language | Project Types |
|----------|---------------|
| Go | Libraries, web apps (Fiber/Echo/Gin), CLI (Cobra/urfave) |
| PHP | Composer packages, Laravel/Symfony |
| PHP/TYPO3 | TYPO3 extensions (auto-detected via `ext_emconf.php`) |
| PHP/Oro | OroCommerce, OroPlatform, OroCRM bundles |
| TypeScript | React, Next.js, Vue, Node.js |
| Python | pip, poetry, Django, Flask, FastAPI |
| Hybrid | Multi-language projects (auto-creates scoped files per stack) |

## Output Structure

### Root File

Root AGENTS.md (~50-80 lines) contains agent-optimized sections:

| Section | Purpose | Format |
|---------|---------|--------|
| **Commands (verified)** | Executable commands with time estimates | Table with ~Time column |
| **File Map** | Directory purposes for navigation | `dir/ → purpose` format |
| **Golden Samples** | Canonical patterns to follow | Table: For / Reference / Key patterns |
| **Utilities List** | Existing helpers to reuse | Table: Need / Use / Location |
| **Heuristics** | Quick decision rules | Table: When / Do |
| **Boundaries** | Always/Ask/Never rules | Three-tier list |
| **Codebase State** | Migrations, tech debt, known issues | Bullet list |
| **Terminology** | Domain-specific terms | Table: Term / Means |
| **Scope Index** | Links to scoped files | List with descriptions |

### Scoped Files

Scoped AGENTS.md files cover six core areas (per [GitHub best practices](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/)):
1. **Commands** - Executable build, test, lint commands
2. **Testing** - Test conventions and execution
3. **Project Structure** - Architecture and key files
4. **Code Style** - Formatting and conventions
5. **Git Workflow** - Commit/PR guidelines
6. **Boundaries** - Always do / Ask first / Never do

Additional recommended sections:
- Overview
- Setup/Prerequisites
- Security
- Good vs Bad examples
- When stuck
- House Rules (for scoped overrides)

## AI Tool Compatibility

### Claude Code

Claude Code centers on CLAUDE.md files. For compatibility, use the `--claude-shim` flag to generate a CLAUDE.md that imports AGENTS.md:

```bash
scripts/generate-agents.sh /path/to/project --claude-shim
```

This creates a minimal CLAUDE.md:
```markdown
<!-- Auto-generated shim for Claude Code compatibility -->
@import AGENTS.md
```

This ensures AGENTS.md remains the source of truth while Claude Code can access it.

### OpenAI Codex

Codex uses stacking semantics with AGENTS.override.md for per-directory overrides:

1. **Concatenation order:** `~/.codex/AGENTS.md` → root → nested directories → current dir
2. **Override files:** Place `AGENTS.override.md` in directories to add/override rules
3. **Size limit:** Default 32 KiB cap - keep root AGENTS.md lean so nested files aren't crowded out

**Best practices for Codex:**
- Keep root AGENTS.md under 4 KiB (leaves room for 7+ nested files)
- Use `--style=thin` template for optimal Codex compatibility
- Move detailed rules to scoped AGENTS.md files in subdirectories
- Use AGENTS.override.md for directory-specific behavior changes

Example override structure:
```
project/
├── AGENTS.md                    # Thin root (~2 KiB)
├── src/
│   ├── AGENTS.md               # Source patterns
│   └── AGENTS.override.md      # Override root rules for src/
└── tests/
    ├── AGENTS.md               # Test patterns
    └── AGENTS.override.md      # Allow larger PRs in tests/
```

### GitHub Copilot

GitHub Copilot uses `.github/copilot-instructions.md` for repository-wide instructions. This skill extracts existing Copilot instructions and can coexist with AGENTS.md files.

## Directory Coverage

When creating AGENTS.md files, create them in ALL key directories:

| Directory | Purpose |
|-----------|---------|
| Root | Precedence, architecture overview |
| `Classes/` or `src/` | Source code patterns |
| `Configuration/` or `config/` | Framework config |
| `Documentation/` or `docs/` | Doc standards |
| `Resources/` or `assets/` | Templates, assets |
| `Tests/` | Testing patterns |

---

> **Contributing:** https://github.com/netresearch/agents-skill
