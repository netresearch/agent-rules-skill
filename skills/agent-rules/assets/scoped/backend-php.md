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
{{PHP_VERSION_LINE}}
{{FRAMEWORK_LINE}}
{{PHP_EXTENSIONS_LINE}}
{{ENV_VARS_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
{{TYPECHECK_LINE}}
{{FORMAT_LINE}}
{{LINT_LINE}}
{{TEST_LINE}}
{{BUILD_LINE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- Follow PSR-12 coding standard
- Use strict types: `declare(strict_types=1);`
- Type hints: always use for parameters and return types
- Naming: `camelCase` for methods, `PascalCase` for classes
- Visibility: always declare (public, protected, private)
- PHPDoc: required for public APIs, include `@param` and `@return`
{{FRAMEWORK_CONVENTIONS}}
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Validate and sanitize all user inputs
- Use prepared statements for database queries
- Escape output in templates
- Never use dynamic code execution functions
- Sensitive data: never log or expose in errors
- CSRF protection: enable for all forms
- XSS protection: escape all user-generated content
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
{{TEST_CHECKLIST_LINE}}
{{TYPECHECK_CHECKLIST_LINE}}
{{FORMAT_CHECKLIST_LINE}}
- [ ] No deprecated functions used
- [ ] Public methods have PHPDoc
- [ ] Security: inputs validated, outputs escaped
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Check PHP documentation: https://www.php.net
{{FRAMEWORK_DOCS_LINE}}
- Review existing patterns in this codebase
- Check root AGENTS.md for project-wide conventions
<!-- AGENTS-GENERATED:END help -->

<!-- AGENTS-GENERATED:START skill-reference -->
## Skill Reference
> For PHP 8.x modernization, type safety, and PHPStan compliance:
> **Invoke skill:** `php-modernization`
<!-- AGENTS-GENERATED:END skill-reference -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
