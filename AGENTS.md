<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Managed by agent: keep sections and order; edit content, not structure -->
<!-- Last updated: 2026-02-01 | Last verified: never -->

# AGENTS.md

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Commands (verified ✓)
<!-- AGENTS-GENERATED:START commands -->
| Task | Command | ~Time |
|------|---------|-------|
| Typecheck |  | ~15s |
| Lint | vendor/bin/php-cs-fixer fix --dry-run | ~10s |
| Format | vendor/bin/php-cs-fixer fix | ~5s |
| Test (single) | vendor/bin/phpunit | ~2s |
| Test (all) | vendor/bin/phpunit | ~30s |
| Build |  | ~30s |
<!-- AGENTS-GENERATED:END commands -->

> If commands fail, run `scripts/verify-commands.sh` or ask user to update.

## File Map
<!-- AGENTS-GENERATED:START filemap -->
```
skills/          → project files
docs/            → documentation
claudedocs/      → documentation
LICENSE/         → project files
```
<!-- AGENTS-GENERATED:END filemap -->

## Golden Samples (follow these patterns)
<!-- AGENTS-GENERATED:START golden-samples -->
| For | Reference | Key patterns |
|-----|-----------|--------------|

<!-- AGENTS-GENERATED:END golden-samples -->

## Utilities (check before creating new)
<!-- AGENTS-GENERATED:START utilities -->
| Need | Use | Location |
|------|-----|----------|

<!-- AGENTS-GENERATED:END utilities -->

## Heuristics (quick decisions)
<!-- AGENTS-GENERATED:START heuristics -->
| When | Do |
|------|-----|
| Adding class | Follow PSR-4 in `Classes/` or `src/` |
| Committing | Use Conventional Commits (feat:, fix:, docs:, etc.) |

| Adding dependency | Ask first - we minimize deps |
| Unsure about pattern | Check Golden Samples above |
<!-- AGENTS-GENERATED:END heuristics -->

## Boundaries

### Always Do
- Run pre-commit checks before committing
- Add tests for new code paths
- Use conventional commit format: `type(scope): subject`
- Follow PSR-12 coding standards and PHP unknown features

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
- Commit composer.lock without composer.json changes
- Modify core framework files

## Codebase State
<!-- AGENTS-GENERATED:START codebase-state -->
- No known migrations or tech debt documented
<!-- AGENTS-GENERATED:END codebase-state -->

## Terminology
| Term | Means |
|------|-------|

## Index of scoped AGENTS.md
<!-- AGENTS-GENERATED:START scope-index -->
- (No scoped AGENTS.md files yet)
<!-- AGENTS-GENERATED:END scope-index -->

## When instructions conflict
The nearest `AGENTS.md` wins. Explicit user prompts override files.
- For PHP-specific patterns, follow PSR standards
