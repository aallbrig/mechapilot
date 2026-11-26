# Godot test framework and GDScript strictness (Godot 4.7.2)

Research for issue #3. Checked on 2026-11-26 against Godot 4.7.2.stable (`ed1daf0bf`),
GdUnit4 v6.2.3, GUT v9.7.1 and gdtoolkit 4.5.0. Claims marked **[smoke]** come from a
throwaway local project (not committed) running a typed event bus, a rule script, and tests
for each framework with every GDScript warning set to Error.

## Answer

- **Test framework: GdUnit4 (v6.2.3).** It enforces the project's warning settings on test
  scripts, and every failure, including a test file that won't compile, gives a non-zero exit
  code. GUT can skip a test file that won't compile and still exit 0.
- **Strictness:** set all 49 `debug/gdscript/warnings/*` settings to `2` (Error). Leave
  `directory_rules` at its default, which excludes `res://addons`. Three small exemptions are
  needed (see below).
- **gdtoolkit 4.5.0 works with Godot 4.7 syntax.** Godot 4.6 and 4.7 added no new GDScript
  syntax, and 4.5 syntax (`@abstract`, variadic `...args`) parses. Its gaps are older
  grammar edge cases and a few formatter bugs. A strict compile gate in `task ci` catches
  any of those that would break code.

## 1. Test framework: GdUnit4

### Evidence

| Requirement | GdUnit4 v6.2.3 | GUT v9.7.1 |
|---|---|---|
| Godot 4.7 support | README matrix: v6.2.x supports 4.5 to 4.7.1, and master supports 4.8.dev7 ([README](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/README.md)). v6.2.3 fixes a "fresh Godot 4.7 editor" bug ([release](https://github.com/MikeSchulze/gdUnit4/releases/tag/v6.2.3)). Ran on 4.7.2 **[smoke]**. | Supported on a separate `godot_4_7` branch; `main` targets 4.6.x ([README](https://github.com/bitwes/Gut/blob/v9.7.1/README.md)). 9.7.0 changed doubles because "Godot 4.7 introduced more restrictive type checking for return values" ([release](https://github.com/bitwes/Gut/releases/tag/v9.7.0)). Ran on 4.7.2 **[smoke]**. |
| Headless CLI exit code | Documented: `0` all pass, `100` failures, `101` warnings ([cmd.md](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/documentation/doc/_advanced_testing/cmd.md#return-codes)). Observed: 0 on pass, 100 on a failing assert, 105 when a test script won't compile, 103 when `--headless` is used without `--ignoreHeadlessMode` **[smoke]**. | `-gexit` sends a failing test to exit 1 ([GutRunner.gd `_handle_quit`](https://github.com/bitwes/Gut/blob/v9.7.1/addons/gut/gui/GutRunner.gd)). Observed: 1 on a failing assert **[smoke]**. **A test script with a warning-as-error was skipped ("Ignoring script … because it does not extend GutTest") and the run exited 0 [smoke].** |
| Works with warnings as errors | Loads test suites with your project settings and lowers only `unsafe_method_access` during the load ([GdUnitTestSuiteScanner.gd `load_with_disabled_warnings`](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/addons/gdUnit4/src/core/GdUnitTestSuiteScanner.gd)). Untyped or unsafe code in tests fails the run **[smoke]**. | Requests `enable = false` while loading test scripts (`warnings_when_loading_test_scripts` in [utils.gd](https://github.com/bitwes/Gut/blob/v9.7.1/addons/gut/utils.gd)). Its docs say "Before each test script is loaded, all warnings are disabled" ([GDScript-Warnings.md](https://github.com/bitwes/Gut/blob/v9.7.1/documentation/docs/GDScript-Warnings.md)). On 4.7.2 the errors still fired, and the file was dropped without failing the run **[smoke]**. |
| Event-driven tests | `monitor_signals` and `assert_signal(obj).is_emitted(signal_ref, args...)` take typed `Signal` references and have a timeout via `wait_until(ms)` ([GdUnitSignalAssert.gd](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/addons/gdUnit4/src/GdUnitSignalAssert.gd), [assert-signal.md](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/documentation/doc/_testing/assert-signal.md)). | `watch_signals` and `assert_signal_emitted_with_parameters` ([test.gd](https://github.com/bitwes/Gut/blob/v9.7.1/addons/gut/test.gd)). Both work **[smoke]**. |
| CI reports | JUnit `results.xml` plus HTML in `res://reports` (`-rd` changes the folder) ([cmd.md](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/documentation/doc/_advanced_testing/cmd.md#the-report)). | JUnit export is available ([Export-Test-Results.md](https://github.com/bitwes/Gut/blob/v9.7.1/documentation/docs/Export-Test-Results.md)). |
| Debugger hang risk | `runtest.sh` passes `--remote-debug tcp://127.0.0.1:0` so that a parse error "prevents Godot from activating its local interactive CLI debugger, which would cause an endless 'debug>' loop" ([runtest.sh](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/addons/gdUnit4/runtest.sh)). | Requires `-d`. A `debug>` prompt appeared on a parse error **[smoke]**. It ended only because stdin was closed. |

The deciding row is the exit code. A strict `task ci` must never pass when a test file fails
to compile, and with GUT on 4.7.2 it can.

### How to run GdUnit4 in `task ci`

`runtest.sh` is a bash script, and the project rule is POSIX `sh`. Call the tool directly,
using the same flags `runtest.sh` passes:

```sh
godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test -c
```

- Treat every non-zero exit as a failure, including 101 (warnings), 103 and 105.
- `--ignoreHeadlessMode` is required with `--headless`. Without it, the tool refuses to
  run and exits 103 **[smoke]**. Input-event scene tests don't work headless (from the
  tool's own banner), which suits rules that live in scene-independent scripts.
- The `--remote-debug … port 0` trick prints two harmless `ERROR:` lines at startup.
- Use `-c` (continue) in CI so one run reports every failure. Without it, GdUnit4 stops at
  the first failure.
- Vendor `addons/gdUnit4/` from tag `v6.2.3` and commit it. Upgrade it deliberately when
  `.godot-version` changes.

### How to write event tests under maximum strictness (verified)

Two strict-mode costs come from GdUnit4's fluent API:

1. Every `assert_*()` returns the assert object, so `return_value_discarded = Error` fails
   each assert line. Put `@warning_ignore_start("return_value_discarded")` right after
   `extends GdUnitTestSuite` in each test file.
2. `assert_signal(...).is_emitted(...)` is declared `@abstract` and non-coroutine, but the
   real implementation awaits. `await` on it therefore trips `redundant_await`, and leaving
   the `await` out drops the check. It needs a per-line `@warning_ignore("redundant_await")`.

Signals emit synchronously, so the simplest pattern that needs no awaits is a typed
recorder. Rules get the bus injected instead of reading the autoload, so each test builds a
fresh bus:

```gdscript
class_name ScoreRulesTest
extends GdUnitTestSuite
@warning_ignore_start("return_value_discarded")

var _bus: EventBus
var _scores: Array[int] = []


func before_test() -> void:
	_bus = EventBus.new()
	_scores.clear()
	var err: Error = _bus.score_changed.connect(_scores.append) as Error
	assert_int(err).is_equal(OK)


func after_test() -> void:
	_bus.free()


func test_enemy_destroyed_emits_score_changed() -> void:
	var _rules: ScoreRules = ScoreRules.new(_bus)
	_bus.enemy_destroyed.emit(100)
	_bus.enemy_destroyed.emit(50)
	assert_array(_scores).contains_exactly([100, 150])
```

Use `assert_signal` (with the ignore line) only when the emission really is asynchronous,
for example after a timer.

## 2. Maximum-strictness `project.godot` settings

Godot has no global "treat warnings as errors" switch. Each warning is set to Ignore (0),
Warn (1) or Error (2) on its own ([Godot docs: GDScript warning system](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html)).
The list below was dumped from `ProjectSettings.get_property_list()` on 4.7.2, so it is
complete for this version: 49 settings with the hint `Ignore,Warn,Error` **[smoke]**.
Several of them default to 0 (`untyped_declaration`, `inferred_declaration`, all four
`unsafe_*`, `return_value_discarded`, `missing_await`), and a few default to 2.

```ini
[debug]

gdscript/warnings/unassigned_variable=2
gdscript/warnings/unassigned_variable_op_assign=2
gdscript/warnings/unused_variable=2
gdscript/warnings/unused_local_constant=2
gdscript/warnings/unused_private_class_variable=2
gdscript/warnings/unused_parameter=2
gdscript/warnings/unused_signal=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/shadowed_variable_base_class=2
gdscript/warnings/shadowed_global_identifier=2
gdscript/warnings/unreachable_code=2
gdscript/warnings/unreachable_pattern=2
gdscript/warnings/standalone_expression=2
gdscript/warnings/standalone_ternary=2
gdscript/warnings/incompatible_ternary=2
gdscript/warnings/untyped_declaration=2
gdscript/warnings/inferred_declaration=2
gdscript/warnings/unsafe_property_access=2
gdscript/warnings/unsafe_method_access=2
gdscript/warnings/unsafe_cast=2
gdscript/warnings/unsafe_call_argument=2
gdscript/warnings/unsafe_void_return=2
gdscript/warnings/return_value_discarded=2
gdscript/warnings/static_called_on_instance=2
gdscript/warnings/missing_tool=2
gdscript/warnings/redundant_static_unload=2
gdscript/warnings/redundant_await=2
gdscript/warnings/missing_await=2
gdscript/warnings/assert_always_true=2
gdscript/warnings/assert_always_false=2
gdscript/warnings/integer_division=2
gdscript/warnings/narrowing_conversion=2
gdscript/warnings/int_as_enum_without_cast=2
gdscript/warnings/int_as_enum_without_match=2
gdscript/warnings/enum_variable_without_default=2
gdscript/warnings/empty_file=2
gdscript/warnings/deprecated_keyword=2
gdscript/warnings/confusable_identifier=2
gdscript/warnings/confusable_local_declaration=2
gdscript/warnings/confusable_local_usage=2
gdscript/warnings/confusable_capture_reassignment=2
gdscript/warnings/confusable_temporary_modification=2
gdscript/warnings/inference_on_variant=2
gdscript/warnings/native_method_override=2
gdscript/warnings/get_node_default_without_onready=2
gdscript/warnings/onready_with_export=2
gdscript/warnings/property_used_as_function=2
gdscript/warnings/constant_used_as_function=2
gdscript/warnings/function_used_as_property=2
```

Leave `debug/gdscript/warnings/enable=true` (the default). Leave
`debug/gdscript/warnings/directory_rules` at its default `{"res://addons": Exclude}`, so
vendored GdUnit4 code is not held to our rules. GdUnit4 itself says it is "not
'inferred_declaration' safe" and that the addon must be excluded
([GdUnitSettings.gd](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/addons/gdUnit4/src/core/GdUnitSettings.gd)).

**What these settings force in our code** (all hit in the smoke test):

- `inferred_declaration` together with `untyped_declaration`: `:=` is rejected, so write
  `var x: int = 1` and give every loop variable a type (`for p: Dictionary in …`).
- `return_value_discarded`: `signal.connect(...)` returns `int`. Write
  `var err: Error = sig.connect(cb) as Error`, then assert on it.
- `unused_signal`: the event bus declares signals that other scripts emit, so every bus
  signal counts as unused. Put `@warning_ignore_start("unused_signal")` above the signal
  block in the bus script (and only there).
- `shadowed_variable_base_class`: a `-s` tool script that extends `SceneTree` can't name a
  local `root`.
- Intentionally unused locals use a `_` prefix (`var _rules`), which `unused_variable`
  accepts. gdlint's default rule rejects that prefix (see section 3).

### Compile every script in CI (verified gap and fix)

The test runner only compiles scripts that tests reach. Godot's own checks do not fail CI
**[smoke]**:

- `godot --headless --check-only --script res://x.gd` exits **0** even when the script has
  warning-as-error parse errors.
- A `-s` script that fails to parse also exits **0**.

So `task ci` needs a small `SceneTree` script. It loads every `.gd` under `res://src` and
`res://test` with `ResourceLoader.CACHE_MODE_IGNORE`, then calls `quit(1)` if any result is
`null` or `not can_instantiate()`. In the smoke test this exited 1 on an untyped script and
0 on clean code.

Keep the checker itself out of the folders it loads. Reloading the running script with
`CACHE_MODE_IGNORE` crashed the VM with "Internal script error! Opcode: 0" and hung
**[smoke]**. Run it with a timeout as well.

## 3. gdtoolkit (gdlint / gdformat) and Godot 4.7

- **Version:** 4.5.0 (2025-10-09) is the latest release, and `master` has had no commits
  since ([releases](https://github.com/Scony/godot-gdscript-toolkit/releases)). The
  version follows the Godot minor it targets. There is no 4.6 or 4.7 release.
- **Is anything missing for 4.7?** No new syntax needs support. The 4.6 and 4.7 release
  pages list no GDScript language, annotation or warning changes
  ([4.6](https://godotengine.org/releases/4.6/), [4.7](https://godotengine.org/releases/4.7/)).
  The 4.5 additions, `@abstract` and variadic functions, were fixed in gdtoolkit before
  4.5.0 ([#398](https://github.com/Scony/godot-gdscript-toolkit/issues/398),
  [#399](https://github.com/Scony/godot-gdscript-toolkit/issues/399)).
- **[smoke] parse test:** `gdparse` over all 574 `.gd` files in GdUnit4 v6.2.3 and GUT
  v9.7.1 failed on only 7. That includes GdUnit4's `@abstract` and `...args` files. All 7
  failures are old grammar edge cases, not 4.7 syntax:
  - a comment between backslash-continued method-chain lines
  - Lua-style dictionaries with string keys (`{"k" = 0}`)
  - a single-quoted string spanning lines

  `@warning_ignore_start`, typed `for` variables, and the smoke project code all lint and
  format cleanly.
- **Known open gaps** (as of this date):
  - [#424](https://github.com/Scony/godot-gdscript-toolkit/issues/424): gdformat can turn a
    nested call that ends in a multiline lambda into code Godot 4.7 rejects ("Unindent
    doesn't match"). Reproduced on 4.5.0 and master against 4.7 stable.
  - [#419](https://github.com/Scony/godot-gdscript-toolkit/issues/419): an `@abstract func`
    line-length mismatch between gdformat and gdlint.
  - [#430](https://github.com/Scony/godot-gdscript-toolkit/issues/430): `@abstract func …;`
    with a trailing semicolon is rejected.
  - [#425](https://github.com/Scony/godot-gdscript-toolkit/issues/425): gdlint misses
    `static func` in the argument-count, max-returns and public-method-count checks.
- **Config conflict:** gdlint's default `function-variable-name` is
  `[a-z][a-z0-9]*(_[a-z0-9]+)*`, which rejects the `_unused` prefix that Godot's
  `unused_variable` rule expects. In `gdlintrc`, set
  `function-variable-name: '_?[a-z][a-z0-9]*(_[a-z0-9]+)*'`. (`class-variable-name`
  already allows `_`.)
- **Mitigations:**
  - Pin `gdtoolkit==4.5.0`.
  - Run gdlint and gdformat on our own code only (`src/`, `test/`, `tools/`), never on
    `addons/`.
  - Order `task ci` as gdformat check, then gdlint, then the strict compile gate, then
    GdUnit4. That way any gdformat output Godot can't parse (#424) fails CI instead of
    shipping.
  - Avoid multiline lambdas passed as arguments to nested calls.
  - Don't end lines with semicolons.

## Sources

- GdUnit4 v6.2.3 (repo moved to `godot-gdunit-labs/gdUnit4`):
  [README](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/README.md),
  [command line and return codes](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/documentation/doc/_advanced_testing/cmd.md),
  [CI](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/documentation/doc/_faq/ci.md),
  [runtest.sh](https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/addons/gdUnit4/runtest.sh),
  [release notes](https://github.com/MikeSchulze/gdUnit4/releases/tag/v6.2.3)
- GUT v9.7.1:
  [README](https://github.com/bitwes/Gut/blob/v9.7.1/README.md),
  [GDScript-Warnings.md](https://github.com/bitwes/Gut/blob/v9.7.1/documentation/docs/GDScript-Warnings.md),
  [Command-Line.md](https://github.com/bitwes/Gut/blob/v9.7.1/documentation/docs/Command-Line.md),
  [9.7.0 release](https://github.com/bitwes/Gut/releases/tag/v9.7.0)
- Godot:
  [GDScript warning system](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html),
  [4.6 release](https://godotengine.org/releases/4.6/),
  [4.7 release](https://godotengine.org/releases/4.7/), and the settings list dumped from
  the 4.7.2 binary
- gdtoolkit:
  [repo and releases](https://github.com/Scony/godot-gdscript-toolkit/releases),
  issues [#398](https://github.com/Scony/godot-gdscript-toolkit/issues/398),
  [#399](https://github.com/Scony/godot-gdscript-toolkit/issues/399),
  [#419](https://github.com/Scony/godot-gdscript-toolkit/issues/419),
  [#424](https://github.com/Scony/godot-gdscript-toolkit/issues/424),
  [#425](https://github.com/Scony/godot-gdscript-toolkit/issues/425),
  [#430](https://github.com/Scony/godot-gdscript-toolkit/issues/430)
