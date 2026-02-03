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
{{SYMFONY_VERSION_LINE}}
{{DATABASE_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Directory structure
```
src/
  Controller/           → HTTP controllers
  Entity/               → Doctrine entities
  Repository/           → Doctrine repositories
  Service/              → Business logic services
  Form/                 → Form types
  EventSubscriber/      → Event subscribers
  Command/              → Console commands
  Security/             → Voters, authenticators
config/
  packages/             → Bundle configuration
  routes/               → Routing configuration
  services.yaml         → Service definitions
templates/              → Twig templates
migrations/             → Doctrine migrations
tests/                  → PHPUnit tests
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests
{{COMMANDS_TABLE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- **PSR-12** coding standard with strict types
- Use **constructor injection** for dependencies
- Controllers are thin: delegate to services
- Use **attributes** for routing, validation, ORM mapping
- Services are autowired by default

### Naming conventions
| Type | Convention | Example |
|------|------------|---------|
| Controller | `<Entity>Controller` | `UserController` |
| Service | `<Domain>Service` or `<Domain>Manager` | `UserService` |
| Repository | `<Entity>Repository` | `UserRepository` |
| Form | `<Entity>Type` | `UserType` |
| Event | `<Entity><Action>Event` | `UserCreatedEvent` |
| Command | `app:<domain>:<action>` | `app:user:import` |
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START patterns -->
## Symfony-specific patterns

### Controller with form handling
```php
#[Route('/user/new', name: 'user_new')]
public function new(Request $request, EntityManagerInterface $em): Response
{
    $user = new User();
    $form = $this->createForm(UserType::class, $user);
    $form->handleRequest($request);

    if ($form->isSubmitted() && $form->isValid()) {
        $em->persist($user);
        $em->flush();
        return $this->redirectToRoute('user_show', ['id' => $user->getId()]);
    }

    return $this->render('user/new.html.twig', ['form' => $form]);
}
```

### Service with dependency injection
```php
final class UserService
{
    public function __construct(
        private readonly UserRepository $userRepository,
        private readonly EventDispatcherInterface $dispatcher,
    ) {}

    public function createUser(string $email): User
    {
        $user = new User($email);
        $this->userRepository->save($user, flush: true);
        $this->dispatcher->dispatch(new UserCreatedEvent($user));
        return $user;
    }
}
```

### Custom console command
```php
#[AsCommand(name: 'app:user:import', description: 'Import users from CSV')]
final class ImportUsersCommand extends Command
{
    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        // Implementation
        return Command::SUCCESS;
    }
}
```
<!-- AGENTS-GENERATED:END patterns -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Use **Voters** for authorization logic, not inline checks
- Store secrets in `.env.local` (never commit)
- Use **CSRF tokens** for all forms
- Enable **security headers** via NelmioSecurityBundle
- Validate all input with Symfony Validator constraints
- Use **parameterized queries** (Doctrine handles this)
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
{{PHPSTAN_CHECKLIST_LINE}}
{{CS_CHECKLIST_LINE}}
{{TEST_CHECKLIST_LINE}}
- [ ] Migrations are reversible (`down()` method works)
- [ ] New routes have proper security annotations
- [ ] Services are properly autowired (no manual config needed)
- [ ] Cache cleared: `bin/console cache:clear`
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Symfony docs: https://symfony.com/doc/current/
- Best practices: https://symfony.com/doc/current/best_practices.html
- Check existing controllers/services for patterns
- Run `bin/console debug:router` to inspect routes
- Run `bin/console debug:container` to inspect services
- Review root AGENTS.md for project-wide conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
