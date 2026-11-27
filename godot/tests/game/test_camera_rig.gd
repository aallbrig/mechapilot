extends GdUnitTestSuite
## The lazy camera: a dead zone, a critically damped follow that lags, a recentre
## once the mech's velocity is steady, and a wider view in portrait (#22).

const TICK: float = 1.0 / 60.0
const DEAD_ZONE: Vector2 = Vector2(6.0, 4.0)
## The safe-frame flights: knockback shoves every SHOVE_EVERY s, and seeded
## random flights of RANDOM_LEGS legs, each a coast with COAST_CHANCE.
const SHOVE_EVERY: float = 1.5
const RANDOM_FLIGHTS: int = 12
const RANDOM_LEGS: int = 24
const COAST_CHANCE: float = 0.15
const RANDOM_FLIGHT_SEED: int = 104
## Seconds of steady cruise in the recentre test.
const RECENTRE_FLIGHT: float = 8.0

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


## Where `point` lands on screen for the rig's camera, in normalised device
## coordinates (-1..1 on each axis), worked out from the camera's own transform
## and FOV through a perspective projection at `aspect`.
func _screen_of(rig: CameraRig, point: Vector3, aspect: float) -> Vector2:
	var cam: Camera3D = rig.camera()
	var proj: Projection = Projection.create_perspective(cam.fov, aspect, cam.near, cam.far)
	var local: Vector3 = cam.global_transform.affine_inverse() * point
	var clip: Vector4 = proj * Vector4(local.x, local.y, local.z, 1.0)
	return Vector2(clip.x / clip.w, clip.y / clip.w)


func _max_axes(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(maxf(absf(a.x), absf(b.x)), maxf(absf(a.y), absf(b.y)))


## Fly the mech through `legs` ([stick, seconds] pairs) in frames of
## `ticks_per_frame` physics ticks, as Godot runs a slow frame. The camera
## advances once per frame, capped at CameraRig.MAX_STEP like the rig's _process.
## Knockback shoves (every SHOVE_EVERY s, alternating) and continuous fire
## straight behind the mech (recoil along its travel) push it past its top speed.
## Returns the furthest the mech strays from screen centre per axis (NDC).
func _fly(aspect: float, ticks_per_frame: int, legs: Array[Array]) -> Vector2:
	var rig: CameraRig = CameraRig.new()
	add_child(rig)
	rig.set_view_aspect(aspect)
	var p: Vector3 = Vector3.ZERO
	var v: Vector3 = _tuning.spawn_velocity
	rig.snap_to(p)
	var worst: Vector2 = Vector2.ZERO
	var since_shot: float = 0.0
	var since_shove: float = 0.0
	var shove_sign: float = 1.0
	var frame: float = TICK * ticks_per_frame
	for leg: Array in legs:
		var stick: Vector2 = leg[0]
		var seconds: float = leg[1]
		for _f: int in ceili(seconds / frame):
			for _t: int in ticks_per_frame:
				v = FlightModel.step_velocity(v, stick, TICK, _tuning)
				since_shot += TICK
				since_shove += TICK
				if since_shot >= _tuning.fire_interval and v.length() > 0.0:
					since_shot = 0.0
					v += v.normalized() * _tuning.recoil
				if since_shove >= SHOVE_EVERY:
					since_shove = 0.0
					shove_sign = -shove_sign
					v += Vector3(shove_sign, 0.0, 0.0) * _tuning.knockback
				p += v * TICK
			rig.advance(minf(frame, CameraRig.MAX_STEP), p, v)
			worst = _max_axes(worst, _screen_of(rig, p, aspect))
	rig.free()
	return worst


## A seeded random flight: a new stick direction (or a coast) every 0.05..1.5 s.
func _random_legs(rng: RandomNumberGenerator) -> Array[Array]:
	var legs: Array[Array] = []
	for _i: int in RANDOM_LEGS:
		var a: float = rng.randf() * TAU
		var stick: Vector2 = Vector2(cos(a), sin(a)) if rng.randf() > COAST_CHANCE else Vector2.ZERO
		legs.append([stick, rng.randf_range(0.05, 1.5)])
	return legs


func test_mech_never_leaves_safe_frame_at_max_speed() -> void:
	var scripted: Array[Array] = [
		[Vector2.RIGHT, 3.0],
		[Vector2.LEFT, 3.0],  # a full-speed reversal
		[Vector2.RIGHT, 2.0],
		[Vector2.UP, 2.5],
		[Vector2.DOWN, 2.5],  # a vertical reversal
		[Vector2(1.0, 1.0).normalized(), 2.0],
		[Vector2(-1.0, -1.0).normalized(), 2.0],
		[Vector2.ZERO, 2.0],  # coasting into a fall
		[Vector2(-1.0, 1.0).normalized(), 2.0],
	]
	var flights: Array[Array] = [scripted]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = RANDOM_FLIGHT_SEED
	for _i: int in RANDOM_FLIGHTS:
		flights.append(_random_legs(rng))
	var worst: Vector2 = Vector2.ZERO
	# Tall phone portrait, square, landscape and super-ultrawide, at 60, 30 and
	# 5 fps (a struggling phone or a tab hitch, where the camera's step is capped).
	for aspect: float in [9.0 / 20.0, 1.0, 16.0 / 9.0, 32.0 / 9.0]:
		for ticks_per_frame: int in [1, 2, 12]:
			for legs: Array[Array] in flights:
				worst = _max_axes(worst, _fly(aspect, ticks_per_frame, legs))
	# The mech's centre never crosses the safe frame on either axis, and the safe
	# frame leaves room on screen for the mech's whole body.
	var share: float = CameraRig.SAFE_FRAME_SHARE
	var _x: GdUnitAssert = assert_float(worst.x).is_less_equal(share + 1e-4)
	var _y: GdUnitAssert = assert_float(worst.y).is_less_equal(share + 1e-4)
	var _room: GdUnitAssert = assert_float(share).is_less_equal(0.8)
	var _not_cramped: GdUnitAssert = assert_float(share).is_greater(CameraRig.DEAD_ZONE_SHARE * 2.0)


func test_safe_frame_scales_with_aspect_and_fov() -> void:
	var share: float = CameraRig.SAFE_FRAME_SHARE
	var rig_error: float = 0.0
	var frame_error: float = 0.0
	# Tall phone portrait to super-ultrawide, at rest and under hit and death FOV
	# punches.
	for aspect: float in [9.0 / 20.0, 9.0 / 16.0, 1.0, 16.0 / 9.0, 21.0 / 9.0, 32.0 / 9.0]:
		for punch: float in [0.0, 4.0, 14.0]:
			# A mech flung far down-right in one frame ends exactly on the safe
			# frame's corner, wherever that is on this screen.
			var rig: CameraRig = CameraRig.new()
			add_child(rig)
			rig.set_view_aspect(aspect)
			rig.snap_to(Vector3.ZERO)
			rig.punch_fov(punch)
			var far: Vector3 = Vector3(500.0, -300.0, 0.0)
			rig.advance(TICK, far, Vector3.ZERO)
			var s: Vector2 = _screen_of(rig, far, aspect)
			rig.free()
			rig_error = maxf(rig_error, maxf(absf(s.x - share), absf(s.y + share)))
			# The frame's own half extents project to the same corner from a
			# camera DISTANCE-fitted for this aspect.
			var fov: float = CameraRig.FOV - punch
			var d: float = CameraRig.distance_for_aspect(aspect)
			var half: Vector2 = CameraRig.safe_frame_for(d, aspect, fov)
			var proj: Projection = Projection.create_perspective(
				fov, aspect, CameraRig.NEAR, CameraRig.FAR
			)
			var clip: Vector4 = proj * Vector4(half.x, half.y, -d, 1.0)
			var corner: Vector2 = Vector2(clip.x / clip.w, clip.y / clip.w)
			var miss: Vector2 = (corner - Vector2(share, share)).abs()
			frame_error = maxf(frame_error, maxf(miss.x, miss.y))
	var _held_on_edge: GdUnitAssert = assert_float(rig_error).is_less(1e-3)
	var _derived: GdUnitAssert = assert_float(frame_error).is_less(1e-4)


## The mech's offset from where the camera centres it (its lead point, LOOKAHEAD
## seconds ahead), per axis, in world units.
func _off_lead(rig: CameraRig, p: Vector3, v: Vector3) -> Vector2:
	var cam: Vector3 = rig.camera().global_position
	var lead: Vector3 = p + v * LazyFollow.LOOKAHEAD
	return Vector2(cam.x - lead.x, cam.y - lead.y)


func test_camera_still_lags_and_recentres() -> void:
	for aspect: float in [9.0 / 20.0, 16.0 / 9.0]:
		var rig: CameraRig = CameraRig.new()
		add_child(rig)
		rig.set_view_aspect(aspect)
		rig.snap_to(Vector3.ZERO)
		var dz: Vector2 = CameraRig.dead_zone_for(CameraRig.distance_for_aspect(aspect), aspect)
		# A sudden hop inside the dead zone: the camera barely moves at first.
		var hop: Vector3 = Vector3(dz.x * 0.6, 0.0, 0.0)
		for _i: int in 6:
			rig.advance(TICK, hop, Vector3.ZERO)
		var hop_follow: float = rig.camera().global_position.x
		rig.snap_to(Vector3.ZERO)
		# Then a cruise from rest at full thrust: the camera falls behind, and
		# RECENTER seconds after the mech's velocity turns steady (within 1% of
		# cruise) it has it back within half the dead zone of centre.
		var stick: Vector2 = Vector2(1.0, -0.3).normalized()
		var cruise: Vector3 = Vector3(stick.x, stick.y, 0.0) * _tuning.speed
		var p: Vector3 = Vector3.ZERO
		var v: Vector3 = Vector3.ZERO
		var peak: float = 0.0
		var steady_at: float = -1.0
		var at_recenter: Vector2 = Vector2.INF
		var t: float = 0.0
		while t < RECENTRE_FLIGHT:
			v = FlightModel.step_velocity(v, stick, TICK, _tuning)
			p += v * TICK
			t += TICK
			rig.advance(TICK, p, v)
			var off: Vector2 = _off_lead(rig, p, v)
			peak = maxf(peak, off.length())
			if steady_at < 0.0 and (v - cruise).length() <= cruise.length() * 0.01:
				steady_at = t
			if (
				steady_at >= 0.0
				and at_recenter == Vector2.INF
				and t >= steady_at + LazyFollow.RECENTER
			):
				at_recenter = off.abs()
		var settled: Vector2 = _off_lead(rig, p, v)
		var screen: Vector2 = _screen_of(rig, p, aspect)
		rig.free()
		var _hop_lags: GdUnitAssert = assert_float(hop_follow).is_less(hop.x * 0.05)
		var _lags: GdUnitAssert = assert_float(peak).is_greater(dz.y * 0.5)
		var _recentred_x: GdUnitAssert = assert_float(at_recenter.x).is_less_equal(dz.x * 0.5)
		var _recentred_y: GdUnitAssert = assert_float(at_recenter.y).is_less_equal(dz.y * 0.5)
		var _settles: GdUnitAssert = assert_float(settled.length()).is_less(0.25)
		# Centred on the lead point, the mech sits behind centre along its travel,
		# so more of what is ahead is on screen.
		var _leads_x: GdUnitAssert = assert_float(screen.x).is_less(0.0)
		var _leads_y: GdUnitAssert = assert_float(screen.y).is_greater(0.0)


func test_snap_centres_mech_without_jump() -> void:
	var rig: CameraRig = CameraRig.new()
	add_child(rig)
	var aspect: float = 16.0 / 9.0
	rig.set_view_aspect(aspect)
	rig.snap_to(Vector3.ZERO)
	# Fly hard, take a death's worth of juice (shake, kick, FOV punch) ...
	var p: Vector3 = Vector3.ZERO
	var v: Vector3 = Vector3.ZERO
	for _i: int in 120:
		v = FlightModel.step_velocity(v, Vector2.RIGHT, TICK, _tuning)
		p += v * TICK
		rig.advance(TICK, p, v)
	rig.add_trauma(1.0)
	rig.kick(Vector3(0.25, -0.25, 0.0))
	rig.punch_fov(14.0)
	rig.advance(TICK, p, v)
	# ... then respawn somewhere else, at rest.
	var spawn: Vector3 = Vector3(-40.0, 12.0, 0.0)
	rig.snap_to(spawn)
	var at_snap: Vector2 = _screen_of(rig, spawn, aspect)
	var fov_at_snap: float = rig.camera().fov
	# The mech hovers, then thrusts away: the camera never moves faster than
	# the mech's top speed, and the FOV holds still.
	p = spawn
	v = Vector3.ZERO
	var last: Vector3 = rig.camera().global_position
	var fastest: float = 0.0
	var fov_drift: float = 0.0
	for i: int in 120:
		if i >= 30:
			v = FlightModel.step_velocity(v, Vector2.LEFT, TICK, _tuning)
		p += v * TICK
		rig.advance(TICK, p, v)
		var now: Vector3 = rig.camera().global_position
		fastest = maxf(fastest, (now - last).length() / TICK)
		fov_drift = maxf(fov_drift, absf(rig.camera().fov - CameraRig.FOV))
		last = now
	rig.free()
	var _centred: GdUnitAssert = assert_vector(Vector3(at_snap.x, at_snap.y, 0.0)).is_equal_approx(
		Vector3.ZERO, Vector3.ONE * 1e-4
	)
	var _fov_reset: GdUnitAssert = assert_float(fov_at_snap).is_equal_approx(CameraRig.FOV, 1e-4)
	var _no_jump: GdUnitAssert = assert_float(fastest).is_less_equal(_tuning.speed * 2.0)
	var _fov_still: GdUnitAssert = assert_float(fov_drift).is_less(1e-4)
