extends GdUnitTestSuite
## The mech's motion juice: layered flames that grow with thrust, eye trails
## that streak with speed, and vapor only on hard turns (#22).

const TICK: float = 1.0 / 60.0


func _sample(velocity: Vector3, lateral_g: float, thrust: float) -> MechMotionSample:
	var s: MechMotionSample = MechMotionSample.new()
	s.velocity = velocity
	s.lateral_g = lateral_g
	s.thrust = thrust
	s.delta = TICK
	s.wing_tips = PackedVector3Array([Vector3(-0.5, 0.5, 0.0), Vector3(0.5, 0.5, 0.0)])
	return s


func _flame() -> ThrusterFlame:
	var flame: ThrusterFlame = ThrusterFlame.new()
	add_child(flame)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	flame.setup(1.0, true, rng)
	return flame


func test_flame_grows_with_thrust() -> void:
	var flame: ThrusterFlame = _flame()
	for _i: int in 60:
		flame.drive(0.0, TICK)
	var idle: float = flame.plume_length()
	var idle_power: float = flame.power
	for _i: int in 60:
		flame.drive(1.0, TICK)
	var full: float = flame.plume_length()
	flame.free()
	var _pilot_light: GdUnitAssert = assert_float(idle_power).is_equal_approx(
		ThrusterFlame.IDLE_POWER, 0.01
	)
	var _grows: GdUnitAssert = assert_float(full).is_greater(idle * 2.5)


func test_flame_eases_instead_of_snapping() -> void:
	var flame: ThrusterFlame = _flame()
	for _i: int in 60:
		flame.drive(0.0, TICK)
	flame.drive(1.0, TICK)
	var first_tick: float = flame.power
	flame.free()
	var _eased: GdUnitAssert = assert_float(first_tick).is_less(0.5)


func test_vapor_cone_appears_on_hard_turns() -> void:
	var vapor: VaporCone = VaporCone.new()
	add_child(vapor)
	for _i: int in 30:
		vapor.on_motion(_sample(Vector3(8.0, 0.0, 0.0), VaporCone.G_FULL, 1.0))
	var strength: float = vapor.strength
	var shown: bool = vapor.cone_visible()
	vapor.free()
	var _strong: GdUnitAssert = assert_float(strength).is_greater(0.9)
	var _shown: GdUnitAssert = assert_bool(shown).is_true()


func test_vapor_stays_off_in_gentle_or_slow_flight() -> void:
	var vapor: VaporCone = VaporCone.new()
	add_child(vapor)
	for _i: int in 30:
		vapor.on_motion(_sample(Vector3(8.0, 0.0, 0.0), VaporCone.G_MIN * 0.5, 1.0))
	var gentle: bool = vapor.cone_visible()
	for _i: int in 30:
		vapor.on_motion(_sample(Vector3(1.0, 0.0, 0.0), VaporCone.G_FULL, 1.0))
	var slow: float = vapor.strength
	vapor.free()
	var _gentle: GdUnitAssert = assert_bool(gentle).is_false()
	var _slow: GdUnitAssert = assert_float(slow).is_equal(0.0)


func test_mech_feedback_mounts_flames_and_eye_trails_on_the_model() -> void:
	var model: MechModel = MechModel.new()
	add_child(model)
	var fx: MechFeedback = MechFeedback.new()
	add_child(fx)
	fx.attach(
		model.main_nozzles,
		MechModel.WING_FLAME_SIZE,
		model.foot_nozzles,
		MechModel.FOOT_FLAME_SIZE,
		model.eyes
	)
	var flames: int = fx.flames().size()
	var trails: int = fx.eye_trails().size()
	fx.on_motion(_sample(Vector3(8.0, 0.0, 0.0), 0.0, 1.0))
	var streaking: bool = fx.eye_trails()[0].emitting
	fx.on_motion(_sample(Vector3.ZERO, 0.0, 0.0))
	var still: bool = fx.eye_trails()[0].emitting
	fx.free()
	model.free()
	var _four_flames: GdUnitAssert = assert_int(flames).is_equal(4)
	var _three_trails: GdUnitAssert = assert_int(trails).is_equal(3)
	var _streak: GdUnitAssert = assert_bool(streaking).is_true()
	var _rest: GdUnitAssert = assert_bool(still).is_false()


func test_destroyed_mech_loses_its_flames() -> void:
	var model: MechModel = MechModel.new()
	add_child(model)
	var fx: MechFeedback = MechFeedback.new()
	add_child(fx)
	fx.attach(model.main_nozzles, 1.0, model.foot_nozzles, 0.5, model.eyes)
	fx.on_destroyed()
	var dark: bool = not fx.flames()[0].visible
	fx.on_respawned()
	var lit: bool = fx.flames()[0].visible
	fx.free()
	model.free()
	var _dark: GdUnitAssert = assert_bool(dark).is_true()
	var _lit: GdUnitAssert = assert_bool(lit).is_true()
