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
{{SETUP_INSTRUCTIONS}}
{{CLI_FRAMEWORK_LINE}}
{{BUILD_OUTPUT_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
{{BUILD_LINE}}
{{RUN_LINE}}
{{TEST_LINE}}
{{LINT_LINE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
{{CLI_FRAMEWORK_CONVENTION_LINE}}
- Provide `--help` for all commands and subcommands
- Use `--version` to display version information
- Exit codes: 0 = success, 1 = general error, 2 = usage error
- Output: structured (JSON) for scripts, human-readable for interactive
- Errors: write to stderr, not stdout
- Progress: show for long-running operations
- Interactive prompts: support non-interactive mode with flags
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Validate all file paths and prevent directory traversal
- Never execute user-provided code without explicit confirmation
- Sensitive data: never log or display in plain text
- Config files: validate schema and permissions
- Network operations: timeout and retry with backoff
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] `--help` text is clear and accurate
- [ ] `--version` displays correct version
- [ ] Exit codes are correct
- [ ] Errors go to stderr
- [ ] Long operations show progress
- [ ] Works in non-interactive mode
- [ ] Tests cover main workflows
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
{{CLI_FRAMEWORK_DOCS_LINE}}
- Check existing commands for patterns
- Test with `--help` to ensure clarity
- Check root AGENTS.md for project conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
