extends GdUnitTestSuite
## Gravity shots: they inherit the mech's velocity, arc under gravity, expire,
## and are pooled (#22, #73).

const TICK: float = 1.0 / 60.0

var _tuning: MechTuning = MechTuning.new()


func test_shot_inherits_sixty_percent_of_mech_velocity() -> void:
	var carrier: Vector3 = Vector3(4.0, -2.0, 0.0)
	var v: Vector3 = Ballistics.launch_velocity(
		Vector3.RIGHT, carrier, _tuning.shot_speed, _tuning.shot_inherit
	)
	var expected: Vector3 = Vector3.RIGHT * _tuning.shot_speed + carrier * 0.6
	var _inherit: GdUnitAssert = assert_float(_tuning.shot_inherit).is_equal(0.6)
	var _velocity: GdUnitAssert = assert_vector(v).is_equal_approx(expected, Vector3.ONE * 1e-5)


func test_shot_launch_stays_on_the_play_plane() -> void:
	var v: Vector3 = Ballistics.launch_velocity(
		Vector3(1.0, 1.0, 0.5), Vector3(0.0, 0.0, 3.0), _tuning.shot_speed, _tuning.shot_inherit
	)
	var _flat: GdUnitAssert = assert_float(v.z).is_equal(0.0)
	var _speed: GdUnitAssert = assert_float(v.length()).is_equal_approx(_tuning.shot_speed, 1e-4)


func test_shot_falls_under_bullet_gravity() -> void:
	var shot: PlayerShot = PlayerShot.new()
	add_child(shot)
	shot.launch(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), _tuning.shot_life, _tuning.shot_gravity)
	for _i: int in 30:
		shot.step(TICK)
	var vel: Vector3 = shot.velocity
	var pos: Vector3 = shot.position
	shot.free()
	var _vx: GdUnitAssert = assert_float(vel.x).is_equal_approx(10.0, 1e-5)
	var _vy: GdUnitAssert = assert_float(vel.y).is_equal_approx(-_tuning.shot_gravity * 0.5, 1e-4)
	var _drops: GdUnitAssert = assert_float(pos.y).is_less(-1.0)
	var _travels: GdUnitAssert = assert_float(pos.x).is_equal_approx(5.0, 1e-4)


func test_shot_expires_after_its_lifetime() -> void:
	var shot: PlayerShot = PlayerShot.new()
	add_child(shot)
	shot.launch(Vector3.ZERO, Vector3.RIGHT, _tuning.shot_life, _tuning.shot_gravity)
	var ticks_alive: int = 0
	while shot.is_live() and ticks_alive < 1000:
		shot.step(TICK)
		ticks_alive += 1
	shot.free()
	var _life: GdUnitAssert = assert_float(_tuning.shot_life).is_equal_approx(1.4 / 0.75, 1e-6)
	# It dies on the first tick at or past its lifetime, not a tick later.
	var _expires: GdUnitAssert = assert_float(ticks_alive * TICK).is_between(
		_tuning.shot_life - 1e-4, _tuning.shot_life + TICK
	)


func test_shot_pool_reuses_expired_shots() -> void:
	var pool: ShotPool = ShotPool.new()
	add_child(pool)
	var first: PlayerShot = pool.fire(Vector3.ZERO, Vector3.RIGHT, 0.05, 0.0)
	for _i: int in 10:
		pool.step(TICK)
	var live_after_expiry: int = pool.live_count()
	var second: PlayerShot = pool.fire(Vector3.ZERO, Vector3.RIGHT, 0.05, 0.0)
	var reused: bool = first == second
	var size: int = pool.pooled_count()
	pool.free()
	var _expired: GdUnitAssert = assert_int(live_after_expiry).is_equal(0)
	var _reused: GdUnitAssert = assert_bool(reused).is_true()
	var _one_node: GdUnitAssert = assert_int(size).is_equal(1)


func test_parked_shot_cannot_hit_anything() -> void:
	var pool: ShotPool = ShotPool.new()
	add_child(pool)
	var shot: PlayerShot = pool.fire(Vector3.ZERO, Vector3.RIGHT, 0.05, 0.0)
	var live_layer: int = shot.collision_layer
	for _i: int in 10:
		pool.step(TICK)
	var parked_layer: int = shot.collision_layer
	var parked_mask: int = shot.collision_mask
	var hidden: bool = not shot.visible
	pool.free()
	var _live: GdUnitAssert = assert_int(live_layer).is_equal(PhysicsLayers.PLAYER_SHOTS)
	var _parked: GdUnitAssert = assert_int(parked_layer | parked_mask).is_equal(0)
	var _hidden: GdUnitAssert = assert_bool(hidden).is_true()
