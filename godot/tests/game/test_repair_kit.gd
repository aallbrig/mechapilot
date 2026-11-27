extends GdUnitTestSuite
## Repair kits: +30 armor, collected by flying through them; they drift down
## under gravity and despawn after 10 s (#73).

const TICK: float = 1.0 / 60.0

var _repairs: Array[int] = []


func before_test() -> void:
	_repairs.clear()


func _on_repaired(amount: int, _position: Vector3) -> void:
	_repairs.append(amount)


func test_repair_kit_drifts_down_under_gravity() -> void:
	var kit: RepairKit = RepairKit.new()
	add_child(kit)
	var speeds: Array[float] = []
	for _i: int in 180:
		kit.step(TICK)
		speeds.append(kit.velocity.y)
	var height: float = kit.position.y
	kit.free()
	var _falls: GdUnitAssert = assert_float(height).is_less(-1.0)
	var _accelerates: GdUnitAssert = assert_float(speeds[30]).is_less(speeds[0])
	var _drifts: GdUnitAssert = assert_float(-speeds[-1]).is_less_equal(RepairKit.TERMINAL_FALL)


func test_repair_kit_despawns_after_ten_seconds() -> void:
	var kit: RepairKit = RepairKit.new()
	add_child(kit)
	var ticks: int = 0
	while not kit.is_spent() and ticks < 2000:
		kit.step(TICK)
		ticks += 1
	kit.free()
	var _ten_seconds: GdUnitAssert = assert_float(RepairKit.LIFETIME).is_equal(10.0)
	var _despawns: GdUnitAssert = assert_float(ticks * TICK).is_between(10.0 - 1e-4, 10.0 + TICK)


func test_repair_kit_is_collected_by_flying_through() -> void:
	var mech: PlayerMech = PlayerMech.new()
	add_child(mech)
	var err: Error = mech.repaired.connect(_on_repaired) as Error
	var kit: RepairKit = RepairKit.new()
	add_child(kit)
	kit.collector = mech
	kit.position = Vector3(3.0, 0.0, 0.0)
	mech.position = Vector3.ZERO
	kit.step(TICK)
	var missed: bool = kit.is_spent()
	mech.position = Vector3(3.0, 0.0, 0.0)
	kit.step(TICK)
	var taken: bool = kit.is_spent()
	kit.step(TICK)
	mech.free()
	kit.free()
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _not_from_afar: GdUnitAssert = assert_bool(missed).is_false()
	var _collected: GdUnitAssert = assert_bool(taken).is_true()
	var _thirty_once: GdUnitAssert = assert_array(_repairs).is_equal([30])


func test_destroyed_mech_cannot_collect_repair_kits() -> void:
	var mech: PlayerMech = PlayerMech.new()
	add_child(mech)
	mech.destroy()
	var kit: RepairKit = RepairKit.new()
	add_child(kit)
	kit.collector = mech
	kit.position = mech.position
	kit.step(TICK)
	var spent: bool = kit.is_spent()
	mech.free()
	kit.free()
	var _left_for_later: GdUnitAssert = assert_bool(spent).is_false()
