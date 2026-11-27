extends GdUnitTestSuite
## Off-screen indicators (#23): a yellow arrow at the screen edge for every
## enemy off screen, pointing toward it, none for enemies on screen, pooled.

const SCREEN: Vector2 = Vector2(800.0, 600.0)
## 20 pixels per unit: the screen spans 40 x 30 units around the player.
const PIXELS_PER_UNIT: float = 20.0

var _h: FieldHarness
var _indicators: OffscreenIndicators
var _projector: ScreenProjector


func before_test() -> void:
	_h = FieldHarness.new()
	add_child(_h.field)
	_h.enter_level(1)
	_projector = ScreenProjector.new()
	_projector.pixels_per_unit = PIXELS_PER_UNIT
	_indicators = OffscreenIndicators.new()
	_indicators.field = _h.field
	_indicators.projector = _projector
	add_child(_indicators)
	_indicators.size = SCREEN


func after_test() -> void:
	_indicators.free()
	_h.dispose()


func test_offscreen_enemy_shows_indicator() -> void:
	var on_screen: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 10.0)
	var right: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 30.0)
	var above: Enemy = _h.order(EnemyKind.Kind.HEAVY, PI / 2.0, 25.0)
	_indicators.refresh()
	var right_arrow: Polygon2D = _indicators.arrow_for(right.enemy_id)
	var above_arrow: Polygon2D = _indicators.arrow_for(above.enemy_id)
	var _two: GdUnitAssert = assert_int(_indicators.shown_count()).is_equal(2)
	var _none_on_screen: GdUnitAssert = (
		assert_object(_indicators.arrow_for(on_screen.enemy_id)).is_null()
	)
	var _yellow: GdUnitAssert = assert_str(right_arrow.color.to_html(false)).is_equal("fff800")
	# On the right edge, inside the margin, pointing right.
	var _right_edge: GdUnitAssert = assert_float(right_arrow.position.x).is_equal_approx(
		SCREEN.x - OffscreenIndicators.MARGIN, 0.01
	)
	var _mid_height: GdUnitAssert = assert_float(right_arrow.position.y).is_equal_approx(
		SCREEN.y / 2.0, 0.01
	)
	var _points_right: GdUnitAssert = assert_float(right_arrow.rotation).is_equal_approx(0.0, 0.01)
	# On the top edge (screen +Y is down), pointing up.
	var _top_edge: GdUnitAssert = assert_float(above_arrow.position.y).is_equal_approx(
		OffscreenIndicators.MARGIN, 0.01
	)
	var _points_up: GdUnitAssert = assert_float(above_arrow.rotation).is_equal_approx(
		-PI / 2.0, 0.01
	)
	var _both_visible: GdUnitAssert = (
		assert_bool(right_arrow.visible and above_arrow.visible).is_true()
	)


func test_indicator_hides_when_enemy_comes_on_screen_or_goes() -> void:
	var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 30.0)
	_indicators.refresh()
	var arrow: Polygon2D = _indicators.arrow_for(enemy.enemy_id)
	# The player (and the camera) fly toward it until it is on screen.
	_h.target.at = Vector3(enemy.position.x - 5.0, enemy.position.y, 0.0)
	_projector.centre = _h.target.at
	_indicators.refresh()
	var shown_on_screen: int = _indicators.shown_count()
	var hidden: bool = not arrow.visible
	# Shot down off screen: its arrow goes too.
	_h.target.at = Vector3.ZERO
	_projector.centre = Vector3.ZERO
	_indicators.refresh()
	var back_off_screen: int = _indicators.shown_count()
	var _hit: bool = _h.field.resolve_shot(enemy.position, 0.3, Vector3.RIGHT)
	_indicators.refresh()
	var _had_arrow: GdUnitAssert = assert_object(arrow).is_not_null()
	var _none_on_screen: GdUnitAssert = assert_int(shown_on_screen).is_equal(0)
	var _hidden: GdUnitAssert = assert_bool(hidden).is_true()
	var _back: GdUnitAssert = assert_int(back_off_screen).is_equal(1)
	var _gone: GdUnitAssert = assert_int(_indicators.shown_count()).is_equal(0)


func test_indicators_are_pooled() -> void:
	var first: Array[Enemy] = []
	for i: int in 4:
		first.append(_h.order(EnemyKind.Kind.FIGHTER, i * 0.5, 30.0))
	_indicators.refresh()
	for enemy: Enemy in first:
		var _hit: bool = _h.field.resolve_shot(enemy.position, 0.3, Vector3.RIGHT)
	for i: int in 3:
		var _next: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 3.0 + i * 0.5, 30.0)
	_indicators.refresh()
	var _three: GdUnitAssert = assert_int(_indicators.shown_count()).is_equal(3)
	var _reused: GdUnitAssert = assert_int(_indicators.pooled_count()).is_equal(4)
