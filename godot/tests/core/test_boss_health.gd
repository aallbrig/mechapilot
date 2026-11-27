extends GdUnitTestSuite
## Boss health and phases (#73, #74): phase changes exactly at the thresholds,
## one defeat, and nothing while disarmed.

var _bus: EventBus
var _boss: BossHealth
var _phases: Array[int] = []
var _defeats: int = 0


func before_test() -> void:
	_bus = EventBus.new()
	_boss = BossHealth.new(_bus)
	_phases.clear()
	_defeats = 0
	var subscribed: Array[int] = [
		_bus.boss.boss_phase_changed.connect(_on_phase),
		_bus.boss.boss_defeated.connect(_on_defeated),
	]
	var _ok: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(subscribed.size())


func after_test() -> void:
	_bus.free()


func _on_phase(phase: int, _count: int) -> void:
	_phases.append(phase)


func _on_defeated(_boss_id: StringName, _position: Vector3) -> void:
	_defeats += 1


## Level 5's boss: three phases starting at 1.0, 0.66 and 0.33 of 540 health.
func _lancer() -> BossDefinition:
	return LevelLibrary.all_levels()[4].boss


func test_boss_health_changes_phase_at_thresholds() -> void:
	var boss: BossDefinition = _lancer()
	_boss.arm(boss)
	var second_at: int = floori(boss.health * boss.phases[1].starts_at)
	_bus.boss.announce_boss_hit(boss.health - second_at - 1, Vector3.ZERO)
	var before_threshold: Array[int] = _phases.duplicate()
	_bus.boss.announce_boss_hit(1, Vector3.ZERO)
	var at_threshold: Array[int] = _phases.duplicate()
	_bus.boss.announce_boss_hit(boss.health, Vector3.ZERO)
	var _not_yet: GdUnitAssert = assert_array(before_threshold).is_empty()
	var _exactly: GdUnitAssert = assert_array(at_threshold).is_equal([1])
	var _skipped_in_order: GdUnitAssert = assert_array(_phases).is_equal([1, 2])
	var _defeated: GdUnitAssert = assert_int(_defeats).is_equal(1)


func test_boss_health_defeat_announces_once() -> void:
	_boss.arm(_lancer())
	for i: int in 5:
		_bus.boss.announce_boss_hit(1000, Vector3.ZERO)
	var _once: GdUnitAssert = assert_int(_defeats).is_equal(1)
	var _empty: GdUnitAssert = assert_int(_boss.health()).is_equal(0)


func test_boss_health_ignores_hits_when_disarmed() -> void:
	_bus.boss.announce_boss_hit(10, Vector3.ZERO)
	_boss.arm(_lancer())
	_boss.disarm()
	_bus.boss.announce_boss_hit(1000, Vector3.ZERO)
	var _full: GdUnitAssert = assert_int(_boss.health()).is_equal(_lancer().health)
	var _none: GdUnitAssert = assert_int(_defeats).is_equal(0)
