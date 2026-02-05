<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
DDEV local development environment configuration. **Use the `typo3-ddev` skill** for setup and multi-version testing.
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START filemap -->
## Key Files
| File | Purpose |
|------|---------|
| `config.yaml` | Main DDEV configuration |
| `docker-compose.*.yaml` | Custom service overrides |
| `commands/host/` | Host-side custom commands |
| `commands/web/` | Container-side custom commands |
| `.env` | Environment variables |
<!-- AGENTS-GENERATED:END filemap -->

<!-- AGENTS-GENERATED:START commands -->
## Common Commands
| Task | Command |
|------|---------|
| Start | `ddev start` |
| Stop | `ddev stop` |
| SSH into container | `ddev ssh` |
| Run composer | `ddev composer ...` |
| Database export | `ddev export-db > dump.sql.gz` |
| Database import | `ddev import-db < dump.sql.gz` |
| View logs | `ddev logs` |
| Restart | `ddev restart` |
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START patterns -->
## Key Patterns
- Use `ddev composer` instead of local composer
- Custom commands in `.ddev/commands/` for project-specific tasks
- Override services with `docker-compose.*.yaml` files
- Use `ddev describe` to see URLs and credentials
- Multi-version testing: change `php_version` in config.yaml
<!-- AGENTS-GENERATED:END patterns -->

<!-- AGENTS-GENERATED:START code-style -->
## Configuration Style
- Keep `config.yaml` minimal, use overrides for complexity
- Document custom commands with `## Description:` header
- Use `#ddev-generated` comment for files DDEV manages
- Pin addon versions for reproducibility
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START checklist -->
## PR Checklist
- [ ] `ddev start` works after changes
- [ ] Custom commands have descriptions
- [ ] No hardcoded paths or credentials
- [ ] Works on macOS, Linux, and Windows (WSL2)
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START skill-reference -->
## Skill Reference
> For DDEV setup, TYPO3 multi-version testing, and custom commands:
> **Invoke skill:** `typo3-ddev`
<!-- AGENTS-GENERATED:END skill-reference -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
