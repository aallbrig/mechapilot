extends GdUnitTestSuite
## Pooled explosions (#26, #9's fix): kills blast from a fixed pool and every
## blast goes back to it; a boss kill chains blasts before the biggest one.

const STEP: float = 1.0 / 60.0

var _bus: EventBus
var _pool: ExplosionPool
var _blasts: Array[float] = []


func before_test() -> void:
	_blasts.clear()
	_bus = EventBus.new()
	_pool = ExplosionPool.new()
	_pool.rng.seed = 26
	add_child(_pool)
	_pool.bind(_bus)
	var _a: int = _pool.detonated.connect(_on_detonated)


func after_test() -> void:
	_pool.free()
	_bus.free()


func _on_detonated(_at: Vector3, blast_size: float) -> void:
	_blasts.append(blast_size)


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_pool.advance(STEP)
		left -= STEP


func _kill(kind: EnemyKind.Kind) -> void:
	_bus.enemy.announce_enemy_destroyed(1, kind, Vector3(3.0, 2.0, 0.0), DestroyCause.Cause.SHOT)


func test_explosions_return_to_pool() -> void:
	var owned: Array[Explosion] = _pool.blasts()
	_kill(EnemyKind.Kind.FIGHTER)
	_kill(EnemyKind.Kind.HEAVY)
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.COLLISION)
	var busy: int = _pool.active_count()
	var idle_while_busy: int = _pool.idle_count()
	_advance(Explosion.LIFETIME + STEP * 2.0)
	var still_busy: int = _pool.active_count()
	var idle_after: int = _pool.idle_count()
	_kill(EnemyKind.Kind.DRONE)
	var reused: Array[Explosion] = _pool.blasts()
	var _three: GdUnitAssert = assert_int(busy).is_equal(3)
	var _taken: GdUnitAssert = assert_int(idle_while_busy).is_equal(ExplosionPool.CAPACITY - 3)
	var _none_left: GdUnitAssert = assert_int(still_busy).is_equal(0)
	var _all_back: GdUnitAssert = assert_int(idle_after).is_equal(ExplosionPool.CAPACITY)
	var _same_nodes: GdUnitAssert = assert_array(reused).contains_exactly_in_any_order(owned)
	var _no_growth: GdUnitAssert = assert_int(_pool.get_child_count()).is_equal(
		ExplosionPool.CAPACITY
	)


func test_a_spent_pool_reuses_its_oldest_blast() -> void:
	for _i: int in ExplosionPool.CAPACITY + 4:
		_kill(EnemyKind.Kind.FIGHTER)
	var _capped: GdUnitAssert = assert_int(_pool.active_count()).is_equal(ExplosionPool.CAPACITY)
	var _no_growth: GdUnitAssert = assert_int(_pool.get_child_count()).is_equal(
		ExplosionPool.CAPACITY
	)
	var _all_blasted: GdUnitAssert = assert_array(_blasts).has_size(ExplosionPool.CAPACITY + 4)


func test_bigger_enemies_blast_bigger() -> void:
	_kill(EnemyKind.Kind.DRONE)
	_kill(EnemyKind.Kind.BOMBER)
	var _bomber_bigger: GdUnitAssert = assert_float(_blasts[1]).is_greater(_blasts[0])


func test_boss_defeat_chains_explosions_before_the_biggest() -> void:
	_bus.boss.announce_boss_defeated(&"albatross", Vector3(5.0, 5.0, 0.0))
	var at_once: int = _blasts.size()
	_advance(ExplosionPool.CHAIN_SECONDS + STEP * 2.0)
	var biggest: float = _blasts.max()
	var _starts_now: GdUnitAssert = assert_int(at_once).is_equal(1)
	var _chain: GdUnitAssert = assert_array(_blasts).has_size(ExplosionPool.CHAIN_COUNT + 1)
	var _last_is_biggest: GdUnitAssert = assert_float(_blasts.back()).is_equal(biggest)
	var _final: GdUnitAssert = assert_float(biggest).is_equal(ExplosionPool.FINAL_SIZE)
	var _nothing_queued: GdUnitAssert = assert_int(_pool.pending_count()).is_equal(0)


func test_reduced_motion_drops_the_flash_but_keeps_the_blast() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.reduced_motion = true
	_bus.profile.announce_settings_changed(settings)
	_kill(EnemyKind.Kind.FIGHTER)
	var blast: Explosion = null
	for candidate: Explosion in _pool.blasts():
		if candidate.is_active():
			blast = candidate
	var _blasted: GdUnitAssert = assert_object(blast).is_not_null()
	var _no_flash: GdUnitAssert = assert_bool(blast.flash_visible()).is_false()
