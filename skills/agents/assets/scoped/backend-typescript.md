<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
- Install: `{{INSTALL_CMD}}`
- Node version: {{NODE_VERSION}}
- Package manager: {{PACKAGE_MANAGER}}
- Runtime: {{RUNTIME}}
- Environment variables: {{ENV_VARS}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests (prefer file-scoped)
- Typecheck a file: `{{TYPECHECK_CMD}}`
- Format a file: `{{FORMAT_CMD}} {{FILE_PATH}}`
- Lint a file: `{{LINT_CMD}} {{FILE_PATH}}`
- Test a file: `{{TEST_CMD}} {{FILE_PATH}}`
- Build: {{BUILD_CMD}}
- Dev server: {{DEV_CMD}}
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
- [ ] Tests pass: `{{TEST_CMD}}`
- [ ] Type check clean: `{{TYPECHECK_CMD}}`
- [ ] Lint clean: `{{LINT_CMD}}`
- [ ] Formatted: `{{FORMAT_CMD}}`
- [ ] No `any` types without justification
- [ ] API endpoints have validation
- [ ] Error responses don't leak internals
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Good vs. bad examples
**Good**: Proper types and async/await
```typescript
interface User {
  id: string;
  email: string;
}

async function fetchUser(id: string): Promise<User | null> {
  const user = await db.users.findUnique({ where: { id } });
  return user;
}
```

**Bad**: Using `any` and missing types
```typescript
async function fetchUser(id: any): Promise<any> {
  const user = await db.users.findUnique({ where: { id } });
  return user;
}
```

**Good**: Input validation with zod
```typescript
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
});

app.post('/users', async (req, res) => {
  const data = CreateUserSchema.parse(req.body);
  // data is typed and validated
});
```
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
