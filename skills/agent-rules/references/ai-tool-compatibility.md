<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# AI Tool Compatibility

How AGENTS.md integrates with different AI coding tools, and what mitigations are needed for each.

## Compatibility Matrix (March 2026; Claude Code row November 2026)

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
| **Claude Code** | Yes (v2.1.277+) | On-demand | `CLAUDE.md` | **None — and no CLAUDE.md** (it would take precedence over AGENTS.md) |
| **Continue.dev** | **No** | No | `.continue/rules/` | Copy/link into rules dir |
| **Amazon Q** | **No** | No | `.amazonq/rules/` | Copy into rules dir |
| **Cline** | **No** | No | `.clinerules/` | Copy/link into dir |
| **Sourcegraph Cody** | **No** | No | `.sourcegraph/*.rule.md` | Copy content |
| **Tabnine** | **No** | No | `.tabnine/guidelines/` | Copy content |

## AGENTS.md Is the Only Instruction File

Keep one instruction file per directory: **AGENTS.md**. Do not create a `CLAUDE.md` — not as a
file, not as a symlink to AGENTS.md, not as an `@AGENTS.md` import — and remove an existing one.
Gemini CLI still needs a `GEMINI.md` symlink or a config entry (see below); that is a separate
tool and does not affect Claude Code.

## Claude Code

Claude Code reads AGENTS.md itself. Source: the Claude Code documentation,
[How Claude remembers your project → AGENTS.md](https://code.claude.com/docs/en/memory#agents-md)
(read 2026-11-27):

- **Version**: "Reading `AGENTS.md` directly requires Claude Code v2.1.277 or later."
- **Precedence (default setting `claude-md-or-agents-md`)**: Claude reads AGENTS.md "only when you
  have no `CLAUDE.md` in your working directory or above it". A `CLAUDE.md`, `.claude/CLAUDE.md` or
  `CLAUDE.local.md` in the working directory or any directory above it counts; when one exists,
  Claude reads "Your `CLAUDE.md` files only". `~/.claude/CLAUDE.md`, the managed `CLAUDE.md` and
  `.claude/rules/` do not count and load alongside AGENTS.md.
- **Subdirectories**: a subdirectory's `AGENTS.md` loads "when Claude opens a file there with the
  Read tool and that subdirectory has none of the three `CLAUDE.md` files of its own". No symlink is
  needed for on-demand loading.
- **Not read**: `AGENTS.local.md`, `AGENTS.override.md`, anything under `.agents/`.
- **Imports**: `@path` imports inside AGENTS.md are expanded.
- **Setting**: **Project instructions** in `/config` (`claude-md-or-agents-md` default,
  `claude-md-and-agents-md`, `claude-md`, `managed-only`), or `pluginConfigs` →
  `cc-plugin-agents-md@builtin` (before v2.1.285 the ID was `agents-md@builtin`) in user, `--settings`
  or managed settings; project and local settings files are ignored for it.
- **When support is unavailable** (Claude then reads `CLAUDE.md` files only): a version before
  v2.1.277; the built-in plugin disabled with `/plugin`; in some cases the first session after an
  upgrade from v2.1.276 or earlier. Before v2.1.281 some sessions (Amazon Bedrock, telemetry
  disabled) also read `CLAUDE.md` only — update Claude Code there instead of adding a `CLAUDE.md`.

So a `CLAUDE.md` next to AGENTS.md is not a compatibility aid any more: under the default setting
it **replaces** AGENTS.md for Claude, and a plain-text checkout of a `CLAUDE.md` symlink (Windows,
`core.symlinks=false`) leaves a file that contains only the word `AGENTS.md`. A personal
`CLAUDE.local.md` has the same effect; keep personal notes in `~/.claude/CLAUDE.md` instead.

To confirm what loaded, run `/context all` and check **Memory files**; an interactive session also
prints a line such as `no CLAUDE.md found; AGENTS.md loaded: …`.

### What the scripts do

- `generate-agents.sh` creates no `CLAUDE.md`. It removes a `CLAUDE.md` it made earlier (a symlink
  to AGENTS.md, an `@AGENTS.md` import file, the old `--claude-shim` file); a `CLAUDE.md` of the
  user's own is kept and reported with the step to take: move its rules into AGENTS.md (or
  `~/.claude/CLAUDE.md` for personal ones), then remove it. `--force` also removes an empty file, but never a `CLAUDE.md` that holds rules beyond the
  `@AGENTS.md` import line, and never a symlink to anything but the `AGENTS.md` of its directory
  (such a symlink is kept and reported with its target). `--claude-shim` is ignored.
- `validate-structure.sh` warns about every `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` beside an AGENTS.md.

## Google Gemini CLI

Gemini CLI reads `GEMINI.md` natively with excellent hierarchical support (global, project, subdirectory).

### Mitigation options

**Option A: Symlink** (recommended)
```bash
ln -s AGENTS.md GEMINI.md    # At every level with an AGENTS.md; commit the symlink
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

`generate-agents.sh` creates a `GEMINI.md` symlink **by default** at every level where an
AGENTS.md is generated (an `@AGENTS.md` import file in `Documentation/`, whose renderer rejects
symlinks), and no `CLAUDE.md`. `--no-symlinks` turns the `GEMINI.md` files off.

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/generate-agents.sh /path/to/project              # GEMINI.md symlinks, no CLAUDE.md
bash ${CLAUDE_SKILL_DIR}/scripts/generate-agents.sh /path/to/project --no-symlinks # no GEMINI.md either
```
