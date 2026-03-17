<!-- Managed by agent: keep sections and order; edit content, not structure. Last updated: {{TIMESTAMP}} -->

# AGENTS.md — {{SCOPE_NAME}}

<!-- AGENTS-GENERATED:START overview -->
## Overview
{{SCOPE_DESCRIPTION}}
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
{{PYTHON_VERSION_LINE}}
{{PACKAGE_MANAGER_LINE}}
{{VENV_LINE}}
{{ENV_VARS_LINE}}
<!-- AGENTS-GENERATED:END setup -->

<!-- AGENTS-GENERATED:START structure -->
## Project configuration
All tool config lives in `pyproject.toml` -- no `setup.cfg`, `setup.py`, `tox.ini`, or scattered config files.

```toml
[project]                    # PEP 621 metadata
[build-system]               # Build backend (hatchling, setuptools, flit, pdm)
[tool.ruff]                  # Linting + formatting (replaces black, isort, flake8, pylint)
[tool.ruff.lint]             # Lint rule selection
[tool.mypy]                  # Static type checking
[tool.pytest.ini_options]    # Test configuration
[tool.coverage]              # Coverage settings
```
<!-- AGENTS-GENERATED:END structure -->

<!-- AGENTS-GENERATED:START commands -->
## Build & tests

| Command | Purpose | ~Time |
|---------|---------|-------|
{{RUFF_CHECK_LINE}}
{{RUFF_FORMAT_LINE}}
{{MYPY_LINE}}
{{PYTEST_LINE}}
{{PYTEST_COV_LINE}}
{{BUILD_LINE}}
<!-- AGENTS-GENERATED:END commands -->

<!-- AGENTS-GENERATED:START code-style -->
## Code style & conventions

### Ruff (linting + formatting)
- Ruff replaces black, isort, flake8, pylint, pyflakes, pycodestyle in one tool
- Format: `ruff format .` -- black-compatible, deterministic
- Lint: `ruff check . --fix` -- auto-fix safe rules
- Config in `pyproject.toml` under `[tool.ruff]`
- Common rule sets: `E` (pycodestyle), `F` (pyflakes), `I` (isort), `UP` (pyupgrade), `B` (bugbear)

### Type hints (mypy)
- All functions must have type annotations (parameters + return)
- Use `mypy --strict` or configure strictness in `pyproject.toml`
- Modern syntax: `str | None` not `Optional[str]`, `list[int]` not `List[int]`
- Use `typing.TypeAlias` for complex types
- Use `Protocol` for structural subtyping (duck typing with types)

### Naming conventions
| Type | Convention | Example |
|------|------------|---------|
| Module | `snake_case` | `user_service.py` |
| Class | `PascalCase` | `UserService` |
| Function | `snake_case` | `get_user_by_id()` |
| Constant | `UPPER_SNAKE_CASE` | `MAX_RETRIES` |
| Type variable | `PascalCase` | `T = TypeVar("T")` |
| Private | `_leading_underscore` | `_internal_helper()` |

### Docstrings
- Google style preferred (compatible with Sphinx napoleon)
- Required for all public modules, classes, functions
- Include `Args:`, `Returns:`, `Raises:` sections

### Imports
- Ruff handles import sorting (`I` rules) -- no separate isort needed
- Group: stdlib, third-party, local (Ruff enforces this)
- Prefer absolute imports; relative only within package internals
<!-- AGENTS-GENERATED:END code-style -->

<!-- AGENTS-GENERATED:START testing -->
## Testing (pytest)
- Test files: `tests/` directory, files named `test_*.py`
- Test functions: `test_<description>()` -- no class needed for simple tests
- Fixtures: prefer `conftest.py` for shared fixtures
- Parametrize: use `@pytest.mark.parametrize` for data-driven tests
- Markers: `@pytest.mark.slow`, `@pytest.mark.integration` for selective runs
- Coverage: `pytest --cov=src --cov-report=term-missing`
- Assert style: plain `assert` (pytest rewrites for detailed output)
<!-- AGENTS-GENERATED:END testing -->

<!-- AGENTS-GENERATED:START dependency-management -->
## Dependency management

### uv (recommended)
```bash
uv sync                     # Install deps from uv.lock
uv add <package>            # Add dependency
uv add --dev <package>      # Add dev dependency
uv run pytest               # Run in managed venv
```

### poetry
```bash
poetry install              # Install deps from poetry.lock
poetry add <package>        # Add dependency
poetry add --group dev <p>  # Add dev dependency
poetry run pytest           # Run in managed venv
```

### pip (fallback)
```bash
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"     # Install with dev extras
```
<!-- AGENTS-GENERATED:END dependency-management -->

<!-- AGENTS-GENERATED:START security -->
## Security & safety
- Validate and sanitize all user inputs
- Use parameterized queries for database access (SQLAlchemy, asyncpg)
- Never use dynamic code evaluation functions with untrusted data
- Sensitive data: never log or expose in errors
- File paths: validate and use `pathlib.Path` for all path operations
- Subprocess: use list args, never `shell=True` with user input
- Dependencies: pin versions in lockfile, audit with `pip-audit` or `safety`
<!-- AGENTS-GENERATED:END security -->

<!-- AGENTS-GENERATED:START checklist -->
## PR/commit checklist
- [ ] `ruff check .` passes (no lint errors)
- [ ] `ruff format --check .` passes (formatting clean)
- [ ] `mypy .` passes (no type errors)
- [ ] `pytest` passes (all tests green)
- [ ] New public functions have type hints and docstrings
- [ ] No `# type: ignore` without explanation comment
<!-- AGENTS-GENERATED:END checklist -->

<!-- AGENTS-GENERATED:START examples -->
## Patterns to Follow
> **Prefer looking at real code in this repo over generic examples.**
> See **Golden Samples** section above for files that demonstrate correct patterns.
<!-- AGENTS-GENERATED:END examples -->

<!-- AGENTS-GENERATED:START help -->
## When stuck
- Python docs: https://docs.python.org
- Ruff rules reference: https://docs.astral.sh/ruff/rules/
- mypy cheat sheet: https://mypy.readthedocs.io/en/stable/cheat_sheet_py3.html
- pytest docs: https://docs.pytest.org
- Review existing patterns in this codebase
- Check root AGENTS.md for project-wide conventions
<!-- AGENTS-GENERATED:END help -->

## House Rules (project-specific)
<!-- This section is NOT auto-generated - add your project-specific rules here -->
{{HOUSE_RULES}}
