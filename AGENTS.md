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

Work on a branch, open a PR whose body links its issue with `Closes #<issue>`, and merge only through the gate (see issue #7):

1. Every list item under the issue's `## Acceptance criteria` ends with exactly one check reference (`task:<target>`, `check:<name>`, `test:[<suite>::]<name>` or `e2e:<name>`). Test names must match exactly, and the test must be defined in test source.
2. The `ci` check is green on the PR's head commit. Its JUnit artifact is the evidence.
3. Adversarial reviewer subagents post PR comments, from the owner account, whose last line is `review-verdict: pass sha=<head-sha> reviewer=<tag>` (or `block`). Each reviewer uses a distinct tag (e.g. `correctness`, `gate-bypass`). A new push invalidates earlier passes.
4. If `scripts/checks/verification-guard` exits 3 (the PR touches the verification stack), two independent passing reviews are required.
5. Merge with `task merge-gate -- <pr> --merge`, run from an up-to-date checkout of `main` (the gate refuses to run unless it is main's copy). It never runs PR code: it uses main's copies of its scripts, reads PR source through `git show`, and judges only the evidence the `ci` workflow recorded for the head commit. Fork PRs are never auto-merged, and linked issues must be labelled `ready-for-agent`.

Releases (`v*` tags), applying infrastructure changes, and anything that needs new secrets are for humans only.

This repository is public: never put account IDs, ARNs, secrets, emails or machine hostnames in issues, PRs, commits or files.
