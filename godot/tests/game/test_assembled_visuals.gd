extends GdUnitTestSuite
## The assembled fight wears the visual pass (#27, #84): every enemy of the
## field and every boss shows its merged VisualLibrary model, and a full wave
## with a boss, under each Level's sky, stays inside the Gameplay draw-call
## budget. The count is DrawCallEstimator's model of the Compatibility renderer.

const BUDGET: int = 100
## A full wave: the spec's worst case on screen at once (#73).
const WAVE: int = 30
## Where the wave sits around the player, so none leaves the Play Sphere.
const RING: float = 20.0
## Live player shots in the measured world.
const SHOTS: int = 12
const SHOT_LIFE: float = 2.0

var _h: FightHarness


func before_test() -> void:
	_h = FightHarness.new()
	add_child(_h.world)


func after_test() -> void:
	_h.dispose()


func _kinds() -> Array[EnemyKind.Kind]:
	var kinds: Array[EnemyKind.Kind] = []
	for kind: int in EnemyKind.IDS.size():
		kinds.append(kind as EnemyKind.Kind)
	return kinds


func _scene_of(kind: EnemyKind.Kind) -> String:
	return VisualLibrary.ENEMIES[EnemyKind.id_of(kind)].resource_path


## The meshes under `look` that are not part of its model.
func _meshes_outside(look: Node3D, model: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [look]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == model:
			continue
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node != null:
			out.append(mesh_node)
		stack.append_array(node.get_children())
	return out


## A boss of `definition` in the harness's world, entering for the player.
func _boss(definition: BossDefinition) -> Boss:
	var boss: Boss = Boss.new()
	_h.world.add_child(boss)
	boss.begin(_h.bus, definition, _h.mech.position, 1)
	return boss


func test_every_enemy_and_boss_uses_visual_scene() -> void:
	_h.reach_skirmish()
	var wrong: Array[String] = []
	for kind: EnemyKind.Kind in _kinds():
		var enemy: Enemy = _h.order(kind, PI * 0.5, RING)
		var model: EnemyVisual = enemy.look().model()
		if model == null or model.scene_file_path != _scene_of(kind):
			wrong.append("enemy %s" % EnemyKind.id_of(kind))
		elif not model.is_visible_in_tree() or model.pieces().is_empty():
			wrong.append("enemy %s not shown" % EnemyKind.id_of(kind))
		elif not _meshes_outside(enemy.look(), model).is_empty():
			wrong.append("enemy %s draws more than its model" % EnemyKind.id_of(kind))
	var boss_ids: Array[StringName] = []
	for level: LevelDefinition in _h.run.levels:
		var boss: Boss = _boss(level.boss)
		var model: BossVisual = boss.look().model()
		boss_ids.append(level.boss.id)
		if (
			model == null
			or model.scene_file_path != VisualLibrary.BOSSES[level.boss.id].resource_path
		):
			wrong.append("boss %s" % level.boss.id)
		elif not model.is_visible_in_tree() or model.pieces().is_empty():
			wrong.append("boss %s not shown" % level.boss.id)
		boss.free()
	# The arena's own boss, summoned by the rules, wears its model too.
	_h.run.reach_boss_fight()
	var summoned: Boss = _h.director.arena().boss()
	var summoned_path: String = summoned.look().model().scene_file_path
	var _all: GdUnitAssert = assert_array(wrong).is_empty()
	var _every_level: GdUnitAssert = assert_int(boss_ids.size()).is_equal(_h.run.levels.size())
	var _arena: GdUnitAssert = assert_str(summoned_path).is_equal(
		VisualLibrary.BOSSES[_h.run.levels[0].boss.id].resource_path
	)


func test_field_enemies_use_visual_library_models() -> void:
	_h.reach_skirmish()
	var first: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, RING)
	var twin: Enemy = _h.order(EnemyKind.Kind.FIGHTER, PI, RING)
	# Each piece is baked once per scene: two fighters share every mesh.
	var shared: bool = true
	var first_pieces: Array[VisualPiece] = first.look().model().pieces()
	var twin_pieces: Array[VisualPiece] = twin.look().model().pieces()
	for i: int in first_pieces.size():
		shared = shared and first_pieces[i].mesh == twin_pieces[i].mesh
	var shadows: int = 0
	for node: MeshInstance3D in _meshes_outside(first, null):
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadows += 1
	var idle_glow: bool = first.look().is_glowing()
	# A parked enemy reused for another kind swaps to that kind's model.
	first.park()
	var reused: Enemy = _h.order(EnemyKind.Kind.HEAVY, 0.0, RING)
	var _same_node: GdUnitAssert = assert_object(reused).is_same(first)
	var _heavy: GdUnitAssert = assert_str(reused.look().model().scene_file_path).is_equal(
		_scene_of(EnemyKind.Kind.HEAVY)
	)
	var _one_draw_each: GdUnitAssert = assert_bool(shared and not first_pieces.is_empty()).is_true()
	var _no_shadows: GdUnitAssert = assert_int(shadows).is_equal(0)
	var _glow_only_charging: GdUnitAssert = assert_bool(idle_glow).is_false()


func test_full_wave_with_boss_stays_within_draw_budget() -> void:
	_h.reach_skirmish()
	var kinds: Array[EnemyKind.Kind] = _kinds()
	var wave: Array[Enemy] = []
	for i: int in WAVE:
		var enemy: Enemy = _h.order(kinds[i % kinds.size()], TAU * i / WAVE, RING)
		if enemy != null:
			wave.append(enemy)
	for i: int in SHOTS:
		var angle: float = TAU * i / SHOTS
		var _shot: PlayerShot = _h.shots.fire(
			_h.mech.position, Vector3(cos(angle), sin(angle), 0.0), SHOT_LIFE, 0.0
		)
	# The mech's flames and eye trails, mounted as main.gd mounts them.
	var feedback: MechFeedback = MechFeedback.new()
	_h.world.add_child(feedback)
	var model: MechModel = _h.mech.model()
	feedback.attach(
		model.main_nozzles,
		MechModel.WING_FLAME_SIZE,
		model.foot_nozzles,
		MechModel.FOOT_FLAME_SIZE,
		model.eyes
	)
	# Worst case: every telegraph glows at once.
	for enemy: Enemy in wave:
		enemy.look().set_charge(1.0)
	_h.director.field().show_telegraphs()
	var glows_shown: int = _h.director.field().telegraph_glows().shown()
	var estimator: DrawCallEstimator = DrawCallEstimator.new()
	var worst: int = 0
	var worst_case: String = ""
	var problems: PackedStringArray = PackedStringArray()
	var measured: int = 0
	for level: LevelDefinition in _h.run.levels:
		var sky: SkyEnvironment = SkyLibrary.for_level(level)
		_h.world.add_child(sky)
		var boss: Boss = _boss(level.boss)
		for phase: int in level.boss.phases.size():
			boss.enter_phase(phase)
			boss.look().set_charge(1.0)
			var draws: int = estimator.measure(_h.world)
			measured += 1
			problems.append_array(estimator.problems())
			if draws > worst:
				worst = draws
				worst_case = "%s sky, %s phase %d" % [level.sky_theme, level.boss.id, phase + 1]
		boss.free()
		sky.free()
	var _full_wave: GdUnitAssert = assert_int(wave.size()).is_equal(WAVE)
	var _all_glowing: GdUnitAssert = assert_int(glows_shown).is_equal(WAVE)
	var _every_level: GdUnitAssert = assert_int(measured).is_greater_equal(_h.run.levels.size())
	var _clean: GdUnitAssert = assert_array(problems).is_empty()
	var _under: GdUnitAssert = (
		assert_int(worst)
		. override_failure_message("%d draw calls (budget %d) at %s" % [worst, BUDGET, worst_case])
		. is_less(BUDGET)
	)
