extends GdUnitTestSuite
## The flight stage wires the player to its input, shots, ragdoll and camera, and
## runs only during the Gameplay Game State. main.gd mounts the mech's juice.

const TICK: float = 1.0 / 60.0


func test_stage_wires_the_player_to_its_parts() -> void:
	var stage: FlightStage = FlightStage.new()
	add_child(stage)
	var player: PlayerMech = stage.player()
	var wired: bool = (
		player.input == stage.player_input()
		and player.shots == stage.shots()
		and player.view == stage.camera_rig()
		and player.debris != null
		and stage.camera_rig().target == player
	)
	stage.free()
	var _wired: GdUnitAssert = assert_bool(wired).is_true()


func test_stage_runs_in_play_and_holds_still_when_paused() -> void:
	var stage: FlightStage = FlightStage.new()
	add_child(stage)
	var idle: Node.ProcessMode = stage.process_mode
	Events.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.SKIRMISH)
	var playing: Node.ProcessMode = stage.process_mode
	Events.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.PAUSED)
	var paused: Node.ProcessMode = stage.process_mode
	Events.flow.announce_game_state_changed(GameState.Phase.PAUSED, GameState.Phase.GAME_OVER)
	var over: Node.ProcessMode = stage.process_mode
	Events.flow.announce_game_state_changed(GameState.Phase.GAME_OVER, GameState.Phase.TITLE)
	var title: Node.ProcessMode = stage.process_mode
	var input_mode: Node.ProcessMode = stage.player_input().process_mode
	stage.free()
	var _idle: GdUnitAssert = assert_int(idle).is_equal(Node.PROCESS_MODE_DISABLED)
	var _playing: GdUnitAssert = assert_int(playing).is_equal(Node.PROCESS_MODE_INHERIT)
	var _paused: GdUnitAssert = assert_int(paused).is_equal(Node.PROCESS_MODE_DISABLED)
	# The ragdoll settles behind the Game Over tally.
	var _over: GdUnitAssert = assert_int(over).is_equal(Node.PROCESS_MODE_INHERIT)
	var _title: GdUnitAssert = assert_int(title).is_equal(Node.PROCESS_MODE_DISABLED)
	var _detects_always: GdUnitAssert = assert_int(input_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_stage_spawns_dropped_repair_kits_for_its_mech() -> void:
	var stage: FlightStage = FlightStage.new()
	add_child(stage)
	Events.player.announce_repair_kit_dropped(Vector3(4.0, 2.0, 1.0))
	var kits: Array[RepairKit] = stage.repair_kits()
	var count: int = kits.size()
	var at: Vector3 = kits[0].position if count > 0 else Vector3.INF
	var collector: bool = count > 0 and kits[0].collector == stage.player()
	stage.free()
	var _spawned: GdUnitAssert = assert_int(count).is_equal(1)
	var _on_plane: GdUnitAssert = assert_vector(at).is_equal(Vector3(4.0, 2.0, 0.0))
	var _for_the_mech: GdUnitAssert = assert_bool(collector).is_true()


func test_firing_fills_the_stage_shot_pool() -> void:
	var stage: FlightStage = FlightStage.new()
	add_child(stage)
	var intent: PilotIntent = PilotIntent.new()
	intent.aim = Vector2.RIGHT
	intent.firing = true
	stage.player().tick(TICK, intent)
	var live: int = stage.shots().live_count()
	stage.free()
	var _one_shot: GdUnitAssert = assert_int(live).is_equal(1)


func test_main_mounts_the_mech_juice_on_the_player() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	var main: Node = scene.instantiate()
	add_child(main)
	var fx: MechFeedback = main.get_node("MechFeedback") as MechFeedback
	var stage: FlightStage = main.get_node("FlightStage") as FlightStage
	var flames: int = fx.flames().size()
	var trails: int = fx.eye_trails().size()
	stage.player().tick(TICK, PilotIntent.new())
	var power: float = fx.flames()[0].power
	main.free()
	var _flames: GdUnitAssert = assert_int(flames).is_equal(4)
	var _trails: GdUnitAssert = assert_int(trails).is_equal(3)
	var _driven: GdUnitAssert = assert_float(power).is_greater(0.0)


func test_stage_flies_under_each_levels_sky() -> void:
	var stage: FlightStage = FlightStage.new()
	add_child(stage)
	var errors: PackedStringArray = PackedStringArray()
	var levels: Array[LevelDefinition] = LevelLibrary.all_levels(errors)
	stage.use_levels(levels)
	var before_any: StringName = stage.sky().sky_id
	var shown: Array[StringName] = []
	var wanted: Array[StringName] = []
	var lit_attract: bool = false
	for level_number: int in range(1, levels.size() + 1):
		Events.run.announce_level_intro_started(level_number, "", "", 0.0)
		shown.append(stage.sky().sky_id)
		wanted.append(levels[level_number - 1].sky_theme)
		var sun_mask: int = stage.sky().sun().light_cull_mask
		lit_attract = lit_attract or (sun_mask & AttractDogfight.layer_mask()) != 0
	stage.free()
	var _loaded: GdUnitAssert = assert_array(errors).is_empty()
	var _default: GdUnitAssert = assert_str(String(before_any)).is_equal(
		String(FlightStage.DEFAULT_SKY)
	)
	var _each_level: GdUnitAssert = assert_array(shown).is_equal(wanted)
	var _sun_leaves_attract: GdUnitAssert = assert_bool(lit_attract).is_false()
