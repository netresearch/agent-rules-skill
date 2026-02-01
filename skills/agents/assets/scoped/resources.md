<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}

Static resources, assets, templates, and configuration files.
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
- Resources are typically consumed by other parts of the application
- Some resources may need preprocessing or compilation
- Check build scripts for resource handling
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START types -->
## Resource types
- **Templates**: HTML, email, or text templates
- **Static assets**: Images, fonts, icons, stylesheets
- **Configuration**: Default configs, schema files, fixtures
- **Localization**: Translation files, locale data
- **Data files**: JSON, YAML, CSV for static data
<!-- AGENTS-GENERATED:END types -->

<!-- AGENTS-GENERATED:START organization -->
## Organization conventions
- Group resources by type: `templates/`, `images/`, `locales/`
- Use consistent naming: lowercase, hyphens for spaces
- Keep related resources together
- Version large binary assets carefully (consider Git LFS)
<!-- AGENTS-GENERATED:END organization -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- Use descriptive file names: `user-profile-template.html` not `template1.html`
- Keep templates simple - logic belongs in code, not templates
- Use consistent indentation in structured files (JSON, YAML, XML)
- Document template variables and their expected values
- Optimize images before committing (compress, resize)
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START templates -->
## Template best practices
- Use clear placeholder syntax: `{{variable}}` or `${variable}`
- Document all required variables in comments or README
- Keep templates focused - one purpose per template
- Use partials/includes for reusable components
<!-- AGENTS-GENERATED:END templates -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Never store secrets in resource files
- Validate all resource files that accept user input
- Sanitize template variables to prevent injection
- Review images/assets for embedded metadata (EXIF, etc.)
- Use CSP-safe inline styles when applicable
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] File names are descriptive and consistent
- [ ] Images are optimized (compressed, correct size)
- [ ] Templates have documented variables
- [ ] No sensitive data in resources
- [ ] Structured files are valid (JSON, YAML syntax)
- [ ] Changes tested with consuming code
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Good vs. bad examples
**Good**: Organized structure
```
resources/
├── templates/
│   ├── email/
│   │   ├── welcome.html
│   │   └── password-reset.html
│   └── reports/
│       └── monthly-summary.html
├── images/
│   ├── logo.svg
│   └── icons/
└── locales/
    ├── en.json
    └── de.json
```

**Bad**: Flat and unclear
```
resources/
├── template1.html
├── template2.html
├── img1.png
├── img2.png
└── strings.json
```

**Good**: Documented template
```html
<!--
  User Welcome Email Template
  Variables:
    - {{user_name}}: User's display name
    - {{activation_link}}: Account activation URL
    - {{support_email}}: Support contact email
-->
<h1>Welcome, {{user_name}}!</h1>
```

**Bad**: Undocumented template
```html
<h1>Welcome, {{name}}!</h1>
<a href="{{link}}">Click here</a>
```
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Check how resources are consumed in the codebase
- Look for build/preprocessing scripts
- Review existing resources for patterns
- Check root AGENTS.md for project conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
