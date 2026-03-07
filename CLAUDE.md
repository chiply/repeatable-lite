# repeatable-lite

Emacs Lisp package providing repeatable prefix key commands with which-key integration.

## Build & Test

```sh
eask install-deps --dev   # install dependencies
eask compile              # byte compile
eask test ert test/repeatable-lite-test.el  # run tests
```

## Lint

CI runs all four linters. Run them all locally before pushing:

```sh
eask lint package
eask lint checkdoc
eask lint elisp-lint
eask lint relint
```

## Git Workflow

- Never push directly to `main` — always work on a feature branch
- Branch from `main` and open a PR for all changes
- Use conventional commits (`feat:`, `fix:`, `chore:`) — release-please automates versioning
- Public symbols: `repeatable-lite-` prefix; private symbols: `repeatable-lite--` prefix
- Docstrings on all public functions and variables
- `;;; -*- lexical-binding: t; -*-` on every source file

## Code Review Configuration

Used by the `/review-loop` skill.

### Pre-flight
- Compile: `eask compile`
- Lint: `eask lint package && eask lint checkdoc && eask lint elisp-lint && eask lint relint`
- Tests: `eask test ert test/repeatable-lite-test.el`

### Local Review
- Severity threshold: ignore "nitpick"
- Max iterations: 3

### CI
- Platform: GitHub Actions
- Expected workflows and jobs:
  - `CI / test` — 4 jobs: (ubuntu-latest + windows-latest) x (Emacs 30.2 + snapshot)
  - `CI / lint` — 1 job: ubuntu-latest, Emacs 30.2
- All 5 jobs must pass before proceeding to remote review
- No known flaky tests

### Copilot Review
- Configured via repository ruleset with "Review new pushes" enabled
- Copilot appears as a review, not a CI check
- Poll with: `gh pr view --json reviews --jq '.reviews[] | select(.author.login == "copilot-pull-request-reviewer")'`
- Read inline comments: `gh api repos/{owner}/{repo}/pulls/{pr-number}/comments`
- Max iterations: 3
