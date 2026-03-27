# AI Tool Compatibility

How AGENTS.md integrates with different AI coding tools, and what mitigations are needed for each.

## Compatibility Matrix (March 2026)

| Agent | Native AGENTS.md | Subdirectory Auto-Load | Own Format | Mitigation |
|-------|:-:|:-:|---|---|
| **Codex CLI** | Yes (creator) | Yes (best-in-class) | `AGENTS.md` | None |
| **GitHub Copilot** | Yes | Yes | `.github/copilot-instructions.md` | None |
| **Cursor** | Yes | Yes | `.cursor/rules/*.mdc` | None |
| **Windsurf** | Yes | Yes (auto-scoped) | `.windsurf/rules/` | None |
| **Devin** | Yes | Yes | AGENTS.md primary | None |
| **Augment Code** | Yes | Yes (hierarchical) | `.augment/rules/` | None |
| **Roo Code** | Yes | Partial (recursive) | `.roo/rules/` | None |
| **JetBrains Junie** | Yes | Needs config path | `.junie/guidelines.md` | Set Guidelines path for monorepos |
| **Gemini CLI** | Via config | Yes (excellent) | `GEMINI.md` | Symlink or settings.json config |
| **Aider** | Via config | No auto-discovery | `CONVENTIONS.md` | `.aider.conf.yml` config |
| **Claude Code** | **No** | On-demand (CLAUDE.md only) | `CLAUDE.md` | **Auto-created when `.claude/` detected** |
| **Continue.dev** | **No** | No | `.continue/rules/` | Copy/link into rules dir |
| **Amazon Q** | **No** | No | `.amazonq/rules/` | Copy into rules dir |
| **Cline** | **No** | No | `.clinerules/` | Copy/link into dir |
| **Sourcegraph Cody** | **No** | No | `.sourcegraph/*.rule.md` | Copy content |
| **Tabnine** | **No** | No | `.tabnine/guidelines/` | Copy content |

## Symlink Strategy (Recommended)

The most reliable cross-agent solution is to **symlink** agent-specific files to AGENTS.md.
This keeps AGENTS.md as the single source of truth while enabling native loading in each tool.

### What to create

At **every level** where an AGENTS.md exists (root AND subdirectories):

```bash
# For each directory containing AGENTS.md:
ln -s AGENTS.md CLAUDE.md    # Claude Code on-demand loading
ln -s AGENTS.md GEMINI.md    # Gemini CLI on-demand loading
```

### Why subdirectory symlinks matter (verified behavior)

Claude Code loads CLAUDE.md files **on demand** when the agent reads files in that directory.
Without a CLAUDE.md symlink, subdirectory AGENTS.md files are **never auto-loaded** — even if
the root AGENTS.md explicitly links to them and says "read nearest AGENTS.md."

**Tested scenarios (March 2026):**

| Setup | Result |
|-------|--------|
| Root CLAUDE.md symlink only, no subdirectory symlinks | Subdirectory AGENTS.md NOT loaded. Agent sees root links but does not proactively read them. |
| Root + subdirectory CLAUDE.md symlinks | Subdirectory AGENTS.md auto-loaded when agent works in that directory. |
| Root instructions say "read nearest AGENTS.md" | Agent acknowledges instruction but does NOT act on it without explicit prompting. |

### Commit symlinks to git

Symlinks are tiny (9 bytes each) and should be committed:

```bash
git add CLAUDE.md GEMINI.md
git add internal/CLAUDE.md internal/GEMINI.md    # etc.
```

They work on all platforms (Linux, macOS, Windows with `core.symlinks=true`).

## Claude Code

Claude Code only reads `CLAUDE.md` files natively. AGENTS.md is not recognized.

**Feature request**: [anthropics/claude-code#6235](https://github.com/anthropics/claude-code/issues/6235) (3,294+ upvotes, no official response as of March 2026).

### Loading behavior

- **Root CLAUDE.md**: Auto-loaded at session start (always in context)
- **Subdirectory CLAUDE.md**: Loaded on demand when agent reads/edits files in that directory
- **AGENTS.md**: Never loaded natively — requires symlink

### Auto-detection (default behavior)

When `generate-agents.sh` detects a `.claude/` directory in the project, it **automatically creates
CLAUDE.md symlinks** at every level where an AGENTS.md is generated. No flags required.

This means Claude Code users get working agent instructions out of the box, without needing to
remember `--symlinks` or `--claude-shim` flags.

To opt out, pass `--no-symlinks` explicitly.

### Manual symlinks (if not using the generator)

```bash
# Root
ln -s AGENTS.md CLAUDE.md

# Every subdirectory with its own AGENTS.md
ln -s AGENTS.md src/CLAUDE.md
ln -s AGENTS.md internal/CLAUDE.md
ln -s AGENTS.md internal/web/CLAUDE.md
```

### Alternative: @import shim (root only, legacy)

If you need Claude-specific overrides on top of AGENTS.md:

```markdown
<!-- CLAUDE.md -->
@AGENTS.md

<!-- Claude-specific overrides below -->
```

Note: `@import` only works at root level. Subdirectories still need symlinks for on-demand loading.

### Alternative: SessionStart hook

For skill users only — auto-create symlinks at session start:

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "find . -name AGENTS.md -not -path './.git/*' | while read f; do dir=$(dirname \"$f\"); [ ! -e \"$dir/CLAUDE.md\" ] && ln -s AGENTS.md \"$dir/CLAUDE.md\"; done",
        "timeout": 5
      }]
    }]
  }
}
```

This only helps users who have the hook installed. Committed symlinks are more reliable.

## Google Gemini CLI

Gemini CLI reads `GEMINI.md` natively with excellent hierarchical support (global, project, subdirectory).

### Mitigation options

**Option A: Symlink** (recommended)
```bash
ln -s AGENTS.md GEMINI.md    # At every level
```

**Option B: settings.json config**
```json
{
  "context": {
    "fileName": ["AGENTS.md", "GEMINI.md"]
  }
}
```

## OpenAI Codex

Codex is the creator of the AGENTS.md standard and has the best support.

- **Concatenation order**: `~/.codex/AGENTS.md` → root → nested directories → current dir
- **Override files**: `AGENTS.override.md` at any level temporarily replaces the base file
- **Size limit**: Default 32 KiB combined (`project_doc_max_bytes`)
- **Fallback filenames**: Configurable via `~/.codex/config.toml`

**Best practices:**
- Keep root AGENTS.md under 4 KiB (leaves room for 7+ nested files)
- Use `--style=thin` template for optimal Codex compatibility
- Use AGENTS.override.md for directory-specific behavior changes

## Aider

Aider reads `CONVENTIONS.md` by default. AGENTS.md requires explicit configuration.

### Mitigation: .aider.conf.yml

```yaml
# .aider.conf.yml
read:
  - AGENTS.md
  - internal/AGENTS.md        # No auto-discovery — list each file explicitly
  - internal/web/AGENTS.md
```

Or via CLI: `aider --read AGENTS.md`

## GitHub Copilot

Full native support for AGENTS.md including subdirectories (announced August 2025).
Also reads CLAUDE.md and GEMINI.md as fallbacks.

Additionally supports its own format:
- `.github/copilot-instructions.md` — repository-wide instructions
- `.github/instructions/*.instructions.md` — path-scoped via YAML frontmatter `applyTo` globs

## Agents Without Native Support

For **Continue.dev**, **Amazon Q**, **Cline**, **Sourcegraph Cody**, and **Tabnine**:

These agents use proprietary directory formats. The only mitigation is to copy or symlink
AGENTS.md content into their respective directories:

| Agent | Target |
|-------|--------|
| Continue.dev | `.continue/rules/agents.md` |
| Amazon Q | `.amazonq/rules/agents.md` |
| Cline | `.clinerules/agents.md` |
| Sourcegraph Cody | `.sourcegraph/agents.rule.md` |
| Tabnine | `.tabnine/guidelines/agents.md` |

Feature requests are open for most of these tools.

## Generation Script Integration

`generate-agents.sh` creates `CLAUDE.md` and `GEMINI.md` symlinks **by default** at every
level where an AGENTS.md is generated. Additionally, when a `.claude/` directory is detected
in the project (indicating a Claude Code environment), CLAUDE.md symlink creation is
**automatically enabled** even if `--no-symlinks` was passed.

```bash
scripts/generate-agents.sh /path/to/project              # Symlinks created by default
scripts/generate-agents.sh /path/to/project --no-symlinks # Skip symlinks (unless .claude/ detected)
```

The `--claude-shim` flag creates a root-only CLAUDE.md with `@import` (legacy behavior).
Use the default symlink behavior instead for full subdirectory support.
