<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: 2026-02-05 -->

# AGENTS.md — agents

<!-- AGENTS-GENERATED:START overview -->
## Overview
Claude Code skill/plugin providing AI agent capabilities
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START filemap -->
## Key Files
| File | Purpose |
|------|---------|
| `skills/agent-rules/scripts/verify-commands.sh` | !/usr/bin/env bash |
| `skills/agent-rules/scripts/generate-file-map.sh` | !/usr/bin/env bash |
| `skills/agent-rules/scripts/analyze-git-history.sh` | !/usr/bin/env bash |
| `skills/agent-rules/scripts/detect-utilities.sh` | !/usr/bin/env bash |
| `skills/agent-rules/scripts/extract-platform-files.sh` | !/usr/bin/env bash |
<!-- AGENTS-GENERATED:END filemap -->

<!-- AGENTS-GENERATED:START golden-samples -->
## Golden Samples (follow these patterns)
| Pattern | Reference |
|---------|-----------|
| Standard implementation | `skills/agent-rules/SKILL.md` |
<!-- AGENTS-GENERATED:END golden-samples -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
- Plugin: agents v2.8.0
- Skills: 1 skill(s) in `skills/`
- Install: `composer require netresearch/agent-rules-skill`
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
.claude-plugin/
  plugin.json          → Plugin manifest (name, version, skills)
skills/
  <skill-name>/
    SKILL.md           → Skill definition and instructions
    assets/            → Templates, reference docs
    scripts/           → Shell scripts for automation
    references/        → Examples, golden samples
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
- Lint scripts: `shellcheck skills/*/scripts/*.sh`
- Validate plugin: `jq . .claude-plugin/plugin.json`
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- SKILL.md: Clear, actionable instructions for AI agents
- Shell scripts: Follow ShellCheck recommendations
- Templates: Use `` syntax for variables
- Keep skills focused on one domain/task
- Include checkpoints for verification
- Provide golden samples for pattern demonstration
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START skill-design -->
## Skill design principles
- **Actionable**: Tell agents WHAT to do, not just WHAT things are
- **Verifiable**: Include checkpoints agents can run to verify work
- **Scoped**: One skill = one domain (don't mix concerns)
- **Referenced**: Point to golden samples, not generic examples
- **Minimal**: Include only what agents need; avoid documentation bloat
<!-- AGENTS-GENERATED:END skill-design -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Never include secrets or credentials in skills
- Validate all user inputs in scripts
- Use placeholder values in examples: `your-api-key`, `example.com`
- Review generated content for sensitive information
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] ShellCheck passes: `shellcheck skills/*/scripts/*.sh`
- [ ] SKILL.md instructions are clear and actionable
- [ ] Templates use whole-line placeholders (not inline)
- [ ] Golden samples exist for key patterns
- [ ] Checkpoints are verifiable
- [ ] plugin.json version updated if releasing
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Check existing skills for patterns
- Review Claude Code documentation
- Test skills with `claude --skill <name>`
- Check root AGENTS.md for project conventions
<!-- AGENTS-GENERATED:END help -->
