<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Managed by agent: keep sections and order; edit content, not structure -->
<!-- Last updated: {{TIMESTAMP}} | Last verified: {{VERIFIED_TIMESTAMP}} -->

# AGENTS.md

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Commands{{VERIFIED_STATUS}}
> Source: {{COMMAND_SOURCE}} — CI-sourced commands are most reliable

<!-- AGENTS-GENERATED:START commands -->
| Task | Command | ~Time |
|------|---------|-------|
| Typecheck | {{TYPECHECK_CMD}} | {{TYPECHECK_TIME}} |
| Lint | {{LINT_CMD}} | {{LINT_TIME}} |
| Format | {{FORMAT_CMD}} | {{FORMAT_TIME}} |
| Test (single) | {{TEST_SINGLE_CMD}} | ~2s |
| Test (all) | {{TEST_CMD}} | {{TEST_TIME}} |
| Build | {{BUILD_CMD}} | {{BUILD_TIME}} |
<!-- AGENTS-GENERATED:END commands -->

> If commands fail, verify against Makefile/package.json/composer.json or ask user to update.

## Workflow
1. **Before coding**: Read nearest `AGENTS.md` + check Golden Samples for the area you're touching
2. **After each change**: Run the smallest relevant check (lint → typecheck → single test)
3. **Before committing**: Run full test suite if changes affect >2 files or touch shared code
4. **Before claiming done**: Run verification and **show output as evidence** — never say "try again" or "should work now" without proof

## File Map
<!-- AGENTS-GENERATED:START filemap -->
```
{{FILE_MAP}}
```
<!-- AGENTS-GENERATED:END filemap -->

## Golden Samples (follow these patterns)
<!-- AGENTS-GENERATED:START golden-samples -->
| For | Reference | Key patterns |
|-----|-----------|--------------|
{{GOLDEN_SAMPLES}}
<!-- AGENTS-GENERATED:END golden-samples -->

## Utilities (check before creating new)
<!-- AGENTS-GENERATED:START utilities -->
| Need | Use | Location |
|------|-----|----------|
{{UTILITIES_LIST}}
<!-- AGENTS-GENERATED:END utilities -->

## Heuristics (quick decisions)
<!-- AGENTS-GENERATED:START heuristics -->
| When | Do |
|------|-----|
{{HEURISTICS}}
| Adding dependency | Ask first - we minimize deps |
| Unsure about pattern | Check Golden Samples above |
<!-- AGENTS-GENERATED:END heuristics -->

## Repository Settings
<!-- AGENTS-GENERATED:START repo-settings -->
{{REPO_SETTINGS}}
<!-- AGENTS-GENERATED:END repo-settings -->

## Boundaries

### Always Do
- Run pre-commit checks before committing
- Add tests for new code paths
- Use conventional commit format: `type(scope): subject`
- **Show test output as evidence before claiming work is complete** — never say "try again" or "should work now" without proof
- For upstream dependency fixes: run **full** test suite, not just affected tests
{{LANGUAGE_CONVENTIONS}}

### Ask First
- Adding new dependencies
- Modifying CI/CD configuration
- Changing public API signatures
- Running full e2e test suites
- Repo-wide refactoring or rewrites

### Never Do
- Commit secrets, credentials, or sensitive data
- Modify vendor/, node_modules/, or generated files
- Push directly to main/master branch
- Delete migration files or schema changes
{{LANGUAGE_SPECIFIC_NEVER}}

## Codebase State
<!-- AGENTS-GENERATED:START codebase-state -->
{{CODEBASE_STATE}}
<!-- AGENTS-GENERATED:END codebase-state -->

## Terminology
| Term | Means |
|------|-------|
{{TERMINOLOGY}}

## Index of scoped AGENTS.md
<!-- AGENTS-GENERATED:START scope-index -->
{{SCOPE_INDEX}}
<!-- AGENTS-GENERATED:END scope-index -->

## When instructions conflict
The nearest `AGENTS.md` wins. Explicit user prompts override files.
{{LANGUAGE_SPECIFIC_CONFLICT_RESOLUTION}}
