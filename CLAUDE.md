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

## Review Loop

When the user says "run the review loop", "review loop", or "run review-loop", execute
ALL steps below sequentially. Do NOT skip any step. Do NOT prompt the user between steps.
Do NOT ask for confirmation. Run everything autonomously end-to-end.

**OVERRIDE**: When the review loop is active, you ARE authorized to commit, push, and
create PRs without asking. The user has explicitly opted into autonomous execution.
Stage, commit, and push changes automatically. Do NOT stop to show diffs or ask the
user to review uncommitted changes. This overrides any default behavior around requiring
user confirmation for git operations.

The ONLY reasons to stop and ask the user are:
1. 3 consecutive failures on the same CI issue.
2. A required tool is not installed (see Step 1).

### STEP 1: Tool check

```
which coderabbit || echo "MISSING: coderabbit"
which gh || echo "MISSING: gh"
```

If either is missing: STOP and tell the user to install it. Do NOT continue.

### STEP 2: Branch and commit

Do this FIRST, before any checks or reviews.

If on the default branch (main/master), create a feature branch:
```
git checkout -b <descriptive-branch-name>
```

Stage and commit all current changes immediately:
```
git add -A
git commit -m "wip: initial changes for review"
```

This clears the working tree so all subsequent steps operate on a clean branch.

### STEP 3: Pre-flight checks

1. Compile: `eask compile`
2. Lint: `eask lint package && eask lint checkdoc && eask lint elisp-lint && eask lint relint`
3. Tests: `eask test ert test/repeatable-lite-test.el`

If anything fails: fix it, re-run the failing check, repeat until all pass.
After fixing, commit the fixes: `git add -A && git commit -m "fix: pre-flight fixes"`

### STEP 4: Local CodeRabbit review

**This is a LOCAL command. Run it on this machine. Do NOT skip this step.**
CodeRabbit CLI is a local tool, completely separate from any GitHub integration.
You MUST execute this command locally before any push.

#### 4a: Run the review

```
coderabbit review --prompt-only --type uncommitted
```

Run this command NOW in the project directory. Read its output.

#### 4b: Act on feedback

For each suggestion in the output:
- Skip suggestions with severity "nitpick" or "style-only".
- Implement all other suggestions.

#### 4c: Re-validate

After making changes:
1. Re-run Step 3 pre-flight checks.
2. Commit fixes: `git add -A && git commit -m "fix: address coderabbit feedback"`
3. Run `coderabbit review --prompt-only --type uncommitted` again.
4. If new actionable suggestions appear, go back to 4b.

#### 4d: Exit

Stop when: no actionable suggestions remain OR 3 iterations completed.
Log any unresolved suggestions. Proceed to Step 5.

### STEP 5: Push and open PR

```
git push -u origin HEAD
```

Check for existing PR: `gh pr view --json url 2>/dev/null`
If no PR exists, create one: `gh pr create --fill`

### STEP 6: Wait for ALL CI checks and Copilot review to pass

A push triggers CI workflows and a Copilot code review (configured via repository
ruleset with "Review new pushes" enabled). ALL must reach a terminal state.

Expected checks for this project:
- `CI / test` — 4 jobs: (ubuntu-latest + windows-latest) x (Emacs 30.2 + snapshot)
- `CI / lint` — 1 job: ubuntu-latest, Emacs 30.2
- `Copilot` — code review (appears as a review, not a check)

Poll CI with: `gh pr checks`
Poll Copilot with: `gh pr view --json reviews --jq '.reviews[] | select(.author.login == "copilot-pull-request-reviewer")'`
Read Copilot inline comments: `gh api repos/{owner}/{repo}/pulls/{pr-number}/comments`

Repeat until every CI check passes AND the Copilot review has appeared.

If a CI check fails:
1. Read logs: `gh run view <run-id> --log-failed`
2. If real failure: fix code, re-run Step 3, `git add -A && git commit`, `git push`, poll again.
3. If flaky/infra: `gh run rerun <run-id> --failed`
4. If same check fails 3 times: STOP and ask user. This is the only valid reason to prompt.

### STEP 7: Act on Copilot feedback

For each Copilot inline comment:
- Skip "nitpick" severity.
- Implement all other suggestions.

If no actionable comments, proceed to Final Summary.

### STEP 8: Re-validate and re-push

1. Re-run Step 3 pre-flight checks.
2. Re-run Step 4 local CodeRabbit review (full iteration loop).
3. `git add -A && git commit -m "fix: address copilot feedback"` then `git push`.
4. Go back to Step 6 (wait for CI + Copilot).

Stop when: CI passes AND no new actionable Copilot comments, OR 3 iterations completed.

### FINAL SUMMARY

Output this when done:

```
## Review Complete

### Local Review (CodeRabbit)
- Iterations: X
- Suggestions addressed: Y
- Suggestions skipped: Z

### Remote Review (CI + Copilot)
- CI runs: X
- Copilot review rounds: Y
- Suggestions addressed: Z
- Suggestions skipped: W

### Changes Made
- [list of changes with brief rationale]

### Unresolved Items
- [any remaining suggestions that were skipped or deferred]
```
