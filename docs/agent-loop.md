# Agent Loop: human setup and boundary

The Agent Loop (#20) is an unattended Claude Code session that the Supervisor (`scripts/agent-loop-supervisor`) starts in the tmux `loops` window. This page covers the steps only a human can take, the layers that limit what the session can reach, and the risks that remain.

**No unattended runs until every step below is done.** `task loop:start` runs `scripts/agent-loop-supervisor preflight`, and the Supervisor runs it again whenever it starts. Both refuse to continue while any check fails.

## Human checklist (once per repository, then once per machine)

1. **Least-privilege GitHub token** (per machine).
   - Create a fine-grained personal access token:
     - Resource owner: the repository owner.
     - Repository access: only this repository.
     - Repository permissions: Contents read and write, Pull requests read and write, Issues read and write, Actions read, Metadata read.
     - Everything else off, in particular **Workflows, Environments, Variables, Secrets, Deployments and Administration**, and every account permission.
   - Save it to `~/.config/mechafighter-agent-loop/gh-token` (or set `AGENT_LOOP_TOKEN_FILE`) and `chmod 600` it. The file must be owned by you and live outside the repository.
   - Preflight probes the token:
     - it can read the repository;
     - it **cannot** read branch protection (no Administration);
     - it **cannot** read Actions secrets.

     The repository's `permissions.admin` field is no test: it reports the user's role, not the token's grants.
   - **Workflows, Environments, Variables, Deployments** (and Secrets and Administration beyond the probes) can't be probed without using them. Run `task loop:confirm-token`, check the token's settings page, and type `I confirm`. The confirmation is stored against a fingerprint of the token file, so a new token needs a new confirmation.
   - Workflows matters most. A token that can push `.github/workflows/*` can add a workflow that runs on push with the repository's secrets and its OIDC deploy role. That workflow could release, deploy or leak secrets with no review at all.
2. **Tag ruleset** (per repository). Create an active ruleset that:
   - targets tags, with `refs/tags/v*` included and **nothing excluded**;
   - restricts creation, update (moving a tag) and deletion;
   - has **no role or user bypass**. Only a deploy key or a GitHub App may be on the bypass list.

   The loop's token acts as you, with your repository role, so a bypass for your role or account would let the loop tag a release. To release, push the tag with a deploy key or a release App, or deliberately switch the ruleset off and back on. Contents-write tokens can push tags, and the `production` environment admits any `v*` tag, so this ruleset is what keeps releases human-only.
3. **Production reviewer** (per repository). The `production` environment needs all three of these:
   - required reviewers;
   - **Prevent self-review** on;
   - **Allow administrators to bypass** off (`can_admins_bypass: false`).

   **Decision for a single-owner repository:** with self-review prevented, the person who triggers a deployment can't approve it. With one account, no deployment can then be approved. Preflight will not accept a weaker setting. Choose one of these:
   - (a) add a second human reviewer to `production`;
   - (b) change preflight's production check in a reviewed PR that records why self-review is acceptable here.
4. **Pin the runtime** (per machine, and again whenever you want the loop to run newer loop code). The session's settings, hooks, status line and skill come from one commit you chose, never from a newer `origin/main`:
   - `task loop:start` pins the current `origin/main` the first time.
   - `task loop:pin -- <sha>` moves the pin to another commit on `origin/main`.

   Review what changed in `scripts/agent-loop-*`, `scripts/claude-statusline`, `.claude/agent-loop-settings.json`, `.claude/skills/agent-loop/` and the lockfiles before you move it.

   **Pinning a commit trusts it with your full user access.** The Supervisor runs the pinned commit's hooks and status line, plus its `scripts/site-chrome`, `npm ci --ignore-scripts` (from its `package-lock.json`) and `tofu init` (from its `infra/` lockfiles), all outside the sandbox. So review `scripts/site-chrome`, `package.json`, `package-lock.json` and `infra/**/.terraform.lock.hcl` too.
5. **Sandbox dependencies** (per machine). macOS ships `sandbox-exec`. On Linux, install `bubblewrap` and `socat`. The session runs with `sandbox.failIfUnavailable: true`, so it exits instead of running unsandboxed.
6. **Claude Code login and trust** (per machine).
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
- [ ] **`task ci` runs offline.** npm packages, Chrome for Testing and OpenTofu providers are pre-installed by the Supervisor, so `task ci` passes with only the allowlisted hosts. If it needs another write path or host, widen the settings only through a reviewed PR, then re-pin.

Because the session runs with `--restricted` and the sandbox protects tool-configuration files (`.claude/` settings, skills, hooks, `.git` config and hooks), the session can't edit them. Issues that need those edits come back as `ready-for-human`.

## The boundary, layer by layer

| Layer | What it stops | Where |
| - | - | - |
| Claude Code sandbox on every Bash command (`allowUnsandboxedCommands: false`, `failIfUnavailable: true`) | Writes outside the checkout and the temp directory. Writes to `.claude` settings, skills and hooks, and to `.git/hooks` and `.git/config`, even inside the checkout. The checkout is a separate clone, so the main repository's `.git` is out of reach. Reads of `~/.aws`, `~/.ssh`, `~/.gnupg`, `~/.config/gh`, the token's directory and other credential files. Any network host outside the allowlist, and SSH or other non-proxied traffic. All unix sockets, tmux included (`allowAllUnixSockets: false`, `allowUnixSockets: []`). | `.claude/agent-loop-settings.json` `sandbox` |
| Human-pinned runtime | Hooks and the status line run *outside* the sandbox with full access. They, the settings and the skill come from `git archive <pin>` in `<state>/runtime`: read-only, outside the sandbox's write scope, and only from a commit a human pinned. A PR the session gets merged changes nothing that runs unsandboxed until a human pins it. | `refresh_runtime`, `task loop:pin` |
| Pre-provisioned tools | npm packages (`npm ci --ignore-scripts` from the pinned `package-lock.json`), the pinned Chrome for Testing and OpenTofu providers are installed outside the sandbox from the pinned commit, then copied into the checkout. Every Supervisor write into the checkout goes through one helper. That helper refuses a symbolic link on any path component, stages the copy in the state dir and renames it into place. The record of what was provisioned lives in the state dir. Before provisioning, the previous session's whole process tree is stopped. The session runs npm with `npm_config_offline=true`. | `provision_ci` |
| `--restricted --strict-mcp-config` | No user, project or local settings files: none of the owner's allow rules, no project hooks such as `scripts/claude-post-edit`, and no MCP servers or claude.ai connectors (`disableClaudeAiConnectors` too). | the launcher |
| Least-privilege token, empty `GH_CONFIG_DIR`, git over HTTPS with only that token, `TMUX` unset | No Workflows, Environments, Variables, Secrets, Deployments or Administration permission. The owner's `gh` login and SSH keys are never reachable. | the launcher; preflight |
| Branch protection, the tag ruleset, the production reviewer | No direct push to `main`, no release tag, no production deploy without a second human. | GitHub settings (human) |
| Production checks run by the Supervisor | `prod-smoke`'s TLS check needs a direct connection the sandbox does not allow. The Supervisor runs it and writes `prod.json`, `prod-history.jsonl` and `prod-smoke.log` for the session to read. | `refresh_prod` |
| Permission rules (`dontAsk`) | Defence in depth, not a boundary: `git push` (only `scripts/agent-loop-push`, which pushes `HEAD:refs/heads/agent-loop/<alias>/<n>`), `gh api`, `gh pr merge`, `gh workflow`, `git commit -n` / `--no-verify`, `git config` / `-c`, `--upload-pack` / `--exec`, `find -exec`, `mise`, `npm`, `npx`, `curl`, `tmux`, `task loop:*` other than status and report, `task infra:*`, `tofu`, `aws`. `scripts/checks/agent-loop-skill-commands` (in `task lint`) checks that every command the skill gives is allowed and none is denied. | `.claude/agent-loop-settings.json` `permissions` |
| Merge gate, two reviews for verification changes | The session can edit anything else in its checkout, including `scripts/`, `.githooks/`, `Taskfile.yml` and `.github/`. Those changes reach `main` only through a PR that passes the gate, and the verification stack needs two independent reviews. | `task merge-gate`, `scripts/checks/verification-guard` |

Network allowlist: `github.com`, `api.github.com`, the QA host `aallbrig.github.io`, `mechafighter.com` and `game.mechafighter.com`. Local binding stays allowed, because Lighthouse CI serves the built site on localhost.

## Residual risks

- **Merging outside the gate (#35).** The token's Contents and Pull requests write lets a sandboxed program merge a PR through the REST API once its `ci` is green, because `main` requires no approving review. The skill and the deny rules send merges only through `task merge-gate`. Such a merge still cannot change anything that runs unsandboxed, because of the pin. Closing the risk itself needs a server-side rule, such as a required review from another identity.
- **Self-posted verdicts (#35).** The session and its reviewer subagents share one identity.
- **The token is visible to sandboxed commands,** because `gh` needs it. Its permissions bound what a leaked token can do, and secret scanning revokes it if it is posted.
- **Allowed hosts can carry data out.** What the session can read is repository content, which is public, and the limited token. Credentials stay unreadable.
