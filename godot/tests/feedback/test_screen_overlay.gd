extends GdUnitTestSuite
## Full-screen juice (#26): the damage vignette, the low-Armor glow, the Boss
## Warning edge and the desaturate effect on the player's death.

const STEP: float = 1.0 / 60.0

var _bus: EventBus
var _overlay: ScreenOverlay


func before_test() -> void:
	_bus = EventBus.new()
	_overlay = ScreenOverlay.new()
	add_child(_overlay)
	_overlay.bind(_bus)


func after_test() -> void:
	_overlay.free()
	_bus.free()


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_overlay.advance(STEP)
		left -= STEP


func test_player_hit_shows_damage_vignette_then_fades() -> void:
	var calm: float = _overlay.vignette()
	_bus.player.announce_armor_changed(90, 100, -10)
	var small_hit: float = _overlay.vignette()
	_advance(1.0)
	var faded: float = _overlay.vignette()
	_bus.player.announce_armor_changed(60, 100, -30)
	var big_hit: float = _overlay.vignette()
	var _calm: GdUnitAssert = assert_float(calm).is_equal(0.0)
	var _flares: GdUnitAssert = assert_float(small_hit).is_greater(0.0)
	var _fades: GdUnitAssert = assert_float(faded).is_equal(0.0)
	var _bigger: GdUnitAssert = assert_float(big_hit).is_greater(small_hit)


func test_low_armor_keeps_the_edge_glowing_until_repaired() -> void:
	_bus.player.announce_armor_changed(20, 100, -30)
	_advance(1.0)
	var low: float = _overlay.vignette()
	_bus.player.announce_armor_changed(50, 100, 30)
	_advance(1.0)
	var _glows: GdUnitAssert = assert_float(low).is_greater(0.0)
	var _repaired: GdUnitAssert = assert_float(_overlay.vignette()).is_equal(0.0)


func test_boss_warning_pulses_a_red_edge_for_its_duration() -> void:
	_bus.boss.announce_boss_warning_started("Albatross", 3.0)
	_advance(1.5)
	var during: float = _overlay.vignette()
	_advance(1.6)
	var _shown: GdUnitAssert = assert_float(during).is_greater(0.0)
	var _over: GdUnitAssert = assert_float(_overlay.vignette()).is_equal(0.0)


func test_reduced_motion_holds_the_warning_edge_steady() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.reduced_motion = true
	_bus.profile.announce_settings_changed(settings)
	_bus.boss.announce_boss_warning_started("Albatross", 3.0)
	var levels: Array[float] = []
	for _i: int in 10:
		_advance(0.1)
		levels.append(_overlay.vignette())
	var _steady: GdUnitAssert = assert_float(levels.min()).is_equal(levels.max())


func test_player_destroyed_desaturates_until_respawn() -> void:
	var idle_pass: bool = _overlay.desaturating()
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.SHOT)
	_advance(1.0)
	var grey: float = _overlay.desaturation()
	_bus.player.announce_player_respawned()
	_advance(1.0)
	var _no_idle_cost: GdUnitAssert = assert_bool(idle_pass).is_false()
	var _drained: GdUnitAssert = assert_float(grey).is_equal(1.0)
	var _colour_back: GdUnitAssert = assert_float(_overlay.desaturation()).is_equal(0.0)
	var _pass_off: GdUnitAssert = assert_bool(_overlay.desaturating()).is_false()
