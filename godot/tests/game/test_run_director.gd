extends GdUnitTestSuite
## The assembled fight (#84): the real player mech, linked to the real rules,
## fights the enemy field and the boss arena through the RunDirector. Hits are
## counted once, shots kill and score through the RunLedger, and the boss's
## repeated contact is absorbed by the 0.6 s invulnerability window.

const STEP: float = FightHarness.STEP
## Close enough that the enemy overlaps the mech on its first step (units).
const ON_TOP: float = 0.5
## Far enough that a fresh enemy cannot reach the mech before the shot does.
const IN_RANGE: float = 9.0
## Off screen at any aspect (units from the player).
const FAR_AWAY: float = 60.0

var _h: FightHarness


func before_test() -> void:
	_h = FightHarness.new()
	add_child(_h.world)


func after_test() -> void:
	_h.dispose()


## How enemy `enemy_id` was destroyed, or -1 while it is not.
func _cause_of(enemy_id: int) -> int:
	return _h.destroyed[enemy_id] if _h.destroyed.has(enemy_id) else -1


func _firing_right() -> PilotIntent:
	var intent: PilotIntent = PilotIntent.new()
	intent.aim = Vector2.RIGHT
	intent.firing = true
	return intent


func test_player_hit_counts_once_end_to_end() -> void:
	_h.reach_skirmish()
	var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, ON_TOP)
	var enemy_id: int = enemy.enemy_id
	_h.advance(STEP * 3.0)
	var _one_hit: GdUnitAssert = assert_array(_h.player_hits).is_equal(
		[DamageSource.Source.ENEMY_COLLISION]
	)
	var _armor: GdUnitAssert = assert_int(_h.run.ledger.armor()).is_equal(
		RunRules.MAX_ARMOR - RunRules.COLLISION_DAMAGE
	)
	var _crashed: GdUnitAssert = assert_int(_cause_of(enemy_id)).is_equal(
		DestroyCause.Cause.COLLISION
	)
	var _guarded: GdUnitAssert = assert_bool(_h.mech.is_invulnerable()).is_true()


func test_player_shot_kills_enemy_and_scores() -> void:
	_h.reach_skirmish()
	var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, IN_RANGE)
	var enemy_id: int = enemy.enemy_id
	var elapsed: float = 0.0
	while not _h.destroyed.has(enemy_id) and elapsed < 2.0:
		_h.advance(STEP, _firing_right())
		elapsed += STEP
	var _shot_down: GdUnitAssert = assert_int(_cause_of(enemy_id)).is_equal(DestroyCause.Cause.SHOT)
	var _scored: GdUnitAssert = assert_int(_h.run.ledger.score()).is_equal(
		RunRules.kill_points(EnemyKind.Kind.FIGHTER)
	)
	var _no_damage: GdUnitAssert = assert_array(_h.player_hits).is_empty()


func test_boss_contact_damages_player_once_per_invulnerability_window() -> void:
	_h.reach_skirmish()
	_h.run.reach_boss_fight()
	var boss: Boss = _h.director.arena().boss()
	var entry: float = 0.0
	while boss != null and boss.state() == Boss.State.ENTERING and entry < 10.0:
		_h.advance(STEP)
		entry += STEP
	var hits_before: int = _h.player_hits.size()
	# Sit inside the boss's hull for one second: its contact strikes every frame.
	var frames: int = roundi(1.0 / STEP)
	for i: int in frames:
		_h.mech.position = boss.position
		_h.advance(STEP)
	var hits: int = _h.player_hits.size() - hits_before
	var windows: int = ceili(1.0 / RunRules.HIT_INVULNERABILITY)
	var _fighting: GdUnitAssert = assert_int(boss.state()).is_equal(Boss.State.FIGHTING)
	var _once_per_window: GdUnitAssert = assert_int(hits).is_equal(windows)
	var _armor: GdUnitAssert = assert_int(_h.run.ledger.armor()).is_greater_equal(
		RunRules.MAX_ARMOR - windows * RunRules.BOSS_ATTACK_DAMAGE_MAX
	)


func test_player_shot_damages_the_boss_through_the_referee() -> void:
	_h.reach_skirmish()
	_h.run.reach_boss_fight()
	var boss: Boss = _h.director.arena().boss()
	var entry: float = 0.0
	while boss.state() == Boss.State.ENTERING and entry < 10.0:
		_h.advance(STEP)
		entry += STEP
	var full: int = _h.run.boss_health.health()
	# Point blank: the mech sits just left of the boss's weak point, firing right.
	for i: int in roundi(0.5 / STEP):
		_h.mech.position = boss.weak_point() + Vector3.LEFT * boss.profile.hit_radius * 1.5
		_h.mech.velocity = Vector3.ZERO
		_h.advance(STEP, _firing_right())
	var _damaged: GdUnitAssert = assert_int(_h.run.boss_health.health()).is_less(full)


func test_run_director_points_indicators_at_off_screen_enemies() -> void:
	_h.reach_skirmish()
	var near: Enemy = _h.order(EnemyKind.Kind.HEAVY, PI * 0.5, IN_RANGE * 0.5)
	var far: Enemy = _h.order(EnemyKind.Kind.HEAVY, 0.0, FAR_AWAY)
	var indicators: OffscreenIndicators = _h.director.indicators()
	indicators.refresh()
	var _shown: GdUnitAssert = assert_int(indicators.shown_count()).is_equal(1)
	var _far_arrow: GdUnitAssert = assert_object(indicators.arrow_for(far.enemy_id)).is_not_null()
	var _near_none: GdUnitAssert = assert_object(indicators.arrow_for(near.enemy_id)).is_null()


func test_run_director_hides_indicators_outside_play() -> void:
	_h.reach_skirmish()
	var in_play: bool = _h.director.indicators().is_visible_in_tree()
	_h.bus.flow.announce_pause_requested()
	var paused: bool = _h.director.indicators().is_visible_in_tree()
	var _shown: GdUnitAssert = assert_bool(in_play).is_true()
	var _hidden: GdUnitAssert = assert_bool(paused).is_false()


## Strikes once a frame, from the current frame on, until a strike is counted by
## the ledger. Returns [phantom hits (announced, armor unchanged), counted hits].
func _strike_until_counted(seconds: float) -> Array[int]:
	var target: CombatTarget = _h.director.target()
	var phantom: int = 0
	var counted: int = 0
	for frame: int in roundi(seconds / STEP):
		var armor_before: int = _h.run.ledger.armor()
		var hits_before: int = _h.player_hits.size()
		var _struck: bool = target.strike(DamageSource.Source.ENEMY_BULLET, 0, Vector3.LEFT)
		if _h.player_hits.size() > hits_before:
			if _h.run.ledger.armor() == armor_before:
				phantom += 1
			else:
				counted += 1
				break
		_h.advance(STEP)
	return [phantom, counted]


func test_respawn_window_refuses_hits_until_the_ledger_window_ends() -> void:
	# The mech's copy of a window must never close before the RunLedger's:
	# otherwise strike() announces player_hit while the ledger ignores it.
	_h.reach_skirmish()
	var target: CombatTarget = _h.director.target()
	var guard: int = 0
	while not _h.run.ledger.is_down() and guard < 20:
		var _crash: bool = target.strike(DamageSource.Source.ENEMY_COLLISION, 0, Vector3.LEFT)
		_h.advance(RunRules.HIT_INVULNERABILITY + STEP)
		guard += 1
	while _h.run.ledger.is_down() and guard < 1000:
		_h.advance(STEP)
		guard += 1
	var result: Array[int] = _strike_until_counted(RunRules.RESPAWN_INVULNERABILITY + 0.5)
	var _respawned: GdUnitAssert = assert_bool(_h.mech.is_alive()).is_true()
	var _no_phantom: GdUnitAssert = assert_int(result[0]).is_equal(0)
	var _then_counted: GdUnitAssert = assert_int(result[1]).is_equal(1)


func test_hit_window_refuses_hits_until_the_ledger_window_ends() -> void:
	_h.reach_skirmish()
	var _first: bool = _h.director.target().strike(
		DamageSource.Source.ENEMY_BULLET, 0, Vector3.LEFT
	)
	_h.advance(STEP)
	var result: Array[int] = _strike_until_counted(RunRules.HIT_INVULNERABILITY + 0.5)
	var _no_phantom: GdUnitAssert = assert_int(result[0]).is_equal(0)
	var _then_counted: GdUnitAssert = assert_int(result[1]).is_equal(1)


func test_run_director_ticks_field_then_arena_then_referee() -> void:
	_h.reach_skirmish()
	# Field before referee: an enemy the field takes out of play this tick (it
	# left the Play Sphere) must not take a shot sitting on it.
	var leaving: Enemy = _h.order(
		EnemyKind.Kind.HEAVY, PI, _h.run.levels[0].play_sphere_radius - 1.0
	)
	_h.mech.position = Vector3.RIGHT * 5.0
	var _parked_shot: PlayerShot = _h.shots.fire(leaving.position, Vector3.ZERO, 1.0, 0.0)
	var hits: Array[int] = []
	var _heard: int = _h.bus.enemy.enemy_hit.connect(
		func(enemy_id: int, _at: Vector3) -> void: hits.append(enemy_id)
	)
	_h.director.step(STEP)
	var field_first: bool = not leaving.is_active() and hits.is_empty()
	# Arena before referee: on the tick the boss ends its entry, a shot on its
	# weak point already lands (an entering boss would deflect it).
	_h.mech.position = Vector3.ZERO
	_h.run.reach_boss_fight()
	var boss: Boss = _h.director.arena().boss()
	var damaged_on_entry_tick: bool = false
	var entered: bool = false
	var guard: int = 0
	while not entered and guard < 1000:
		var health_before: int = _h.run.boss_health.health()
		var _probe: PlayerShot = _h.shots.fire(boss.weak_point(), Vector3.ZERO, STEP * 0.5, 0.0)
		_h.director.step(STEP)
		entered = boss.state() == Boss.State.FIGHTING
		damaged_on_entry_tick = entered and _h.run.boss_health.health() < health_before
		_h.shots.step(STEP)
		guard += 1
	var _field: GdUnitAssert = assert_bool(field_first).is_true()
	var _arena: GdUnitAssert = assert_bool(damaged_on_entry_tick).is_true()
