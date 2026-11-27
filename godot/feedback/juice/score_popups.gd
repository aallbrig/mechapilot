class_name ScorePopups
extends Node3D
## Score pop-ups in the sky (#26): every scored kill floats its points up from
## where the enemy died, with the Combo multiplier when there is one, bigger and
## hotter as the Combo grows. Repair Kits pop "+ARMOR". Labels are pooled; the
## oldest is reused when all are showing.

const POOL_SIZE: int = 12
## Pop-ups start a little above and in front of the kill, then rise.
const OFFSET: Vector3 = Vector3(0.0, 1.0, 2.0)
const RISE: float = 2.5
const SECONDS: float = 0.8
const FONT_SIZE: int = 64
const FONT_SIZE_PER_COMBO: int = 8
const OUTLINE_SIZE: int = 16
const PIXEL_SIZE: float = 0.012
## Colour by Combo multiplier (index = multiplier - 1, 1 to 8).
const COMBO_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.95, 0.6),
	Color(1.0, 0.88, 0.35),
	Color(1.0, 0.75, 0.25),
	Color(1.0, 0.6, 0.2),
	Color(1.0, 0.45, 0.2),
	Color(1.0, 0.32, 0.25),
	Color(1.0, 0.2, 0.35),
]
const REPAIR_COLOR: Color = Color(0.45, 1.0, 0.55)
const REPAIR_TEXT: String = "+ARMOR"

var _labels: Array[Label3D] = []
var _tweens: Array[Tween] = []
var _next: int = 0


func _init() -> void:
	for _i: int in POOL_SIZE:
		var label: Label3D = Label3D.new()
		label.pixel_size = PIXEL_SIZE
		label.outline_size = OUTLINE_SIZE
		label.no_depth_test = true
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visible = false
		add_child(label)
		_labels.append(label)
		_tweens.append(null)


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	(
		BusLinks
		. require_ok(
			"ScorePopups",
			[
				bus.run.kill_scored.connect(_on_kill_scored),
				bus.player.repair_collected.connect(_on_repair_collected),
			]
		)
	)


## The text of every pop-up on show, oldest first.
func showing() -> Array[String]:
	var texts: Array[String] = []
	for i: int in POOL_SIZE:
		var label: Label3D = _labels[(_next + i) % POOL_SIZE]
		if label.visible:
			texts.append(label.text)
	return texts


## The text of a kill pop-up: the points, then the multiplier when above 1.
static func kill_text(points: int, multiplier: int) -> String:
	if multiplier > 1:
		return "+%d\nx%d" % [points, multiplier]
	return "+%d" % points


func _show(text: String, at: Vector3, color: Color, font_size: int) -> void:
	var index: int = _next
	_next = (_next + 1) % POOL_SIZE
	var label: Label3D = _labels[index]
	label.text = text
	label.font_size = font_size
	label.modulate = color
	label.position = at + OFFSET
	label.visible = true
	_tweens[index] = JuiceTween.rise_and_fade(label, _tweens[index], RISE, SECONDS)


func _on_kill_scored(points: int, multiplier: int, at: Vector3) -> void:
	var step: int = clampi(multiplier, 1, COMBO_COLORS.size()) - 1
	_show(
		kill_text(points, multiplier),
		at,
		COMBO_COLORS[step],
		FONT_SIZE + FONT_SIZE_PER_COMBO * step
	)


func _on_repair_collected(at: Vector3) -> void:
	_show(REPAIR_TEXT, at, REPAIR_COLOR, FONT_SIZE)
