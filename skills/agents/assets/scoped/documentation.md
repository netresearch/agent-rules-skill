<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}

Project documentation, guides, and reference materials.
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START filemap -->
## Key Files
{{SCOPE_FILE_MAP}}
<!-- AGENTS-GENERATED:END filemap -->

<!-- AGENTS-GENERATED:START golden-samples -->
## Golden Samples (follow these patterns)
{{SCOPE_GOLDEN_SAMPLES}}
<!-- AGENTS-GENERATED:END golden-samples -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
- Documentation may use a static site generator (check for config files)
- Preview locally before committing major changes
- Check for broken links and formatting issues
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Building docs
- Preview: check for `npm run docs`, `make docs`, or similar
- Build: check for documentation build commands in root
- Serve locally to verify rendering
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START structure -->
## Documentation structure
- `README.md` - Entry point, project overview
- `getting-started/` - Installation and quick start guides
- `guides/` - How-to guides and tutorials
- `reference/` - API documentation, configuration reference
- `architecture/` - Design documents, ADRs
- `contributing/` - Contribution guidelines
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- Use clear, concise language
- Include code examples for technical concepts
- Keep line length reasonable (~80-120 chars for readability)
- Use consistent heading hierarchy (H1 for page title, H2 for sections)
- Add alt text to images for accessibility
- Use relative links for internal references
- Keep code examples up-to-date with actual codebase
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START markdown -->
## Markdown best practices
- Use fenced code blocks with language hints: ```python
- Use tables for structured data comparison
- Use admonitions for warnings/notes (if supported)
- Keep paragraphs focused on one idea
- Use bullet points for lists, numbered lists for sequences
<!-- AGENTS-GENERATED:END markdown -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Never include secrets, API keys, or credentials in examples
- Use placeholder values: `your-api-key`, `example.com`
- Review screenshots for sensitive information
- Avoid documenting security vulnerabilities in detail
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] Documentation matches current code behavior
- [ ] Code examples are tested and work
- [ ] Links are valid (no 404s)
- [ ] Images have alt text
- [ ] Spelling and grammar checked
- [ ] Formatting renders correctly
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Check existing documentation for patterns
- Review the style guide (if one exists)
- Preview changes locally before committing
- Check root AGENTS.md for project conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
