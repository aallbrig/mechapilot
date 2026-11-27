class_name PlayerBusLink
extends Node
## The one place the player mech and its input meet the Events bus (#21's
## catalog, see godot/core/README.md). Nodes report, rules decide:
##
##   reported   PlayerMech.fired         -> player.player_fired
##              PlayerMech.hit_taken     -> player.player_hit
##              PlayerMech.repaired      -> player.repair_collected
##              PlayerInput.device_changed -> flow.input_device_changed
##   decided    player.armor_changed (a loss)  -> PlayerMech.react_to_hit()
##              player.invulnerability_started -> PlayerMech.guard_for()
##              player.invulnerability_ended   -> PlayerMech.end_guard()
##              player.player_destroyed        -> PlayerMech.destroy()
##              player.player_respawned        -> PlayerMech.respawn() where it fell
##              run.run_started                -> end_guard(), then respawn() at the origin
##              flow.game_state_changed        -> PlayerMech.drop_queued_tap()
##
## Once linked, the mech stops guarding itself: the RunLedger owns the window.

## Where a new Run starts the mech.
const RUN_START: Vector3 = Vector3.ZERO

var _player: PlayerMech
var _errors: int = 0


## Wire `player` and `input` to `bus` (the Events autoload, or a test bus).
func link(bus: EventBus, player: PlayerMech, input: PlayerInput) -> void:
	_player = player
	player.self_guarding = false
	_check(player.fired.connect(bus.player.announce_player_fired) as Error)
	_check(player.hit_taken.connect(bus.player.announce_player_hit) as Error)
	_check(player.repaired.connect(bus.player.announce_repair_collected) as Error)
	_check(input.device_changed.connect(bus.flow.announce_input_device_changed) as Error)
	_check(bus.player.armor_changed.connect(_on_armor_changed) as Error)
	_check(bus.player.invulnerability_started.connect(player.guard_for) as Error)
	_check(bus.player.invulnerability_ended.connect(player.end_guard) as Error)
	_check(bus.player.player_destroyed.connect(_on_player_destroyed) as Error)
	_check(bus.player.player_respawned.connect(_on_player_respawned) as Error)
	_check(bus.run.run_started.connect(_on_run_started) as Error)
	_check(bus.flow.game_state_changed.connect(_on_game_state_changed) as Error)


## Connections that failed (0 when fully linked).
func error_count() -> int:
	return _errors


func _on_armor_changed(_armor: int, _max_armor: int, delta: int) -> void:
	if delta < 0:
		_player.react_to_hit()


func _on_player_destroyed(_position: Vector3, _cause: DestroyCause.Cause) -> void:
	_player.destroy()


func _on_player_respawned() -> void:
	_player.respawn(_player.position)


func _on_run_started(_level_number: int) -> void:
	# RunLedger.start_run() zeroes its window without announcing
	# invulnerability_ended, and a linked respawn() keeps whatever window is open,
	# so a window left over from the last Run would outlive it.
	_player.end_guard()
	_player.respawn(RUN_START)


func _check(err: Error) -> void:
	if err != OK:
		_errors += 1
		push_error("PlayerBusLink: could not connect: %s" % error_string(err))


## A Tap Shot from before a Pause (or any change of Game State) never fires after it.
func _on_game_state_changed(_from: GameState.Phase, _to: GameState.Phase) -> void:
	_player.drop_queued_tap()
