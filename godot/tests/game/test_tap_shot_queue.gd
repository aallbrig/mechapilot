extends GdUnitTestSuite
## Tap Shots and the fire cooldown (#25, #84): a tap during the cooldown waits
## for it, aimed at the world point it was tapped on, and the latest tap wins.
## Holding fire drops the waiting tap, and so does a respawn.

const FINGER: int = 0
const OTHER_FINGER: int = 1
const FIRST: Vector2 = Vector2(800.0, 300.0)
## High and low on the right half: their world points are far apart.
const HIGH: Vector2 = Vector2(700.0, 20.0)
const LOW: Vector2 = Vector2(700.0, 580.0)
const HOLD_ANCHOR: Vector2 = Vector2(750.0, 400.0)
const AIM_TOLERANCE: float = 0.05

var _h: TouchHarness


func before_test() -> void:
	_h = TouchHarness.new()
	add_child(_h.holder)
	_h.settle()
	_h.start()


func after_test() -> void:
	_h.dispose()


## Fire one tap at FIRST so the cooldown runs, then queue a tap at `at`.
func _queue_tap(at: Vector2) -> void:
	_h.tap(FINGER, FIRST)
	_h.fly(TouchHarness.TICK)
	_h.tap(FINGER, at)
	_h.fly(TouchHarness.TICK)


## The unit direction from the mech to the world point under `screen` now.
func _toward(screen: Vector2) -> Vector3:
	var to: Vector3 = _h.rig.screen_to_play_plane(screen) - _h.mech.global_position
	return (to * Vector3(1.0, 1.0, 0.0)).normalized()


func test_latest_queued_tap_wins() -> void:
	var high: Vector3 = _toward(HIGH)
	var low: Vector3 = _toward(LOW)
	_queue_tap(HIGH)
	_h.tap(FINGER, LOW)
	_h.fly(0.3)
	var _two_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(2)
	var _apart: GdUnitAssert = assert_float(high.dot(low)).is_less(0.9)
	var _latest: GdUnitAssert = assert_float(_h.last_shot().dot(low)).is_greater(
		_h.last_shot().dot(high)
	)


func test_holding_fire_drops_the_queued_tap() -> void:
	var high: Vector3 = _toward(HIGH)
	_queue_tap(HIGH)
	# Open the aim stick and fire right, then let go before the next interval.
	_h.press(OTHER_FINGER, HOLD_ANCHOR)
	_h.drag(OTHER_FINGER, HOLD_ANCHOR + Vector2(50.0, 0.0))
	_h.fly(TouchHarness.TICK)
	_h.release(OTHER_FINGER, HOLD_ANCHOR + Vector2(50.0, 0.0))
	_h.fly(0.5)
	var toward_high: int = 0
	for i: int in range(1, _h.shots.size()):
		if _h.shots[i].dot(high) > 1.0 - AIM_TOLERANCE:
			toward_high += 1
	var _first_fired: GdUnitAssert = assert_int(_h.shots.size()).is_greater_equal(1)
	var _dropped: GdUnitAssert = assert_int(toward_high).is_equal(0)


func test_respawn_clears_the_queued_tap() -> void:
	_queue_tap(HIGH)
	_h.mech.respawn(_h.mech.position)
	_h.fly(0.3)
	var _only_the_first: GdUnitAssert = assert_int(_h.shots.size()).is_equal(1)


func test_queued_tap_aims_where_it_was_tapped() -> void:
	var tapped_world: Vector3 = _h.rig.screen_to_play_plane(HIGH)
	_queue_tap(HIGH)
	# The camera moves before the cooldown ends: the tap keeps its world point.
	# Far enough that the same screen point now lies well below the mech.
	var reach: float = (tapped_world - _h.mech.global_position).length()
	_h.rig.snap_to(_h.mech.position + Vector3(0.0, -3.0 * reach, 0.0))
	var stale: Vector3 = _toward(HIGH)
	_h.fly(0.3)
	var expected: Vector3 = (
		((tapped_world - _h.mech.global_position) * Vector3(1.0, 1.0, 0.0)).normalized()
	)
	var _two_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(2)
	var _at_tap_point: GdUnitAssert = assert_float(_h.last_shot().dot(expected)).is_greater(
		1.0 - AIM_TOLERANCE
	)
	var _not_rescreened: GdUnitAssert = assert_float(_h.last_shot().dot(stale)).is_less(0.9)
