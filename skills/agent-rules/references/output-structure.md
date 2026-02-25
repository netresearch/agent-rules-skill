# Output Structure

## Root File

Root AGENTS.md (~50-80 lines) contains agent-optimized sections:

| Section | Purpose | Format |
|---------|---------|--------|
| **Commands (verified)** | Executable commands with time estimates | Table with ~Time column |
| **File Map** | Directory purposes for navigation | `dir/ -> purpose` format |
| **Golden Samples** | Canonical patterns to follow | Table: For / Reference / Key patterns |
| **Utilities List** | Existing helpers to reuse | Table: Need / Use / Location |
| **Heuristics** | Quick decision rules | Table: When / Do |
| **Boundaries** | Always/Ask/Never rules | Three-tier list |
| **Codebase State** | Migrations, tech debt, known issues | Bullet list |
| **Terminology** | Domain-specific terms | Table: Term / Means |
| **Scope Index** | Links to scoped files | List with descriptions |

## Scoped Files

Scoped AGENTS.md files cover six core areas (per [GitHub best practices](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/)):
1. **Commands** - Executable build, test, lint commands
2. **Testing** - Test conventions and execution
3. **Project Structure** - Architecture and key files
4. **Code Style** - Formatting and conventions
5. **Git Workflow** - Commit/PR guidelines
6. **Boundaries** - Always do / Ask first / Never do

Additional recommended sections:
- Overview
- Setup/Prerequisites
- Security
- Good vs Bad examples
- When stuck
- House Rules (for scoped overrides)

## When to Customize vs Auto-Generate

### Auto-Generate These Sections

These sections are factual and extractable - let scripts handle them:

| Section | Why Auto-Generate |
|---------|-------------------|
| **Commands** | Extract from Makefile/package.json - always accurate |
| **File Map** | Directory listing is objective |
| **Scope Index** | Detectable from filesystem structure |
| **Language/Framework** | Detectable from config files |
| **Test Commands** | Extract from CI config |

### Manually Curate These Sections

These sections require human judgment - preserve them during updates:

| Section | Why Manual |
|---------|------------|
| **Golden Samples** | Requires taste - which file exemplifies good patterns? |
| **Heuristics** | Decision rules come from team experience |
| **Boundaries** | Always/Ask/Never rules reflect team policy |
| **Codebase State** | Tech debt awareness requires context |
| **Terminology** | Domain knowledge is human insight |
| **Architecture Decisions** | Why choices were made isn't extractable |

### Override Best Practices

When updating existing AGENTS.md files, preserve custom content:

**1. Use `--update` flag:**
```bash
scripts/generate-agents.sh /path/to/project --update
```
This preserves content outside `<!-- GENERATED:START -->` / `<!-- GENERATED:END -->` markers.

**2. Place custom content outside markers:**
```markdown
<!-- GENERATED:START -->
## Commands (auto-generated)
| Command | Purpose |
|---------|---------|
| `make test` | Run tests |
<!-- GENERATED:END -->

## Custom Heuristics (preserved)
| When | Do |
|------|-----|
| Adding endpoint | Create OpenAPI spec first |
```

**3. Use scoped overrides for exceptions:**
```
project/
├── AGENTS.md              # Global rules
└── legacy/
    └── AGENTS.md          # "Ignore linting in this directory"
```

**4. Review diffs before committing:**
```bash
# After regenerating
git diff AGENTS.md
# Ensure custom sections weren't overwritten
```

## Directory Coverage

When creating AGENTS.md files, create them in ALL key directories:

| Directory | Purpose |
|-----------|---------|
| Root | Precedence, architecture overview |
| `Classes/` or `src/` | Source code patterns |
| `Configuration/` or `config/` | Framework config |
| `Documentation/` or `docs/` | Doc standards |
| `Resources/` or `assets/` | Templates, assets |
| `Tests/` | Testing patterns |
