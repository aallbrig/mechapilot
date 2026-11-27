extends GdUnitTestSuite
## Hit-stop and slow-mo (#26): a kill freezes time for about 40 ms, a death or a
## boss kill slows it, and the time scale always comes back to exactly 1.

const STEP: float = 1.0 / 120.0

## Physics ticks run by the real main loop for the in-engine hit-stop test.
const LIVE_KILL_TICK: int = 10
const LIVE_TICKS: int = 40
## A physics tick counts as frozen when its delta is below half a 60 Hz step.
const FROZEN_DELTA: float = 0.5 / 60.0
const LIVE_WAIT_MS: int = 2000

var _bus: EventBus
var _time: TimeScaleDirector


## Announces a kill from _physics_process, as the enemy field does, and counts
## the physics ticks the hit-stop freezes after it.
class LiveKiller:
	extends Node
	var bus: EventBus
	var ticks: int = 0
	var frozen_after_kill: int = 0

	func _physics_process(delta: float) -> void:
		ticks += 1
		if ticks > LIVE_KILL_TICK and ticks <= LIVE_TICKS and delta < FROZEN_DELTA:
			frozen_after_kill += 1
		if ticks == LIVE_KILL_TICK:
			bus.enemy.announce_enemy_destroyed(
				1, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
			)


func before_test() -> void:
	_bus = EventBus.new()
	_time = TimeScaleDirector.new()
	add_child(_time)
	_time.bind(_bus)


func after_test() -> void:
	_time.release_engine()
	_time.free()
	_bus.free()


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_time.advance(minf(STEP, left))
		left -= STEP


func _kill() -> void:
	_bus.enemy.announce_enemy_destroyed(
		1, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
	)


func test_enemy_kill_triggers_hitstop_and_restores() -> void:
	var at_rest: float = _time.time_scale()
	_kill()
	var frozen: float = _time.time_scale()
	_advance(TimeScaleDirector.HITSTOP_SECONDS * 0.5)
	var still_frozen: float = _time.time_scale()
	_advance(TimeScaleDirector.HITSTOP_SECONDS)
	var resumed: float = _time.time_scale()
	var _before: GdUnitAssert = assert_float(at_rest).is_equal(1.0)
	var _frozen: GdUnitAssert = assert_float(frozen).is_equal(TimeScaleDirector.HITSTOP_SCALE)
	var _held: GdUnitAssert = assert_float(still_frozen).is_equal(TimeScaleDirector.HITSTOP_SCALE)
	var _restored: GdUnitAssert = assert_float(resumed).is_equal(1.0)
	var _about_40_ms: GdUnitAssert = assert_float(TimeScaleDirector.HITSTOP_SECONDS).is_between(
		0.03, 0.05
	)


func test_rapid_kills_never_stack_hitstop_past_its_cap() -> void:
	for _i: int in 20:
		_kill()
		_advance(STEP)
	_advance(TimeScaleDirector.MAX_HITSTOP)
	var _restored: GdUnitAssert = assert_float(_time.time_scale()).is_equal(1.0)


func test_player_destroyed_slows_time_then_restores() -> void:
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.SHOT)
	var slow: float = _time.time_scale()
	_advance(TimeScaleDirector.DEATH_SLOWMO_SECONDS * 0.5)
	var easing: float = _time.time_scale()
	_advance(TimeScaleDirector.DEATH_SLOWMO_SECONDS)
	var _slow: GdUnitAssert = assert_float(slow).is_equal_approx(
		TimeScaleDirector.DEATH_SLOWMO_SCALE, 0.001
	)
	var _easing: GdUnitAssert = assert_float(easing).is_between(slow, 1.0)
	var _restored: GdUnitAssert = assert_float(_time.time_scale()).is_equal(1.0)


func test_boss_defeat_slows_time_longer_than_a_death() -> void:
	_bus.boss.announce_boss_defeated(&"albatross", Vector3.ZERO)
	_advance(TimeScaleDirector.DEATH_SLOWMO_SECONDS)
	var still_slow: float = _time.time_scale()
	_advance(TimeScaleDirector.BOSS_SLOWMO_SECONDS)
	var _longer: GdUnitAssert = assert_float(still_slow).is_less(1.0)
	var _restored: GdUnitAssert = assert_float(_time.time_scale()).is_equal(1.0)


func test_leaving_play_restores_the_time_scale_at_once() -> void:
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.SHOT)
	_bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.PAUSED)
	var paused: float = _time.time_scale()
	_bus.boss.announce_boss_defeated(&"albatross", Vector3.ZERO)
	_bus.flow.announce_game_state_changed(GameState.Phase.LEVEL_CLEAR, GameState.Phase.TITLE)
	var _paused: GdUnitAssert = assert_float(paused).is_equal(1.0)
	var _title: GdUnitAssert = assert_float(_time.time_scale()).is_equal(1.0)


func test_hitstop_outlasts_the_frame_it_starts_in() -> void:
	_time.drive_engine()
	var killer: LiveKiller = LiveKiller.new()
	killer.bus = _bus
	add_child(killer)
	await await_millis(LIVE_WAIT_MS)
	var ticks: int = killer.ticks
	var frozen: int = killer.frozen_after_kill
	_time.release_engine()
	killer.free()
	var _ran: GdUnitAssert = assert_int(ticks).is_greater(LIVE_TICKS)
	var _held: GdUnitAssert = assert_int(frozen).is_greater_equal(2)
	var _restored: GdUnitAssert = assert_float(_time.time_scale()).is_equal(1.0)
