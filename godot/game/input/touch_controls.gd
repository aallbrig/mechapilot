class_name TouchControls
extends Control
## The on-screen touch controls (#25): twin virtual sticks and a pause button,
## drawn over the flight. The rules live in TouchSticks; this node routes the
## screen events to them, feeds PlayerInput's touch seam (set_touch_sticks and
## request_tap_shot), and draws:
##
## - the sticks only while a finger holds them (the aim stick once a touch is a
##   hold, never during a tap), at the Settings touch stick opacity, with a pop
##   when they open and a hot knob while the aim stick fires;
## - the pause button in the top-right corner, sized for a thumb. A touch that
##   starts on it (or within PAUSE_GUARD of it) is the button's and never a
##   stick or a shot; lifting it on the button announces pause_requested.
##
## Everything shows only on a touch screen and only in play (Level Intro to Boss
## Fight). Leaving play drops every touch and zeroes the sticks, so no finger
## keeps steering after Pause or Game Over. The node reads screen events in
## _unhandled_input, so a touch on any UI control (a HUD button) never steers.
## It never takes mouse input itself: menus get taps as emulated clicks.
## main.tscn anchors it to the full screen; the halves split at its centre.

## The pause button: its side (px), its distance from the screen edges, and the
## extra band around it that still belongs to it.
const PAUSE_SIZE: float = 72.0
const PAUSE_MARGIN: float = 24.0
const PAUSE_GUARD: float = 16.0
const PAUSE_BAR_SIZE: Vector2 = Vector2(10.0, 32.0)
const PAUSE_BAR_GAP: float = 10.0
const PAUSE_FILL: Color = Color(0.05, 0.08, 0.16, 0.55)
const PAUSE_PRESSED_FILL: Color = Color(0.25, 0.55, 1.0, 0.75)
const PAUSE_INK: Color = Color(0.92, 0.97, 1.0, 0.9)
const PAUSE_PRESS_SCALE: float = 0.9
## Stick drawing: the base ring follows TouchSticks.STICK_RANGE.
const BASE_FILL: Color = Color(0.05, 0.08, 0.16, 0.45)
const BASE_RING: Color = Color(0.92, 0.97, 1.0, 0.8)
const BASE_RING_WIDTH: float = 3.0
const KNOB_RADIUS: float = 28.0
const KNOB_COLOR: Color = Color(0.92, 0.97, 1.0, 0.9)
const KNOB_FIRING_COLOR: Color = Color(1.0, 0.55, 0.2, 0.95)
const ARC_POINTS: int = 48
## Juice: a stick opens with a pop that settles at POP_SETTLE per second.
const OPEN_POP: float = 0.35
const POP_SETTLE: float = 10.0

var _sticks: TouchSticks = TouchSticks.new()
var _input: PlayerInput
var _touch_screen: bool = false
var _in_play: bool = false
var _bus: EventBus
var _opacity: float = GameSettings.DEFAULT_TOUCH_STICK_OPACITY
var _pause_finger: int = TouchSticks.NO_TOUCH
var _pause_pressed: bool = false
var _move_pop: float = 0.0
var _aim_pop: float = 0.0
var _move_was_shown: bool = false
var _aim_was_shown: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false


## Wire the controls to `bus` and `input`. `touch_screen`: the device has one
## (DisplayServer.is_touchscreen_available() in the game); without one the
## controls stay hidden and ignore every event.
func attach(bus: EventBus, input: PlayerInput, touch_screen: bool) -> void:
	_bus = bus
	_input = input
	_touch_screen = touch_screen
	(
		Subscriptions
		. require_ok(
			"TouchControls",
			[
				bus.flow.game_state_changed.connect(_on_game_state_changed),
				bus.profile.settings_changed.connect(_on_settings_changed),
			]
		)
	)
	_refresh_visibility()


func _unhandled_input(event: InputEvent) -> void:
	handle_event(event, Time.get_ticks_usec() / PlayerInput.USEC_PER_SECOND)


func _process(delta: float) -> void:
	if not _is_active():
		return
	update(Time.get_ticks_usec() / PlayerInput.USEC_PER_SECOND)
	var settle: float = exp(-POP_SETTLE * delta)
	_move_pop *= settle
	_aim_pop *= settle
	queue_redraw()


## Feed one screen event observed at `now` seconds (the engine calls this
## through _unhandled_input). Every other event is ignored.
func handle_event(event: InputEvent, now: float) -> void:
	if not _is_active():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var at: Vector2 = _local(touch.position)
		if touch.pressed:
			_on_press(touch.index, at, now)
		else:
			_on_release(touch.index, at, now, touch.canceled)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		var to: Vector2 = _local(drag.position)
		if drag.index == _pause_finger:
			_pause_pressed = _pause_hit_rect().has_point(to)
		else:
			_sticks.drag(drag.index, to, now)
	_push()


## Let time pass to `now` seconds: a held aim touch becomes the aim stick.
func update(now: float) -> void:
	if not _is_active():
		return
	_sticks.update(now)
	_push()


## The pause button, in this node's coordinates.
func pause_button_rect() -> Rect2:
	var side: Vector2 = Vector2(PAUSE_SIZE, PAUSE_SIZE)
	return Rect2(Vector2(size.x - PAUSE_MARGIN - PAUSE_SIZE, PAUSE_MARGIN), side)


func is_pause_button_shown() -> bool:
	return _is_active()


func is_move_stick_shown() -> bool:
	return _is_active() and _sticks.is_move_held()


func is_aim_stick_shown() -> bool:
	return _is_active() and _sticks.is_aim_holding()


## The sticks' opacity, from the player's settings.
func stick_opacity() -> float:
	return _opacity


func _draw() -> void:
	if not _is_active():
		return
	if is_move_stick_shown():
		_draw_stick(_sticks.move_stick(), _move_pop, false)
	if is_aim_stick_shown():
		var firing: bool = _sticks.aim().length() > PlayerInput.TOUCH_AIM_THRESHOLD
		_draw_stick(_sticks.aim_stick(), _aim_pop, firing)
	_draw_pause_button()


func _on_press(index: int, at: Vector2, now: float) -> void:
	if _sticks.is_tracking(index) or index == _pause_finger:
		return
	if _pause_finger == TouchSticks.NO_TOUCH and _pause_hit_rect().has_point(at):
		_pause_finger = index
		_pause_pressed = true
		return
	_sticks.split_x = size.x * 0.5
	_sticks.press(index, at, now)


func _on_release(index: int, at: Vector2, now: float, cancelled: bool) -> void:
	if index != _pause_finger:
		_sticks.release(index, at, now, cancelled)
		return
	var pressed: bool = _pause_pressed and not cancelled and _pause_hit_rect().has_point(at)
	_pause_finger = TouchSticks.NO_TOUCH
	_pause_pressed = false
	if pressed:
		_bus.flow.announce_pause_requested()


## Hand the sticks and any taps to PlayerInput, and start the open pops.
func _push() -> void:
	if _input == null:
		return
	_input.set_touch_sticks(_sticks.move(), _sticks.aim())
	for tap: Vector2 in _sticks.take_taps():
		_input.request_tap_shot(get_global_transform_with_canvas() * tap)
	var move_shown: bool = is_move_stick_shown()
	var aim_shown: bool = is_aim_stick_shown()
	if move_shown and not _move_was_shown:
		_move_pop = OPEN_POP
	if aim_shown and not _aim_was_shown:
		_aim_pop = OPEN_POP
	_move_was_shown = move_shown
	_aim_was_shown = aim_shown
	queue_redraw()


func _is_active() -> bool:
	return _touch_screen and _in_play and _input != null


func _refresh_visibility() -> void:
	visible = _is_active()
	if not _is_active():
		_sticks.reset()
		_pause_finger = TouchSticks.NO_TOUCH
		_pause_pressed = false
		_move_was_shown = false
		_aim_was_shown = false
		if _input != null:
			_input.set_touch_sticks(Vector2.ZERO, Vector2.ZERO)
	queue_redraw()


func _pause_hit_rect() -> Rect2:
	return pause_button_rect().grow(PAUSE_GUARD)


## A viewport point in this node's coordinates.
func _local(viewport_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_point


func _draw_stick(stick: TouchSticks.Stick, pop: float, firing: bool) -> void:
	var base: Color = BASE_FILL
	base.a *= _opacity
	var ring: Color = BASE_RING
	ring.a *= _opacity
	var knob: Color = KNOB_FIRING_COLOR if firing else KNOB_COLOR
	knob.a *= _opacity
	var radius: float = TouchSticks.STICK_RANGE * (1.0 + pop)
	draw_circle(stick.anchor, radius, base)
	draw_arc(stick.anchor, radius, 0.0, TAU, ARC_POINTS, ring, BASE_RING_WIDTH, true)
	draw_circle(stick.anchor + stick.offset(), KNOB_RADIUS * (1.0 + pop), knob)


func _draw_pause_button() -> void:
	var rect: Rect2 = pause_button_rect()
	var center: Vector2 = rect.get_center()
	var scale_now: float = PAUSE_PRESS_SCALE if _pause_pressed else 1.0
	var drawn: Rect2 = Rect2(center - rect.size * 0.5 * scale_now, rect.size * scale_now)
	draw_rect(drawn, PAUSE_PRESSED_FILL if _pause_pressed else PAUSE_FILL)
	draw_rect(drawn, PAUSE_INK, false, BASE_RING_WIDTH)
	var bar: Vector2 = PAUSE_BAR_SIZE * scale_now
	var gap: float = PAUSE_BAR_GAP * scale_now * 0.5
	draw_rect(Rect2(center + Vector2(-gap - bar.x, -bar.y * 0.5), bar), PAUSE_INK)
	draw_rect(Rect2(center + Vector2(gap, -bar.y * 0.5), bar), PAUSE_INK)


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_in_play = GameState.is_play(to)
	_refresh_visibility()


func _on_settings_changed(settings: GameSettings) -> void:
	_opacity = clampf(
		settings.touch_stick_opacity,
		GameSettings.MIN_TOUCH_STICK_OPACITY,
		GameSettings.MAX_TOUCH_STICK_OPACITY
	)
	queue_redraw()
