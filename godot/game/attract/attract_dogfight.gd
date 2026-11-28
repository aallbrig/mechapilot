class_name AttractDogfight
extends Node3D
## The Title's attract mode (#73): an AI-flown mech dogfighting a few enemies
## behind the menu, under the Level 1 sky. It is self-contained on purpose: it
## announces no Game Events (so it never scores, unlocks Intel or spawns through
## the rules). Its look is the game's own: the dawn sky (SkyLibrary), the player
## mech (PlayerMechVisual) and the enemy models (VisualLibrary); only the shots
## and blasts are drawn here.
##
## It is the one title view: its camera is current and it runs only while
## ACTIVE_PHASES holds the Game State, and it hands the view back otherwise. Its
## models sit on their own visual layer and its camera renders only that layer,
## so the flight stage resting behind the Title never shows through.
##
## Seam: when the gameplay scenes are in, the composition root can swap this
## node for the real stage flown by a bot pilot; anything with this contract
## works.

const ACTIVE_PHASES: Array[GameState.Phase] = [GameState.Phase.BOOT, GameState.Phase.TITLE]
## The enemy models that take part, in order (one each).
const ENEMY_IDS: Array[StringName] = [&"fighter", &"interceptor", &"drone", &"heavy"]
## The sky the Title shows: Level 1's.
const SKY_ID: StringName = &"dawn"
## The visual layer (1-based) the attract scene draws on, alone.
const VISUAL_LAYER: int = 20
const ORBIT_RADIUS: float = 9.0
const MECH_ORBIT_RADIUS: float = 5.0
const MECH_ORBIT_SPEED: float = 0.55
const ENEMY_ORBIT_SPEED: float = 0.35
const BOB_HEIGHT: float = 1.2
const ENEMY_DEPTH: float = -2.0
const MECH_SCALE: float = 1.6
## How far the mech tilts toward its climb or dive (fraction of the slope angle).
const MECH_TILT: float = 0.5
## A streamlined flying pose for the mech, in the prototype's joint angles.
const WING_POSE: float = 0.35
const ARM_POSE: float = -0.75
const THIGH_POSE: float = -0.6
const SHIN_POSE: float = -0.08
const FIRE_INTERVAL: float = 0.35
const SHOT_SPEED: float = 22.0
const SHOT_GRAVITY: float = 9.0
const SHOT_LIFE: float = 1.6
const SHOT_RADIUS: float = 0.15
const HIT_RADIUS: float = 1.1
const RESPAWN_TIME: float = 1.2
const BLAST_TIME: float = 0.5
const BLAST_SCALE: float = 3.5
const CAMERA_POSITION: Vector3 = Vector3(0.0, 0.0, 22.0)
const SHOT_COLOR: Color = Color(1.0, 0.9, 0.4)
const BLAST_COLOR: Color = Color(1.0, 0.6, 0.2)

var _time: float = 0.0
var _fire_left: float = 0.0
var _sky: SkyEnvironment
var _mech: PlayerMechVisual
var _mech_last: Vector3 = Vector3.ZERO
var _enemies: Array[EnemyVisual] = []
var _enemy_last: Array[Vector3] = []
var _enemy_phase: Array[float] = []
var _respawn_left: Array[float] = []
var _shots: Array[MeshInstance3D] = []
var _shot_velocity: Array[Vector3] = []
var _shot_age: Array[float] = []
var _shot_mesh: SphereMesh
var _camera: Camera3D
var _kills: int = 0


func _ready() -> void:
	_build_world()
	_mech = VisualLibrary.player_mech()
	_mech.scale = Vector3.ONE * MECH_SCALE
	add_child(_mech)
	_pose(PlayerMechVisual.LEFT)
	_pose(PlayerMechVisual.RIGHT)
	for i: int in ENEMY_IDS.size():
		var enemy: EnemyVisual = VisualLibrary.enemy(ENEMY_IDS[i])
		add_child(enemy)
		_enemies.append(enemy)
		_enemy_last.append(Vector3.ZERO)
		_enemy_phase.append(TAU * i / ENEMY_IDS.size())
		_respawn_left.append(0.0)
	_shot_mesh = SphereMesh.new()
	_shot_mesh.radius = SHOT_RADIUS
	_shot_mesh.height = SHOT_RADIUS * 2.0
	_put_on_layer(self)
	if Events.flow.game_state_changed.connect(_on_game_state_changed) != OK:
		push_error("AttractDogfight: could not hear game_state_changed")
	step(0.0)
	_activate(true)


## True while the dogfight runs.
func is_active() -> bool:
	return visible


## Whether its camera is the view (it is, exactly while active).
func has_view() -> bool:
	return _camera.current


## The Environment its camera looks through (the sky's own).
func view_environment() -> Environment:
	return _camera.environment


## The visual layers its camera renders (the attract scene's own, alone).
func view_layers() -> int:
	return _camera.cull_mask


## Enemies shot down so far (the dogfight is alive).
func kills() -> int:
	return _kills


## The sky behind the dogfight.
func sky() -> SkyEnvironment:
	return _sky


## The player mech flying the dogfight.
func mech() -> PlayerMechVisual:
	return _mech


## The enemy models in the dogfight.
func enemies() -> Array[EnemyVisual]:
	return _enemies.duplicate()


## Advances the dogfight by `delta` seconds (the engine calls it every frame).
func step(delta: float) -> void:
	_time += delta
	var mech_angle: float = _time * MECH_ORBIT_SPEED
	_mech_last = _mech.position
	_mech.position = Vector3(
		cos(mech_angle) * MECH_ORBIT_RADIUS, sin(mech_angle * 2.0) * BOB_HEIGHT, 0.0
	)
	_face_mech(_mech.position - _mech_last)
	for i: int in _enemies.size():
		_step_enemy(i, delta)
	_fire_left -= delta
	if _fire_left <= 0.0:
		_fire_left = FIRE_INTERVAL
		_fire()
	_step_shots(delta)
	_sky.follow(_camera.position)


func _process(delta: float) -> void:
	step(delta)


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_activate(ACTIVE_PHASES.has(to))


func _activate(on: bool) -> void:
	visible = on
	set_process(on)
	# Hand the view back to the game's camera outside the Title.
	_camera.current = on


func _pose(side: int) -> void:
	_mech.wing(side).rotation.x = WING_POSE
	_mech.arm(side).rotation.x = ARM_POSE
	_mech.thigh(side).rotation.x = THIGH_POSE
	_mech.shin(side).rotation.x = SHIN_POSE


## Turn the mech to fly along `travel`: its body yaws to face left or right,
## and the whole mech tilts toward the climb or dive.
func _face_mech(travel: Vector3) -> void:
	if travel.length_squared() < 1e-10:
		return
	var facing: float = 1.0 if travel.x >= 0.0 else -1.0
	_mech.body().rotation.y = -PI * 0.5 * facing
	_mech.rotation.z = atan2(travel.y, absf(travel.x)) * MECH_TILT * facing


## Point a side-profile model (nose along +X) along `travel`, keeping it upright.
static func _face(model: Node3D, travel: Vector3) -> void:
	if travel.length_squared() < 1e-10:
		return
	if travel.x >= 0.0:
		model.rotation = Vector3(0.0, 0.0, atan2(travel.y, travel.x))
	else:
		model.rotation = Vector3(0.0, PI, atan2(travel.y, -travel.x))


func _step_enemy(i: int, delta: float) -> void:
	var enemy: EnemyVisual = _enemies[i]
	if _respawn_left[i] > 0.0:
		_respawn_left[i] -= delta
		enemy.visible = _respawn_left[i] <= 0.0
		return
	var angle: float = _enemy_phase[i] - _time * ENEMY_ORBIT_SPEED
	_enemy_last[i] = enemy.position
	enemy.position = Vector3(
		cos(angle) * ORBIT_RADIUS, sin(angle * 1.5) * ORBIT_RADIUS * 0.45, ENEMY_DEPTH
	)
	_face(enemy, enemy.position - _enemy_last[i])


func _fire() -> void:
	var target: EnemyVisual = _nearest_enemy()
	if target == null:
		return
	var aim: Vector3 = (target.position - _mech.position).normalized()
	var shot: MeshInstance3D = MeshInstance3D.new()
	shot.mesh = _shot_mesh
	shot.material_override = _material(SHOT_COLOR)
	shot.position = _mech.position
	shot.layers = layer_mask()
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
	blast.mesh = SphereMesh.new()
	blast.material_override = _material(BLAST_COLOR)
	blast.position = _enemies[i].position
	blast.layers = layer_mask()
	add_child(blast)
	var tween: Tween = blast.create_tween().set_parallel(true)
	var _grow: PropertyTweener = tween.tween_property(
		blast, "scale", Vector3.ONE * BLAST_SCALE, BLAST_TIME
	)
	var _fade: PropertyTweener = tween.tween_property(
		blast.material_override, "albedo_color:a", 0.0, BLAST_TIME
	)
	var _gone: CallbackTweener = tween.chain().tween_callback(blast.queue_free)


func _nearest_enemy() -> EnemyVisual:
	var best: EnemyVisual = null
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
	_camera = Camera3D.new()
	_camera.position = CAMERA_POSITION
	_camera.cull_mask = layer_mask()
	add_child(_camera)
	_sky = SkyLibrary.instantiate(SKY_ID)
	add_child(_sky)
	# The camera looks through the sky's own Environment, so the Title shows the
	# dawn sky whichever WorldEnvironment the world uses, and the sky's sun
	# lights only the attract scene.
	# Its WorldEnvironment node is released: the world's one is the stage's sky.
	_camera.environment = _sky.release_world_environment()
	_sky.sun().light_cull_mask = layer_mask()


## Move every visual node below `node` onto the attract scene's own layer.
static func _put_on_layer(node: Node) -> void:
	var visual: VisualInstance3D = node as VisualInstance3D
	if visual != null:
		visual.layers = layer_mask()
	for child: Node in node.get_children():
		_put_on_layer(child)


## The visual-layer bit of the attract scene (other lights leave it alone).
static func layer_mask() -> int:
	return 1 << (VISUAL_LAYER - 1)


static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
