<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: 2026-02-04 -->

# AGENTS.md — web

<!-- AGENTS-GENERATED:START overview -->
## Overview
Frontend application (TypeScript/React/Vue)
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START filemap -->
## Key Files
| File | Purpose |
|------|---------|
| `internal/web/src/Sidebar.tsx` | (add description) |
| `internal/web/src/App.tsx` | (add description) |
| `internal/web/src/Button.tsx` | (add description) |
| `internal/web/src/Header.tsx` | (add description) |
| `internal/web/src/Footer.tsx` | (add description) |
<!-- AGENTS-GENERATED:END filemap -->

<!-- AGENTS-GENERATED:START golden-samples -->
## Golden Samples (follow these patterns)
| Pattern | Reference |
|---------|-----------|
| Standard implementation | `internal/web/src/Sidebar.tsx` |
<!-- AGENTS-GENERATED:END golden-samples -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
- Framework: react
- Package manager: npm
- Environment variables: See .env.example
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
- Install: `npm install`
- Typecheck: `npx tsc --noEmit`
- Lint: `npx eslint .`
- Format: `npx prettier --write .`
- Test: `npm test`
- Build: `npm run build`
- Dev server: `npm run dev`
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- Follow tsconfig.json compiler options
- Use functional components with hooks
- Naming: `camelCase` for variables/functions, `PascalCase` for components
- File naming: `ComponentName.tsx`, `utilityName.ts`
- Imports: group and sort (external, internal, types)
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
- [ ] TypeScript compiles: `npx tsc --noEmit`
- [ ] Lint clean: `npx eslint .`
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
