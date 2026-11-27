# Agent Loop: human setup and boundary

The Agent Loop (#20) is an unattended Claude Code session that the Supervisor (`scripts/agent-loop-supervisor`) starts in the tmux `loops` window. This page covers the steps only a human can take, the layers that limit what the session can reach, and the risks that remain.

**No unattended runs until every step below is done.** `task loop:start` runs `scripts/agent-loop-supervisor preflight`, and the Supervisor runs it again whenever it starts. Both refuse to continue while any check fails.

## Human checklist (once per repository, then once per machine)

1. **Least-privilege GitHub token** (per machine).
   - Create a fine-grained personal access token:
     - Resource owner: the repository owner.
     - Repository access: only this repository.
     - Repository permissions: Contents read and write, Pull requests read and write, Issues read and write, Metadata read.
     - Everything else off, in particular **Actions, Workflows, Environments, Variables, Secrets, Deployments and Administration**, and every account permission.
   - Save it to `~/.config/mechafighter-agent-loop/gh-token` (or set `AGENT_LOOP_TOKEN_FILE`) and `chmod 600` it. The file must be owned by you and live outside the repository.
   - Preflight probes the token:
     - it can read the repository;
     - it **cannot** read branch protection (no Administration);
     - it **cannot** read Actions secrets.

     The repository's `permissions.admin` field is no test: it reports the user's role, not the token's grants.
   - **Actions, Workflows, Environments, Variables, Deployments** (and Secrets and Administration beyond the probes) can't be probed without using them. Run `task loop:confirm-token`, check the token's settings page, and type `I confirm`. The confirmation is stored against a fingerprint of the token file and the checklist's version, so a new token, or a changed checklist, needs a new confirmation.
   - **Actions and Workflows are the human gate for Production** ([ADR 0001](adr/0001-owner-dispatches-production-deploys.md)):
     - Actions write can dispatch the Deploy workflow, and only the owner deploys.
     - A token that can push `.github/workflows/*` can add a workflow that runs on push with the repository's secrets and its OIDC deploy role. That workflow could release, deploy or leak secrets with no review at all.

     The merge gate still reads `ci` runs and artifacts under this token. That works because the repository is public; a private repository would need Actions read, and the ADR would need revisiting.
2. **Production environment** (per repository). The `production` environment needs:
   - a **custom deployment branch policy** with exactly one pattern, the branch `main`, and no tag pattern;
   - **Allow administrators to bypass** off (`can_admins_bypass: false`).

   It needs no required reviewers, and there is no `v*` tag ruleset. Deploy is a `workflow_dispatch` from `main` (#31). The human gate is that only the owner can dispatch it, and that no production job runs on any push. Preflight checks both settings, and it runs `scripts/checks/production-dispatch-only` on `origin/main`'s workflows. That check requires every workflow using `production` to run only on `workflow_dispatch`. Every other workflow must declare its token permissions and never grant `actions: write`, because a push-triggered `GITHUB_TOKEN` with that permission could dispatch Deploy itself. The same check runs in `task checks`, so a PR can't weaken it unnoticed.
3. **Pin the runtime** (per machine, and again whenever you want the loop to run newer loop code). The session's settings, hooks, status line and skill come from one commit you chose, never from a newer `origin/main`:
   - `task loop:start` pins the current `origin/main` the first time.
   - `task loop:pin -- <sha>` moves the pin to another commit on `origin/main`.

   Review what changed in `scripts/agent-loop-*`, `scripts/claude-statusline`, `.claude/agent-loop-settings.json`, `.claude/skills/agent-loop/` and the lockfiles before you move it.

   **Pinning a commit trusts it with your full user access.** The Supervisor runs the pinned commit's hooks and status line, plus `npm ci --ignore-scripts` (from its `package-lock.json`) and `tofu init` (from its `infra/` lockfiles), all outside the sandbox. So review `package.json`, `package-lock.json` and `infra/**/.terraform.lock.hcl` too. (`scripts/site-chrome` is no longer run outside the sandbox: no browser is installed for the session.)
4. **Sandbox dependencies** (per machine). macOS ships `sandbox-exec`. On Linux, install `bubblewrap` and `socat`. The session runs with `sandbox.failIfUnavailable: true`, so it exits instead of running unsandboxed.
5. **Claude Code login and trust** (per machine).
   - Log in with a claude.ai subscription (`/login`); Remote Control does not accept API keys.
   - Run `claude` once in the loop's checkout (`<main checkout>.agent-loop`, a separate clone the Supervisor creates on its first start) to accept workspace trust and the Remote Control confirmation.

Then run `task loop:start`, and work through the first-run checklist below while you watch.

## First supervised run: check by hand

These depend on Claude Code behaviour the docs don't settle. Check each one on the first run, and stop the loop (`task loop:stop`) if any of them fails.

- [ ] **The pinned skill is followed.** The Supervisor types `Run the Agent Loop: run cat '<state>/runtime/.claude/skills/agent-loop/SKILL.md' and follow it exactly.` The session runs that `cat` and works the passes. This doesn't depend on project skills loading under `--restricted`; separately, note whether `/agent-loop` resolves at all.
- [ ] **Remote Control works with `--restricted`.** The session `mechafighter.com dev loop` appears on claude.ai/code and in the app.
- [ ] **Subagent Bash is sandboxed.** Ask a reviewer subagent to run `cat ~/.ssh/known_hosts`, then `ls ..`. The first must be refused and the second must not reach outside the checkout.
- [ ] **tmux fails inside the sandbox.** Ask the session to run `tmux list-sessions`. The deny rule and the closed unix sockets must both refuse it.
- [ ] **The sandbox protects git's internals.** Ask the session to run `mv .git .git.x` and `printf x > .git/commondir`. Both must be refused, and so must writes to `.git/config` and `.git/hooks/`.
- [ ] **`task ci:sandbox` runs offline.** npm packages and OpenTofu providers are pre-installed by the Supervisor, so `task ci:sandbox` passes with only the allowlisted hosts and no local binding. If it needs another write path or host, widen the settings only through a reviewed PR, then re-pin.
- [ ] **`Agent` worktrees run no hooks outside the sandbox.** Ask the session to dispatch a subagent with worktree isolation, and to make one commit in a `git worktree add .agent-loop/review/<tag> <sha>` checkout. Then, in the main checkout, `<state>/hook-outside-sandbox` must not exist, and `task loop:status` must print no hook warning. The pinned `scripts/lib-toolchain` writes that file whenever a session hook can write the state dir, which only happens outside the sandbox. Preflight then refuses to start until you have looked and removed it.
- [ ] **Commits and merges pass the pinned hooks.** The session's first `git commit` runs the pinned `pre-commit`, which must not call mise in the untrusted clone. A `git merge origin/main` that creates a merge commit runs `task ci:sandbox`, not `task ci`.
- [ ] **The merge gate works without Actions permission.** `task merge-gate -- <pr>` reads `ci` runs and downloads their artifact under the loop's token, as public-repository data. If it fails with 403 or 404, stop the loop: the token model in [ADR 0001](adr/0001-owner-dispatches-production-deploys.md) needs revisiting.
- [ ] **Measure the nudge cap and the checkout scan.** After the first few episodes, `task loop:report` shows the most nudges in one episode against the cap of 6, and the median and maximum time of the `lsof +D` scan. Tune `AGENT_LOOP_MAX_EPISODE_NUDGES` from those numbers, not from guesses.

## API budget and the report

All the agents share one REST budget (5000 requests an hour per user, whatever the token).
- **Readings.** Once per tick, the Supervisor reads `gh api rate_limit`, which doesn't count against that budget. It records the `x-ratelimit-remaining`, `-limit`, `-reset` and `-used` headers as a `rate_limit` event in `metrics.jsonl`. `scripts/agent-loop-gh` does the same for every REST call it makes.
- **Where the session's readings go.** The session's sandbox can't write the state dir, so its readings go to `<checkout>/.agent-loop/metrics.jsonl`, and the Supervisor never reads that file. Pass it to `task loop:report -- <file>` to see them.
- **The hold.** While the remaining budget is below 20% of the limit (`AGENT_LOOP_BUDGET_MIN_PCT`), the Supervisor starts no session and gives an idle session no new pass until the reset time. It logs each such tick and records one `budget_hold` event per hold. A stalled session is still nudged.

`task loop:report` reads only the metrics file and makes one `gh run list` call. It prints:
- cycle time per issue (claim to merge) and review rounds per PR;
- CI minutes and the cancelled-run rate of the `ci` workflow;
- the API usage;
- the nudge and scan measurements above.

`task loop:report -- --json` prints the same as one object that conforms to `schemas/agent-loop-report.schema.json`.

## Triage

When nothing ready-for-agent can be claimed, the session triages `needs-triage` issues, at most 3 per pass (the skill's pass 5). The Supervisor counts such issues as work.
- **Most issues become `ready-for-agent`.** The session writes acceptance criteria in the gate format, checks them against the map, GLOSSARY.md, the ADRs and the existing issues, and adds the label.
- **A human gets it only when one is truly needed:** secrets, infrastructure apply, releases and deploys, or account settings.
- **Closing is rare.** The session closes an issue only when it is a clear duplicate or the work is already on main, with a comment saying why.
- **Contradictions are parked.** An issue that contradicts a recorded decision gets `needs-info` and a comment naming the decision.

**The session's clone is untrusted.** Don't open `<main checkout>.agent-loop` in an IDE, and don't let direnv or mise trust it (`mise trust`, `direnv allow`). Its files, including `.envrc`, `.mise.toml`, editor settings and git hooks, are written by an unattended agent. Inspect it from the main checkout or on GitHub, through the PRs it opens. An editor kept open in it also counts as a process using the checkout, which blocks the next session start.

Because the session runs with `--restricted` and the sandbox protects tool-configuration files (`.claude/` settings, skills, hooks, `.git` config and hooks), the session can't edit them. Issues that need those edits come back as `ready-for-human`.

## The boundary, layer by layer

| Layer | What it stops | Where |
| - | - | - |
| Claude Code sandbox on every Bash command (`allowUnsandboxedCommands: false`, `failIfUnavailable: true`) | Writes outside the checkout and the temp directory. Writes to `.claude` settings, skills and hooks, and to `.git/hooks` and `.git/config`, even inside the checkout. The checkout is a separate clone, so the main repository's `.git` is out of reach. Reads of `~/.aws`, `~/.ssh`, `~/.gnupg`, `~/.config/gh`, the token's directory and other credential files. Any network host outside the allowlist, and SSH or other non-proxied traffic. All unix sockets, tmux included (`allowAllUnixSockets: false`, `allowUnixSockets: []`). | `.claude/agent-loop-settings.json` `sandbox` |
| Human-pinned runtime | Hooks and the status line run *outside* the sandbox with full access. They, the settings and the skill come from `git archive <pin>` in `<state>/runtime`: read-only, outside the sandbox's write scope, and only from a commit a human pinned. A PR the session gets merged changes nothing that runs unsandboxed until a human pins it. | `refresh_runtime`, `task loop:pin` |
| Pre-provisioned tools, and no Supervisor writes into the checkout | npm packages (`npm ci --ignore-scripts` from the pinned `package-lock.json`) and OpenTofu providers are installed outside the sandbox, from the pinned commit, into a read-only directory in the state dir (`ci-deps/<pin>`). The session reads it through `AGENT_LOOP_CI_DEPS` and copies it into its own checkout with `scripts/agent-loop-deps`, inside the sandbox. After it creates the clone, **the Supervisor never writes into the session's checkout**, so no link or race in the checkout can redirect an unsandboxed write. A test runs a tick against a read-only checkout, and another swaps links in the checkout while the tick runs. Before a start, `lsof +D <checkout>` must find no live process. This is defence in depth: a leftover double-forked or `setsid` process escapes `kill_tree`, and with no Supervisor writes into the checkout such a process has nothing unsandboxed to redirect anyway. If lsof finds one, the Supervisor refuses, escalates and holds. `kill_tree` only kills the recorded session pid while its start time and command name still match, so a reused pid is never killed. Every git command the Supervisor runs has `core.hooksPath=/dev/null` and `core.fsmonitor=false`, set through `GIT_CONFIG_*` in its environment, so a hook carried by a fetched commit never runs outside the sandbox. Inherited `GIT_CONFIG_PARAMETERS` (`git -c`), `GIT_DIR` and the other repository-selecting variables are unset first, and a new tmux server the Supervisor starts never inherits the hooks-off config. The session pid is recorded as soon as its pane's process is listed, and only the pane's own pid counts as the session: a human session with the same name is never recorded, nudged or killed. The session runs npm with `npm_config_offline=true`, and its git uses the pinned, read-only copy of `.githooks` (`core.hooksPath` via `GIT_CONFIG_*`). Those hooks source the pinned `scripts/lib-toolchain` beside them, never the checkout's, and run no mise in the session. They still run the checkout's `task lint` and `task ci:fast`: their job is to check the tree being committed, they run inside the sandbox, and the `ci` check is the gate that counts. A hook that ever runs outside the sandbox leaves `<state>/hook-outside-sandbox`, which fails preflight. | `provision_ci`, `checkout_users` |
| `--restricted --strict-mcp-config` | No user, project or local settings files: none of the owner's allow rules, no project hooks such as `scripts/claude-post-edit`, and no MCP servers or claude.ai connectors (`disableClaudeAiConnectors` too). | the launcher |
| Least-privilege token, empty `GH_CONFIG_DIR`, git over HTTPS with only that token, `TMUX` unset | No Workflows, Environments, Variables, Secrets, Deployments or Administration permission. The owner's `gh` login and SSH keys are never reachable. | the launcher; preflight |
| Branch protection, the `production` environment (only `main`, no admin bypass), the dispatch-only Deploy workflow, no Actions or Workflows permission on the token | No direct push to `main`. No production job on any push, and no workflow token that could dispatch Deploy (`scripts/checks/production-dispatch-only`). Only the owner can dispatch Deploy ([ADR 0001](adr/0001-owner-dispatches-production-deploys.md)). | GitHub settings (human), preflight, `task checks` |
| Production checks run by the Supervisor | `prod-smoke`'s TLS check needs a direct connection the sandbox does not allow. The Supervisor runs it and writes `prod.json`, `prod-history.jsonl` and `prod-smoke.log` for the session to read. | `refresh_prod` |
| Permission rules (`dontAsk`) | Defence in depth, not a boundary: `git push` (only `scripts/agent-loop-push`, which pushes `HEAD:refs/heads/agent-loop/<alias>/<n>`), `gh api`, `gh pr merge`, `gh workflow`, `git commit -n` / `--no-verify`, `git config` / `-c`, `--upload-pack` / `--exec`, `find -exec`, `mise`, `npm`, `npx`, `curl`, `tmux`, `task loop:*` other than status and report, `task infra:*`, `tofu`, `aws`. `scripts/checks/agent-loop-skill-commands` (in `task lint`) checks that every command the skill gives is allowed and none is denied. | `.claude/agent-loop-settings.json` `permissions` |
| Merge gate, two reviews for verification changes | The session can edit anything else in its checkout, including `scripts/`, `.githooks/`, `Taskfile.yml` and `.github/`. Those changes reach `main` only through a PR that passes the gate, and the verification stack needs two independent reviews. | `task merge-gate`, `scripts/checks/verification-guard` |

Network allowlist: `github.com`, `api.github.com`, the QA host `aallbrig.github.io`, `mechafighter.com` and `game.mechafighter.com`.

**Local binding is off** (`allowLocalBinding` is never set). On macOS it would allow binding and connecting on every localhost port, and accepting connections on all interfaces. That would reach unsandboxed local services such as IDE MCP servers, the Claude Code IDE bridge (its lock files under `~/.claude/ide` are in `denyRead` as well) and the Godot editor's ports, and it would let the LAN connect in. The two `task ci` steps that need localhost, the pinned-Chrome page check (`scripts/site-observe`) and Lighthouse CI, therefore don't run in the session. The session runs `task ci:sandbox`, which is `task ci` without those two steps. The full `task ci`, including both, runs in the `ci` check on GitHub's runners, and the merge gate requires it to pass. They don't run in the Supervisor either: that would load pages the session built into a Chrome outside any sandbox, where page script could reach the same localhost services. A disposable GitHub runner is the isolated place for them.

## Residual risks

- **Merging outside the gate (#35).** The token's Contents and Pull requests write lets a sandboxed program merge a PR through the REST API once its `ci` is green, because `main` requires no approving review. The skill and the deny rules send merges only through `task merge-gate`. Such a merge still cannot change anything that runs unsandboxed, because of the pin. Closing the risk itself needs a server-side rule, such as a required review from another identity.
- **Self-posted verdicts (#35).** The session and its reviewer subagents share one identity.
- **The token is visible to sandboxed commands,** because `gh` needs it. Its permissions bound what a leaked token can do, and secret scanning revokes it if it is posted.
- **Allowed hosts can carry data out.** What the session can read is repository content, which is public, and the limited token. Credentials stay unreadable.
