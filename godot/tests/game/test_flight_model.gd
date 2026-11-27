extends GdUnitTestSuite
## Flight rules for the player mech: coasting falls gently, thrust overrides
## gravity, and the pace is GAME_SPEED 0.75 (#22, #73).

const TICK: float = 1.0 / 60.0

var _tuning: MechTuning = MechTuning.new()


func _fly(start: Vector3, move: Vector2, seconds: float) -> Array[Vector3]:
	var v: Vector3 = start
	var trace: Array[Vector3] = []
	var ticks: int = roundi(seconds / TICK)
	for _i: int in ticks:
		v = FlightModel.step_velocity(v, move, TICK, _tuning)
		trace.append(v)
	return trace


func test_game_speed_is_three_quarters() -> void:
	var _pace: GdUnitAssert = assert_float(Pace.GAME_SPEED).is_equal(0.75)
	var _speed: GdUnitAssert = assert_float(_tuning.speed).is_equal_approx(11.0 * 0.75, 1e-6)
	var _shot: GdUnitAssert = assert_float(_tuning.shot_speed).is_equal_approx(46.0 * 0.75, 1e-6)
	var _gravity: GdUnitAssert = assert_float(_tuning.shot_gravity).is_equal_approx(
		20.0 * 0.75 * 0.75, 1e-6
	)


func test_coasting_mech_falls_under_gentle_gravity() -> void:
	var trace: Array[Vector3] = _fly(Vector3.ZERO, Vector2.ZERO, 0.5)
	var rises: int = 0
	for i: int in range(1, trace.size()):
		if trace[i].y > trace[i - 1].y:
			rises += 1
	# After 0.5 s of free coasting: falling at coast gravity, never rising.
	var _falls: GdUnitAssert = assert_float(trace[-1].y).is_equal_approx(
		-_tuning.coast_gravity * 0.5, 0.01
	)
	var _gentle: GdUnitAssert = assert_float(-trace[-1].y).is_less(_tuning.coast_terminal_fall)
	var _never_rises: GdUnitAssert = assert_int(rises).is_equal(0)


func test_coasting_fall_is_capped_at_terminal_speed() -> void:
	var trace: Array[Vector3] = _fly(Vector3.ZERO, Vector2.ZERO, 5.0)
	var _capped: GdUnitAssert = assert_float(trace[-1].y).is_equal_approx(
		-_tuning.coast_terminal_fall, 1e-4
	)


func test_coasting_keeps_horizontal_momentum_with_light_drag() -> void:
	var trace: Array[Vector3] = _fly(Vector3(6.0, 0.0, 0.0), Vector2.ZERO, 1.0)
	var expected: float = 6.0 * exp(-_tuning.coast_drag * 1.0)
	var _drag: GdUnitAssert = assert_float(trace[-1].x).is_equal_approx(expected, 0.01)


func test_coasting_mech_never_rises_on_its_own() -> void:
	# Even with upward momentum, coasting only ever reduces the climb rate.
	var trace: Array[Vector3] = _fly(Vector3(0.0, 4.0, 0.0), Vector2.ZERO, 3.0)
	var climbs: int = 0
	for i: int in range(1, trace.size()):
		if trace[i].y > trace[i - 1].y:
			climbs += 1
	var _never_climbs: GdUnitAssert = assert_int(climbs).is_equal(0)
	var _ends_falling: GdUnitAssert = assert_float(trace[-1].y).is_less(0.0)


func test_thrust_overrides_gravity() -> void:
	# Full sideways thrust from a fall: the mech levels off instead of sinking.
	var trace: Array[Vector3] = _fly(Vector3(0.0, -5.0, 0.0), Vector2.RIGHT, 1.5)
	var _level: GdUnitAssert = assert_float(absf(trace[-1].y)).is_less(0.01)
	var _forward: GdUnitAssert = assert_float(trace[-1].x).is_equal_approx(_tuning.speed, 0.01)


func test_thrust_reaches_player_speed() -> void:
	var trace: Array[Vector3] = _fly(Vector3.ZERO, Vector2(0.0, 1.0), 1.5)
	var _speed: GdUnitAssert = assert_float(trace[-1].length()).is_equal_approx(_tuning.speed, 0.01)
	var _up: GdUnitAssert = assert_float(trace[-1].y).is_greater(0.0)


func test_small_stick_input_coasts() -> void:
	var noise: Vector2 = Vector2(_tuning.thrust_deadzone * 0.5, 0.0)
	var _coasts: GdUnitAssert = assert_bool(FlightModel.is_thrusting(noise, _tuning)).is_false()
	var _thrusts: GdUnitAssert = (
		assert_bool(FlightModel.is_thrusting(Vector2.UP, _tuning)).is_true()
	)


func test_flight_stays_on_the_play_plane() -> void:
	var trace: Array[Vector3] = _fly(Vector3(1.0, 1.0, 3.0), Vector2(1.0, 1.0), 0.5)
	var _flat: GdUnitAssert = assert_float(trace[-1].z).is_equal(0.0)
