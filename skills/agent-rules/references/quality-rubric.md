# AGENTS.md Quality Rubric

Grade AGENTS.md files so you know which ones most need work. The grade has two
layers that are **kept separate on purpose**:

1. **Deterministic score** — `scripts/score-agents.sh PATH`. A 0-100 from the four
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
scripts/score-agents.sh PATH --review /tmp/review.json
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

1. `scripts/score-agents.sh PATH` → deterministic report (worst-first).
2. Open the worst-graded files; run the three overlay axes on each.
3. Fix highest-leverage gaps first (a `D` on Structure is mechanical; a `weak`
   on Non-obvious patterns needs human/session knowledge — see
   [`feedback-memory-schema.md`](feedback-memory-schema.md) and the retro-skill).
