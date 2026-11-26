# Claude Code features the Supervisor needs

Research for [#4](https://github.com/aallbrig/mechapilot/issues/4) (map: [#1](https://github.com/aallbrig/mechapilot/issues/1)).
Checked on 2026-11-26 against Claude Code **2.1.332** (`claude --version`), `claude --help`,
`claude remote-control --help`, `claude agents --help`, and the official docs at code.claude.com.
Claude Code changes quickly. Recheck the flags marked **verify** before building on them.

## Question

Which Claude Code features let a POSIX `sh` Supervisor that spends no inference tokens:

1. start a Remote Control session with a fixed name (`mechafighter.com dev loop`) in a tmux pane,
2. tell whether that session is alive, working or stalled,
3. read its context usage (restart at about 45%),
4. clear or restart it,
5. nudge it to continue?

Also: how to commit project hooks (PostToolUse format/lint) and a permission allowlist that is safe for
unattended runs, and how headless `claude -p` compares with an interactive Remote Control session.

## Short answer

Run an **interactive** session in a tmux pane with `claude --remote-control "<name>"`. The Supervisor
needs no tokens for any of its own checks:

| Need | Mechanism | Token-free? |
| - | - | - |
| Start, named, remote-controllable | `claude -n NAME --remote-control NAME "/agent-loop"` in `tmux new-window` | Yes (the session then spends tokens on its work) |
| Alive / working / waiting | `claude agents --json` → entry with `name == NAME`: `pid`, `status` = `busy`/`waiting`/`idle`, `waitingFor` | Yes |
| Stalled (hung while "busy") | `busy` but no new transcript line / heartbeat for N minutes (`transcript_path` mtime, or a heartbeat file written by hooks) | Yes |
| Context usage | `statusLine` command gets `context_window.used_percentage` on stdin; it writes that to a state file the Supervisor reads | Yes (docs: status line "does not consume API tokens") |
| Clear / restart | `tmux send-keys -t PANE '/clear' Enter` then the skill prompt; or kill the pane and relaunch | Yes (sending keys); the next turn costs tokens |
| Nudge | Project `Stop` hook that returns `{"decision":"block","reason":...}` while ready work exists; fallback `tmux send-keys` | Hook is token-free; the continued turn costs tokens |

Not supported, with workarounds:

- **No CLI command sends a message into a running interactive session.** Use `tmux send-keys`.
  (Background sessions have `claude --resume <id> --bg "<msg>"`, but they are not Remote Control
  sessions; see below.)
- **No CLI command reports context usage of a running session.** Use the status line as a reporter.
  The transcript JSONL holds usage too, but the docs call its format internal and unstable.
- **A committed project file cannot turn on Remote Control** (`remoteControlAtStartup: true` is
  ignored in project settings) **or set `defaultMode` to `auto`/`bypassPermissions`.** Pass flags at
  launch instead.

## 1. Start a named Remote Control session

Three ways to start Remote Control ([Remote Control docs](https://code.claude.com/docs/en/remote-control)):

- **Server mode**: `claude remote-control --name "My Project"` (alias `claude rc`). It waits for
  connections from claude.ai/code or the app. You cannot type into it locally, and it takes no
  initial prompt. `--spawn session` serves exactly one session. In an extended network outage the
  server "gives up after roughly 10 minutes and the `claude remote-control` process exits".
- **Interactive**: `claude --remote-control "My Project"` (or `--rc`). "A full interactive session in
  your terminal that you can also control from claude.ai or the Claude app." In a network outage it
  keeps working locally and reconnects.
- **From a session**: `/remote-control [name]`.

Requirements from the same page:

- A claude.ai subscription login (Pro/Max/Ultra/Team/Enterprise). **API keys are not supported.**
  So the Supervisor's machine must be logged in with `/login`, not `ANTHROPIC_API_KEY`, and must
  not set `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` or `CLAUDE_CODE_DISABLE_FEATURE_FLAGS`.
- Remote Control's one-time confirmation and **workspace trust** must be accepted once by a human.
  `claude remote-control` "can't ask and exits with a `Workspace not trusted` error" when not on a
  terminal. Trust is keyed on the git repository root and covers its worktrees
  ([permissions: workspace trust](https://code.claude.com/docs/en/permissions#project-allow-rules-and-workspace-trust)).
  Add this one-time step to `task setup` docs.
- "Local process must keep running ... start it inside `tmux` or `screen`." That fits the plan.
- Auto-connect via settings: `remoteControlAtStartup: true` works only in user or managed settings;
  a project file's `true` is ignored ([settings](https://code.claude.com/docs/en/settings#exceptions-to-managed-settings-precedence)).
  So the launch flag is the reliable route.

Naming: `-n, --name <name>` sets the session display name, shown in the `/resume` picker and resumable
with `claude --resume <name>` ([sessions](https://code.claude.com/docs/en/sessions#name-your-sessions)).
`--remote-control [name]` names the remote session on claude.ai/code. `/clear` with no argument
"keeps a name you set with `--name` or `/rename`".

**Recommended launch** (run by the Supervisor; **verify** the argument parsing, because
`--remote-control` takes an optional value and a following positional could be read as that value):

```sh
NAME='mechafighter.com dev loop'
tmux new-window -d -t "$TMUX_SESSION" -n agent-loop -c "$WORKTREE" \
  "claude -n '$NAME' --remote-control '$NAME' --permission-mode acceptEdits \
     --settings \"$SUPERVISOR_SETTINGS\" '/agent-loop'"
```

`claude "query"` starts an interactive session with an initial prompt, and user-invoked skills
expand from `/skill-name`. If the optional-value parsing eats the prompt, use
`--remote-control="$NAME"` or start without a prompt and send it with `tmux send-keys` once the
pane is up.

## 2. Alive, working or stalled

**`claude agents --json`** (agent view; works without a terminal) prints "every live session" as
a JSON array ([agent view](https://code.claude.com/docs/en/agent-view)). It includes **interactive**
sessions, not only background ones. Live output on this machine:

```json
{ "pid": 38206, "cwd": "/Users/aallbrig/src/mechapilot", "kind": "interactive",
  "startedAt": 1795701144120, "sessionId": "f711de90-...", "name": "mechafighter.com", "status": "busy" }
```

Fields (docs): `pid` and `status` while the process is alive; `status` is `busy`, `waiting` or `idle`;
`waitingFor` when waiting (`permission prompt`, `input needed`, `sandbox request`, `worker request`,
`dialog open`); `sessionId` and `name` when set. `--cwd <path>` filters by directory.

Supervisor logic (token-free):

```sh
row=$(claude agents --json --cwd "$WORKTREE" | jq -c --arg n "$NAME" '.[] | select(.name == $n)')
```

- No row → not running → start it if `gh` shows `ready-for-agent` work.
- `status == "waiting"` → stuck on a prompt or question. With unattended permissions (section 6)
  this should not happen, so it counts as a stall: nudge, then file an issue naming `waitingFor`.
- `status == "idle"` while ready work exists → the turn ended without the skill exiting. Nudge.
- `status == "busy"` → working, unless the heartbeat is stale (below).

**Stall while busy** (a hung tool or a hung request): Claude Code has no "stalled" status. Use a
heartbeat. Every hook and the status line receive `session_id` and `transcript_path`
([hooks](https://code.claude.com/docs/en/hooks), [statusline](https://code.claude.com/docs/en/statusline)).
Options, cheapest first:

1. The mtime of `transcript_path`. Transcripts live at `~/.claude/projects/<cwd with non-alphanumerics
   replaced by ->/<session-id>.jsonl` ([sessions](https://code.claude.com/docs/en/sessions#where-transcripts-are-stored)).
   Only use the mtime, not the content, because the format is internal.
2. A heartbeat file touched by an async `PostToolUse` hook (`"async": true` runs it without blocking).

Rule of thumb: `busy` and no heartbeat for 15 minutes → stalled. Long `task ci` runs need a larger
window, or the CI target can touch the heartbeat itself.

Other signals: a `Notification` hook with matcher `idle_prompt` fires "about 60 seconds after
Claude finishes responding" if no one has typed; `permission_prompt` fires on a permission prompt.
Either can write a marker file the Supervisor reads.

## 3. Context usage

The status line command gets JSON on stdin with `context_window.used_percentage`,
`remaining_percentage`, `context_window_size`, `current_usage`, plus `session_id`, `session_name`
and `transcript_path` ([statusline](https://code.claude.com/docs/en/statusline)). The docs say it
"runs locally and does not consume API tokens". It runs at session start and resume, on each new
assistant message, after `/compact`, and every `refreshInterval` seconds if set. `used_percentage`
"may be `null` early in the session" and is computed from input tokens only.

**Recommended:** commit a `statusLine` in `.claude/settings.json` that does two things. It prints a
short line, and it writes the state the Supervisor needs:

```sh
#!/bin/sh
# .claude/statusline.sh: also a state reporter for the Supervisor
set -eu
input=$(cat)
dir="${XDG_STATE_HOME:-$HOME/.local/state}/mechapilot"
mkdir -p "$dir"
printf '%s\n' "$input" | jq -c '{session_id, session_name, transcript_path,
  pct: (.context_window.used_percentage // 0), at: now}' > "$dir/context.json.tmp"
mv "$dir/context.json.tmp" "$dir/context.json"
printf '%s\n' "$input" | jq -r '"\(.context_window.used_percentage // 0)% ctx"'
```

The Supervisor reads `pct` and acts when it is `>= 45`. Caveat: the status line runs only in the
terminal UI, which is fine for the tmux design and does not exist under `claude -p`.

Related setting: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` makes Claude Code itself compact earlier; it
"can't raise the threshold" ([env vars](https://code.claude.com/docs/en/env-vars)). Compaction keeps
a summary instead of starting fresh, so it does not replace the 45% clear. It is a backstop if the
Supervisor is down.

## 4. Clear or restart

- **Clear in place** (preferred): wait until `status` is `idle`, then
  `tmux send-keys -t "$PANE" '/clear' Enter`, then send the skill prompt (`/agent-loop`). `/clear`
  starts a new session ID but keeps the `--name`. The Remote Control connection stays on the same
  process. A `SessionStart` hook with matcher `clear` fires ([hooks](https://code.claude.com/docs/en/hooks):
  `source` is `startup`, `resume`, `clear`, `compact` or `fork`), and its stdout is added to the new
  context. Use it to inject "resume this machine's claimed work" instructions.
  `/clear` also works from the phone or browser over Remote Control.
- **Hard restart** (when hung): `tmux kill-pane`, or `kill -INT $pid` from the `claude agents` row,
  then relaunch with the command in section 1. The Agent Loop finds its claimed work from GitHub
  labels, so it needs no conversation history.
- Don't clear mid-turn. If `busy` stays above 45%, wait for `idle` or let auto-compact handle it.

## 5. Nudge

**Primary: a `Stop` hook.** A `Stop` hook runs "when Claude finishes responding". If it prints
`{"decision":"block","reason":"..."}` (or exits 2), Claude does not stop and gets the reason as its
next instruction. Input includes `stop_hook_active` (`true` when it is already continuing because of a
stop hook) and `last_assistant_message` ([hooks](https://code.claude.com/docs/en/hooks)). The hook is a
shell command, so it spends no tokens itself:

```sh
#!/bin/sh
# .claude/hooks/stop-continue.sh
set -eu
input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active')" = true ] && exit 0   # no infinite loop
n=$(gh issue list --label ready-for-agent --state open --json number --jq length)
[ "$n" -gt 0 ] || exit 0          # no work: let the skill exit
printf '{"decision":"block","reason":"%s ready-for-agent issues remain. Continue the Agent Loop."}\n' "$n"
```

Limit it to the Agent Loop session, for example by checking an env var the Supervisor sets at
launch. Otherwise it fires in every session in the repo.

**Fallback:** `tmux send-keys -t "$PANE" 'Continue the Agent Loop.' Enter` when the session is `idle`
or `waiting` with work remaining. After K nudges with no progress, `gh issue create` a stall report
(session name, `status`, `waitingFor`, last heartbeat, context %), and hard-restart.

## 6. Committed hooks and an unattended-safe allowlist

**Where:** `.claude/settings.json` is the shared, committed file for "team permissions, hooks,
plugins" ([settings](https://code.claude.com/docs/en/settings)). `permissions.allow` rules from it
apply only after workspace trust is accepted; `deny` and `ask` rules apply immediately.

**PostToolUse format/lint hook:**

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Edit|Write",
        "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/fmt-lint.sh" } ] }
    ]
  }
}
```

The input JSON on stdin has `tool_input.file_path`, which is always absolute for `Edit`/`Write`. Exit 2
"shows stderr to Claude; the tool already ran", which feeds lint errors back. The script calls the
`task` target that formats and lints one file (gdformat/gdlint, shfmt/shellcheck by extension).
Default command-hook timeout is long (600 s on most events), so keep per-file work fast.

**Permissions.** Rules are evaluated deny, then ask, then allow; the first match wins
([permissions](https://code.claude.com/docs/en/permissions)). For Bash, compound commands must have
every subcommand allowed, and a Bash rule "isn't a security boundary": `Bash(rm *)` doesn't stop
`/bin/rm` or `sh -c 'rm ...'`. For real enforcement use [sandboxing](https://code.claude.com/docs/en/sandboxing).

Recommended shape (narrow allow, explicit deny):

```json
{
  "permissions": {
    "allow": [
      "Bash(task *)", "Bash(git status *)", "Bash(git diff *)", "Bash(git log *)",
      "Bash(git add *)", "Bash(git commit *)", "Bash(git switch *)", "Bash(git worktree *)",
      "Bash(git fetch *)", "Bash(git pull *)", "Bash(git merge *)", "Bash(git push origin agent-loop/*)",
      "Bash(gh issue *)", "Bash(gh pr *)", "Bash(gh run *)", "Bash(godot --headless *)"
    ],
    "deny": [
      "Bash(git push --force *)", "Bash(git push -f *)", "Bash(git reset --hard *)",
      "Bash(rm -rf *)", "Bash(sudo *)", "Bash(curl *)", "Bash(tofu apply *)",
      "Read(./.env)", "Read(./.env.*)", "Read(~/.aws/**)"
    ]
  }
}
```

Avoid `Bash(*)`, interpreters (`Bash(python *)`, `Bash(node *)`, `Bash(sh *)`) and anything that
runs arbitrary code. Those defeat the allowlist.

**Unattended mode:** the permission mode and "don't wait on prompts" settings can't come from the
committed file:

- `permissions.defaultMode` values `auto` and `bypassPermissions` "don't take effect from project or
  local settings". Pass `--permission-mode acceptEdits` (or `auto`) at launch.
- `permissions.denyInsteadOfPrompting: true` makes calls that would prompt get denied instead of
  waiting, "so an unattended session keeps working". It's honored from `~/.claude/settings.json` or
  `--settings`. The Supervisor passes `--settings "$SUPERVISOR_SETTINGS"` with this key so a prompt
  never stalls the loop. A denial then shows up as an error Claude can route around, or report.
- Don't use `bypassPermissions` outside a container or VM (docs warning).

## 7. Headless `claude -p` vs interactive Remote Control

| | `claude -p` | Interactive `--remote-control` in tmux |
| - | - | - |
| Remote Control from phone/web | No. Remote Control is server, interactive or `/remote-control` only; `--bg` rejects `-p` | Yes |
| Context usage | Per-turn `usage` in `--output-format json`/`stream-json` | Status line `context_window.used_percentage` |
| Liveness | Process exit code; `stream-json` events | `claude agents --json` `status` |
| Nudge | Run again with `--resume <session-id>` | Stop hook or `tmux send-keys` |
| Permission prompts | `--permission-prompts none` / `dontAsk`: deny without waiting | `denyInsteadOfPrompting` via `--settings` |
| Ends when work is done | Naturally (process exits) | Skill must `/exit` (works over Remote Control too) |
| Trust dialog | Skipped ("Only use this in directories you trust") | Must be accepted once |
| Session picker | Hidden from `/resume` and `--continue` | Listed, resumable by name |

Sources: [headless](https://code.claude.com/docs/en/headless), [Remote Control](https://code.claude.com/docs/en/remote-control),
[sessions](https://code.claude.com/docs/en/sessions).

**Recommendation:** interactive Remote Control, because the destination wants a session the human can
watch and steer from a phone. `claude -p` is a good fallback for a "no human watching" mode and for CI.
A `claude -p` loop also makes "restart at 45%" easy: start a fresh run per issue.

Background sessions (`claude --bg`, `claude attach/logs/stop/respawn`) survive closing the terminal and
accept `claude --resume <id> --bg "<msg>"`. The docs don't say they can use Remote Control, so they
don't meet the "remote-controllable" requirement. Not recommended for now.

## Open items to verify in a prototype

1. `claude -n NAME --remote-control NAME "/agent-loop"` parses the prompt correctly (section 1).
2. `claude agents --json` from a launchd/systemd context (no TTY, minimal env) sees the tmux session,
   and does not start the background-session supervisor as a side effect.
3. The interactive session's `name` in `claude agents --json` equals the `-n` value after `/clear`.
4. `denyInsteadOfPrompting` via `--settings` holds in an interactive Remote Control session.
