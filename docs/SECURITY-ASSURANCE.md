<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Security assurance case — agent-rules-skill

This document states what a user can expect from this repository in terms of security, and argues why that expectation holds. Every claim names the file that implements it. Reporting a vulnerability: see the [security policy](https://github.com/netresearch/.github/blob/main/SECURITY.md). Scanner findings reviewed as false positives are recorded in [SECURITY-AUDIT.md](../SECURITY-AUDIT.md). Components and data flow: [ARCHITECTURE.md](ARCHITECTURE.md).

## What the repository ships

| Part | Files | Runs where |
| --- | --- | --- |
| Skill content: instructions and references for an AI agent | `skills/agent-rules/SKILL.md`, `skills/agent-rules/references/*.md` | Read by the agent as instructions; not executed |
| Templates | `skills/agent-rules/assets/` except `example-workflows/` | Rendered by `generate-agents.sh` into the `AGENTS.md` files it writes |
| Example workflow | `skills/agent-rules/assets/example-workflows/validate-agents.yml` | Copied by users into their own `.github/workflows/` |
| Example projects | `skills/agent-rules/references/examples/` | Read as examples; used as generator fixtures in CI (`.github/workflows/validate-agents.yml`) |
| Generator and checks | `skills/agent-rules/scripts/*.sh`, `skills/agent-rules/scripts/lib/*.sh` | On the user's machine, run by the agent or the user against a project directory given as `PATH` |
| Repository checks | `scripts/verify-harness.sh`, `Build/Scripts/check-plugin-version.sh`, `Build/hooks/pre-push`, `skills/agent-rules/scripts/tests/*.sh` | On contributors' machines (the pre-push hook runs `check-plugin-version.sh`, the others are run by hand); `skills/agent-rules/scripts/tests/*.sh` also in this repository's CI (`test-scripts.yml`) |

The skill has no server component, stores no data outside the target project, and handles no user accounts.

## Security requirements

1. The generator does not replace a `CLAUDE.md` or `GEMINI.md` that it did not create, unless the user passes `--force`.
2. The generator does not replace an existing `AGENTS.md` unless the user passes `--force` or `--update`; `--update` rewrites only the sections between `AGENTS-GENERATED` markers when the file has them, and renders the whole file anew when it has none.
3. With `--dry-run`, `generate-agents.sh` writes no file.
4. When the user sets `SMOKE_TEST=true`, `verify-commands.sh` refuses to run a command string that contains shell metacharacters or whose first word is not on its list of build tools.
5. The scripts send nothing from the target project to a network service other than the repository's owner and name, used to read its GitHub settings with the user's own `gh` login.
6. Nothing committed to this repository contains a secret.

## Actors and trust boundaries

- **Agent and skill user.** The agent reads `SKILL.md` and the references as instructions. Text in this repository is therefore trusted input to the agent; changes to it go through pull request review like code (see [Governance](https://github.com/netresearch/.github/blob/main/GOVERNANCE.md)). `SKILL.md` pre-approves only the skill's own scripts and `git`, `jq`, `grep`, `find`, `Read`, `Glob` and `Grep` (`allowed-tools` in the front matter).
- **Target project.** The scripts read the project at `PATH`: build files (`Makefile`, `package.json`, `composer.json`, `go.mod`, `pyproject.toml`), CI configuration, documentation and file names. The scripts treat this content as trusted: they are built to document a project the user works on, not to analyse code of unknown origin.
- **Generated files.** `AGENTS.md` and its scoped copies contain text taken from the target project (commands, paths, rules). An agent that later reads them treats that text as instructions.
- **GitHub API.** `extract-github-settings.sh` and `extract-github-rulesets.sh` read repository settings, branch protection and rulesets with `gh api` GET requests; `scripts/verify-harness.sh` reads the organisation's pull request template. They use the user's `gh` login and stop silently when `gh` is missing or not logged in.
- **CI.** Workflows run on GitHub-hosted runners with `permissions: {}` at the top level and the minimum job permissions each reusable workflow needs (`.github/workflows/*.yml`).

## Threats and countermeasures

| Threat | Countermeasure | Evidence |
| --- | --- | --- |
| The generator overwrites a user's own `CLAUDE.md` or `GEMINI.md` | A compatibility file is written only when it is absent, is a symlink to `AGENTS.md`, or is an `@AGENTS.md` import file; anything else is kept and reported unless `--force` is given | `generate-agents.sh` (`compat_file_is_ours`); `skills/agent-rules/scripts/tests/test-symlink-write-boundary.sh` (foreign symlink kept, foreign regular file kept, `--dry-run --force` leaves the foreign symlink in place), `skills/agent-rules/scripts/tests/test-claude-import-file.sh` |
| The generator discards hand-written content in an existing `AGENTS.md` | An existing file is kept unless `--force` or `--update`; `--update` replaces only the marked sections and keeps everything outside them except that every `Last updated: <date>` in the file is set to the current date; a file without `AGENTS-GENERATED` markers is rendered anew, like `--force` | `generate-agents.sh` (root and scope file checks), `skills/agent-rules/scripts/lib/template.sh` (`update_generated_sections`) |
| A documented command chains a second command during a smoke test (CWE-78) | Before a smoke test, `is_safe_command` rejects any string containing `;`, `&`, `\|`, `` ` ``, `$`, `<`, `>`, braces, parentheses, `*`, `?`, `!` or a newline, and any first word that is not on its list of build tools | `skills/agent-rules/scripts/verify-commands.sh` (`is_safe_command`); `skills/agent-rules/scripts/tests/test-command-allowlist.sh` asserts that `git status; touch PWNED` neither runs nor counts as verified, and that a plain allowlisted command still runs |
| A smoke-tested command hangs the run | Each smoke-tested command runs under `timeout` | `skills/agent-rules/scripts/verify-commands.sh` (`smoke_test_command`) |
| Code from the target project is loaded into the scripts' shell | The scripts `source` only their own files under `skills/agent-rules/scripts/lib/`; no script under `skills/agent-rules/scripts/` or its `lib/` uses `eval` (only the test `test-command-allowlist.sh` does, on the function text of `verify-commands.sh`); file names from the project reach commands as arguments, never inside a `sh -c` string | `generate-agents.sh`, `detect-project.sh`, `extract-commands.sh` (the `source` lines); `skills/agent-rules/scripts/tests/test-golden-sample-file-names.sh` |
| Project data leaves the machine | No script calls `curl` or `wget`; the only network access is the `gh api` GET requests named under trust boundaries | `extract-github-settings.sh`, `extract-github-rulesets.sh`, `scripts/verify-harness.sh` |
| A predictable temporary file is hijacked (CWE-377) | The only temporary file in a script under `skills/agent-rules/scripts/` or its `lib/` is created with `mktemp`, and the tests create their work directories with `mktemp -d`; no script uses a fixed path under `/tmp` | `skills/agent-rules/scripts/lib/template.sh` (`update_generated_sections`) |
| An error in one step goes unnoticed and a later step works on a partial result | The generator, detector, extractor and verification scripts run with `set -euo pipefail`; `score-agents.sh`, `validate-structure.sh` and the tests run with `set -uo pipefail` and handle failures explicitly | `skills/agent-rules/scripts/*.sh`, `scripts/verify-harness.sh`, `Build/Scripts/check-plugin-version.sh` |
| A secret is committed | Betterleaks scans every push and pull request to `main` | `.github/workflows/security.yml` |
| A vulnerable or malicious dependency is added | Dependency review fails on high or critical vulnerabilities in a pull request; Composer Audit fails on known PHP advisories; Renovate proposes updates, including pre-commit hook revisions | `.github/workflows/security.yml`, `renovate.json` |
| Insecure code or workflow patterns | Opengrep fails its check on findings from rules of severity WARNING (the default `--severity WARNING` selects only those rules); zizmor reports workflow findings to code scanning; ShellCheck runs on every `*.sh` file at severity `error` in the Skill Validation check | `.github/workflows/security.yml`, `.github/workflows/lint.yml` |

Which of these checks a pull request must pass before it can be merged is set in the branch protection of `main`, not in this repository. On 2026-09-29 the required checks were Skill Validation, Eval Validation, DCO and CodeQL (repository default setup, languages Actions, Go, JavaScript/TypeScript and Python); the jobs of `security.yml` ran on every pull request but were not required. CodeQL does not analyse shell scripts, which make up the executable part of this skill.

## Secure design principles applied

- **Secure defaults:** `generate-agents.sh` keeps existing files unless `--force` or `--update` is given (`--update` keeps hand-written text only outside the markers of a file that has them).
- **Least privilege:** `SKILL.md` pre-approves a short list of tools; workflows declare `permissions: {}` and grant each job only what its reusable workflow needs (`.github/workflows/*.yml`).
- **Complete input rejection instead of escaping:** `is_safe_command` refuses a command with shell syntax rather than trying to quote it (`skills/agent-rules/scripts/verify-commands.sh`).
- **Minimal attack surface:** the skill is Markdown plus shell scripts with no network listener; network access is limited to `gh api` reads.

## What a user cannot expect

- The scripts are not a sandbox. They treat the target project as trusted input; run them only on a project whose contents you trust.
- `SMOKE_TEST=true` executes the project's own build commands (`make`, `npm run`, `composer`, `go` and others on the list). A documented command runs with the user's permissions. The list restricts the shell syntax and the first word, not what the tool then does: an allowlisted tool runs whatever the project's build files and the command's own arguments tell it to.
- `--force` replaces existing `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` files.
- Text copied from the target project into `AGENTS.md` is not filtered. An agent that reads the generated file follows whatever instructions the project put there; review generated files before committing them.
- The GitHub settings the generator records are those visible to the user's `gh` login at the time of the run.
