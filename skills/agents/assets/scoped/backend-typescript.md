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
{{NODE_VERSION_LINE}}
{{PACKAGE_MANAGER_LINE}}
{{RUNTIME_LINE}}
{{ENV_VARS_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
{{TYPECHECK_LINE}}
{{FORMAT_LINE}}
{{LINT_LINE}}
{{TEST_LINE}}
{{BUILD_LINE}}
{{DEV_LINE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- Use TypeScript strict mode (`strict: true` in tsconfig)
- No `any` without explicit justification comment
- Prefer `interface` over `type` for object shapes
- Naming: `camelCase` for functions/vars, `PascalCase` for classes/types
- Async/await over raw Promises
- Prefer `const` over `let`, never use `var`
- Destructure objects and arrays when appropriate
{{FRAMEWORK_CONVENTIONS}}
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Validate all user inputs (use zod or similar)
- Parameterized queries only (no string concatenation)
- Never use dynamic code execution with user data
- Sensitive data: never log or expose in errors
- Environment: use dotenv, never hardcode secrets
- CORS: configure explicitly, no wildcard in production
- Rate limiting: implement for public endpoints
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
{{TEST_CHECKLIST_LINE}}
{{TYPECHECK_CHECKLIST_LINE}}
{{LINT_CHECKLIST_LINE}}
{{FORMAT_CHECKLIST_LINE}}
- [ ] No `any` types without justification
- [ ] API endpoints have validation
- [ ] Error responses don't leak internals
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Check Node.js docs: https://nodejs.org/docs
- TypeScript handbook: https://www.typescriptlang.org/docs
- Review existing patterns in this codebase
- Check root AGENTS.md for project-wide conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
