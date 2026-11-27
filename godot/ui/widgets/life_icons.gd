class_name LifeIcons
extends Control
## The HUD's lives: one small side-on mech per life (the prototype's icon).
## A gained life pops in; a lost one blinks out.

const ICON_SPACING: float = 40.0
const ICON_SIZE: Vector2 = Vector2(36.0, 36.0)
const MAX_SHOWN: int = 9
const BODY_COLOR: Color = Color(0.75, 0.9, 1.0)
const WING_COLOR: Color = Color(0.3, 0.8, 1.0)
const EYE_COLOR: Color = Color(1.0, 0.2, 0.2)
const POP_AMOUNT: float = 0.35

var _lives: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ICON_SPACING * 3.0, ICON_SIZE.y)


## The number of lives shown.
func lives() -> int:
	return _lives


## Shows `count` lives, popping when it grows.
func show_lives(count: int) -> void:
	var grew: bool = count > _lives
	_lives = maxi(count, 0)
	custom_minimum_size = Vector2(ICON_SPACING * maxf(3.0, mini(_lives, MAX_SHOWN)), ICON_SIZE.y)
	queue_redraw()
	if grew:
		TweenFx.punch(self, POP_AMOUNT)


func _draw() -> void:
	for i: int in mini(_lives, MAX_SHOWN):
		_draw_icon(Vector2(ICON_SPACING * (i + 0.5), size.y * 0.5 + 4.0))


func _draw_icon(at: Vector2) -> void:
	draw_colored_polygon(
		PackedVector2Array([at + Vector2(-2, -4), at + Vector2(-16, -18), at + Vector2(-12, -2)]),
		WING_COLOR
	)
	draw_rect(Rect2(at + Vector2(-6, -8), Vector2(12, 12)), BODY_COLOR)
	draw_rect(Rect2(at + Vector2(-4, -15), Vector2(8, 6)), BODY_COLOR)
	draw_rect(Rect2(at + Vector2(-5, 4), Vector2(4, 10)), BODY_COLOR)
	draw_rect(Rect2(at + Vector2(1, 4), Vector2(4, 10)), BODY_COLOR)
	draw_rect(Rect2(at + Vector2(2, -13), Vector2(2, 2)), EYE_COLOR)
