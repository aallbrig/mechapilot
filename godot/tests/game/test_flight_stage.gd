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


func test_stage_runs_only_during_gameplay() -> void:
	var stage: FlightStage = FlightStage.new()
	add_child(stage)
	var idle: Node.ProcessMode = stage.process_mode
	Events.announce_game_state_changed(GameState.Phase.MENU, GameState.Phase.GAMEPLAY)
	var playing: Node.ProcessMode = stage.process_mode
	Events.announce_game_state_changed(GameState.Phase.GAMEPLAY, GameState.Phase.GAME_OVER)
	var over: Node.ProcessMode = stage.process_mode
	var input_mode: Node.ProcessMode = stage.player_input().process_mode
	stage.free()
	var _idle: GdUnitAssert = assert_int(idle).is_equal(Node.PROCESS_MODE_DISABLED)
	var _playing: GdUnitAssert = assert_int(playing).is_equal(Node.PROCESS_MODE_INHERIT)
	var _over: GdUnitAssert = assert_int(over).is_equal(Node.PROCESS_MODE_DISABLED)
	var _detects_always: GdUnitAssert = assert_int(input_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


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
