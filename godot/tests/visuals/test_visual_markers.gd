extends GdUnitTestSuite
## Every model scene keeps its marker contract with logic (#27): the pivots,
## muzzles, nozzles, weak points and phase groups that the player, enemy and
## boss logic drive. The contract is written out here, independently of the
## scenes and their scripts, so a scene can't drop a marker by also dropping
## it from its own list.

const FRAME: Array[String] = [
	"Hull",
	"Body",
	"Head",
	"GunPivot",
	"Muzzle",
	"ArmL",
	"ArmR",
	"ThighL",
	"ThighR",
	"ShinL",
	"ShinR",
	"WingL",
	"WingR",
	"WingNozzleL",
	"WingNozzleR",
	"FootNozzleL",
	"FootNozzleR",
	"WingTipL",
	"WingTipR",
	"EyeL",
	"EyeR",
	"EyeC"
]
const ENEMY: Array[String] = ["Hull", "Muzzle", "Exhaust"]
const BOSS_IDS: Array[StringName] = [
	&"albatross", &"thunderhead", &"hornet", &"leviathan", &"crimson_lancer", &"ascendant"
]
const ENEMY_IDS: Array[StringName] = [
	&"fighter", &"heavy", &"interceptor", &"drone", &"bomber", &"enemy_mech"
]
## Phases per boss, from the level table in #73.
const BOSS_PHASES: Dictionary[StringName, int] = {
	&"albatross": 1,
	&"thunderhead": 2,
	&"hornet": 2,
	&"leviathan": 2,
	&"crimson_lancer": 3,
	&"ascendant": 3,
}


func test_every_visual_scene_exposes_its_required_markers() -> void:
	var missing: Array[String] = []
	var unlisted: Array[String] = []
	var contracts: Dictionary[String, Array] = _contracts()
	for scene_name: String in contracts:
		var rig: VisualRig = _instantiate(scene_name)
		var expected: Array = contracts[scene_name]
		for marker_name: String in expected:
			if rig.marker(StringName(marker_name)) == null:
				missing.append("%s: %%%s" % [scene_name, marker_name])
		for promised: StringName in rig.required_markers():
			if not expected.has(String(promised)):
				unlisted.append("%s: %s" % [scene_name, promised])
		rig.free()
	var _count: GdUnitAssert = assert_int(contracts.size()).is_equal(13)
	var _present: GdUnitAssert = assert_array(missing).is_empty()
	var _agreed: GdUnitAssert = assert_array(unlisted).is_empty()


func test_registries_cover_every_enemy_and_boss_of_the_spec() -> void:
	var _enemies: GdUnitAssert = assert_array(VisualLibrary.enemy_ids()).is_equal(ENEMY_IDS)
	var _bosses: GdUnitAssert = assert_array(VisualLibrary.boss_ids()).is_equal(BOSS_IDS)


func test_every_piece_bakes_into_one_surface() -> void:
	var bad: Array[String] = []
	var pieces: int = 0
	for scene_name: String in _contracts():
		var rig: VisualRig = _instantiate(scene_name)
		for piece: VisualPiece in rig.pieces():
			pieces += 1
			var surfaces: int = piece.mesh.get_surface_count() if piece.mesh != null else 0
			if surfaces != 1 or not piece.primitive_parts().is_empty():
				bad.append("%s: %s" % [scene_name, piece.name])
			if piece.material_override != VisualPiece.HULL_MATERIAL:
				bad.append("%s: %s has no hull material" % [scene_name, piece.name])
		rig.free()
	var _some: GdUnitAssert = assert_int(pieces).is_greater(40)
	var _baked: GdUnitAssert = assert_array(bad).is_empty()


func test_boss_phases_show_only_their_parts() -> void:
	var wrong: Array[String] = []
	for boss_id: StringName in BOSS_IDS:
		var boss: BossVisual = VisualLibrary.boss(boss_id)
		add_child(boss)
		if boss.phase_count != BOSS_PHASES[boss_id]:
			wrong.append("%s has %d phases" % [boss_id, boss.phase_count])
		for phase: int in range(1, boss.phase_count + 1):
			boss.set_phase(phase)
			for other: int in range(1, boss.phase_count + 1):
				var shown: bool = boss.marker(VisualRig.phase_name(other)).visible
				if shown != (other == phase):
					wrong.append("%s phase %d shows Phase%d=%s" % [boss_id, phase, other, shown])
		boss.free()
	var _phases: GdUnitAssert = assert_array(wrong).is_empty()


func test_muzzles_and_exhausts_point_the_right_way() -> void:
	var wrong: Array[String] = []
	for enemy_id: StringName in ENEMY_IDS:
		var enemy: EnemyVisual = VisualLibrary.enemy(enemy_id)
		add_child(enemy)
		# Every enemy flies nose-first along +X: its exhaust trails backwards.
		if -enemy.exhaust().global_basis.z.x > 0.0:
			wrong.append("%s exhaust points forward" % enemy_id)
		enemy.free()
	var mech: PlayerMechVisual = VisualLibrary.player_mech()
	add_child(mech)
	# The cannon's muzzle sits at the far end of the barrel along -Z.
	var barrel: Vector3 = mech.muzzle().position
	if barrel.z > -2.0 or not is_equal_approx(barrel.x, 0.0):
		wrong.append("player muzzle is not on the barrel's -Z axis: %s" % barrel)
	# Wing exhaust leaves backwards (+Z in the wing's frame) and down.
	var wing_exhaust: Vector3 = -mech.wing_nozzle(PlayerMechVisual.LEFT).basis.z
	if wing_exhaust.z <= 0.0 or wing_exhaust.y >= 0.0:
		wrong.append("wing exhaust direction %s" % wing_exhaust)
	mech.free()
	var _ok: GdUnitAssert = assert_array(wrong).is_empty()


func test_flash_swaps_every_piece_to_the_shared_flash_material() -> void:
	var boss: BossVisual = VisualLibrary.boss(&"leviathan")
	add_child(boss)
	boss.set_flash(true)
	var flashed: bool = true
	for piece: VisualPiece in boss.pieces():
		flashed = flashed and piece.material_override == VisualPiece.FLASH_MATERIAL
	boss.set_flash(false)
	var restored: bool = true
	for piece: VisualPiece in boss.pieces():
		restored = restored and piece.material_override == VisualPiece.HULL_MATERIAL
	boss.free()
	var _flashed: GdUnitAssert = assert_bool(flashed).is_true()
	var _restored: GdUnitAssert = assert_bool(restored).is_true()


func test_baked_pieces_are_shared_between_instances() -> void:
	var first: EnemyVisual = VisualLibrary.enemy(&"fighter")
	var second: EnemyVisual = VisualLibrary.enemy(&"fighter")
	add_child(first)
	add_child(second)
	var shared: bool = first.pieces()[0].mesh == second.pieces()[0].mesh
	var lancer: BossVisual = VisualLibrary.boss(&"crimson_lancer")
	var mech: PlayerMechVisual = VisualLibrary.player_mech()
	add_child(lancer)
	add_child(mech)
	var hull: StringName = VisualRig.HULL
	var recoloured: bool = (
		(lancer.marker(hull) as VisualPiece).mesh != (mech.marker(hull) as VisualPiece).mesh
	)
	for rig: VisualRig in [first, second, lancer, mech]:
		rig.free()
	var _shared: GdUnitAssert = assert_bool(shared).is_true()
	var _recoloured: GdUnitAssert = assert_bool(recoloured).is_true()


func _instantiate(scene_name: String) -> VisualRig:
	var rig: VisualRig = null
	if scene_name == "player_mech":
		rig = VisualLibrary.player_mech()
	elif VisualLibrary.ENEMIES.has(StringName(scene_name)):
		rig = VisualLibrary.enemy(StringName(scene_name))
	else:
		rig = VisualLibrary.boss(StringName(scene_name))
	add_child(rig)
	return rig


## Scene id -> every marker logic relies on.
func _contracts() -> Dictionary[String, Array]:
	var contracts: Dictionary[String, Array] = {"player_mech": FRAME}
	for enemy_id: StringName in ENEMY_IDS:
		contracts[String(enemy_id)] = ENEMY.duplicate()
	contracts["bomber"].append("BombBay")
	contracts["albatross"] = _boss(1, 2, 1, [])
	contracts["thunderhead"] = _boss(2, 1, 2, ["BombBay1", "BombBay2"])
	contracts["hornet"] = _boss(2, 1, 1, ["RotorFront", "RotorRear"])
	var bays: Array[String] = []
	for i: int in range(1, 5):
		bays.append_array(["LaunchBay%d" % i, "LaunchBay%dSpawn" % i])
	contracts["leviathan"] = _boss(2, 2, 1, bays)
	var lancer: Array[String] = FRAME.duplicate()
	lancer.append_array(["Lance", "LanceTip"])
	contracts["crimson_lancer"] = _boss(3, 0, 1, lancer)
	contracts["ascendant"] = _boss(3, 4, 1, ["ShieldNode1", "ShieldNode2", "ShieldNode3"])
	return contracts


func _boss(phases: int, turrets: int, weak_points: int, extra: Array[String]) -> Array[String]:
	var names: Array[String] = ["Hull"]
	for i: int in range(1, phases + 1):
		names.append("Phase%d" % i)
	for i: int in range(1, turrets + 1):
		names.append_array(["Turret%d" % i, "Turret%dMuzzle" % i])
	for i: int in range(1, weak_points + 1):
		names.append("WeakPoint%d" % i)
	for extra_name: String in extra:
		if not names.has(extra_name):
			names.append(extra_name)
	return names
