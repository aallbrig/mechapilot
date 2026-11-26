# Agent Loop: human setup and boundary

The Agent Loop (#20) is an unattended Claude Code session that the Supervisor (`scripts/agent-loop-supervisor`) starts in the tmux `loops` window. This page lists the steps only a human can do, and the layers that limit what the session can reach.

**No unattended runs until every step below is done.** `task loop:start` runs `scripts/agent-loop-supervisor preflight`, and so does the Supervisor itself when it starts. Either one refuses to continue while any check fails.

## Human checklist (once per repository, then once per machine)

1. **Least-privilege GitHub token** (per machine).
   - Create a fine-grained personal access token:
     - Resource owner: the repository owner.
     - Repository access: only this repository.
     - Repository permissions: Contents read and write, Pull requests read and write, Issues read and write, Actions read, Metadata read.
     - Leave everything else off, in particular Administration, Workflows, Secrets, Variables, Environments and every account permission.
   - A GitHub App installation with the same permissions also works, but its tokens expire hourly, and refreshing them is not automated yet.
   - Save the token to `~/.config/mechafighter-agent-loop/gh-token` (or set `AGENT_LOOP_TOKEN_FILE`), then `chmod 600` it. The file must be owned by you and sit outside the repository.
   - Preflight checks the following:
     - The file exists, belongs to you and has mode 0600.
     - The token can read the repository.
     - The token **cannot** read branch protection, which shows it has no Administration permission.
     - The token **cannot** read Actions secrets.

     The repository's `permissions.admin` field is not a usable test: it reports the user's role, not the token's grants.
2. **Tag ruleset** (per repository). Add an active ruleset targeting tags that includes `refs/tags/v*` and restricts creation, with only the owner allowed to bypass. Contents-write tokens can push tags, and the `production` environment admits any `v*` tag, so this ruleset is what keeps releases human-only.
3. **Production reviewer** (per repository). The `production` environment requires a reviewer, so a deployment never starts without a human.
4. **Sandbox dependencies** (per machine). macOS has `sandbox-exec` built in. On Linux, install `bubblewrap` and `socat`. The session runs with `sandbox.failIfUnavailable: true`, so it exits instead of running unsandboxed.
5. **Claude Code login and trust** (per machine).
   - Log in with a claude.ai subscription (`/login`). Remote Control does not accept API keys.
   - Run `claude` once in the loop's checkout (`<main checkout>.agent-loop`, a separate clone the Supervisor creates on its first start) to accept workspace trust and the Remote Control confirmation.

Then run `task loop:start`.

## The boundary, layer by layer

| Layer | What it stops | Where |
| - | - | - |
| Claude Code sandbox, applied to every Bash command, with `allowUnsandboxedCommands: false` and `failIfUnavailable: true` | Writes anywhere outside the worktree and the temp directory. Writes to `.claude` settings, skills and hooks, and to `.git/hooks` and `.git/config`, even inside the worktree. The worktree is a separate clone, so its `.git` is inside the sandbox and the main repository's `.git` is not. Reads of `~/.aws`, `~/.ssh`, `~/.gnupg`, `~/.config/gh`, the token's directory and other credential files. Network access to any host outside the allowlist, plus SSH and other non-proxied traffic. | `.claude/agent-loop-settings.json` `sandbox` |
| Read-only runtime copy | Hooks and the status line run *outside* the sandbox with full access. They come from `git archive origin/main` in `<state>/runtime`, which is read-only and outside the sandbox's write scope. Editing the worktree cannot change them, or the settings. | `refresh_runtime` in the Supervisor |
| `--restricted --strict-mcp-config` | No user, project or local settings files are loaded: none of the owner's allow rules, no project hooks such as `scripts/claude-post-edit`, and no MCP servers or claude.ai connectors (also `disableClaudeAiConnectors`). | the launcher |
| Least-privilege token, empty `GH_CONFIG_DIR`, git over HTTPS with only that token | No Administration, Workflows, Secrets, Environments or Rulesets permission. The owner's `gh` login and SSH keys are never reachable. | the launcher; preflight |
| Branch protection, the tag ruleset, the production reviewer | No direct push to `main`, no release tag, no production deploy without a human. | GitHub settings (human) |
| Permission rules (`dontAsk`) | Defence in depth, not a boundary: `git push` (only `scripts/agent-loop-push`, which pushes `HEAD:refs/heads/agent-loop/<alias>/<n>`), `gh api`, `gh pr merge`, `gh workflow`, `git commit -n` / `--no-verify`, `git config` / `-c`, `--upload-pack` / `--exec`, `find -exec`, `mise`, `curl`, `task loop:start` / `loop:stop`, `task infra:*`, `tofu`, `aws`. | `.claude/agent-loop-settings.json` `permissions` |
| Merge gate, two reviews for verification changes | The session can edit anything in its worktree, including `scripts/`, `.githooks/`, `Taskfile.yml` and `.github/`. Those changes reach `main` only through a PR that passes the gate. A PR that touches the verification stack needs two independent reviews. | `task merge-gate`, `scripts/checks/verification-guard` |

Network allowlist: `github.com`, `api.github.com`, the QA host `aallbrig.github.io`, `mechafighter.com`, `game.mechafighter.com`, and the three download hosts `task ci` needs (`registry.npmjs.org`, `storage.googleapis.com`, `googlechromelabs.github.io`).

## Residual risks

- **Merging outside the gate.** With Contents and Pull requests write, the token can merge a PR through the REST API once its `ci` check is green, because main requires no approving review. The skill sends every merge through `task merge-gate`, and `gh api` and `gh pr merge` are denied. But a sandboxed program that speaks HTTPS to `api.github.com` could still do it. Closing this needs a server-side rule (tracked with #35, verdicts and identity), such as a required review from a different account.
- **Self-posted verdicts (#35).** The session and its reviewer subagents share one identity, so the session could post a `review-verdict: pass` itself.
- **The token is visible to sandboxed commands,** because `gh` needs it. Its permissions bound what a leaked token can do. GitHub secret scanning revokes tokens that get posted publicly.
- **Allowed hosts can carry data out.** Anything the session can read could be sent to an allowed host. The sandbox keeps credentials unreadable, so what remains is repository content (public anyway) and the limited token.
- **Not yet observed on a real run:**
  - that `--restricted` keeps project skills (`/agent-loop`);
  - which writes `task ci` needs inside the sandbox (caches are redirected into `<worktree>/.agent-loop/cache`);
  - whether subagents' Bash runs in the same sandbox (the docs don't say).

  Check these on the first supervised run and widen only through a reviewed PR.
