extends GdUnitTestSuite
## The assembled game in main.tscn (#84): the attract and flight cameras hand
## off with the Game State, the fight is wired to the stage's mech, and the
## rules' Repair Kit drops land in the sky. Driven through the Events autoload,
## as the screens and the game nodes drive it, and through real input
## (Input.parse_input_event, as the engine feeds it) for touch and mouse. Every
## store is in memory.

## Fighter kills reported, at most, while filling the Boss Gauge.
const KILL_LIMIT: int = 200
## Game seconds the game may take to reach a Game State before the test gives up.
## Every random decision in the game follows this seed.
const SEED: int = 8484
## Engine time runs this many times faster than the wall clock.
const TIME_FACTOR: float = 8.0
const STATE_LIMIT: float = 30.0
## Physics ticks that span at least two rendered frames at TIME_FACTOR (the
## engine runs up to 8 ticks a frame), so injected input is flushed and seen.
const INPUT_TICKS: int = 24
## Physics ticks for a screen's entrance to finish (2 game seconds).
const SETTLE_TICKS: int = 120
## Two window points for _calibrate (any two that differ on both axes).
const CALIBRATE_FROM: Vector2 = Vector2(10.0, 10.0)
const CALIBRATE_TO: Vector2 = Vector2(40.0, 30.0)

var _main: Main
var _phase: GameState.Phase = GameState.Phase.BOOT
var _drops: int = 0
var _shots_fired: int = 0
var _window_scale: Vector2 = Vector2.ONE
var _window_offset: Vector2 = Vector2.ZERO


func before_test() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Main
	_main.memory_stores = true
	_main.rng_seed = SEED
	_phase = GameState.Phase.BOOT
	_drops = 0
	_shots_fired = 0
	var subscribed: Array[int] = [
		Events.flow.game_state_changed.connect(_on_state),
		Events.player.repair_kit_dropped.connect(_on_drop),
		Events.player.player_fired.connect(_on_fired),
	]
	var _ok: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(subscribed.size())


func after_test() -> void:
	Events.flow.game_state_changed.disconnect(_on_state)
	Events.player.repair_kit_dropped.disconnect(_on_drop)
	Events.player.player_fired.disconnect(_on_fired)
	_main.free()


func _on_state(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to


func _on_drop(_position: Vector3) -> void:
	_drops += 1


func _on_fired(_origin: Vector3, _direction: Vector3) -> void:
	_shots_fired += 1


## Lets the game run `ticks` physics ticks (queued input is flushed first).
func _wait(clock: TickClock, ticks: int) -> void:
	for _tick: int in ticks:
		await clock.ticked


## Starts the game, scene runner and clock, and plays into Level 1's Skirmish.
func _start_skirmish() -> TickClock:
	var runner: GdUnitSceneRunner = scene_runner(_main)
	var _fast: GdUnitSceneRunner = runner.set_time_factor(TIME_FACTOR)
	var clock: TickClock = auto_free(TickClock.new())
	add_child(clock)
	Events.flow.announce_start_requested()
	Events.flow.announce_play_requested()
	await _reach(clock, GameState.Phase.SKIRMISH)
	return clock


## Learns how the engine maps window coordinates (what Input.parse_input_event
## takes) onto the viewport (what the game sees), from two real mouse moves
## read back through the player's aim point. Headless, the window is not the
## project's size, so the mapping is measured rather than assumed.
func _calibrate(clock: TickClock) -> void:
	var input: PlayerInput = _stage().player_input()
	var sent: Array[Vector2] = [CALIBRATE_FROM, CALIBRATE_TO]
	var seen: Array[Vector2] = []
	for at: Vector2 in sent:
		var move: InputEventMouseMotion = InputEventMouseMotion.new()
		move.position = at
		move.global_position = at
		move.relative = Vector2(DeviceDetector.MOUSE_SLOP * 4.0, 0.0)
		Input.parse_input_event(move)
		await _wait(clock, INPUT_TICKS)
		seen.append(input.read_intent().aim_point)
	var spread: Vector2 = seen[1] - seen[0]
	var measured: bool = absf(spread.x) > 0.0 and absf(spread.y) > 0.0
	var _calibrated: GdUnitAssert = (
		assert_bool(measured)
		. override_failure_message(
			"input calibration read %s for both mouse moves: the engine saw no movement" % [seen]
		)
		. is_true()
	)
	if not measured:
		return
	_window_scale = spread / (sent[1] - sent[0])
	_window_offset = seen[0] - sent[0] * _window_scale


## A point in `item`'s own space, in window coordinates (after _calibrate).
func _window_point(item: CanvasItem, local_point: Vector2) -> Vector2:
	var in_viewport: Vector2 = item.get_global_transform_with_canvas() * local_point
	return (in_viewport - _window_offset) / _window_scale


func _window_center(control: Control) -> Vector2:
	return _window_point(control, control.size * 0.5)


func _button(screen_name: StringName, text: String) -> Button:
	var ui: UiRoot = _main.get_node("Ui/UiRoot") as UiRoot
	for control: Control in ui.screen(screen_name).juiced_controls():
		if control is Button and (control as Button).text == text:
			return control as Button
	return null


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = index
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)


func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = index
	drag.position = to
	drag.relative = to - from
	Input.parse_input_event(drag)


## Runs the game until the Game State is `phase` (or the time limit).
func _reach(clock: TickClock, phase: GameState.Phase) -> void:
	var start: float = clock.elapsed
	while _phase != phase and clock.elapsed - start < STATE_LIMIT:
		await clock.ticked


func _stage() -> FlightStage:
	return _main.get_node("FlightStage") as FlightStage


func _run() -> RunDirector:
	return _main.get_node("Run") as RunDirector


## The attract mode's own camera (the Title's dogfight builds it).
func _attract_camera() -> Camera3D:
	for child: Node in _main.get_node("Attract").get_children():
		if child is Camera3D:
			return child as Camera3D
	return null


## True when `camera` is the one camera of the two that is current.
func _only_current(camera: Camera3D, other: Camera3D) -> bool:
	return camera.is_current() and not other.is_current()


func test_main_camera_hands_off_between_attract_and_flight() -> void:
	add_child(_main)
	var flight: Camera3D = _stage().camera_rig().camera()
	var attract: Camera3D = _attract_camera()
	var on_boot: bool = _only_current(attract, flight)
	Events.flow.announce_start_requested()
	var on_title: bool = _only_current(attract, flight)
	Events.flow.announce_play_requested()
	var in_play: bool = _only_current(flight, attract)
	Events.flow.announce_pause_requested()
	var paused: bool = _only_current(flight, attract)
	Events.flow.announce_quit_to_title_requested()
	var after_quit: bool = _only_current(attract, flight)
	Events.flow.announce_play_requested()
	var replay: bool = _only_current(flight, attract)
	var _boot: GdUnitAssert = assert_bool(on_boot).is_true()
	var _title: GdUnitAssert = assert_bool(on_title).is_true()
	var _play: GdUnitAssert = assert_bool(in_play).is_true()
	var _pause: GdUnitAssert = assert_bool(paused).is_true()
	var _quit: GdUnitAssert = assert_bool(after_quit).is_true()
	var _again: GdUnitAssert = assert_bool(replay).is_true()


func test_main_fights_the_stage_mech() -> void:
	add_child(_main)
	var player: PlayerMech = _stage().player()
	_stage().player().position = Vector3(3.0, -2.0, 0.0)
	var _target: GdUnitAssert = assert_vector(_run().target().position()).is_equal(
		Vector3(3.0, -2.0, 0.0)
	)
	var _alive: GdUnitAssert = assert_bool(_run().target().is_alive()).is_equal(player.is_alive())
	var _radius: GdUnitAssert = assert_float(_run().target().radius()).is_equal(
		player.contact_radius()
	)


func test_main_drops_repair_kits_in_the_sky() -> void:
	# The whole chain, from reported facts only: the gauge fills from shot
	# kills, the rules summon the boss, a reported hit defeats it, and the
	# spawn director's rule (a boss always drops a Repair Kit) puts one in the sky.
	var runner: GdUnitSceneRunner = scene_runner(_main)
	var _fast: GdUnitSceneRunner = runner.set_time_factor(TIME_FACTOR)
	var clock: TickClock = TickClock.new()
	add_child(clock)
	Events.flow.announce_start_requested()
	Events.flow.announce_play_requested()
	await _reach(clock, GameState.Phase.SKIRMISH)
	var kills: int = 0
	while _phase == GameState.Phase.SKIRMISH and kills < KILL_LIMIT:
		kills += 1
		Events.enemy.announce_enemy_destroyed(
			kills, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
		)
	await _reach(clock, GameState.Phase.BOSS_FIGHT)
	var kits_before: int = _stage().repair_kits().size()
	var drops_before: int = _drops
	Events.boss.announce_boss_hit(RunRules.BOSS_ATTACK_DAMAGE_MAX * 1000, Vector3.ZERO)
	var _cleared: GdUnitAssert = assert_int(_phase).is_equal(GameState.Phase.LEVEL_CLEAR)
	var _decided: GdUnitAssert = assert_int(_drops - drops_before).is_equal(1)
	clock.queue_free()
	var _in_sky: GdUnitAssert = assert_int(_stage().repair_kits().size()).is_equal(kits_before + 1)


func test_menu_button_accepts_a_real_tap() -> void:
	_main.touch_screen = true
	var runner: GdUnitSceneRunner = scene_runner(_main)
	var _fast: GdUnitSceneRunner = runner.set_time_factor(TIME_FACTOR)
	var clock: TickClock = auto_free(TickClock.new())
	add_child(clock)
	await _calibrate(clock)
	var ui: UiRoot = _main.get_node("Ui/UiRoot") as UiRoot
	var screen_middle: Vector2 = _window_center(ui)
	_touch(0, screen_middle, true)
	_touch(0, screen_middle, false)
	await _reach(clock, GameState.Phase.TITLE)
	var on_title: GameState.Phase = _phase
	var play: Button = _button(&"Title", "PLAY")
	# Past the Title's slide-in, so PLAY sits where it stays.
	await _wait(clock, SETTLE_TICKS)
	var on_play: Vector2 = _window_center(play)
	# A finger down and up on PLAY: the engine turns it into a click.
	_touch(0, on_play, true)
	await _wait(clock, INPUT_TICKS)
	_touch(0, on_play, false)
	await _reach(clock, GameState.Phase.LEVEL_INTRO)
	var _title: GdUnitAssert = assert_int(on_title).is_equal(GameState.Phase.TITLE)
	var _played: GdUnitAssert = assert_int(_phase).is_equal(GameState.Phase.LEVEL_INTRO)


func test_touch_on_hud_control_does_not_steer() -> void:
	_main.touch_screen = true
	var clock: TickClock = await _start_skirmish()
	var input: PlayerInput = _stage().player_input()
	await _calibrate(clock)
	Events.flow.announce_pause_requested()
	await _wait(clock, INPUT_TICKS)
	var resume: Button = _button(&"Pause", "RESUME")
	var on_button: Vector2 = _window_center(resume)
	var stick: Vector2 = Vector2(TouchSticks.STICK_RANGE, 0.0)
	# A finger lands on RESUME and slides: the menu's, never a stick's.
	_touch(0, on_button, true)
	_drag(0, on_button, on_button + stick)
	await _wait(clock, INPUT_TICKS)
	var paused_move: Vector2 = input.read_intent().move
	# The game resumes while that finger is still down, and it keeps sliding.
	Autopilot.press_key(KEY_ESCAPE)
	await _reach(clock, GameState.Phase.SKIRMISH)
	var shots_before: int = _shots_fired
	_drag(0, on_button + stick, on_button + stick * 2.0)
	await _wait(clock, INPUT_TICKS)
	var resumed: PilotIntent = input.read_intent()
	_touch(0, on_button + stick * 2.0, false)
	await _wait(clock, INPUT_TICKS)
	var _resumed: GdUnitAssert = assert_int(_phase).is_equal(GameState.Phase.SKIRMISH)
	var _still_paused: GdUnitAssert = assert_vector(paused_move).is_equal(Vector2.ZERO)
	var _no_steer: GdUnitAssert = assert_vector(resumed.move).is_equal(Vector2.ZERO)
	var _no_shot: GdUnitAssert = assert_int(_shots_fired).is_equal(shots_before)


func test_mouse_click_on_pause_fires_no_shot() -> void:
	var clock: TickClock = await _start_skirmish()
	await _calibrate(clock)
	var controls: TouchControls = _main.get_node("TouchControls") as TouchControls
	var on_pause: Vector2 = _window_point(controls, controls.pause_button_rect().get_center())
	# A real mouse: it moves past the slop, onto the Pause button.
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = on_pause
	move.global_position = on_pause
	move.relative = Vector2(DeviceDetector.MOUSE_SLOP * 4.0, 0.0)
	Input.parse_input_event(move)
	await _wait(clock, INPUT_TICKS)
	var shown: bool = controls.is_pause_button_shown()
	var shots_before: int = _shots_fired
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = on_pause
		click.global_position = on_pause
		click.pressed = pressed
		Input.parse_input_event(click)
		await _wait(clock, INPUT_TICKS)
	await _wait(clock, INPUT_TICKS)
	var _for_mouse: GdUnitAssert = assert_bool(shown).is_true()
	var _paused: GdUnitAssert = assert_int(_phase).is_equal(GameState.Phase.PAUSED)
	var _no_shot: GdUnitAssert = assert_int(_shots_fired).is_equal(shots_before)


func test_main_has_one_world_environment() -> void:
	add_child(_main)
	var found: Array[WorldEnvironment] = []
	var stack: Array[Node] = [_main]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is WorldEnvironment:
			found.append(node as WorldEnvironment)
		stack.append_array(node.get_children())
	var stage_sky: WorldEnvironment = _stage().sky().world_environment()
	var attract_view: Environment = _attract_camera().environment
	var _one: GdUnitAssert = assert_int(found.size()).is_equal(1)
	var _the_stage_sky: GdUnitAssert = (
		assert_object(found[0] if found.size() == 1 else null).is_same(stage_sky)
	)
	# The Title still shows its own sky, through the attract camera.
	var _attract_sky: GdUnitAssert = assert_object(attract_view).is_not_null()
