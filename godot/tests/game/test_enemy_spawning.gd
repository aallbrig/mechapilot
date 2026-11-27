extends GdUnitTestSuite
## The enemy field driven by the real spawn director and Level progression
## (#23, #73): spawns follow the director and the Level's roster, stop during
## the Boss Warning (the survivors stay), stop while the player is destroyed,
## and shot kills (not crashes) drop Repair Kits.

const STEP: float = FieldHarness.STEP

var _h: FieldHarness
var _director: SpawnDirector


func before_test() -> void:
	_h = FieldHarness.new()
	add_child(_h.field)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = FieldHarness.SEED
	_director = SpawnDirector.new(_h.bus, rng, _h.levels)


func after_test() -> void:
	_h.dispose()


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 1e-6:
		_director.tick(STEP)
		_h.field.step(STEP)
		left -= STEP


func test_spawns_follow_the_director_and_the_level_roster() -> void:
	_h.enter_level(5)
	_h.target.invulnerable = true
	_advance(6.0)
	var roster: Array[EnemyKind.Kind] = []
	for entry: LevelDefinition.RosterEntry in _h.levels[4].roster:
		roster.append(entry.kind)
	var _spawned: GdUnitAssert = assert_int(_h.spawned.size()).is_greater(0)
	for kind: EnemyKind.Kind in _h.spawned.values():
		var _in_roster: GdUnitAssert = assert_bool(roster.has(kind)).is_true()
	# Every request was answered: the director's count matches the field's.
	var live: int = _h.field.active_enemies().size()
	var _answered: GdUnitAssert = assert_int(_director.live_count()).is_equal(live)


func test_spawns_pause_during_boss_warning_and_survivors_stay() -> void:
	_h.enter_level(1)
	_h.target.invulnerable = true
	_advance(3.0)
	var survivors: int = _h.field.active_enemies().size()
	var spawned_before: int = _h.spawned.size()
	_h.bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.BOSS_WARNING)
	_advance(RunRules.BOSS_WARNING_DURATION - STEP)
	var _had_enemies: GdUnitAssert = assert_int(survivors).is_greater(0)
	var _none_new: GdUnitAssert = assert_int(_h.spawned.size()).is_equal(spawned_before)
	var _stay: GdUnitAssert = (
		assert_int(_h.field.active_enemies().size() + _h.destroyed.size() + _h.left_sphere.size())
		. is_equal(survivors)
	)


func test_spawning_stops_while_player_destroyed() -> void:
	_h.enter_level(1)
	_h.target.invulnerable = true
	_advance(1.0)
	_h.target.alive = false
	_h.bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.COLLISION)
	var spawned_at_death: int = _h.spawned.size()
	_advance(5.0)
	var while_down: int = _h.spawned.size()
	_h.target.alive = true
	_h.bus.player.announce_player_respawned()
	_advance(3.0)
	var _none_while_down: GdUnitAssert = assert_int(while_down).is_equal(spawned_at_death)
	var _resumes: GdUnitAssert = assert_int(_h.spawned.size()).is_greater(while_down)


func test_shot_kills_drop_repair_kits_and_crashes_do_not() -> void:
	_h.enter_level(1)
	_h.target.at = Vector3(0.0, -1000.0, 0.0)
	var kills: int = 0
	while kills < 400:
		var enemy: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 20.0)
		if _h.field.resolve_shot(enemy.position, 0.3, Vector3.LEFT):
			kills += 1
	var shot_drops: int = _h.repair_drops
	var crashes: int = 0
	_h.target.at = Vector3.ZERO
	_h.target.invulnerable = true
	while crashes < 200:
		var _crasher: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 1.0)
		_h.field.step(STEP)
		crashes += 1
	# About 6% of 400: 24, well inside 8 to 48.
	var _about_six_percent: GdUnitAssert = assert_int(shot_drops).is_between(8, 48)
	var _crashes_drop_none: GdUnitAssert = assert_int(_h.repair_drops).is_equal(shot_drops)
	var _every_kill_reported: GdUnitAssert = assert_int(_h.destroyed.size()).is_equal(600)
