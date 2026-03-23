# Git Hooks Setup for Autonomous Agents

## Why Hooks Matter

Git hooks catch formatting errors, lint violations, and test failures **before commit** -- not minutes later in CI. For autonomous agents, this is critical: a failed CI run wastes time, tokens, and creates noisy fix-up commits. Hooks provide immediate feedback in the local loop.

## Detecting the Hook Framework

Check for these files in the repository root:

| File | Framework | Language ecosystem |
|------|-----------|-------------------|
| `lefthook.yml` or `.lefthook.yml` | [Lefthook](https://github.com/evilmartians/lefthook) | Any (Go binary) |
| `captainhook.json` | [CaptainHook](https://github.com/captainhookphp/captainhook) | PHP / Composer |
| `.husky/` directory | [Husky](https://github.com/typicode/husky) | Node.js / npm |
| `.pre-commit-config.yaml` | [pre-commit](https://pre-commit.com/) | Python / Any |

## Setup Commands

### Lefthook

```bash
# If a Makefile target exists (preferred)
make setup

# Otherwise install directly
go install github.com/evilmartians/lefthook@latest
lefthook install
```

### CaptainHook (PHP)

```bash
# Hooks install automatically via Composer plugin
composer install
```

CaptainHook registers itself as a Composer plugin. Running `composer install` triggers the post-install hook that sets up git hooks. No extra step needed.

### Husky (Node.js)

```bash
# Hooks install automatically via npm prepare script
npm install
```

Husky uses the `prepare` lifecycle script in `package.json`. Running `npm install` (or `yarn install`) automatically runs `husky install`.

### pre-commit (Python)

```bash
pip install pre-commit
pre-commit install
```

Or if the project uses a virtual environment:

```bash
# Inside activated venv
pre-commit install
```

## When No Hooks Exist

If no hook framework is detected:

1. **Do not skip this step.** The absence of hooks is a gap worth flagging.
2. Suggest adding hooks to the project -- recommend Lefthook for polyglot repos, or the ecosystem-native tool (Husky for JS, CaptainHook for PHP, pre-commit for Python).
3. See the `git-workflow` skill for hook framework setup guidance.

## Never Skip Hooks

**NEVER** use `--no-verify` to bypass hooks. If a hook fails:

1. Read the hook output to understand the failure.
2. Fix the underlying issue (formatting, lint error, failing test).
3. Stage the fix and commit again.

Skipping hooks defeats their purpose and pushes problems to CI where they are more expensive to fix.
