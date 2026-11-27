class_name TimeScaleDirector
extends Node
## Hit-stop and slow-mo (#26, #9's juice spec). A kill freezes time for about
## 40 ms; the player's death and a boss kill slow it, then ease it back. It
## counts real time, so it always ends, and every effect ends at exactly 1.0.
## Reduced motion turns hit-stop off; slow-mo stays (it paces the moment, it is
## not motion). Leaving play (Pause, Title, Scoreboard) restores 1.0 at once.
## Real time comes from RealClock, never from the frame's scaled delta, and an
## effect counts from the moment it starts, even mid-frame (from a kill
## announced in _physics_process).
##
## It writes Engine.time_scale only once drive_engine() is called (main.gd), so
## tests read time_scale() instead of the engine's.

## The hit-stop of one kill: its length (s, real time) and the time scale.
const HITSTOP_SECONDS: float = 0.04
const HITSTOP_SCALE: float = 0.02
## A boss phase change freezes a little longer.
const PHASE_HITSTOP_SECONDS: float = 0.08
## Hit-stop never runs longer than this in one go, however many kills land.
const MAX_HITSTOP: float = 0.12
## The death slow-mo: its length (s, real time) and its deepest scale.
const DEATH_SLOWMO_SECONDS: float = 0.9
const DEATH_SLOWMO_SCALE: float = 0.2
## The boss kill: a longer, deeper slow-mo for the defeat sequence.
const BOSS_SLOWMO_SECONDS: float = 1.6
const BOSS_SLOWMO_SCALE: float = 0.25
## Real time per frame is never taken as longer than this (a stall).

var _clock: RealClock = RealClock.new()
var _hitstop_left: float = 0.0
var _slowmo_left: float = 0.0
var _slowmo_length: float = 1.0
var _slowmo_scale: float = 1.0
var _scale: float = 1.0
var _drives_engine: bool = false
var _settings: GameSettings = GameSettings.new()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	advance(_clock.step())


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	(
		BusLinks
		. require_ok(
			"TimeScaleDirector",
			[
				bus.enemy.enemy_destroyed.connect(_on_enemy_destroyed),
				bus.player.player_destroyed.connect(_on_player_destroyed),
				bus.boss.boss_defeated.connect(_on_boss_defeated),
				bus.boss.boss_phase_changed.connect(_on_boss_phase_changed),
				bus.flow.game_state_changed.connect(_on_game_state_changed),
				bus.profile.settings_changed.connect(_on_settings_changed),
			]
		)
	)


## From now on, write the time scale to Engine.time_scale (the game, not tests).
func drive_engine() -> void:
	_drives_engine = true
	_apply()


## Stop writing Engine.time_scale, and put it back to 1.0.
func release_engine() -> void:
	if _drives_engine:
		Engine.time_scale = 1.0
	_drives_engine = false


## The time scale in effect.
func time_scale() -> float:
	return _scale


## Move the effects on by `real_delta` seconds of real time.
func advance(real_delta: float) -> void:
	_hitstop_left = maxf(0.0, _hitstop_left - real_delta)
	_slowmo_left = maxf(0.0, _slowmo_left - real_delta)
	_apply()


func _freeze(seconds: float) -> void:
	if not JuiceSettings.hitstop(_settings):
		return
	_hitstop_left = minf(maxf(_hitstop_left, seconds), MAX_HITSTOP)
	_clock.mark()
	_apply()


func _slow(seconds: float, deepest: float) -> void:
	_slowmo_length = seconds
	_slowmo_left = seconds
	_slowmo_scale = deepest
	_clock.mark()
	_apply()


func _restore() -> void:
	_hitstop_left = 0.0
	_slowmo_left = 0.0
	_apply()


func _apply() -> void:
	if _hitstop_left > 0.0:
		_scale = HITSTOP_SCALE
	elif _slowmo_left > 0.0:
		_scale = lerpf(1.0, _slowmo_scale, _slowmo_left / _slowmo_length)
	else:
		_scale = 1.0
	if _drives_engine:
		Engine.time_scale = _scale


func _on_enemy_destroyed(
	_enemy_id: int, _kind: EnemyKind.Kind, _position: Vector3, _cause: DestroyCause.Cause
) -> void:
	_freeze(HITSTOP_SECONDS)


func _on_player_destroyed(_position: Vector3, _cause: DestroyCause.Cause) -> void:
	_slow(DEATH_SLOWMO_SECONDS, DEATH_SLOWMO_SCALE)


func _on_boss_defeated(_boss_id: StringName, _position: Vector3) -> void:
	_slow(BOSS_SLOWMO_SECONDS, BOSS_SLOWMO_SCALE)


func _on_boss_phase_changed(_phase: int, _phases: int) -> void:
	_freeze(PHASE_HITSTOP_SECONDS)


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	if (
		to == GameState.Phase.PAUSED
		or to == GameState.Phase.TITLE
		or to == GameState.Phase.SCOREBOARD
		or to == GameState.Phase.BOOT
	):
		_restore()


func _on_settings_changed(settings: GameSettings) -> void:
	_settings = settings.copy()
	if not JuiceSettings.hitstop(_settings):
		_hitstop_left = 0.0
		_apply()
