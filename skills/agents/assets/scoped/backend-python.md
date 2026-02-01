<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}
<!-- AGENTS-GENERATED:END overview -->

<!-- AGENTS-GENERATED:START setup -->
## Setup & environment
- Install: `{{INSTALL_CMD}}`
- Python version: {{PYTHON_VERSION}}
- Package manager: {{PACKAGE_MANAGER}}
- Virtual env: `{{VENV_CMD}}`
- Environment variables: {{ENV_VARS}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests (prefer file-scoped)
- Typecheck a file: `{{TYPECHECK_CMD}} {{FILE_PATH}}`
- Format a file: `{{FORMAT_CMD}} {{FILE_PATH}}`
- Lint a file: `{{LINT_CMD}} {{FILE_PATH}}`
- Test a file: `{{TEST_CMD}} {{FILE_PATH}}`
- Build: {{BUILD_CMD}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions
- Follow PEP 8 style guide
- Use type hints for all function signatures
- Naming: `snake_case` for functions/variables, `PascalCase` for classes
- Docstrings: Google style, required for public APIs
- Imports: group by stdlib, third-party, local (use isort)
- Modern Python: prefer `|` over `Union`, `list` over `List`
{{FRAMEWORK_CONVENTIONS}}
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Validate and sanitize all user inputs
- Use parameterized queries for database access
- Never use dynamic code execution with untrusted data
- Sensitive data: never log or expose in errors
- File paths: validate and use `pathlib` for path operations
- Subprocess: use list args, avoid shell=True with user input
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] Tests pass: `{{TEST_CMD}}`
- [ ] Type check clean: `{{TYPECHECK_CMD}}`
- [ ] Lint clean: `{{LINT_CMD}}`
- [ ] Formatted: `{{FORMAT_CMD}}`
- [ ] Public functions have docstrings
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Good vs. bad examples
**Good**: Type hints and proper error handling
```python
def fetch_user(user_id: int) -> User | None:
    """Fetch user by ID, returns None if not found."""
    try:
        return db.query(User).filter_by(id=user_id).first()
    except DatabaseError as e:
        logger.error("Failed to fetch user %d: %s", user_id, e)
        raise
```

**Bad**: Missing types and bare except
```python
def fetch_user(user_id):
    try:
        return db.query(User).filter_by(id=user_id).first()
    except:
        pass
```

**Good**: Context managers and pathlib
```python
from pathlib import Path

def read_config(path: Path) -> dict:
    with path.open() as f:
        return json.load(f)
```
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Check Python documentation: https://docs.python.org
- Review existing patterns in this codebase
- Check root AGENTS.md for project-wide conventions
- Use `python -m pydoc <module>` for stdlib help
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
