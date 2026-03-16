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
```

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

## License

This project uses split licensing:

- **Code** (scripts, workflows, configs): [MIT](LICENSE-MIT)
- **Content** (skill definitions, documentation, references): [CC-BY-SA-4.0](LICENSE-CC-BY-SA-4.0)

See the individual license files for full terms.
## Credits

Developed and maintained by [Netresearch DTT GmbH](https://www.netresearch.de/).

---

**Made with ❤️ for Open Source by [Netresearch](https://www.netresearch.de/)**
