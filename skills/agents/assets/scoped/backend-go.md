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
{{INSTALL_LINE}}
{{GO_VERSION_LINE}}
{{GO_TOOLS_LINE}}
{{ENV_VARS_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
{{VET_LINE}}
{{FORMAT_LINE}}
{{LINT_LINE}}
{{TEST_LINE}}
{{TEST_SINGLE_LINE}}
{{BUILD_LINE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- Follow Go 1.{{GO_MINOR_VERSION}} idioms
- Use standard library over external deps when possible
- Errors: wrap with `fmt.Errorf("context: %w", err)`
- Naming: `camelCase` for private, `PascalCase` for exported
- Struct tags: use canonical form (json, yaml, etc.)
- Comments: complete sentences ending with period
- Package docs: first sentence summarizes purpose
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Validate all inputs from external sources
- Use `context.Context` for cancellation and timeouts
- Avoid goroutine leaks: always ensure termination paths
- Sensitive data: never log or include in errors
- SQL: use parameterized queries only
- File paths: validate and sanitize user-provided paths
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
{{TEST_CHECKLIST_LINE}}
{{LINT_CHECKLIST_LINE}}
{{FORMAT_CHECKLIST_LINE}}
- [ ] No goroutine leaks
- [ ] Error messages are descriptive
- [ ] Public APIs have godoc comments
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.

Key patterns:
- Context handling: always pass and respect `context.Context`
- Interfaces: define where used, not where implemented
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Check Go documentation: https://pkg.go.dev
- Review existing patterns in this codebase
- Check root AGENTS.md for project-wide conventions
- Run `go doc <package>` for standard library help
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
