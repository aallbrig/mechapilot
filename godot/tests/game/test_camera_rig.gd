extends GdUnitTestSuite
## The lazy camera: a dead zone, a critically damped follow that lags, a recentre
## once the mech's velocity is steady, and a wider view in portrait (#22).

const TICK: float = 1.0 / 60.0
const DEAD_ZONE: Vector2 = Vector2(6.0, 4.0)

var _tuning: MechTuning = MechTuning.new()


func test_camera_ignores_small_moves_inside_the_dead_zone() -> void:
	var follow: LazyFollow = LazyFollow.new()
	follow.snap(Vector3.ZERO)
	# A sudden hop inside the dead zone, then the mech hovers there.
	var hop: Vector3 = Vector3(DEAD_ZONE.x * 0.6, 0.0, 0.0)
	var focus: Vector3 = Vector3.ZERO
	for _i: int in 6:
		focus = follow.step(hop, Vector3.ZERO, DEAD_ZONE, TICK)
	var _barely_moves: GdUnitAssert = assert_float(focus.x).is_less(hop.x * 0.05)


func test_camera_follows_a_move_past_the_dead_zone_without_overshoot() -> void:
	var follow: LazyFollow = LazyFollow.new()
	follow.snap(Vector3.ZERO)
	var jump: Vector3 = Vector3(20.0, -12.0, 0.0)
	var peak_x: float = 0.0
	var focus: Vector3 = Vector3.ZERO
	for _i: int in 600:
		focus = follow.step(jump, Vector3.ZERO, DEAD_ZONE, TICK)
		peak_x = maxf(peak_x, focus.x)
	var _arrives: GdUnitAssert = assert_vector(focus).is_equal_approx(jump, Vector3.ONE * 0.05)
	var _no_overshoot: GdUnitAssert = assert_float(peak_x).is_less_equal(jump.x + 1e-3)


func test_camera_lags_behind_a_moving_mech() -> void:
	var follow: LazyFollow = LazyFollow.new()
	follow.snap(Vector3.ZERO)
	var v: Vector3 = Vector3(_tuning.speed, 0.0, 0.0)
	var p: Vector3 = Vector3.ZERO
	var focus: Vector3 = Vector3.ZERO
	for _i: int in 30:
		p += v * TICK
		focus = follow.step(p, v, DEAD_ZONE, TICK)
	var _lags: GdUnitAssert = assert_float(focus.x).is_less(p.x * 0.5)


func test_camera_recentres_on_a_steady_mech() -> void:
	var follow: LazyFollow = LazyFollow.new()
	follow.snap(Vector3.ZERO)
	var v: Vector3 = Vector3(_tuning.speed, -2.0, 0.0)
	var p: Vector3 = Vector3.ZERO
	var off_centre_early: float = 0.0
	var focus: Vector3 = Vector3.ZERO
	for i: int in 480:
		p += v * TICK
		focus = follow.step(p, v, DEAD_ZONE, TICK)
		if i == 45:
			off_centre_early = (p + v * LazyFollow.LOOKAHEAD - focus).length()
	var off_centre_late: float = (p + v * LazyFollow.LOOKAHEAD - focus).length()
	# The mech first drifts toward the dead zone's edge, then the camera settles
	# it back on centre (plus the lookahead) while its velocity stays steady.
	var _drifted: GdUnitAssert = assert_float(off_centre_early).is_greater(2.0)
	var _recentred: GdUnitAssert = assert_float(off_centre_late).is_less(0.25)


func test_camera_widens_in_portrait() -> void:
	var landscape: float = CameraRig.distance_for_aspect(16.0 / 9.0)
	var portrait: float = CameraRig.distance_for_aspect(9.0 / 16.0)
	var half_width: float = tan(deg_to_rad(CameraRig.FOV * 0.5)) * portrait * (9.0 / 16.0)
	var _landscape: GdUnitAssert = assert_float(landscape).is_equal(CameraRig.DISTANCE)
	var _wider: GdUnitAssert = assert_float(portrait).is_greater(landscape)
	var _min_width: GdUnitAssert = assert_float(half_width).is_equal_approx(
		CameraRig.MIN_HALF_WIDTH, 1e-3
	)


func test_camera_dead_zone_scales_with_the_view() -> void:
	var dz: Vector2 = CameraRig.dead_zone_for(CameraRig.DISTANCE, 2.0)
	var half_h: float = tan(deg_to_rad(CameraRig.FOV * 0.5)) * CameraRig.DISTANCE
	var _height: GdUnitAssert = assert_float(dz.y).is_equal_approx(
		half_h * CameraRig.DEAD_ZONE_SHARE, 1e-4
	)
	var _width: GdUnitAssert = assert_float(dz.x).is_equal_approx(dz.y * 2.0, 1e-4)


func test_camera_rig_frames_the_side_view() -> void:
	var rig: CameraRig = CameraRig.new()
	add_child(rig)
	rig.set_view_aspect(16.0 / 9.0)
	rig.snap_to(Vector3(5.0, 3.0, 0.0))
	rig.advance(TICK, Vector3(5.0, 3.0, 0.0), Vector3.ZERO)
	var cam: Camera3D = rig.camera()
	var cam_pos: Vector3 = cam.global_position
	var forward: Vector3 = -cam.global_basis.z
	rig.free()
	var _side_on: GdUnitAssert = assert_vector(forward).is_equal_approx(
		Vector3.FORWARD, Vector3.ONE * 1e-4
	)
	var _framed: GdUnitAssert = assert_vector(cam_pos).is_equal_approx(
		Vector3(5.0, 3.0, CameraRig.DISTANCE), Vector3.ONE * 1e-3
	)


## Cruise at full thrust for 4 s, then brake with `brake` (zero: stop dead), and
## return the camera's lead over the mech (focus x minus mech x) on every tick
## after braking starts.
func _leads_after_braking(brake: Vector2) -> Array[float]:
	var follow: LazyFollow = LazyFollow.new()
	follow.snap(Vector3.ZERO)
	var dz: Vector2 = CameraRig.dead_zone_for(CameraRig.DISTANCE, 16.0 / 9.0)
	var v: Vector3 = Vector3.ZERO
	var p: Vector3 = Vector3.ZERO
	for _i: int in 240:
		v = FlightModel.step_velocity(v, Vector2.RIGHT, TICK, _tuning)
		p += v * TICK
		var _cruising: Vector3 = follow.step(p, v, dz, TICK)
	var leads: Array[float] = []
	for _i: int in 240:
		if brake == Vector2.ZERO or v.x <= 0.0:
			v = Vector3.ZERO
		else:
			# Reverse thrust brakes to a stop, never past it.
			v = FlightModel.step_velocity(v, brake, TICK, _tuning)
			v = Vector3(maxf(v.x, 0.0), 0.0, 0.0)
		p += v * TICK
		leads.append(follow.step(p, v, dz, TICK).x - p.x)
	return leads


func _growth_steps(leads: Array[float]) -> int:
	var grew: int = 0
	for i: int in range(1, leads.size()):
		if leads[i] > leads[i - 1] + 1e-5:
			grew += 1
	return grew


func test_camera_does_not_overshoot_a_braking_mech() -> void:
	var cruise_lead: float = _tuning.speed * LazyFollow.LOOKAHEAD
	var stop_dead: Array[float] = _leads_after_braking(Vector2.ZERO)
	var reverse: Array[float] = _leads_after_braking(Vector2.LEFT)
	# The camera never runs further ahead of a braking mech than its cruise
	# lookahead, and once braking starts its lead only shrinks.
	var stop_peak: float = stop_dead.max()
	var reverse_peak: float = reverse.max()
	var _stop_bound: GdUnitAssert = assert_float(stop_peak).is_less_equal(cruise_lead + 0.05)
	var _stop_shrinks: GdUnitAssert = assert_int(_growth_steps(stop_dead)).is_equal(0)
	var _reverse_bound: GdUnitAssert = assert_float(reverse_peak).is_less_equal(cruise_lead + 0.05)
	var _reverse_shrinks: GdUnitAssert = assert_int(_growth_steps(reverse)).is_equal(0)
	var _settles: GdUnitAssert = assert_float(absf(stop_dead[-1])).is_less(0.5)
