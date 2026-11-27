class_name TouchHarness
extends RefCounted
## Test support for the touch controls (#25): a private Events bus, a
## PlayerInput, the TouchControls on a 1000x600 screen, and a player mech (no
## shot spread) with a camera rig, so a test can synthesize InputEventScreenTouch
## and InputEventScreenDrag on a controlled clock and count the shots that leave
## the muzzle. The suite adds `holder` to its tree and calls dispose() at the end.

const TICK: float = 1.0 / 60.0
const START: float = 10.0
const SCREEN: Vector2 = Vector2(1000.0, 600.0)

var holder: Node = Node.new()
var bus: EventBus = EventBus.new()
var input: PlayerInput = PlayerInput.new()
var controls: TouchControls = TouchControls.new()
var mech: PlayerMech = PlayerMech.new()
var rig: CameraRig = CameraRig.new()
## The direction of every shot fired, in order.
var shots: Array[Vector3] = []
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
	controls.size = SCREEN
	Subscriptions.require_ok("TouchHarness", [mech.fired.connect(_on_fired)])


## Call once the suite has added `holder` to its tree: centres the camera on the mech.
func settle() -> void:
	rig.snap_to(mech.position)


## Frees every node and the bus. Call once at the end of every test.
func dispose() -> void:
	holder.free()
	bus.free()


## Attach the controls to `on_bus` (this harness's bus unless given), on a touch
## screen unless told otherwise.
func attach(touch_screen: bool = true, on_bus: EventBus = null) -> void:
	controls.attach(bus if on_bus == null else on_bus, input, touch_screen)


## Attach the controls and enter play (Skirmish).
func start(touch_screen: bool = true) -> void:
	attach(touch_screen)
	bus.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.SKIRMISH)


func press(index: int, at: Vector2) -> void:
	controls.handle_event(_touch(index, at, true), now)


func release(index: int, at: Vector2) -> void:
	controls.handle_event(_touch(index, at, false), now)


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
