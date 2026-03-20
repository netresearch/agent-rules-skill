# AI Agent Contribution Guidelines

Guidelines for AI agents contributing to projects with AGENTS.md files. Based on the "3 Cs" framework from GitHub's open source mentorship research (March 2026).

## The 3 Cs

### Comprehension

Before submitting any code change, the agent must demonstrate understanding of the problem:

- Read the linked issue fully — understand the *why*, not just the symptoms
- Check if the issue is already assigned to someone
- Understand the trade-offs involved (performance vs readability, backwards compatibility, etc.)
- If the issue is unclear, ask for clarification rather than guessing

**Red flag**: Submitting code that "looks right" without understanding why the current behavior exists.

### Context

Every PR must provide enough context for efficient review:

- Link to the issue being addressed (Fixes #NNN)
- Explain the approach taken and alternatives considered
- If AI tools assisted the contribution, disclose this if the project requires it
- Include test evidence (test output, before/after screenshots)
- Note any side effects or breaking changes

**Red flag**: A PR with only "Fixes the bug" as description.

### Continuity

Contributions are not fire-and-forget:

- Respond to review comments within a reasonable timeframe
- Be willing to iterate on feedback
- Don't submit to many projects simultaneously without capacity to follow up
- If you can't continue, say so — maintainers prefer honesty over silence

**Red flag**: Opening a PR and never responding to review feedback.

## Detection Patterns

The agent-rules skill detects contribution requirements from:

| Source | What's extracted |
|--------|-----------------|
| `CONTRIBUTING.md` | Issue-first requirements, AI disclosure policy |
| PR templates (`.github/pull_request_template.md`) | Required fields (issue links, test plans) |
| Branch protection rules | Linked issue requirements |
| `AGENTS.md` | Agent-specific boundaries and conventions |

## What AGENTS.md Signals

Having an AGENTS.md file signals:
- The project is AI-contribution-ready
- Agents should follow the conventions documented in the file
- The closest AGENTS.md to the files being changed takes precedence
- Explicit user instructions override AGENTS.md

## References

- [Rethinking open source mentorship in the AI era](https://github.blog/open-source/maintainers/rethinking-open-source-mentorship-in-the-ai-era/) (GitHub Blog, March 2026)
- [agents.md convention](https://agents.md/) — the standard our skill implements
