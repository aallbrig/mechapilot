extends GdUnitTestSuite
## The assembled fight wears the visual pass (#27, #84): every enemy of the
## field and every boss shows its merged VisualLibrary model, and a full wave
## with a boss, under each Level's sky, stays inside the Gameplay draw-call
## budget. The count is DrawCallEstimator's model of the Compatibility renderer.
## The drawn boss and the rules agree: every point the rules shoot from or
## take hits at lies on the model.

const BUDGET: int = 100
## A full wave: the spec's worst case on screen at once (#73).
const WAVE: int = 30
## Where the wave sits around the player, so none leaves the Play Sphere.
const RING: float = 20.0
## Live player shots in the measured world.
const SHOTS: int = 12
const SHOT_LIFE: float = 2.0
## Live enemy and boss shells in the measured world, across every style.
const SHELLS: int = 60
const SHELL_SPEED: float = 1.0
const SHELL_LIFE: float = 5.0
const SHELL_RADIUS: float = 0.3
## How far inside or outside a hull edge the body probes sit, as a share of its size.
const EDGE_SHARE: float = 0.05
## How far the body may drift from the baked hull, as a share of its size (the
## body is measured from the parts before the bake).
const BAKE_TOLERANCE: float = 0.02
## Where the hull probe sits, as a share of the hull's top edge (clear of the bays).
const HULL_PROBE: float = 0.75

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
	# A full volley of shells, every style, spread around the player.
	var shells: EnemyShotPool = _h.director.field().shots()
	for i: int in SHELLS:
		var style: ShotSpec.Style = (i % ShotSpec.Style.size()) as ShotSpec.Style
		var spec: ShotSpec = ShotSpec.new(
			style, DamageSource.Source.ENEMY_BULLET, SHELL_SPEED, 0.0, SHELL_LIFE, SHELL_RADIUS
		)
		var angle: float = TAU * i / SHELLS
		var _shell: EnemyShot = shells.fire(
			spec,
			_h.mech.position + Vector3(cos(angle), sin(angle), 0.0) * RING * 0.5,
			Vector3.LEFT,
			1.0,
			Vector3.ZERO
		)
	shells.show_shots()
	var shells_drawn: int = shells.drawn_count()
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
	var _volley: GdUnitAssert = assert_int(shells_drawn).is_equal(SHELLS)
	var _every_level: GdUnitAssert = assert_int(measured).is_greater_equal(_h.run.levels.size())
	var _clean: GdUnitAssert = assert_array(problems).is_empty()
	var _under: GdUnitAssert = (
		assert_int(worst)
		. override_failure_message("%d draw calls (budget %d) at %s" % [worst, BUDGET, worst_case])
		. is_less(BUDGET)
	)


func _leviathan() -> BossDefinition:
	for level: LevelDefinition in _h.run.levels:
		if level.boss.id == &"leviathan":
			return level.boss
	return null


func test_leviathan_visible_launch_bays_take_shielded_hits() -> void:
	_h.reach_skirmish()
	var boss: Boss = _boss(_leviathan())
	var guard: int = 0
	while boss.state() != Boss.State.FIGHTING and guard < 1000:
		boss.step(
			FightHarness.STEP,
			_h.director.target(),
			_h.director.field().shots(),
			_h.director.field(),
			1.0
		)
		guard += 1
	var hits: Array[int] = [0]
	var _heard: int = _h.bus.boss.boss_hit.connect(
		func(_damage: int, _at: Vector3) -> void: hits[0] += 1
	)
	var shielded: bool = boss.is_shielded()
	var model: BossVisual = boss.look().model()
	var bays: Array[Node3D] = []
	for marker_name: StringName in model.extra_markers:
		var text: String = String(marker_name)
		if text.begins_with("LaunchBay") and not text.ends_with("Spawn"):
			bays.append(model.marker(marker_name))
	# The hull deflects a shot on it, clear of the bays, while shielded.
	var hull: Rect2 = boss.look().hull_rect()
	var on_hull: Vector3 = boss.position + Vector3(0.0, hull.end.y * HULL_PROBE, 0.0)
	var _deflected: bool = boss.resolve_shot(on_hull, PlayerShot.RADIUS)
	var hull_hits: int = hits[0]
	var visible_bays: int = 0
	for bay: Node3D in bays:
		if bay.is_visible_in_tree():
			visible_bays += 1
		var _spent: bool = boss.resolve_shot(bay.global_position, PlayerShot.RADIUS)
	boss.free()
	var _fighting_shielded: GdUnitAssert = assert_bool(shielded).is_true()
	var _four_bays: GdUnitAssert = assert_int(visible_bays).is_equal(4)
	var _hull_deflects: GdUnitAssert = assert_int(hull_hits).is_equal(0)
	var _every_bay_hits: GdUnitAssert = assert_int(hits[0]).is_equal(visible_bays)


func test_every_boss_weak_point_and_turret_is_on_its_model() -> void:
	_h.reach_skirmish()
	var wrong: Array[String] = []
	for level: LevelDefinition in _h.run.levels:
		var boss: Boss = _boss(level.boss)
		var look: BossLook = boss.look()
		var model: BossVisual = look.model()
		var drawn: AABB = model.transform * model.bounds()
		var points: Array[Vector3] = [Vector3.ZERO]
		points.append_array(look.turret_points())
		points.append_array(look.bay_points())
		for point: Vector3 in points:
			var on_model: bool = (
				point.x >= drawn.position.x
				and point.x <= drawn.end.x
				and point.y >= drawn.position.y
				and point.y <= drawn.end.y
			)
			if not on_model:
				wrong.append("%s point %s off its model %s" % [level.boss.id, point, drawn])
		# The rules' body is the drawn hull: a shot just inside it lands, and one
		# just outside it misses.
		var hull: Rect2 = look.hull_rect()
		var inset: Vector2 = hull.size * EDGE_SHARE
		var inside: Array[Vector2] = [hull.position + inset, hull.end - inset]
		var outside: Array[Vector2] = [hull.position - inset, hull.end + inset]
		for at: Vector2 in inside:
			if not boss.touches(boss.position + Vector3(at.x, at.y, 0.0), 0.0):
				wrong.append("%s misses its own hull at %s" % [level.boss.id, at])
		for at: Vector2 in outside:
			if boss.touches(boss.position + Vector3(at.x, at.y, 0.0), 0.0):
				wrong.append("%s takes hits in open air at %s" % [level.boss.id, at])
		var drawn_rect: Rect2 = Rect2(
			Vector2(drawn.position.x, drawn.position.y), Vector2(drawn.size.x, drawn.size.y)
		)
		var drift: float = maxf(
			(hull.position - drawn_rect.position).length(), (hull.end - drawn_rect.end).length()
		)
		if drift > drawn_rect.size.length() * BAKE_TOLERANCE:
			wrong.append("%s body %s is not its drawn hull %s" % [level.boss.id, hull, drawn_rect])
		# Every point shows, even with no telegraph running.
		if look.shown_glows() != look.turret_points().size() + look.bay_points().size():
			wrong.append("%s shows %d point glows" % [level.boss.id, look.shown_glows()])
		if look.turret_points().is_empty():
			wrong.append("%s has no gun" % level.boss.id)
		boss.free()
	var _on_models: GdUnitAssert = assert_array(wrong).is_empty()
