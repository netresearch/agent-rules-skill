<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
TYPO3 extension test suite. **Use the `typo3-testing` skill** for comprehensive guidance.
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START filemap -->
## Key Files
{{SCOPE_FILE_MAP}}
<!-- AGENTS-GENERATED:END filemap -->

<!-- AGENTS-GENERATED:START golden-samples -->
## Golden Samples (follow these patterns)
{{SCOPE_GOLDEN_SAMPLES}}
<!-- AGENTS-GENERATED:END golden-samples -->

<!-- AGENTS-GENERATED:START structure -->
## Test Structure (TYPO3 standard)
```
Tests/
├── Unit/                    # Fast, isolated unit tests
│   └── Domain/
│       └── Model/
├── Functional/              # Tests with database/TYPO3 context
│   ├── Fixtures/            # Test data, SQL, XML
│   └── Domain/
│       └── Repository/
└── Build/                   # CI configuration
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START commands -->
## Running Tests
| Type | Command |
|------|---------|
| Unit tests | `composer ci:test:php:unit` or `Build/Scripts/runTests.sh -s unit` |
| Functional tests | `composer ci:test:php:functional` or `Build/Scripts/runTests.sh -s functional` |
| Single file | `Build/Scripts/runTests.sh -s unit -p Tests/Unit/Path/To/Test.php` |
| Coverage | `composer ci:test:php:unit -- --coverage-html .Build/coverage` |
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START patterns -->
## Key Patterns (TYPO3-specific)
- Unit tests extend `\TYPO3\TestingFramework\Core\Unit\UnitTestCase`
- Functional tests extend `\TYPO3\TestingFramework\Core\Functional\FunctionalTestCase`
- Use `$this->importCSVDataSet()` for functional test fixtures
- Define `$testExtensionsToLoad` for extension dependencies
- Use `GeneralUtility::makeInstance()` for DI-aware instantiation in functional tests
<!-- AGENTS-GENERATED:END patterns -->

<!-- AGENTS-GENERATED:START code-style -->
## Code Style
- Test class name matches source: `MyClass` → `MyClassTest`
- Test methods: `test` prefix or `@test` annotation
- One assertion concept per test
- Use data providers for multiple similar cases
- Mock external services, never real HTTP calls
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START checklist -->
## PR Checklist
- [ ] All tests pass: `composer ci:test:php:unit && composer ci:test:php:functional`
- [ ] New functionality has tests
- [ ] Fixtures are minimal and focused
- [ ] No hardcoded credentials or paths
- [ ] Coverage hasn't decreased
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START skill-reference -->
## Skill Reference
> For comprehensive TYPO3 testing guidance including fixtures, mocking, CI setup, and runTests.sh:
> **Invoke skill:** `typo3-testing`
<!-- AGENTS-GENERATED:END skill-reference -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
