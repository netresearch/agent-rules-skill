<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: 2026-02-03 -->

# AGENTS.md — web

<!-- AGENTS-GENERATED:START overview -->
## Overview
Frontend application (TypeScript/React/Vue)
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START filemap -->
## Key Files

<!-- AGENTS-GENERATED:END filemap -->

<!-- AGENTS-GENERATED:START golden-samples -->
## Golden Samples (follow these patterns)

<!-- AGENTS-GENERATED:END golden-samples -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
- Node version: >=20.0.0
- Framework: react
- Package manager: npm
- Environment variables: See .env.example
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
- Install: `npm install`
- Typecheck: `npm run typecheck`
- Lint: `npm run lint`
- Format: `npx prettier --write .`
- Test: `npm test`
- Build: `npm run build`
- Dev server: `npm run dev`
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- TypeScript strict mode enabled
- Use functional components with hooks (React)
- Naming: `camelCase` for variables/functions, `PascalCase` for components
- File naming: `ComponentName.tsx`, `utilityName.ts`
- Imports: group and sort (external, internal, types)
- CSS: CSS Modules (CSS Modules, Tailwind, styled-components, etc.)
- Use functional components with hooks
- Avoid class components
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
- [ ] Tests pass: `npm test`
- [ ] TypeScript compiles: `npm run typecheck`
- [ ] Lint clean: `npm run lint`
- [ ] Formatted: `npx prettier --write .`
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
- Check React documentation: https://react.dev
- Review TypeScript handbook: https://www.typescriptlang.org/docs/
- Check root AGENTS.md for project-wide conventions
- Review existing components for patterns
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
