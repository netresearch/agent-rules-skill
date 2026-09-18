# AGENTS.md Quality Rubric

Grade AGENTS.md files so you know which ones most need work. The grade has two
layers that are **kept separate on purpose**:

1. **Deterministic score** — `${CLAUDE_SKILL_DIR}/scripts/score-agents.sh PATH`. A 0-100 from the four
   verifier scripts; no model call, so re-running on an unchanged tree gives the
   same grade — except a file dated *today*, where git's bare-date `--since` can
   shift the Currency axis within the day.
2. **Qualitative LLM overlay** — three axes a *reading agent* judges (below).
   These vary between runs, so they are **never folded into the deterministic
   number**; present them as a separate annotation.

## Deterministic axes (score-agents.sh)

| Axis | Max | Source | What it measures |
|------|-----|--------|------------------|
| Structure | 25 | `validate-structure.sh --json` | Managed header, thin root, precedence, scope links, CLAUDE.md symlink, required scoped sections |
| Currency | 20 | `check-freshness.sh --json` | Commits in scope since the file's "Last updated" date |
| Content | 20 | `verify-content.sh --json` | Documented files/commands/counts that match reality |
| Commands | 15 | `verify-commands.sh --json` | Documented commands that actually run (root only) |
| Conciseness | 20 | line count vs budget | Root ≤50 lines ideal; scoped files get a larger budget |

Per file: `percent = earned / (sum of applicable axis maxima) × 100`. Scoped
files have no Commands axis (maxima sum to 85, normalised to 100).

Grades: **A ≥90 · B ≥75 · C ≥50 · D ≥30 · F <30**.

## Qualitative LLM overlay (agent-judged)

Run after the deterministic score. Read each AGENTS.md and rate three axes the
scripts cannot measure. Use **strong / adequate / weak** with a one-line reason.

| Axis | Strong | Weak |
|------|--------|------|
| **Architecture clarity** | A new agent can place code from the file alone — key dirs, module relationships, entry points | Vague or missing structure; "see the code" |
| **Actionability** | Concrete, copy-paste commands, real paths, decisive heuristics ("squash-merge", "ask first") | Theoretical advice ("follow best practices", "write good tests") |
| **Non-obvious patterns** | Captures what code can't tell you — ordering deps, quirks, "why we do it this way" | Only restates what the filenames already say |

### A convention needs a fill-in skeleton, not a paragraph

Actionability is not only about commands. Where the file states a *convention*
the agent has to reproduce — commit trailers, a message format, a required
header — prose is followed partially even when it is read, because the agent's
own defaults fill the gap. Give it a skeleton to copy, near the top.

Measured 2026-09-18 on `TYPO3-Documentation/TYPO3CMS-Reference-CoreApi`, whose
`AGENTS.md` states its commit trailers as prose in two numbered rules: a clone
with one uncommitted edit, a headless session asked only for the commit
message, Haiku 4.5, six runs per variant.

| | prose rules | + skeleton | + skeleton and "replace the example" |
|---|---|---|---|
| required trailer present and correct | 4 / 12 | 6 / 6 | 6 / 6 |
| documented `Assisted-by:` form | 0 / 12 | 6 / 6 | 6 / 6 |
| model correctly named | — | 1 / 6 | 6 / 6 |

Two things the last column pays for:

- **A concrete example is copied verbatim.** Five of six runs filed
  `Assisted-by: Claude Sonnet 5` while a different model was running — a
  skeleton turns a placeholder into an assertion unless it says to replace it.
- **A placeholder loses the field.** Writing `<model name> <contact>` instead
  removed the false attribution by removing the trailer: it then appeared in
  1 of 6. Keep the example *and* say to replace it.

The control matters for the axis, too: deleting the file took every trailer to
0 of 6, so the file was being read the whole time. "Not followed" and "not
loaded" look identical in the output and have different fixes — verify which
one you have before rewriting content. Claude Code reaches the rules only
through `CLAUDE.md` (symlink or `@AGENTS.md` import), never by the AGENTS.md
name alone; see [`ai-tool-compatibility.md`](ai-tool-compatibility.md).

### How to feed it back: `--review`

Rate each file, write the ratings to JSON, and pass it to the scorer. It keeps the
deterministic grade as the headline and adds a clearly-labelled, **non-reproducible**
secondary grade:

```bash
cat > /tmp/review.json <<'JSON'
{
  "AGENTS.md":     {"architecture":"strong","actionability":"adequate","non_obvious":"weak"},
  "web/AGENTS.md": {"architecture":"weak","actionability":"weak","non_obvious":"weak"}
}
JSON
bash ${CLAUDE_SKILL_DIR}/scripts/score-agents.sh PATH --review /tmp/review.json
```

```
  B  78/100    AGENTS.md
       structure 25/25  currency 15/20  content 18/20  conciseness 20/20  commands 0/15
       with review: B ~75/100  (non-reproducible)
```

Rating → fraction of the axis max: **strong = 1.0 · adequate = 0.6 · weak = 0.2**.
Blended = `(deterministic_earned + llm_earned) / (deterministic_max + 25) × 100`.
The headline `percent`/`grade` are **byte-identical** with or without `--review` —
the overlay never moves the reproducible number.

- The overlay's job is to catch files that **score well but read poorly** — e.g.
  structurally complete (B+) yet every line is obvious, or actionability is vague.
  Those are the highest-value edits.
- The blended figure varies between reviews (model judgement); the deterministic
  headline stays put. Always cite both, never the blended number alone.

## Workflow

1. `${CLAUDE_SKILL_DIR}/scripts/score-agents.sh PATH` → deterministic report (worst-first).
2. Open the worst-graded files; run the three overlay axes on each.
3. Fix highest-leverage gaps first (a `D` on Structure is mechanical; a `weak`
   on Non-obvious patterns needs human/session knowledge — see
   [`feedback-memory-schema.md`](feedback-memory-schema.md) and the retro-skill).
