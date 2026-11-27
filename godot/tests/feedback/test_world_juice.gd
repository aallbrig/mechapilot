extends GdUnitTestSuite
## World-space juice (#26): score pop-ups for every scored kill (with the
## Combo) and a muzzle flash for every shot.

var _bus: EventBus
var _popups: ScorePopups
var _muzzle: MuzzleFlashes


func before_test() -> void:
	_bus = EventBus.new()
	_popups = ScorePopups.new()
	add_child(_popups)
	_popups.bind(_bus)
	_muzzle = MuzzleFlashes.new()
	add_child(_muzzle)
	_muzzle.bind(_bus)


func after_test() -> void:
	_muzzle.free()
	_popups.free()
	_bus.free()


func test_kill_scored_pops_points_and_combo() -> void:
	_bus.run.announce_kill_scored(100, 1, Vector3.ZERO)
	_bus.run.announce_kill_scored(600, 3, Vector3.ONE)
	_bus.player.announce_repair_collected(Vector3.ONE)
	var _shown: GdUnitAssert = assert_array(_popups.showing()).contains_exactly(
		["+100", "+600\nx3", ScorePopups.REPAIR_TEXT]
	)


func test_score_popups_reuse_their_pool() -> void:
	for i: int in ScorePopups.POOL_SIZE + 3:
		_bus.run.announce_kill_scored(100 + i, 1, Vector3.ZERO)
	var shown: Array[String] = _popups.showing()
	var _capped: GdUnitAssert = assert_array(shown).has_size(ScorePopups.POOL_SIZE)
	var _newest_last: GdUnitAssert = assert_str(shown.back()).is_equal(
		"+%d" % (100 + ScorePopups.POOL_SIZE + 2)
	)
	var _no_growth: GdUnitAssert = assert_int(_popups.get_child_count()).is_equal(
		ScorePopups.POOL_SIZE
	)


func test_shots_flash_the_muzzle_unless_motion_is_reduced() -> void:
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	var flashed: int = _muzzle.showing()
	var settings: GameSettings = GameSettings.new()
	settings.reduced_motion = true
	_bus.profile.announce_settings_changed(settings)
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	var _one: GdUnitAssert = assert_int(flashed).is_equal(1)
	var _still_one: GdUnitAssert = assert_int(_muzzle.showing()).is_equal(1)
