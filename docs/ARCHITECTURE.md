# Architecture Overview

The agent-rules-skill generates and maintains [AGENTS.md](https://agents.md/) files -- structured Markdown context files designed for AI coding agents. It detects project type, extracts commands and architecture rules, and produces thin root files plus scoped subsystem files.

## Component Map

```
skills/agent-rules/
  SKILL.md              Skill definition (triggers, metadata, allowed tools)
  scripts/              Shell scripts for generation, validation, extraction
    generate-agents.sh  Main entry point: detect project, render templates
    validate-structure.sh  Validate AGENTS.md section compliance
    check-freshness.sh  Detect drift between code and documented state
    detect-project.sh   Language/framework detection (Go, PHP, TS, Python)
    detect-scopes.sh    Identify directories needing scoped AGENTS.md
    extract-commands.sh Extract commands from Makefile/package.json/composer.json
    extract-ci-rules.sh Extract CI quality gates and version matrix
    verify-commands.sh  Run documented commands to confirm they work
    verify-content.sh   Cross-check documented files/commands against codebase
    lib/                Shared helpers (config, summary, template rendering)
  assets/               Root and scoped templates (Go, PHP, TS, Python, TYPO3, etc.)
  references/           Convention docs, compatibility matrix, examples
  checkpoints.yaml      Eval checkpoints
  evals/                Skill evaluation suite
```

## Data Flow

1. **Detection** -- `detect-project.sh` identifies language, framework, build tools
2. **Extraction** -- `extract-*.sh` scripts pull commands, CI rules, ADRs, architecture boundaries
3. **Scoping** -- `detect-scopes.sh` identifies subsystem directories (backend/, frontend/, internal/)
4. **Generation** -- `generate-agents.sh` renders templates into root + scoped AGENTS.md files
5. **Verification** -- `validate-structure.sh`, `verify-content.sh`, `check-freshness.sh` ensure correctness

## Integration with Other Skills

The skill is packaged as an [Agent Skill](https://agentskills.io) and can be installed via the Netresearch marketplace, npx, Composer, or git clone. It is consumed by Claude Code, Cursor, GitHub Copilot, and other skills-compatible AI agents. Generated AGENTS.md files can be symlinked to platform-specific names (CLAUDE.md, GEMINI.md) for cross-agent compatibility.
