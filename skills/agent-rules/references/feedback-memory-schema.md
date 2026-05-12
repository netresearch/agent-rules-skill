# Feedback Memory Schema

Canonical format for **approved session learnings** materialized as project-rule or user-memory files. This schema is the contract between `retro-skill` (which writes these files) and `agent-rules-skill` (which manages how they integrate with AGENTS.md and project documentation).

## When this schema applies

| Destination | Path |
|---|---|
| **user-memory** (personal preference across projects) | `~/.claude/projects/<project-dir-slug>/memory/feedback_<slug>.md` |
| **project-rule** (project-specific convention) | `<project>/docs/feedback/feedback_<slug>.md` |

### Variable definitions

| Variable | Meaning | Example |
|---|---|---|
| `<project-dir-slug>` | Claude Code's encoding of the absolute working directory for user-memory. Slashes are replaced with `-`. | `/home/sme/p` → `-home-sme-p` |
| `<slug>` | kebab-case filename slug for *this specific learning* | `merge-strategy`, `preserve-commit-signing` |

`<project-dir-slug>` and `<slug>` are distinct. `retro-skill` MUST compute `<project-dir-slug>` deterministically from the absolute working directory at the time of materialization (not from any frontmatter field).

For user-memory **global** scope (not tied to a single project): place under whatever project-dir-slug Claude Code uses for global memory; consult `~/.claude/projects/` for the convention in use.

## Schema

```markdown
---
name: <human-readable title; may be free prose>
description: "<one-line summary; used for relevance scoring across sessions>"
type: feedback
originSessionId: <session-id-from-jsonl-filename>
---
**Why:** <1-2 paragraphs explaining the friction and root cause>

**How to apply:** <1-2 paragraphs describing how the assistant should behave next time>
```

### Field semantics

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Human-readable title for the learning. May be a free-form sentence (e.g. `"Preserve commit signing on rewrite operations"`) or a short slug (e.g. `"merge strategy"`). **Not necessarily kebab-case** — the canonical examples use both natural language and slugs. The **filename** uses an independent kebab-case slug (see "Filename slug" below). |
| `description` | yes | One-line summary, ≤200 chars. Used by retro-skill to score relevance against new friction. **MUST be double-quoted** when it contains any of `: # [ ] { } , & * ! \| > ' " % @` or a leading whitespace, or it may break YAML parsing. Safer rule: quote unconditionally. |
| `type` | yes | always `feedback` (distinguishes from other memory types). |
| `originSessionId` | recommended, not required | Session ID where the friction was first observed (audit trail). If absent, the file is still valid but loses traceability. |
| `**Why:**` body section | yes | Start of line, exact form `**Why:** ` (with trailing space). Without this, the file rots — readers can't judge if it still applies. |
| `**How to apply:**` body section | yes | Start of line, exact form `**How to apply:** `. Vague rules don't change behavior. |

### Filename slug (independent from `name`)

The `<slug>` in the filename `feedback_<slug>.md` is **separately chosen** by retro-skill, kebab-case, descriptive of the learning topic. It is NOT required to match `frontmatter.name`.

Canonical examples demonstrate the freedom: file `feedback_skill-sources.md` has `name: "skill source vs cache"`; file `feedback_no-version-bumps-in-feature-prs.md` has `name: "No version bumps in feature PRs"`.

## Project-rule placement

When `retro-skill` materializes a `project-rule` destination:

1. **Write file:** `<project>/docs/feedback/feedback_<slug>.md` (create `docs/feedback/` if missing).
2. **Add AGENTS.md index entry** under a `## Approved learnings` section:

```markdown
## Approved learnings

- [feedback_<slug>.md](docs/feedback/feedback_<slug>.md) — <one-line summary from frontmatter description>
```

The index entry is a single line; the full prose lives in the linked file.

### Section position in AGENTS.md

`## Approved learnings` should be placed **after `## Key Decisions` and before `## Boundaries`** in the `root-thin.md` template's section order. **Place it outside `<!-- AGENTS-GENERATED:START ... -->` markers** so `generate-agents.sh --update` preserves it — this section is managed by retro-skill, not by the generator.

If the project's AGENTS.md is at or near the 150-line cap (the harness AH-02 threshold), prune older inactive learnings or move to a scoped `AGENTS.md` rather than letting the index grow unbounded.

## User-memory placement

When `retro-skill` materializes a `user-memory` destination:

1. **Compute path:** `~/.claude/projects/<project-dir-slug>/memory/feedback_<slug>.md` for project-scoped learnings, OR the global-scope path (consult `~/.claude/projects/`).
2. **Write file** using the schema above.
3. **Add MEMORY.md index entry** under the existing flat `## Topic Files` section (no sub-sections):

```markdown
- [feedback_<slug>.md](feedback_<slug>.md) — <one-line summary>
```

Do not create a separate `## Feedback` heading — MEMORY.md uses a single flat list.

## Why this schema (rationale)

- **Frontmatter** is machine-readable and tool-discoverable.
- **`description`** lets retro-skill detect duplicates and rank relevance.
- **`Why:` + `How to apply:`** structure forces meaningful content; vague file = vague rule.
- **`originSessionId`** allows tracing back to the friction; supports audit and deprecation.

## Validation

A valid feedback file has:

- YAML frontmatter present and parseable by PyYAML / yq.
- Required fields populated (non-empty): `name`, `description`, `type`.
- `description` is double-quoted (or doesn't contain YAML-special characters).
- Both `**Why:** ` and `**How to apply:** ` body markers present at start-of-line.
- File path matches `feedback_<slug>.md` where `<slug>` is kebab-case (independent of frontmatter `name`).

`originSessionId` is recommended but its absence does NOT invalidate the file.

Optional `scripts/verify-feedback-memory.sh` (not yet implemented; tracked as TODO) can enforce this in CI.

## Validation gap (current state)

`references/verification-guide.md` does **not** yet include a row for feedback files. Adding the check is tracked separately. retro-skill's PR-time validation of materialized files is the de-facto enforcement until the agent-rules-skill validator catches up.

## Examples in the wild

The user's own memory at `~/.claude/projects/-home-sme-p/memory/` contains **9 files** following this schema:

- `feedback_dup-repo-verification.md`
- `feedback_merge-strategy.md`
- `feedback_merge-vs-rollout.md`
- `feedback_no-version-bumps-in-feature-prs.md`
- `feedback_obsolete-docs-prefer-delete.md`
- `feedback_preserve-commit-signing.md`
- `feedback_skill-iteration-cadence.md`
- `feedback_skill-sources.md`
- `feedback_subagent-default.md`

Some include an extended `metadata:` block (e.g. `feedback_merge-vs-rollout.md` has `metadata: { node_type: memory, type: feedback }`); that variant is tolerated, not required.

## See also

- `retro-skill/references/destination-taxonomy.md` — Where this schema applies (in retro-skill repo)
- `retro-skill/references/patch-workflow.md` — How retro-skill writes these (in retro-skill repo)
- `references/output-structure.md` — How AGENTS.md indexes feedback files
- `references/verification-guide.md` — How to validate the resulting AGENTS.md
