<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: 2026-02-05 -->

# AGENTS.md — src

<!-- AGENTS-GENERATED:START overview -->
## Overview
Backend services (TypeScript/Node.js)
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START filemap -->
## Key Files
| File | Purpose |
|------|---------|
| `src/config.ts` | (add description) |
| `src/routes/health.ts` | Add database connectivity check here |
| `src/routes/users.ts` | (add description) |
| `src/index.ts` | Middleware |
| `src/utils/logger.ts` | (add description) |
<!-- AGENTS-GENERATED:END filemap -->

<!-- AGENTS-GENERATED:START golden-samples -->
## Golden Samples (follow these patterns)
| Pattern | Reference |
|---------|-----------|
| Standard implementation | `src/controllers/userController.ts` |
<!-- AGENTS-GENERATED:END golden-samples -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
- Install: `pnpm install`
- Node version: >=20.0.0
- Package manager: pnpm
- Environment variables: See .env or .env.example
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
- Typecheck (project-wide): `pnpm typecheck`
- Format: `pnpm format`
- Lint: `pnpm lint`
- Test: `pnpm test`
- Build: `pnpm build`
- Dev server: `pnpm dev`
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
- [ ] Tests pass: `pnpm test`
- [ ] Type check clean: `pnpm typecheck`
- [ ] Lint clean: `pnpm lint`
- [ ] Formatted: `pnpm format`
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
