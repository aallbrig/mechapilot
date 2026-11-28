class_name LevelProgression
extends RefCounted
## Runs the Run (#73): six Levels in order, each Level Intro, Skirmish, Boss
## Warning, Boss Fight and Level Clear, then Victory after Level 6, or Game
## Over when the last life is lost. It drives the GameStateMachine and calls
## the RunLedger's lifecycle methods in a fixed order.
##
## The Boss Gauge fills with the points of shot kills earned during this
## Level's Skirmish; at the Level's threshold the Boss Warning starts. Losing a
## life keeps the gauge and the boss's health: only the mech respawns.
##
## Listens: flow.play_requested (new Run), flow.continue_requested (next Level),
## flow.game_state_changed (a quit to Title abandons the Run), run.kill_scored
## (the gauge), player.life_lost (respawn or Game Over) and boss.boss_defeated.
## Announces: run.run_started, run.level_intro_started, run.level_intro_completed,
## run.boss_gauge_changed, run.level_cleared, run.run_ended,
## boss.boss_warning_started, boss.boss_summoned and player.player_respawned.
##
## Developer commands (#116, through DevCommands): fill_boss_gauge() and
## skip_level(), which take only the Game State's legal transitions.

## The phases from which Play starts a new Run.
const RUN_START_PHASES: Array[GameState.Phase] = [
	GameState.Phase.TITLE,
	GameState.Phase.GAME_OVER,
	GameState.Phase.VICTORY,
	GameState.Phase.SCOREBOARD,
]

var _events: EventBus
var _machine: GameStateMachine
var _ledger: RunLedger
var _boss_health: BossHealth
var _levels: Array[LevelDefinition] = []
var _level: LevelDefinition = null
var _run_active: bool = false
var _gauge: int = 0
var _phase_left: float = 0.0
var _respawn_left: float = 0.0
var _game_over_left: float = 0.0
var _game_over_pending: bool = false


func _init(
	events: EventBus,
	machine: GameStateMachine,
	ledger: RunLedger,
	boss_health: BossHealth,
	levels: Array[LevelDefinition]
) -> void:
	_events = events
	_machine = machine
	_ledger = ledger
	_boss_health = boss_health
	_levels = levels.duplicate()
	var subscribed: Array[int] = [
		_events.flow.play_requested.connect(_on_play_requested),
		_events.flow.continue_requested.connect(_on_continue_requested),
		_events.flow.game_state_changed.connect(_on_game_state_changed),
		_events.run.kill_scored.connect(_on_kill_scored),
		_events.player.life_lost.connect(_on_life_lost),
		_events.boss.boss_defeated.connect(_on_boss_defeated),
	]
	Subscriptions.require_ok("LevelProgression", subscribed)


## Advances the Level Intro, Boss Warning, respawn and Game Over timers by
## `delta` seconds. Nothing advances while paused or outside a Run.
func tick(delta: float) -> void:
	if not _run_active or _machine.state() == GameState.Phase.PAUSED or delta <= 0.0:
		return
	if _game_over_pending:
		_game_over_left -= delta
		if _game_over_left <= 0.0:
			_end_run(false)
		return
	if _respawn_left > 0.0:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_respawn()
	match _machine.state():
		GameState.Phase.LEVEL_INTRO:
			_phase_left -= delta
			if _phase_left <= 0.0 and _machine.request(GameState.Phase.SKIRMISH):
				_events.run.announce_level_intro_completed(_level.number)
		GameState.Phase.BOSS_WARNING:
			_phase_left -= delta
			if _phase_left <= 0.0:
				_summon_boss()
		_:
			pass


## The current Level (null outside a Run).
func current_level() -> LevelDefinition:
	return _level


## The current Level's number, or 0 outside a Run.
func level_number() -> int:
	return _level.number if _level != null else 0


## Boss Gauge points earned in this Level (never above the threshold).
func gauge() -> int:
	return _gauge


func is_run_active() -> bool:
	return _run_active


## True between losing the last life and Game Over.
func is_game_over_pending() -> bool:
	return _game_over_pending


## Fills the Boss Gauge to the Level's threshold, which starts the Boss
## Warning as a full gauge always does. Only in the Skirmish; returns true
## when it filled the gauge.
func fill_boss_gauge() -> bool:
	if not _run_active or _game_over_pending or _machine.state() != GameState.Phase.SKIRMISH:
		return false
	_raise_gauge(_level.boss.threshold)
	return true


## Closes the current Level at once, without the boss's score: from the Level
## Intro, Skirmish, Boss Warning or Boss Fight it walks the legal transitions
## to the Boss Fight (no boss is summoned) and clears the Level, to Level Clear
## or, on the last Level, Victory. Returns true when the Level was closed.
func skip_level() -> bool:
	if not _run_active or _game_over_pending:
		return false
	if _machine.state() == GameState.Phase.LEVEL_INTRO:
		if not _machine.request(GameState.Phase.SKIRMISH):
			return false
		_events.run.announce_level_intro_completed(_level.number)
	if _machine.state() == GameState.Phase.SKIRMISH:
		var _warned: bool = _machine.request(GameState.Phase.BOSS_WARNING)
	if _machine.state() == GameState.Phase.BOSS_WARNING:
		var _fought: bool = _machine.request(GameState.Phase.BOSS_FIGHT)
	if _machine.state() != GameState.Phase.BOSS_FIGHT:
		return false
	_clear_level(false)
	return true


func _on_play_requested() -> void:
	if _levels.is_empty() or not RUN_START_PHASES.has(_machine.state()):
		return
	_run_active = true
	_ledger.start_run()
	_events.run.announce_run_started(1)
	_enter_level(0)


func _on_continue_requested() -> void:
	if not _run_active or _machine.state() != GameState.Phase.LEVEL_CLEAR:
		return
	_enter_level(_level.number)


func _on_game_state_changed(from: GameState.Phase, to: GameState.Phase) -> void:
	if from == GameState.Phase.PAUSED and to == GameState.Phase.TITLE:
		_abandon()


func _on_kill_scored(points: int, _multiplier: int, _position: Vector3) -> void:
	if not _run_active or _machine.state() != GameState.Phase.SKIRMISH:
		return
	_raise_gauge(points)


func _raise_gauge(points: int) -> void:
	var threshold: int = _level.boss.threshold
	_gauge = mini(_gauge + points, threshold)
	_events.run.announce_boss_gauge_changed(_gauge, threshold)
	if _gauge >= threshold and _machine.request(GameState.Phase.BOSS_WARNING):
		_phase_left = RunRules.BOSS_WARNING_DURATION
		_events.boss.announce_boss_warning_started(
			_level.boss.display_name, RunRules.BOSS_WARNING_DURATION
		)


func _on_life_lost(lives_left: int) -> void:
	if not _run_active:
		return
	if lives_left > 0:
		_respawn_left = RunRules.RESPAWN_DELAY
		return
	_respawn_left = 0.0
	_game_over_pending = true
	_game_over_left = _level.game_over_delay
	if _game_over_left <= 0.0:
		_end_run(false)


func _on_boss_defeated(_boss_id: StringName, _position: Vector3) -> void:
	if not _run_active or _game_over_pending or _machine.state() != GameState.Phase.BOSS_FIGHT:
		return
	_clear_level(true)


## Closes the Level from the Boss Fight: the boss's score (when `award_boss`),
## the tally, then Level Clear, or Victory after the last Level.
func _clear_level(award_boss: bool) -> void:
	_boss_health.disarm()
	if award_boss:
		_ledger.award_boss()
	_events.run.announce_level_cleared(_ledger.close_level())
	if _level.number >= _levels.size():
		_end_run(true)
	else:
		var _cleared: bool = _machine.request(GameState.Phase.LEVEL_CLEAR)


func _enter_level(index: int) -> void:
	_level = _levels[index]
	_gauge = 0
	_phase_left = _level.intro_duration
	_boss_health.disarm()
	if _ledger.is_down():
		_respawn()
	_respawn_left = 0.0
	_ledger.start_level(_level.number)
	_events.run.announce_level_intro_started(
		_level.number, _level.display_name, _level.objective, _level.intro_duration
	)
	_events.run.announce_boss_gauge_changed(_gauge, _level.boss.threshold)
	var _entered: bool = _machine.request(GameState.Phase.LEVEL_INTRO)


func _summon_boss() -> void:
	if not _machine.request(GameState.Phase.BOSS_FIGHT):
		return
	var boss: BossDefinition = _level.boss
	_boss_health.arm(boss)
	_events.boss.announce_boss_summoned(boss.id, boss.display_name, boss.health, boss.phases.size())


func _respawn() -> void:
	_respawn_left = 0.0
	_ledger.respawn()
	_events.player.announce_player_respawned()


func _end_run(victory: bool) -> void:
	var target: GameState.Phase = GameState.Phase.VICTORY if victory else GameState.Phase.GAME_OVER
	if not _machine.request(target):
		return
	_run_active = false
	_game_over_pending = false
	_boss_health.disarm()
	_events.run.announce_run_ended(_ledger.summary(victory))


func _abandon() -> void:
	_run_active = false
	_game_over_pending = false
	_respawn_left = 0.0
	_boss_health.disarm()
	_level = null
