extends GdUnitTestSuite
## The visual pass stays inside the Gameplay draw-call budget (#27, #73): every
## sky, the player mech, 30 enemies of every type and each boss in each of its
## phases. The count is DrawCallEstimator's model of the Compatibility renderer.

const BUDGET: int = 100
const ENEMY_COUNT: int = 30
const SPACING: float = 4.0


func test_gameplay_draw_calls_under_budget() -> void:
	var estimator: DrawCallEstimator = DrawCallEstimator.new()
	var worst: int = 0
	var worst_case: String = ""
	var problems: PackedStringArray = PackedStringArray()
	var measured: int = 0
	for sky_id: StringName in SkyLibrary.ids():
		for boss_id: StringName in VisualLibrary.boss_ids():
			var world: Node3D = _gameplay_world(sky_id)
			var boss: BossVisual = VisualLibrary.boss(boss_id)
			world.add_child(boss)
			for phase: int in range(1, boss.phase_count + 1):
				boss.set_phase(phase)
				var draws: int = estimator.measure(world)
				measured += 1
				problems.append_array(estimator.problems())
				if draws > worst:
					worst = draws
					worst_case = "%s sky, %s phase %d" % [sky_id, boss_id, phase]
			world.free()
	var _cases: GdUnitAssert = assert_int(measured).is_greater_equal(
		SkyLibrary.ids().size() * VisualLibrary.boss_ids().size()
	)
	var _clean: GdUnitAssert = assert_array(problems).is_empty()
	var _under: GdUnitAssert = (
		assert_int(worst)
		. override_failure_message("%d draw calls (budget %d) at %s" % [worst, BUDGET, worst_case])
		. is_less(BUDGET)
	)


func test_draw_call_estimator_counts_passes_and_fails_closed() -> void:
	var root: Node3D = Node3D.new()
	var box: MeshInstance3D = MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.next_pass = StandardMaterial3D.new()
	box.material_override = material
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(box)
	var crowd: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = BoxMesh.new()
	multi.instance_count = 50
	crowd.multimesh = multi
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(crowd)
	var hidden: MeshInstance3D = MeshInstance3D.new()
	hidden.mesh = BoxMesh.new()
	hidden.visible = false
	root.add_child(hidden)
	add_child(root)
	var estimator: DrawCallEstimator = DrawCallEstimator.new()
	var clean_draws: int = estimator.measure(root)
	var clean_problems: PackedStringArray = estimator.problems().duplicate()
	root.add_child(CSGBox3D.new())
	root.add_child(OmniLight3D.new())
	var _dirty_draws: int = estimator.measure(root)
	var dirty_problems: PackedStringArray = estimator.problems().duplicate()
	root.free()
	var _passes: GdUnitAssert = assert_int(clean_draws).is_equal(3)
	var _clean: GdUnitAssert = assert_array(clean_problems).is_empty()
	var _fails_closed: GdUnitAssert = assert_int(dirty_problems.size()).is_equal(3)


## A Gameplay-like world: the sky, the player mech and ENEMY_COUNT enemies,
## cycling through every enemy type, laid out in a grid around the player.
func _gameplay_world(sky_id: StringName) -> Node3D:
	var world: Node3D = Node3D.new()
	add_child(world)
	world.add_child(SkyLibrary.instantiate(sky_id))
	world.add_child(VisualLibrary.player_mech())
	var enemy_ids: Array[StringName] = VisualLibrary.enemy_ids()
	for i: int in ENEMY_COUNT:
		var enemy: EnemyVisual = VisualLibrary.enemy(enemy_ids[i % enemy_ids.size()])
		enemy.position = Vector3(float(i % 6) - 2.5, floorf(i / 6.0) - 2.5, 0.0) * SPACING
		world.add_child(enemy)
	return world
