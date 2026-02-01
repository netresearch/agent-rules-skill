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
{{NODE_VERSION_LINE}}
{{FRAMEWORK_LINE}}
{{PACKAGE_MANAGER_LINE}}
{{ENV_VARS_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
- Install: `{{INSTALL_CMD}}`
- Typecheck: `{{TYPECHECK_CMD}}`
- Lint: `{{LINT_CMD}}`
- Format: `{{FORMAT_CMD}}`
- Test: `{{TEST_CMD}}`
- Build: `{{BUILD_CMD}}`
- Dev server: `{{DEV_CMD}}`
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- TypeScript strict mode enabled
- Use functional components with hooks (React)
- Naming: `camelCase` for variables/functions, `PascalCase` for components
- File naming: `ComponentName.tsx`, `utilityName.ts`
- Imports: group and sort (external, internal, types)
- CSS: {{CSS_APPROACH}} (CSS Modules, Tailwind, styled-components, etc.)
{{FRAMEWORK_CONVENTIONS}}
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Sanitize user inputs before rendering
- Raw HTML rendering only with sanitized content (use DOMPurify)
- Validate environment variables at build time
- Never expose secrets in client-side code
- Use HTTPS for all API calls
- Implement CSP headers
- WCAG 2.2 AA accessibility compliance
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
{{TEST_CHECKLIST_LINE}}
{{TYPECHECK_CHECKLIST_LINE}}
{{LINT_CHECKLIST_LINE}}
{{FORMAT_CHECKLIST_LINE}}
- [ ] Accessibility: keyboard navigation works, ARIA labels present
- [ ] Responsive: tested on mobile, tablet, desktop
- [ ] Performance: no unnecessary re-renders
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
{{FRAMEWORK_DOCS_LINE}}
- Review TypeScript handbook: https://www.typescriptlang.org/docs/
- Check root AGENTS.md for project-wide conventions
- Review existing components for patterns
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
