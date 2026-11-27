extends GdUnitTestSuite
## The enemy field (#23, #73): spawn orders become enemies, the six kinds fly
## and fight as #73 describes, shots and crashes destroy them with the right
## cause, enemies never collide with each other, and the Play Sphere despawns
## whatever flies out of it.

const STEP: float = FieldHarness.STEP
## How closely (radians) a lobbed shell must follow the solved arc.
const ARC_TOLERANCE: float = 0.01

var _h: FieldHarness


func before_test() -> void:
	_h = FieldHarness.new()
	add_child(_h.field)
	_h.enter_level(1)


func after_test() -> void:
	_h.dispose()


func _watch(enemy: Enemy, record: FireLog) -> void:
	var errs: Array[int] = [
		enemy.telegraphed.connect(record.on_telegraphed),
		enemy.fired.connect(record.on_fired),
	]
	var _ok: GdUnitAssert = assert_int(errs.count(OK)).is_equal(errs.size())


func _advance_logged(seconds: float, record: FireLog) -> void:
	var left: float = seconds
	while left > 1e-6:
		record.clock += STEP
		_h.field.step(STEP)
		left -= STEP


func test_spawn_order_places_enemy_and_reports_it() -> void:
	_h.target.at = Vector3(5.0, -3.0, 0.0)
	var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, PI / 2.0, 25.0)
	var second: Enemy = _h.order(EnemyKind.Kind.FIGHTER, PI, 20.0)
	var _one_each: GdUnitAssert = assert_int(_h.spawn_positions.size()).is_equal(2)
	var _distinct_ids: GdUnitAssert = assert_int(second.enemy_id).is_not_equal(enemy.enemy_id)
	# Angle 90 degrees is straight above the player on the play plane.
	var _above: GdUnitAssert = assert_vector(_h.spawn_positions[0]).is_equal_approx(
		Vector3(5.0, 22.0, 0.0), Vector3.ONE * 1e-4
	)
	var _left: GdUnitAssert = assert_vector(_h.spawn_positions[1]).is_equal_approx(
		Vector3(-15.0, -3.0, 0.0), Vector3.ONE * 1e-4
	)
	# It heads in toward the player.
	var _inbound: GdUnitAssert = assert_float(enemy.velocity.y).is_less(0.0)


func test_every_enemy_kind_spawns_with_its_profile() -> void:
	var hit_points: Dictionary[EnemyKind.Kind, int] = {}
	for kind: EnemyKind.Kind in EnemyKind.Kind.values():
		var enemy: Enemy = _h.order(kind, 0.0, 20.0)
		hit_points[kind] = enemy.hit_points
		var _kind_kept: GdUnitAssert = assert_int(enemy.kind).is_equal(kind)
		var _has_look: GdUnitAssert = assert_object(enemy.look()).is_not_null()
	var _six: GdUnitAssert = assert_int(_h.field.active_enemies().size()).is_equal(6)
	var _heavy_4: GdUnitAssert = assert_int(hit_points[EnemyKind.Kind.HEAVY]).is_equal(4)
	var _drone_1: GdUnitAssert = assert_int(hit_points[EnemyKind.Kind.DRONE]).is_equal(1)
	var _fighter_1: GdUnitAssert = assert_int(hit_points[EnemyKind.Kind.FIGHTER]).is_equal(1)
	# Every kind but the Fighter and the Drone (contact only) has a gun.
	for kind: EnemyKind.Kind in EnemyKind.Kind.values():
		var armed: bool = EnemyProfile.of(kind).attack != EnemyProfile.Attack.NONE
		var unarmed_kind: bool = kind == EnemyKind.Kind.FIGHTER or kind == EnemyKind.Kind.DRONE
		var _armed: GdUnitAssert = assert_bool(armed).is_equal(not unarmed_kind)


func test_fighter_chases_the_player() -> void:
	var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 25.0)
	var start: float = enemy.position.length()
	_h.advance(1.0)
	var closed_to: float = enemy.position.length()
	# The player jumps 30 units up; the Fighter must turn after it.
	var moved_to: Vector3 = Vector3(0.0, 30.0, 0.0)
	_h.target.at = moved_to
	var gap_at_move: float = enemy.position.distance_to(moved_to)
	_h.advance(2.0)
	var toward: Vector3 = FiringSolution.aimed(enemy.position, moved_to)
	var heading: Vector3 = enemy.velocity.normalized()
	var _closes_in: GdUnitAssert = assert_float(closed_to).is_less(start - 4.0)
	# Heading within 45 degrees of the new position (a lazy turn stays heading -X).
	var _turned: GdUnitAssert = assert_float(heading.dot(toward)).is_greater(cos(PI / 4.0))
	# And it actually closes on the new position.
	var _closes_again: GdUnitAssert = assert_float(enemy.position.distance_to(moved_to)).is_less(
		gap_at_move - 5.0
	)


func test_heavy_takes_four_shots() -> void:
	var enemy: Enemy = _h.order(EnemyKind.Kind.HEAVY, 0.0, 20.0)
	var landed: Array[bool] = []
	var alive_after: Array[bool] = []
	for _i: int in 4:
		landed.append(_h.field.resolve_shot(enemy.position, 0.3, Vector3.LEFT))
		alive_after.append(enemy.is_active())
	var _all_hit: GdUnitAssert = assert_array(landed).is_equal([true, true, true, true])
	var _dies_on_fourth: GdUnitAssert = assert_array(alive_after).is_equal(
		[true, true, true, false]
	)
	var _four_hits_reported: GdUnitAssert = assert_int(_h.hits.size()).is_equal(4)


func test_interceptor_keeps_its_distance_and_fires_arcing_shots() -> void:
	var enemy: Enemy = _h.order(EnemyKind.Kind.INTERCEPTOR, 0.0, 25.0, 1.0)
	var record: FireLog = FireLog.new()
	_watch(enemy, record)
	var spec: ShotSpec = EnemyProfile.of(EnemyKind.Kind.INTERCEPTOR).shot
	var launches: int = 0
	var on_arc: int = 0
	var lifted: int = 0
	for _i: int in roundi(20.0 / STEP):
		_advance_logged(STEP, record)
		for shell: EnemyShot in _h.field.shots().live_shots():
			# A shell launched this tick: its flight began on the solved arc.
			if shell.life_left < spec.life - STEP * 1.5:
				continue
			launches += 1
			var solved: Vector3 = FiringSolution.arc(
				shell.position, _h.target.at, spec.speed, spec.gravity
			)
			var straight: Vector3 = FiringSolution.aimed(shell.position, _h.target.at)
			var launch: Vector3 = shell.velocity.normalized()
			# On the solved arc to within a hundredth of a radian...
			if launch.angle_to(solved) < ARC_TOLERANCE:
				on_arc += 1
			# ...which, but for close shots, is clearly above the straight aim.
			if launch.y > straight.y + ARC_TOLERANCE * 2.0:
				lifted += 1
	var gap: float = enemy.position.distance_to(_h.target.at)
	var standoff: float = EnemyProfile.of(EnemyKind.Kind.INTERCEPTOR).standoff
	var _holds_off: GdUnitAssert = assert_float(gap).is_between(standoff * 0.6, standoff * 1.5)
	var _fired: GdUnitAssert = assert_int(launches).is_greater_equal(5)
	var _every_shell_on_arc: GdUnitAssert = assert_int(on_arc).is_equal(launches)
	var _lobbed_high: GdUnitAssert = assert_int(lifted).is_greater_equal(floori(launches * 0.5))
	var _not_rammed: GdUnitAssert = assert_bool(_h.destroyed.is_empty()).is_true()
	# Lobbed on the arc, the shells land on a player who holds still.
	var _shells_land: GdUnitAssert = assert_int(_h.player_hits.size()).is_greater_equal(
		floori(launches * 0.5)
	)


func test_drone_homes_and_explodes_on_contact() -> void:
	var profile: EnemyProfile = EnemyProfile.of(EnemyKind.Kind.DRONE)
	var enemy: Enemy = _h.order(EnemyKind.Kind.DRONE, 0.0, 20.0)
	var id: int = enemy.enemy_id
	var launch_speed: float = enemy.velocity.length()
	_h.advance(0.25)
	var early_speed: float = enemy.velocity.length()
	_h.advance(0.75)
	var later_speed: float = enemy.velocity.length()
	# The player dodges up; the drone follows it in.
	_h.target.at = Vector3(0.0, 8.0, 0.0)
	var guard: int = 0
	while enemy.is_active() and guard < 600:
		_h.field.step(STEP)
		guard += 1
	# It launches slow and accelerates toward its top speed (a missile, not a chaser).
	var _launches_slow: GdUnitAssert = assert_float(launch_speed).is_equal_approx(
		profile.speed_min, 1e-4
	)
	var _accelerates: GdUnitAssert = assert_float(early_speed).is_less_equal(
		profile.speed_min + profile.acceleration * 0.25 + 1e-3
	)
	var _speeds_up: GdUnitAssert = assert_float(later_speed).is_greater(
		profile.speed_min + profile.acceleration * 0.5
	)
	var _capped: GdUnitAssert = assert_float(later_speed).is_less_equal(profile.speed_max + 1e-3)
	var _exploded: GdUnitAssert = assert_bool(_h.destroyed.has(id)).is_true()
	var _as_a_crash: GdUnitAssert = assert_int(_h.destroyed[id]).is_equal(
		DestroyCause.Cause.COLLISION
	)
	var _missile_damage: GdUnitAssert = assert_array(_h.player_hits).is_equal(
		[DamageSource.Source.MISSILE]
	)
	var _armor: GdUnitAssert = assert_array(_h.target.damage_taken).is_equal(
		[RunRules.MISSILE_DAMAGE]
	)


func test_bomber_crosses_and_drops_bombs() -> void:
	# From the left, it crosses above the player toward the right.
	var enemy: Enemy = _h.order(EnemyKind.Kind.BOMBER, PI, 20.0, 1.0)
	var record: FireLog = FireLog.new()
	_watch(enemy, record)
	var bomb_seen: bool = false
	var falling: bool = true
	var guard: int = 0
	while enemy.position.x < 12.0 and guard < 1200:
		_advance_logged(STEP, record)
		for shot: EnemyShot in _h.field.shots().live_shots():
			bomb_seen = bomb_seen or shot.spec.style == ShotSpec.Style.BOMB
			falling = falling and shot.velocity.y < 0.0
		guard += 1
	var altitude: float = EnemyProfile.of(EnemyKind.Kind.BOMBER).altitude
	var _crossed: GdUnitAssert = assert_float(enemy.position.x).is_greater_equal(12.0)
	var _above: GdUnitAssert = assert_float(enemy.position.y).is_greater(altitude * 0.5)
	var _bombed: GdUnitAssert = assert_bool(bomb_seen).is_true()
	var _bombs_fall: GdUnitAssert = assert_bool(falling).is_true()
	var _flat_course: GdUnitAssert = assert_float(absf(enemy.velocity.y)).is_less(
		absf(enemy.velocity.x)
	)


func test_bomber_bomb_hits_with_bomb_damage() -> void:
	# A wide stand-in, so a carpet spaced a few units apart must hit it.
	_h.target.contact = 1.5
	var enemy: Enemy = _h.order(EnemyKind.Kind.BOMBER, PI, 20.0, 1.0)
	var guard: int = 0
	while _h.player_hits.is_empty() and enemy.position.x < 20.0 and guard < 1500:
		_h.field.step(STEP)
		guard += 1
	var _bomb_source: GdUnitAssert = assert_array(_h.player_hits).is_equal(
		[DamageSource.Source.BOMB]
	)


func test_enemy_mech_strafes_and_fires_three_way_spreads() -> void:
	var enemy: Enemy = _h.order(EnemyKind.Kind.ENEMY_MECH, 0.0, 20.0, 0.5)
	var record: FireLog = FireLog.new()
	_watch(enemy, record)
	var heights: Array[float] = []
	var volley_sizes: Array[int] = []
	var seen_shots: int = 0
	for _i: int in 360:
		_advance_logged(STEP, record)
		heights.append(enemy.position.y)
		if record.shots.size() > seen_shots:
			seen_shots = record.shots.size()
			volley_sizes.append(_h.field.shots().live_shots().size())
	var low: float = heights.min()
	var high: float = heights.max()
	var standoff: float = EnemyProfile.of(EnemyKind.Kind.ENEMY_MECH).standoff
	var _beside: GdUnitAssert = assert_float(absf(enemy.position.x)).is_between(
		standoff * 0.6, standoff * 1.5
	)
	var _sweeps: GdUnitAssert = assert_float(high - low).is_greater(3.0)
	var _fires: GdUnitAssert = assert_int(volley_sizes.size()).is_greater_equal(2)
	# Each volley adds three bullets.
	var _three_way: GdUnitAssert = assert_int(volley_sizes[0]).is_equal(3)


func test_enemy_attacks_are_telegraphed() -> void:
	var armed: Array[EnemyKind.Kind] = [
		EnemyKind.Kind.HEAVY,
		EnemyKind.Kind.INTERCEPTOR,
		EnemyKind.Kind.BOMBER,
		EnemyKind.Kind.ENEMY_MECH,
	]
	var logs: Array[FireLog] = []
	var glows: Array[float] = []
	for kind: EnemyKind.Kind in armed:
		var angle: float = PI if kind == EnemyKind.Kind.BOMBER else 0.0
		var enemy: Enemy = _h.order(kind, angle, 18.0, 1.0)
		var record: FireLog = FireLog.new()
		_watch(enemy, record)
		logs.append(record)
		var charge_glow: float = 0.0
		for _i: int in 600:
			_advance_logged(STEP, record)
			if enemy.is_telegraphing():
				charge_glow = maxf(charge_glow, enemy.look().glow_energy())
		glows.append(charge_glow)
		enemy.telegraphed.disconnect(record.on_telegraphed)
		enemy.fired.disconnect(record.on_fired)
		_h.field.clear()
	for i: int in logs.size():
		var _fired: GdUnitAssert = assert_int(logs[i].shots.size()).is_greater(0)
		for charged: float in logs[i].charged_for:
			var _telegraphed: GdUnitAssert = assert_float(charged).is_greater_equal(
				RunRules.MIN_TELEGRAPH - 1e-6
			)
		var _glows: GdUnitAssert = assert_float(glows[i]).is_greater(EnemyLook.GLOW_IDLE * 4.0)


func test_projectile_destroys_enemy_with_shot_cause() -> void:
	var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 20.0)
	var id: int = enemy.enemy_id
	var miss: bool = _h.field.resolve_shot(
		enemy.position + Vector3(0.0, 5.0, 0.0), 0.3, Vector3.LEFT
	)
	var hit: bool = _h.field.resolve_shot(enemy.position, 0.3, Vector3.LEFT)
	var again: bool = _h.field.resolve_shot(enemy.position, 0.3, Vector3.LEFT)
	var _missed: GdUnitAssert = assert_bool(miss).is_false()
	var _hit: GdUnitAssert = assert_bool(hit).is_true()
	var _gone: GdUnitAssert = assert_bool(again).is_false()
	var _shot_cause: GdUnitAssert = assert_int(_h.destroyed[id]).is_equal(DestroyCause.Cause.SHOT)
	var _accuracy_hit: GdUnitAssert = assert_array(_h.hits).is_equal([id])
	var _no_player_damage: GdUnitAssert = assert_array(_h.player_hits).is_empty()


func test_crash_destroys_enemy_with_collision_cause_and_damages_player() -> void:
	var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 3.0)
	var id: int = enemy.enemy_id
	var guard: int = 0
	while enemy.is_active() and guard < 300:
		_h.field.step(STEP)
		guard += 1
	# While invulnerable, a crash still destroys the enemy but deals nothing.
	_h.target.invulnerable = true
	var second: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 3.0)
	var second_id: int = second.enemy_id
	guard = 0
	while second.is_active() and guard < 300:
		_h.field.step(STEP)
		guard += 1
	var _collision: GdUnitAssert = assert_int(_h.destroyed[id]).is_equal(
		DestroyCause.Cause.COLLISION
	)
	var _both: GdUnitAssert = assert_int(_h.destroyed[second_id]).is_equal(
		DestroyCause.Cause.COLLISION
	)
	var _once: GdUnitAssert = assert_array(_h.player_hits).is_equal(
		[DamageSource.Source.ENEMY_COLLISION]
	)
	var _armor: GdUnitAssert = assert_array(_h.target.damage_taken).is_equal(
		[RunRules.COLLISION_DAMAGE]
	)


func test_enemies_do_not_collide_with_each_other() -> void:
	# Two Heavies on top of each other, far from the player.
	_h.target.at = Vector3(0.0, -30.0, 0.0)
	var first: Enemy = _h.order(EnemyKind.Kind.HEAVY, PI / 2.0, 25.0)
	var second: Enemy = _h.order(EnemyKind.Kind.HEAVY, PI / 2.0, 25.0)
	var overlap: float = first.position.distance_to(second.position)
	_h.advance(1.0)
	var _overlapping: GdUnitAssert = assert_float(overlap).is_less(first.radius())
	var _first_lives: GdUnitAssert = assert_bool(first.is_active()).is_true()
	var _second_lives: GdUnitAssert = assert_bool(second.is_active()).is_true()
	var _none_destroyed: GdUnitAssert = assert_bool(_h.destroyed.is_empty()).is_true()


func test_enemy_outside_play_sphere_despawns() -> void:
	var radius: float = _h.levels[0].play_sphere_radius
	var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 25.0)
	var id: int = enemy.enemy_id
	_h.field.step(STEP)
	var inside: bool = enemy.is_active()
	# The player flies away faster than the Fighter can follow.
	_h.target.at = Vector3(-radius - 30.0, 0.0, 0.0)
	_h.field.step(STEP)
	var _was_inside: GdUnitAssert = assert_bool(inside).is_true()
	var _despawned: GdUnitAssert = assert_bool(enemy.is_active()).is_false()
	var _reported: GdUnitAssert = assert_array(_h.left_sphere).is_equal([id])
	var _not_a_kill: GdUnitAssert = assert_bool(_h.destroyed.has(id)).is_false()


func test_enemies_hold_fire_while_player_destroyed() -> void:
	var enemy: Enemy = _h.order(EnemyKind.Kind.HEAVY, 0.0, 6.0, 1.0)
	_h.target.alive = false
	var record: FireLog = FireLog.new()
	_watch(enemy, record)
	_advance_logged(6.0, record)
	var _no_telegraph: GdUnitAssert = assert_array(record.telegraphs).is_empty()
	var _no_crash: GdUnitAssert = assert_bool(enemy.is_active()).is_true()
	var _no_hits: GdUnitAssert = assert_array(_h.player_hits).is_empty()


func test_level_clear_clears_remaining_enemies() -> void:
	var _a: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 20.0)
	var heavy: Enemy = _h.order(EnemyKind.Kind.HEAVY, 1.0, 20.0, 1.0)
	_h.advance(1.0)
	var _in_flight: EnemyShot = _h.field.shots().fire(
		EnemyProfile.of(EnemyKind.Kind.HEAVY).shot,
		Vector3(0.0, 15.0, 0.0),
		Vector3.UP,
		1.0,
		Vector3.ZERO
	)
	var shots_before: int = _h.field.shots().live_shots().size()
	_h.bus.flow.announce_game_state_changed(GameState.Phase.BOSS_FIGHT, GameState.Phase.LEVEL_CLEAR)
	var _had_shots: GdUnitAssert = assert_int(shots_before).is_greater(0)
	var _cleared: GdUnitAssert = assert_array(_h.field.active_enemies()).is_empty()
	var _no_shots: GdUnitAssert = assert_array(_h.field.shots().live_shots()).is_empty()
	var _silent: GdUnitAssert = assert_bool(_h.destroyed.has(heavy.enemy_id)).is_false()


func test_field_reuses_parked_enemies() -> void:
	for _i: int in 5:
		var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 20.0)
		var _hit: bool = _h.field.resolve_shot(enemy.position, 0.3, Vector3.LEFT)
	var _pooled: GdUnitAssert = assert_int(_h.field.pooled_count()).is_equal(1)
	var _five_ids: GdUnitAssert = assert_int(_h.destroyed.size()).is_equal(5)
