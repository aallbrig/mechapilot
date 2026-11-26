---
name: agent-loop
description: One Agent Loop pass for this machine - check Production, resume or claim a ready-for-agent issue, deliver it through the merge gate, and stop when no work remains. The Supervisor types /agent-loop; a human can too.
disable-model-invocation: true
---

# Agent Loop

You are this machine's Agent Loop. Work the passes below in order, then start again at pass 1 until pass 5 says stop. You run unattended: decide, act, and record every decision on GitHub, because the Supervisor (`scripts/agent-loop-supervisor`) may `/clear` you at about 45% context and type `/agent-loop` again. GitHub (claims, branches, PRs, comments) is your memory; anything kept only in this conversation is lost.

Setup, once per session:

- `alias="$(scripts/agent-loop-supervisor alias)"`: this machine's alias, `m-` plus 6 hex digits. Your label is `machine:<alias>` and your branches are `agent-loop/<alias>/<n>`.
- You are in the Agent Loop's own worktree. Run `task setup` there if `task doctor` fails.
- The stop file is `"$AGENT_LOOP_STATE_DIR/stop"`. When it exists, claim nothing new.

## 1. Production

1. `git fetch --quiet --tags origin`. When `git tag -l 'v*'` prints nothing, Production has never been released: go to pass 2.
2. Run `scripts/checks/prod-smoke`. When it prints `prod-smoke: ok`, go to pass 2.
3. On failure, find the open incident: `gh issue list --state open --label prod-incident --json number,labels`. When none exists, file one: `gh label create prod-incident --color B60205 2>/dev/null || true`, then `gh issue create --title "Production incident: <what failed>" --label prod-incident --label ready-for-agent --assignee @me` with the smoke output in the body. Add each new smoke result as a comment.
4. Work only on the incident until it closes:
   - **Diagnose** read-only: `curl -sS -I`, `dig`, `openssl s_client`.
   - **Roll back** Production to the previous `v*` release when the workflow exists: `gh workflow run deploy-prod -f tag=<previous v* tag>`.
   - **Fix forward**: deliver the fix as in pass 4, with `Closes #<incident>` only when the fix restores Production.
   - Anything human-only (see **Human-only**) goes on the incident as a `ready-for-human` checklist; then remove `ready-for-agent` from it so the loop stops spending tokens on it.
   - Close the incident only after `prod-smoke` passed 3 times in a row, at least 5 minutes apart, with each run in a comment.

Done when the smoke check passes, or the open incident carries `ready-for-human` and no `ready-for-agent` (then go to pass 5).

## 2. Resume

1. `gh issue list --state open --label "machine:${alias}" --json number,title`.
2. When it lists an issue, take the lowest number. `git fetch origin`, then switch to `agent-loop/<alias>/<n>` (from `origin` if it exists there, else create it from `origin/main`). `gh pr list --head agent-loop/<alias>/<n> --state open` tells you whether a PR exists. Continue pass 4 at the first step that is not yet done.

Done when you hold one issue to deliver (go to pass 4), or this machine claims none (go to pass 3).

## 3. Claim

1. When the stop file exists, go to pass 5.
2. List candidates: `gh issue list --state open --label ready-for-agent --json number,labels,assignees`. A candidate has no assignee, no `machine:*` label, and none of `needs-info`, `ready-for-human`, `wontfix`.
3. Take the lowest-numbered candidate whose open blockers are zero: `gh api "repos/{owner}/{repo}/issues/<n>" --jq .issue_dependencies_summary.blocked_by` prints `0`.
4. Claim it before any other work: `gh label create "machine:${alias}" --color 5319E7 2>/dev/null || true`, then `gh issue edit <n> --add-assignee @me --add-label "machine:${alias}"`.
5. Re-read its labels. When another `machine:*` label is there too, the alias that sorts first keeps it: if that is not yours, `gh issue edit <n> --remove-label "machine:${alias}"` and go back to step 2.

Done when you hold a claimed issue (go to pass 4), or no candidate remains (go to pass 5).

## 4. Deliver

Follow AGENTS.md **Delivery** exactly; it is the contract the merge gate enforces.

1. **Criteria.** `gh issue view <n>`. Every item under `## Acceptance criteria` must end with exactly one check reference. When one cannot be proven as written, edit it (`gh issue edit`) to an equivalent or stricter one, never weaker, and list the edit in the PR body.
2. **Build test-first** on `agent-loop/<alias>/<n>`, branched from `origin/main`. Commit with plain `git commit`; the hooks run the pinned toolchain.
3. **Prove it.** `task ci` is green, and `ACCEPTANCE_RECORD="$(mktemp)" scripts/verify-acceptance <n>` reports every criterion proven.
4. **PR.** `git push -u origin agent-loop/<alias>/<n>`, then `gh pr create` with `Closes #<n>`, a summary, the decisions you made and any criterion edits.
5. **CI.** The REST budget is shared with other agents: check `gh pr checks <pr>` once, when CI should be done, or `gh run watch <id>` at most once per push. When `ci` fails, fix, push and repeat.
6. **Adversarial review.** Dispatch two reviewer subagents in parallel, each with a distinct lowercase tag (for example `correctness` and `gate-bypass`). Give each the issue, the PR number and the diff, never your own assessment, and tell it to try to break the change. Each posts one PR comment whose last line is `review-verdict: pass sha=<40-char head SHA> reviewer=<tag>` or `review-verdict: block sha=<40-char head SHA> reviewer=<tag>`. Fix every block, push, and review again: a push invalidates earlier passes.
7. **Merge.** `git fetch origin && git switch --detach origin/main`, then `task merge-gate -- <pr> --merge`. When it prints a BLOCKED reason, fix that reason and return to the step it names.

Done when the merge gate merged the PR and the issue is closed; go back to pass 1.

When three honest attempts cannot make `ci` pass or the gate cannot be satisfied, un-claim: `gh issue edit <n> --add-label needs-info --remove-label ready-for-agent --remove-label "machine:${alias}"`, comment what blocks it and what you tried, and go to pass 1.

## 5. Stop

Reply `Agent Loop: no work remains.` and end your turn. The Supervisor sees an idle session with no work and ends it; that costs nothing.

## Human-only

These belong to the owner. Record them as a `ready-for-human` checklist on the issue and move on:

- creating `v*` tags or releases, and deploying a new release to Production
- applying infrastructure (`task infra:plan`, `task infra:apply`, `tofu`), DNS changes, branch protection or rulesets
- adding, rotating or reading secrets
- merging any way other than `task merge-gate`, or bypassing a hook or check

This repository is public: issues, PRs, comments and commits carry no account IDs, ARNs, secrets, emails or hostnames. Your machine is only ever its alias.
