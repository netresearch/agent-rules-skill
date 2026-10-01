<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# AGENTS.md Generator Skill

Netresearch AI skill for generating and maintaining AGENTS.md files following the [agents.md specification](https://agents.md/).

> **What is AGENTS.md?** A context file written **for AI coding agents**, not humans. Human readability is a side effect, not a goal. Adopted by 60,000+ open-source projects. See the [official specification](https://agents.md/) and [best practices from 2,500+ repositories](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/).

## Standards Compliance

This skill implements two complementary standards:

1. **[agents.md](https://agents.md/)** - The file format this skill generates. A simple Markdown convention for guiding AI coding agents, supported by Claude Code, GitHub Copilot, Cursor, and 60,000+ open-source projects.

2. **[Agent Skills](https://agentskills.io)** - How this skill is packaged and distributed. A portable format for procedural knowledge that works across AI agents.

**Supported Platforms:**
- ✅ Claude Code (Anthropic)
- ✅ Cursor
- ✅ GitHub Copilot
- ✅ Other skills-compatible AI agents


## Features

- **Thin Root Files** - ~30 lines with precedence rules and global defaults
- **Scoped Files** - Automatic subsystem detection (backend/, frontend/, internal/, cmd/)
- **Auto-Extraction** - Commands from Makefile, package.json, composer.json, go.mod
- **Multi-Language** - Templates for Go, PHP, TypeScript, Python, and hybrid projects
- **Idempotent Updates** - Preserve existing structure while refreshing content
- **Managed Headers** - Mark files as agent-maintained with timestamps

## Installation

### Marketplace (Recommended)

Add the [Netresearch marketplace](https://github.com/netresearch/claude-code-marketplace) once, then browse and install skills:

```bash
# Claude Code
/plugin marketplace add netresearch/claude-code-marketplace
/plugin install agent-rules@netresearch-claude-code-marketplace
```

### Without a marketplace

Since Claude Code 2.1.157 a plugin directory under your personal skills directory loads on its own:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/netresearch/agent-rules-skill.git \
  ~/.claude/skills/agent-rules
```

It loads as `agent-rules@skills-dir` on the next session. Update with `git -C ~/.claude/skills/agent-rules pull` and start a new session; remove it by deleting the directory. This route has no `claude plugin update`.

### npx ([skills.sh](https://skills.sh))

Install with any [Agent Skills](https://agentskills.io)-compatible agent:

```bash
npx skills add https://github.com/netresearch/agent-rules-skill --skill agent-rules
```

### Download Release

Download the [latest release](https://github.com/netresearch/agent-rules-skill/releases/latest) and extract to your agent's skills directory.

### Git Clone

```bash
git clone https://github.com/netresearch/agent-rules-skill.git
```

### Composer (PHP Projects)

```bash
composer require netresearch/agent-rules-skill
```

Requires [netresearch/composer-agent-skill-plugin](https://github.com/netresearch/composer-agent-skill-plugin).
### npm (Node Projects)

```bash
npm install --save-dev \
  @netresearch/agent-skill-coordinator \
  github:netresearch/agent-rules-skill
```

Requires [@netresearch/agent-skill-coordinator](https://github.com/netresearch/node-agent-skill-coordinator), which discovers the skill in `node_modules` and registers it in `AGENTS.md` via a `postinstall` hook. For pnpm, also allowlist the coordinator's postinstall:

```json
{
  "pnpm": {
    "onlyBuiltDependencies": ["@netresearch/agent-skill-coordinator"]
  }
}
```

## Usage

The skill triggers on keywords like:
- "AGENTS.md", "agents file"
- "agent documentation", "AI onboarding"
- "project context for AI"

### Example Prompts

```
"Generate AGENTS.md for this project"
"Update the agents documentation"
"Create scoped AGENTS.md files for each subsystem"
"Validate AGENTS.md structure"
```

## Supported Projects

| Type | Detection | Features |
|------|-----------|----------|
| Go | `go.mod` | Version extraction, CLI tool detection |
| PHP | `composer.json` | TYPO3/Laravel/Symfony detection |
| TypeScript | `package.json` | React/Next.js/Vue/Express detection |
| Python | `pyproject.toml` | Poetry/Ruff/Django/Flask detection |
| Hybrid | Multiple markers | Auto-creates scoped files per stack |

## Structure

```
agents/
├── SKILL.md              # AI instructions
├── README.md             # This file
├── LICENSE-MIT           # Code license (MIT)
├── LICENSE-CC-BY-SA-4.0  # Content license (CC-BY-SA-4.0)
├── composer.json         # PHP distribution
├── references/           # Convention documentation
├── scripts/              # Generator scripts
│   ├── generate-agents.sh
│   ├── validate-structure.sh
│   └── detect-scopes.sh
└── templates/            # Language-specific templates
    ├── go/
    ├── php/
    ├── typescript/
    └── python/
```

## Contributing

Contributions welcome! Please submit PRs for:
- Additional language templates
- Detection signal improvements
- Script enhancements
- Documentation updates

## Governance and policies

This repository follows the organisation-wide policies of `netresearch`:

- [Governance](https://github.com/netresearch/.github/blob/main/GOVERNANCE.md): roles, how changes are decided and disputes resolved, and who controls access to sensitive resources.
- [Roadmap](https://github.com/netresearch/.github/blob/main/ROADMAP.md): the maintenance work planned and excluded for the coming year.
- [Handling of dependency and code analysis findings](https://github.com/netresearch/.github/blob/main/SECURITY.md#handling-of-dependency-and-code-analysis-findings): which vulnerability, licence and static-analysis findings block a change, the deadlines for the others, and how exceptions are recorded.
- [Secret management](https://github.com/netresearch/.github/blob/main/SECURITY.md#secret-management): where CI secrets are stored, who can access them, and when they are rotated.
- [Access roster](https://github.com/netresearch/.github/blob/main/docs/access-roster.md): the accounts with admin, maintain and write access to this repository.

Checks that run on every pull request to `main` (`.github/workflows/security.yml`):

- Dependency review: fails on a known vulnerability of severity high or critical in a dependency the pull request adds or changes.
- Composer Audit: fails on a known vulnerability in a Composer dependency.
- Opengrep: static security analysis of the repository's code; which findings fail the check is set by the [organisation's static analysis rule](https://github.com/netresearch/.github/blob/main/SECURITY.md#static-analysis-sast).
- Betterleaks: fails on a committed secret.
- zizmor: static analysis of the GitHub Actions workflows; findings go to code scanning and do not fail the check.

What you can and cannot expect from this repository in terms of security, with its threat model: [docs/SECURITY-ASSURANCE.md](docs/SECURITY-ASSURANCE.md).

## License

This project uses split licensing:

- **Code** (scripts, workflows, configs): [MIT](LICENSE-MIT)
- **Content** (skill definitions, documentation, references): [CC-BY-SA-4.0](LICENSE-CC-BY-SA-4.0)

See the individual license files for full terms.
## Credits

Developed and maintained by [Netresearch DTT GmbH](https://www.netresearch.de/).

---

**Made with ❤️ for Open Source by [Netresearch](https://www.netresearch.de/)**
