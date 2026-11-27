class_name ArrowButton
extends Button
## A button drawn as an up or down triangle (the initials picker's touch and
## mouse controls). It never takes keyboard focus: the picker itself does.

const SIZE: Vector2 = Vector2(96.0, 56.0)
const ARROW_HALF_WIDTH: float = 22.0
const ARROW_HALF_HEIGHT: float = 12.0
const ARROW_COLOR: Color = Color(0.92, 0.97, 1.0)

var _up: bool = true


func _init(points_up: bool) -> void:
	_up = points_up
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = SIZE
	tooltip_text = "Next letter" if points_up else "Previous letter"


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var tip: float = -1.0 if _up else 1.0
	var points: PackedVector2Array = [
		center + Vector2(0.0, ARROW_HALF_HEIGHT * tip),
		center + Vector2(ARROW_HALF_WIDTH, -ARROW_HALF_HEIGHT * tip),
		center + Vector2(-ARROW_HALF_WIDTH, -ARROW_HALF_HEIGHT * tip),
	]
	draw_colored_polygon(points, ARROW_COLOR)
