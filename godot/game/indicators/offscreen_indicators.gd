class_name OffscreenIndicators
extends Control
## A yellow (#FFF800) arrow at the screen edge for every enemy that is off
## screen, pointing the way to it, so the player always knows where the fight
## is. Arrows are pooled: one per enemy, reused as enemies come and go. Its
## parent lays it over the whole screen (its size is the screen's); it ignores
## the mouse.

const COLOR: Color = Color("#FFF800")
## Pixels between the screen edge and an arrow's tip.
const MARGIN: float = 28.0
## The arrow's shape (pixels), tip along +X.
const ARROW: PackedVector2Array = [
	Vector2(14.0, 0.0), Vector2(-10.0, 10.0), Vector2(-4.0, 0.0), Vector2(-10.0, -10.0)
]
## Arrows pulse in size so they read at a glance (Hz and share of size).
const PULSE_RATE: float = 3.0
const PULSE_SIZE: float = 0.15
## Arrows for nearer enemies are drawn larger: full size within NEAR units,
## shrinking to FAR_SCALE at FAR units.
const NEAR: float = 26.0
const FAR: float = 40.0
const FAR_SCALE: float = 0.6

var field: EnemyField
var projector: ScreenProjector

var _arrows: Array[Polygon2D] = []
var _shown: Dictionary[int, Polygon2D] = {}
var _clock: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_clock += delta
	refresh()


## Place an arrow for every off-screen enemy, and hide the rest.
func refresh() -> void:
	_shown.clear()
	if field == null or projector == null:
		_hide_from(0)
		return
	var screen: Rect2 = Rect2(Vector2.ZERO, size)
	var inner: Rect2 = screen.grow(-MARGIN)
	var middle: Vector2 = screen.get_center()
	var used: int = 0
	var target: CombatTarget = field.player_target()
	var player: Vector3 = target.position() if target != null else Vector3.ZERO
	for enemy: Enemy in field.active_enemies():
		var point: Vector2 = projector.to_screen(enemy.position, size)
		var behind: bool = projector.is_behind(enemy.position)
		if not behind and screen.has_point(point):
			continue
		var toward: Vector2 = point - middle
		if behind:
			toward = -toward
		if toward.length() < FiringSolution.MIN_DISTANCE:
			continue
		var arrow: Polygon2D = _arrow(used)
		used += 1
		arrow.position = edge_point(middle, toward, inner)
		arrow.rotation = toward.angle()
		var distance: float = (
			Vector2(enemy.position.x - player.x, enemy.position.y - player.y).length()
		)
		var near_scale: float = remap(clampf(distance, NEAR, FAR), NEAR, FAR, 1.0, FAR_SCALE)
		arrow.scale = Vector2.ONE * near_scale * (1.0 + sin(_clock * TAU * PULSE_RATE) * PULSE_SIZE)
		arrow.visible = true
		_shown[enemy.enemy_id] = arrow
	_hide_from(used)


## How many arrows show now.
func shown_count() -> int:
	return _shown.size()


## The arrow pointing at `enemy_id`, or null if it is on screen or gone.
func arrow_for(enemy_id: int) -> Polygon2D:
	if not _shown.has(enemy_id):
		return null
	return _shown[enemy_id]


## Arrow nodes made so far.
func pooled_count() -> int:
	return _arrows.size()


## Where the ray from `from` along `toward` leaves `rect`.
static func edge_point(from: Vector2, toward: Vector2, rect: Rect2) -> Vector2:
	var t: float = INF
	if toward.x > 0.0:
		t = minf(t, (rect.end.x - from.x) / toward.x)
	elif toward.x < 0.0:
		t = minf(t, (rect.position.x - from.x) / toward.x)
	if toward.y > 0.0:
		t = minf(t, (rect.end.y - from.y) / toward.y)
	elif toward.y < 0.0:
		t = minf(t, (rect.position.y - from.y) / toward.y)
	if is_inf(t):
		return from
	return from + toward * maxf(t, 0.0)


func _arrow(index: int) -> Polygon2D:
	while _arrows.size() <= index:
		var arrow: Polygon2D = Polygon2D.new()
		arrow.polygon = ARROW
		arrow.color = COLOR
		arrow.visible = false
		add_child(arrow)
		_arrows.append(arrow)
	return _arrows[index]


func _hide_from(index: int) -> void:
	for i: int in range(index, _arrows.size()):
		_arrows[i].visible = false
