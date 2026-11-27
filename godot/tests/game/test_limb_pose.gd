extends GdUnitTestSuite
## Spring limbs: a stiff, streamlined pose while thrusting and a loose, dangling
## one while coasting, blended over POSE_BLEND_TIME (#22).

const TICK: float = 1.0 / 60.0


func test_pose_blend_endpoints_are_the_coast_and_thrust_constants() -> void:
	var coast: LimbPose = LimbPose.blend(0.0)
	var thrust: LimbPose = LimbPose.blend(1.0)
	var _coast_thigh: GdUnitAssert = assert_float(coast.thigh_rest).is_equal(
		LimbPose.COAST_THIGH_REST
	)
	var _coast_wing: GdUnitAssert = assert_float(coast.wing_rest).is_equal(LimbPose.COAST_WING_REST)
	var _coast_leg: GdUnitAssert = assert_vector(coast.leg_spring).is_equal(
		LimbPose.COAST_LEG_SPRING
	)
	var _thrust_thigh: GdUnitAssert = assert_float(thrust.thigh_rest).is_equal(
		LimbPose.THRUST_THIGH_REST
	)
	var _thrust_arm: GdUnitAssert = assert_float(thrust.arm_rest).is_equal(LimbPose.THRUST_ARM_REST)
	var _thrust_leg: GdUnitAssert = assert_vector(thrust.leg_spring).is_equal(
		LimbPose.THRUST_LEG_SPRING
	)
	var _thrust_lag: GdUnitAssert = assert_float(thrust.vel_lag).is_equal_approx(
		LimbPose.THRUST_VEL_LAG, 1e-9
	)


func test_pose_blend_midpoint_interpolates_every_value() -> void:
	var mid: LimbPose = LimbPose.blend(0.5)
	var thigh: float = (LimbPose.COAST_THIGH_REST + LimbPose.THRUST_THIGH_REST) * 0.5
	var shin: float = (LimbPose.COAST_SHIN_REST + LimbPose.THRUST_SHIN_REST) * 0.5
	var arm_k: Vector2 = (LimbPose.COAST_ARM_SPRING + LimbPose.THRUST_ARM_SPRING) * 0.5
	var acc: float = (LimbPose.COAST_ACC_LAG + LimbPose.THRUST_ACC_LAG) * 0.5
	var _thigh: GdUnitAssert = assert_float(mid.thigh_rest).is_equal_approx(thigh, 1e-6)
	var _shin: GdUnitAssert = assert_float(mid.shin_rest).is_equal_approx(shin, 1e-6)
	var _arm: GdUnitAssert = assert_vector(mid.arm_spring).is_equal_approx(
		arm_k, Vector2.ONE * 1e-5
	)
	var _acc: GdUnitAssert = assert_float(mid.acc_lag).is_equal_approx(acc, 1e-6)
	var _hang: GdUnitAssert = assert_float(mid.hang).is_equal_approx(
		LimbPose.COAST_GRAVITY * 0.5, 1e-6
	)


func test_pose_blend_clamps_outside_zero_to_one() -> void:
	var under: LimbPose = LimbPose.blend(-1.0)
	var over: LimbPose = LimbPose.blend(2.0)
	var _under: GdUnitAssert = assert_float(under.thigh_rest).is_equal(LimbPose.COAST_THIGH_REST)
	var _over: GdUnitAssert = assert_float(over.thigh_rest).is_equal(LimbPose.THRUST_THIGH_REST)


func test_thrusting_pose_is_stiffer_than_coasting() -> void:
	var _legs: GdUnitAssert = assert_float(LimbPose.THRUST_LEG_SPRING.x).is_greater(
		LimbPose.COAST_LEG_SPRING.x * 4.0
	)
	var _arms: GdUnitAssert = assert_float(LimbPose.THRUST_ARM_SPRING.y).is_greater(
		LimbPose.COAST_ARM_SPRING.y * 4.0
	)


func test_pose_blend_takes_pose_blend_time() -> void:
	var fly: float = 0.0
	var ticks: int = 0
	while fly < 1.0 and ticks < 600:
		fly = LimbPose.advance_fly(fly, true, TICK)
		ticks += 1
	var down: float = LimbPose.advance_fly(1.0, false, LimbPose.POSE_BLEND_TIME * 0.5)
	var _time: GdUnitAssert = assert_float(ticks * TICK).is_equal_approx(
		LimbPose.POSE_BLEND_TIME, TICK
	)
	var _half_back: GdUnitAssert = assert_float(down).is_equal_approx(0.5, 1e-5)


func test_limb_spring_settles_on_its_target() -> void:
	var spring: LimbSpring = LimbSpring.new()
	for _i: int in 240:
		spring.step(0.5, 0.0, LimbPose.THRUST_LEG_SPRING, TICK)
	var _settled: GdUnitAssert = assert_float(spring.angle).is_equal_approx(0.5, 1e-3)
	var _still: GdUnitAssert = assert_float(absf(spring.velocity)).is_less(1e-2)


func test_coasting_limbs_lag_and_overshoot() -> void:
	# Loose springs swing past the rest when released: the flail of coasting.
	var loose: LimbSpring = LimbSpring.new()
	var stiff: LimbSpring = LimbSpring.new()
	var loose_peak: float = 0.0
	var stiff_peak: float = 0.0
	for _i: int in 120:
		loose.step(0.5, 0.0, LimbPose.COAST_LEG_SPRING, TICK)
		stiff.step(0.5, 0.0, LimbPose.THRUST_LEG_SPRING, TICK)
		loose_peak = maxf(loose_peak, loose.angle)
		stiff_peak = maxf(stiff_peak, stiff.angle)
	var _overshoots: GdUnitAssert = assert_float(loose_peak).is_greater(0.75)
	var _controlled: GdUnitAssert = assert_float(stiff_peak).is_less(0.6)


func test_limb_spring_is_clamped_to_its_joint_range() -> void:
	var spring: LimbSpring = LimbSpring.new()
	for _i: int in 60:
		spring.step(10.0, 50.0, LimbPose.COAST_LEG_SPRING, TICK)
	var _clamped: GdUnitAssert = assert_float(spring.angle).is_equal(LimbSpring.MAX_ANGLE)


func test_kick_adds_angular_velocity() -> void:
	var spring: LimbSpring = LimbSpring.new()
	spring.kick(2.0)
	var _kicked: GdUnitAssert = assert_float(spring.velocity).is_equal(2.0)
