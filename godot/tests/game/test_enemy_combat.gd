extends GdUnitTestSuite
## Enemy weapons (#23, #73): every attack is telegraphed at least 0.4 s before
## it fires, every enemy projectile falls under gravity, aimed arcing shots
## land on their target, and a projectile that reaches the player strikes it
## with its own damage source.

const STEP: float = 1.0 / 60.0

var _bus: EventBus
var _sources: Array[DamageSource.Source] = []


func before_test() -> void:
	_bus = EventBus.new()
	_sources.clear()
	var err: int = _bus.player.player_hit.connect(_on_player_hit)
	var _ok: GdUnitAssert = assert_int(err).is_equal(OK)


func after_test() -> void:
	_bus.free()


func _on_player_hit(source: DamageSource.Source, _position: Vector3, _damage: int) -> void:
	_sources.append(source)


func _bullet() -> ShotSpec:
	return EnemyProfile.of(EnemyKind.Kind.HEAVY).shot


func test_attack_cycle_telegraphs_before_every_shot() -> void:
	# The data asks for a 0.1 s telegraph; the rule floor is 0.4 s.
	var cycle: AttackCycle = AttackCycle.new(1.0, 0.1, 0.25)
	var clock: float = 0.0
	var charge_started: float = -1.0
	var charges: Array[float] = []
	var shots: Array[float] = []
	while clock < 10.0:
		clock += STEP
		match cycle.tick(STEP, true):
			AttackCycle.Step.TELEGRAPH:
				charge_started = clock
			AttackCycle.Step.FIRE:
				shots.append(clock)
				charges.append(clock - charge_started)
				charge_started = -1.0
			_:
				pass
	var _telegraph_floor: GdUnitAssert = assert_float(cycle.telegraph).is_equal(
		RunRules.MIN_TELEGRAPH
	)
	var _fires: GdUnitAssert = assert_int(shots.size()).is_between(9, 10)
	for charge: float in charges:
		var _charged: GdUnitAssert = assert_float(charge).is_greater_equal(
			RunRules.MIN_TELEGRAPH - 1e-6
		)
	for i: int in range(1, shots.size()):
		var _rhythm: GdUnitAssert = assert_float(shots[i] - shots[i - 1]).is_between(
			1.0 - 1e-6, 1.0 + STEP + 1e-6
		)


func test_attack_cycle_held_charge_starts_over() -> void:
	var cycle: AttackCycle = AttackCycle.new(1.0, 0.4, 0.0)
	var first: AttackCycle.Step = cycle.tick(STEP, true)
	for _i: int in 12:
		var _step: AttackCycle.Step = cycle.tick(STEP, true)
	var mid_charge: bool = cycle.is_telegraphing()
	# The target ducks out of range mid-charge: the charge is cancelled.
	var held: AttackCycle.Step = cycle.tick(STEP, false)
	var cancelled: bool = not cycle.is_telegraphing()
	var steps: Array[AttackCycle.Step] = []
	var fired_after: int = -1
	for i: int in 60:
		var step: AttackCycle.Step = cycle.tick(STEP, true)
		steps.append(step)
		if step == AttackCycle.Step.FIRE and fired_after < 0:
			fired_after = i
	var _started: GdUnitAssert = assert_int(first).is_equal(AttackCycle.Step.TELEGRAPH)
	var _was_charging: GdUnitAssert = assert_bool(mid_charge).is_true()
	var _no_shot_held: GdUnitAssert = assert_int(held).is_equal(AttackCycle.Step.NONE)
	var _cancelled: GdUnitAssert = assert_bool(cancelled).is_true()
	var _recharges: GdUnitAssert = assert_int(steps[0]).is_equal(AttackCycle.Step.TELEGRAPH)
	# A full fresh 0.4 s charge (24 ticks) before the shot.
	var _full_charge: GdUnitAssert = assert_int(fired_after).is_greater_equal(24)


func test_enemy_projectiles_obey_gravity() -> void:
	var pool: EnemyShotPool = EnemyShotPool.new()
	add_child(pool)
	var target: StandInTarget = StandInTarget.new(_bus)
	target.at = Vector3(1000.0, 1000.0, 0.0)
	var specs: Array[ShotSpec] = [
		_bullet(),
		EnemyProfile.of(EnemyKind.Kind.INTERCEPTOR).shot,
		EnemyProfile.of(EnemyKind.Kind.BOMBER).shot,
		EnemyProfile.of(EnemyKind.Kind.ENEMY_MECH).shot,
	]
	var launched: Array[EnemyShot] = []
	for spec: ShotSpec in specs:
		launched.append(pool.fire(spec, Vector3.ZERO, Vector3.RIGHT, 1.0, Vector3.ZERO))
	var seconds: float = 0.5
	for _i: int in roundi(seconds / STEP):
		pool.step(STEP, target)
	var drops: Array[float] = []
	var fall_speeds: Array[float] = []
	for shot: EnemyShot in launched:
		drops.append(shot.position.y)
		fall_speeds.append(shot.velocity.y)
	pool.free()
	# #73: every enemy projectile, bombs included, falls like the player's shots.
	var player_gravity: float = 20.0 * Pace.GAME_SPEED * Pace.GAME_SPEED
	for spec: ShotSpec in specs:
		var _like_the_player: GdUnitAssert = assert_float(spec.gravity).is_equal_approx(
			player_gravity, 1e-6
		)
	for i: int in specs.size():
		var gravity: float = specs[i].gravity
		var _has_gravity: GdUnitAssert = assert_float(gravity).is_greater(0.0)
		# v = -g t and y = -g t^2 / 2 (to the tick), from a level launch.
		var _falls_faster: GdUnitAssert = assert_float(fall_speeds[i]).is_equal_approx(
			-gravity * seconds, 1e-3
		)
		var _drops: GdUnitAssert = assert_float(drops[i]).is_equal_approx(
			-0.5 * gravity * seconds * seconds, gravity * seconds * STEP
		)


func test_arcing_shot_lands_on_its_target() -> void:
	var spec: ShotSpec = EnemyProfile.of(EnemyKind.Kind.INTERCEPTOR).shot
	var cases: Array[Vector3] = [
		Vector3(14.0, 0.0, 0.0), Vector3(-12.0, 5.0, 0.0), Vector3(16.0, -6.0, 0.0)
	]
	for goal: Vector3 in cases:
		var dir: Vector3 = FiringSolution.arc(Vector3.ZERO, goal, spec.speed, spec.gravity)
		var at: Vector3 = Vector3.ZERO
		var vel: Vector3 = dir * spec.speed
		var closest: float = INF
		for _i: int in 600:
			vel = Ballistics.fall(vel, spec.gravity, STEP / 4.0)
			at += vel * STEP / 4.0
			closest = minf(closest, at.distance_to(goal))
		var _lands: GdUnitAssert = assert_float(closest).is_less(spec.radius)
		# Aimed above a level target: shots drop, so the arc compensates.
		var _lifted: GdUnitAssert = assert_float(dir.y).is_greater(
			FiringSolution.aimed(Vector3.ZERO, goal).y
		)


func test_enemy_bullet_hit_damages_player_with_bullet_source() -> void:
	var pool: EnemyShotPool = EnemyShotPool.new()
	add_child(pool)
	var target: StandInTarget = StandInTarget.new(_bus)
	target.at = Vector3(3.0, 0.0, 0.0)
	var bomb: ShotSpec = EnemyProfile.of(EnemyKind.Kind.BOMBER).shot
	var _shot: EnemyShot = pool.fire(_bullet(), Vector3.ZERO, Vector3.RIGHT, 1.0, Vector3.ZERO)
	for _i: int in 30:
		pool.step(STEP, target)
	var after_bullet: int = pool.live_shots().size()
	var _bomb: EnemyShot = pool.fire(bomb, Vector3(3.0, 2.0, 0.0), Vector3.DOWN, 1.0, Vector3.ZERO)
	for _i: int in 90:
		pool.step(STEP, target)
	# A destroyed player is not hit, and the shot flies on.
	target.alive = false
	var _late: EnemyShot = pool.fire(_bullet(), Vector3.ZERO, Vector3.RIGHT, 1.0, Vector3.ZERO)
	for _i: int in 30:
		pool.step(STEP, target)
	pool.free()
	var _spent: GdUnitAssert = assert_int(after_bullet).is_equal(0)
	var _sources_reported: GdUnitAssert = assert_array(_sources).is_equal(
		[DamageSource.Source.ENEMY_BULLET, DamageSource.Source.BOMB]
	)
	var _armor: GdUnitAssert = assert_array(target.damage_taken).is_equal(
		[RunRules.BULLET_DAMAGE, RunRules.BOMB_DAMAGE]
	)
