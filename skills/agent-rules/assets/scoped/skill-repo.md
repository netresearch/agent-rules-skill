<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}
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
- **Plugin manifest**: `.claude-plugin/plugin.json` (name, version, skills array, author URL)
- **Skills**: `skills/<name>/SKILL.md` — one per domain
- **Licensing**: Split MIT (code) + CC-BY-SA-4.0 (content) — entity: `Netresearch DTT GmbH`
- **CI**: Reusable workflows from `netresearch/skill-repo-skill` (`validate.yml`, `auto-merge-deps.yml`)
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
.claude-plugin/
  plugin.json            → Plugin manifest (name, version, skills, author)
skills/
  <skill-name>/
    SKILL.md             → Skill definition (max 500 words)
    assets/              → Templates, scoped AGENTS.md templates
    scripts/             → Shell scripts (bash 4.3+, ShellCheck clean)
    references/          → Extended docs, golden samples, examples
    checkpoints/         → Checkpoint definitions (YAML)
LICENSE-MIT              → MIT license for code
LICENSE-CC-BY-SA-4.0     → CC-BY-SA-4.0 for content
.github/
  workflows/
    lint.yml             → Calls skill-repo-skill validate.yml@main
    auto-merge-deps.yml  → Calls skill-repo-skill auto-merge-deps.yml@main
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
{{LINT_LINE}}
{{VALIDATE_LINE}}
{{SHELLCHECK_LINE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions

### SKILL.md rules
- Max **500 words** — keep it focused and actionable
- Use `references/` for extended documentation (no word limit)
- Front matter: `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`
- Instructions are FOR AGENTS, not humans — be prescriptive, not descriptive

### plugin.json rules
- `version`: semver, bump on release
- `author.url`: must be a valid URL
- `skills[].name` must match directory name under `skills/`

### Shell scripts
- Shebang: `#!/usr/bin/env bash`
- `set -euo pipefail` at top
- ShellCheck clean (no suppressions without justification)
- Use `"$var"` quoting everywhere

### Templates
- Use `{{PLACEHOLDER}}` syntax — whole-line placeholders only
- Wrap auto-generated sections in `<!-- AGENTS-GENERATED:START name -->` / `<!-- AGENTS-GENERATED:END name -->`

### Licensing
- Entity name: **Netresearch DTT GmbH** (never "Netresearch GmbH & Co. KG")
- Code files (`.sh`, `.py`, `.json`): MIT
- Content files (`.md`, `.yaml`): CC-BY-SA-4.0
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START checkpoints -->
## Checkpoints (verification)
- `checkpoints.yaml` defines verifiable steps agents can run
- Each checkpoint: `name`, `command`, `expected` (exit code or output pattern)
- Agents run checkpoints after completing tasks to verify correctness
- Keep checkpoints fast (<10s each)
<!-- AGENTS-GENERATED:END checkpoints -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Never include secrets or credentials in skills
- Validate all user inputs in scripts
- Use placeholder values in examples: `your-api-key`, `example.com`
- Review generated content for sensitive information
- Shell scripts: quote all variables, avoid `eval` with user input
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START ci -->
## CI/CD
- **Validate workflow**: Runs on PR — markdown lint, YAML lint, ShellCheck, plugin.json schema
- **Auto-merge deps**: Merges Renovate/Dependabot PRs after CI passes
- Config files (`.markdownlint-cli2.jsonc`, `.yamllint.yml`) are per-repo; validate.yml provides defaults if missing
- **Releasing**: bump `plugin.json` version, create signed tag, push — release workflow handles the rest
<!-- AGENTS-GENERATED:END ci -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] SKILL.md is under 500 words
- [ ] `plugin.json` version bumped if releasing
- [ ] Shell scripts pass ShellCheck
- [ ] Templates use whole-line `{{PLACEHOLDER}}` syntax
- [ ] Golden samples exist for key patterns
- [ ] Checkpoints are verifiable (fast, deterministic)
- [ ] Entity name is "Netresearch DTT GmbH" in all license files
- [ ] No trailing blank lines in YAML files
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Check existing skill repos for patterns (e.g., `agent-rules-skill`, `go-development-skill`)
- Review `skill-repo-skill` for CI workflow definitions
- Test skills locally with `claude --skill <name>`
- Check root AGENTS.md for project conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
