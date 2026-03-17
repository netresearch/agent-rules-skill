# AGENTS.md

## Project Overview

CLI Tools Skill (`netresearch/cli-tools-skill`) is an Agent Skill that provides automatic CLI tool management for AI agents. It detects missing tools from shell errors, installs them via optimal package managers, and audits project environments for missing or outdated tooling.

- **Repository**: https://github.com/netresearch/cli-tools-skill
- **Type**: Agent Skill (compatible with Claude Code, Cursor, GitHub Copilot)
- **License**: MIT (code) + CC-BY-SA-4.0 (content)
- **Entity**: Netresearch DTT GmbH

## Architecture

```
cli-tools-skill/
├── .claude-plugin/plugin.json    # Skill plugin manifest (version, metadata)
├── hooks/hooks.json              # PostToolUse hook config (triggers on Bash errors)
├── scripts/detect_missing_tool.py  # Hook script: parses "command not found" from stdin
├── catalog/                      # 74+ tool definitions (one JSON file per tool)
│   ├── ripgrep.json
│   ├── jq.json
│   └── ...
├── skills/cli-tools/
│   ├── SKILL.md                  # Skill definition and agent workflows
│   ├── scripts/                  # Installation and audit scripts
│   │   ├── install_tool.sh       # Main tool installer (dispatches to method-specific installers)
│   │   ├── check_environment.sh  # Environment audit script
│   │   ├── detect_project_type.sh  # Detects project type from files
│   │   ├── auto_update.sh        # Batch update all managed tools
│   │   ├── install_composer.sh   # Composer-specific installer
│   │   ├── lib/                  # Shared shell libraries
│   │   │   ├── common.sh         # Common utilities
│   │   │   ├── catalog.sh        # Catalog lookup functions
│   │   │   ├── capability.sh     # System capability detection
│   │   │   ├── dependency.sh     # Dependency resolution
│   │   │   ├── install_strategy.sh  # Strategy selection logic
│   │   │   ├── path_check.sh     # PATH management
│   │   │   ├── policy.sh         # Installation policy enforcement
│   │   │   ├── reconcile.sh      # State reconciliation
│   │   │   └── scope_detection.sh  # Scope (user/system) detection
│   │   └── installers/           # Method-specific installers
│   │       ├── github_release_binary.sh
│   │       ├── github_clone.sh
│   │       ├── npm_global.sh
│   │       ├── npm_self_update.sh
│   │       ├── uv_tool.sh
│   │       ├── package_manager.sh
│   │       ├── hashicorp_zip.sh
│   │       ├── aws_installer.sh
│   │       └── dedicated_script.sh
│   └── references/               # Extended documentation
│       ├── binary_to_tool_map.md
│       ├── preferred-tools.md
│       ├── project_type_requirements.md
│       ├── resolution-workflow.md
│       └── troubleshooting.md
├── Build/
│   ├── Scripts/                  # Build helper scripts
│   └── hooks/                    # Git hooks
└── .github/workflows/
    ├── lint.yml                  # CI: Markdown, YAML, ShellCheck, skill validation
    ├── release.yml               # Release on tag push (reusable from skill-repo-skill)
    └── auto-merge-deps.yml       # Auto-merge dependency update PRs
```

## Key Concepts

### Hook-Based Detection

The skill registers a `PostToolUse` hook (`hooks/hooks.json`) that runs `scripts/detect_missing_tool.py` after every Bash tool invocation. The Python script reads tool output from stdin, matches it against "command not found" patterns (bash, zsh, sh, PowerShell), extracts the tool name, and emits a `<system-reminder>` to the agent suggesting installation via the skill.

### Tool Catalog

Each tool in `catalog/` is a JSON file defining:
- `name`, `description`, `homepage`, `binary_name`
- `install_method` (or `"auto"` for multi-method)
- `available_methods` array with priority-ordered installation strategies
- `github_repo`, `download_url_template`, `arch_map` for binary downloads
- `requires` (dependency list), `tags` (categorization)

### Installation Priority

The skill selects installation methods in this order:
1. GitHub Release Binary (fastest, no dependencies)
2. Cargo (Rust tools)
3. UV/Pip (Python tools)
4. NPM (Node tools)
5. Apt/Brew (system packages, fallback)

User-level paths (`~/.local/bin`, `~/.cargo/bin`) are preferred over system-level.

### Project Type Detection

`detect_project_type.sh` identifies projects by marker files (e.g., `pyproject.toml` for Python, `go.mod` for Go, `composer.json` for PHP) and maps them to required tools.

## Development Guidelines

### Adding a New Tool

1. Create `catalog/<tool-name>.json` following the schema of existing entries (see `ripgrep.json` for a multi-method example, `jq.json` for a simple one).
2. If the binary name differs from the tool name, update `references/binary_to_tool_map.md`.
3. Test installation: `skills/cli-tools/scripts/install_tool.sh <tool> install`
4. Submit a PR.

### Modifying Installation Logic

- Shared libraries live in `skills/cli-tools/scripts/lib/` -- edit these for cross-cutting changes to strategy selection, dependency resolution, or PATH management.
- Method-specific logic lives in `skills/cli-tools/scripts/installers/` -- one file per installation method.
- The main dispatcher is `skills/cli-tools/scripts/install_tool.sh`.

### Modifying the Detection Hook

- The hook script is `scripts/detect_missing_tool.py` (project root, not under `skills/`).
- The hook configuration is `hooks/hooks.json`.
- The script must complete within the 3-second timeout configured in `hooks.json`.

### CI and Quality

CI runs on every push to `main` and on PRs via `.github/workflows/lint.yml`:
- **Markdown lint** (markdownlint-cli2)
- **YAML lint** (yamllint)
- **ShellCheck** with `-x` (follow sourced files), severity: error
- **Skill validation** via `netresearch/skill-repo-skill` reusable workflow

Releases are automated: push a signed tag (`v*`) and the release workflow handles it.

### Versioning

The version is tracked in `.claude-plugin/plugin.json`. Bump it before tagging a release. The `Build/Scripts/check-plugin-version.sh` script validates version consistency.

### Coding Standards

- Shell scripts must pass ShellCheck (severity: error, with `-x` for sourced files).
- Markdown must pass markdownlint-cli2 (config in `.markdownlint-cli2.jsonc`).
- YAML must pass yamllint (config in `.yamllint.yml`).
- SKILL.md must stay under 500 words; put extended content in `references/`.
- Use "Netresearch DTT GmbH" as the entity name in all metadata and license files.
