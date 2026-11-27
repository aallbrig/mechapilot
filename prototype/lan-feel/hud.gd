extends Control
## PROTOTYPE in-game HUD: score, combo, banners, 1UP, lives icons, off-screen
## indicators and touch sticks. Reads game state from `game` (main.gd).

const TweenFx := preload("res://tween_fx.gd")
const COMBO_WINDOW := 1.6
const STICK_RANGE := 70.0

var game: Node
var score_label: Label
var combo_label: Label
var center_label: Label
var sub_label: Label
var oneup_label: Label
var lives_shown := 0


static func make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = maxi(4, size / 6)
	ls.outline_color = Color(0, 0, 0.1)
	ls.shadow_size = 4
	ls.shadow_color = Color(0, 0, 0, 0.5)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label = _top_label(44, Color(1, 1, 1), 14, 60)
	combo_label = _top_label(30, Color(1, 0.85, 0.2), 72, 40)
	center_label = make_label(84, Color(1, 1, 1))
	center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_label.offset_bottom = -120
	add_child(center_label)
	sub_label = make_label(26, Color(0.8, 0.9, 1.0))
	sub_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_label.offset_top = 120
	add_child(sub_label)
	oneup_label = make_label(110, Color(0.4, 1.0, 0.5))
	oneup_label.set_anchors_preset(Control.PRESET_CENTER)
	oneup_label.size = Vector2(600, 140)
	oneup_label.position = Vector2(-300, -250)
	oneup_label.pivot_offset = Vector2(300, 70)
	oneup_label.text = "1UP!"
	oneup_label.visible = false
	add_child(oneup_label)
	Events.score_changed.connect(_on_score_changed)
	Events.wave_started.connect(_on_wave_started)
	Events.extra_life.connect(_on_extra_life)
	Events.life_lost.connect(_on_life_lost)


func _top_label(size: int, color: Color, y: float, h: float) -> Label:
	var l := make_label(size, color)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.size = Vector2(500, h)
	l.position = Vector2(-250, y)
	l.pivot_offset = Vector2(250, h * 0.5)
	add_child(l)
	return l


func clear() -> void:
	score_label.text = ""
	combo_label.text = ""
	center_label.text = ""
	sub_label.text = ""


func banner(text: String, hold: float = 0.9) -> void:
	center_label.text = text
	center_label.modulate.a = 1.0
	TweenFx.pop(center_label, 0.5, 0.35)
	var tw := TweenFx.fade(center_label, 0.0, 0.4, hold)
	tw.tween_callback(_clear_center.bind(text))


func _clear_center(text: String) -> void:
	if center_label.text == text:
		center_label.text = ""
	center_label.modulate.a = 1.0


func _on_score_changed(new_score: int, new_combo: int) -> void:
	score_label.text = "SCORE %d" % new_score
	combo_label.text = "x%d COMBO" % new_combo if new_combo > 1 else ""
	TweenFx.punch_scale(score_label, 0.3, 0.3)
	if new_combo > 1:
		TweenFx.punch_scale(combo_label, 0.15 + 0.04 * new_combo, 0.35)


func _on_wave_started(number: int) -> void:
	banner("WAVE %d" % number)


func _on_extra_life(_lives: int) -> void:
	oneup_label.visible = true
	oneup_label.modulate.a = 1.0
	oneup_label.rotation = -0.2
	TweenFx.pop(oneup_label, 0.1, 0.6)
	var tw := oneup_label.create_tween().set_ignore_time_scale(true)
	tw.tween_property(oneup_label, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_interval(0.8)
	tw.tween_property(oneup_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(oneup_label.hide)


func _on_life_lost(_lives_left: int) -> void:
	TweenFx.shake(score_label, 14.0, 0.35)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var playing: bool = game.is_playing()
	var rect := Rect2(Vector2.ZERO, size)
	if playing:
		_draw_indicators(rect)
		var combo: int = game.combo
		if combo > 1:
			var k: float = clampf(game.combo_timer / COMBO_WINDOW, 0.0, 1.0)
			var w := 220.0 * k
			draw_rect(Rect2(size.x * 0.5 - w * 0.5, 112, w, 6), Color(1, 0.85, 0.2, 0.9))
		var lives: int = game.lives
		for i in lives:
			_draw_life_icon(Vector2(34 + i * 40, 34))
	_draw_stick(game.touch_move_id, game.touch_move_origin, game.touch_move_vec)
	var aim_id: int = game.touch_aim_id if game.touch_aim_holding else -1
	_draw_stick(aim_id, game.touch_aim_origin, game.touch_aim_vec)


func _draw_indicators(rect: Rect2) -> void:
	var cam: Camera3D = game.cam
	var player: Node3D = game.player
	var center := rect.size * 0.5
	var inner := rect.grow(-28.0)
	for e: Variant in game.enemies:
		var pos: Vector3 = e.node.position
		var sp := cam.unproject_position(pos)
		if rect.has_point(sp):
			continue
		var dir := (sp - center).normalized()
		var edge := _clamp_to_rect(center, dir, inner)
		var dist := player.position.distance_to(pos)
		var sz := clampf(22.0 - dist * 0.35, 9.0, 18.0)
		var col := Color(1, 0.6, 0.1) if e.big else Color(1, 0.3, 0.4)
		var pts := PackedVector2Array(
			[
				edge + dir * sz,
				edge + dir.orthogonal() * sz * 0.6,
				edge - dir.orthogonal() * sz * 0.6
			]
		)
		draw_colored_polygon(pts, col)


## A tiny side-on mech with its booster wings.
func _draw_life_icon(at: Vector2) -> void:
	var c := Color(0.75, 0.9, 1.0)
	var wing := Color(0.3, 0.8, 1.0)
	draw_colored_polygon(
		PackedVector2Array([at + Vector2(-2, -4), at + Vector2(-16, -18), at + Vector2(-12, -2)]),
		wing
	)
	draw_rect(Rect2(at + Vector2(-6, -8), Vector2(12, 12)), c)
	draw_rect(Rect2(at + Vector2(-4, -15), Vector2(8, 6)), c)
	draw_rect(Rect2(at + Vector2(-5, 4), Vector2(4, 10)), c)
	draw_rect(Rect2(at + Vector2(1, 4), Vector2(4, 10)), c)
	draw_rect(Rect2(at + Vector2(2, -13), Vector2(2, 2)), Color(1, 0.2, 0.2))


func _draw_stick(id: int, origin: Vector2, vec: Vector2) -> void:
	if id < 0:
		return
	var r := STICK_RANGE
	draw_circle(origin, r, Color(1, 1, 1, 0.12))
	draw_arc(origin, r, 0, TAU, 48, Color(1, 1, 1, 0.4), 3.0)
	draw_circle(origin + vec * r, 30.0, Color(1, 1, 1, 0.45))


func _clamp_to_rect(center: Vector2, dir: Vector2, r: Rect2) -> Vector2:
	var tx := INF
	var ty := INF
	if absf(dir.x) > 0.0001:
		tx = ((r.end.x if dir.x > 0 else r.position.x) - center.x) / dir.x
	if absf(dir.y) > 0.0001:
		ty = ((r.end.y if dir.y > 0 else r.position.y) - center.y) / dir.y
	return center + dir * minf(tx, ty)
