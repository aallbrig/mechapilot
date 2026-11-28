class_name PlayMarkers
extends Node
## Console markers that let the web smoke test (tests/e2e/web-smoke.mjs) see
## real play in the browser, once each per Run: a Level's Skirmish began, the
## player fired a shot, and the mech flew under thrust from the move input
## (PlayerMech.thrust past its dead zone: nothing but the pilot's move intent
## sets it). One line per fact, never per frame.

const PLAY_MARKER: String = "mechapilot: level %d in play"
const FIRED_MARKER: String = "mechapilot: player fired"
const STEERED_MARKER: String = "mechapilot: player steered"

var _mech: PlayerMech
var _fired: bool = false
var _steered: bool = false


## Watch `events` and `mech`. Call once.
func setup(events: EventBus, mech: PlayerMech) -> void:
	_mech = mech
	var subscribed: Array[int] = [
		events.run.run_started.connect(_on_run_started),
		events.run.level_intro_completed.connect(_on_level_in_play),
		events.player.player_fired.connect(_on_fired),
	]
	if subscribed.count(OK) != subscribed.size():
		push_error("PlayMarkers: could not subscribe to the bus")
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not _steered and _mech.thrust > _mech.tuning.thrust_deadzone:
		_steered = true
		set_physics_process(false)
		print(STEERED_MARKER)


func _on_run_started(_level_number: int) -> void:
	_fired = false
	_steered = false
	set_physics_process(true)


func _on_level_in_play(level_number: int) -> void:
	print(PLAY_MARKER % level_number)


func _on_fired(_origin: Vector3, _direction: Vector3) -> void:
	if not _fired:
		_fired = true
		print(FIRED_MARKER)
