---
status: accepted
---

# The owner's dispatch is the only human gate for Production

Production has one human gate. Only the owner can dispatch the Deploy workflow, from `main`, and no production job ever runs on its own. Releases are cut automatically on green `main` (#31); deploying one is a `workflow_dispatch`. The `production` environment admits only the `main` branch, through a custom deployment branch policy with exactly that one pattern and no tag pattern, and `can_admins_bypass` is false. It has **no required reviewers**. Agents can't press the button: the Agent Loop's token has no Actions permission (Actions write can dispatch a workflow) and no Workflows permission (it can't add a workflow that runs on push). `scripts/checks/production-dispatch-only` (in `task checks`) and the Supervisor's preflight (#64) enforce the rest. Every workflow that uses the `production` environment runs only on `workflow_dispatch`. Every other workflow calls no reusable workflow outside this repository, because a remote callee's `environment: production` would resolve to this repository's. It also declares its token permissions and never grants `actions: write`, so no push-triggered `GITHUB_TOKEN` can dispatch Deploy either.

## Considered options

- **A required reviewer with Prevent self-review.** With one human account, nobody could ever approve a deployment.
- **The owner as required reviewer, self-review allowed** (briefly chosen on 2026-11-26). Whoever dispatches is already the owner, so the approval is one more click and adds no control.
- **A `v*` tag ruleset with no role bypass, and deploys from `v*` tags.** The owner rejected it. A Contents-write token can push tags, so a tag-triggered deploy would make the ruleset the only gate, and the loop's token can neither read nor toggle rulesets without Administration, so preflight could only trust it, not enforce it.

## Consequences

- Any token or app with Actions write on this repository can deploy Production. Never give one to an agent. `task loop:confirm-token` asks the owner to confirm this explicitly, and a changed checklist invalidates earlier confirmations.
- The loop's token reads Actions data (runs and artifacts for the merge gate) only as public-repository data. If the repository ever goes private, the loop would need Actions read, and this decision must be revisited.
- Preflight fails until the environment's policy is exactly `main`.
