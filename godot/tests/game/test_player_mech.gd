extends GdUnitTestSuite
## The player mech node: it flies, fires gravity shots that inherit its velocity,
## reacts to hits, collects repairs and breaks apart on death (#22, #73).

const TICK: float = 1.0 / 60.0

var _fired: Array[Vector3] = []
var _hits: Array[DamageSource.Source] = []
var _repairs: Array[Vector3] = []
var _samples: int = 0


func before_test() -> void:
	_fired.clear()
	_hits.clear()
	_repairs.clear()
	_samples = 0


func _mech() -> PlayerMech:
	var mech: PlayerMech = PlayerMech.new()
	mech.tuning = MechTuning.new()
	mech.tuning.shot_spread = 0.0
	mech.rng.seed = 7
	add_child(mech)
	return mech


func _intent(move: Vector2, aim: Vector2, firing: bool) -> PilotIntent:
	var intent: PilotIntent = PilotIntent.new()
	intent.move = move
	intent.aim = aim
	intent.firing = firing
	return intent


func _on_fired(_origin: Vector3, direction: Vector3) -> void:
	_fired.append(direction)


func _on_hit(source: DamageSource.Source, _position: Vector3, _attack_damage: int) -> void:
	_hits.append(source)


func _on_repaired(position: Vector3) -> void:
	_repairs.append(position)


func _on_sample(_sample: MechMotionSample) -> void:
	_samples += 1


func test_coasting_mech_drifts_down_with_no_input() -> void:
	var mech: PlayerMech = _mech()
	mech.velocity = Vector3.ZERO
	var start: float = mech.position.y
	for _i: int in 60:
		mech.tick(TICK, PilotIntent.new())
	var fell: float = start - mech.position.y
	mech.free()
	var _falls: GdUnitAssert = assert_float(fell).is_greater(1.0)


func test_holding_fire_shoots_ten_per_second() -> void:
	var mech: PlayerMech = _mech()
	var err: Error = mech.fired.connect(_on_fired) as Error
	for _i: int in 60:
		mech.tick(TICK, _intent(Vector2.ZERO, Vector2.RIGHT, true))
	mech.free()
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _cadence: GdUnitAssert = assert_int(_fired.size()).is_equal(10)


func test_fired_shot_inherits_the_mech_velocity() -> void:
	var mech: PlayerMech = _mech()
	var pool: ShotPool = ShotPool.new()
	add_child(pool)
	mech.shots = pool
	mech.velocity = Vector3(6.0, 3.0, 0.0)
	# Coast one tick while firing straight up, then read the shot's launch velocity.
	var coasted: Vector3 = FlightModel.step_velocity(mech.velocity, Vector2.ZERO, TICK, mech.tuning)
	mech.tick(TICK, _intent(Vector2.ZERO, Vector2(0.0, 1.0), true))
	var shot_velocity: Vector3 = _first_shot(pool).velocity
	var expected: Vector3 = Vector3.UP * mech.tuning.shot_speed + coasted * 0.6
	mech.free()
	pool.free()
	var _inherits: GdUnitAssert = assert_vector(shot_velocity).is_equal_approx(
		expected, Vector3.ONE * 1e-4
	)


func _first_shot(pool: ShotPool) -> PlayerShot:
	return pool.live_shots()[0]


func test_firing_recoils_the_mech_against_the_aim() -> void:
	var mech: PlayerMech = _mech()
	mech.velocity = Vector3.ZERO
	mech.tick(TICK, _intent(Vector2.ZERO, Vector2.RIGHT, true))
	var vx: float = mech.velocity.x
	mech.free()
	var _recoil: GdUnitAssert = assert_float(vx).is_equal_approx(-mech_recoil(), 1e-4)


func mech_recoil() -> float:
	return MechTuning.new().recoil


func test_aim_is_independent_of_movement() -> void:
	var mech: PlayerMech = _mech()
	for _i: int in 30:
		mech.tick(TICK, _intent(Vector2.RIGHT, Vector2.LEFT, true))
	var aim: Vector3 = mech.aim_direction
	var vx: float = mech.velocity.x
	var facing: float = mech.facing
	mech.free()
	var _aims_back: GdUnitAssert = assert_vector(aim).is_equal_approx(
		Vector3.LEFT, Vector3.ONE * 1e-4
	)
	var _flies_forward: GdUnitAssert = assert_float(vx).is_greater(0.0)
	var _faces_aim: GdUnitAssert = assert_float(facing).is_equal(-1.0)


func test_hit_reaction_guards_flashes_and_knocks_back() -> void:
	var mech: PlayerMech = _mech()
	var err: Error = mech.hit_taken.connect(_on_hit) as Error
	mech.velocity = Vector3.ZERO
	var first: bool = mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	var flashed: bool = mech.model().is_flashing()
	var knocked: float = mech.velocity.x
	var second: bool = mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	for _i: int in 40:
		mech.tick(TICK, PilotIntent.new())
	var third: bool = mech.take_hit(DamageSource.Source.ENEMY_COLLISION, Vector3.RIGHT)
	mech.free()
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _lands: GdUnitAssert = assert_bool(first).is_true()
	var _flash: GdUnitAssert = assert_bool(flashed).is_true()
	var _knockback: GdUnitAssert = assert_float(knocked).is_less(-1.0)
	var _guarded: GdUnitAssert = assert_bool(second).is_false()
	var _after_window: GdUnitAssert = assert_bool(third).is_true()
	var _reported: GdUnitAssert = assert_array(_hits).is_equal(
		[DamageSource.Source.ENEMY_BULLET, DamageSource.Source.ENEMY_COLLISION]
	)


func test_invulnerable_mech_blinks_then_shows_solid() -> void:
	var mech: PlayerMech = _mech()
	var _hit: bool = mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	var hidden_frames: int = 0
	for _i: int in 36:
		mech.tick(TICK, PilotIntent.new())
		if not mech.model().visible:
			hidden_frames += 1
	mech.tick(TICK, PilotIntent.new())
	var solid: bool = mech.model().visible and not mech.is_invulnerable()
	mech.free()
	var _blinked: GdUnitAssert = assert_int(hidden_frames).is_greater(5)
	var _solid: GdUnitAssert = assert_bool(solid).is_true()


func test_respawn_grants_two_seconds_of_invulnerability() -> void:
	var mech: PlayerMech = _mech()
	mech.destroy()
	mech.respawn(Vector3(3.0, 4.0, 0.0))
	var guarded: bool = mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	for _i: int in 119:
		mech.tick(TICK, PilotIntent.new())
	var still: bool = mech.is_invulnerable()
	for _i: int in 2:
		mech.tick(TICK, PilotIntent.new())
	var open: bool = mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	mech.free()
	var _guarded: GdUnitAssert = assert_bool(guarded).is_false()
	var _still: GdUnitAssert = assert_bool(still).is_true()
	var _open: GdUnitAssert = assert_bool(open).is_true()


func test_repair_kit_pickup_is_reported() -> void:
	var mech: PlayerMech = _mech()
	var err: Error = mech.repaired.connect(_on_repaired) as Error
	mech.position = Vector3(2.0, 1.0, 0.0)
	mech.repair()
	mech.free()
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _reported: GdUnitAssert = assert_array(_repairs).is_equal([Vector3(2.0, 1.0, 0.0)])


func test_death_breaks_the_mech_into_a_falling_ragdoll() -> void:
	var mech: PlayerMech = _mech()
	var debris: MechDebris = MechDebris.new()
	add_child(debris)
	mech.debris = debris
	mech.destroy()
	var pieces: int = debris.piece_count()
	var parts: int = mech.model().meshes().size()
	for _i: int in 20:
		debris.step(TICK)
	var early: float = debris.mean_height()
	for _i: int in 60:
		debris.step(TICK)
	var later: float = debris.mean_height()
	var hidden: bool = not mech.model().visible
	var inert: bool = not mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	mech.free()
	debris.free()
	var _every_part: GdUnitAssert = assert_int(pieces).is_equal(parts)
	var _hidden: GdUnitAssert = assert_bool(hidden).is_true()
	var _falls: GdUnitAssert = assert_float(later).is_less(early)
	var _inert: GdUnitAssert = assert_bool(inert).is_true()


func test_mech_reports_motion_every_tick() -> void:
	var mech: PlayerMech = _mech()
	var err: Error = mech.motion_sampled.connect(_on_sample) as Error
	for _i: int in 5:
		mech.tick(TICK, PilotIntent.new())
	mech.free()
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _sampled: GdUnitAssert = assert_int(_samples).is_equal(5)


func test_thrusting_blends_the_limbs_into_the_flying_pose() -> void:
	var mech: PlayerMech = _mech()
	for _i: int in 60:
		mech.tick(TICK, _intent(Vector2.RIGHT, Vector2.ZERO, false))
	var thrusting_fly: float = mech.animator().fly
	var thrust_thigh: float = mech.animator().thigh_angle(0)
	for _i: int in 120:
		mech.tick(TICK, PilotIntent.new())
	var coasting_fly: float = mech.animator().fly
	mech.free()
	var _flying: GdUnitAssert = assert_float(thrusting_fly).is_equal(1.0)
	# Streamlined: thighs swept back toward the thrust rest (negative).
	var _swept: GdUnitAssert = assert_float(thrust_thigh).is_less(-0.3)
	var _coasting: GdUnitAssert = assert_float(coasting_fly).is_equal(0.0)


func test_mech_model_has_the_original_flight_design() -> void:
	var model: MechModel = MechModel.new()
	var eyes: int = model.eyes.size()
	var wings: int = model.wings.size()
	var mains: int = model.main_nozzles.size()
	var feet: int = model.foot_nozzles.size()
	var tips: int = model.wing_tips.size()
	model.free()
	var _three_eyes: GdUnitAssert = assert_int(eyes).is_equal(3)
	var _binder_wings: GdUnitAssert = assert_int(wings).is_equal(2)
	var _wing_thrusters: GdUnitAssert = assert_int(mains).is_equal(2)
	var _foot_thrusters: GdUnitAssert = assert_int(feet).is_equal(2)
	var _tips: GdUnitAssert = assert_int(tips).is_equal(2)
