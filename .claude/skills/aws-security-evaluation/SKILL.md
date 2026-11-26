---
name: aws-security-evaluation
description: Measured, read-only security evaluation of the AWS account behind mechafighter.com, scored by scripts and published only after redaction.
disable-model-invocation: true
---

# AWS security evaluation

Measure first, then judge. The scripts in `scripts/aws-eval/` collect the posture read-only, score it with fixed jq rules, and redact it; your assessment explains the numbers and never replaces them. Every number you report comes from `score`.

This repository is **public**. Raw output under `.scratch/aws-eval/` holds real account IDs, ARNs and resource names and stays on this machine. Text leaves the machine (an issue, a PR, a comment, a chat message) only after it has passed through `scripts/aws-eval/redact`. When redact fails closed, the text stays local and you fix the text.

You change nothing in AWS. Fixes are **human-applied** through the OpenTofu stack in `infra/` (issue #29); your output is findings and recommended changes to that stack.

## Steps

1. **Confirm the profile is read-only.** Run `scripts/aws-eval/check-profile` with the human's `AWS_PROFILE`. Done when it prints `check-profile: read-only (...)`. When it exits non-zero, stop and ask the human for a profile with only `ReadOnlyAccess`, `SecurityAudit` or `ViewOnlyAccess`.

2. **Collect.** Run `scripts/aws-eval/collect`. It calls only the allowlisted reads in `scripts/aws-eval/aws-ro` and runs `trivy config` on `infra/` when it exists. Done when it prints `collect: wrote .scratch/aws-eval/inventory.json`. A failed call stops collection; report which service failed and why, then stop: a partial inventory scores as falsely clean or falsely broken.

3. **Score.** Run `scripts/aws-eval/score >.scratch/aws-eval/report.json`. Done when the report exists. Its `score`, `counts` and `findings` are the measurement; the rules and weights live in `scripts/aws-eval/rules.jq`.

4. **Assess.** Write `.scratch/aws-eval/assessment.md`: the score and the four severity counts verbatim, then every finding grouped by severity, each with what it exposes, the change to `infra/` that fixes it, and how a re-run would prove the fix. Done when every finding in the report appears in the assessment, critical first.

5. **Redact.** Run `scripts/aws-eval/redact --known .scratch/aws-eval/inventory.json <.scratch/aws-eval/assessment.md >.scratch/aws-eval/assessment.redacted.md` (and the same for `report.json` if you publish it). Done when redact exits 0. Read the redacted file once: placeholders such as `[bucket-1]` and `[account-1]` stand where identifiers were; the public domain and its subdomains stay.

6. **File findings.** First list what is already open: `gh issue list --state open --label needs-triage --search "<finding title> in:title"` per finding, and on a match comment the redacted re-run evidence there (through `redact --check` first) instead of filing again. For each remaining critical or high finding, and one issue for the remaining medium and low ones, write a body from the redacted text and run `scripts/aws-eval/file-issue "<title>" <body-file>`. It re-checks a private copy of title and body, files exactly that copy labelled `needs-triage`, and files nothing when an open issue has the same title; a refusal means an identifier is still present, so edit the body and re-run redact. Titles name the finding class ("S3 bucket is public"), never a resource. Done when every finding is in an open issue; reply to the human with the score, the counts and the issue links.

## Gotchas

- `redact` replaces names it knows only from the inventory: pass `--known` with the inventory of the same run, every time.
- `aws-ro` controls the call, not the machine: the human's `HTTPS_PROXY`, `AWS_CA_BUNDLE` and any `credential_process` in their AWS config still apply. Before step 1, ask the human to confirm those point only at what they trust.
- `aws-ro` refuses anything outside its allowlist. A rule that needs a new read gets a new allowlist entry, a fake-API fixture and a test in `tests/shell/test_aws_eval`, in a PR.
