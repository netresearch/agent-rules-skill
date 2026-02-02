<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}

Oro bundle following [Oro Architecture](https://doc.oroinc.com/backend/architecture/) and Symfony best practices.
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
{{SETUP_COMMANDS}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
src/
  Acme/
    Bundle/
      MyBundle/
        AcmeMyBundle.php        → Bundle class
        Controller/             → Web and API controllers
        Entity/                 → Doctrine entities
        Form/                   → Form types
        Resources/
          config/
            oro/                → Oro-specific configs
              workflows.yml     → Workflow definitions
              datagrids.yml     → Datagrid definitions
              navigation.yml    → Menu/navigation
              acl.yml           → ACL definitions
            services.yml        → Service definitions
          views/                → Twig templates
          translations/         → Translation files
        Migrations/
          Schema/               → Doctrine schema migrations
          Data/                 → Data migrations (fixtures)
        Api/                    → API processors
        Async/                  → Message queue processors
        EventListener/          → Event subscribers/listeners
        ImportExport/           → Import/export processors
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
- Use Oro's **config-based** approach (YAML over annotations when possible)
- Dependency injection via `services.yml`
- Entities extend Oro base classes when applicable

### Naming conventions
| Type | Convention | Example |
|------|------------|---------|
| Bundle | `VendorNameBundle` | `AcmeCrmBundle` |
| Entity | `PascalCase` | `CustomerOrder` |
| Datagrid | `vendor-entity-grid` | `acme-orders-grid` |
| Workflow | `vendor_entity_flow` | `acme_order_flow` |
| API resource | `vendor_entity` | `acme_orders` |
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START patterns -->
## Oro-specific patterns

### Datagrids (datagrids.yml)
```yaml
datagrids:
    acme-orders-grid:
        source:
            type: orm
            query:
                select:
                    - o.id
                    - o.orderNumber
                from:
                    - { table: Acme\Bundle\OrderBundle\Entity\Order, alias: o }
        columns:
            orderNumber:
                label: acme.order.order_number.label
        sorters:
            columns:
                orderNumber:
                    data_name: o.orderNumber
        filters:
            columns:
                orderNumber:
                    type: string
                    data_name: o.orderNumber
```

### Workflows (workflows.yml)
```yaml
workflows:
    acme_order_flow:
        entity: Acme\Bundle\OrderBundle\Entity\Order
        entity_attribute: order
        start_step: draft
        steps:
            draft:
                allowed_transitions:
                    - submit
            submitted:
                allowed_transitions:
                    - approve
                    - reject
        transitions:
            submit:
                step_to: submitted
```

### ACL (acl.yml)
```yaml
acl:
    acme_order_view:
        type: entity
        class: Acme\Bundle\OrderBundle\Entity\Order
        permission: VIEW
    acme_order_edit:
        type: entity
        class: Acme\Bundle\OrderBundle\Entity\Order
        permission: EDIT
```
<!-- AGENTS-GENERATED:END patterns -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- **ACL**: Define permissions in `acl.yml`, check with `isGranted()`
- **CSRF**: Oro handles automatically for forms
- **API auth**: OAuth2 or WSSE authentication
- **Input validation**: Use Symfony validators + Oro constraints
- **Sensitive data**: Use Oro's `ConfigManager` for encrypted values
- **SQL**: Always use Doctrine ORM/DBAL, never raw queries
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
{{CACHE_CHECKLIST_LINE}}
{{PHPSTAN_CHECKLIST_LINE}}
{{UNIT_TEST_CHECKLIST_LINE}}
- [ ] Schema migrations are reversible
- [ ] Data migrations use `DependentFixtureInterface` for ordering
- [ ] Datagrids tested in browser
- [ ] Workflows tested end-to-end
- [ ] ACL permissions defined for new entities
- [ ] Translation keys added to `messages.en.yml`
- [ ] API resources documented with NelmioApiDocBundle annotations
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START messaging -->
## Message Queue patterns
```php
// Async processor
class ProcessOrderProcessor implements MessageProcessorInterface
{
    public function process(MessageInterface $message, SessionInterface $session): string
    {
        $data = JSON::decode($message->getBody());
        // Process order...
        return self::ACK;
    }
}

// Producer usage
$this->messageProducer->send(ProcessOrderTopic::NAME, ['orderId' => $order->getId()]);
```
<!-- AGENTS-GENERATED:END messaging -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Oro Documentation: https://doc.oroinc.com
- Backend Architecture: https://doc.oroinc.com/backend/architecture/
- Datagrids: https://doc.oroinc.com/backend/entities/data-grids/
- Workflows: https://doc.oroinc.com/backend/entities/workflows/
- API: https://doc.oroinc.com/api/
- Check existing bundles in `vendor/oro/` for patterns
- Review root AGENTS.md for project-wide conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
