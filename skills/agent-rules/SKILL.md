---
name: agent-rules
description: "Use when creating or updating AGENTS.md files, .github/copilot-instructions.md, or other AI agent rule files, onboarding AI agents to a project, standardizing agent documentation, or when anyone mentions AGENTS.md, agent rules, project onboarding, or codebase documentation for AI agents."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
compatibility: "Requires bash 4.3+, jq 1.5+, git 2.0+."
metadata:
  author: Netresearch DTT GmbH
  version: "3.4.0"
  repository: https://github.com/netresearch/agent-rules-skill
allowed-tools: Bash(git:*) Bash(jq:*) Bash(grep:*) Bash(find:*) Bash(bash:*) Read Glob Grep
---

# AGENTS.md Generator Skill

Generate and maintain AGENTS.md files following the [agents.md convention](https://agents.md/). AGENTS.md is FOR AGENTS, not humans.

## When to Use

- Creating or updating AGENTS.md for new/existing projects
- Standardizing agent documentation across repositories
- Checking if AGENTS.md files are current with recent code changes
- Onboarding AI agents to an unfamiliar codebase

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/generate-agents.sh PATH` | Generate AGENTS.md files |
| `scripts/validate-structure.sh PATH` | Validate structure compliance |
| `scripts/check-freshness.sh PATH` | Check if files are outdated |
| `scripts/verify-content.sh PATH` | Verify documented files/commands match codebase |
| `scripts/verify-commands.sh PATH` | Verify documented commands execute |
| `scripts/detect-project.sh PATH` | Detect language, version, build tools |
| `scripts/detect-scopes.sh PATH` | Identify directories needing scoped files |
| `scripts/extract-commands.sh PATH` | Extract commands from build configs |
| `scripts/extract-ci-rules.sh PATH` | Extract CI quality gates and version matrix |
| `scripts/extract-architecture-rules.sh PATH` | Extract module boundaries |
| `scripts/extract-adrs.sh PATH` | Extract architectural decision records |
| `scripts/extract-github-rulesets.sh PATH` | Extract GitHub rulesets and merge rules |

See `references/scripts-guide.md` for full options.

## Core Principles

- **Structured over Prose** -- tables and maps parse faster than paragraphs
- **Verified Commands** -- commands that don't work waste tokens debugging
- **Pointer Principle** -- point to files, don't duplicate content
- **Audit Before Generating** -- discover existing docs before running scripts

## Cross-Agent Compatibility

After generating AGENTS.md, **create symlinks** for agents using their own format:

```bash
scripts/generate-agents.sh /path/to/project --symlinks
# Or manually: ln -s AGENTS.md CLAUDE.md && ln -s AGENTS.md GEMINI.md
```

Claude Code loads subdirectory CLAUDE.md on demand -- without symlinks, subdirectory AGENTS.md files are never loaded. Commit symlinks to git (9 bytes each).

See [`references/ai-tool-compatibility.md`](references/ai-tool-compatibility.md) for the full 16-agent compatibility matrix.

## References

| File | Contents |
|------|----------|
| [`verification-guide.md`](references/verification-guide.md) | Verification steps, design principles |
| [`scripts-guide.md`](references/scripts-guide.md) | Script options, validation checklist |
| [`ai-tool-compatibility.md`](references/ai-tool-compatibility.md) | 16-agent compatibility matrix |
| [`output-structure.md`](references/output-structure.md) | Root/scoped sections |
| [`examples/`](references/examples/) | Complete examples |

## Templates

Root: `assets/root-thin.md` (default), `root-verbose.md`. Scoped: `assets/scoped/` -- `backend-go.md`, `backend-php.md`, `python-modern.md`, `typo3.md`, `symfony.md`, `skill-repo.md`, `cli.md`, `frontend-typescript.md`, `oro.md`.

## Supported Projects

Go, PHP (Composer/Laravel/Symfony/TYPO3/Oro), TypeScript (React/Next/Vue/Node), Python (pip/poetry/ruff/mypy), Skill repos, Hybrid (multi-stack with auto-scoping).
