# AI Agent Development Guide

**Project:** t3_cowriter - AI-powered content writing assistant for TYPO3 CKEditor
**Type:** TYPO3 CMS Extension (PHP 8.2+ / JavaScript ES6)
**TYPO3:** 13.4 LTS + 14.0
**License:** GPL-3.0-or-later
**Repository:** https://github.com/netresearch/t3x-cowriter

## Quick Start

```bash
# Install dependencies
composer install

# Run all quality checks (lint, phpstan, rector, code style)
composer ci:test

# Run all tests (unit, functional, integration, e2e)
composer ci:test:all

# Fix code style
composer ci:cgl

# Apply PHP modernization
composer ci:rector

# Local TYPO3 instance (optional, for manual testing)
make up                      # Start DDEV + install TYPO3 v13 + v14
make urls                    # Show access URLs
```

## Architecture

### Version Matrix

| TYPO3 | PHP | Status |
|-------|-----|--------|
| 13.4 LTS | 8.2, 8.3, 8.4, 8.5 | Supported |
| 14.0 | 8.2, 8.3, 8.4, 8.5 | Supported |

### Component Overview

```
t3_cowriter/
├── Classes/
│   ├── Controller/
│   │   ├── AjaxController.php          # Main chat/complete/stream + tasks/configs/context/page-search
│   │   ├── Backend/
│   │   │   └── StatusController.php    # Admin diagnostic module (LLM config chain checker)
│   │   ├── VisionController.php        # Image analysis and alt text generation
│   │   ├── TranslationController.php   # Content translation endpoint
│   │   ├── TemplateController.php      # Prompt template listing
│   │   └── ToolController.php          # LLM function/tool calling
│   ├── Domain/DTO/                     # Request/response value objects (readonly)
│   │   ├── CompleteRequest.php         # Prompt + configuration + model override
│   │   ├── CompleteResponse.php        # Success/error response with HTML escaping
│   │   ├── ContextRequest.php          # Context scope request
│   │   ├── ExecuteTaskRequest.php      # Task execution parameters
│   │   ├── PageSearchResult.php        # Page search result
│   │   ├── ToolRequest.php             # Tool calling request
│   │   ├── TranslationRequest.php      # Translation parameters
│   │   ├── UsageData.php               # Token usage statistics
│   │   └── VisionRequest.php           # Vision/image analysis parameters
│   ├── EventListener/
│   │   └── InjectAjaxUrlsListener.php  # CSP-compliant AJAX URL injection
│   ├── Service/
│   │   ├── ContextAssemblyService.php  # Context building for task execution
│   │   ├── ContextAssemblyServiceInterface.php
│   │   ├── DiagnosticService.php       # 8-step LLM configuration chain checker
│   │   ├── Dto/                        # Severity enum, DiagnosticCheck, DiagnosticResult
│   │   ├── RateLimiterInterface.php    # Rate limiter abstraction
│   │   ├── RateLimiterService.php      # Sliding window (20 req/min per user)
│   │   └── RateLimitResult.php         # Rate limit check result
│   └── Tools/
│       └── ContentQueryTool.php        # LLM tool for querying TYPO3 content
├── Configuration/
│   ├── Backend/
│   │   ├── AjaxRoutes.php              # 12 AJAX route definitions
│   │   └── Modules.php                 # Backend module (cowriter_status under Admin Tools)
│   ├── ContentSecurityPolicies.php     # CSP configuration
│   ├── JavaScriptModules.php           # ES6 module registration for TYPO3
│   ├── RTE/Cowriter.yaml              # CKEditor toolbar preset
│   ├── Services.yaml                   # DI container configuration
│   ├── TCA/Overrides/sys_template.php
│   ├── TypoScript/setup.typoscript
│   └── page.tsconfig
├── Resources/
│   ├── Private/
│   │   ├── Language/                   # XLF translation files
│   │   └── Templates/                  # Fluid templates (status module)
│   └── Public/
│       ├── Icons/                      # Extension + module SVG icons
│       └── JavaScript/Ckeditor/
│           ├── AIService.js            # Frontend API client (all endpoints + error handling)
│           ├── cowriter.js             # CKEditor 5 plugin (4 toolbar items)
│           ├── CowriterDialog.js       # Task dialog UI with status link on errors
│           └── UrlLoader.js            # CSP-compliant URL injection from data attributes
├── Tests/
│   ├── Unit/                           # PHPUnit unit tests
│   ├── Integration/                    # PHPUnit integration tests
│   ├── E2E/                            # PHP E2E + Playwright browser tests
│   ├── JavaScript/                     # Vitest tests for frontend JS
│   └── Support/                        # Test helpers
├── Build/                              # Tool configurations (phpstan, rector, php-cs-fixer, phpunit)
└── Documentation/                      # RST documentation (rendered via DDEV)
```

### Data Flow

```
CKEditor Toolbar
  ├─ cowriter          → CowriterDialog → AIService.js → AjaxController
  ├─ cowriterVision    → AIService.js ─────────────────→ VisionController
  ├─ cowriterTranslate → AIService.js ─────────────────→ TranslationController
  ├─ cowriterTemplates → AIService.js ─────────────────→ TemplateController
  └─ (tool calling)    → AIService.js ─────────────────→ ToolController
                                                              ↓
                                                   LlmServiceManagerInterface (nr-llm)
                                                              ↓
                                                        External LLM API
```

All LLM requests are proxied through the TYPO3 backend. API keys are stored encrypted in the nr-llm extension and never exposed to the browser.

### AJAX Routes

All routes are registered in `Configuration/Backend/AjaxRoutes.php` under `/cowriter/*` and require TYPO3 backend authentication.

| Route Key | Path | Controller | Purpose |
|-----------|------|------------|---------|
| `tx_cowriter_chat` | `/cowriter/chat` | `AjaxController::chatAction` | Stateless chat completion |
| `tx_cowriter_complete` | `/cowriter/complete` | `AjaxController::completeAction` | Single prompt completion |
| `tx_cowriter_stream` | `/cowriter/stream` | `AjaxController::streamAction` | Streaming via SSE |
| `tx_cowriter_configurations` | `/cowriter/configurations` | `AjaxController::getConfigurationsAction` | List LLM configurations |
| `tx_cowriter_tasks` | `/cowriter/tasks` | `AjaxController::getTasksAction` | List available tasks |
| `tx_cowriter_task_execute` | `/cowriter/task-execute` | `AjaxController::executeTaskAction` | Execute a predefined task |
| `tx_cowriter_context` | `/cowriter/context` | `AjaxController::getContextAction` | Context preview |
| `tx_cowriter_page_search` | `/cowriter/page-search` | `AjaxController::searchPagesAction` | Page search for tools |
| `tx_cowriter_vision` | `/cowriter/vision` | `VisionController::analyzeAction` | Image alt text generation |
| `tx_cowriter_translate` | `/cowriter/translate` | `TranslationController::translateAction` | Content translation |
| `tx_cowriter_templates` | `/cowriter/templates` | `TemplateController::listAction` | Prompt template listing |
| `tx_cowriter_tools` | `/cowriter/tools` | `ToolController::executeAction` | LLM tool/function calling |

### Key Dependencies

- **netresearch/nr-llm** (`^0.3 || ^0.4 || ^0.5`): Backend LLM abstraction layer (provider management, tool calling, chat options)
- **typo3/cms-rte-ckeditor** (`^13.4 || ^14.0`): CKEditor 5 integration for TYPO3

## Build and Test Commands

**CI is authoritative** -- always verify fixes pass in GitHub Actions CI before merging. Run tests locally via composer (same commands as CI), not via DDEV.

CI runs a **multi-version matrix**: PHP 8.2, 8.3, 8.4, 8.5 x TYPO3 ^13.4, ^14.0. See `.github/workflows/ci.yml`.

### Quality Checks

```bash
composer ci:test:php:lint       # PHP syntax check
composer ci:test:php:phpstan    # Static analysis (level 10)
composer ci:test:php:cgl        # Code style check (dry-run)
composer ci:test:php:rector     # PHP modernization check (dry-run)
composer ci:test                # All quality checks
```

### Tests

```bash
composer ci:test:php:unit        # Unit tests
composer ci:test:php:functional  # Functional tests
composer ci:test:php:integration # Integration tests
composer ci:test:php:e2e         # E2E tests (PHP)
composer ci:test:all             # All test suites

# JavaScript tests (Vitest)
npm test                         # Run JS tests
npm run test:coverage            # JS tests with coverage

# Playwright E2E (browser tests)
npm run test:e2e                 # Browser E2E tests
```

### Code Fixes

```bash
composer ci:cgl                  # Auto-fix code style
composer ci:rector               # Apply PHP modernization
npm run lint:fix                 # Fix JS lint issues
```

### Coverage and Mutation Testing

```bash
make test-coverage               # Generate PHP coverage reports (via DDEV)
composer ci:test:php:phpstan:baseline  # Regenerate PHPStan baseline
```

Coverage targets:
- Codecov patch: 80% (new code in PRs)
- Mutation testing (Infection): Covered Code MSI >= 85%

## Code Style

### PHP Standards

- **PSR-12 + PER-CS 2.0** baseline
- **Strict types** required in every file: `declare(strict_types=1);`
- **PHP 8.2+** baseline -- code must work on PHP 8.2 through 8.5
- **PHPStan level 10** -- zero errors allowed
- **Config:** `Build/.php-cs-fixer.dist.php` (inherits from typo3-ci-workflows)
- **License header:** Required on all PHP files

```php
<?php

/*
 * Copyright (c) 2025-2026 Netresearch DTT GmbH
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

declare(strict_types=1);

namespace Netresearch\T3Cowriter\Controller;

// Imports sorted alphabetically by vendor
use Netresearch\NrLlm\Service\LlmServiceManagerInterface;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use TYPO3\CMS\Core\Http\JsonResponse;

final readonly class AjaxController
{
    public function __construct(
        private LlmServiceManagerInterface $llmServiceManager,
        private RateLimiterInterface $rateLimiter,
        private LoggerInterface $logger,
    ) {}
}
```

### PHP Patterns (Required)

**Final readonly classes for DTOs:**
```php
final readonly class CompleteRequest
{
    public function __construct(
        public string $prompt,
        public ?string $configuration,
        public ?string $modelOverride,
    ) {}

    public static function fromRequest(ServerRequestInterface $request): self
    {
        // Parse and validate from request body
    }
}
```

**Static factory methods** for creating DTOs from requests and building responses.

**HTML escaping on all LLM output** to prevent XSS:
```php
content: htmlspecialchars($response->content, ENT_QUOTES | ENT_HTML5, 'UTF-8'),
```

**nr-llm integration** via `LlmServiceManagerInterface`:
```php
$configuration = $this->configurationRepository->findDefault();
$options = $configuration->toChatOptions();
$response = $this->llmServiceManager->chat($messages, $options);
```

### JavaScript Standards

- **ES6 modules** -- CKEditor 5 plugin format
- **TYPO3 AJAX routes** -- always use `TYPO3.settings.ajaxUrls`, never call LLM APIs directly
- **Async/await** for all asynchronous operations
- **No jQuery** -- vanilla JavaScript only
- **Location:** `Resources/Public/JavaScript/Ckeditor/`
- **Linter:** ESLint (`eslint.config.js`)
- **Tests:** Vitest with jsdom environment (`vitest.config.js`)

```javascript
// CORRECT: Use TYPO3 AJAX routes
const response = await fetch(TYPO3.settings.ajaxUrls.tx_cowriter_chat, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ messages }),
});

// WRONG: Never call LLM APIs directly from frontend
const response = await fetch('https://api.openai.com/v1/chat', {
    headers: { 'Authorization': `Bearer ${apiKey}` }  // API key exposed!
});
```

## CI/CD Workflows

All workflows in `.github/workflows/`. Uses reusable workflows from `netresearch/typo3-ci-workflows`.

| Workflow | File | Purpose |
|----------|------|---------|
| **CI** | `ci.yml` | Multi-version matrix (PHP x TYPO3): lint, phpstan, rector, cgl, unit, functional tests, coverage |
| **Extended Testing** | `testing.yml` | Per-suite PHP coverage, mutation testing (Infection), JS coverage (Vitest), fuzz testing |
| **Release** | `release.yml` | SBOM, Cosign signing, GitHub Release, TER publish |
| **Auto-merge Deps** | `auto-merge-deps.yml` | Auto-merge Renovate dependency updates |
| **Community** | `community.yml` | Community health automation |
| **Security** | via `ci.yml` | Gitleaks, dependency audit |
| **CodeQL** | via `ci.yml` | GitHub code scanning |
| **Scorecard** | via `ci.yml` | OpenSSF supply-chain security |
| **Dependency Review** | via `ci.yml` | New dependency review on PRs |
| **PR Quality** | via `ci.yml` | Auto-approve, review readiness |

## Testing

### Test Structure

```
Tests/
├── Unit/                                  # Fast, isolated, no TYPO3 framework
│   ├── Controller/                        # Controller unit tests (mocked dependencies)
│   ├── Domain/DTO/                        # DTO validation and serialization
│   ├── EventListener/                     # Event listener tests
│   ├── Service/                           # Service logic tests
│   └── Tools/                             # Tool definition tests
├── Integration/                           # With TYPO3 framework, DI container
│   ├── AbstractIntegrationTestCase.php    # Base class for integration tests
│   └── Controller/                        # Controller integration tests
├── E2E/                                   # End-to-end tests
│   ├── AbstractE2ETestCase.php            # PHP E2E base class
│   ├── CowriterWorkflowTest.php           # Full workflow PHP tests
│   ├── *.spec.ts                          # Playwright browser tests
│   └── fixtures/                          # Test fixtures (auth, etc.)
├── JavaScript/                            # Vitest frontend tests
│   ├── AIService.test.js
│   ├── cowriter.test.js
│   ├── CowriterDialog.test.js
│   ├── UrlLoader.test.js
│   └── __mocks__/                         # CKEditor and TYPO3 mocks
└── Support/                               # Shared test helpers
```

### PHPUnit Conventions

- Use **PHPUnit 11/12 attribute syntax**: `#[Test]`, `#[CoversClass]`, `#[DataProvider]`
- `#[CoversClass]` is **mandatory** for all test classes -- PHPUnit only attributes coverage to listed classes
- Use **DataProviders** for multiple input scenarios
- Follow **Arrange/Act/Assert** pattern
- Mock nr-llm via `LlmServiceManagerInterface`

```php
#[CoversClass(AjaxController::class)]
final class AjaxControllerTest extends TestCase
{
    private LlmServiceManagerInterface&MockObject $llmManager;

    protected function setUp(): void
    {
        $this->llmManager = $this->createMock(LlmServiceManagerInterface::class);
    }

    #[Test]
    public function completeActionReturnsSuccessForValidPrompt(): void
    {
        // Arrange / Act / Assert
    }

    #[Test]
    #[DataProvider('invalidPromptProvider')]
    public function completeActionRejectsInvalidPrompts(mixed $prompt): void
    {
        // Test with various invalid inputs
    }

    public static function invalidPromptProvider(): iterable
    {
        yield 'empty string' => [''];
        yield 'whitespace only' => ['   '];
        yield 'null' => [null];
    }
}
```

### TYPO3 Final Class Workarounds

`ModuleTemplateFactory` and `ModuleTemplate` are `final` and cannot be mocked. Use `ReflectionClass::newInstanceWithoutConstructor()` when needed.

### Constructor Change Checklist

When modifying a controller constructor, update ALL test files that instantiate it:
```bash
grep -rn "new AjaxController(" Tests/
```
This includes Unit/, Integration/, and E2E/ directories.

## Security

- **No API keys in frontend:** All LLM calls go through the PHP backend via nr-llm
- **AJAX route authentication:** All routes protected by TYPO3 backend session
- **Rate limiting:** 20 requests/minute per backend user (sliding window, cache-backed)
- **HTML escaping:** All LLM output escaped with `htmlspecialchars()`
- **Content sanitization:** Frontend DOMParser-based sanitization via CKEditor's HTML pipeline
- **CSP compatibility:** URL injection via data attributes, not inline scripts
- **Input validation:** Type-cast all request parameters; DTOs validate via `fromRequest()` factories
- **PHPStan level 10:** Strict static analysis

## Commit and PR Guidelines

### Commit Format

```
<type>(<scope>): <subject>
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
**Scopes:** `backend`, `frontend`, `config`, `docs`, `build`, `ddev`

Examples:
```
feat(backend): add streaming support for chat responses
fix(frontend): handle empty AI responses gracefully
test(unit): add coverage for rate limiter edge cases
```

### PR Checklist

1. `composer ci:test` passes (lint, phpstan, rector, cgl)
2. `composer ci:test:all` passes (unit, functional, integration, e2e)
3. `npm test` passes (JavaScript tests)
4. PHPStan level 10 -- zero errors
5. No new PHPStan baseline entries without justification
6. All LLM output HTML-escaped
7. `#[CoversClass]` on all test classes
8. Coverage >= 80% on new code
9. CHANGELOG.md updated for user-facing changes
10. Documentation updated if API changed

## Troubleshooting

| Problem | Solution |
|---------|----------|
| LLM not responding | Check nr-llm extension configuration in Admin Tools |
| AJAX 403 error | User not logged into TYPO3 backend |
| PHPStan errors | Update baseline: `composer ci:test:php:phpstan:baseline` |
| Code style fails | Run `composer ci:cgl` to auto-fix |
| CKEditor plugin not loading | Check browser console for JS import errors |
| Rate limit hit | Wait 60 seconds or check `cowriter_ratelimit` cache |
| Tests fail on constructor change | Update all test files that instantiate the class (Unit + Integration + E2E) |
| Empty AI response | Check TYPO3 backend logs for PHP errors |

## Design Principles

- **Security first:** No API keys in frontend; all calls proxied through backend
- **SOLID:** Single responsibility, dependency injection via `Services.yaml`
- **Composition over inheritance:** Prefer interfaces and DI
- **Final readonly:** DTOs and value objects are `final readonly` classes
- **Provider agnostic:** All LLM interaction via nr-llm's `LlmServiceManagerInterface`
- **TYPO3 conventions:** PSR-7 request/response, TYPO3 DI, AJAX routes, Fluid templates

## Related Resources

- **nr-llm extension:** https://github.com/netresearch/t3x-nr-llm
- **TYPO3 Documentation:** https://docs.typo3.org/
- **CKEditor 5 Documentation:** https://ckeditor.com/docs/ckeditor5/
- **TYPO3 RTE CKEditor:** https://docs.typo3.org/c/typo3/cms-rte-ckeditor/main/en-us/
- **TYPO3 AJAX API:** https://docs.typo3.org/m/typo3/reference-coreapi/main/en-us/ApiOverview/Ajax/Index.html
