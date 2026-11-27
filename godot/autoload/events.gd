class_name EventBus
extends Node
## The Game Event bus, registered as the `Events` autoload. It holds no state
## and declares every Game Event as a typed signal, grouped into channels:
##
##   Events.flow     intents from the screens, the Game State and the input device
##   Events.run      the Run, its Levels, the Boss Gauge and scoring
##   Events.player   the player mech: shots, hits, Armor, lives, Repair Kits
##   Events.enemy    spawn decisions and enemy facts
##   Events.boss     the boss: warning, summon, hits, phases, defeat
##   Events.profile  persisted player data: Scoreboard, Settings, Intel
##   Events.dev      the Developer console's commands and status (#116)
##
## Emit only through each channel's typed `announce_*` methods: they type-check
## every payload at compile time, which `Signal.emit()` does not.
## scripts/checks/godot-architecture rejects `.emit(` on a bus signal elsewhere.
## Payload types live in types/, which every layer may use.
## godot/core/README.md documents who announces and who listens to each event.

## Intents from the screens (they never call core/ directly) and the Game State.
var flow: FlowChannel = FlowChannel.new()
## The Run, its Levels, the Boss Gauge and scoring.
var run: RunChannel = RunChannel.new()
## The player mech.
var player: PlayerChannel = PlayerChannel.new()
## Spawn decisions and enemy facts.
var enemy: EnemyChannel = EnemyChannel.new()
## The boss of the current Level.
var boss: BossChannel = BossChannel.new()
## Persisted player data.
var profile: ProfileChannel = ProfileChannel.new()
## The Developer console (#116).
var dev: DevChannel = DevChannel.new()


## Intents from the screens, and the Game State itself.
class FlowChannel:
	extends RefCounted

	## The Boot screen was tapped or a key pressed (audio is unlocked).
	signal start_requested
	## Play was chosen (Title, Game Over, Victory or Scoreboard): start a new Run.
	signal play_requested
	## The player paused (Esc, P, Start or the on-screen button).
	signal pause_requested
	## Resume was chosen on the Pause screen.
	signal resume_requested
	## Quit to Title was confirmed on the Pause screen. The Run is abandoned.
	signal quit_to_title_requested
	## "Press to continue" on the Level Clear screen.
	signal continue_requested
	## The Scoreboard was opened (from Title, Game Over or Victory).
	signal scoreboard_requested
	## Back to the Title (from the Scoreboard, Game Over or Victory).
	signal title_requested
	## The Game State changed. At boot `from` equals `to` (the first state entered).
	signal game_state_changed(from: GameState.Phase, to: GameState.Phase)
	## Reported by game/: the player used a different kind of input device, so
	## prompts and glyphs switch to it.
	signal input_device_changed(device: InputDevice.Kind)
	## A screen asks for a UI sound (focus, confirm, tally tick, ...).
	signal ui_cue_requested(cue: UiCue.Cue)

	func announce_start_requested() -> void:
		start_requested.emit()

	func announce_play_requested() -> void:
		play_requested.emit()

	func announce_pause_requested() -> void:
		pause_requested.emit()

	func announce_resume_requested() -> void:
		resume_requested.emit()

	func announce_quit_to_title_requested() -> void:
		quit_to_title_requested.emit()

	func announce_continue_requested() -> void:
		continue_requested.emit()

	func announce_scoreboard_requested() -> void:
		scoreboard_requested.emit()

	func announce_title_requested() -> void:
		title_requested.emit()

	func announce_game_state_changed(from: GameState.Phase, to: GameState.Phase) -> void:
		game_state_changed.emit(from, to)

	func announce_input_device_changed(device: InputDevice.Kind) -> void:
		input_device_changed.emit(device)

	func announce_ui_cue_requested(cue: UiCue.Cue) -> void:
		ui_cue_requested.emit(cue)


## The Run, its Levels, the Boss Gauge and scoring.
class RunChannel:
	extends RefCounted

	## A new Run started at `level_number` (always 1 in normal play).
	signal run_started(level_number: int)
	## A Level Intro card opened: number, name, objective and how long it shows.
	signal level_intro_started(
		level_number: int, level_name: String, objective: String, duration: float
	)
	## The Level Intro ended and the Skirmish began.
	signal level_intro_completed(level_number: int)
	## The Boss Gauge moved: points earned this Level toward the boss threshold.
	signal boss_gauge_changed(points: int, threshold: int)
	## The Level's boss was defeated; the tally's bonus is already in the score.
	signal level_cleared(tally: LevelTally)
	## The Run ended at Game Over or Victory.
	signal run_ended(summary: RunSummary)
	## A shot kill scored `points` (base points times the combo `multiplier`).
	signal kill_scored(points: int, multiplier: int, position: Vector3)
	## The score changed to `total` by `delta`.
	signal score_changed(total: int, delta: int)
	## The combo multiplier changed (1 when no combo is running, up to 8).
	signal combo_changed(multiplier: int)
	## A first-flight tutorial prompt appears.
	signal tutorial_prompt_shown(prompt: TutorialPrompt.Id)
	## A tutorial prompt leaves: `completed` when its condition was met.
	signal tutorial_prompt_dismissed(prompt: TutorialPrompt.Id, completed: bool)

	func announce_run_started(level_number: int) -> void:
		run_started.emit(level_number)

	func announce_level_intro_started(
		level_number: int, level_name: String, objective: String, duration: float
	) -> void:
		level_intro_started.emit(level_number, level_name, objective, duration)

	func announce_level_intro_completed(level_number: int) -> void:
		level_intro_completed.emit(level_number)

	func announce_boss_gauge_changed(points: int, threshold: int) -> void:
		boss_gauge_changed.emit(points, threshold)

	func announce_level_cleared(tally: LevelTally) -> void:
		level_cleared.emit(tally)

	func announce_run_ended(summary: RunSummary) -> void:
		run_ended.emit(summary)

	func announce_kill_scored(points: int, multiplier: int, position: Vector3) -> void:
		kill_scored.emit(points, multiplier, position)

	func announce_score_changed(total: int, delta: int) -> void:
		score_changed.emit(total, delta)

	func announce_combo_changed(multiplier: int) -> void:
		combo_changed.emit(multiplier)

	func announce_tutorial_prompt_shown(prompt: TutorialPrompt.Id) -> void:
		tutorial_prompt_shown.emit(prompt)

	func announce_tutorial_prompt_dismissed(prompt: TutorialPrompt.Id, completed: bool) -> void:
		tutorial_prompt_dismissed.emit(prompt, completed)


## The player mech.
class PlayerChannel:
	extends RefCounted

	## Reported by game/: the player fired a shot.
	signal player_fired(origin: Vector3, direction: Vector3)
	## Reported by game/: something hit the player. `attack_damage` is the boss
	## attack's damage from the Level data for BOSS_ATTACK, and ignored otherwise.
	signal player_hit(source: DamageSource.Source, position: Vector3, attack_damage: int)
	## Armor changed to `armor` (of `max_armor`) by `delta` (negative on a hit).
	signal armor_changed(armor: int, max_armor: int, delta: int)
	## The player cannot be damaged for `duration` seconds (after a hit or a respawn).
	signal invulnerability_started(duration: float)
	## The player can be damaged again.
	signal invulnerability_ended
	## Armor reached 0: the mech is destroyed (death ragdoll, slow-mo).
	signal player_destroyed(position: Vector3, cause: DestroyCause.Cause)
	## A life was lost; `lives_left` may be 0 (Game Over follows).
	signal life_lost(lives_left: int)
	## The number of lives changed (Run start, life lost, bonus life).
	signal lives_changed(lives: int)
	## The one-time bonus life was awarded; the player now has `lives`.
	signal bonus_life_awarded(lives: int)
	## The player respawns now, at full Armor (game/ resets the mech).
	signal player_respawned
	## A Repair Kit drops at `position` (game/ spawns it).
	signal repair_kit_dropped(position: Vector3)
	## Reported by game/: the player flew through a Repair Kit.
	signal repair_collected(position: Vector3)
	## Reported by game/: the player steered the mech (once per Skirmish is enough).
	signal player_moved
	## Reported by game/: a player shot expired without hitting anything.
	signal shot_missed(position: Vector3)

	func announce_player_fired(origin: Vector3, direction: Vector3) -> void:
		player_fired.emit(origin, direction)

	func announce_player_hit(
		source: DamageSource.Source, position: Vector3, attack_damage: int
	) -> void:
		player_hit.emit(source, position, attack_damage)

	func announce_armor_changed(armor: int, max_armor: int, delta: int) -> void:
		armor_changed.emit(armor, max_armor, delta)

	func announce_invulnerability_started(duration: float) -> void:
		invulnerability_started.emit(duration)

	func announce_invulnerability_ended() -> void:
		invulnerability_ended.emit()

	func announce_player_destroyed(position: Vector3, cause: DestroyCause.Cause) -> void:
		player_destroyed.emit(position, cause)

	func announce_life_lost(lives_left: int) -> void:
		life_lost.emit(lives_left)

	func announce_lives_changed(lives: int) -> void:
		lives_changed.emit(lives)

	func announce_bonus_life_awarded(lives: int) -> void:
		bonus_life_awarded.emit(lives)

	func announce_player_respawned() -> void:
		player_respawned.emit()

	func announce_repair_kit_dropped(position: Vector3) -> void:
		repair_kit_dropped.emit(position)

	func announce_repair_collected(position: Vector3) -> void:
		repair_collected.emit(position)

	func announce_player_moved() -> void:
		player_moved.emit()

	func announce_shot_missed(position: Vector3) -> void:
		shot_missed.emit(position)


## Spawn decisions and enemy facts.
class EnemyChannel:
	extends RefCounted

	## The spawn director decided to spawn an enemy (game/ places it).
	signal spawn_requested(order: SpawnOrder)
	## Reported by game/: an enemy entered play with a unique `enemy_id`.
	signal enemy_spawned(enemy_id: int, kind: EnemyKind.Kind, position: Vector3)
	## Reported by game/: a player shot hit an enemy (it may survive).
	signal enemy_hit(enemy_id: int, position: Vector3)
	## Reported by game/: an enemy was destroyed, by a shot or by a crash.
	signal enemy_destroyed(
		enemy_id: int, kind: EnemyKind.Kind, position: Vector3, cause: DestroyCause.Cause
	)
	## Reported by game/: an enemy left the Play Sphere and was despawned.
	signal enemy_left_play_sphere(enemy_id: int)

	func announce_spawn_requested(order: SpawnOrder) -> void:
		spawn_requested.emit(order)

	func announce_enemy_spawned(enemy_id: int, kind: EnemyKind.Kind, position: Vector3) -> void:
		enemy_spawned.emit(enemy_id, kind, position)

	func announce_enemy_hit(enemy_id: int, position: Vector3) -> void:
		enemy_hit.emit(enemy_id, position)

	func announce_enemy_destroyed(
		enemy_id: int, kind: EnemyKind.Kind, position: Vector3, cause: DestroyCause.Cause
	) -> void:
		enemy_destroyed.emit(enemy_id, kind, position, cause)

	func announce_enemy_left_play_sphere(enemy_id: int) -> void:
		enemy_left_play_sphere.emit(enemy_id)


## The boss of the current Level.
class BossChannel:
	extends RefCounted

	## The Boss Gauge is full: siren, red vignette and a WARNING banner.
	signal boss_warning_started(boss_name: String, duration: float)
	## The boss enters (game/ spawns it), with its health and phase count.
	signal boss_summoned(boss_id: StringName, boss_name: String, max_health: int, phases: int)
	## Reported by game/: a player shot hit the boss for `damage`.
	signal boss_hit(damage: int, position: Vector3)
	## The boss's health changed to `health` of `max_health`.
	signal boss_damaged(health: int, max_health: int)
	## The boss entered `phase` (0-based) of `phases`.
	signal boss_phase_changed(phase: int, phases: int)
	## The boss was defeated, once, at `position`.
	signal boss_defeated(boss_id: StringName, position: Vector3)

	func announce_boss_warning_started(boss_name: String, duration: float) -> void:
		boss_warning_started.emit(boss_name, duration)

	func announce_boss_summoned(
		boss_id: StringName, boss_name: String, max_health: int, phases: int
	) -> void:
		boss_summoned.emit(boss_id, boss_name, max_health, phases)

	func announce_boss_hit(damage: int, position: Vector3) -> void:
		boss_hit.emit(damage, position)

	func announce_boss_damaged(health: int, max_health: int) -> void:
		boss_damaged.emit(health, max_health)

	func announce_boss_phase_changed(phase: int, phases: int) -> void:
		boss_phase_changed.emit(phase, phases)

	func announce_boss_defeated(boss_id: StringName, position: Vector3) -> void:
		boss_defeated.emit(boss_id, position)


## Persisted player data: Scoreboard, Settings and Intel.
class ProfileChannel:
	extends RefCounted

	## The Game Over or Victory screen confirmed three initials.
	signal initials_submitted(initials: String)
	## The Settings screen asks for new settings (core/ clamps and saves them).
	signal settings_change_requested(settings: GameSettings)
	## The Settings screen asks to reset every setting to its default.
	signal settings_reset_requested
	## The ended Run's score places at `rank` (0-based): ask for initials.
	signal scoreboard_qualified(rank: int)
	## A Scoreboard entry was saved at `rank` (0-based).
	signal scoreboard_saved(entry: ScoreEntry, rank: int)
	## The Scoreboard's entries, best first; `highlight_rank` is the new entry or -1.
	signal scoreboard_changed(entries: Array[ScoreEntry], highlight_rank: int)
	## The settings in effect (on load, on change and on reset).
	signal settings_changed(settings: GameSettings)
	## An Intel entry (an enemy kind id or a boss id) was encountered for the first time.
	signal intel_unlocked(entry_id: StringName)
	## Every unlocked Intel entry id, on load.
	signal intel_changed(unlocked: Array[StringName])
	## What the Intel codex lists (enemies, then bosses), on load.
	signal intel_catalog_changed(entries: Array[IntelEntry])

	func announce_initials_submitted(initials: String) -> void:
		initials_submitted.emit(initials)

	func announce_settings_change_requested(settings: GameSettings) -> void:
		settings_change_requested.emit(settings)

	func announce_settings_reset_requested() -> void:
		settings_reset_requested.emit()

	func announce_scoreboard_qualified(rank: int) -> void:
		scoreboard_qualified.emit(rank)

	func announce_scoreboard_saved(entry: ScoreEntry, rank: int) -> void:
		scoreboard_saved.emit(entry, rank)

	func announce_scoreboard_changed(entries: Array[ScoreEntry], highlight_rank: int) -> void:
		scoreboard_changed.emit(entries, highlight_rank)

	func announce_settings_changed(settings: GameSettings) -> void:
		settings_changed.emit(settings)

	func announce_intel_unlocked(entry_id: StringName) -> void:
		intel_unlocked.emit(entry_id)

	func announce_intel_changed(unlocked: Array[StringName]) -> void:
		intel_changed.emit(unlocked)

	func announce_intel_catalog_changed(entries: Array[IntelEntry]) -> void:
		intel_catalog_changed.emit(entries)

## The Developer console (#116): its commands, and what they decided.
class DevChannel:
	extends RefCounted

	## The Developer console asks for `command` (core/ ignores it unless
	## Developer mode is on).
	signal dev_command_requested(command: DevCommand.Command)
	## Developer invulnerability is `invulnerable`; the current Run is
	## `dev_assisted` (it will never be saved to the Scoreboard).
	signal dev_status_changed(invulnerable: bool, dev_assisted: bool)
	## Every enemy in play is to be destroyed now, as by a shot (game/ does it
	## and reports each one as enemy_destroyed).
	signal enemies_purge_ordered

	func announce_dev_command_requested(command: DevCommand.Command) -> void:
		dev_command_requested.emit(command)

	func announce_dev_status_changed(invulnerable: bool, dev_assisted: bool) -> void:
		dev_status_changed.emit(invulnerable, dev_assisted)

	func announce_enemies_purge_ordered() -> void:
		enemies_purge_ordered.emit()
