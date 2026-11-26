---
name: agent-loop
description: One Agent Loop pass for this machine - check Production, resume or claim a ready-for-agent issue, deliver it through the merge gate, and stop when no work remains. The Supervisor types /agent-loop; a human can too.
disable-model-invocation: true
---

# Agent Loop

You are this machine's Agent Loop. Work the passes below in order, then start again at pass 1 until pass 5 says stop. You run unattended: decide, act, and record every decision on GitHub. The Supervisor (`scripts/agent-loop-supervisor`) may `/clear` you at about 45% context and type `/agent-loop` again. GitHub (claims, branches, PRs, comments) is your memory, and anything kept only in this conversation is lost.

Your environment:

- `$AGENT_LOOP_MACHINE` is this machine's alias, `m-` plus 6 hex digits, set for every command. It is stored in `$AGENT_LOOP_STATE_DIR/machine`. Your label is `machine:$AGENT_LOOP_MACHINE` and your branches are `agent-loop/<alias>/<n>`. Write the alias literally into commands; shell variables you set do not survive between commands.
- You work in the Agent Loop's own worktree, inside Claude Code's sandbox. Writes outside the worktree fail, network access is limited to GitHub and the mechafighter.com sites, and GitHub sees you as the loop's least-privilege token.
- A denied command is a **boundary**, never an obstacle to work around. Record what was denied and why you needed it on the issue, as a `ready-for-human` request, and move on.
- The stop file is `"$AGENT_LOOP_STATE_DIR/stop"`. When `test -e "$AGENT_LOOP_STATE_DIR/stop"` succeeds, claim nothing new.

## 1. Production

1. `git fetch origin --tags`. When `git tag -l 'v*'` prints nothing, Production has never been released: go to pass 2.
2. Run `scripts/checks/prod-smoke`. When it prints `prod-smoke: ok`, go to pass 2.
3. On failure, find the open incident: `gh issue list --state open --label prod-incident --json number,labels`. When none exists, file one: `gh label create prod-incident --color B60205`, then `gh issue create --title "Production incident: <what failed>" --label prod-incident --label ready-for-agent --assignee @me`, with the smoke output in the body. Add each new smoke result as a comment.
4. Work only on the incident until it closes:
   - **Diagnose** with `scripts/checks/prod-smoke` and WebFetch on the two sites.
   - **Fix forward**: deliver the fix as in pass 4, with `Closes #<incident>` only when the fix restores Production.
   - **Roll back**, cut a release, change infrastructure or DNS: these are human-only (see **Human-only**). Post a `ready-for-human` checklist on the incident, then remove `ready-for-agent` from it so the loop stops spending tokens on it.
   - Close the incident only after `prod-smoke` has passed 3 times in a row, at least 5 minutes apart, with each run posted as a comment.

Done when the smoke check passes, or the open incident carries `ready-for-human` and no `ready-for-agent` (then go to pass 5).

## 2. Resume

1. `gh issue list --state open --label "machine:$AGENT_LOOP_MACHINE" --json number,title`.
2. When it lists an issue, take the lowest number. Run `git fetch origin`. Then switch to `agent-loop/<alias>/<n>`, from `origin` if it exists there, else created from `origin/main`. `gh pr list --head agent-loop/<alias>/<n> --state open` tells you whether a PR exists. Continue pass 4 at the first step that is not done yet.

Done when you hold one issue to deliver (go to pass 4), or this machine claims none (go to pass 3).

## 3. Claim

1. When the stop file exists, go to pass 5.
2. List candidates: `gh issue list --state open --label ready-for-agent --json number,labels,assignees`. A candidate has no assignee, no `machine:*` label, and none of `needs-info`, `ready-for-human`, `wontfix`.
3. Take the lowest-numbered candidate for which `scripts/agent-loop-gh blockers <n>` prints `0`.
4. Claim it before any other work: `gh label create "machine:$AGENT_LOOP_MACHINE" --color 5319E7`, then `gh issue edit <n> --add-assignee @me --add-label "machine:$AGENT_LOOP_MACHINE"`.
5. Re-read its labels. When another `machine:*` label is there too, the alias that sorts first keeps the issue. If that is not yours, `gh issue edit <n> --remove-label "machine:$AGENT_LOOP_MACHINE"` and go back to step 2.

Done when you hold a claimed issue (go to pass 4), or no candidate remains (go to pass 5).

## 4. Deliver

Follow AGENTS.md **Delivery** exactly; it is the contract the merge gate enforces.

1. **Criteria.** `gh issue view <n>`. Every item under `## Acceptance criteria` must end with exactly one check reference. When one cannot be proven as written, edit it (`gh issue edit`) to an equivalent or stricter one, never a weaker one, and list the edit in the PR body.
2. **Build test-first** on `agent-loop/<alias>/<n>`, branched from `origin/main`. Commit with plain `git commit`: the hooks run the pinned toolchain. To pick up main, `git fetch origin main` and `git merge origin/main`.
3. **Prove it.** `task ci` is green, and `ACCEPTANCE_RECORD="$(mktemp)" scripts/verify-acceptance <n>` reports every criterion proven.
4. **PR.** `scripts/agent-loop-push <n>` pushes HEAD to `agent-loop/<alias>/<n>`. Then `gh pr create --head agent-loop/<alias>/<n>`, with `Closes #<n>`, a summary, the decisions you made and any criterion edits in the body.
5. **CI.** The REST budget is shared with other agents. Check `gh pr checks <pr>` once, when CI should be done, or `gh run watch <id>` at most once per push. When `ci` fails, fix it, push, and repeat.
6. **Adversarial review.** Dispatch two reviewer subagents in parallel, each with a distinct lowercase tag (for example `correctness` and `gate-bypass`). Give each one the issue, the PR number and the diff, never your own assessment, and tell it to try to break the change. A reviewer that needs its own checkout uses `git worktree add .agent-loop/review/<tag> <head SHA>`, which stays inside the sandbox. Each reviewer posts one PR comment whose last line is `review-verdict: pass sha=<40-char head SHA> reviewer=<tag>` or `review-verdict: block sha=<40-char head SHA> reviewer=<tag>`. Fix every block, push, and review again: a push invalidates earlier passes.
7. **Merge.** `git fetch origin main`, then `git switch --detach origin/main`, then `task merge-gate -- <pr> --merge`. Merges happen only through `task merge-gate`. When it prints a BLOCKED reason, fix that reason and return to the step it names.

Done when the merge gate has merged the PR and the issue is closed. Then go back to pass 1.

When three honest attempts cannot make `ci` pass or satisfy the gate, un-claim the issue: `gh issue edit <n> --add-label needs-info --remove-label ready-for-agent --remove-label "machine:$AGENT_LOOP_MACHINE"`. Comment with what blocks it and what you tried, then go to pass 1.

## 5. Stop

Reply `Agent Loop: no work remains.` and end your turn. The Supervisor sees an idle session with no work and ends it, which costs nothing.

## Human-only

These belong to the owner. Record them as a `ready-for-human` checklist on the issue and move on:

- creating `v*` tags or releases, deploying or rolling back Production
- applying infrastructure (the `task infra:*` targets beyond `task lint`, `tofu`), DNS changes, branch protection or rulesets
- adding, rotating or reading secrets, and changing the loop's token, sandbox or allowlist (`.claude/agent-loop-settings.json`)
- merging any way other than `task merge-gate`, or bypassing a hook or check

This repository is public: issues, PRs, comments and commits carry no account IDs, ARNs, secrets, emails or hostnames. Your machine is only ever its alias.
