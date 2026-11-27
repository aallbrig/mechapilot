extends RefCounted
## PROTOTYPE juice helpers on Godot's built-in Tween (no addon). Every tween ignores
## Engine.time_scale so hit-stop and slow-mo never freeze the UI.


static func _tween(node: Node) -> Tween:
	return node.create_tween().set_ignore_time_scale(true)


## Scale up from `from` with an overshoot.
static func pop(
	node: CanvasItem, from: float = 0.2, dur: float = 0.45, delay: float = 0.0
) -> Tween:
	node.set("scale", Vector2.ONE * from)
	var tw := _tween(node)
	(
		tw
		. tween_property(node, "scale", Vector2.ONE, dur)
		. set_delay(delay)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	return tw


## Jump to 1 + amount, then spring back elastically.
static func punch_scale(node: CanvasItem, amount: float = 0.25, dur: float = 0.35) -> Tween:
	node.set("scale", Vector2.ONE * (1.0 + amount))
	var tw := _tween(node)
	tw.tween_property(node, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)
	return tw


## Tween scale to a value (hover and press states).
static func scale_to(node: CanvasItem, to: float, dur: float = 0.12) -> Tween:
	var tw := _tween(node)
	tw.tween_property(node, "scale", Vector2.ONE * to, dur).set_trans(Tween.TRANS_QUAD)
	return tw


## Decaying random jitter around the current position.
static func shake(node: Control, strength: float = 12.0, dur: float = 0.3) -> Tween:
	var base := node.position
	var tw := _tween(node)
	var steps := 6
	for i in steps:
		var k := 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k
		tw.tween_property(node, "position", base + off, dur / float(steps + 1))
	tw.tween_property(node, "position", base, dur / float(steps + 1))
	return tw


## Slide from position + offset to the current position while fading in.
static func slide_in(node: Control, offset: Vector2, delay: float = 0.0, dur: float = 0.5) -> Tween:
	var target := node.position
	node.position = target + offset
	node.modulate.a = 0.0
	var tw := _tween(node).set_parallel(true)
	(
		tw
		. tween_property(node, "position", target, dur)
		. set_delay(delay)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tw.tween_property(node, "modulate:a", 1.0, dur * 0.6).set_delay(delay)
	return tw


static func fade(node: CanvasItem, to: float, dur: float = 0.3, delay: float = 0.0) -> Tween:
	var tw := _tween(node)
	tw.tween_property(node, "modulate:a", to, dur).set_delay(delay)
	return tw
