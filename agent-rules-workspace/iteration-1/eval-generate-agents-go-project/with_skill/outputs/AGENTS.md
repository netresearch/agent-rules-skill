<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Managed by agent: keep sections and order; edit content, not structure -->
<!-- Last updated: 2026-03-17 | Last verified: 2026-03-17 -->

# AGENTS.md

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Commands (verified)
> Source: Makefile — CI-sourced commands are most reliable

<!-- AGENTS-GENERATED:START commands -->
| Task | Command | ~Time |
|------|---------|-------|
| Vet | `make vet` | ~5s |
| Format check | `make fmt-check` | ~3s |
| Format fix | `make fmt` | ~3s |
| Lint | `make lint` | ~30s |
| Test (single pkg) | `go test -v ./core/...` | ~10s |
| Test (all) | `make test` | ~45s |
| Test (race) | `make test-race` | ~60s |
| Test (integration) | `make test-integration` | ~120s |
| Test (smoke) | `make test-smoke` | ~15s |
| Build | `make build` | ~10s |
| Docker build | `make docker-build` | ~30s |
| Dev setup | `make setup` | ~60s |
| All checks | `make dev-check` | ~90s |
| Security | `make security-check` | ~20s |
| Mutation test | `make mutation-test` | ~300s |
<!-- AGENTS-GENERATED:END commands -->

> If commands fail, verify against Makefile or ask user to update.

## Workflow
1. **Before coding**: Read nearest `AGENTS.md` + check Golden Samples for the area you're touching
2. **After each change**: Run the smallest relevant check (lint -> typecheck -> single test)
3. **Before committing**: Run full test suite if changes affect >2 files or touch shared code
4. **Before claiming done**: Run verification and **show output as evidence** -- never say "try again" or "should work now" without proof

## File Map
<!-- AGENTS-GENERATED:START filemap -->
```
ofelia.go        -> main entry point (CLI parser, subcommands)
cli/             -> CLI commands: daemon, validate, config, init, doctor, hash-password
core/            -> job scheduling engine, job types, Docker integration, resilience
core/adapters/   -> Docker adapter (hexagonal architecture), mock adapter
core/domain/     -> domain types: container, event, exec, image, network, service
core/ports/      -> port interfaces for Docker operations
config/          -> input validation, command sanitization
middlewares/     -> notification middleware: mail, Slack, webhook, overlap, presets
middlewares/presets/ -> YAML-based webhook presets (Discord, Teams, ntfy, etc.)
web/             -> HTTP server, auth, health checks, REST API
static/          -> embedded web UI (Pico CSS, single-page app)
metrics/         -> Prometheus metrics exporter
test/            -> test utilities, test configs, integration fixtures
e2e/             -> end-to-end scheduler lifecycle tests
scripts/         -> release and hook install scripts
docs/            -> project documentation
example/         -> sample configuration files
.github/workflows/ -> CI: ci.yml, mutation.yml, release-slsa.yml, pr-quality.yml, scorecard.yml
```
<!-- AGENTS-GENERATED:END filemap -->

## Golden Samples (follow these patterns)
<!-- AGENTS-GENERATED:START golden-samples -->
| For | Reference | Key patterns |
|-----|-----------|--------------|
| Job implementation | `core/runjob.go` | Docker container job with validation, context, error wrapping |
| Resilience | `core/resilient_job.go` | Retry logic with exponential backoff |
| Docker adapter | `core/adapters/docker/client.go` | Hexagonal architecture, port/adapter pattern |
| Middleware | `middlewares/webhook.go` | Notification middleware with config validation |
| CLI command | `cli/daemon.go` | Subcommand with slog logger, Docker handler |
| Integration test | `e2e/scheduler_lifecycle_test.go` | Full lifecycle test with Docker |
| Unit test | `core/scheduler_test.go` | Table-driven tests, mock injection |
<!-- AGENTS-GENERATED:END golden-samples -->

## Utilities (check before creating new)
<!-- AGENTS-GENERATED:START utilities -->
| Need | Use | Location |
|------|-----|----------|
| Test logging | `testlogger.go` | `test/testlogger.go` |
| Eventually assertion | `Eventually()` | `test/testutil/eventually.go` |
| Buffer pooling | `BufferPool` | `core/buffer_pool.go` |
| Cron expression utils | `ParseSchedule()` | `core/cron_utils.go` |
| Error types | Custom errors | `core/errors.go` |
| Command sanitization | `Sanitize()` | `config/sanitizer.go` |
| Command validation | `ValidateCommand()` | `config/command_validator.go` |
| Performance metrics | `PerformanceMetrics` | `core/performance_metrics.go` |
| Mock Docker client | `MockClient` | `core/adapters/mock/client.go` |
<!-- AGENTS-GENERATED:END utilities -->

## Heuristics (quick decisions)
<!-- AGENTS-GENERATED:START heuristics -->
| When | Do |
|------|-----|
| Adding a new job type | Implement in `core/`, follow `runjob.go` pattern, add to scheduler |
| Adding notification channel | Add middleware in `middlewares/`, or create YAML preset in `middlewares/presets/` |
| Docker interaction needed | Use port interfaces in `core/ports/`, implement via `core/adapters/docker/` |
| Adding CLI subcommand | Add to `cli/` package, register in `ofelia.go` main function |
| Adding API endpoint | Add handler in `web/server.go`, follow existing middleware chain |
| Running tasks | Check `make help` for available commands |
| Adding dependency | Ask first -- we minimize deps |
| Unsure about pattern | Check Golden Samples above |
<!-- AGENTS-GENERATED:END heuristics -->

## Repository Settings
<!-- AGENTS-GENERATED:START repo-settings -->
- **Default branch:** `main`
- **Merge strategy:** merge commits only (merge queue required)
- **Branch protection:** merge queue, no direct push to main
- **Delete branch on merge:** yes
- **Dismiss stale reviews:** yes
- **CI checks required:** unit tests, golangci-lint, CodeQL Analysis
- **Automated reviewers:** github-actions (auto-approve), gemini-code-assist, Copilot
- **Git hooks:** lefthook (pre-commit, commit-msg, pre-push, post-checkout, post-merge)
<!-- AGENTS-GENERATED:END repo-settings -->

## Go JSON serialization
- Struct fields with explicit `json` tags use the tag name (e.g., `json:"lastRun"` -> `lastRun`)
- Struct fields **without** `json` tags serialize as the Go field name (capitalized: `Image`, `Container`)
- Always `grep 'json:"' web/server.go` before writing frontend code that reads API responses
- `apiJob.Config` is `json.RawMessage` from `json.Marshal(job)` -- core structs lack json tags, so keys are capitalized

## Boundaries

### Always Do
- Run pre-commit checks before committing
- Add tests for new code paths
- Use conventional commit format: `type(scope): subject`
- **Show test output as evidence before claiming work is complete** -- never say "try again" or "should work now" without proof
- For upstream dependency fixes: run **full** test suite, not just affected tests
- Follow Go 1.26 conventions and idioms
- Use `*slog.Logger` from stdlib `log/slog` for all logging
- Commit with `--signoff` (DCO required, enforced by lefthook)
- Wrap errors with context: `fmt.Errorf("context: %w", err)`

### Ask First
- Adding new dependencies
- Modifying CI/CD configuration
- Changing public API signatures
- Running full e2e test suites
- Repo-wide refactoring or rewrites

### Never Do
- Commit secrets, credentials, or sensitive data
- Modify vendor/, node_modules/, or generated files
- Push directly to main/master branch (merge queue required)
- Delete migration files or schema changes
- Commit go.sum without go.mod changes
- Run `go mod vendor` -- this project uses Go modules, no vendoring
- Use `log` package directly -- use `*slog.Logger`
- Use `gh pr merge --delete-branch` -- not supported with merge queue

## Codebase State
<!-- AGENTS-GENERATED:START codebase-state -->
- Go 1.26.1 (`go.mod`)
- `github.com/netresearch/go-cron` v0.13.1 -- maintained fork with DAG engine, pause/resume, @triggered schedules
- `github.com/mitchellh/mapstructure` replaced with `github.com/go-viper/mapstructure` (archived upstream)
- ~60% test coverage, mutation testing enabled
- Hexagonal architecture in `core/adapters/` (Docker adapter, mock adapter, domain, ports)
- 45+ golangci-lint rules enabled (see `.golangci.yml`)
- Web UI uses embedded Pico CSS v2 single-page app (`static/ui/index.html`)
<!-- AGENTS-GENERATED:END codebase-state -->

## Terminology
| Term | Means |
|------|-------|
| RunJob | Job that runs a new Docker container |
| ExecJob | Job that executes a command inside an existing container |
| LocalJob | Job that runs a command on the host |
| ComposeJob | Job that runs docker compose commands |
| RunServiceJob | Job that creates/updates a Docker Swarm service |
| Middleware | Pre/post-execution hooks (notifications, overlap prevention, etc.) |
| Preset | YAML-defined webhook template (Discord, Teams, ntfy, etc.) |
| go-cron | Maintained fork of robfig/cron with DAG, pause/resume, @triggered |
| lefthook | Go-native git hooks manager (replaces pre-commit) |

## Index of scoped AGENTS.md
<!-- AGENTS-GENERATED:START scope-index -->
- `cli/AGENTS.md` -- CLI commands, configuration parsing, Docker label handling
- `core/AGENTS.md` -- Job scheduling engine, job types, Docker integration, resilience
- `web/AGENTS.md` -- HTTP server, REST API, authentication, web UI
- `middlewares/AGENTS.md` -- Notification middleware, webhook presets, overlap prevention
- `test/AGENTS.md` -- Test utilities, integration test fixtures
<!-- AGENTS-GENERATED:END scope-index -->

## When instructions conflict
The nearest `AGENTS.md` wins. Explicit user prompts override files.
- For Go-specific patterns, defer to language idioms and standard library conventions
