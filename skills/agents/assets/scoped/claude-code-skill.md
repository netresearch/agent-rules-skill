<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}

Claude Code skill/plugin providing AI agent capabilities.
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START filemap -->
## Key Files
{{SCOPE_FILE_MAP}}
<!-- AGENTS-GENERATED:END filemap -->

<!-- AGENTS-GENERATED:START golden-samples -->
## Golden Samples (follow these patterns)
{{SCOPE_GOLDEN_SAMPLES}}
<!-- AGENTS-GENERATED:END golden-samples -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
{{PLUGIN_JSON_LINE}}
{{SKILLS_LINE}}
{{INSTALL_LINE}}
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
{{LINT_LINE}}
{{TEST_LINE}}
{{VALIDATE_LINE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- SKILL.md: Clear, actionable instructions for AI agents
- Shell scripts: Follow ShellCheck recommendations
- Templates: Use `{{PLACEHOLDER}}` syntax for variables
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
{{LINT_CHECKLIST_LINE}}
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

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
