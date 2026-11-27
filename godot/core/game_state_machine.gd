class_name GameStateMachine
extends RefCounted
## The Game State machine (#73): a table of legal transitions. Illegal requests
## are rejected and announce nothing. Pause is legal only during play
## (GameState.is_play), and the Paused state resumes only to the phase it
## paused, or quits to the Title.
##
## Listens (screen intents): flow.start_requested (Boot to Title),
## flow.pause_requested, flow.resume_requested, flow.quit_to_title_requested,
## flow.scoreboard_requested and flow.title_requested.
## Announces: flow.game_state_changed for every accepted transition.
## Starting a Run and moving between Level phases is LevelProgression's job: it
## calls request().

## Legal targets of every phase except PAUSED (whose targets depend on the
## phase it paused; see _targets()).
const TRANSITIONS: Dictionary[GameState.Phase, Array] = {
	GameState.Phase.BOOT: [GameState.Phase.TITLE],
	GameState.Phase.TITLE: [GameState.Phase.LEVEL_INTRO, GameState.Phase.SCOREBOARD],
	GameState.Phase.LEVEL_INTRO: [GameState.Phase.SKIRMISH, GameState.Phase.PAUSED],
	GameState.Phase.SKIRMISH:
	[GameState.Phase.BOSS_WARNING, GameState.Phase.PAUSED, GameState.Phase.GAME_OVER],
	GameState.Phase.BOSS_WARNING:
	[GameState.Phase.BOSS_FIGHT, GameState.Phase.PAUSED, GameState.Phase.GAME_OVER],
	GameState.Phase.BOSS_FIGHT:
	[
		GameState.Phase.LEVEL_CLEAR,
		GameState.Phase.VICTORY,
		GameState.Phase.PAUSED,
		GameState.Phase.GAME_OVER
	],
	GameState.Phase.LEVEL_CLEAR: [GameState.Phase.LEVEL_INTRO],
	GameState.Phase.PAUSED: [],
	GameState.Phase.GAME_OVER:
	[GameState.Phase.LEVEL_INTRO, GameState.Phase.SCOREBOARD, GameState.Phase.TITLE],
	GameState.Phase.VICTORY:
	[GameState.Phase.LEVEL_INTRO, GameState.Phase.SCOREBOARD, GameState.Phase.TITLE],
	GameState.Phase.SCOREBOARD: [GameState.Phase.LEVEL_INTRO, GameState.Phase.TITLE],
}

var _events: EventBus
var _state: GameState.Phase = GameState.Phase.BOOT
var _paused_from: GameState.Phase = GameState.Phase.BOOT
var _booted: bool = false


func _init(events: EventBus) -> void:
	_events = events
	var subscribed: Array[int] = [
		_events.flow.start_requested.connect(_on_start_requested),
		_events.flow.pause_requested.connect(_on_pause_requested),
		_events.flow.resume_requested.connect(_on_resume_requested),
		_events.flow.quit_to_title_requested.connect(_on_quit_to_title_requested),
		_events.flow.scoreboard_requested.connect(_on_scoreboard_requested),
		_events.flow.title_requested.connect(_on_title_requested),
	]
	Subscriptions.require_ok("GameStateMachine", subscribed)


## Enters BOOT and announces it (from == to == BOOT). Only the first call counts.
func boot() -> void:
	if _booted:
		return
	_booted = true
	_events.flow.announce_game_state_changed(_state, _state)


## The current phase.
func state() -> GameState.Phase:
	return _state


## The phase the game was paused from (meaningful only while PAUSED).
func paused_from() -> GameState.Phase:
	return _paused_from


## True when `to` is a legal transition from the current phase (after boot()).
func can_transition(to: GameState.Phase) -> bool:
	return _booted and _targets().has(to)


## Moves to `to` if legal, and announces it. Returns false (and announces
## nothing) when the transition is illegal.
func request(to: GameState.Phase) -> bool:
	if not can_transition(to):
		return false
	var from: GameState.Phase = _state
	if to == GameState.Phase.PAUSED:
		_paused_from = from
	_state = to
	_events.flow.announce_game_state_changed(from, to)
	return true


## Every legal target of the current phase.
func _targets() -> Array:
	if _state == GameState.Phase.PAUSED:
		return [_paused_from, GameState.Phase.TITLE]
	return TRANSITIONS[_state]


func _on_start_requested() -> void:
	var _ok: bool = request(GameState.Phase.TITLE) if _state == GameState.Phase.BOOT else false


func _on_pause_requested() -> void:
	var _ok: bool = request(GameState.Phase.PAUSED)


func _on_resume_requested() -> void:
	var _ok: bool = request(_paused_from) if _state == GameState.Phase.PAUSED else false


func _on_quit_to_title_requested() -> void:
	var _ok: bool = request(GameState.Phase.TITLE) if _state == GameState.Phase.PAUSED else false


func _on_scoreboard_requested() -> void:
	var _ok: bool = request(GameState.Phase.SCOREBOARD)


func _on_title_requested() -> void:
	# Back to the Title never abandons a Run: Pause has its own confirmed quit.
	var _ok: bool = request(GameState.Phase.TITLE) if _state != GameState.Phase.PAUSED else false
