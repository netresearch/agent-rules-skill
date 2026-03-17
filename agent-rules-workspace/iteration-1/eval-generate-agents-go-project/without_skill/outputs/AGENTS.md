<!-- Managed by agent: keep sections and order; edit content, not structure. -->

# AGENTS.md (root)

This file explains repo-wide conventions and where to find scoped rules.
**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Global rules
- Keep diffs small; add tests for new code paths.
- Use semantic commit messages following Conventional Commits style (e.g., `feat:`, `fix:`, `docs:`).
- Write comprehensive commit message bodies that thoroughly describe every change introduced.
- Ask first before: adding heavy deps, running full e2e suites, or repo-wide rewrites.
- Update `README.md` or files in `docs/` when you change user-facing behavior.

## Minimal pre-commit checks
- Format Go code: `gofmt -w $(git ls-files '*.go')`
- Vet code: `go vet ./...`
- Run tests: `go test ./...`
- Full lint check: `make lint`
- Security check: `make security-check`

## Go JSON serialization
- Struct fields with explicit `json` tags use the tag name (e.g., `json:"lastRun"` -> `lastRun`)
- Struct fields **without** `json` tags serialize as the Go field name (capitalized: `Image`, `Container`)
- Always `grep 'json:"' web/server.go` before writing frontend code that reads API responses
- `apiJob.Config` is `json.RawMessage` from `json.Marshal(job)` -- core structs lack json tags, so keys are capitalized

## CI & merge workflow
- ~26 CI checks: golangci-lint (140-char line limit), CodeQL, Trivy, govulncheck, mutation, unit/integration/fuzz
- Repo uses **GitHub merge queue** -- `gh pr merge --delete-branch` is NOT supported
- Automated reviewers: github-actions (auto-approve), gemini-code-assist, Copilot (both COMMENTED -- check all)

## Release process
- Releases trigger on `release: published` event via `release-slsa.yml`
- Create signed tags locally, then create a GitHub release: `gh release create vX.Y.Z --title "vX.Y.Z" --notes-file notes.md --verify-tag`
- The Release workflow builds SLSA Level 3 provenance, container images, and binary artifacts
- Follow the narrative release notes style from previous releases (user-facing highlights first, then categorized changes)

## Dependencies
- `github.com/netresearch/go-cron` -- maintained fork of robfig/cron with DAG engine, pause/resume, @triggered schedules
- Go version tracked in `go.mod` -- CI reads from `go-version-file: go.mod`
- Update Go version in `go.mod` to fix stdlib vulnerabilities (govulncheck detects these)

## Index of scoped AGENTS.md
- `./cli/AGENTS.md` -- command-line interface and configuration
- `./core/AGENTS.md` -- core business logic and scheduling
- `./web/AGENTS.md` -- web interface and HTTP handlers
- `./middlewares/AGENTS.md` -- notification and middleware logic
- `./test/AGENTS.md` -- testing utilities and integration tests

## Repository hygiene
- Manage dependencies exclusively with Go modules.
- Do **not** vendor or commit downloaded modules. Avoid running `go mod vendor`.
- Ensure the `vendor/` directory is ignored via `.gitignore`.

## When instructions conflict
- The nearest `AGENTS.md` wins. Explicit user prompts override files.
