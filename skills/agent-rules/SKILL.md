---
name: agent-rules
version: "3.3.0"
description: "Use when creating or updating AGENTS.md files, .github/copilot-instructions.md, or other AI agent rule files, onboarding AI agents to a project, standardizing agent documentation, or when anyone mentions AGENTS.md, agent rules, project onboarding, or codebase documentation for AI agents."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
---

# AGENTS.md Generator Skill

## Overview

Generate and maintain AGENTS.md files following the [agents.md convention](https://agents.md/). AGENTS.md is FOR AGENTS, not humans.

## When to Use

- Creating a new project and establishing baseline AGENTS.md
- Standardizing existing projects with consistent agent documentation
- Ensuring multi-repo consistency across repositories
- Checking if AGENTS.md files are current with recent code changes
- Onboarding AI agents to an unfamiliar codebase

## Quick Reference

| Script | Purpose |
|--------|---------|
| `scripts/generate-agents.sh PATH` | Generate AGENTS.md files |
| `scripts/validate-structure.sh PATH` | Validate structure compliance |
| `scripts/check-freshness.sh PATH` | Check if files are outdated vs git commits |
| `scripts/verify-content.sh PATH` | Verify documented files/commands match codebase |
| `scripts/verify-commands.sh PATH` | Verify documented commands execute |
| `scripts/detect-project.sh PATH` | Detect language, version, build tools |
| `scripts/detect-scopes.sh PATH` | Identify directories needing scoped files |
| `scripts/extract-commands.sh PATH` | Extract commands from build configs |

See `references/scripts-guide.md` for full options and validation checklist.

## Core Principles

- **Structured over Prose** -- tables and maps parse faster than paragraphs
- **Verified Commands** -- commands that don't work waste 500+ tokens debugging
- **Pointer Principle** -- point to files, don't duplicate content
- **Golden Samples** -- one example file beats pages of explanation
- **Audit Before Generating** -- discover existing docs and pain points before running scripts

## Language Choice

Default to English. Exception: match your code's naming language to prevent agents mixing languages.

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Bash | 4.3+ | Nameref variables (`local -n`). macOS: `brew install bash` |
| jq | 1.5+ | JSON processing |
| git | 2.0+ | For git history analysis |

## Cross-Agent Compatibility

AGENTS.md is not natively supported by all coding agents. After generating AGENTS.md files, **always create symlinks** for agents that use their own instruction file format:

```bash
# Recommended: use --symlinks flag during generation
scripts/generate-agents.sh /path/to/project --symlinks

# Or create manually at every level with an AGENTS.md:
ln -s AGENTS.md CLAUDE.md    # Claude Code (on-demand loading)
ln -s AGENTS.md GEMINI.md    # Gemini CLI (hierarchical loading)
```

**Why symlinks are critical for Claude Code**: Claude Code loads subdirectory CLAUDE.md files on demand when working in that directory. Without CLAUDE.md symlinks, subdirectory AGENTS.md files are **never loaded** — even if the root file links to them. Root-level instructions to "read nearest AGENTS.md" are insufficient; agents acknowledge them but don't act. (Verified March 2026.)

**Commit symlinks to git.** They are 9 bytes each and work on all platforms.

### Runtime agent detection

When this skill runs, check the environment to detect the current coding agent and warn about compatibility:

| Variable / Signal | Agent | Action needed |
|---|---|---|
| `CLAUDE_CODE` set, or parent is `claude` | Claude Code | Create CLAUDE.md symlinks if missing |
| `CURSOR_*` env vars, or `.cursor/` exists | Cursor | None (native AGENTS.md support) |
| `WINDSURF_*` env vars | Windsurf | None (native support) |
| `GEMINI_CLI` set, or `GEMINI.md` exists | Gemini CLI | Create GEMINI.md symlinks if missing |
| `.aider.conf.yml` exists | Aider | Warn: add `read: AGENTS.md` to config |
| `.continue/` exists | Continue.dev | Warn: copy/link into `.continue/rules/` |
| `.amazonq/` exists | Amazon Q | Warn: copy into `.amazonq/rules/` |
| `.clinerules/` exists | Cline | Warn: copy/link into `.clinerules/` |

After generation, **auto-create missing symlinks** for Claude Code and Gemini CLI. For other agents, print a warning with the required manual step.

### .gitignore guidance

CLAUDE.md and GEMINI.md symlinks should be **committed**, not ignored. If a project's `.gitignore` excludes them, warn the user. These are the primary mechanism for cross-agent compatibility and must be in the repo for all contributors.

See [`references/ai-tool-compatibility.md`](references/ai-tool-compatibility.md) for the full 16-agent compatibility matrix.

## References

Detailed documentation in `references/`:

| File | Contents |
|------|----------|
| [`verification-guide.md`](references/verification-guide.md) | Verification steps, name matching, command verification, design principles |
| [`scripts-guide.md`](references/scripts-guide.md) | Script options, post-generation validation checklist |
| [`ai-tool-compatibility.md`](references/ai-tool-compatibility.md) | 16-agent compatibility matrix, symlink strategy, per-agent mitigations |
| [`output-structure.md`](references/output-structure.md) | Root/scoped sections, auto-generate vs manual curation |
| [`analysis.md`](references/analysis.md) | Analysis of 21 real-world AGENTS.md files |
| [`directory-coverage.md`](references/directory-coverage.md) | Coverage guidance for PHP/TYPO3, Go, TypeScript |
| [`examples/`](references/examples/) | Complete examples (coding-agent-cli, ldap-selfservice, simple-ldap-go, t3x-rte-ckeditor-image) |

## Asset Templates

Root templates in `assets/`: `root-thin.md` (~30 lines, default), `root-verbose.md` (~100 lines).

Scoped templates in `assets/scoped/`: `backend-go.md`, `backend-php.md`, `typo3.md`, `oro.md`, `cli.md`, `frontend-typescript.md`.

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
