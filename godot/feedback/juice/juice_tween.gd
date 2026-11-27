class_name JuiceTween
extends RefCounted
## The small helper every short juice animation goes through (owner direction
## on #26: juice uses Godot's built-in Tween). Each call replaces the node's
## previous juice tween, so a pooled node never runs two at once. World juice
## runs in game time, so it slows down with slow-mo and hit-stop on purpose.


## A fresh tween bound to `node`, replacing `previous` (which may be null).
static func restart(node: Node, previous: Tween) -> Tween:
	if previous != null and previous.is_valid():
		previous.kill()
	var tween: Tween = node.create_tween()
	return tween


## Pop `node` up to `peak` scale and back to nothing over `seconds`.
static func pop(node: Node3D, previous: Tween, peak: float, seconds: float) -> Tween:
	var tween: Tween = restart(node, previous)
	node.scale = Vector3.ONE * peak * 0.4
	var _grow: PropertyTweener = (
		tween
		. tween_property(node, "scale", Vector3.ONE * peak, seconds * 0.3)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	var _shrink: PropertyTweener = (
		tween.tween_property(node, "scale", Vector3.ZERO, seconds * 0.7).set_ease(Tween.EASE_IN)
	)
	var _hide: CallbackTweener = tween.tween_callback(node.hide)
	return tween


## Float `label` up by `rise` while it fades out over `seconds`, then hide it.
static func rise_and_fade(label: Label3D, previous: Tween, rise: float, seconds: float) -> Tween:
	var tween: Tween = restart(label, previous).set_parallel(true)
	var _up: PropertyTweener = (
		tween
		. tween_property(label, "position:y", label.position.y + rise, seconds)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	var _fade: PropertyTweener = (
		tween.tween_property(label, "modulate:a", 0.0, seconds * 0.6).set_delay(seconds * 0.4)
	)
	var _out: CallbackTweener = tween.chain().tween_callback(label.hide)
	return tween
