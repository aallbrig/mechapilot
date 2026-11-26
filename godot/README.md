# Mecha Fighter: Godot project

Godot 4.7.2 (pinned in `/.godot-version`), GDScript only, Compatibility renderer, single-threaded web export.

## Setup

`task setup` installs the pinned editor and the two web export templates with `scripts/install-godot`. Every download is checked against the SHA512 sums pinned in `/.godot-sha512sums`. The editor runs in self-contained mode from `~/.cache/mechapilot/godot/<version>/`, so it keeps its own editor settings and templates. It never reads or changes a Godot installed elsewhere on your machine. `scripts/godot` runs that pinned editor and never falls back to a `godot` on `PATH`.

| Task | What it does |
|---|---|
| `task godot:editor` | Opens the editor on this project with this repo's ports (below) |
| `task godot:check` | Compiles every script and scene with every GDScript warning as an error |
| `task godot:test` | Runs the GdUnit4 suites in `tests/` headless and writes `build/test-results/godot.xml` |
| `task godot:export:web` | Exports the Web build to `build/web/` |
| `task e2e:web` | Exports the Web build, then boots it in headless Chromium and fails on any console error |
| `task serve` | Serves `build/` at <http://127.0.0.1:8060/> (the game is at `/web/`) |

## Editor ports

Another Godot project on the same machine may use Godot's default ports. This repo uses its own:

| Service | Default | This repo |
|---|---|---|
| GDScript language server (LSP) | 6005 | **6305** |
| Debug adapter (DAP) | 6006 | **6306** |
| Editor debug server | 6007 | **6307** |

The ports are defined once, as `GODOT_LSP_PORT`, `GODOT_DAP_PORT` and `GODOT_DEBUG_PORT` in `/Taskfile.yml`. `task godot:editor` passes them on the command line (`--lsp-port`, `--dap-port`, `--debug-server tcp://127.0.0.1:6307`), so nothing depends on shared editor settings. To check the command without launching the editor, run `task godot:editor -- --dry-run`. `task doctor` warns when one of the ports is already in use.

Always open the editor through `task godot:editor`. If you open it another way, it falls back to the defaults and may connect your IDE to the other project.

### JetBrains Rider

Rider's Godot support connects to the editor's language server. Menu names can differ slightly between Rider versions.

1. Start the editor with `task godot:editor`.
2. In Rider, open **Settings > Languages & Frameworks > Godot Engine**.
3. Set the LSP connection to **Remote**, host `127.0.0.1`, port **6305**.
4. To debug through DAP, use port **6306**.

Other editors (VS Code's godot-tools, Neovim) have the same host and port settings: use 6305 for LSP and 6306 for DAP.

## Layout and rules

Architecture (decided in #9; checked by `scripts/checks/godot-architecture`):

- `types/`: shared value types (pure enums and value classes, `RefCounted`), such as `GameState.Phase`. Every layer may use them, so typed bus payloads never fall back to untyped `Dictionary` values.
- `autoload/events.gd`: the `Events` bus. It holds only typed signals, plus typed `announce_*` methods, which are the only way to emit them.
- `core/`: pure, deterministic rules (`RefCounted`). They never touch the scene tree, the engine or the host (`Engine`, `OS`, `Input`, `Time`, `ClassDB`, runtime `load()`), and they never use global randomness. They receive `Events` and a `RandomNumberGenerator` by injection, so runs can be replayed.
- `game/` uses `core/`. `ui/` and `feedback/` see only `Events` and `types/`.
- `main.gd` is the composition root, the only place that constructs core classes.
- `levels/*.json`: Level data, validated by `/schemas/level.schema.json`.
- `tests/`: GdUnit4 suites (`test_*.gd`). GdUnit4 6.2.3 is vendored in `addons/gdUnit4` and is excluded from our warnings and lint.

Strictness without suppressions: every warning is an error, and `@warning_ignore` is not allowed. In tests, bind GdUnit4's fluent asserts to an `_`-prefixed local, for example `var _ok: GdUnitAssert = assert_int(x).is_equal(1)`.

### How far test results can be trusted

GdUnit4 runs tests in the same Godot process as its runner, counters and report writer. Test code is untrusted, and these layers guard the verdict:

- **One process per suite.** `scripts/godot-test` runs each suite file in its own Godot process with a private report dir, in a process group that is killed when the suite ends. A suite cannot reach another suite's in-memory results.
- **Filesystem containment on Linux (required in CI).** Every Godot step that loads project code (import, compile check, tests and web export) goes through `scripts/godot-run`, which runs it under bubblewrap on a private copy of the project. The whole filesystem is read-only except a private per-suite directory, which holds the report dir, `HOME`, the XDG dirs and therefore `user://`, plus a private copy of `godot/.godot`. The network is off. A test cannot write the repo, the harness, the Godot install or another suite's report. The parent copies the report out after the process exits.
- **Tamper detection everywhere.** `godot-test` runs from a private copy of itself. `scripts/tree-guard` hashes the repo, `node_modules` and the Godot binary and templates before the first suite and again after the last. Any change outside `build/` and `godot/.godot/` fails every case. `task ci` wraps the whole gate in the same check. The Godot binary is also checked against its pinned SHA512 before it runs.
- **Exact, fail-closed reports.** A report counts only if its test names exactly match the suite's `func test_*` names. A suite that crashes, times out or exits non-zero has every case recorded as failed, plus a failing `godot_suite_exit_status` case.
- **Static bans.** `scripts/checks/godot-safe-api` is part of `task lint` and covers all project code.
  - Reflection is banned, whether called or passed as a method reference: `get`, `set`, `call`, `callv`, `get_indexed`, `get_script`, `get_meta`, `get_property_list`, `call_group`, `Callable(...)`, `Expression` and `ClassDB`.
  - Reaching nodes you weren't given is banned: `.root`, `get_parent`, `owner`, `get_viewport`, group lookups, and `..` or absolute node paths.
  - GdUnit4 internals are banned, including `__` identifiers and strings that name them.
  - Process, command-line and environment access is banned, along with the path getters `globalize_path` and `OS.get_user_data_dir`.
  - `DirAccess` is banned entirely.
  - `FileAccess` and `.save*()` may only take one complete string literal with no `..`: `user://...`, or reading `res://...`. `load()` may only take a literal `res://` path.
  - Scripts embedded in scenes and `@tool` scripts are banned.
  - In tests, `get_tree` and parameterized tests are also banned, and every test must call an `assert_*` function.

**What is not proven.** On macOS there is no sandbox. The tree check *detects* writes to the repo, harness or Godot install, but nothing *prevents* them, and `user://` is only made private by pointing `HOME` at a per-suite directory. On every platform, test code that forges its own suite's verdict inside its own process is stopped by the static bans and by review. It is not shown to be impossible. #41 tracks proving that assertions actually run.

`godot/addons/` must match `godot/addons.sha256` exactly (`scripts/checks/godot-addons`).
