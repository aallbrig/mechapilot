extends GdUnitTestSuite
## The spawn director (#73): per-Level roster and ramp, waves, escorts, Repair
## Kit drops, and the same decisions for the same seed.

const STEP: float = 1.0 / 60.0
const SEED: int = 7331

var _bus: EventBus
var _levels: Array[LevelDefinition] = []
var _orders: Array[SpawnOrder] = []
var _drops: int = 0
var _next_id: int = 1


func before_test() -> void:
	_bus = EventBus.new()
	_levels = LevelLibrary.all_levels()
	_orders.clear()
	_drops = 0
	var subscribed: Array[int] = [
		_bus.enemy.spawn_requested.connect(_on_spawn_requested),
		_bus.player.repair_kit_dropped.connect(_on_drop),
	]
	var _ok: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(subscribed.size())


func after_test() -> void:
	_bus.free()


func _on_spawn_requested(order: SpawnOrder) -> void:
	_orders.append(order)
	# Like game/: every requested enemy enters play and is reported.
	_bus.enemy.announce_enemy_spawned(_next_id, order.kind, Vector3.ZERO)
	_next_id += 1


func _on_drop(_position: Vector3) -> void:
	_drops += 1


func _director(level_number: int, seed_value: int = SEED) -> SpawnDirector:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var director: SpawnDirector = SpawnDirector.new(_bus, rng, _levels)
	var level: LevelDefinition = _levels[level_number - 1]
	_bus.run.announce_level_intro_started(level_number, level.display_name, level.objective, 1.0)
	_bus.flow.announce_game_state_changed(GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH)
	return director


func _advance(director: SpawnDirector, seconds: float) -> void:
	var left: float = seconds
	while left > 1e-6:
		director.tick(minf(STEP, left))
		left -= STEP


## Destroys the oldest live enemy by a shot.
func _kill_one(kind: EnemyKind.Kind = EnemyKind.Kind.FIGHTER) -> void:
	_bus.enemy.announce_enemy_destroyed(
		_next_id - _orders.size(), kind, Vector3.ZERO, DestroyCause.Cause.SHOT
	)


## A scripted Skirmish: spawn, kill, spawn more. Returns every order made.
func _script_run(seed_value: int) -> Array[SpawnOrder]:
	_orders.clear()
	_next_id = 1
	var director: SpawnDirector = _director(4, seed_value)
	for round_index: int in 20:
		_advance(director, 1.5)
		_bus.enemy.announce_enemy_destroyed(
			round_index + 1, EnemyKind.Kind.DRONE, Vector3.ZERO, DestroyCause.Cause.SHOT
		)
	return _orders.duplicate()


func test_spawn_director_same_seed_same_orders() -> void:
	var first: Array[SpawnOrder] = _script_run(SEED)
	var second: Array[SpawnOrder] = _script_run(SEED)
	var other: Array[SpawnOrder] = _script_run(SEED + 1)
	var same: bool = first.size() == second.size()
	for i: int in mini(first.size(), second.size()):
		same = same and first[i].equals(second[i])
	var differs: bool = other.size() != first.size()
	for i: int in mini(first.size(), other.size()):
		differs = differs or not first[i].equals(other[i])
	var _spawned: GdUnitAssert = assert_int(first.size()).is_greater(10)
	var _same: GdUnitAssert = assert_bool(same).is_true()
	var _seeded: GdUnitAssert = assert_bool(differs).is_true()


func test_spawn_director_limit_ramps_with_kills() -> void:
	var director: SpawnDirector = _director(1)
	var tuning: LevelDefinition.SpawnTuning = _levels[0].spawn
	var start: float = director.limit()
	for i: int in 3:
		_bus.enemy.announce_enemy_destroyed(
			100 + i, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
		)
	var after_three: float = director.limit()
	for i: int in 100:
		_bus.enemy.announce_enemy_destroyed(
			200 + i, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.COLLISION
		)
	var _start: GdUnitAssert = assert_float(start).is_equal_approx(tuning.limit_start, 1e-6)
	var _ramped: GdUnitAssert = assert_float(after_three).is_equal_approx(
		tuning.limit_start + 3 * tuning.limit_per_kill, 1e-6
	)
	var _capped: GdUnitAssert = assert_float(director.limit()).is_equal(float(tuning.limit_max))
	var _buffer: GdUnitAssert = assert_float(director.buffer()).is_equal(tuning.buffer_min)
	var _aggression: GdUnitAssert = assert_float(director.aggression()).is_equal(
		tuning.aggression_max
	)


func test_spawn_director_respects_live_limit() -> void:
	var director: SpawnDirector = _director(1)
	var tuning: LevelDefinition.SpawnTuning = _levels[0].spawn
	_advance(director, tuning.wave_interval - 1.0)
	var _limited: GdUnitAssert = assert_int(director.live_count()).is_equal(
		floori(tuning.limit_start)
	)
	var _trickle: GdUnitAssert = assert_int(_orders.size()).is_equal(floori(tuning.limit_start))


func test_spawn_director_sends_waves_on_interval() -> void:
	var director: SpawnDirector = _director(1)
	var tuning: LevelDefinition.SpawnTuning = _levels[0].spawn
	_advance(director, tuning.wave_interval + STEP)
	var first_wave: int = _orders.size() - floori(tuning.limit_start)
	_advance(director, tuning.wave_interval)
	var second_wave: int = _orders.size() - floori(tuning.limit_start) - first_wave
	var _first: GdUnitAssert = assert_int(first_wave).is_equal(tuning.wave_size_start)
	var _grows: GdUnitAssert = assert_int(second_wave).is_equal(
		tuning.wave_size_start + tuning.wave_size_growth
	)


func test_spawn_director_picks_only_unlocked_roster_kinds() -> void:
	var director: SpawnDirector = _director(2)
	var heavy_gate: int = 0
	for entry: LevelDefinition.RosterEntry in _levels[1].roster:
		if entry.kind == EnemyKind.Kind.HEAVY:
			heavy_gate = entry.min_kills
	_advance(director, 30.0)
	var early_heavies: int = 0
	for order: SpawnOrder in _orders:
		if order.kind == EnemyKind.Kind.HEAVY:
			early_heavies += 1
	for i: int in heavy_gate:
		_bus.enemy.announce_enemy_destroyed(
			i + 1, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
		)
	_orders.clear()
	for i: int in 40:
		_advance(director, 2.0)
		_kill_one()
	var later_heavies: int = 0
	for order: SpawnOrder in _orders:
		if order.kind == EnemyKind.Kind.HEAVY:
			later_heavies += 1
	var _gated: GdUnitAssert = assert_int(heavy_gate).is_greater(0)
	var _none_early: GdUnitAssert = assert_int(early_heavies).is_equal(0)
	var _then_some: GdUnitAssert = assert_int(later_heavies).is_greater(0)


func test_spawn_director_stops_while_player_destroyed() -> void:
	var director: SpawnDirector = _director(1)
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.SHOT)
	_advance(director, 30.0)
	var while_down: int = _orders.size()
	_bus.player.announce_player_respawned()
	_advance(director, 1.0)
	var _stopped: GdUnitAssert = assert_int(while_down).is_equal(0)
	var _resumed: GdUnitAssert = assert_int(_orders.size()).is_greater(0)


func test_spawn_director_holds_during_boss_warning_then_sends_escorts() -> void:
	var director: SpawnDirector = _director(1)
	_bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.BOSS_WARNING)
	_advance(director, 30.0)
	var during_warning: int = _orders.size()
	_bus.flow.announce_game_state_changed(GameState.Phase.BOSS_WARNING, GameState.Phase.BOSS_FIGHT)
	_advance(director, 60.0)
	var escorts: bool = not _orders.is_empty()
	for order: SpawnOrder in _orders:
		escorts = escorts and order.escort
	var _hold: GdUnitAssert = assert_int(during_warning).is_equal(0)
	var _escorts: GdUnitAssert = assert_bool(escorts).is_true()
	var _limit: GdUnitAssert = assert_int(director.live_count()).is_equal(
		_levels[0].boss.escort_limit
	)


func test_spawn_director_drops_repair_kits() -> void:
	var director: SpawnDirector = _director(1)
	for i: int in 1000:
		_bus.enemy.announce_enemy_destroyed(
			i + 1, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
		)
	var from_kills: int = _drops
	_bus.boss.announce_boss_defeated(&"albatross", Vector3.ZERO)
	var _near_six_percent: GdUnitAssert = assert_int(from_kills).is_between(30, 90)
	var _boss_always: GdUnitAssert = assert_int(_drops).is_equal(from_kills + 1)
	var _alive: GdUnitAssert = assert_int(director.kills()).is_equal(1000)
