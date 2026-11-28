class_name FlightStage
extends Node3D
## The 3D world the player flies in, seen side-on: the Level's sky (its
## SkyLibrary scene: the world's one WorldEnvironment, its sun and its cloud
## layers), the camera rig, the player mech, its input, shot pool and death
## ragdoll. It wires these game nodes to each other (each reaches only what it
## is given). The camera's juice is decided by feedback/ (CameraJuice, which
## honours the shake and reduced-motion settings) and main.gd connects it to
## camera_rig(). It links the mech to the
## Events bus (PlayerBusLink) and spawns the Repair Kits the rules drop. It runs
## in play, Level Clear, Game Over and Victory; it holds still while Paused and
## behind the Title and Scoreboard.

## The sky shown before a Level names its own (the first Level's).
const DEFAULT_SKY: StringName = &"dawn"
## The seed for every random effect in a stage.
const DEFAULT_SEED: int = 22

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player: PlayerMech = PlayerMech.new()
var _input: PlayerInput = PlayerInput.new()
var _shots: ShotPool = ShotPool.new()
var _debris: MechDebris = MechDebris.new()
var _rig: CameraRig = CameraRig.new()
var _sky: SkyEnvironment
var _levels: Array[LevelDefinition] = []
var _link: PlayerBusLink = PlayerBusLink.new()
var _pickups: Node3D = Node3D.new()


func _init() -> void:
	rng.seed = DEFAULT_SEED
	show_sky(DEFAULT_SKY)
	# Device detection runs in every Game State, so menus show the right glyphs.
	_input.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_input)
	add_child(_shots)
	add_child(_debris)
	add_child(_pickups)
	add_child(_link)
	add_child(_player)
	add_child(_rig)
	_player.name = "Player"
	_player.input = _input
	_player.shots = _shots
	_player.debris = _debris
	_player.view = _rig
	_player.rng = rng
	_rig.target = _player
	_connect(_player.destroyed.connect(_on_destroyed) as Error)
	_connect(_player.respawned.connect(_on_respawned) as Error)


func _ready() -> void:
	_rig.snap_to(_player.position)
	_link.link(Events, _player, _input)
	_connect(Events.flow.game_state_changed.connect(_on_game_state_changed) as Error)
	_connect(Events.player.repair_kit_dropped.connect(spawn_repair_kit) as Error)
	_connect(Events.run.level_intro_started.connect(_on_level_intro_started) as Error)
	_set_running(false)


func _process(_delta: float) -> void:
	_sky.follow(_rig.camera().global_position)


## The Levels whose skies the stage shows, by number (from the Level data).
func use_levels(levels: Array[LevelDefinition]) -> void:
	_levels = levels


## Show the sky of theme `sky_id` (a SkyLibrary id) in place of the current one.
func show_sky(sky_id: StringName) -> void:
	if _sky != null and _sky.sky_id == sky_id:
		return
	var next: SkyEnvironment = SkyLibrary.instantiate(sky_id)
	if next == null:
		return
	if _sky != null:
		remove_child(_sky)
		_sky.queue_free()
	_sky = next
	# The attract scene behind the Title lights itself; this sun leaves its layer.
	_sky.sun().light_cull_mask = _sky.sun().light_cull_mask & ~AttractDogfight.layer_mask()
	add_child(_sky)
	move_child(_sky, 0)


## The sky shown now.
func sky() -> SkyEnvironment:
	return _sky


func player() -> PlayerMech:
	return _player


func player_input() -> PlayerInput:
	return _input


func camera_rig() -> CameraRig:
	return _rig


func shots() -> ShotPool:
	return _shots


## The Repair Kits in the sky.
func repair_kits() -> Array[RepairKit]:
	var kits: Array[RepairKit] = []
	for node: Node in _pickups.get_children():
		var kit: RepairKit = node as RepairKit
		if kit != null and not kit.is_spent():
			kits.append(kit)
	return kits


## Drop a Repair Kit at `at` that only this stage's mech can collect.
func spawn_repair_kit(at: Vector3) -> void:
	var kit: RepairKit = RepairKit.new()
	kit.position = Vector3(at.x, at.y, 0.0)
	kit.collector = _player
	_pickups.add_child(kit)


## Whether the stage runs in `phase`.
static func runs_in(phase: GameState.Phase) -> bool:
	return (
		GameState.is_play(phase)
		or phase == GameState.Phase.LEVEL_CLEAR
		or phase == GameState.Phase.GAME_OVER
		or phase == GameState.Phase.VICTORY
	)


## Run (Gameplay) or hold still (every other Game State).
func _set_running(running: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if running else Node.PROCESS_MODE_DISABLED


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_set_running(runs_in(to))


func _on_destroyed(_position: Vector3) -> void:
	_shots.clear()


func _on_respawned(position_now: Vector3) -> void:
	_rig.snap_to(position_now)


func _on_level_intro_started(
	level_number: int, _level_name: String, _objective: String, _duration: float
) -> void:
	if level_number >= 1 and level_number <= _levels.size():
		show_sky(_levels[level_number - 1].sky_theme)


func _connect(err: Error) -> void:
	if err != OK:
		push_error("FlightStage: could not connect a signal: %s" % error_string(err))
