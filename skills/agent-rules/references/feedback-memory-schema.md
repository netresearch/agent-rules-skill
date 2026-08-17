# Feedback Memory Schema

How **approved session learnings** reach a repository, and the file format of
the learning files that earlier versions of `retro-skill` wrote. This is the
contract between `retro-skill` (which materializes learnings) and
`agent-rules-skill` (which owns how they sit in AGENTS.md).

`retro-skill` owns *what it writes and where*. This document follows it; where
the two disagree, [retro's destination
taxonomy](https://github.com/netresearch/retro-skill/blob/main/skills/retro/references/destination-taxonomy.md)
wins.

## Where approved learnings go today

| Destination | Target | Form |
|---|---|---|
| **`personal-rule`** (personal preference across projects) | `~/.claude/CLAUDE.md` | A titled rule appended to the always-loaded global rules file. Nothing lands in the repository, and nothing here manages it. |
| **`project-rule`** (project-specific convention) | `<project>/AGENTS.md` | A titled rule appended to AGENTS.md, which is the single project rule store. |

`personal-rule` was called `user-memory` in earlier versions; the old name is a
deprecated alias `retro` still accepts as input.

A rule in either target has the same shape:

```markdown
## <Short rule title>

<1-2 sentences: what to do and why. State the trigger and the action.>
```

**Not** `~/.claude/projects/<slug>/memory/`. That directory is cwd-scoped — a
file written there is only recalled when the working directory resolves to the
same project slug — so it is no longer a destination at all. It is only ever a
*source*: `/retro promote` drains what accumulated there upward into the
correct destination.

## Project-rule placement in AGENTS.md

The rule is appended under `## Approved learnings`.

### Section position

`## Approved learnings` goes **after `## Key Decisions` and before
`## Boundaries`** in the `root-thin.md` template's section order, and
**outside** any `<!-- AGENTS-GENERATED:START ... -->` markers, so that
`generate-agents.sh --update` preserves it. The section is managed by
`retro-skill`, not by the generator.

### Size

AGENTS.md is an index, and the harness caps it at 150 lines (`AH-02`). When the
section pushes against that cap, prune learnings that no longer apply or move
them to a scoped `AGENTS.md` next to the code they govern. Growing the root
index unbounded trades one problem for another: a 400-line AGENTS.md is read
less carefully than a 120-line one.

## Legacy learning files

Earlier versions wrote each learning to its own file —
`<project>/docs/feedback/feedback_<slug>.md` for project rules,
`~/.claude/projects/<slug>/memory/feedback_<slug>.md` for personal ones — with
a one-line index entry in AGENTS.md pointing at it. Those files still exist in
repositories and in local memory, `retro` still reads them, and `/retro
promote` re-homes the personal ones. Nothing writes new ones.

Keep reading them in this format:

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

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Human-readable title. May be free-form (`"Preserve commit signing on rewrite operations"`) or a short slug (`"merge strategy"`) — **not necessarily kebab-case**. The filename slug is independent of it. |
| `description` | yes | One-line summary, ≤200 chars, used to score relevance against new friction. **MUST be double-quoted** when it contains any of `: # [ ] { } , & * ! \| > ' " % @` or leading whitespace. Safer rule: quote unconditionally. |
| `type` | yes | Always `feedback`. |
| `originSessionId` | recommended | Session where the friction was first observed. Its absence does not invalidate the file, only its traceability. |
| `**Why:**` body section | yes | Start of line, exact form `**Why:**` plus a trailing space. Without it the file rots — a reader cannot judge whether it still applies. |
| `**How to apply:**` body section | yes | Start of line, exact form `**How to apply:**` plus a trailing space. A vague rule changes no behaviour. |

An extended `metadata:` block (`node_type`, `type`) appears in some files; it is
tolerated, not required.

A legacy file is valid when its frontmatter parses (PyYAML / yq), `name`,
`description` and `type` are non-empty, both body markers are present at start
of line, and the filename matches `feedback_<slug>.md` with a kebab-case slug.

An AGENTS.md that still indexes such files keeps working — the index entry is a
plain link, and the harness `AH-10` check verifies that it resolves. Migrating
an existing `docs/feedback/` tree into AGENTS.md rules is optional and is not
something this skill does automatically.

## Why the format was what it was

- **Frontmatter** is machine-readable and tool-discoverable.
- **`description`** lets retro detect duplicates and rank relevance.
- **`Why:` + `How to apply:`** forces content that can be acted on; a vague file
  is a vague rule.
- **`originSessionId`** traces a rule back to the friction that produced it,
  which is what makes deprecating it later possible.

The current inline-rule form keeps the first, third and fourth properties in a
smaller footprint: the rule is read where it is stored, and there is one place
to look instead of an index plus a file.

## Validation gap (current state)

`references/verification-guide.md` has no row for approved-learning sections
yet. Until it does, `retro-skill`'s own PR-time validation of what it
materializes is the de-facto enforcement.

## See also

- [`retro-skill` destination taxonomy](https://github.com/netresearch/retro-skill/blob/main/skills/retro/references/destination-taxonomy.md) — the authoritative list of destinations and their materialization formats
- [`retro-skill` patch workflow](https://github.com/netresearch/retro-skill/blob/main/skills/retro/references/patch-workflow.md) — how retro writes them
- [`output-structure.md`](output-structure.md) — how AGENTS.md is laid out
- [`verification-guide.md`](verification-guide.md) — how to validate the resulting AGENTS.md
