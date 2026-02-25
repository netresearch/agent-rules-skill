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
## Setup & environment
{{DOCKER_VERSION_LINE}}
{{COMPOSE_VERSION_LINE}}
{{REGISTRY_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
docker/                      # or deploy/, .docker/, infrastructure/
  Dockerfile                 → Main application image
  Dockerfile.dev             → Development image (optional)
  docker-compose.yml         → Local development stack
  docker-compose.prod.yml    → Production overrides
  .dockerignore              → Build context exclusions
  entrypoint.sh              → Container entrypoint script
  healthcheck.sh             → Health check script
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START commands -->
## Build & run
| Task | Command |
|------|---------|
| Build image | `docker build -t app .` |
| Run container | `docker run -p 8080:80 app` |
| Start stack | `docker compose up -d` |
| View logs | `docker compose logs -f` |
| Stop stack | `docker compose down` |
| Rebuild | `docker compose up -d --build` |
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Dockerfile conventions
- **Multi-stage builds**: Separate build and runtime stages
- **Non-root user**: Run as non-root user in production
- **Layer caching**: Order instructions from least to most frequently changing
- **Specific versions**: Pin base image versions (e.g., `node:20-alpine`, not `node:latest`)
- **COPY over ADD**: Prefer COPY unless extracting archives
- **.dockerignore**: Exclude unnecessary files from build context

### Naming conventions
| Type | Convention | Example |
|------|------------|---------|
| Dockerfile | `Dockerfile` or `Dockerfile.<variant>` | `Dockerfile.dev` |
| Compose file | `docker-compose.yml` or `compose.yml` | `docker-compose.prod.yml` |
| Image tag | `<registry>/<name>:<version>` | `ghcr.io/org/app:1.2.3` |
| Service name | lowercase with hyphens | `web-app`, `postgres-db` |
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START patterns -->
## Common patterns

### Multi-stage build
```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Runtime stage
FROM node:20-alpine AS runtime
WORKDIR /app
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER appuser
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Health check
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
```

### Compose with profiles
```yaml
services:
  app:
    build: .
    profiles: ["dev", "prod"]
  debug:
    build:
      context: .
      dockerfile: Dockerfile.dev
    profiles: ["dev"]
```
<!-- AGENTS-GENERATED:END patterns -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- **No secrets in images**: Use runtime environment variables or secret mounts
- **Non-root execution**: Always use USER directive in production
- **Minimal base images**: Prefer Alpine or distroless images
- **Scan images**: Use `docker scout`, `trivy`, or similar tools
- **Pin versions**: Avoid `latest` tags for reproducibility
- **Read-only filesystem**: Use `--read-only` when possible
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] Dockerfile builds successfully
- [ ] Image runs without errors
- [ ] Non-root user configured for production
- [ ] .dockerignore excludes sensitive/unnecessary files
- [ ] Health check configured
- [ ] No secrets or credentials in image layers
- [ ] Base image version pinned
- [ ] Multi-stage build used where appropriate
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Docker docs: https://docs.docker.com
- Dockerfile best practices: https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- Compose specification: https://docs.docker.com/compose/compose-file/
- Check existing Dockerfiles in this repo for patterns
- Review root AGENTS.md for project-wide conventions
<!-- AGENTS-GENERATED:END help -->

<!-- AGENTS-GENERATED:START skill-reference -->
## Skill Reference
> For Dockerfile best practices, multi-stage builds, and compose patterns:
> **Invoke skill:** `docker-development`
<!-- AGENTS-GENERATED:END skill-reference -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
