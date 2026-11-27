class_name BossLook
extends Node3D
## A boss's model, driven by Boss and owning no game logic. Until the model
## kit (#27) lands, a placeholder: a hull in the boss's colour, a glowing
## core whose colour shifts with each phase, and a glow on every turret that
## brightens through each attack's telegraph. set_flash() shows the hit flash.

const PHASE_CORE_COLORS: Array[Color] = [
	Color(0.3, 0.8, 1.0), Color(1.0, 0.6, 0.1), Color(1.0, 0.15, 0.2)
]
const GLOW_COLOR: Color = Color(1.0, 0.75, 0.2)
const FLASH_COLOR: Color = Color.WHITE
const GLOW_IDLE: float = 0.6
const GLOW_FULL: float = 9.0
const GLOW_GROW: float = 2.0
const TURRET_SIZE: float = 0.5
const CORE_SHARE: float = 0.3
const CORE_GLOW: float = 3.0

var _hull: MeshInstance3D = MeshInstance3D.new()
var _hull_material: StandardMaterial3D = StandardMaterial3D.new()
var _core: MeshInstance3D = MeshInstance3D.new()
var _core_material: StandardMaterial3D = StandardMaterial3D.new()
var _glows: Array[MeshInstance3D] = []
var _glow_material: StandardMaterial3D = StandardMaterial3D.new()
var _flash_material: StandardMaterial3D = StandardMaterial3D.new()
var _flashing: bool = false


func _init(profile: BossProfile) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = profile.size
	_hull.mesh = box
	_hull_material.albedo_color = profile.color
	_hull.material_override = _hull_material
	add_child(_hull)
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = profile.size.y * CORE_SHARE
	core_mesh.height = core_mesh.radius * 2.0
	_core.mesh = core_mesh
	_core.position = Vector3(0.0, 0.0, profile.size.z * 0.5)
	_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_material.emission_enabled = true
	_core_material.emission_energy_multiplier = CORE_GLOW
	_core.material_override = _core_material
	add_child(_core)
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.albedo_color = GLOW_COLOR
	_glow_material.emission_enabled = true
	_glow_material.emission = GLOW_COLOR
	var glow_mesh: SphereMesh = SphereMesh.new()
	glow_mesh.radius = TURRET_SIZE
	glow_mesh.height = TURRET_SIZE * 2.0
	for turret: Vector3 in profile.turrets:
		var glow: MeshInstance3D = MeshInstance3D.new()
		glow.mesh = glow_mesh
		glow.material_override = _glow_material
		glow.position = turret
		add_child(glow)
		_glows.append(glow)
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = FLASH_COLOR
	set_phase(0)
	set_charge(0.0)


## Show the phase's core colour (0-based).
func set_phase(phase: int) -> void:
	var tint: Color = PHASE_CORE_COLORS[clampi(phase, 0, PHASE_CORE_COLORS.size() - 1)]
	_core_material.albedo_color = tint
	_core_material.emission = tint


## The telegraph on every turret: 0 idle, 1 about to fire.
func set_charge(amount: float) -> void:
	var t: float = clampf(amount, 0.0, 1.0)
	_glow_material.emission_energy_multiplier = lerpf(GLOW_IDLE, GLOW_FULL, t)
	for glow: MeshInstance3D in _glows:
		glow.scale = Vector3.ONE * lerpf(1.0, GLOW_GROW, t)


## The core's colour now (it shows the phase).
func core_color() -> Color:
	return _core_material.albedo_color


## Hide the turret glows: the launch bays are wrecked (the Leviathan).
func set_bays_destroyed(destroyed: bool) -> void:
	for glow: MeshInstance3D in _glows:
		glow.visible = not destroyed


## True when every turret glow is hidden.
func bays_destroyed() -> bool:
	for glow: MeshInstance3D in _glows:
		if glow.visible:
			return false
	return not _glows.is_empty()


func glow_energy() -> float:
	return _glow_material.emission_energy_multiplier


func set_flash(on: bool) -> void:
	_flashing = on
	_hull.material_override = _flash_material if on else _hull_material


func is_flashing() -> bool:
	return _flashing
