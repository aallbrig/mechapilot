class_name AttractDogfight
extends Node3D
## The Title's attract mode (#73): an AI-flown mech dogfighting a few enemies
## behind the menu. It is self-contained on purpose: it announces no Game
## Events (so it never scores, unlocks Intel or spawns through the rules), and
## builds its scene from primitive meshes.
##
## Seam: when the gameplay scenes (player mech #22, enemies #23) are in, the
## composition root can swap this node for the real stage flown by a bot pilot.
## Anything with this node's contract works: it shows and runs only while
## `active_phases` holds the Game State, and stays idle otherwise.

const ACTIVE_PHASES: Array[GameState.Phase] = [GameState.Phase.BOOT, GameState.Phase.TITLE]
const ENEMY_COUNT: int = 4
const ORBIT_RADIUS: float = 9.0
const MECH_ORBIT_RADIUS: float = 5.0
const MECH_ORBIT_SPEED: float = 0.55
const ENEMY_ORBIT_SPEED: float = 0.35
const BOB_HEIGHT: float = 1.2
const FIRE_INTERVAL: float = 0.35
const SHOT_SPEED: float = 22.0
const SHOT_GRAVITY: float = 9.0
const SHOT_LIFE: float = 1.6
const HIT_RADIUS: float = 1.1
const RESPAWN_TIME: float = 1.2
const BLAST_TIME: float = 0.5
const BLAST_SCALE: float = 3.5
const CAMERA_POSITION: Vector3 = Vector3(0.0, 0.0, 22.0)
const SKY_TOP: Color = Color(0.16, 0.24, 0.55)
const SKY_HORIZON: Color = Color(0.98, 0.62, 0.55)
const MECH_COLOR: Color = Color(0.75, 0.9, 1.0)
const ENEMY_COLOR: Color = Color(1.0, 0.35, 0.4)
const SHOT_COLOR: Color = Color(1.0, 0.9, 0.4)
const BLAST_COLOR: Color = Color(1.0, 0.6, 0.2)

var _time: float = 0.0
var _fire_left: float = 0.0
var _mech: MeshInstance3D
var _enemies: Array[MeshInstance3D] = []
var _enemy_phase: Array[float] = []
var _respawn_left: Array[float] = []
var _shots: Array[MeshInstance3D] = []
var _shot_velocity: Array[Vector3] = []
var _shot_age: Array[float] = []
var _shot_mesh: SphereMesh
var _kills: int = 0


func _ready() -> void:
	_build_world()
	_mech = _mesh(_mech_mesh(), MECH_COLOR)
	for i: int in ENEMY_COUNT:
		var enemy: MeshInstance3D = _mesh(_enemy_mesh(), ENEMY_COLOR)
		_enemies.append(enemy)
		_enemy_phase.append(TAU * i / ENEMY_COUNT)
		_respawn_left.append(0.0)
	_shot_mesh = SphereMesh.new()
	_shot_mesh.radius = 0.15
	_shot_mesh.height = 0.3
	if Events.flow.game_state_changed.connect(_on_game_state_changed) != OK:
		push_error("AttractDogfight: could not hear game_state_changed")
	_activate(true)


## True while the dogfight runs.
func is_active() -> bool:
	return visible


## Enemies shot down so far (the dogfight is alive).
func kills() -> int:
	return _kills


## Advances the dogfight by `delta` seconds (the engine calls it every frame).
func step(delta: float) -> void:
	_time += delta
	var mech_angle: float = _time * MECH_ORBIT_SPEED
	_mech.position = Vector3(
		cos(mech_angle) * MECH_ORBIT_RADIUS, sin(mech_angle * 2.0) * BOB_HEIGHT, 0.0
	)
	_mech.rotation.z = mech_angle + PI * 0.5
	for i: int in _enemies.size():
		_step_enemy(i, delta)
	_fire_left -= delta
	if _fire_left <= 0.0:
		_fire_left = FIRE_INTERVAL
		_fire()
	_step_shots(delta)


func _process(delta: float) -> void:
	step(delta)


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_activate(ACTIVE_PHASES.has(to))


func _activate(on: bool) -> void:
	visible = on
	set_process(on)


func _step_enemy(i: int, delta: float) -> void:
	var enemy: MeshInstance3D = _enemies[i]
	if _respawn_left[i] > 0.0:
		_respawn_left[i] -= delta
		enemy.visible = _respawn_left[i] <= 0.0
		return
	var angle: float = _enemy_phase[i] - _time * ENEMY_ORBIT_SPEED
	enemy.position = Vector3(
		cos(angle) * ORBIT_RADIUS, sin(angle * 1.5) * ORBIT_RADIUS * 0.45, -2.0
	)
	enemy.rotation.z = angle - PI * 0.5


func _fire() -> void:
	var target: MeshInstance3D = _nearest_enemy()
	if target == null:
		return
	var aim: Vector3 = (target.position - _mech.position).normalized()
	var shot: MeshInstance3D = MeshInstance3D.new()
	shot.mesh = _shot_mesh
	shot.material_override = _material(SHOT_COLOR, true)
	shot.position = _mech.position
	add_child(shot)
	_shots.append(shot)
	# Aim a little high: the shots drop, like the player's.
	_shot_velocity.append((aim + Vector3.UP * 0.12).normalized() * SHOT_SPEED)
	_shot_age.append(0.0)


func _step_shots(delta: float) -> void:
	for i: int in range(_shots.size() - 1, -1, -1):
		_shot_velocity[i] += Vector3.DOWN * SHOT_GRAVITY * delta
		_shots[i].position += _shot_velocity[i] * delta
		_shot_age[i] += delta
		var hit: int = _hit_enemy(_shots[i].position)
		if hit >= 0:
			_destroy(hit)
		if hit >= 0 or _shot_age[i] > SHOT_LIFE:
			_shots[i].queue_free()
			_shots.remove_at(i)
			_shot_velocity.remove_at(i)
			_shot_age.remove_at(i)


func _hit_enemy(at: Vector3) -> int:
	for i: int in _enemies.size():
		if _respawn_left[i] <= 0.0 and _enemies[i].position.distance_to(at) < HIT_RADIUS:
			return i
	return -1


func _destroy(i: int) -> void:
	_kills += 1
	_respawn_left[i] = RESPAWN_TIME
	_enemies[i].visible = false
	var blast: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	blast.mesh = sphere
	blast.material_override = _material(BLAST_COLOR, true)
	blast.position = _enemies[i].position
	add_child(blast)
	var tween: Tween = blast.create_tween().set_parallel(true)
	var _grow: PropertyTweener = tween.tween_property(
		blast, "scale", Vector3.ONE * BLAST_SCALE, BLAST_TIME
	)
	var _fade: PropertyTweener = tween.tween_property(
		blast.material_override, "albedo_color:a", 0.0, BLAST_TIME
	)
	var _gone: CallbackTweener = tween.chain().tween_callback(blast.queue_free)


func _nearest_enemy() -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_distance: float = INF
	for i: int in _enemies.size():
		if _respawn_left[i] > 0.0:
			continue
		var distance: float = _enemies[i].position.distance_to(_mech.position)
		if distance < best_distance:
			best_distance = distance
			best = _enemies[i]
	return best


func _build_world() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.position = CAMERA_POSITION
	camera.current = true
	add_child(camera)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, 0.6, 0.0)
	add_child(light)
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP
	sky_material.sky_horizon_color = SKY_HORIZON
	sky_material.ground_horizon_color = SKY_HORIZON
	sky_material.ground_bottom_color = SKY_TOP
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, false)
	add_child(instance)
	return instance


static func _mech_mesh() -> Mesh:
	var body: CapsuleMesh = CapsuleMesh.new()
	body.radius = 0.45
	body.height = 1.8
	return body


static func _enemy_mesh() -> Mesh:
	var body: PrismMesh = PrismMesh.new()
	body.size = Vector3(1.2, 1.6, 0.5)
	return body


static func _material(color: Color, glow: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
