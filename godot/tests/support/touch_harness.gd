class_name TouchHarness
extends RefCounted
## Test support for the touch controls (#25): a private Events bus, a
## PlayerInput, the TouchControls on a 1000x600 screen, and a player mech (no
## shot spread) with a camera rig, so a test can synthesize InputEventScreenTouch
## and InputEventScreenDrag on a controlled clock and count the shots that leave
## the muzzle. The mech is linked to the bus by the game's PlayerBusLink. The
## suite adds `holder` to its tree and calls dispose() at the end.

const TICK: float = 1.0 / 60.0
const START: float = 10.0
const SCREEN: Vector2 = Vector2(1000.0, 600.0)
## A touch index no test uses, for device switches.
const UNUSED_FINGER: int = 9

var holder: Node = Node.new()
var bus: EventBus = EventBus.new()
var input: PlayerInput = PlayerInput.new()
var controls: TouchControls = TouchControls.new()
var mech: PlayerMech = PlayerMech.new()
var rig: CameraRig = CameraRig.new()
var link: PlayerBusLink = PlayerBusLink.new()
## The direction of every shot fired, in order.
var shots: Array[Vector3] = []
## How many times pause_requested was announced on `bus`.
var pauses: int = 0
var now: float = START


func _init() -> void:
	mech.tuning = MechTuning.new()
	mech.tuning.shot_spread = 0.0
	mech.rng.seed = 7
	mech.input = input
	mech.view = rig
	holder.add_child(input)
	holder.add_child(controls)
	holder.add_child(rig)
	holder.add_child(mech)
	holder.add_child(link)
	controls.size = SCREEN
	link.link(bus, mech, input)
	Subscriptions.require_ok(
		"TouchHarness",
		[mech.fired.connect(_on_fired), bus.flow.pause_requested.connect(_on_pause_requested)]
	)


## Call once the suite has added `holder` to its tree: centres the camera on the mech.
func settle() -> void:
	rig.snap_to(mech.position)


## Frees every node and the bus. Call once at the end of every test.
func dispose() -> void:
	holder.free()
	bus.free()


## Attach the controls to `on_bus` (this harness's bus unless given), on a touch
## screen unless told otherwise. On a touch screen the last-used device is touch,
## as after the Boot screen's tap.
func attach(touch_screen: bool = true, on_bus: EventBus = null) -> void:
	controls.attach(bus if on_bus == null else on_bus, input, touch_screen)
	if touch_screen:
		use_touch()


## The player touches the screen (PlayerInput notices; no touch reaches the controls).
func use_touch() -> void:
	input.handle_event(_touch(UNUSED_FINGER, Vector2.ZERO, false), now)


## The player uses a real mouse (a move past the device slop).
func use_mouse() -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.relative = Vector2(DeviceDetector.MOUSE_SLOP * 4.0, 0.0)
	input.handle_event(move, now + DeviceDetector.TOUCH_MOUSE_GRACE)


## The player presses a key.
func use_keyboard() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_UP
	key.pressed = true
	input.handle_event(key, now)


## The player presses a gamepad button.
func use_gamepad() -> void:
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	input.handle_event(button, now)


## A left mouse click (press, then release) at `at` from `device` (a real mouse
## unless told otherwise), fed as the engine does: PlayerInput first.
func click(at: Vector2, device: int = 0) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.pressed = pressed
		ev.device = device
		input.handle_event(ev, now + DeviceDetector.TOUCH_MOUSE_GRACE)
		controls.handle_event(ev, now)


## Attach the controls and enter play (Skirmish).
func start(touch_screen: bool = true) -> void:
	attach(touch_screen)
	bus.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.SKIRMISH)


func press(index: int, at: Vector2) -> void:
	controls.handle_event(_touch(index, at, true), now)


func release(index: int, at: Vector2) -> void:
	controls.handle_event(_touch(index, at, false), now)


## A quick tap: down and up at `at` in the same instant.
func tap(index: int, at: Vector2) -> void:
	press(index, at)
	release(index, at)


## The OS took the touch away (a system gesture): released without a tap.
func cancel(index: int, at: Vector2) -> void:
	var ev: InputEventScreenTouch = _touch(index, at, false)
	ev.canceled = true
	controls.handle_event(ev, now)


func drag(index: int, to: Vector2) -> void:
	var ev: InputEventScreenDrag = InputEventScreenDrag.new()
	ev.index = index
	ev.position = to
	controls.handle_event(ev, now)


## Run the game for `seconds` in fixed ticks: the controls see the clock, and the
## mech reads the intent and flies.
func fly(seconds: float) -> void:
	var left: float = seconds
	while left > 1e-6:
		now += TICK
		left -= TICK
		controls.update(now)
		mech.tick(TICK, input.read_intent())


## The last shot's direction (zero when nothing fired).
func last_shot() -> Vector3:
	return shots[shots.size() - 1] if not shots.is_empty() else Vector3.ZERO


func _touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var ev: InputEventScreenTouch = InputEventScreenTouch.new()
	ev.index = index
	ev.position = at
	ev.pressed = pressed
	return ev


func _on_fired(_origin: Vector3, direction: Vector3) -> void:
	shots.append(direction)


func _on_pause_requested() -> void:
	pauses += 1
