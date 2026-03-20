# Eval: On-Demand AGENTS.md Loading

## Purpose

Verify that AGENTS.md content is actually loaded by coding agents when working in subdirectories.
This is a **manual/live eval** — it requires spawning real agent sessions.

## Methodology (Claude Code)

Tested March 2026 with Claude Opus 4.6.

### Test 1: Vanilla on-demand loading (with symlinks)

1. Create `internal/CLAUDE.md → AGENTS.md` symlink
2. Spawn a subagent: `Agent(prompt="What do you know about resettoken? Don't read any files.")`
3. **Expected**: Agent does NOT know resettoken details (not yet loaded)
4. Have the subagent read a file in `internal/` (e.g., `internal/resettoken/token.go`)
5. **Expected**: Agent NOW knows resettoken details from `internal/AGENTS.md` (auto-loaded via CLAUDE.md symlink)

### Test 2: Root instructions only (no subdirectory symlinks)

1. Remove `internal/CLAUDE.md` symlink
2. Root AGENTS.md contains links to `internal/AGENTS.md` and says "read nearest AGENTS.md"
3. Spawn a subagent tasked with working in `internal/`
4. **Expected**: Agent acknowledges the instruction but does NOT proactively read `internal/AGENTS.md`
5. **Conclusion**: Root-level instructions are insufficient — symlinks are required

### Test 3: No symlinks at all

1. Remove all CLAUDE.md symlinks
2. Spawn a subagent working in `internal/`
3. **Expected**: `internal/AGENTS.md` is never loaded

## Results (March 2026)

| Test | Subdirectory CLAUDE.md symlink? | Root instructions? | Loaded? |
|------|:-:|:-:|:-:|
| Test 1 (with symlink, after file access) | Yes | N/A | **Yes** |
| Test 2 (root instructions only) | No | Yes | **No** |
| Test 3 (no symlinks) | No | No | **No** |

## Conclusion

Claude Code's on-demand loading ONLY works through CLAUDE.md files. AGENTS.md files are
never loaded natively. Symlinks (`CLAUDE.md → AGENTS.md`) at every directory level are
required for subdirectory AGENTS.md content to be available.

Root-level instructions telling agents to "read nearest AGENTS.md" serve as documentation
and may help agents that follow explicit instructions, but Claude Code does not act on them.

## Automation

This eval cannot be fully automated because it requires:
1. A live Claude Code session with subagent capability
2. Introspection of the subagent's loaded context
3. Verification that context was loaded on-demand (not pre-loaded)

The static eval (`eval-symlink-generation`) verifies the prerequisites (symlinks exist).
This eval verifies the runtime behavior.
