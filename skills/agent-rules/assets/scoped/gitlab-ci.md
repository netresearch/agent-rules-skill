<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}
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
## Pipeline configuration
{{JOB_COUNT_LINE}}
{{INCLUDES_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## File structure
```
.gitlab-ci.yml          → Main pipeline configuration
.gitlab/
  ci/
    templates/          → Reusable job templates
    jobs/               → Job definitions (included)
  CODEOWNERS            → Code ownership
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START code-style -->
## Pipeline conventions
- Use **stages** to organize job execution order
- **Extend templates** with `extends:` for DRY jobs
- Use **rules:** instead of `only:/except:` (deprecated)
- **Cache dependencies** between jobs
- Use **artifacts** to pass files between stages

### Naming conventions
| Type | Convention | Example |
|------|------------|---------|
| Stage | lowercase | `build`, `test`, `deploy` |
| Job | kebab-case with stage prefix | `build-app`, `test-unit` |
| Variable | SCREAMING_SNAKE | `DEPLOY_ENV`, `CI_TOKEN` |
| Template | `.template-name` (dot prefix) | `.build-template` |
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START patterns -->
## Common patterns

### Basic pipeline structure
```yaml
stages:
  - build
  - test
  - deploy

variables:
  NODE_VERSION: "20"

build-app:
  stage: build
  image: node:${NODE_VERSION}
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

test-unit:
  stage: test
  needs: [build-app]
  script:
    - npm test
```

### Reusable job template
```yaml
.deploy-template:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache curl
  script:
    - ./deploy.sh $ENVIRONMENT

deploy-staging:
  extends: .deploy-template
  variables:
    ENVIRONMENT: staging
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

deploy-production:
  extends: .deploy-template
  variables:
    ENVIRONMENT: production
  rules:
    - if: $CI_COMMIT_TAG
  when: manual
```

### Matrix builds (parallel)
```yaml
test:
  stage: test
  parallel:
    matrix:
      - NODE_VERSION: ["18", "20", "22"]
        OS: ["alpine", "debian"]
  image: node:${NODE_VERSION}-${OS}
  script:
    - npm test
```

### Include external files
```yaml
include:
  - local: '.gitlab/ci/templates.yml'
  - project: 'company/ci-templates'
    ref: main
    file: '/templates/docker.yml'
  - template: Security/SAST.gitlab-ci.yml
```
<!-- AGENTS-GENERATED:END patterns -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Use **protected variables** for secrets (Settings > CI/CD > Variables)
- **Mask variables** to prevent log exposure
- Use **protected branches** for deployment jobs
- Enable **SAST/DAST** scanning templates
- **Pin Docker images** to specific versions/digests
- Use `rules:` with `$CI_COMMIT_TAG` for release workflows
- Review **merge request pipelines** before merging
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] Pipeline syntax valid: use CI/CD > Editor > Validate
- [ ] Jobs use appropriate stages
- [ ] Sensitive variables are masked and protected
- [ ] Artifacts have reasonable `expire_in` values
- [ ] Cache keys are appropriate for the content
- [ ] Rules conditions are correct (not using deprecated only/except)
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- GitLab CI docs: https://docs.gitlab.com/ee/ci/
- CI/CD YAML syntax: https://docs.gitlab.com/ee/ci/yaml/
- Predefined variables: https://docs.gitlab.com/ee/ci/variables/predefined_variables.html
- Use the pipeline editor for validation: CI/CD > Editor
- Check existing `.gitlab-ci.yml` patterns in this repo
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
