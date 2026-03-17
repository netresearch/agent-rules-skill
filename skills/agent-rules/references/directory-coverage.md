# Directory Coverage for AGENTS.md

Comprehensive AGENTS.md coverage means creating files in ALL key directories, not just root.

## Why Full Coverage Matters

- Each directory has unique patterns and conventions
- AI agents working in subdirectories benefit from local context
- Reduces need to navigate up to root AGENTS.md

## Standard Directory Structure

### PHP/TYPO3 Projects

| Directory | AGENTS.md Content |
|-----------|-------------------|
| Root | Project overview, precedence list, architecture diagram |
| `Classes/` | DI patterns, service layer, security rules |
| `Configuration/` | TCA, Services.yaml, module registration |
| `Documentation/` | RST standards, directives, rendering |
| `Resources/` | Templates, XLIFF, assets |
| `Tests/` | Unit/functional patterns, fixtures |
| `Tests/E2E/` | E2E-specific patterns (if exists) |

### Go Projects

| Directory | AGENTS.md Content |
|-----------|-------------------|
| Root | Module overview, build commands |
| `cmd/` | CLI entry points, flags |
| `internal/` | Private packages, no export |
| `pkg/` | Public API patterns |

### Python Projects

| Directory | AGENTS.md Content |
|-----------|-------------------|
| Root | Project overview, pyproject.toml config |
| `src/` | Source code patterns, type hints |
| `tests/` | pytest conventions, fixtures, markers |
| `scripts/` | CLI scripts, entry points |
| `docs/` | Sphinx/MkDocs documentation standards |

### TypeScript/Node Projects

| Directory | AGENTS.md Content |
|-----------|-------------------|
| Root | Package overview, scripts |
| `src/` | Source patterns, imports |
| `components/` | UI component patterns |
| `tests/` or `__tests__/` | Testing patterns |

### Skill Repos (Claude Code Plugins)

| Directory | AGENTS.md Content |
|-----------|-------------------|
| Root | Project overview, plugin.json, licensing |
| `skills/<name>/` | Skill-specific patterns, SKILL.md rules |
| `skills/<name>/scripts/` | Shell script conventions |
| `skills/<name>/references/` | Extended documentation patterns |
| `.github/workflows/` | CI workflow patterns (validate, auto-merge) |

## Precedence Rules

Root AGENTS.md should list all child files:

```markdown
## Precedence

1. This file (root)
2. Directory-specific files:
   - `Classes/AGENTS.md`
   - `Configuration/AGENTS.md`
   - `Tests/AGENTS.md`
3. Framework standards
```

## Anti-pattern

**Wrong**: Only creating root AGENTS.md and Tests/AGENTS.md

**Right**: Create AGENTS.md in EVERY directory with unique patterns
