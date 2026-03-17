<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Managed by agent: keep sections and order; edit content, not structure -->
<!-- Last updated: 2026-03-17 | Last verified: 2026-03-17 -->

# AGENTS.md

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Commands (verified)
> Source: composer.json, package.json, Makefile — CI-sourced commands are most reliable

<!-- AGENTS-GENERATED:START commands -->
| Task | Command | ~Time |
|------|---------|-------|
| Lint (PHP syntax) | `composer ci:test:php:lint` | ~5s |
| Typecheck (PHPStan) | `composer ci:test:php:phpstan` | ~15s |
| Code style check | `composer ci:test:php:cgl` | ~10s |
| Code style fix | `composer ci:cgl` | ~5s |
| Rector check | `composer ci:test:php:rector` | ~10s |
| Rector fix | `composer ci:rector` | ~5s |
| All quality checks | `composer ci:test` | ~40s |
| Test (unit) | `composer ci:test:php:unit` | ~5s |
| Test (integration) | `composer ci:test:php:integration` | ~10s |
| Test (e2e PHP) | `composer ci:test:php:e2e` | ~15s |
| Test (all PHP) | `composer ci:test:all` | ~30s |
| Test (JS unit) | `npm test` | ~5s |
| Lint (JS) | `npm run lint` | ~5s |
| Lint fix (JS) | `npm run lint:fix` | ~5s |
| Test (E2E Playwright) | `npm run test:e2e` | ~30s |
| PHPStan baseline | `composer ci:test:php:phpstan:baseline` | ~15s |
| Security audit | `composer ci:security` | ~5s |
| DDEV full setup | `make up` | ~5min |
| Show URLs | `make urls` | ~1s |
| Render docs | `make docs` | ~30s |
<!-- AGENTS-GENERATED:END commands -->

> If commands fail, verify against composer.json scripts, package.json scripts, or Makefile. Makefile includes shared targets from `netresearch/typo3-ci-workflows` via `-include .Build/vendor/netresearch/typo3-ci-workflows/Makefile.include` (provides `cgl`, `cgl-fix`, `phpstan`, `rector`, `lint`, `test-unit`, `test-functional`).

## Workflow
1. **Before coding**: Read nearest `AGENTS.md` + check Golden Samples for the area you're touching
2. **After each change**: Run the smallest relevant check (lint -> typecheck -> single test)
3. **Before committing**: Run full test suite if changes affect >2 files or touch shared code
4. **Before claiming done**: Run verification and **show output as evidence** -- never say "try again" or "should work now" without proof

## File Map
<!-- AGENTS-GENERATED:START filemap -->
```
Classes/                     -> PHP backend: controllers, DTOs, services, tools
Classes/Controller/          -> AJAX controllers (chat, complete, stream, vision, translate, templates, tools)
Classes/Controller/Backend/  -> Backend module controllers (StatusController)
Classes/Domain/DTO/          -> Request/response value objects (immutable DTOs)
Classes/Service/             -> Business logic (rate limiting, context assembly, diagnostics)
Classes/Service/Dto/         -> Service-layer value objects (DiagnosticCheck, Severity)
Classes/Tools/               -> LLM tool definitions (ContentQueryTool)
Classes/EventListener/       -> TYPO3 event listeners (InjectAjaxUrlsListener)
Configuration/               -> TYPO3 configuration (TCA, routes, DI, RTE preset)
Configuration/Backend/       -> AJAX routes (AjaxRoutes.php) + backend modules (Modules.php)
Configuration/RTE/           -> CKEditor preset (Cowriter.yaml)
Resources/Public/JavaScript/ -> CKEditor 5 plugin JS (ES6 modules)
Resources/Private/           -> Fluid templates, XLIFF translations
Documentation/               -> RST documentation for docs.typo3.org rendering
Tests/Unit/                  -> PHPUnit unit tests (mirrors Classes/ structure)
Tests/Integration/           -> PHPUnit integration tests (TYPO3 bootstrapped)
Tests/E2E/                   -> Playwright E2E specs (.spec.ts) + PHPUnit E2E tests
Tests/JavaScript/            -> Vitest JS unit tests + CKEditor mocks
Tests/Support/               -> Test helpers (TestQueryResult)
Build/                       -> Tool configs (phpstan.neon, rector.php, phpunit XMLs, php-cs-fixer)
.github/workflows/           -> CI (ci.yml), release, security, CodeQL, scorecard, dependency-review
```
<!-- AGENTS-GENERATED:END filemap -->

## Golden Samples (follow these patterns)
<!-- AGENTS-GENERATED:START golden-samples -->
| For | Reference | Key patterns |
|-----|-----------|--------------|
| AJAX controller | `Classes/Controller/AjaxController.php` | `final readonly class`, constructor DI, PSR-7 request/response, JsonResponse, rate limiting, input validation |
| Request DTO | `Classes/Domain/DTO/CompleteRequest.php` | Static `fromRequest()` factory, `isValid()` method, immutable properties |
| Service with interface | `Classes/Service/RateLimiterService.php` + `RateLimiterInterface.php` | Interface + implementation, aliased in Services.yaml |
| CKEditor plugin | `Resources/Public/JavaScript/Ckeditor/cowriter.js` | CKEditor 5 plugin registration, ES6 module, TYPO3 importModules |
| Frontend API client | `Resources/Public/JavaScript/Ckeditor/AIService.js` | TYPO3.settings.ajaxUrls, fetch API, error handling |
| Unit test | `Tests/Unit/Controller/AjaxControllerTest.php` | PHPUnit, mocking via `createMock()`, mirrors Classes/ structure |
| JS unit test | `Tests/JavaScript/AIService.test.js` | Vitest, CKEditor mocks in `__mocks__/` |
| E2E spec | `Tests/E2E/cowriter-dialog.spec.ts` | Playwright, TYPO3 backend auth fixture |
| AJAX routes | `Configuration/Backend/AjaxRoutes.php` | Route key naming `tx_cowriter_*`, path `/cowriter/*` |
| DI config | `Configuration/Services.yaml` | Autowire defaults, public controllers, interface aliases |
<!-- AGENTS-GENERATED:END golden-samples -->

## Utilities (check before creating new)
<!-- AGENTS-GENERATED:START utilities -->
| Need | Use | Location |
|------|-----|----------|
| LLM completion | `LlmServiceManagerInterface` | From `netresearch/nr-llm` (injected via DI) |
| Rate limiting | `RateLimiterInterface` | `Classes/Service/RateLimiterService.php` |
| Context assembly | `ContextAssemblyServiceInterface` | `Classes/Service/ContextAssemblyService.php` |
| Diagnostic checks | `DiagnosticService` | `Classes/Service/DiagnosticService.php` |
| AJAX URL injection | `InjectAjaxUrlsListener` | `Classes/EventListener/InjectAjaxUrlsListener.php` |
| Request parsing | DTO `::fromRequest()` / `::fromQueryParams()` | `Classes/Domain/DTO/*` |
| Test query helper | `TestQueryResult` | `Tests/Support/TestQueryResult.php` |
| CKEditor mock | Mock modules | `Tests/JavaScript/__mocks__/` |
| Shared CI targets | Makefile include | `.Build/vendor/netresearch/typo3-ci-workflows/Makefile.include` |
<!-- AGENTS-GENERATED:END utilities -->

## Heuristics (quick decisions)
<!-- AGENTS-GENERATED:START heuristics -->
| When | Do |
|------|-----|
| Adding AJAX endpoint | Add route in `Configuration/Backend/AjaxRoutes.php`, create controller action, register controller as `public: true` in `Services.yaml` |
| Adding new controller | Make it `final readonly class`, inject deps via constructor, return PSR-7 `ResponseInterface` |
| Adding DTO | Create in `Classes/Domain/DTO/`, add static factory `fromRequest()`, add `isValid()`, exclude from DI in `Services.yaml` |
| Adding service | Create interface + implementation, register alias in `Services.yaml` |
| Frontend JS change | Edit `Resources/Public/JavaScript/Ckeditor/`, use ES6 modules, access URLs via `TYPO3.settings.ajaxUrls` |
| LLM interaction | Use `LlmServiceManagerInterface` from nr-llm, never call provider APIs directly |
| Markdown from LLM | `AjaxController::convertMarkdownToHtml()` handles markdown-to-HTML post-processing |
| Adding CKEditor toolbar button | Register in `Configuration/RTE/Cowriter.yaml` under `toolbar.items` + `importModules` |
| Committing | Use Conventional Commits: `type(scope): subject` |
| Adding dependency | Ask first -- we minimize deps |
| Unsure about pattern | Check Golden Samples above |
| PHPStan error from baseline | Run `composer ci:test:php:phpstan:baseline` to regenerate |
| Code style fails | Run `composer ci:cgl` to auto-fix |
<!-- AGENTS-GENERATED:END heuristics -->

## Repository Settings
<!-- AGENTS-GENERATED:START repo-settings -->
- **Default branch:** `main`
- **CI matrix:** PHP 8.2, 8.3, 8.4, 8.5 x TYPO3 ^13.4, ^14.0
- **CI source:** `netresearch/typo3-ci-workflows` (reusable workflows)
- **Renovate:** Enabled (auto-merge via `auto-merge-deps.yml`)
- **License:** GPL-3.0-or-later
- **DDEV:** Multi-site (v13 + v14) with Ollama for local LLM
<!-- AGENTS-GENERATED:END repo-settings -->

## Boundaries

### Always Do
- Run pre-commit checks before committing
- Add tests for new code paths (PHP unit test + JS test if touching frontend)
- Use conventional commit format: `type(scope): subject`
- **Show test output as evidence before claiming work is complete** -- never say "try again" or "should work now" without proof
- For upstream dependency fixes: run **full** test suite, not just affected tests
- Follow PSR-12 + PER-CS 2.0 coding standards
- Use `declare(strict_types=1)` in all PHP files
- Make controllers `final readonly class`
- Use constructor promotion for DI
- Validate all request input (type-cast, length limits)
- Return `JsonResponse` from AJAX actions
- Keep API keys server-side only (via nr-llm)

### Ask First
- Adding new dependencies (PHP or npm)
- Modifying CI/CD configuration
- Changing public API signatures (AJAX routes, controller actions)
- Running full e2e test suites
- Repo-wide refactoring or rewrites
- Changing rate limit thresholds
- Modifying CKEditor toolbar layout

### Never Do
- Commit secrets, credentials, or sensitive data
- Modify vendor/, node_modules/, or generated files
- Push directly to main/master branch
- Delete migration files or schema changes
- Commit composer.lock without composer.json changes
- Expose API keys or LLM provider credentials in frontend JavaScript
- Call LLM provider APIs directly -- always go through nr-llm
- Modify core TYPO3 framework files
- Hardcode cache backends in `ext_localconf.php` (use TYPO3 instance defaults)

## Codebase State
<!-- AGENTS-GENERATED:START codebase-state -->
- **Version:** 3.1.0 (stable)
- **ext_localconf.php:** Hardcodes `Typo3DatabaseBackend` for `cowriter_ratelimit` cache -- should be removed to respect instance cache config
- **Functional tests:** `Tests/Functional/` directory exists but is empty
- **Dual test stacks:** PHP tests via PHPUnit (unit, integration, e2e), JS tests via Vitest + Playwright
- **Markdown-to-HTML:** `AjaxController` includes inline markdown-to-HTML converter for small LLM models that ignore HTML formatting instructions
- **nr-llm dependency:** `^0.3 || ^0.4 || ^0.5` -- wide version range, API surface may vary
<!-- AGENTS-GENERATED:END codebase-state -->

## Terminology
| Term | Means |
|------|-------|
| nr-llm | `netresearch/nr-llm` -- TYPO3 extension providing LLM abstraction layer (providers, configurations, tasks) |
| Cowriter | The CKEditor plugin that provides AI writing assistance toolbar buttons |
| LlmServiceManager | Central service from nr-llm that routes requests to configured LLM providers |
| Task | A predefined prompt template (from nr-llm) with category, description, and LLM configuration |
| Context scope | How much surrounding content to include: selection, text, field, record, page, site |
| SSE | Server-Sent Events -- used for streaming LLM responses to the frontend |
| Rate limiter | Sliding-window rate limiter using TYPO3 cache, configurable per-minute limit (default: 20) |
| DiagnosticService | 8-step checker that validates the entire LLM configuration chain |
| ContentQueryTool | LLM tool definition enabling the model to query TYPO3 page content |

## Index of scoped AGENTS.md
<!-- AGENTS-GENERATED:START scope-index -->
- `Classes/AGENTS.md` -- PHP backend patterns, DI conventions, controller/service structure
- `Resources/AGENTS.md` -- JavaScript/CKEditor 5 plugin conventions, TYPO3 module format
- `Tests/AGENTS.md` -- Test organization, PHPUnit/Vitest/Playwright patterns, fixtures
<!-- AGENTS-GENERATED:END scope-index -->

## When instructions conflict
The nearest `AGENTS.md` wins. Explicit user prompts override files.
- For PHP-specific patterns, follow PSR-12 + PER-CS 2.0
- For CKEditor integration, follow TYPO3 rte_ckeditor conventions
- For LLM integration, follow nr-llm patterns
