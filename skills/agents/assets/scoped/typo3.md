<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}

TYPO3 extension following [TYPO3 Coding Guidelines](https://docs.typo3.org/m/typo3/reference-coreapi/main/en-us/CodingGuidelines/Index.html) and PSR-12.
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
- Install: `composer install` or via Extension Manager
- PHP version: {{PHP_VERSION}}
- TYPO3 version: {{TYPO3_VERSION}}
- Local dev: `ddev start && ddev composer install`
- Required extensions: {{REQUIRED_EXTENSIONS}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
Classes/           → PHP classes (PSR-4: Vendor\ExtKey\)
  Controller/      → Backend/Frontend controllers
  Domain/          → Model, Repository, Validator
  Service/         → Business logic services
  ViewHelpers/     → Fluid ViewHelpers
Configuration/     → TYPO3 configuration
  TCA/             → Table Configuration Array
  TypoScript/      → TypoScript setup/constants
  FlexForms/       → FlexForm XML definitions
  Backend/         → Backend module config
Resources/
  Private/         → Templates, Partials, Layouts (Fluid)
  Public/          → CSS, JS, Icons
Tests/
  Unit/            → PHPUnit unit tests
  Functional/      → Functional tests with DB
Documentation/     → RST documentation for docs.typo3.org
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
| Task | Command | ~Time |
|------|---------|-------|
| Lint | `composer ci:php:lint` | ~5s |
| CS Fix | `composer ci:php:cs-fixer` | ~10s |
| PHPStan | `composer ci:php:stan` | ~15s |
| Unit tests | `composer ci:tests:unit` | ~10s |
| Functional | `composer ci:tests:functional` | ~60s |
| All CI | `composer ci` | ~90s |

Alternative with ddev:
- `ddev composer ci:tests:unit`
- `ddev exec vendor/bin/phpunit -c Tests/Build/UnitTests.xml`
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- **PSR-12** + TYPO3 CGL (Coding Guidelines)
- Strict types: `declare(strict_types=1);` in all PHP files
- Namespace: `{{VENDOR}}\{{EXT_KEY}}\` (PSR-4 from Classes/)
- Use dependency injection via `Services.yaml`, not `GeneralUtility::makeInstance()`
- Extbase conventions for domain models and repositories
- Fluid templates: use `<f:` and custom ViewHelpers
- TCA: use TYPO3 API, not raw SQL for schema
- Never use `$GLOBALS['TYPO3_DB']` (deprecated since v8)

### Naming conventions
| Type | Convention | Example |
|------|------------|---------|
| Extension key | `lowercase_underscore` | `my_extension` |
| Composer name | `vendor/ext-key` | `vendor/my-extension` |
| Namespace | `Vendor\ExtKey\` | `Vendor\MyExtension\` |
| Controller | `*Controller` | `BlogController` |
| Repository | `*Repository` | `PostRepository` |
| ViewHelper | `*ViewHelper` | `FormatDateViewHelper` |
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- **Always use QueryBuilder** or Extbase repositories - never raw SQL
- **Escape output** in Fluid: `{variable}` auto-escapes, use `<f:format.raw>` only when safe
- **CSRF protection**: use `@TYPO3\CMS\Extbase\Annotation\IgnoreValidation` carefully
- **Access checks**: use `$GLOBALS['BE_USER']->check()` for backend
- **File handling**: use FAL (File Abstraction Layer), never direct file paths
- **Never trust user input**: validate via Extbase validators or custom validation
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] `composer ci` passes (lint, cs-fixer, phpstan, tests)
- [ ] PHPStan level {{PHPSTAN_LEVEL}} clean
- [ ] ext_emconf.php version updated if releasing
- [ ] TCA changes have matching SQL in ext_tables.sql
- [ ] Documentation updated in Documentation/
- [ ] No deprecated TYPO3 APIs (run Extension Scanner)
- [ ] Tested on target TYPO3 versions ({{TYPO3_VERSION}})
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Good vs. bad examples

**Good**: Dependency injection
```php
public function __construct(
    private readonly PostRepository $postRepository,
    private readonly Context $context,
) {}
```

**Bad**: Static instantiation
```php
$postRepository = GeneralUtility::makeInstance(PostRepository::class);
```

**Good**: QueryBuilder with proper escaping
```php
$queryBuilder = $this->connectionPool->getQueryBuilderForTable('tx_myext_posts');
$queryBuilder
    ->select('*')
    ->from('tx_myext_posts')
    ->where($queryBuilder->expr()->eq('uid', $queryBuilder->createNamedParameter($uid, Connection::PARAM_INT)));
```

**Bad**: String concatenation in queries
```php
$result = $connection->query("SELECT * FROM tx_myext_posts WHERE uid = " . $uid);
```

**Good**: Fluid with escaping
```html
<f:for each="{posts}" as="post">
    <h2>{post.title}</h2>
    <f:format.html>{post.bodytext}</f:format.html>
</f:for>
```
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START upgrade -->
## TYPO3 upgrade considerations
- Run **Extension Scanner** before upgrading: Backend → Upgrade → Scan Extension Files
- Use **Rector** for automated migrations: `vendor/bin/rector process`
- Check **deprecation log** in TYPO3 backend
- Review [TYPO3 Changelog](https://docs.typo3.org/c/typo3/cms-core/main/en-us/Index.html) for breaking changes
<!-- AGENTS-GENERATED:END upgrade -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- TYPO3 Documentation: https://docs.typo3.org
- TCA Reference: https://docs.typo3.org/m/typo3/reference-tca/main/en-us/
- Core API: https://docs.typo3.org/m/typo3/reference-coreapi/main/en-us/
- Extbase Guide: https://docs.typo3.org/m/typo3/book-extbasefluid/main/en-us/
- Check existing patterns in EXT:core or EXT:backend
- Review root AGENTS.md for project-wide conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
