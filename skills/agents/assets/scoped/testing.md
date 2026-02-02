<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}

Test suites, fixtures, and testing utilities for the project.
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
- Install dev dependencies before running tests
- Some tests may require additional setup (see individual test files)
- Use the project's test framework consistently
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Running tests
{{TEST_LINE}}
{{TEST_SINGLE_LINE}}
{{TEST_COVERAGE_LINE}}
{{TEST_WATCH_LINE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START organization -->
## Test organization
- Group tests by feature or module
- Name test files to match source files (e.g., `foo_test.go`, `foo.test.ts`)
- Use descriptive test names that explain the expected behavior
- Keep fixtures and mocks in dedicated directories
<!-- AGENTS-GENERATED:END organization -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- One assertion per test when possible
- Use descriptive test names: `test_should_return_error_when_input_is_empty`
- Avoid testing implementation details; focus on behavior
- Keep tests independent - no shared mutable state
- Mock external dependencies (network, filesystem, time)
- Use table-driven tests for multiple similar cases
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Never commit real credentials in test fixtures
- Use environment variables or mock services for sensitive data
- Sanitize any test data that might contain PII
- Ensure test databases are isolated from production
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] All tests pass locally
- [ ] New functionality has corresponding tests
- [ ] Test names describe expected behavior
- [ ] No hardcoded credentials or sensitive data
- [ ] Mocks are appropriate and maintainable
- [ ] Coverage hasn't decreased significantly
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Check existing tests for patterns
- Review test framework documentation
- Ensure test isolation (no shared state)
- Check root AGENTS.md for project conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
