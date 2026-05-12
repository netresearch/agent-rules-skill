# Feedback Memory Schema

Canonical format for **approved session learnings** materialized as project-rule or user-memory files. This schema is the contract between `retro-skill` (which writes these files) and `agent-rules-skill` (which manages how they integrate with AGENTS.md and project documentation).

## When this schema applies

- **user-memory destination:** `retro-skill` writes to `~/.claude/projects/<slug>/memory/feedback_<slug>.md`
- **project-rule destination:** `retro-skill` writes to `<project>/docs/feedback/<slug>.md`

Both files use the same schema. The location indicates the scope.

## Schema

```markdown
---
name: <kebab-case-slug>
description: <one-line summary; used for relevance scoring across sessions>
type: feedback
originSessionId: <session-id-from-jsonl-filename, optional but recommended>
---
**Why:** <1-2 paragraphs explaining the friction and root cause>

**How to apply:** <1-2 paragraphs describing how the assistant should behave next time>
```

### Field semantics

| Field | Required | Notes |
|---|---|---|
| `name` | yes | kebab-case slug, used in filename (`feedback_<name>.md`) |
| `description` | yes | one-line summary, ≤200 chars; used by retro-skill to score relevance against new friction |
| `type` | yes | always `feedback` (distinguishes from other memory types) |
| `originSessionId` | recommended | Session ID where the friction was first observed (audit trail) |
| `**Why:** …` | yes | Root cause analysis. Without this, the file rots — readers can't judge if it still applies. |
| `**How to apply:** …` | yes | Concrete action for the agent. Vague rules don't change behavior. |

## Project-rule placement

When `retro-skill` materializes a `project-rule` destination:

1. **Write file:** `<project>/docs/feedback/<slug>.md` (create `docs/feedback/` if missing)
2. **Add AGENTS.md index entry:** under a `## Approved learnings` section:

```markdown
## Approved learnings

- [<slug>](docs/feedback/<slug>.md) — <one-line summary from frontmatter description>
```

The index entry is a single line; the full prose lives in the linked file. This keeps AGENTS.md as an index (the agent-rules-skill conformance rule), not a rule dump.

## User-memory placement

When `retro-skill` materializes a `user-memory` destination:

1. **Write file:** `~/.claude/projects/<slug>/memory/feedback_<slug>.md` (project-scoped) or `~/.claude/projects/<global>/memory/feedback_<slug>.md` if cross-project
2. **Add MEMORY.md index entry:** under appropriate topic in the existing MEMORY.md index pattern

## Why this schema (rationale)

- **Frontmatter** is machine-readable and tool-discoverable
- **`description`** lets retro-skill detect duplicates and rank relevance
- **`Why:` + `How to apply:`** structure forces meaningful content; vague file = vague rule
- **`originSessionId`** allows tracing back to the friction; supports audit and deprecation

## Validation

A valid feedback file must have:
- YAML frontmatter present and parseable
- All required fields populated (non-empty)
- Both `**Why:**` and `**How to apply:**` body sections present
- File path matches `feedback_<name>.md` where `<name>` equals frontmatter `name`

Optional `scripts/verify-feedback-memory.sh` (TODO) can be added later to enforce this in CI.

## Examples in the wild

The user's own memory at `~/.claude/projects/-home-sme-p/memory/` contains 8 files following this schema:

- `feedback_skill-sources.md`
- `feedback_skill-iteration-cadence.md`
- `feedback_merge-strategy.md`
- `feedback_dup-repo-verification.md`
- `feedback_obsolete-docs-prefer-delete.md`
- `feedback_subagent-default.md`
- `feedback_preserve-commit-signing.md`
- `feedback_no-version-bumps-in-feature-prs.md`
- `feedback_merge-vs-rollout.md`

These are canonical references for the format.

## See also

- `retro-skill/references/destination-taxonomy.md` — Where this schema applies
- `retro-skill/references/patch-workflow.md` — How retro-skill writes these
- `references/output-structure.md` — How AGENTS.md indexes feedback files
- `references/verification-guide.md` — How to validate the resulting AGENTS.md
