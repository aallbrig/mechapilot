extends GdUnitTestSuite
## Touch sticks (#25, #73 Controls, the owner's rules): the left half is a move
## stick that never fires. On the right half a tap (under 180 ms and 12 px) fires
## one shot at the tapped point, and touch-and-hold opens a stick anchored at
## the touch-down point that fires along the drag direction, never at the
## finger. Nothing fires before the tap or hold decision. Each touch is tracked
## by its index. Events are synthesized InputEventScreenTouch and
## InputEventScreenDrag on a controlled clock; shots are counted at the muzzle.

const LEFT_POINT: Vector2 = Vector2(200.0, 400.0)
const RIGHT_POINT: Vector2 = Vector2(750.0, 400.0)
const FINGER: int = 0
const OTHER_FINGER: int = 1
const THIRD_FINGER: int = 2
const EPS2: Vector2 = Vector2(0.01, 0.01)
const EPS3: Vector3 = Vector3(0.001, 0.001, 0.001)
## World units the mech is placed ahead of the finger's world point.
const BEHIND: float = 20.0

var _h: TouchHarness


func before_test() -> void:
	_h = TouchHarness.new()
	add_child(_h.holder)
	_h.settle()


func after_test() -> void:
	_h.dispose()


func test_left_stick_drag_moves_player() -> void:
	_h.start()
	var start_x: float = _h.mech.position.x
	_h.press(FINGER, LEFT_POINT)
	_h.drag(FINGER, LEFT_POINT + Vector2(TouchSticks.STICK_RANGE, 0.0))
	var intent: PilotIntent = _h.input.read_intent()
	_h.fly(1.0)
	var _moves: GdUnitAssert = assert_vector(intent.move).is_equal_approx(Vector2.RIGHT, EPS2)
	var _flew_right: GdUnitAssert = assert_float(_h.mech.position.x - start_x).is_greater(1.0)
	var _no_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(0)


func test_left_drag_up_moves_up_in_world_terms() -> void:
	_h.start()
	_h.press(FINGER, LEFT_POINT)
	_h.drag(FINGER, LEFT_POINT + Vector2(0.0, -TouchSticks.STICK_RANGE * 0.5))
	var half_up: PilotIntent = _h.input.read_intent()
	_h.drag(FINGER, LEFT_POINT + Vector2(0.0, TouchSticks.STICK_RANGE * 3.0))
	var full_down: PilotIntent = _h.input.read_intent()
	var _half: GdUnitAssert = assert_vector(half_up.move).is_equal_approx(Vector2(0.0, 0.5), EPS2)
	var _capped: GdUnitAssert = assert_vector(full_down.move).is_equal_approx(
		Vector2(0.0, -1.0), EPS2
	)


func test_left_half_never_fires() -> void:
	_h.start()
	_h.press(FINGER, LEFT_POINT)
	_h.release(FINGER, LEFT_POINT)
	_h.fly(0.1)
	_h.press(FINGER, LEFT_POINT)
	_h.fly(0.5)
	_h.drag(FINGER, LEFT_POINT + Vector2(0.0, -60.0))
	_h.fly(0.5)
	_h.release(FINGER, LEFT_POINT + Vector2(0.0, -60.0))
	_h.fly(0.2)
	var _no_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(0)


func test_right_tap_fires_one_shot_at_the_point() -> void:
	_h.start()
	var tap: Vector2 = Vector2(800.0, 150.0)
	var target: Vector3 = _h.rig.screen_to_play_plane(tap)
	_h.press(FINGER, tap)
	_h.fly(0.05)
	_h.release(FINGER, tap + Vector2(3.0, 2.0))
	var expected: Vector3 = (target - _h.mech.global_position) * Vector3(1.0, 1.0, 0.0)
	_h.fly(1.0)
	var _one_shot: GdUnitAssert = assert_int(_h.shots.size()).is_equal(1)
	var _at_point: GdUnitAssert = assert_vector(_h.last_shot()).is_equal_approx(
		expected.normalized(), EPS3
	)


func test_slow_or_moved_tap_is_not_a_shot() -> void:
	_h.start()
	_h.press(FINGER, RIGHT_POINT)
	_h.fly(TouchSticks.TAP_TIME + 0.05)
	_h.release(FINGER, RIGHT_POINT)
	_h.press(OTHER_FINGER, RIGHT_POINT)
	_h.drag(OTHER_FINGER, RIGHT_POINT + Vector2(0.0, TouchSticks.TAP_SLOP + 1.0))
	_h.drag(OTHER_FINGER, RIGHT_POINT)
	_h.release(OTHER_FINGER, RIGHT_POINT)
	_h.fly(0.5)
	var _no_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(0)


func test_right_hold_without_drag_fires_nothing() -> void:
	_h.start()
	_h.press(FINGER, RIGHT_POINT)
	_h.fly(2.0)
	var intent: PilotIntent = _h.input.read_intent()
	var holding: bool = _h.controls.is_aim_stick_shown()
	_h.release(FINGER, RIGHT_POINT)
	_h.fly(0.5)
	var _no_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(0)
	var _not_firing: GdUnitAssert = assert_bool(intent.firing).is_false()
	var _stick_open: GdUnitAssert = assert_bool(holding).is_true()


func test_nothing_fires_before_the_tap_or_hold_decision() -> void:
	_h.start()
	_h.press(FINGER, RIGHT_POINT)
	_h.drag(FINGER, RIGHT_POINT + Vector2(TouchSticks.TAP_SLOP - 1.0, 0.0))
	_h.fly(TouchSticks.TAP_TIME * 0.5)
	var undecided: PilotIntent = _h.input.read_intent()
	var _no_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(0)
	var _not_firing: GdUnitAssert = assert_bool(undecided.firing).is_false()
	var _no_aim: GdUnitAssert = assert_vector(undecided.aim).is_equal(Vector2.ZERO)
	var _no_stick: GdUnitAssert = assert_bool(_h.controls.is_aim_stick_shown()).is_false()


func test_right_stick_hold_aims_and_fires() -> void:
	_h.start()
	_h.press(FINGER, RIGHT_POINT)
	_h.fly(TouchSticks.TAP_TIME + 0.1)
	_h.drag(FINGER, RIGHT_POINT + Vector2(0.0, -50.0))
	_h.fly(0.5)
	var up_shots: int = _h.shots.size()
	var up: Vector3 = _h.last_shot()
	_h.drag(FINGER, RIGHT_POINT + Vector2(-40.0, 0.0))
	_h.fly(0.5)
	var _continuous: GdUnitAssert = assert_int(up_shots).is_greater_equal(4)
	var _up: GdUnitAssert = assert_vector(up).is_equal_approx(Vector3.UP, EPS3)
	var _left: GdUnitAssert = assert_vector(_h.last_shot()).is_equal_approx(Vector3.LEFT, EPS3)
	var _more: GdUnitAssert = assert_int(_h.shots.size()).is_greater(up_shots)


func test_right_stick_fires_along_the_drag_never_at_the_finger() -> void:
	_h.start()
	# Put the mech to the right of where the finger lands in the world, so the
	# finger's world point is behind it: a rightward drag still fires right.
	var anchor: Vector2 = Vector2(750.0, 300.0)
	var finger: Vector2 = anchor + Vector2(30.0, 0.0)
	var finger_world: Vector3 = _h.rig.screen_to_play_plane(finger)
	_h.mech.position = Vector3(finger_world.x + BEHIND, finger_world.y, 0.0)
	var to_finger: Vector3 = finger_world - _h.mech.global_position
	_h.press(FINGER, anchor)
	_h.drag(FINGER, finger)
	_h.fly(0.5)
	var intent: PilotIntent = _h.input.read_intent()
	var _finger_is_behind: GdUnitAssert = assert_float(to_finger.x).is_less(0.0)
	var _shots_fired: GdUnitAssert = assert_int(_h.shots.size()).is_greater(0)
	var _along_drag: GdUnitAssert = assert_vector(_h.last_shot()).is_equal_approx(
		Vector3.RIGHT, EPS3
	)
	var _no_point_aim: GdUnitAssert = assert_bool(intent.has_aim_point or intent.has_tap).is_false()


func test_two_touches_tracked_independently() -> void:
	_h.start()
	_h.press(FINGER, LEFT_POINT)
	_h.press(OTHER_FINGER, RIGHT_POINT)
	_h.drag(FINGER, LEFT_POINT + Vector2(-TouchSticks.STICK_RANGE, 0.0))
	_h.drag(OTHER_FINGER, RIGHT_POINT + Vector2(50.0, 0.0))
	_h.fly(0.5)
	var both: PilotIntent = _h.input.read_intent()
	_h.release(FINGER, LEFT_POINT)
	var aim_only: PilotIntent = _h.input.read_intent()
	# A third finger on the held right half, and its release, are ignored.
	_h.press(THIRD_FINGER, Vector2(600.0, 300.0))
	_h.release(THIRD_FINGER, Vector2(600.0, 300.0))
	var after_third: PilotIntent = _h.input.read_intent()
	# A finger that starts on the left stays the move stick across the middle.
	_h.press(FINGER, LEFT_POINT)
	_h.drag(FINGER, LEFT_POINT + Vector2(400.0, 0.0))
	_h.release(OTHER_FINGER, RIGHT_POINT)
	var move_only: PilotIntent = _h.input.read_intent()
	var _moves_left: GdUnitAssert = assert_vector(both.move).is_equal_approx(Vector2.LEFT, EPS2)
	var _aims_right: GdUnitAssert = assert_vector(both.aim).is_equal_approx(Vector2.RIGHT, EPS2)
	var _fires: GdUnitAssert = assert_bool(both.firing).is_true()
	var _move_released: GdUnitAssert = assert_vector(aim_only.move).is_equal(Vector2.ZERO)
	var _still_aims: GdUnitAssert = assert_bool(aim_only.firing).is_true()
	var _third_ignored: GdUnitAssert = (
		assert_bool(after_third.firing and not after_third.has_tap).is_true()
	)
	var _aim_released: GdUnitAssert = assert_bool(move_only.firing or move_only.has_tap).is_false()
	var _still_moves: GdUnitAssert = assert_vector(move_only.move).is_equal_approx(
		Vector2.RIGHT, EPS2
	)


func test_leaving_play_releases_the_sticks() -> void:
	_h.start()
	_h.press(FINGER, LEFT_POINT)
	_h.press(OTHER_FINGER, RIGHT_POINT)
	_h.drag(FINGER, LEFT_POINT + Vector2(TouchSticks.STICK_RANGE, 0.0))
	_h.drag(OTHER_FINGER, RIGHT_POINT + Vector2(50.0, 0.0))
	_h.bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.PAUSED)
	var paused: PilotIntent = _h.input.read_intent()
	_h.bus.flow.announce_game_state_changed(GameState.Phase.PAUSED, GameState.Phase.SKIRMISH)
	_h.drag(FINGER, LEFT_POINT + Vector2(-TouchSticks.STICK_RANGE, 0.0))
	_h.release(OTHER_FINGER, RIGHT_POINT)
	var resumed: PilotIntent = _h.input.read_intent()
	var _stopped: GdUnitAssert = assert_vector(paused.move).is_equal(Vector2.ZERO)
	var _ceased: GdUnitAssert = assert_bool(paused.firing).is_false()
	var _stale_drag: GdUnitAssert = assert_vector(resumed.move).is_equal(Vector2.ZERO)
	var _stale_release: GdUnitAssert = assert_bool(resumed.has_tap).is_false()


func test_cancelled_touch_is_not_a_tap() -> void:
	_h.start()
	_h.press(FINGER, RIGHT_POINT)
	_h.cancel(FINGER, RIGHT_POINT)
	_h.fly(0.2)
	var _no_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(0)
