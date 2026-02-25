# Verification Guide

**NEVER trust existing AGENTS.md content as accurate.** Always verify documented information against the actual codebase.

## Mandatory Verification Steps

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

## What to Verify

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

## Critical: Exact Name Matching

File names in AGENTS.md must match actual filenames **exactly**:

| Documented | Actual | Status |
|------------|--------|--------|
| `CowriterAjaxController.php` | `AjaxController.php` | **WRONG** - name mismatch |
| `AjaxController.php` | `AjaxController.php` | Correct |

**Real-world example from t3x-cowriter review:**
- AGENTS.md documented `Controller/CowriterAjaxController.php`
- Actual file was `Controller/AjaxController.php`
- This mismatch confused agents trying to find the file

## Critical: Command Verification

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

## Example Verification Commands

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

## Anti-Patterns to Avoid

- **WRONG:** Updating only dates and counts based on git commits
- **WRONG:** Trusting that existing AGENTS.md was created correctly
- **WRONG:** Copying file lists without verifying they exist
- **WRONG:** Using extracted command output without running it
- **RIGHT:** Extract -> Compare -> Fix discrepancies -> Validate

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
