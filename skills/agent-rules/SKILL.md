---
name: agent-rules
description: "Use when creating or updating AGENTS.md files, .github/copilot-instructions.md, or other AI agent rule files, onboarding AI agents to a project, standardizing agent documentation, or when anyone mentions AGENTS.md, agent rules, project onboarding, or codebase documentation for AI agents."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
compatibility: "Requires bash 4.3+, jq 1.7+, git 2.0+."
metadata:
  author: Netresearch DTT GmbH
  version: "3.15.3"
  repository: https://github.com/netresearch/agent-rules-skill
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/*) Bash(bash ${CLAUDE_SKILL_DIR}/scripts/*) Bash(git:*) Bash(jq:*) Bash(grep:*) Bash(find:*) Read Glob Grep
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

Call every script by its full path: `bash ${CLAUDE_SKILL_DIR}/scripts/<name> PATH`. Calling one relative to the working directory is not covered by the frontmatter rule and raises a permission prompt per call.

| Script | Purpose |
|--------|---------|
| `generate-agents.sh PATH` | Generate AGENTS.md files |
| `validate-structure.sh PATH` | Validate structure compliance |
| `check-freshness.sh PATH` | Check if files are outdated |
| `verify-content.sh PATH` | Verify documented files/commands match codebase |
| `verify-commands.sh PATH` | Verify documented commands execute |
| `score-agents.sh PATH` | Grade AGENTS.md quality, worst-first |
| `detect-project.sh PATH` | Detect language, version, build tools |
| `detect-scopes.sh PATH` | Identify directories needing scoped files |
| `extract-commands.sh PATH` | Extract commands from build configs |
| `extract-ci-rules.sh PATH` | Extract CI quality gates and version matrix |
| `extract-architecture-rules.sh PATH` | Extract module boundaries |
| `extract-adrs.sh PATH` | Extract architectural decision records |
| `extract-github-rulesets.sh PATH` | Extract GitHub rulesets and merge rules |

See `references/scripts-guide.md` for full options.

## Workflow

1. **Detect**: `detect-project.sh` + `detect-scopes.sh` — stacks and subsystems
2. **Extract**: `extract-commands.sh`, `extract-ci-rules.sh` — gather facts
3. **Generate**: `generate-agents.sh --style=thin` (default) or `--verbose`
4. **Verify**: `verify-content.sh` + `verify-commands.sh` -- MANDATORY before done

`--update` preserves curated content outside `<!-- GENERATED -->` markers.

## Core Principles

- **Structured over Prose** -- tables parse faster than paragraphs
- **Never Fabricate** -- only document what exists; verify every command and path
- **Pointer Principle** -- point to files, don't duplicate content
- **Auto Symlinks** -- CLAUDE.md/GEMINI.md by default ([`ai-tool-compatibility.md`](references/ai-tool-compatibility.md))

## References

| File | Contents |
|------|----------|
| [`verification-guide.md`](references/verification-guide.md) | Verification steps, anti-bloat, preservation check |
| [`fleet-sync-sweep.md`](references/fleet-sync-sweep.md) | Fleet-wide AGENTS.md sweeps |
| [`scripts-guide.md`](references/scripts-guide.md) | Script options, validation checklist |
| [`quality-rubric.md`](references/quality-rubric.md) | Grading rubric |
| [`ai-tool-compatibility.md`](references/ai-tool-compatibility.md) | 16-agent compatibility matrix |
| [`output-structure.md`](references/output-structure.md) | Root/scoped sections |
| [`git-hooks-setup.md`](references/git-hooks-setup.md) | Hook framework setup |
| [`examples/`](references/examples/) | Complete examples |
| [`ai-contribution-guidelines.md`](references/ai-contribution-guidelines.md) | "3 Cs" AI-contribution framework |
| [`directory-coverage.md`](references/directory-coverage.md) | Scoped-file coverage rationale |
| [`feedback-memory-schema.md`](references/feedback-memory-schema.md) | Approved-learning file format |

## Templates

Root: `assets/root-thin.md` (default) or `root-verbose.md`. Scoped: `assets/scoped/`, one per stack (Go/PHP/Python/TYPO3/Symfony/Oro/CLI/TS/skill-repo).

## Supported Projects

Go, PHP (Composer/Laravel/Symfony/TYPO3/Oro), TypeScript (React/Next/Vue/Node), Python (pip/poetry/ruff/mypy), skill repos, hybrid.

## See Also

- [`agent-harness-skill`](https://github.com/netresearch/agent-harness-skill) — agent-readiness harness (CI enforcement).
- [`skill-repo-skill`](https://github.com/netresearch/skill-repo-skill) — skill-repo structure (plugin.json, licensing, releases).
