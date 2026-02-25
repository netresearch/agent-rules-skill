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
{{ORO_VERSION_LINE}}
{{DATABASE_LINE}}
{{MESSAGE_QUEUE_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
bin/
  console              → Symfony console entry point
config/
  bundles.php          → Registered bundles
  config.yml           → Main configuration
  config_dev.yml       → Development overrides
  config_prod.yml      → Production settings
  parameters.yml       → Environment parameters
  security.yml         → Security configuration
  oro/
    bundles.yml        → Oro bundle registration
public/
  index.php            → Web entry point
  bundles/             → Bundle assets
src/
  Acme/                → Custom bundles
    Bundle/
      MyBundle/
var/
  cache/               → Cache files
  logs/                → Log files
  attachment/          → File attachments
migrations/
  Schema/              → Doctrine schema migrations
  Data/                → Data migrations/fixtures
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
{{COMMANDS_TABLE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- **PSR-12** coding standard
- Strict types: `declare(strict_types=1);`
- Symfony best practices + Oro conventions
- Bundle-based architecture for all custom code
- Use Oro's config-based approach (YAML over annotations)
- Dependency injection via `services.yml`

### Project structure rules
| Type | Location | Purpose |
|------|----------|---------|
| Custom bundles | `src/Vendor/Bundle/` | All custom functionality |
| Overrides | `config/` | Configuration overrides |
| Migrations | `migrations/` | Application-level migrations |
| Assets | `public/bundles/` | Compiled/copied assets |
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START oro-commands -->
## Oro CLI commands
```bash
# Installation & setup
bin/console oro:install                    # Full installation
bin/console oro:platform:update           # Update after code changes

# Cache management
bin/console cache:clear                   # Clear cache
bin/console oro:assets:install            # Install bundle assets
bin/console oro:localization:dump         # Dump translations

# Database & migrations
bin/console doctrine:migrations:migrate   # Run migrations
bin/console oro:migration:data:load       # Load data migrations

# Message queue (required for Oro)
bin/console oro:message-queue:consume     # Process queue
bin/console oro:cron                      # Run cron jobs

# Development
bin/console debug:router                  # List routes
bin/console debug:container               # Debug DI container
```
<!-- AGENTS-GENERATED:END oro-commands -->

<!-- AGENTS-GENERATED:START message-queue -->
## Message Queue
Oro requires a running message queue consumer for:
- Email sending
- Search indexing
- Workflow processing
- Data import/export

**Development:** Run `bin/console oro:message-queue:consume` in terminal
**Production:** Use supervisor or systemd to keep consumer running
<!-- AGENTS-GENERATED:END message-queue -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- **Parameters**: Use `parameters.yml` for sensitive values (not in git)
- **OAuth2**: Configure for API authentication
- **ACL**: Define permissions in bundle `acl.yml`
- **HTTPS**: Enforce in production
- **Secrets**: Use Symfony secrets for production credentials
- **Session**: Configure secure session handling
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START deployment -->
## Deployment
```bash
# Production deployment steps
composer install --no-dev --optimize-autoloader
bin/console cache:clear --env=prod
bin/console oro:platform:update --env=prod --force
bin/console oro:assets:install --env=prod
bin/console assetic:dump --env=prod
```
- Always run `oro:platform:update` after code changes
- Restart message queue consumer after deployment
- Warm up cache before switching to new release
<!-- AGENTS-GENERATED:END deployment -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
{{CACHE_CHECKLIST_LINE}}
{{PHPSTAN_CHECKLIST_LINE}}
{{UNIT_TEST_CHECKLIST_LINE}}
- [ ] Bundle registered in `config/oro/bundles.yml`
- [ ] Migrations reversible and tested
- [ ] Assets installed: `bin/console oro:assets:install`
- [ ] Message queue tested with consumer running
- [ ] ACL permissions defined for new entities
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Oro Documentation: https://doc.oroinc.com
- Installation: https://doc.oroinc.com/backend/setup/
- Backend Architecture: https://doc.oroinc.com/backend/architecture/
- CLI Commands: `bin/console list oro`
- Check `vendor/oro/` bundles for reference implementations
- Review root AGENTS.md for project-wide conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
