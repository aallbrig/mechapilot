class_name FlightStage
extends Node3D
## The 3D world the player flies in, seen side-on: sky, light, clouds, the
## camera rig, the player mech, its input, shot pool and death ragdoll. It wires
## these game nodes to each other (each reaches only what it is given) and adds
## the camera's share of the juice for shots and hits. It links the mech to the
## Events bus (PlayerBusLink) and spawns the Repair Kits the rules drop. It runs
## in play, Level Clear, Game Over and Victory; it holds still while Paused and
## behind the Title and Scoreboard.

## Camera kick per shot (units, against the aim), and shake per shot and per hit.
const SHOT_KICK: float = 0.25
const SHOT_TRAUMA: float = 0.04
const HIT_TRAUMA: float = 0.5
const HIT_FOV_PUNCH: float = 4.0
const DEATH_TRAUMA: float = 1.0
const DEATH_FOV_PUNCH: float = 14.0
const SKY_COLOR: Color = Color(0.0, 0.1, 0.3)
const AMBIENT_COLOR: Color = Color(0.45, 0.5, 0.7)
const AMBIENT_ENERGY: float = 0.6
const FOG_COLOR: Color = Color(0.35, 0.55, 0.85)
const FOG_DENSITY: float = 0.01
const GLOW_INTENSITY: float = 0.9
const GLOW_BLOOM: float = 0.05
const GLOW_THRESHOLD: float = 0.9
const SUN_ANGLES: Vector3 = Vector3(-35.0, 25.0, 0.0)
const SUN_COLOR: Color = Color(1.0, 0.957, 0.839)
const SUN_ENERGY: float = 1.1
## The seed for the sky and every random effect in a stage.
const DEFAULT_SEED: int = 22

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player: PlayerMech = PlayerMech.new()
var _input: PlayerInput = PlayerInput.new()
var _shots: ShotPool = ShotPool.new()
var _debris: MechDebris = MechDebris.new()
var _rig: CameraRig = CameraRig.new()
var _clouds: CloudField = CloudField.new()
var _link: PlayerBusLink = PlayerBusLink.new()
var _pickups: Node3D = Node3D.new()


func _init() -> void:
	rng.seed = DEFAULT_SEED
	_build_world()
	add_child(_clouds)
	_clouds.scatter(rng)
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
	_connect(_player.fired.connect(_on_fired) as Error)
	_connect(_player.hit_taken.connect(_on_hit_taken) as Error)
	_connect(_player.destroyed.connect(_on_destroyed) as Error)
	_connect(_player.respawned.connect(_on_respawned) as Error)


func _ready() -> void:
	_rig.snap_to(_player.position)
	_link.link(Events, _player, _input)
	_connect(Events.flow.game_state_changed.connect(_on_game_state_changed) as Error)
	_connect(Events.player.repair_kit_dropped.connect(spawn_repair_kit) as Error)
	_set_running(false)


func _process(_delta: float) -> void:
	_clouds.wrap_around(_rig.camera().global_position)


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


func _on_fired(_origin: Vector3, direction: Vector3) -> void:
	_rig.kick(-direction * SHOT_KICK)
	_rig.add_trauma(SHOT_TRAUMA)


func _on_hit_taken(_damage: int, _position: Vector3) -> void:
	_rig.add_trauma(HIT_TRAUMA)
	_rig.punch_fov(HIT_FOV_PUNCH)


func _on_destroyed(_position: Vector3) -> void:
	_rig.add_trauma(DEATH_TRAUMA)
	_rig.punch_fov(DEATH_FOV_PUNCH)
	_shots.clear()


func _on_respawned(position_now: Vector3) -> void:
	_rig.snap_to(position_now)


func _build_world() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = FOG_DENSITY
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_THRESHOLD
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ANGLES
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	add_child(sun)


func _connect(err: Error) -> void:
	if err != OK:
		push_error("FlightStage: could not connect a signal: %s" % error_string(err))
