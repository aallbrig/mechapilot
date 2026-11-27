class_name SkyEnvironment
extends Node3D
## One level's sky: the world Environment and sun (the lighting setup), the
## theme's gradient sky shader as the Environment's background (so it sits
## behind everything for any camera), parallax cloud layers that wrap around the focus,
## and the theme's weather (the storm's rain and lightning). SkyLibrary maps the
## Level data's `sky` id to one of these scenes.
## Place it at the world origin, and call follow() every frame with the camera's
## focus (usually the player). It owns the world's WorldEnvironment and its only
## light, so a scene shows one sky at a time.

## Emitted when lightning strikes, for thunder and screen effects (0..1).
signal lightning_struck(strength: float)

const WORLD_ENVIRONMENT: NodePath = ^"WorldEnvironment"
const SUN: NodePath = ^"Sun"
const CLOUDS: NodePath = ^"Clouds"
const WEATHER: NodePath = ^"Weather"
## The storm sky shader's parameters driven by lightning.
const FLASH_PARAM: StringName = &"flash"
const BOLT_PARAM: StringName = &"bolt_x"
const WORLD_OFFSET_PARAM: StringName = &"world_offset"
## Range of the bolt's horizontal position in sky coordinates.
const BOLT_RANGE: Vector2 = Vector2(-0.9, 0.9)
## Chance that a strike flickers a second time.
const DOUBLE_FLASH_CHANCE: float = 0.5
const DOUBLE_FLASH_DELAY: float = 0.12

## The Level data id this sky answers to (dawn, storm, sunset, night,
## stratosphere, orbit).
@export var sky_id: StringName = &""
## Seconds between lightning strikes (min, max); zero disables lightning.
@export var lightning_interval: Vector2 = Vector2.ZERO
## How fast a flash fades (per second).
@export var lightning_decay: float = 4.0
## Extra sun energy at full flash.
@export var lightning_light_boost: float = 2.5
## Seed for lightning timing and placement, so a run replays the same.
@export var lightning_seed: int = 7

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _flash: float = 0.0
var _next_strike: float = 0.0
var _second_flash_in: float = -1.0
var _sun_energy: float = 1.0
var _world_offset: Vector2 = Vector2.ZERO
var _released_environment: Environment


func _ready() -> void:
	_rng.seed = lightning_seed
	_sun_energy = sun().light_energy
	_schedule_strike()
	set_process(has_lightning())


func _process(delta: float) -> void:
	_next_strike -= delta
	if _next_strike <= 0.0:
		strike(_rng.randf_range(0.7, 1.0))
		_schedule_strike()
		if _rng.randf() < DOUBLE_FLASH_CHANCE:
			_second_flash_in = DOUBLE_FLASH_DELAY
	if _second_flash_in >= 0.0:
		_second_flash_in -= delta
		if _second_flash_in < 0.0:
			strike(_rng.randf_range(0.5, 0.9))
	_flash = move_toward(_flash, 0.0, lightning_decay * delta)
	_apply_flash()


## Keep the weather and the cloud wrap centred on the focus.
func follow(focus: Vector3) -> void:
	var weather: Node3D = get_node_or_null(WEATHER) as Node3D
	if weather != null:
		weather.position = focus
	var focus_2d: Vector2 = Vector2(focus.x, focus.y)
	for layer: CloudLayer in cloud_layers():
		layer.follow(focus_2d)


## The scene moved its origin back by `offset` (to keep coordinates small on a
## long flight). The clouds keep their places relative to the focus and the
## sky's parallax keeps counting from the original origin, so nothing jumps.
## Call it with the same offset you subtract from the camera and the focus.
func shift_origin(offset: Vector3) -> void:
	var flat: Vector2 = Vector2(offset.x, offset.y)
	_world_offset += flat
	for layer: CloudLayer in cloud_layers():
		layer.shift_origin(flat)
	var weather: Node3D = get_node_or_null(WEATHER) as Node3D
	if weather != null:
		weather.position -= offset
	var material: ShaderMaterial = sky_material()
	if material != null:
		material.set_shader_parameter(WORLD_OFFSET_PARAM, _world_offset)


## The total distance the origin has been moved back by.
func world_offset() -> Vector2:
	return _world_offset


## Flash lightning now (0..1).
func strike(strength: float) -> void:
	_flash = maxf(_flash, clampf(strength, 0.0, 1.0))
	var material: ShaderMaterial = sky_material()
	if material != null:
		material.set_shader_parameter(BOLT_PARAM, _rng.randf_range(BOLT_RANGE.x, BOLT_RANGE.y))
	_apply_flash()
	lightning_struck.emit(strength)


func has_lightning() -> bool:
	return lightning_interval.y > 0.0


## The current lightning flash (0 when none).
func flash_amount() -> float:
	return _flash


## The world's WorldEnvironment, or null once release_world_environment() ran.
func world_environment() -> WorldEnvironment:
	return get_node_or_null(WORLD_ENVIRONMENT) as WorldEnvironment


## Give up the WorldEnvironment node and keep only its Environment, for a
## camera to look through (Camera3D.environment). A scene holds one
## WorldEnvironment, the world's own sky's: a second sky shown by its own
## camera (the attract scene's) releases its node. Returns the Environment.
func release_world_environment() -> Environment:
	var node: WorldEnvironment = world_environment()
	if node == null:
		return _released_environment
	_released_environment = node.environment
	remove_child(node)
	node.free()
	return _released_environment


func sun() -> DirectionalLight3D:
	return get_node(SUN) as DirectionalLight3D


func environment() -> Environment:
	var node: WorldEnvironment = world_environment()
	return node.environment if node != null else _released_environment


## The theme's sky shader material (the Environment's background).
func sky_material() -> ShaderMaterial:
	var sky: Sky = environment().sky
	if sky == null:
		return null
	return sky.sky_material as ShaderMaterial


func cloud_layers() -> Array[CloudLayer]:
	var layers: Array[CloudLayer] = []
	for child: Node in get_node(CLOUDS).get_children():
		var layer: CloudLayer = child as CloudLayer
		if layer != null:
			layers.append(layer)
	return layers


func _schedule_strike() -> void:
	if has_lightning():
		_next_strike = _rng.randf_range(lightning_interval.x, lightning_interval.y)


func _apply_flash() -> void:
	sun().light_energy = _sun_energy + _flash * lightning_light_boost
	var material: ShaderMaterial = sky_material()
	if material != null and has_lightning():
		material.set_shader_parameter(FLASH_PARAM, _flash)
