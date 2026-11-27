class_name Autopilot
extends Node
## Test support: a scripted player for the assembled game in main.tscn. It
## plays only through real input: menu keys go through Input.parse_input_event
## (so the screens see them as a player's key presses), and flight goes through
## the game's own input actions (Input.action_press on move_* and aim_*), which
## PlayerInput reads like a keyboard or gamepad.
##
##   FIGHT    keep a stand-off distance from the nearest enemy (or the boss),
##            circle it, and aim the gravity-shot arc at it (aiming fires).
##   RAM      fly straight into the nearest enemy without firing, to lose lives.
##   IDLE     touch nothing in flight.
## In menus it presses Enter (the Boot, Title, Level Clear, Game Over and
## Victory screens all confirm with it) at a human pace.

## One physics tick was flown (tests await it instead of the scene tree).
signal ticked

enum Mode { FIGHT, RAM, IDLE }

## Seconds between menu presses (game time).
const MENU_PRESS_EVERY: float = 0.4
## The stand-off distance kept from enemies and from the boss (units).
const STAND_OFF: float = 9.0
const BOSS_STAND_OFF: float = 11.0
## How strongly the pilot circles its target, against closing the distance.
const ORBIT: float = 0.8
## Seconds of target motion the aim leads.
const LEAD: float = 0.25

var mode: Mode = Mode.FIGHT
## Game time flown, in physics seconds.
var flown: float = 0.0

var _stage: FlightStage
var _run: RunDirector
var _phase: GameState.Phase = GameState.Phase.BOOT
var _menu_left: float = 0.0
var _orbit_sign: float = 1.0
var _orbit_left: float = 0.0


func _init(main: Node) -> void:
	_stage = main.get_node("FlightStage") as FlightStage
	_run = main.get_node("Run") as RunDirector
	if Events.flow.game_state_changed.connect(_on_game_state_changed) != OK:
		push_error("Autopilot: could not hear the Game State")


func _exit_tree() -> void:
	release_all()


func _physics_process(delta: float) -> void:
	flown += delta
	_act(delta)
	ticked.emit()


func _act(delta: float) -> void:
	if GameState.is_play(_phase):
		_fly(delta)
		return
	release_all()
	_menu_left -= delta
	if _menu_left <= 0.0 and _phase != GameState.Phase.SCOREBOARD:
		_menu_left = MENU_PRESS_EVERY
		press_key(KEY_ENTER)


## Lets go of every flight action.
func release_all() -> void:
	for action: StringName in InputBindings.ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)


## One full key press (down, then up), as a player would make it.
static func press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


func _fly(delta: float) -> void:
	var mech: PlayerMech = _stage.player()
	var at: Vector3 = mech.global_position
	var target: Vector3 = Vector3.INF
	var boss: Boss = _run.arena().boss()
	var stand_off: float = STAND_OFF
	if mode != Mode.RAM and boss != null and boss.state() == Boss.State.FIGHTING:
		target = boss.weak_point()
		stand_off = BOSS_STAND_OFF
	else:
		target = _nearest_enemy(at)
	if mode == Mode.IDLE or target == Vector3.INF:
		_steer(Vector2.ZERO, Vector2.ZERO)
		return
	var gap: Vector3 = target - at
	gap.z = 0.0
	var toward: Vector2 = Vector2(gap.x, gap.y).normalized()
	if mode == Mode.RAM:
		_steer(toward, Vector2.ZERO)
		return
	_orbit_left -= delta
	if _orbit_left <= 0.0:
		_orbit_left = 3.0
		_orbit_sign = -_orbit_sign
	var closing: float = clampf((gap.length() - stand_off) / stand_off, -1.0, 1.0)
	var circle: Vector2 = toward.orthogonal() * _orbit_sign * ORBIT
	var move: Vector2 = (toward * closing + circle).limit_length(1.0)
	var tuning: MechTuning = mech.tuning
	var aim3: Vector3 = FiringSolution.arc(at, target, tuning.shot_speed, tuning.shot_gravity)
	_steer(move, Vector2(aim3.x, aim3.y))


func _nearest_enemy(at: Vector3) -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_distance: float = INF
	for enemy: Enemy in _run.field().active_enemies():
		var distance: float = enemy.position.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = enemy.position + enemy.velocity * LEAD
	return best


## Holds the move and aim actions at these stick values (x right, y up).
func _steer(move: Vector2, aim: Vector2) -> void:
	_axis(InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT, move.x)
	_axis(InputBindings.MOVE_DOWN, InputBindings.MOVE_UP, move.y)
	_axis(InputBindings.AIM_LEFT, InputBindings.AIM_RIGHT, aim.x)
	_axis(InputBindings.AIM_DOWN, InputBindings.AIM_UP, aim.y)


static func _axis(negative: StringName, positive: StringName, value: float) -> void:
	if value > 0.0:
		Input.action_release(negative)
		Input.action_press(positive, value)
	elif value < 0.0:
		Input.action_release(positive)
		Input.action_press(negative, -value)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to
	_menu_left = MENU_PRESS_EVERY
