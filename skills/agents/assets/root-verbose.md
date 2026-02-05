<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Managed by agent: keep sections and order; edit content, not structure -->
<!-- Last updated: {{TIMESTAMP}} | Last verified: {{VERIFIED_TIMESTAMP}} -->

# AGENTS.md

**Precedence:** The **closest AGENTS.md** to changed files wins. Root holds global defaults only.

## Project Overview
<!-- AGENTS-GENERATED:START project-overview -->
{{PROJECT_DESCRIPTION}}

**Tech Stack**: {{LANGUAGE}} {{VERSION}}, {{BUILD_TOOL}}, {{FRAMEWORK}}
**Type**: {{PROJECT_TYPE}}
<!-- AGENTS-GENERATED:END project-overview -->

## Global Rules
- Keep PRs small (~≤300 net LOC)
- Conventional Commits: `type(scope): subject`
{{LANGUAGE_CONVENTIONS}}

## Boundaries

### Always Do
- Run pre-commit checks before committing
- Add tests for new code paths
- Use conventional commit format: `type(scope): subject`
- Keep dependencies updated
- Validate all user inputs
- **Show test output as evidence before claiming work is complete** — never say "try again" or "should work now" without proof
- For upstream dependency fixes: run **full** test suite, not just affected tests

### Ask First
- Adding new dependencies
- Modifying CI/CD configuration
- Changing public API signatures
- Running full e2e test suites
- Repo-wide refactoring or rewrites
- Modifying security-sensitive code
- Changing database schemas

### Never Do
- Commit secrets, credentials, API keys, or PII
- Modify vendor/, node_modules/, or generated files
- Push directly to main/master branch
- Delete migration files or schema changes
- Disable security features or linting rules
- Hardcode environment-specific values
{{LANGUAGE_SPECIFIC_NEVER}}

## Development Workflow
1. Create feature branch: `git checkout -b feature/description`
2. Make changes with tests
3. Run pre-commit checks (see below)
4. Commit with conventional format
5. Push and create PR
6. Address review feedback
7. Merge when approved

## Agent Work Loop
1. **Before coding**: Read nearest `AGENTS.md` + check Golden Samples for the area you're touching
2. **After each change**: Run the smallest relevant check (lint → typecheck → single test)
3. **Before committing**: Run full test suite if changes affect >2 files or touch shared code
4. **Before claiming done**: Run verification and **show output as evidence** — never say "should work" without proof

## Pre-commit Checks
> Source: {{COMMAND_SOURCE}} — CI-sourced commands are most reliable

<!-- AGENTS-GENERATED:START precommit-checks -->
**Always run before committing:**
- Typecheck: {{TYPECHECK_CMD}}
- Lint: {{LINT_CMD}}
- Format: {{FORMAT_CMD}}
- Tests: {{TEST_CMD}}
- Build: {{BUILD_CMD}}
<!-- AGENTS-GENERATED:END precommit-checks -->

## Code Quality Standards
<!-- AGENTS-GENERATED:START quality-standards -->
{{QUALITY_STANDARDS}}
<!-- AGENTS-GENERATED:END quality-standards -->

## Security & Safety
- Never commit secrets, credentials, or PII
- Validate all user inputs
- Use parameterized queries for database access
- Keep dependencies updated
{{SECURITY_SPECIFIC}}

## Testing Requirements
<!-- AGENTS-GENERATED:START testing -->
- Write tests for new features
- Maintain {{TEST_COVERAGE}}% minimum coverage
- Run fast tests locally: {{TEST_FAST_CMD}}
- Run full suite in CI: {{TEST_FULL_CMD}}
<!-- AGENTS-GENERATED:END testing -->

## Index of Scoped AGENTS.md
<!-- AGENTS-GENERATED:START scope-index -->
{{SCOPE_INDEX}}
<!-- AGENTS-GENERATED:END scope-index -->

## When Instructions Conflict
Nearest AGENTS.md wins. User prompts override files.
{{LANGUAGE_SPECIFIC_CONFLICT_RESOLUTION}}

## Code Examples

### Good Pattern
{{GOOD_EXAMPLE}}

### Avoid
{{BAD_EXAMPLE}}

## Documentation
<!-- AGENTS-GENERATED:START documentation -->
- Architecture: {{ARCHITECTURE_DOC}}
- API docs: {{API_DOC}}
- Contributing: {{CONTRIBUTING_DOC}}
<!-- AGENTS-GENERATED:END documentation -->
