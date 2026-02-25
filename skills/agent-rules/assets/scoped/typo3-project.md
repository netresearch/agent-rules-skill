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
{{COMPOSER_MODE_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
public/                 → Web root (DocumentRoot)
  typo3/               → TYPO3 backend assets
  typo3conf/           → Configuration (legacy, avoid)
  fileadmin/           → User uploads (FAL)
  index.php            → Entry point
config/                → Project configuration
  sites/               → Site configurations (YAML)
    <site>/
      config.yaml      → Site routing, languages
  system/              → System-wide settings
    settings.php       → LocalConfiguration equivalent
    additional.php     → AdditionalConfiguration
var/                   → Runtime data (cache, logs)
  cache/               → Cache files
  log/                 → Log files
  session/             → Session data
vendor/                → Composer dependencies
packages/              → Local extensions (recommended)
  my_extension/        → Custom extension
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
{{COMMANDS_TABLE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- **PSR-12** + TYPO3 CGL (Coding Guidelines)
- Strict types: `declare(strict_types=1);` in all PHP files
- Use **Composer Mode** for all extensions
- Site configuration in `config/sites/` (not database)
- Use environment variables for sensitive config
- Avoid `typo3conf/` - use `config/` and `packages/` instead

### Project vs Extension code
| Type | Location | Purpose |
|------|----------|---------|
| Local extensions | `packages/` | Custom functionality |
| Site config | `config/sites/` | Routing, languages |
| System config | `config/system/` | TYPO3 settings |
| Templates | Extension `Resources/` | Fluid templates |
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START extensions -->
## Extension management
- **Composer-only**: All extensions via `composer require`
- **Local packages**: Use `packages/` with path repository
- **Never use Extension Manager** for production
- Lock extension versions in `composer.lock`

### Adding local extension
```json
{
    "repositories": [
        {"type": "path", "url": "packages/*"}
    ],
    "require": {
        "vendor/my-extension": "@dev"
    }
}
```
<!-- AGENTS-GENERATED:END extensions -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- **Environment variables**: Use for DB credentials, encryption key
- **Restrict backend access**: Use `.htaccess` or server config
- **Disable install tool**: Remove `ENABLE_INSTALL_TOOL` after setup
- **File permissions**: Strict permissions on `var/`, `config/`
- **HTTPS only**: Enforce in site configuration
- **Update regularly**: Security updates for core and extensions
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START deployment -->
## Deployment
- Use `composer install --no-dev --optimize-autoloader`
- Clear caches: `vendor/bin/typo3 cache:flush`
- Warmup caches: `vendor/bin/typo3 cache:warmup`
- Run database migrations: `vendor/bin/typo3 database:updateschema`
- Never deploy `var/cache/` or `var/session/`
<!-- AGENTS-GENERATED:END deployment -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
{{CI_CHECKLIST_LINE}}
- [ ] Site configuration is valid YAML
- [ ] No hardcoded credentials or paths
- [ ] Extensions installed via Composer only
- [ ] Database schema changes documented
{{TYPO3_VERSION_CHECKLIST_LINE}}
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- TYPO3 Documentation: https://docs.typo3.org
- Installation Guide: https://docs.typo3.org/m/typo3/tutorial-getting-started/main/en-us/
- Site Configuration: https://docs.typo3.org/m/typo3/reference-coreapi/main/en-us/ApiOverview/SiteHandling/
- Console Commands: `vendor/bin/typo3 list`
- Review root AGENTS.md for project-wide conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
