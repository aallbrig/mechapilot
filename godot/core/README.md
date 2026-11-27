# core/: the rules of Mecha Fighter

Pure, deterministic rules for the 1.0 spec (#73). Every class is `RefCounted`, receives the `Events` bus (`EventBus`) by injection, and never touches the scene tree, the engine or the host. Randomness comes only from an injected `RandomNumberGenerator`. `main.gd` builds everything; `game/`, `ui/` and `feedback/` talk to the rules only through `Events`.

**Rules decide, nodes report, and feedback reacts.** `game/` nodes report facts (marked *reported* below). The rules announce decisions. Screens announce intents (marked *intent*) and never call `core/`.

Fixed tuning lives in `run_rules.gd` (`RunRules`); per-Level tuning lives in `levels/level_N.json`, validated by `schemas/level.schema.json` in CI and by `LevelDefinition.parse()` at runtime.

## Classes

| Class | Job | Public API |
|---|---|---|
| `GameStateMachine` | The Game State: legal transitions only; Pause only during play; Paused resumes only to the phase it paused, or quits to Title. | `boot()`, `state()`, `paused_from()`, `can_transition(to)`, `request(to) -> bool` |
| `LevelProgression` | Runs the Run: Level Intro (2.5 s), Skirmish, Boss Gauge to threshold, Boss Warning (3 s), Boss Fight, Level Clear, next Level, Victory after Level 6, Game Over after the last life. Losing a life keeps the gauge and the boss's health. | `tick(delta)`, `current_level()`, `level_number()`, `gauge()`, `is_run_active()`, `is_game_over_pending()`; developer commands (#116): `fill_boss_gauge() -> bool`, `skip_level() -> bool` |
| `RunLedger` | The Run's accounts: score table, combo (x1 to x8, 1.2 s, reset on damage), Armor 100 and damage by source, invulnerability (0.6 s after a hit, 2 s after a respawn), lives (3), the one-time bonus life at 100,000, boss score (5,000 x Level), Level Clear bonus (Armor x 50, plus 10,000 with no death), kills, accuracy and Run time (timed phases only). | `start_run()`, `start_level(n)`, `respawn()`, `award_boss()`, `close_level() -> LevelTally`, `summary(victory) -> RunSummary`, `tick(delta)`, `score()`, `lives()`, `armor()`, `multiplier()`, `is_down()`, `is_invulnerable()`, `run_time()`; developer commands (#116): `toggle_dev_invulnerability() -> bool`, `mark_dev_assisted()`, `is_dev_assisted()`, `award_points(points)`, `restore_armor() -> bool`, `award_life()` |
| `BossHealth` | The current boss's health and phases; announces each phase crossed and one defeat. | `arm(boss)`, `disarm()`, `is_armed()`, `health()`, `phase()` |
| `SpawnDirector` | Seeded spawn decisions: the Skirmish trickle and waves (limit, buffer and aggression ramp with kills; roster kinds unlock by kill count), nothing during the Boss Warning, escorts in the Boss Fight, a pause while the player is destroyed, and Repair Kit drops (6% per shot kill, always from a boss). | `tick(delta)`, `live_count()`, `limit()`, `buffer()`, `aggression()`, `kills()` |
| `LevelDefinition` | One parsed Level file, including `sky_theme` (one of `SKY_THEMES`: dawn, storm, sunset, night, stratosphere, orbit), which game/ uses to pick the environment; inner `RosterEntry`, `PlayerTuning`, `CameraTuning`, `SpawnTuning`. | `static parse(data, errors) -> LevelDefinition` (null on any error), `static parse_roster(...)` |
| `BossDefinition` | A Level's boss: id, name, description, threshold, health, phases (inner `Phase`, `Attack`) and escorts. | `static parse(...)`, `phase_for(health) -> int` |
| `Scoreboard` | Top 10 Runs, best first (ties keep the earlier entry). A dev-assisted Run never places. | `restore()`, `entries()`, `rank_for(score)`, `submit(entry) -> rank`, `static normalize_initials(raw)` |
| `DevCommands` | The Developer console's commands (#116), only while Developer mode is on, through the rule APIs below: `RunLedger.award_points/award_life/restore_armor/toggle_dev_invulnerability`, `LevelProgression.fill_boss_gauge/skip_level`, and `dev.enemies_purge_ordered` for game/. A command that changes a Run marks it dev-assisted. | `run_command(command) -> bool`, `is_enabled()` |
| `Settings` | The player's `GameSettings`, clamped, with per-field fallback to defaults. | `restore()`, `current()`, `apply(settings)`, `reset()` |
| `IntelCodex` | Intel unlocks on first encounter in play (not in the Title's attract mode), and what the codex lists. | `static catalog(levels)`, `static entries_for(levels)`, `restore()`, `is_unlocked(id)`, `unlocked()`, `unlock(id) -> bool` |
| `TutorialProgress` | Which first-flight prompts are done, and whether the first Run was flown. No events: `TutorialCoach` decides when prompts show. | `restore()`, `is_done(prompt)`, `mark_done(prompt) -> bool`, `is_complete()`, `is_first_run_done()`, `mark_first_run_done()`, `reset()` |
| `TutorialCoach` | The first-flight tutorial (#75): in Level 1 of the first Run, each prompt shows once and leaves when its condition is met (move; 3 shots; a miss, then a hit; 25% Boss Gauge; a Repair Kit drop, then a pickup; the Boss Warning), one at a time; the read-only ones leave after `HOLD_TIME` of play. Hints off hides them all. | `tick(delta)`, `current()`, `is_running()` |
| `EnemyRoster` | Each enemy kind's name, Intel description and hit points (#73 fixes Heavy 4 and Drone 1; the enemy nodes take theirs from here). | `static hit_points(kind)`, `static intel_entry(kind)` |
| `DocumentStore` | The storage interface behind every store: one JSON-shaped `Dictionary`. `MemoryDocumentStore` (here) is for tests; `LocalDocumentStore` (`game/`) keeps one fixed `user://` file per slot. | `read_document() -> Dictionary`, `write_document(doc) -> bool` |
| `RunRules` | The fixed tuning constants of #73. | `static kill_points(kind)`, `static damage_for(source, attack_damage)`, `static boss_points(level)` |
| `DataReader`, `Subscriptions` | Helpers: validating reads of JSON data; one check of a class's bus connections. | |

Payload value types live in `types/`: `GameState.Phase`, `DestroyCause.Cause`, `DamageSource.Source`, `EnemyKind.Kind`, `TutorialPrompt.Id`, `IntelEntry`, `InputDevice.Kind`, `UiCue.Cue`, `SpawnOrder`, `LevelTally`, `RunSummary`, `ScoreEntry`, `GameSettings` and `DevCommand.Command`.

### Wiring and ticking

`main.gd` constructs the rules on `Events`, restores the stores (`Settings`, `Scoreboard`, `IntelCodex`, `TutorialProgress`), calls `GameStateMachine.boot()`, and on every physics step (60 Hz) ticks `RunLedger`, then `LevelProgression`, then `SpawnDirector`, then `TutorialCoach`. Nothing ticks while Paused.

The fight is `game/run/RunDirector` (in `main.tscn`): `main.gd` hands it the stage's mech, shot pool and camera. Each physics step it advances the `EnemyField`, then the `BossArena`, then runs every live player shot past the boss and the enemies (`ShotReferee`); it also owns the off-screen indicators. Enemies and bosses hit the mech through `PlayerTarget`, so `CombatTarget.strike()` is the one place `player_hit` is announced.

## Events

Connect with `Events.<channel>.<event>.connect(...)`; emit only with `Events.<channel>.announce_<event>(...)`. `scripts/checks/godot-architecture` rejects any other use of a Game Event outside `autoload/events.gd`.

### `Events.flow`

| Event | Payload | Announced by | Heard by |
|---|---|---|---|
| `start_requested` | | Boot screen (*intent*) | `GameStateMachine` (Boot to Title); the Audio Unlock |
| `play_requested` | | Title, Game Over, Victory, Scoreboard (*intent*) | `LevelProgression` (new Run) |
| `pause_requested` | | input, pause button (*intent*) | `GameStateMachine` |
| `resume_requested` | | Pause screen (*intent*) | `GameStateMachine` |
| `quit_to_title_requested` | | Pause screen, after confirming (*intent*) | `GameStateMachine`; `LevelProgression` abandons the Run |
| `continue_requested` | | Level Clear screen (*intent*) | `LevelProgression` (next Level) |
| `scoreboard_requested` | | Title, Game Over, Victory (*intent*) | `GameStateMachine` |
| `title_requested` | | Scoreboard, Game Over, Victory (*intent*) | `GameStateMachine` |
| `game_state_changed` | `from, to: GameState.Phase` (equal at boot) | `GameStateMachine` | every screen; `RunLedger`, `SpawnDirector`, `IntelCodex`, `LevelProgression` |
| `input_device_changed` | `device: InputDevice.Kind` | player input (*reported*, `PlayerBusLink`) | prompts and glyphs (#75, #24) |
| `ui_cue_requested` | `cue: UiCue.Cue` | every screen (focus, press, tally tick, pop, ...) | `SfxDirector` (the UI bus); `AudioUnlock` (`START`) |

### `Events.run`

| Event | Payload | Announced by | Heard by |
|---|---|---|---|
| `run_started` | `level_number: int` | `LevelProgression` | HUD, music |
| `level_intro_started` | `level_number, level_name, objective, duration` | `LevelProgression` | Level Intro card; `SpawnDirector` (loads the Level) |
| `level_intro_completed` | `level_number` | `LevelProgression` | HUD, tutorial |
| `boss_gauge_changed` | `points, threshold: int` | `LevelProgression` | HUD Boss Gauge, tutorial (25%) |
| `level_cleared` | `tally: LevelTally` (bonus already scored) | `LevelProgression` | Level Clear and Victory tally; the Level Clear sting |
| `run_ended` | `summary: RunSummary` | `LevelProgression` (Game Over or Victory) | Game Over and Victory screens; `Scoreboard` |
| `kill_scored` | `points, multiplier: int, position: Vector3` | `RunLedger` | score pop-ups, juice; `LevelProgression` (gauge) |
| `score_changed` | `total, delta: int` | `RunLedger` | HUD |
| `combo_changed` | `multiplier: int` (1 when none) | `RunLedger` | HUD, juice |
| `tutorial_prompt_shown` | `prompt: TutorialPrompt.Id` | `TutorialCoach` | HUD tutorial banner |
| `tutorial_prompt_dismissed` | `prompt: TutorialPrompt.Id, completed: bool` | `TutorialCoach` | HUD tutorial banner |

### `Events.player`

| Event | Payload | Announced by | Heard by |
|---|---|---|---|
| `player_fired` | `origin, direction: Vector3` | player mech (*reported*, `PlayerBusLink`) | muzzle juice, SFX; `RunLedger` (accuracy) |
| `player_hit` | `source: DamageSource.Source, position: Vector3, attack_damage: int` (boss attacks only) | `CombatTarget.strike()` only (*reported*, through `PlayerTarget`: once per hit, refused while the mech's window is open) | `RunLedger` |
| `armor_changed` | `armor, max_armor, delta: int` | `RunLedger` | HUD armor bar, hit flash, vignette, shake, rumble |
| `invulnerability_started` | `duration: float` | `RunLedger` | player mech (blink) |
| `invulnerability_ended` | | `RunLedger` | player mech |
| `player_destroyed` | `position: Vector3, cause: DestroyCause.Cause` | `RunLedger` (Armor 0) | death ragdoll, slow-mo; `SpawnDirector` (stops) |
| `life_lost` | `lives_left: int` | `RunLedger` | HUD; `LevelProgression` (respawn or Game Over) |
| `lives_changed` | `lives: int` | `RunLedger` | HUD |
| `bonus_life_awarded` | `lives: int` | `RunLedger` | "1UP" juice, SFX |
| `player_respawned` | | `LevelProgression` (after `RunRules.RESPAWN_DELAY`) | player mech (reset); `SpawnDirector` (resumes) |
| `repair_kit_dropped` | `position: Vector3` | `SpawnDirector` | Repair Kit spawner, tutorial |
| `repair_collected` | `position: Vector3` | Repair Kit (*reported*, `PlayerBusLink`) | `RunLedger` (+30 Armor), juice; `TutorialCoach` |
| `player_moved` | | player mech (*reported*: the pilot steered; once per Skirmish is enough) | `TutorialCoach` |
| `shot_missed` | `position: Vector3` | player shot (*reported*: it expired without a hit) | `TutorialCoach` |

### `Events.enemy`

| Event | Payload | Announced by | Heard by |
|---|---|---|---|
| `spawn_requested` | `order: SpawnOrder` | `SpawnDirector` | enemy spawner (places it, then reports `enemy_spawned`) |
| `enemy_spawned` | `enemy_id: int, kind: EnemyKind.Kind, position: Vector3` | enemy spawner (*reported*) | indicators; `SpawnDirector`, `IntelCodex` |
| `enemy_hit` | `enemy_id: int, position: Vector3` | enemy (*reported*, player shots only) | hit juice; `RunLedger` (accuracy) |
| `enemy_destroyed` | `enemy_id, kind, position, cause: DestroyCause.Cause` | enemy (*reported*) | explosions, hit-stop; `RunLedger`, `SpawnDirector` |
| `enemy_left_play_sphere` | `enemy_id: int` | Play Sphere (*reported*) | indicators; `SpawnDirector` |

Every `spawn_requested` must be answered by exactly one `enemy_spawned`; `SpawnDirector` counts unanswered requests as live. At Level Clear `game/` clears the remaining enemies; the next `level_intro_started` resets the director's count.

### `Events.boss`

| Event | Payload | Announced by | Heard by |
|---|---|---|---|
| `boss_warning_started` | `boss_name: String, duration: float` | `LevelProgression` | siren, red vignette, WARNING banner, music crossfade, tutorial |
| `boss_summoned` | `boss_id: StringName, boss_name: String, max_health, phases: int` | `LevelProgression` | boss spawner, health bar; `IntelCodex` |
| `boss_hit` | `damage: int, position: Vector3` | boss (*reported*) | `BossHealth`; `RunLedger` (accuracy) |
| `boss_damaged` | `health, max_health: int` | `BossHealth` | boss health bar |
| `boss_phase_changed` | `phase, phases: int` (0-based) | `BossHealth` | boss (switches patterns), juice |
| `boss_defeated` | `boss_id: StringName, position: Vector3` (once) | `BossHealth` | slow-mo, explosions, rumble; `LevelProgression`, `SpawnDirector` (Repair Kit) |

### `Events.profile`

| Event | Payload | Announced by | Heard by |
|---|---|---|---|
| `initials_submitted` | `initials: String` | Game Over or Victory initials entry (*intent*) | `Scoreboard` |
| `settings_change_requested` | `settings: GameSettings` | Settings screen (*intent*) | `Settings` |
| `settings_reset_requested` | | Settings screen (*intent*) | `Settings` |
| `scoreboard_qualified` | `rank: int` | `Scoreboard` (on `run_ended`) | Game Over and Victory screens (ask for initials) |
| `scoreboard_saved` | `entry: ScoreEntry, rank: int` | `Scoreboard` | Scoreboard screen |
| `scoreboard_changed` | `entries: Array[ScoreEntry], highlight_rank: int` | `Scoreboard` (restore and save) | Scoreboard screen |
| `settings_changed` | `settings: GameSettings` | `Settings` (restore, change, reset) | audio buses, juice, touch sticks, rumble, tutorial |
| `intel_unlocked` | `entry_id: StringName` | `IntelCodex` | "New Intel" toast |
| `intel_changed` | `unlocked: Array[StringName]` | `IntelCodex` (restore) | Intel screen |
| `intel_catalog_changed` | `entries: Array[IntelEntry]` | `IntelCodex` (restore) | Intel screen |

### `Events.dev`

| Event | Payload | Announced by | Heard by |
|---|---|---|---|
| `dev_command_requested` | `command: DevCommand.Command` | Developer console (*intent*) | `DevCommands` |
| `dev_status_changed` | `invulnerable, dev_assisted: bool` | `DevCommands` (after a command, at Run start) | Developer console |
| `enemies_purge_ordered` | | `DevCommands` (kill all enemies) | enemy field (destroys each enemy as a shot kill, reported as `enemy_destroyed`) |

## Decisions worth knowing

- Only shot kills score, and only in the timed phases (Skirmish, Boss Warning, Boss Fight) while the player is not down. Hits are ignored while invulnerable, down, or outside those phases.
- The Boss Gauge fills only from `kill_scored` points during the Skirmish (combo included), never from boss or Level Clear bonuses, and is capped at the threshold.
- Defeating the boss scores it, closes the Level (adding the bonus, with no Armor bonus if the player is down at that moment) and announces the tally, then moves to Level Clear, or to Victory after Level 6. Once the last life is lost, a boss defeat no longer counts.
- Quitting to Title from Pause abandons the Run: no `run_ended`, no Scoreboard entry.
- Kills that happen while the player is down (between a lost life and the respawn) score nothing.
- Developer commands (#116) take only the legal paths: Skip walks the Game State's legal transitions to the Boss Fight and clears the Level without the boss's score; "kill all enemies" goes through the enemy field's shot-kill path, so the ledger scores the kills. A command that changes a Run marks it dev-assisted, and a dev-assisted Run never asks for initials or places on the Scoreboard.
