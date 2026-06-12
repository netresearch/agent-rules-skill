---
name: agent-rules
description: "Use when creating or updating AGENTS.md files, .github/copilot-instructions.md, or other AI agent rule files, onboarding AI agents to a project, standardizing agent documentation, or when anyone mentions AGENTS.md, agent rules, project onboarding, or codebase documentation for AI agents."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
compatibility: "Requires bash 4.3+, jq 1.7+, git 2.0+."
metadata:
  author: Netresearch DTT GmbH
  version: "3.12.0"
  repository: https://github.com/netresearch/agent-rules-skill
allowed-tools: Bash(git:*) Bash(jq:*) Bash(grep:*) Bash(find:*) Bash(bash:*) Read Glob Grep
---

# AGENTS.md Generator Skill

Generate and maintain AGENTS.md files following the [agents.md convention](https://agents.md/). AGENTS.md is FOR AGENTS, not humans.

## When to Use

- Creating or updating AGENTS.md for new/existing projects
- **Scaffolding a new repository** — ship AGENTS.md with the initial commits; retrofitting later needs full re-verification
- Standardizing agent documentation across repositories
- Checking AGENTS.md freshness after code changes
- Onboarding AI agents to an unfamiliar codebase

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/generate-agents.sh PATH` | Generate AGENTS.md files |
| `scripts/validate-structure.sh PATH` | Validate structure compliance |
| `scripts/check-freshness.sh PATH` | Check if files are outdated |
| `scripts/verify-content.sh PATH` | Verify documented files/commands match codebase |
| `scripts/verify-commands.sh PATH` | Verify documented commands execute |
| `scripts/score-agents.sh PATH` | Grade AGENTS.md quality, worst-first |
| `scripts/detect-project.sh PATH` | Detect language, version, build tools |
| `scripts/detect-scopes.sh PATH` | Identify directories needing scoped files |
| `scripts/extract-commands.sh PATH` | Extract commands from build configs |
| `scripts/extract-ci-rules.sh PATH` | Extract CI quality gates and version matrix |
| `scripts/extract-architecture-rules.sh PATH` | Extract module boundaries |
| `scripts/extract-adrs.sh PATH` | Extract architectural decision records |
| `scripts/extract-github-rulesets.sh PATH` | Extract GitHub rulesets and merge rules |

See `references/scripts-guide.md` for full options.

## Workflow

1. **Detect**: `detect-project.sh` + `detect-scopes.sh` to identify stacks and subsystems
2. **Extract**: `extract-commands.sh`, `extract-ci-rules.sh`, etc. to gather facts
3. **Generate**: `generate-agents.sh` with `--style=thin` (default) or `--verbose`
4. **Verify**: `verify-content.sh` + `verify-commands.sh` -- MANDATORY before done

Use `--update` to preserve human-curated content outside `<!-- GENERATED -->` markers.

## Core Principles

- **Structured over Prose** -- tables parse faster than paragraphs
- **Never Fabricate** -- only document what exists; verify every command and path
- **Pointer Principle** -- point to files, don't duplicate content
- **Auto Symlinks** -- CLAUDE.md/GEMINI.md symlinks by default (see [`ai-tool-compatibility.md`](references/ai-tool-compatibility.md))

## References

| File | Contents |
|------|----------|
| [`verification-guide.md`](references/verification-guide.md) | Verification steps, design principles, anti-bloat |
| [`scripts-guide.md`](references/scripts-guide.md) | Script options, validation checklist |
| [`quality-rubric.md`](references/quality-rubric.md) | Quality grading rubric |
| [`ai-tool-compatibility.md`](references/ai-tool-compatibility.md) | 16-agent compatibility matrix |
| [`output-structure.md`](references/output-structure.md) | Root/scoped sections |
| [`git-hooks-setup.md`](references/git-hooks-setup.md) | Hook framework detection and setup |
| [`examples/`](references/examples/) | Complete examples |
| [`ai-contribution-guidelines.md`](references/ai-contribution-guidelines.md) | "3 Cs" framework for AI contributions |
| [`directory-coverage.md`](references/directory-coverage.md) | Scoped-file coverage rationale |

## Templates

Root: `assets/root-thin.md` (default) or `root-verbose.md`. Scoped: `assets/scoped/`, one per stack (Go/PHP/Python/TYPO3/Symfony/Oro/CLI/TS/skill-repo).

## Supported Projects

Go, PHP (Composer/Laravel/Symfony/TYPO3/Oro), TypeScript (React/Next/Vue/Node), Python (pip/poetry/ruff/mypy), Skill repos, Hybrid (auto-scoping).

## See Also

- [`agent-harness-skill`](https://github.com/netresearch/agent-harness-skill) — agent-readiness harness (CI enforcement).
- [`skill-repo-skill`](https://github.com/netresearch/skill-repo-skill) — skill-repo structure (plugin.json, licensing, releases).
