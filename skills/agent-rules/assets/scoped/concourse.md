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
{{PIPELINE_COUNT_LINE}}
{{TASKS_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
ci/
  pipeline.yml          → Main pipeline definition
  pipeline-*.yml        → Additional pipelines (optional)
  tasks/
    build.yml           → Task definitions
    test.yml
    deploy.yml
  scripts/
    build.sh            → Task scripts
    test.sh
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START code-style -->
## Pipeline conventions
- **Resources first**: Define all resources at top of pipeline
- **Jobs reference resources**: Use `get:` and `put:` for resource I/O
- **Tasks are reusable**: Define tasks in separate files under `ci/tasks/`
- **Params over hardcoding**: Use `((params))` for configuration
- **YAML anchors**: Use anchors for repeated configuration

### Naming conventions
| Type | Convention | Example |
|------|------------|---------|
| Resource | kebab-case | `source-code`, `docker-image` |
| Job | kebab-case with verb | `build-app`, `deploy-staging` |
| Task | kebab-case | `run-tests`, `push-image` |
| Param | snake_case | `docker_repo`, `deploy_env` |
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START patterns -->
## Common patterns

### Basic pipeline structure
```yaml
resources:
  - name: source-code
    type: git
    source:
      uri: ((git_uri))
      branch: main

  - name: app-image
    type: registry-image
    source:
      repository: ((docker_repo))

jobs:
  - name: build-and-test
    plan:
      - get: source-code
        trigger: true
      - task: run-tests
        file: source-code/ci/tasks/test.yml
      - task: build-image
        privileged: true
        config:
          platform: linux
          image_resource:
            type: registry-image
            source: {repository: concourse/oci-build-task}
          inputs:
            - name: source-code
          outputs:
            - name: image
          run:
            path: build
      - put: app-image
        params:
          image: image/image.tar
```

### Task definition (ci/tasks/test.yml)
```yaml
platform: linux

image_resource:
  type: registry-image
  source:
    repository: node
    tag: "20"

inputs:
  - name: source-code

run:
  path: /bin/sh
  args:
    - -c
    - |
      cd source-code
      npm ci
      npm test
```

### Multi-environment deployment
```yaml
jobs:
  - name: deploy-staging
    plan:
      - get: source-code
        passed: [build-and-test]
        trigger: true
      - task: deploy
        file: source-code/ci/tasks/deploy.yml
        params:
          ENVIRONMENT: staging

  - name: deploy-production
    plan:
      - get: source-code
        passed: [deploy-staging]
      - task: deploy
        file: source-code/ci/tasks/deploy.yml
        params:
          ENVIRONMENT: production
```

### Using across step for parallel deploys
```yaml
- across:
    - var: region
      values: [us-east-1, eu-west-1, ap-southeast-1]
  task: deploy-region
  file: ci/tasks/deploy.yml
  params:
    REGION: ((.:region))
```
<!-- AGENTS-GENERATED:END patterns -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Store secrets in **Vault** or **CredHub**, never in pipeline YAML
- Use **((params))** syntax for all sensitive values
- **Privileged containers** only for image building (oci-build-task)
- Pin **resource versions** for reproducibility
- Use **webhook tokens** with secrets for triggers
- Review **fly set-pipeline** changes before applying
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] Pipeline validates: `fly validate-pipeline -c pipeline.yml`
- [ ] Resources have appropriate `check_every` intervals
- [ ] Tasks are defined in separate files (not inline)
- [ ] Secrets use ((param)) syntax, not hardcoded
- [ ] Jobs have appropriate `passed:` constraints
- [ ] Triggers are on correct resources only
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Concourse docs: https://concourse-ci.org/docs.html
- Resource types: https://resource-types.concourse-ci.org/
- Pipeline examples: https://concourse-ci.org/examples.html
- Validate locally: `fly validate-pipeline -c pipeline.yml`
- Check existing pipelines in this repo for patterns
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
