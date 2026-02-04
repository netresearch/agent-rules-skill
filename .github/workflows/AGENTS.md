<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: 2026-02-05 -->

# AGENTS.md — workflows

<!-- AGENTS-GENERATED:START overview -->
## Overview
GitHub Actions workflows and CI/CD automation
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START filemap -->
## Key Files
| File | Purpose |
|------|---------|
| `release.yml` | Release |
| `validate-agents.yml` | Validate AGENTS.md |
<!-- AGENTS-GENERATED:END filemap -->

<!-- AGENTS-GENERATED:START golden-samples -->
## Workflow files
- Workflows: 2 workflow file(s)
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
.github/
  workflows/
    ci.yml              → Main CI workflow (lint, test, build)
    release.yml         → Release/deploy workflow
    dependabot.yml      → Dependency updates
  actions/
    <action-name>/      → Composite actions (reusable)
      action.yml
  CODEOWNERS            → Code ownership rules
  pull_request_template.md
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START code-style -->
## Workflow conventions
- **Pin action versions** with full SHA, not tags (`uses: actions/checkout@abc123...`)
- **Minimal permissions**: Use `permissions:` block, never use `permissions: write-all`
- **Reusable workflows**: Extract common patterns to `.github/workflows/reusable-*.yml`
- **Job dependencies**: Use `needs:` to express dependencies
- **Caching**: Use `actions/cache` for dependencies (npm, composer, go)

### Naming conventions
| Type | Convention | Example |
|------|------------|---------|
| Workflow file | `<purpose>.yml` | `ci.yml`, `release.yml` |
| Workflow name | Title Case | `CI Pipeline`, `Release` |
| Job ID | kebab-case | `build-and-test`, `deploy-staging` |
| Step name | Sentence case | `Install dependencies` |
| Secret | SCREAMING_SNAKE | `DEPLOY_TOKEN`, `NPM_TOKEN` |
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START patterns -->
## Common patterns

### Basic CI workflow
```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af # v4.1.0
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm test
```

### Matrix builds
```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        node: ['18', '20', '22']
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af # v4.1.0
        with:
          node-version: ${{ matrix.node }}
```

### Reusable workflow
```yaml
# .github/workflows/reusable-test.yml
on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
```

### Conditional deployment
```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    needs: [test, build]
    environment: production
    steps:
      - name: Deploy
        run: ./deploy.sh
```
<!-- AGENTS-GENERATED:END patterns -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- **NEVER** expose secrets in logs: use `::add-mask::` for dynamic secrets
- **Pin actions** to full commit SHA, not mutable tags
- **Minimal permissions**: Start with `contents: read`, add only what's needed
- **Environment protection**: Use environments with required reviewers for deploys
- **Secret scanning**: Enable in repository settings
- **Dependency review**: Use `actions/dependency-review-action` for PRs
- **OIDC**: Prefer OIDC over long-lived secrets for cloud providers
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] Actions pinned to full SHA (not tags)
- [ ] Permissions block uses minimal required permissions
- [ ] Secrets are not exposed in logs
- [ ] Workflow syntax valid: `actionlint` or GitHub UI validation
- [ ] Matrix strategy covers required versions/platforms
- [ ] Caching configured for dependencies
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- GitHub Actions docs: https://docs.github.com/en/actions
- Workflow syntax: https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions
- Action marketplace: https://github.com/marketplace?type=actions
- Use `act` for local testing: https://github.com/nektos/act
- Check existing workflows in this repo for patterns
<!-- AGENTS-GENERATED:END help -->
