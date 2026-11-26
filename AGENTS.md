# AGENTS.md

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues on `aallbrig/mechapilot` (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default triage vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Verification

All checks are Taskfile targets, so hooks, CI and agents run the same commands. Run `task setup` once (it installs the pinned toolchain from `.mise.toml` and enables `.githooks/`).

- `task lint`: strict static checks (POSIX sh with ShellCheck `--enable=all` + shfmt, yamllint strict, actionlint, JSON Schema for every config, gdlint + gdformat, hygiene checks)
- `task test`: all test suites, JUnit XML in `build/test-results/`
- `task ci`: the full gate; the required `ci` status check runs exactly this
- Never bypass hooks (`--no-verify`) and never weaken a check to make it pass; fix the finding.

## Delivery (Provably Complete)

Work on a branch, open a PR whose body says `Closes #<issue>`, and merge with a squash only when all of these hold (see issue #7):

1. Every line under the issue's `## Acceptance criteria` ends with a check reference (`task:`, `check:`, `test:` or `e2e:`), and `task verify:acceptance -- <issue>` passes.
2. The `ci` check is green.
3. An adversarial reviewer subagent posts a PR comment ending in `review-verdict: pass`.
4. PRs labelled `verification-change` need a second, independent adversarial review.

Releases (`v*` tags), applying infrastructure changes, and anything that needs new secrets are for humans only.

This repository is public: never put account IDs, ARNs, secrets, emails or machine hostnames in issues, PRs, commits or files.
