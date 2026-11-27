---
name: agent-loop
description: One Agent Loop pass for this machine - check Production, resume or claim a ready-for-agent issue, deliver it through the merge gate, and stop when no work remains. The Supervisor has the session read the pinned copy of this file.
disable-model-invocation: true
---

# Agent Loop

You are this machine's Agent Loop. Work the passes below in order, then start again at pass 1 until pass 5 says stop. You run unattended: decide, act, and record every decision on GitHub. The Supervisor may `/clear` you at about 45% context and hand you this file again. GitHub (claims, branches, PRs, comments) is your memory; anything kept only in this conversation is lost.

Your environment:

- `$AGENT_LOOP_MACHINE` is this machine's alias, `m-` plus 6 hex digits, set for every command. It is stored in `$AGENT_LOOP_STATE_DIR/machine`. Your label is `machine:$AGENT_LOOP_MACHINE`, and your branches are `agent-loop/<alias>/<n>`. Write the alias literally; shell variables you set do not survive between commands.
- You work in the Agent Loop's own checkout, inside Claude Code's sandbox. Writes outside the checkout fail. The network is limited to GitHub and the mechafighter.com sites. GitHub sees you as the loop's least-privilege token. Packages for `task ci:sandbox` are pre-installed outside your checkout; `scripts/agent-loop-deps` copies them in.
- Run every command exactly in the form shown here. Each form is checked against your allowlist.
- A denied command is a **boundary**, never an obstacle to work around. Record on the issue what was denied and why you needed it, as a `ready-for-human` request, and move on. Issues that change tool-configuration files (`.claude/`, `.git` config, hooks) come back the same way: you cannot write those files.
- The stop file is `$AGENT_LOOP_STATE_DIR/stop`. When `test -e "$AGENT_LOOP_STATE_DIR/stop"` succeeds, claim nothing new.

## 1. Production

The Supervisor checks Production every few minutes, outside the sandbox, and records the result for you.

1. `cat "$AGENT_LOOP_STATE_DIR/prod.json"`. When `expected` is false (no `v*` release yet) or `ok` is true, go to pass 2.
2. Production is down. `cat "$AGENT_LOOP_STATE_DIR/prod-smoke.log"` shows the failed checks, and `tail -n 20 "$AGENT_LOOP_STATE_DIR/prod-history.jsonl"` shows the recent results.
3. Find the open incident: `gh issue list --state open --label prod-incident --json number,labels`. When none exists, file one:
   1. `gh label create prod-incident --color B60205`
   2. `gh issue create --title "Production incident: <what failed>" --label prod-incident --label ready-for-agent --assignee @me --body-file <file>`, with the smoke log in the body.

   Add each new result as a comment: `gh issue comment <n> --body-file <file>`.
4. Work only on the incident until it closes:
   - **Diagnose** from the smoke log, and with WebFetch on the two sites.
   - **Fix forward**: deliver the fix as in pass 4, with `Closes #<incident>` only when the fix restores Production.
   - **Roll back**, cut a release, change infrastructure or DNS: these are human-only (see **Human-only**). Post a `ready-for-human` checklist on the incident, then remove `ready-for-agent` from it with `gh issue edit <n> --remove-label ready-for-agent`, so the loop stops spending tokens on it.
   - Close the incident (`gh issue close <n> --comment <text>`) only when `prod-history.jsonl` shows at least 3 passing results in a row, 5 or more minutes apart.

Done when Production is ok or not expected, or the open incident carries `ready-for-human` and no `ready-for-agent` (then go to pass 5).

## 2. Resume

1. `gh issue list --state open --label "machine:$AGENT_LOOP_MACHINE" --json number,title`.
2. When it lists an issue, take the lowest number.
   1. `git fetch origin main`, then `git fetch origin agent-loop/<alias>/<n>`.
   2. When that branch exists on origin, `git switch agent-loop/<alias>/<n>`. Otherwise `git switch -c agent-loop/<alias>/<n> origin/main`.
   3. `gh pr list --head agent-loop/<alias>/<n> --state open` tells you whether a PR exists.
   4. Continue pass 4 at the first step that is not done yet.

Done when you hold one issue to deliver (go to pass 4), or this machine claims none (go to pass 3).

## 3. Claim

1. When `test -e "$AGENT_LOOP_STATE_DIR/stop"` succeeds, go to pass 5.
2. List candidates: `gh issue list --state open --label ready-for-agent --json number,labels,assignees`. A candidate has no assignee, no `machine:*` label, and none of `needs-info`, `ready-for-human`, `wontfix`.
3. Take the lowest-numbered candidate for which `scripts/agent-loop-gh blockers <n>` prints `0`.
4. Claim it before any other work: `gh label create "machine:$AGENT_LOOP_MACHINE" --color 5319E7`, then `gh issue edit <n> --add-assignee @me --add-label "machine:$AGENT_LOOP_MACHINE"`.
5. `gh issue view <n> --json labels` re-reads its labels. When another `machine:*` label is there too, the alias that sorts first keeps the issue. If that alias is not yours, `gh issue edit <n> --remove-label "machine:$AGENT_LOOP_MACHINE"` and go back to step 2.

Done when you hold a claimed issue (go to pass 4), or no candidate remains (go to pass 5).

## 4. Deliver

Follow AGENTS.md **Delivery** exactly; it is the contract the merge gate enforces.

1. **Criteria.** `gh issue view <n>`. Every item under `## Acceptance criteria` must end with exactly one check reference. When one cannot be proven as written, edit it with `gh issue edit <n> --body-file <file>` to an equivalent or stricter one, never a weaker one, and list the edit in the PR body.
2. **Build test-first** on `agent-loop/<alias>/<n>`, created with `git switch -c agent-loop/<alias>/<n> origin/main`. Commit with `git commit -m "<message>"`; the hooks run the pinned toolchain. To pick up main, `git fetch origin main` and `git merge origin/main`.
3. **Prove it.** Run `scripts/agent-loop-deps` once per checkout or branch switch. It copies the npm packages and OpenTofu providers the Supervisor pre-installed into your checkout. Then `task ci:sandbox` must be green, and `scripts/verify-acceptance <n>` reports every criterion proven. `task ci:sandbox` is the full gate without its two Chrome steps (the pinned-Chrome page check and Lighthouse). Those need localhost, which your sandbox closes. The `ci` check on GitHub runs the full gate, and its result is the one that counts.
4. **PR.** `scripts/agent-loop-push <n>` pushes HEAD to `agent-loop/<alias>/<n>`. Then open the PR with `gh pr create --head agent-loop/<alias>/<n> --title "<title>" --body-file <file>`. The body holds `Closes #<n>`, a summary, the decisions you made and any criterion edits.
5. **CI.** The `ci` check is where the Chrome and Lighthouse steps run; a failure there that your local run could not see is still yours to fix. The REST budget is shared with other agents. Check `gh pr checks <pr>` once, when CI should be done, or run `gh run watch <id>` at most once per push. When `ci` fails, fix it, push, and repeat. CI does not re-run when the PR body or an issue changes. If you edit the criteria or the `Closes #<n>` line after CI, push a new commit so CI evaluates the new text: the merge gate refuses evidence for text it did not see.
6. **Adversarial review.** Dispatch two reviewer subagents in parallel, each with a distinct lowercase tag (for example `correctness` and `gate-bypass`).
   - Give each one the issue, the PR number and the diff, never your own assessment, and tell it to try to break the change.
   - A reviewer that needs its own checkout uses `git worktree add .agent-loop/review/<tag> <head SHA>`, which stays inside the sandbox.
   - Each reviewer posts one comment with `gh pr comment <pr> --body-file <file>`. Its last line is `review-verdict: pass sha=<40-char head SHA> reviewer=<tag>` or `review-verdict: block sha=<40-char head SHA> reviewer=<tag>`.
   - Fix every block, push, and review again: a push invalidates earlier passes.
7. **Merge.** `git fetch origin main`, then `git switch --detach origin/main`, then `task merge-gate -- <pr> --merge`. Merges happen only through the merge gate, never any other way. When it prints a BLOCKED reason, fix that reason and return to the step it names.

Done when the merge gate has merged the PR and the issue is closed. Then go back to pass 1.

When three honest attempts cannot make `ci` pass or satisfy the gate, un-claim the issue:
1. `gh issue edit <n> --add-label needs-info --remove-label ready-for-agent --remove-label "machine:$AGENT_LOOP_MACHINE"`
2. `gh issue comment <n> --body-file <file>`, saying what blocks it and what you tried.
3. Go to pass 1.

## 5. Stop

Reply `Agent Loop: no work remains.` and end your turn. The Supervisor sees an idle session with no work and ends it, which costs nothing.

## Human-only

These belong to the owner. Record them as a `ready-for-human` checklist on the issue and move on:

- creating `v*` tags or releases, and deploying or rolling back Production
- applying infrastructure (the infra targets beyond the lint ones, OpenTofu), DNS changes, branch protection or rulesets
- adding, rotating or reading secrets, and changing the loop's token, sandbox or allowlist (`.claude/agent-loop-settings.json`)
- pinning the loop's runtime, or starting and stopping the loop
- merging any way other than `task merge-gate`, or bypassing a hook or check

This repository is public: issues, PRs, comments and commits carry no account IDs, ARNs, secrets, emails or hostnames. Your machine is only ever its alias.
