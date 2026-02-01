<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Managed by agent: keep sections and order; edit content, not structure -->
<!-- Last updated: {{TIMESTAMP}} | Last verified: {{VERIFIED_TIMESTAMP}} -->

# AGENTS.md

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Commands (verified ✓)
| Task | Command | ~Time |
|------|---------|-------|
| Typecheck | {{TYPECHECK_CMD}} | {{TYPECHECK_TIME}} |
| Lint | {{LINT_CMD}} | {{LINT_TIME}} |
| Format | {{FORMAT_CMD}} | {{FORMAT_TIME}} |
| Test (single) | {{TEST_SINGLE_CMD}} | ~2s |
| Test (all) | {{TEST_CMD}} | {{TEST_TIME}} |
| Build | {{BUILD_CMD}} | {{BUILD_TIME}} |

> If commands fail, run `scripts/verify-agents-md.sh` or ask user to update.

## File Map
```
{{FILE_MAP}}
```

## Golden Samples (follow these patterns)
| For | Reference | Key patterns |
|-----|-----------|--------------|
{{GOLDEN_SAMPLES}}

## Utilities (check before creating new)
| Need | Use | Location |
|------|-----|----------|
{{UTILITIES_LIST}}

## Heuristics (quick decisions)
| When | Do |
|------|-----|
{{HEURISTICS}}
| Adding dependency | Ask first - we minimize deps |
| Unsure about pattern | Check Golden Samples above |

## Boundaries

### Always Do
- Run pre-commit checks before committing
- Add tests for new code paths
- Use conventional commit format: `type(scope): subject`
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
{{CODEBASE_STATE}}

## Terminology
| Term | Means |
|------|-------|
{{TERMINOLOGY}}

## Index of scoped AGENTS.md
{{SCOPE_INDEX}}

## When instructions conflict
The nearest `AGENTS.md` wins. Explicit user prompts override files.
{{LANGUAGE_SPECIFIC_CONFLICT_RESOLUTION}}
