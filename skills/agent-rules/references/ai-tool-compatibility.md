# AI Tool Compatibility

How AGENTS.md integrates with different AI coding tools.

## Claude Code

Claude Code centers on CLAUDE.md files. For compatibility, use the `--claude-shim` flag to generate a CLAUDE.md that imports AGENTS.md:

```bash
scripts/generate-agents.sh /path/to/project --claude-shim
```

This creates a minimal CLAUDE.md:
```markdown
<!-- Auto-generated shim for Claude Code compatibility -->
@import AGENTS.md
```

This ensures AGENTS.md remains the source of truth while Claude Code can access it.

## OpenAI Codex

Codex uses stacking semantics with AGENTS.override.md for per-directory overrides:

1. **Concatenation order:** `~/.codex/AGENTS.md` -> root -> nested directories -> current dir
2. **Override files:** Place `AGENTS.override.md` in directories to add/override rules
3. **Size limit:** Default 32 KiB cap - keep root AGENTS.md lean so nested files aren't crowded out

**Best practices for Codex:**
- Keep root AGENTS.md under 4 KiB (leaves room for 7+ nested files)
- Use `--style=thin` template for optimal Codex compatibility
- Move detailed rules to scoped AGENTS.md files in subdirectories
- Use AGENTS.override.md for directory-specific behavior changes

Example override structure:
```
project/
├── AGENTS.md                    # Thin root (~2 KiB)
├── src/
│   ├── AGENTS.md               # Source patterns
│   └── AGENTS.override.md      # Override root rules for src/
└── tests/
    ├── AGENTS.md               # Test patterns
    └── AGENTS.override.md      # Allow larger PRs in tests/
```

## GitHub Copilot

GitHub Copilot uses `.github/copilot-instructions.md` for repository-wide instructions. This skill extracts existing Copilot instructions and can coexist with AGENTS.md files.
