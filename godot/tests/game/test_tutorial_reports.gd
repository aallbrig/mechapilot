extends GdUnitTestSuite
## The reports the first-flight tutorial (#75) needs from the player mech:
## steering (the MOVE prompt) and shots that run out of life without a hit
## (SHOTS_DROP). PlayerBusLink publishes them as Game Events.

const TICK: float = 1.0 / 60.0


func _firing() -> PilotIntent:
	var intent: PilotIntent = PilotIntent.new()
	intent.aim = Vector2.RIGHT
	intent.firing = true
	return intent


func test_bus_link_reports_steering_and_missed_shots() -> void:
	var bus: EventBus = EventBus.new()
	var mech: PlayerMech = PlayerMech.new()
	mech.tuning.shot_spread = 0.0
	add_child(mech)
	var pool: ShotPool = ShotPool.new()
	add_child(pool)
	mech.shots = pool
	var input: PlayerInput = PlayerInput.new()
	add_child(input)
	var link: PlayerBusLink = PlayerBusLink.new()
	add_child(link)
	link.link(bus, mech, input)
	var moves: Array[int] = [0]
	var misses: Array[Vector3] = []
	var subscribed: Array[int] = [
		bus.player.player_moved.connect(func() -> void: moves[0] += 1),
		bus.player.shot_missed.connect(func(at: Vector3) -> void: misses.append(at)),
	]
	var steer: PilotIntent = PilotIntent.new()
	steer.move = Vector2.RIGHT
	var still_before: int = moves[0]
	mech.tick(TICK, PilotIntent.new())
	var coasting: int = moves[0]
	# Holding the stick is one report; letting go and steering again is another.
	for _i: int in 10:
		mech.tick(TICK, steer)
	var held: int = moves[0]
	mech.tick(TICK, PilotIntent.new())
	mech.tick(TICK, steer)
	var again: int = moves[0]
	# A shot that hits is spent, not missed; one that runs out of life is a miss.
	mech.tick(TICK, _firing())
	pool.live_shots()[0].spend()
	var after_hit: int = misses.size()
	var cooldown_ticks: int = ceili(mech.tuning.fire_interval / TICK) + 1
	for _i: int in cooldown_ticks:
		mech.tick(TICK, PilotIntent.new())
	mech.tick(TICK, _firing())
	var flying: PlayerShot = pool.live_shots()[0]
	var life_ticks: int = ceili(mech.tuning.shot_life / TICK) + 1
	var last_position: Vector3 = Vector3.ZERO
	for _i: int in life_ticks:
		if flying.is_live():
			pool.step(TICK)
			last_position = flying.position
	var linked: int = link.error_count()
	link.free()
	input.free()
	pool.free()
	mech.free()
	bus.free()
	var _linked: GdUnitAssert = assert_int(linked).is_equal(0)
	var _connected: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(2)
	var _no_move_yet: GdUnitAssert = assert_int(still_before + coasting).is_equal(0)
	var _held_once: GdUnitAssert = assert_int(held).is_equal(1)
	var _steered_again: GdUnitAssert = assert_int(again).is_equal(2)
	var _hit_is_no_miss: GdUnitAssert = assert_int(after_hit).is_equal(0)
	var _missed_once: GdUnitAssert = assert_array(misses).is_equal([last_position])
