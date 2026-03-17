---
name: agent-rules
description: "Use when creating or updating AGENTS.md files, .github/copilot-instructions.md, or other AI agent rule files, onboarding AI agents to a project, or standardizing agent documentation across repositories."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
compatibility: "Requires bash 4.3+, jq 1.5+, git 2.0+."
metadata:
  author: Netresearch DTT GmbH
  version: "3.1.0"
  repository: https://github.com/netresearch/agent-rules-skill
allowed-tools: Bash(git:*) Bash(jq:*) Bash(grep:*) Bash(find:*) Bash(bash:*) Read Glob Grep
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

## References

Detailed documentation in `references/`:

| File | Contents |
|------|----------|
| [`verification-guide.md`](references/verification-guide.md) | Verification steps, name matching, command verification, design principles |
| [`scripts-guide.md`](references/scripts-guide.md) | Script options, post-generation validation checklist |
| [`ai-tool-compatibility.md`](references/ai-tool-compatibility.md) | Claude Code shim, Codex stacking, Copilot integration |
| [`output-structure.md`](references/output-structure.md) | Root/scoped sections, auto-generate vs manual curation |
| [`analysis.md`](references/analysis.md) | Analysis of 21 real-world AGENTS.md files |
| [`directory-coverage.md`](references/directory-coverage.md) | Coverage guidance for PHP/TYPO3, Go, TypeScript |
| [`examples/`](references/examples/) | Complete examples (coding-agent-cli, ldap-selfservice, simple-ldap-go, t3x-rte-ckeditor-image) |

## Templates

Root: `assets/root-thin.md` (default), `root-verbose.md`. Scoped: `assets/scoped/` — `backend-go.md`, `backend-php.md`, `python-modern.md`, `typo3.md`, `symfony.md`, `skill-repo.md`, `cli.md`, `frontend-typescript.md`, `oro.md`.

## Supported Projects

Go, PHP (Composer/Laravel/Symfony/TYPO3/Oro), TypeScript (React/Next/Vue/Node), Python (pip/poetry/ruff/mypy), Skill repos, Hybrid (multi-stack with auto-scoping).
