extends GdUnitTestSuite
## Gamepad rumble (#73): on hits and on boss kills, and the toggle turns it off.

var _bus: EventBus
var _rumble: RumbleDirector
var _strong: Array[float] = []


func before_test() -> void:
	_strong.clear()
	_bus = EventBus.new()
	_rumble = RumbleDirector.new()
	add_child(_rumble)
	_rumble.bind(_bus)
	var _a: int = _rumble.rumbled.connect(_on_rumbled)


func after_test() -> void:
	_rumble.free()
	_bus.free()


func _on_rumbled(_weak: float, strong: float, _seconds: float) -> void:
	_strong.append(strong)


func test_rumble_on_hits_and_boss_kills() -> void:
	_bus.player.announce_armor_changed(100, 100, 30)
	var repaired: int = _strong.size()
	_bus.player.announce_armor_changed(90, 100, -10)
	_bus.player.announce_armor_changed(60, 100, -30)
	_bus.boss.announce_boss_defeated(&"albatross", Vector3.ZERO)
	var _repair_is_still: GdUnitAssert = assert_int(repaired).is_equal(0)
	var _three: GdUnitAssert = assert_array(_strong).has_size(3)
	var _bigger_hit: GdUnitAssert = assert_float(_strong[1]).is_greater(_strong[0])
	var _boss_hardest: GdUnitAssert = assert_float(_strong[2]).is_equal(1.0)


func test_rumble_toggle_turns_rumble_off() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.rumble = false
	_bus.profile.announce_settings_changed(settings)
	_bus.player.announce_armor_changed(60, 100, -30)
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.SHOT)
	_bus.boss.announce_boss_defeated(&"albatross", Vector3.ZERO)
	var _silent: GdUnitAssert = assert_array(_strong).is_empty()
