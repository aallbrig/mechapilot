class_name TweenFx
extends RefCounted
## Juice on Godot's built-in Tween, ported from the LAN feel prototype
## (prototype/lan-feel/tween_fx.gd). Every tween ignores Engine.time_scale, so
## hit-stop and slow-mo never freeze the UI, and runs while the tree is paused.
##
## Reduced motion (#73 Settings): when `reduced_motion` is on, movement and
## scaling jump straight to their end state, and counters finish at once. Fades
## still run, briefly, because they do not move anything.

const HOVER_SCALE: float = 1.06
const PRESS_SCALE: float = 0.92
const HOVER_TIME: float = 0.12
const PRESS_TIME: float = 0.06
const POP_FROM: float = 0.6
const POP_TIME: float = 0.4
const PUNCH_AMOUNT: float = 0.2
const PUNCH_TIME: float = 0.3
const SHAKE_STEPS: int = 6
const SLIDE_TIME: float = 0.45
const FADE_SHARE: float = 0.6
const REDUCED_FADE_TIME: float = 0.1

## Set from GameSettings.reduced_motion by the UI root.
static var reduced_motion: bool = false
## The running scale tween of each control (by instance id): a new scale
## effect replaces the old one, so a hover never fights an entrance pop.
static var _scale_tweens: Dictionary[int, Tween] = {}


## A tween bound to `node` that ignores time scale and runs while paused.
static func make(node: Node) -> Tween:
	return node.create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


## Scale up from `from` to 1 with an overshoot, after `delay` seconds.
static func pop(
	control: Control, from: float = POP_FROM, duration: float = POP_TIME, delay: float = 0.0
) -> void:
	_center_pivot(control)
	if reduced_motion:
		_scale_tween(control).kill()
		control.scale = Vector2.ONE
		return
	control.scale = Vector2.ONE * from
	var tween: Tween = _scale_tween(control)
	var _step: PropertyTweener = (
		tween
		. tween_property(control, "scale", Vector2.ONE, duration)
		. set_delay(delay)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


## Jump to 1 + amount, then spring back elastically.
static func punch(
	control: Control, amount: float = PUNCH_AMOUNT, duration: float = PUNCH_TIME
) -> void:
	_center_pivot(control)
	if reduced_motion:
		_scale_tween(control).kill()
		control.scale = Vector2.ONE
		return
	control.scale = Vector2.ONE * (1.0 + amount)
	var tween: Tween = _scale_tween(control)
	var _step: PropertyTweener = (
		tween
		. tween_property(control, "scale", Vector2.ONE, duration)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)


## Ease the scale to `to` (hover, focus and press states).
static func scale_to(control: Control, to: float, duration: float = HOVER_TIME) -> void:
	_center_pivot(control)
	if reduced_motion:
		_scale_tween(control).kill()
		control.scale = Vector2.ONE
		return
	var tween: Tween = _scale_tween(control)
	var _step: PropertyTweener = (
		tween
		. tween_property(control, "scale", Vector2.ONE * to, duration)
		. set_trans(Tween.TRANS_QUAD)
	)


## A decaying side-to-side jitter around the current position. Only for
## controls that are not laid out by a container (a container would undo it).
static func shake(control: Control, strength: float, duration: float) -> void:
	if reduced_motion:
		return
	var base: Vector2 = control.position
	var tween: Tween = make(control)
	var step_time: float = duration / float(SHAKE_STEPS + 1)
	for i: int in SHAKE_STEPS:
		var falloff: float = 1.0 - float(i) / float(SHAKE_STEPS)
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var offset: Vector2 = Vector2(side, side * 0.5 * (1.0 - 2.0 * (i % 3))) * strength * falloff
		var _jitter: PropertyTweener = tween.tween_property(
			control, "position", base + offset, step_time
		)
	var _home: PropertyTweener = tween.tween_property(control, "position", base, step_time)


## Slide from `position + offset` back to the current position while fading in.
static func slide_in(
	control: Control, offset: Vector2, delay: float = 0.0, duration: float = SLIDE_TIME
) -> void:
	var target: Vector2 = control.position
	if reduced_motion:
		fade_in(control, REDUCED_FADE_TIME)
		return
	control.position = target + offset
	control.modulate.a = 0.0
	var tween: Tween = make(control).set_parallel(true)
	var _move: PropertyTweener = (
		tween
		. tween_property(control, "position", target, duration)
		. set_delay(delay)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	var _fade: PropertyTweener = (
		tween.tween_property(control, "modulate:a", 1.0, duration * FADE_SHARE).set_delay(delay)
	)


## Fade from transparent to opaque.
static func fade_in(control: CanvasItem, duration: float, delay: float = 0.0) -> void:
	control.modulate.a = 0.0
	fade(control, 1.0, duration, delay)


## Fade the alpha to `to`.
static func fade(control: CanvasItem, to: float, duration: float, delay: float = 0.0) -> void:
	var tween: Tween = make(control)
	var length: float = minf(duration, REDUCED_FADE_TIME) if reduced_motion else duration
	var _step: PropertyTweener = tween.tween_property(control, "modulate:a", to, length).set_delay(
		delay
	)


## Pulse the scale between 1 and 1 + amount forever (until the node is freed or
## the returned tween is killed). With reduced motion, nothing pulses.
static func pulse(control: Control, amount: float, period: float) -> Tween:
	_center_pivot(control)
	var tween: Tween = _scale_tween(control).set_loops()
	var half: float = period * 0.5
	if reduced_motion:
		var _hold: IntervalTweener = tween.tween_interval(period)
		return tween
	var _up: PropertyTweener = (
		tween
		. tween_property(control, "scale", Vector2.ONE * (1.0 + amount), half)
		. set_trans(Tween.TRANS_SINE)
	)
	var _down: PropertyTweener = (
		tween.tween_property(control, "scale", Vector2.ONE, half).set_trans(Tween.TRANS_SINE)
	)
	return tween


## Count from 0 to 1 over `duration`, calling `step(t)` on the way and `done()`
## at the end. With reduced motion it reaches the end on the next frame.
static func count(node: Node, duration: float, step: Callable, done: Callable) -> Tween:
	var length: float = 0.0 if reduced_motion else maxf(duration, 0.0)
	var tween: Tween = make(node)
	var _run: MethodTweener = tween.tween_method(step, 0.0, 1.0, length)
	var _end: CallbackTweener = tween.tween_callback(done)
	return tween


## A fresh tween for `control`'s scale, killing the one it replaces.
static func _scale_tween(control: Control) -> Tween:
	var id: int = control.get_instance_id()
	if _scale_tweens.has(id) and _scale_tweens[id].is_valid():
		_scale_tweens[id].kill()
	for stale: int in _scale_tweens.keys():
		if not _scale_tweens[stale].is_valid():
			var _gone: bool = _scale_tweens.erase(stale)
	var tween: Tween = make(control)
	_scale_tweens[id] = tween
	return tween


## Keep a control's pivot at its centre, so scale juice grows from the middle.
static func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
