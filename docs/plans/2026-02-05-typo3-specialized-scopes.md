# Skill-Aware Scopes Plan

**Goal:** Reference relevant skills in AGENTS.md templates so agents know which skill to invoke for specialized work.

**Pattern:**
```markdown
## Skill Reference
> For comprehensive guidance: **Invoke skill:** `skill-name`
```

**Scope → Skill Mapping:**

| Scope/Context | Skill | When |
|---------------|-------|------|
| `Tests/` in TYPO3 ext | `typo3-testing` | PROJECT_TYPE=php-typo3-extension |
| `Documentation/` in TYPO3 ext | `typo3-docs` | PROJECT_TYPE=php-typo3-extension |
| `.ddev/` folder | `typo3-ddev` | .ddev/ exists |
| TYPO3 extension root | `typo3-conformance` | PROJECT_TYPE=php-typo3-extension |
| PHP project root | `php-modernization` | LANGUAGE=php |
| `Dockerfile` / `compose.yml` | `docker-development` | docker scope detected |

**Approach:**
1. Create new specialized templates where needed
2. Add skill references to existing templates
3. Update scope detection for new scopes (.ddev/)

---

## Task 1: Create typo3-testing.md Template (NEW)

**File:** `skills/agents/assets/scoped/typo3-testing.md`

**Content highlights:**
```markdown
# AGENTS.md — {{SCOPE_NAME}}

## Overview
TYPO3 extension test suite. **Use the `typo3-testing` skill** for detailed guidance.

## Test Types
| Type | Location | Command |
|------|----------|---------|
| Unit | `Tests/Unit/` | `composer ci:test:php:unit` |
| Functional | `Tests/Functional/` | `composer ci:test:php:functional` |

## Key Patterns (TYPO3-specific)
- Use `typo3/testing-framework` for functional tests
- Fixtures go in `Tests/Functional/Fixtures/`
- Test classes extend `\TYPO3\TestingFramework\Core\Unit\UnitTestCase`
- Functional tests extend `\TYPO3\TestingFramework\Core\Functional\FunctionalTestCase`

## Skill Reference
> For comprehensive testing guidance including fixtures, mocking, and CI setup:
> **Invoke skill:** `typo3-testing`
```

---

## Task 2: Create typo3-docs.md Template

**File:** `skills/agents/assets/scoped/typo3-docs.md`

**Content highlights:**
```markdown
# AGENTS.md — {{SCOPE_NAME}}

## Overview
TYPO3 extension documentation (RST format). **Use the `typo3-docs` skill** for detailed guidance.

## Structure (docs.typo3.org standard)
```
Documentation/
├── Index.rst           # Main entry point
├── Introduction/
│   └── Index.rst
├── Installation/
│   └── Index.rst
├── Configuration/
│   └── Index.rst
├── Editor/
│   └── Index.rst
└── Settings.cfg        # Sphinx configuration
```

## Key Patterns (TYPO3-specific)
- Use RST format, not Markdown
- Follow docs.typo3.org rendering guidelines
- Use TYPO3 directives: `confval`, `versionadded`, `deprecated`
- Screenshots go in `Documentation/Images/`

## Commands
- Render locally: `docker run --rm -v $(pwd):/project ghcr.io/typo3-documentation/render-guides:latest`
- Preview: Open `Documentation-GENERATED-temp/Index.html`

## Skill Reference
> For RST syntax, TYPO3 directives, and docs.typo3.org deployment:
> **Invoke skill:** `typo3-docs`
```

---

## Task 3: Modify detect-scopes.sh for TYPO3 Context

**File:** `skills/agents/scripts/detect-scopes.sh`

**Change:** In the PHP/TYPO3 section, use TYPO3-specific scope types:

```bash
# Current (line 100-113):
[ -d "Tests" ] && {
    count=$(count_source_files "Tests" "*.php")
    [ "$count" -ge 3 ] && add_scope "Tests" "testing" "$count"
}

[ -d "Documentation" ] && {
    count=$(find Documentation -type f \( -name "*.rst" -o -name "*.md" \) | wc -l)
    [ "$count" -ge 3 ] && add_scope "Documentation" "documentation" "$count"
}

# After:
[ -d "Tests" ] && {
    count=$(count_source_files "Tests" "*.php")
    if [ "$count" -ge 3 ]; then
        if [ "$PROJECT_TYPE" = "php-typo3-extension" ]; then
            add_scope "Tests" "typo3-testing" "$count"
        else
            add_scope "Tests" "testing" "$count"
        fi
    fi
}

[ -d "Documentation" ] && {
    count=$(find Documentation -type f \( -name "*.rst" -o -name "*.md" \) | wc -l)
    if [ "$count" -ge 3 ]; then
        if [ "$PROJECT_TYPE" = "php-typo3-extension" ]; then
            add_scope "Documentation" "typo3-docs" "$count"
        else
            add_scope "Documentation" "documentation" "$count"
        fi
    fi
}
```

---

## Task 4: Test with Real TYPO3 Extension

**Test fixture:** Use `t3x-rte-ckeditor-image` or create minimal fixture with `Tests/` and `Documentation/` folders.

```bash
# Generate
bash skills/agents/scripts/generate-agents.sh skills/agents/references/examples/t3x-rte-ckeditor-image --force

# Verify scopes detected
bash skills/agents/scripts/detect-scopes.sh skills/agents/references/examples/t3x-rte-ckeditor-image | jq .

# Check generated AGENTS.md files reference skills
grep -r "typo3-testing\|typo3-docs" skills/agents/references/examples/t3x-rte-ckeditor-image/
```

---

## Task 5: Commit and Release

```bash
git add skills/agents/assets/scoped/typo3-testing.md \
        skills/agents/assets/scoped/typo3-docs.md \
        skills/agents/scripts/detect-scopes.sh
git commit -S -m "feat(scopes): add TYPO3-specific testing and docs templates

- typo3-testing.md: References typo3-testing skill, TYPO3 testing patterns
- typo3-docs.md: References typo3-docs skill, RST/docs.typo3.org standards
- detect-scopes.sh: Uses TYPO3 templates when PROJECT_TYPE=php-typo3-extension"
```

---

---

## Task 6: Create ddev.md Template (NEW)

**File:** `skills/agents/assets/scoped/ddev.md`

**Content highlights:**
```markdown
# AGENTS.md — {{SCOPE_NAME}}

## Overview
DDEV local development environment. **Use the `typo3-ddev` skill** for setup and configuration.

## Key Files
| File | Purpose |
|------|---------|
| `.ddev/config.yaml` | Main DDEV configuration |
| `.ddev/docker-compose.*.yaml` | Custom service overrides |
| `.ddev/commands/` | Custom DDEV commands |

## Common Commands
- Start: `ddev start`
- Stop: `ddev stop`
- SSH: `ddev ssh`
- Composer: `ddev composer ...`

## Skill Reference
> For DDEV setup, multi-version testing, and TYPO3 configuration:
> **Invoke skill:** `typo3-ddev`
```

---

## Task 7: Add Skill Reference to typo3-extension.md (MODIFY)

**File:** `skills/agents/assets/scoped/typo3-extension.md`

**Add section:**
```markdown
## Skill Reference
> For TYPO3 extension standards, TER compliance, and conformance checks:
> **Invoke skill:** `typo3-conformance`
```

---

## Task 8: Add Skill Reference to backend-php.md (MODIFY)

**File:** `skills/agents/assets/scoped/backend-php.md`

**Add section:**
```markdown
## Skill Reference
> For PHP 8.x modernization, type safety, and PHPStan compliance:
> **Invoke skill:** `php-modernization`
```

---

## Task 9: Add Skill Reference to docker.md (MODIFY)

**File:** `skills/agents/assets/scoped/docker.md`

**Add section:**
```markdown
## Skill Reference
> For Dockerfile best practices, multi-stage builds, and compose patterns:
> **Invoke skill:** `docker-development`
```

---

## Task 10: Add .ddev/ Scope Detection (MODIFY)

**File:** `skills/agents/scripts/detect-scopes.sh`

**Add detection for .ddev folder (in PHP section or generic):**
```bash
# DDEV local development
[ -d ".ddev" ] && {
    count=$(find .ddev -type f \( -name "*.yaml" -o -name "*.yml" \) | wc -l)
    [ "$count" -ge 1 ] && add_scope ".ddev" "ddev" "$count"
}
```

---

## Task 11: Test All Changes

```bash
# Test TYPO3 extension with Tests/, Documentation/, .ddev/
bash skills/agents/scripts/generate-agents.sh skills/agents/references/examples/t3x-rte-ckeditor-image --force

# Verify skill references appear
grep -r "Invoke skill" skills/agents/references/examples/t3x-rte-ckeditor-image/

# Test PHP project
bash skills/agents/scripts/generate-agents.sh skills/agents/references/examples/php-with-frontend --force
grep "php-modernization" skills/agents/references/examples/php-with-frontend/AGENTS.md
```

---

## Summary

| File | Change | Skill Referenced |
|------|--------|------------------|
| `typo3-testing.md` | NEW | `typo3-testing` |
| `typo3-docs.md` | NEW | `typo3-docs` |
| `ddev.md` | NEW | `typo3-ddev` |
| `typo3-extension.md` | ADD skill ref | `typo3-conformance` |
| `backend-php.md` | ADD skill ref | `php-modernization` |
| `docker.md` | ADD skill ref | `docker-development` |
| `detect-scopes.sh` | ADD .ddev detection, TYPO3-specific scope types |

**Effort:** Medium - 3 new templates, 3 template modifications, scope detection updates
