# Fleet Sync Sweep

Bringing AGENTS.md across a whole repo fleet to one standard, in one pass. Written after the 2026-08-19 sweep over 24 `netresearch/t3x-*` repositories (17 with existing files to sync, 5 with none at all, 2 already done) — every step below either saved that sweep or was learned by breaking it.

## Shape

Four phases, in this order. The expensive mistake is starting the per-repo work before the assessment exists — you then discover mid-sweep that a third of the fleet needs a different treatment.

1. **Assess mechanically, all repos, before touching one.** One script that per repo fetches, resolves the default branch, creates or updates a checkout, then runs `validate-structure.sh`, `score-agents.sh` and (if the harness is in play) `verify-harness.sh`, writing one TSV row plus a per-repo log. That table is the plan: it separates the repos that need a *sync* from those that need first-time *generation*, and its before/after numbers become the report.
2. **Write a playbook file, not a prompt.** Every trap you already know goes in one markdown file that each agent reads first. A trap explained in a prompt is explained once per agent and drifts; a playbook file is one artifact you can fix mid-sweep.
3. **Fan out in small batches**, each agent on one repo in its own worktree.
4. **Verify and merge in the main loop only.** Never the agent.

## The playbook file

It must state, at minimum: the worktree convention with absolute paths, the exact verification commands and their pass criteria, the required sections for scoped files, the CLAUDE.md convention including directories where symlinks are forbidden, commit/PR conventions (signing, conventional commits, no bot attribution, issue-before-PR where the repo demands it), and a fixed report format the agent must end with.

Two clauses do the heavy lifting:

- **"Never merge."** State it as the first absolute rule. An agent that merges removes your verification step entirely, and it will merge if it can.
- **"Verify every fact you write."** Commands against `composer.json`/`Makefile`, CI claims against the workflow file, referenced paths against the tree. Documentation drift is exactly what the sweep exists to fix; an agent inventing new drift while fixing old drift is the failure mode that looks like success.

## Batch size

Cap concurrent agents at ~4. Larger fan-outs trip the global rate limiter, and a throttled agent fails in ways that look like content problems. Batches of four across six waves cost less wall-clock than one wave of twenty that half-fails.

## Verification in the main loop

The per-repo scripts are necessary and not sufficient. In the 2026-08-19 sweep all three agent errors that mattered passed `validate-structure.sh` **and** `verify-harness.sh` green:

| What the agent did | What caught it |
|---|---|
| Deleted a curated "Response Style" section to meet the line budget | reading the diff for removed `##` headings |
| Wrote a file count into a scoped file | the repo's own convention test, red in CI |
| Wrote a non-conventional commit subject | reading `git log --format=%s -1` |

So the main-loop pass per PR is: rerun the tools yourself (never trust the reported numbers), diff every documented command against the real `composer.json`/`Makefile`, resolve every referenced path, and for each removed heading prove where its content went — see [`verification-guide.md`](verification-guide.md). Only then merge.

## Traps that cost time

- **A background CI watcher dies with the worktree it was started in.** `getcwd: cannot access parent directories` after you clean up a merged repo. Start watchers from a stable directory, never from the worktree they are watching.
- **Fast-moving repos need the rebase built into the plan.** One repo's `main` moved twice between green CI and merge; each move meant rebase, re-verify, re-watch. Arm auto-merge as soon as the gate is clean rather than after the next status read.
- **Repo-specific tests outrank the generic rules.** One repo forbids file counts in agent docs and enforces it in its unit suite; the sweep's own "name what exists" phrasing broke it anyway. When a repo's CI red-flags generated documentation, the repo is right.
- **A default branch is not always `main`.** Resolve it per repo (`git ls-remote --symref origin HEAD`); one `master` in the fleet breaks every hardcoded assumption at once.
- **Local checkouts are unreliable ground truth.** Dirty, behind, or parked on someone's feature branch. Create the task worktree from `origin/<default>` and never edit the pre-existing checkout.

## Reporting

Report per repo: issue URL, PR URL, gate state, checks, and the before/after numbers from phase 1. A sweep summary without the assessment numbers cannot be audited; with them, "average 68 → 96" is a claim someone can re-derive.
