extends GdUnitTestSuite
## The lazy camera's hard safe frame (#104): the mech never leaves it at any
## speed, aspect or frame rate, the frame follows the live FOV, distance and
## aspect, the camera still lags and recentres, and a snap starts centred and still.

const TICK: float = 1.0 / 60.0
## The safe-frame flights: knockback shoves every SHOVE_EVERY s, and seeded
## random flights of RANDOM_LEGS legs, each a coast with COAST_CHANCE.
const SHOVE_EVERY: float = 1.5
const RANDOM_FLIGHTS: int = 12
const RANDOM_LEGS: int = 24
const COAST_CHANCE: float = 0.15
const RANDOM_FLIGHT_SEED: int = 104
## The boosts that force the clamp at 60 fps: BOOST times top speed for
## BOOST_TIME s, then CRUISE_TIME s at top speed, along each of BOOST_DIRECTIONS.
const BOOST: float = 20.0
const BOOST_TIME: float = 1.5
const CRUISE_TIME: float = 1.5
const BOOST_DIRECTIONS: Array[Vector3] = [
	Vector3.RIGHT, Vector3.DOWN, Vector3(-1.0, 1.0, 0.0), Vector3(1.0, -0.4, 0.0)
]
## Seconds of steady cruise in the recentre test.
const RECENTRE_FLIGHT: float = 8.0

var _tuning: MechTuning = MechTuning.new()


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
	var frame_error: float = 0.0
	var rig_error: float = 0.0
	var punched_screen: float = 0.0
	var hit_jump: float = 0.0
	# Tall phone portrait to super-ultrawide.
	for aspect: float in [9.0 / 20.0, 9.0 / 16.0, 1.0, 16.0 / 9.0, 21.0 / 9.0, 32.0 / 9.0]:
		var d: float = CameraRig.distance_for_aspect(aspect)
		# The frame's half extents project to SAFE_FRAME_SHARE of the screen for
		# any FOV, from a camera fitted for this aspect.
		for fov: float in [45.0, CameraRig.FOV, 75.0]:
			var half: Vector2 = CameraRig.safe_frame_for(d, aspect, fov)
			var proj: Projection = Projection.create_perspective(
				fov, aspect, CameraRig.NEAR, CameraRig.FAR
			)
			var clip: Vector4 = proj * Vector4(half.x, half.y, -d, 1.0)
			var miss: Vector2 = (
				(Vector2(clip.x / clip.w, clip.y / clip.w) - Vector2(share, share)).abs()
			)
			frame_error = maxf(frame_error, maxf(miss.x, miss.y))
		# A mech flung far down-right in one frame ends exactly on the rig's safe
		# frame corner, at SAFE_FRAME_SHARE of the screen.
		var far: Vector3 = Vector3(500.0, -300.0, 0.0)
		var rig: CameraRig = _held_at_edge(aspect, far)
		var s: Vector2 = _screen_of(rig, far, aspect)
		rig_error = maxf(rig_error, maxf(absf(s.x - share), absf(s.y + share)))
		# The same frame then hit by an FOV punch: the punch never narrows the
		# frame (it uses the resting FOV), so the camera goes exactly where it
		# would have gone without the hit, and the mech stays on screen.
		rig.advance(TICK, far, Vector3.ZERO)
		var unhit: Vector3 = rig.camera().global_position
		rig.free()
		for punch: float in [4.0, 14.0]:
			var hit: CameraRig = _held_at_edge(aspect, far)
			hit.punch_fov(punch)
			hit.advance(TICK, far, Vector3.ZERO)
			hit_jump = maxf(hit_jump, (hit.camera().global_position - unhit).length())
			var on: Vector2 = _screen_of(hit, far, aspect).abs()
			punched_screen = maxf(punched_screen, maxf(on.x, on.y))
			hit.free()
	var _derived: GdUnitAssert = assert_float(frame_error).is_less(1e-4)
	var _held_on_edge: GdUnitAssert = assert_float(rig_error).is_less(1e-3)
	var _no_jump_on_hit: GdUnitAssert = assert_float(hit_jump).is_less(1e-3)
	var _on_screen: GdUnitAssert = assert_float(punched_screen).is_less(1.0)


## A rig at `aspect` whose mech was flung from the centre to `far` in one frame,
## so the safe frame holds it on the frame's edge.
func _held_at_edge(aspect: float, far: Vector3) -> CameraRig:
	var rig: CameraRig = CameraRig.new()
	add_child(rig)
	rig.set_view_aspect(aspect)
	rig.snap_to(Vector3.ZERO)
	rig.advance(TICK, far, Vector3.ZERO)
	return rig


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


## A mech shot along `dir` at BOOST times its top speed for BOOST_TIME seconds,
## far past anything the camera's spring can follow, then cruising at top speed,
## in frames of `ticks_per_frame` physics ticks. Returns per frame: the mech's
## furthest screen offset from centre (NDC, either axis), the camera's speed
## along `dir` and the mech's.
func _boosted(aspect: float, dir: Vector3, ticks_per_frame: int) -> Array[Vector3]:
	var rig: CameraRig = CameraRig.new()
	add_child(rig)
	rig.set_view_aspect(aspect)
	rig.snap_to(Vector3.ZERO)
	var p: Vector3 = Vector3.ZERO
	var frame: float = TICK * ticks_per_frame
	var last: Vector3 = rig.camera().global_position
	var rows: Array[Vector3] = []
	var t: float = 0.0
	while t < BOOST_TIME + CRUISE_TIME:
		var boosting: bool = t < BOOST_TIME
		var v: Vector3 = dir * _tuning.speed * (BOOST if boosting else 1.0)
		p += v * frame
		t += frame
		rig.advance(frame, p, v)
		var cam: Vector3 = rig.camera().global_position
		var s: Vector2 = _screen_of(rig, p, aspect).abs()
		rows.append(Vector3(maxf(s.x, s.y), (cam - last).dot(dir) / frame, v.dot(dir)))
		last = cam
	rig.free()
	return rows


func test_clamp_holds_the_limit_at_60_fps() -> void:
	var share: float = CameraRig.SAFE_FRAME_SHARE
	var worst: float = 0.0
	var least_reach: float = INF
	for aspect: float in [9.0 / 20.0, 16.0 / 9.0, 32.0 / 9.0]:
		for dir: Vector3 in BOOST_DIRECTIONS:
			var reach: float = 0.0
			for row: Vector3 in _boosted(aspect, dir.normalized(), 1):
				reach = maxf(reach, row.x)
			worst = maxf(worst, reach)
			least_reach = minf(least_reach, reach)
	# Every boost drives the mech onto the safe frame at a normal frame rate,
	# and none gets past it.
	var _engaged: GdUnitAssert = assert_float(least_reach).is_greater_equal(share - 1e-3)
	var _held: GdUnitAssert = assert_float(worst).is_less_equal(share + 1e-4)


func test_camera_does_not_snap_back_when_clamp_lets_go() -> void:
	var share: float = CameraRig.SAFE_FRAME_SHARE
	var released: int = 0
	var runs: int = 0
	var slowest_lead: float = INF
	var back_to_edge: int = 0
	for aspect: float in [9.0 / 20.0, 16.0 / 9.0]:
		for dir: Vector3 in BOOST_DIRECTIONS:
			runs += 1
			var rows: Array[Vector3] = _boosted(aspect, dir.normalized(), 1)
			var engaged: bool = false
			var let_go: bool = false
			for i: int in range(1, rows.size()):
				var row: Vector3 = rows[i]
				var on_edge: bool = row.x >= share - 1e-4
				engaged = engaged or on_edge
				if engaged and not on_edge and not let_go:
					let_go = true
					released += 1
				# Once the clamp lets go, while the boost holds, the camera
				# keeps at least the mech's pace: it never drops back, and
				# the mech never slides back onto the edge.
				if let_go and row.z == rows[i - 1].z and row.z > _tuning.speed * 2.0:
					slowest_lead = minf(slowest_lead, row.y - row.z)
					if on_edge:
						back_to_edge += 1
	var _every_run_releases: GdUnitAssert = assert_int(released).is_equal(runs)
	var _keeps_pace: GdUnitAssert = assert_float(slowest_lead).is_greater_equal(-1e-3)
	var _stays_off_edge: GdUnitAssert = assert_int(back_to_edge).is_equal(0)
