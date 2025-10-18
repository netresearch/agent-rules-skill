# agents-skill Creation Status

**Created**: 2025-10-18
**Status**: PARTIAL - Core structure created, implementation needed

## ✅ Completed

1. **Directory Structure**: Created all necessary directories
2. **SKILL.md**: Complete skill metadata and documentation
3. **`.gitignore**`: Standard ignores
4. **Analysis**: Complete analysis of 21 real AGENTS.md files saved in `/tmp/agents-analysis.md`

## ⏳ Remaining Tasks

### High Priority (Core Functionality)

1. **Templates**:
   - `templates/root-thin.md` - Thin root template (simple-ldap-go style)
   - `templates/root-verbose.md` - Verbose root template
   - `templates/scoped/*.md` - Scoped file templates for different types
   - `templates/sections/*.md` - Modular section templates

2. **Main Generator** (`scripts/generate-agents.sh`):
   - Orchestrate detection → extraction → generation
   - Handle --dry-run, --update, --force flags
   - Template rendering with placeholder replacement

3. **Detection Scripts**:
   - `scripts/detect-project.sh` - Auto-detect language, framework, tools
   - `scripts/detect-scopes.sh` - Find directories needing scoped files
   - `scripts/extract-commands.sh` - Parse Makefile, package.json, etc.

4. **Examples**: Copy real AGENTS.md from analyzed projects:
   - `references/examples/simple-ldap-go/` - Perfect thin root
   - `references/examples/ldap-selfservice/` - Hybrid Go + TS
   - `references/examples/t3x-rte-ckeditor-image/` - PHP TYPO3
   - `references/examples/coding-agent-cli/` - Python CLI

### Medium Priority (Quality & Validation)

5. **Validation** (`scripts/validate-structure.sh`):
   - Check root is thin
   - Verify 9-section schema in scoped files
   - Validate managed headers
   - Check links work

6. **README.md**:
   - Installation instructions
   - Quick start guide
   - Examples with screenshots
   - Troubleshooting

### Low Priority (Polish)

7. **LICENSE**: GPL-2.0-or-later
8. **References**:
   - Copy `/tmp/agents-analysis.md` → `references/analysis.md`
   - Create `references/best-practices.md`
   - Save user's prompt to `references/prompt.md`

## 📦 Quick Implementation Guide

### 1. Create root-thin Template

File: `templates/root-thin.md`

```markdown
<!-- Managed by agent: keep sections & order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md (root)

**Precedence:** The **closest AGENTS.md** to changed files wins. Root holds global defaults only.

## Global rules
- Keep PRs small (~≤300 net LOC)
- Conventional Commits: type(scope): subject
- Ask before: heavy deps, full e2e, repo rewrites
- Never commit secrets or PII

## Minimal pre-commit checks
- Typecheck: {{TYPECHECK_CMD}}
- Lint: {{LINT_CMD}}
- Format: {{FORMAT_CMD}}
- Tests: {{TEST_CMD}}

## Index of scoped AGENTS.md
{{SCOPE_INDEX}}

## When instructions conflict
Nearest AGENTS.md wins. User prompts override files.
```

### 2. Create Main Generator (Pseudo-code)

```bash
#!/usr/bin/env bash
# scripts/generate-agents.sh

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Detect project
PROJECT_INFO=$(./scripts/detect-project.sh .)

# Detect scopes
SCOPES=$(./scripts/detect-scopes.sh .)

# Extract commands
COMMANDS=$(./scripts/extract-commands.sh .)

# Generate root
./scripts/generate-root.sh --template=root-thin \
  --project="$PROJECT_INFO" \
  --commands="$COMMANDS" \
  --scopes="$SCOPES"

# Generate scoped files
echo "$SCOPES" | jq -r '.scopes[] | @base64' | while read scope; do
  SCOPE_DATA=$(echo "$scope" | base64 -d)
  PATH=$(echo "$SCOPE_DATA" | jq -r '.path')
  TYPE=$(echo "$SCOPE_DATA" | jq -r '.type')

  ./scripts/generate-scoped.sh --path="$PATH" \
    --type="$TYPE" \
    --project="$PROJECT_INFO" \
    --commands="$COMMANDS"
done

# Validate
./scripts/validate-structure.sh .
```

### 3. Project Detection (Pseudo-code)

```bash
#!/usr/bin/env bash
# scripts/detect-project.sh

detect_language() {
  [ -f go.mod ] && echo "go" && return
  [ -f composer.json ] && echo "php" && return
  [ -f package.json ] && echo "typescript" && return
  [ -f pyproject.toml ] && echo "python" && return
  echo "unknown"
}

detect_version() {
  case "$LANGUAGE" in
    go) grep '^go ' go.mod | awk '{print $2}' ;;
    php) jq -r '.require.php // "unknown"' composer.json ;;
    typescript) jq -r '.engines.node // "unknown"' package.json ;;
    python) grep 'requires-python' pyproject.toml | cut -d'"' -f2 ;;
  esac
}

# Output JSON
jq -n --arg lang "$LANGUAGE" \
      --arg ver "$VERSION" \
      --arg build "$BUILD_TOOL" \
      '{ type: $lang, version: $ver, build_tool: $build }'
```

## 🚀 Next Steps

1. **Implement templates** (start with root-thin.md)
2. **Create generator scripts** (start with detect-project.sh)
3. **Copy examples** from analyzed projects
4. **Test on real projects**:
   - `/tmp/simple-ldap-go` (should produce thin root)
   - `/tmp/t3x-rte_ckeditor_image` (should create scoped files)
5. **Create README.md** with usage examples
6. **Initialize git** and push to GitHub
7. **Add to marketplace** sync config

## 📝 Files Created So Far

```
/tmp/agents-skill/
├── .gitignore               ✅ Created
├── SKILL.md                 ✅ Created (complete)
├── STATUS.md                ✅ Created (this file)
├── templates/               ✅ Directory structure
│   ├── scoped/              ✅ Created
│   └── sections/            ✅ Created
├── scripts/                 ✅ Directory structure
│   └── lib/                 ✅ Created
└── references/              ✅ Directory structure
    └── examples/            ✅ Created
        ├── simple-ldap-go/  ✅ Created
        ├── ldap-selfservice/ ✅ Created
        ├── t3x-rte-ckeditor-image/ ✅ Created
        └── coding-agent-cli/ ✅ Created
```

## 📚 Reference Materials Available

- **Analysis document**: `/tmp/agents-analysis.md` (comprehensive)
- **Real AGENTS.md files**: All 21 files cloned and analyzed
- **Best example**: `/tmp/simple-ldap-go/AGENTS.md` (26 lines, perfect)
- **User's prompt**: Saved in conversation history

## ⚠️ Important Notes

- Token limit approaching - implementation stopped at core documentation
- All critical analysis and planning is complete
- Ready for implementation by continuing the conversation or manual completion
- Structure follows exact patterns from analyzed projects

Would you like me to continue implementing the scripts in a follow-up session?
