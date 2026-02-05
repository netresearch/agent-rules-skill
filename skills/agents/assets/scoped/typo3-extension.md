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
{{INSTALL_LINE}}
{{PHP_VERSION_LINE}}
{{TYPO3_VERSION_LINE}}
{{DEV_SETUP_LINE}}
{{REQUIRED_EXTENSIONS_LINE}}
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
{{COMMANDS_TABLE}}
{{DDEV_ALTERNATIVE}}
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
- **CSRF protection**: use `\TYPO3\CMS\Core\FormProtection\FormProtectionFactory` for forms
- **Access checks**: use `$GLOBALS['BE_USER']->check()` for backend
- **File handling**: use FAL (File Abstraction Layer), never direct file paths
- **Never trust user input**: validate via Extbase validators or custom validation
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
{{CI_CHECKLIST_LINE}}
{{PHPSTAN_CHECKLIST_LINE}}
- [ ] ext_emconf.php version updated if releasing
- [ ] TCA changes have matching SQL in ext_tables.sql
- [ ] Documentation updated in Documentation/
- [ ] No deprecated TYPO3 APIs (run Extension Scanner)
{{TYPO3_VERSION_CHECKLIST_LINE}}
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
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

<!-- AGENTS-GENERATED:START skill-reference -->
## Skill Reference
> For TYPO3 extension standards, TER compliance, and conformance checks:
> **Invoke skill:** `typo3-conformance`
<!-- AGENTS-GENERATED:END skill-reference -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
