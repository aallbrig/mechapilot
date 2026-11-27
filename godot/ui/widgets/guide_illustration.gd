class_name GuideIllustration
extends Control
## The small drawing on each How to Play page: two sticks, a mech with a flight
## path, a dropping shot arc, an Armor bar and a Repair Kit, life icons with a
## 1UP, a combo counter, a filling Boss Gauge, or the six Levels climbing to
## orbit. Drawn in code, so it scales cleanly.

const SIZE: Vector2 = Vector2(320.0, 120.0)
const MECH_COLOR: Color = Color(0.75, 0.9, 1.0)
const ACCENT: Color = Color(1.0, 0.85, 0.2)
const ARMOR_COLOR: Color = Color(0.35, 1.0, 0.55)
const DANGER: Color = Color(1.0, 0.25, 0.3)
const LINE_WIDTH: float = 4.0
const ARC_POINTS: int = 16
const DASH: float = 10.0
## CONTROLS: the two sticks' spacing, size and tilt.
const STICK_SPREAD: float = 110.0
const STICK_RADIUS: float = 30.0
const STICK_TILT: float = 10.0
## LEVELS: one dot per Level, coloured like its sky, climbing in steps.
const LEVEL_STEP: Vector2 = Vector2(48.0, 14.0)
const LEVEL_DOT: float = 13.0
const LEVEL_SKIES: Array[Color] = [
	Color(1.0, 0.7, 0.45),
	Color(0.45, 0.5, 0.6),
	Color(1.0, 0.45, 0.3),
	Color(0.1, 0.12, 0.35),
	Color(0.35, 0.6, 1.0),
	Color(0.05, 0.02, 0.15),
]

var _topic: GuidePages.Topic = GuidePages.Topic.MOVING


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Draws the illustration for `topic`.
func show_topic(topic: GuidePages.Topic) -> void:
	_topic = topic
	queue_redraw()


## The topic drawn.
func shown_topic() -> GuidePages.Topic:
	return _topic


func _draw() -> void:
	var middle: Vector2 = size * 0.5
	match _topic:
		GuidePages.Topic.CONTROLS:
			# Two sticks: one flies, the other aims.
			for side: float in [-1.0, 1.0]:
				var stick: Vector2 = middle + Vector2(side * STICK_SPREAD, 0.0)
				draw_arc(stick, STICK_RADIUS, 0.0, TAU, 32, MECH_COLOR, LINE_WIDTH)
				draw_circle(
					stick + Vector2(side * STICK_TILT, -STICK_TILT), STICK_RADIUS * 0.4, ACCENT
				)
			_mech(middle + Vector2(0.0, 20.0))
		GuidePages.Topic.MOVING:
			_mech(middle + Vector2(-90.0, 20.0))
			draw_dashed_line(
				middle + Vector2(-60.0, 10.0),
				middle + Vector2(110.0, -40.0),
				ACCENT,
				LINE_WIDTH,
				DASH
			)
		GuidePages.Topic.AIMING:
			_mech(middle + Vector2(-120.0, 30.0))
			_arc(middle + Vector2(-95.0, 15.0), Vector2(230.0, -200.0))
			_enemy(middle + Vector2(120.0, 10.0))
		GuidePages.Topic.ARMOR:
			_bar(Rect2(middle + Vector2(-140.0, -40.0), Vector2(160.0, 22.0)), 0.6, ARMOR_COLOR)
			_cross(middle + Vector2(90.0, 10.0))
		GuidePages.Topic.LIVES:
			for i: int in 4:
				_mech(middle + Vector2(-110.0 + i * 50.0, 20.0))
			draw_string(
				get_theme_default_font(),
				middle + Vector2(70.0, -30.0),
				"1UP",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				32,
				ARMOR_COLOR
			)
		GuidePages.Topic.BOSSES:
			_bar(Rect2(middle + Vector2(-140.0, -50.0), Vector2(280.0, 22.0)), 1.0, ACCENT)
			draw_circle(middle + Vector2(0.0, 30.0), 30.0, DANGER)
			draw_arc(middle + Vector2(0.0, 30.0), 42.0, 0.0, TAU, 32, ACCENT, LINE_WIDTH)
		GuidePages.Topic.COMBOS:
			for i: int in 3:
				_enemy(middle + Vector2(-110.0 + i * 60.0, 20.0))
			draw_string(
				get_theme_default_font(),
				middle + Vector2(70.0, 0.0),
				"x8",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				48,
				ACCENT
			)
		GuidePages.Topic.LEVELS:
			# Six skies climbing from dawn to orbit, the boss waiting at the top.
			var step: Vector2 = Vector2(LEVEL_STEP.x, -LEVEL_STEP.y)
			var first: Vector2 = middle + Vector2(-2.5 * LEVEL_STEP.x, 2.5 * LEVEL_STEP.y)
			for i: int in LEVEL_SKIES.size():
				var at: Vector2 = first + step * i
				if i > 0:
					draw_dashed_line(at - step, at, MECH_COLOR, LINE_WIDTH * 0.5, DASH * 0.5)
				draw_circle(at, LEVEL_DOT, LEVEL_SKIES[i])
				draw_arc(at, LEVEL_DOT, 0.0, TAU, 24, Color.WHITE, 2.0)
			draw_arc(
				first + step * (LEVEL_SKIES.size() - 1),
				LEVEL_DOT * 1.6,
				0.0,
				TAU,
				32,
				DANGER,
				LINE_WIDTH
			)


func _mech(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-10.0, -14.0), Vector2(20.0, 22.0)), MECH_COLOR)
	draw_rect(Rect2(at + Vector2(-7.0, -26.0), Vector2(14.0, 10.0)), MECH_COLOR)
	draw_colored_polygon(
		PackedVector2Array([at + Vector2(-4, -8), at + Vector2(-30, -30), at + Vector2(-22, -4)]),
		Color(0.3, 0.8, 1.0)
	)


func _enemy(at: Vector2) -> void:
	draw_colored_polygon(
		PackedVector2Array([at + Vector2(0, -18), at + Vector2(16, 14), at + Vector2(-16, 14)]),
		DANGER
	)


func _arc(from: Vector2, velocity: Vector2) -> void:
	var points: PackedVector2Array = []
	var gravity: Vector2 = Vector2(0.0, 380.0)
	for i: int in ARC_POINTS + 1:
		var t: float = float(i) / ARC_POINTS
		var _added: bool = points.append(from + velocity * t + gravity * t * t * 0.5)
	draw_polyline(points, ACCENT, LINE_WIDTH)


func _bar(rect: Rect2, fill: float, color: Color) -> void:
	draw_rect(rect, Color(0.02, 0.05, 0.14, 0.9))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), color)
	draw_rect(rect, Color.WHITE, false, 2.0)


func _cross(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-26.0, -26.0), Vector2(52.0, 52.0)), Color.WHITE)
	draw_rect(Rect2(at + Vector2(-6.0, -18.0), Vector2(12.0, 36.0)), ARMOR_COLOR)
	draw_rect(Rect2(at + Vector2(-18.0, -6.0), Vector2(36.0, 12.0)), ARMOR_COLOR)
