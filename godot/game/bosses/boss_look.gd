class_name BossLook
extends Node3D
## A boss's model, driven by Boss and owning no game logic. It shows the boss's
## merged model from the visual pass (VisualLibrary.boss, #27), fitted inside
## the hull size the rules were tuned on, with that model's phase parts; a
## glowing core whose colour shifts with each phase; and a glow on every turret
## that shows only through each attack's telegraph. set_flash() shows the
## shared white hit flash.

const PHASE_CORE_COLORS: Array[Color] = [
	Color(0.3, 0.8, 1.0), Color(1.0, 0.6, 0.1), Color(1.0, 0.15, 0.2)
]
const GLOW_COLOR: Color = Color(1.0, 0.75, 0.2)
const GLOW_IDLE: float = 0.6
const GLOW_FULL: float = 9.0
const GLOW_GROW: float = 2.0
const TURRET_SIZE: float = 0.5
const CORE_SHARE: float = 0.3
const CORE_GLOW: float = 3.0
## The model's launch bays (the Leviathan's), hidden once they are wrecked.
const BAY_PREFIX: String = "LaunchBay"

var _model: BossVisual
var _core: MeshInstance3D = MeshInstance3D.new()
var _core_material: StandardMaterial3D = StandardMaterial3D.new()
var _glows: Array[MeshInstance3D] = []
var _glow_material: StandardMaterial3D = StandardMaterial3D.new()
var _bays: Array[Node3D] = []
var _flashing: bool = false
var _charging: bool = false
var _bays_destroyed: bool = false


func _init(profile: BossProfile) -> void:
	_model = VisualLibrary.boss(profile.id)
	var box: Vector3 = _model.bounds().size
	var fit: float = 1.0
	if box.x > 0.0 and box.y > 0.0:
		fit = minf(profile.size.x / box.x, profile.size.y / box.y)
	_model.scale = Vector3.ONE * fit
	add_child(_model)
	for marker_name: StringName in _model.extra_markers:
		var bay: Node3D = _model.marker(marker_name)
		if bay != null and String(marker_name).begins_with(BAY_PREFIX):
			if not String(marker_name).ends_with("Spawn"):
				_bays.append(bay)
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = profile.size.y * CORE_SHARE
	core_mesh.height = core_mesh.radius * 2.0
	_core.mesh = core_mesh
	_core.position = Vector3(0.0, 0.0, profile.size.z * 0.5)
	_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_material.emission_enabled = true
	_core_material.emission_energy_multiplier = CORE_GLOW
	_core.material_override = _core_material
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = turret
		add_child(glow)
		_glows.append(glow)
	set_phase(0)
	set_charge(0.0)


## The merged model shown (a VisualLibrary boss scene).
func model() -> BossVisual:
	return _model


## Show the phase (0-based): its core colour and the model's parts of it.
func set_phase(phase: int) -> void:
	var tint: Color = PHASE_CORE_COLORS[clampi(phase, 0, PHASE_CORE_COLORS.size() - 1)]
	_core_material.albedo_color = tint
	_core_material.emission = tint
	_model.set_phase(phase + 1)


## The telegraph on every turret: 0 idle (no glow), 1 about to fire.
func set_charge(amount: float) -> void:
	var t: float = clampf(amount, 0.0, 1.0)
	_charging = t > 0.0
	_glow_material.emission_energy_multiplier = lerpf(GLOW_IDLE, GLOW_FULL, t)
	for glow: MeshInstance3D in _glows:
		glow.scale = Vector3.ONE * lerpf(1.0, GLOW_GROW, t)
	_show_glows()


## The core's colour now (it shows the phase).
func core_color() -> Color:
	return _core_material.albedo_color


## Wreck the launch bays (the Leviathan): their turret glows and the model's
## bays hide.
func set_bays_destroyed(destroyed: bool) -> void:
	_bays_destroyed = destroyed
	for bay: Node3D in _bays:
		bay.visible = not destroyed
	_show_glows()


## True once the bays are wrecked (never for a boss without turrets).
func bays_destroyed() -> bool:
	return _bays_destroyed and not _glows.is_empty()


## Whether the turret telegraph glows show.
func is_glowing() -> bool:
	return not _glows.is_empty() and _glows[0].visible


func glow_energy() -> float:
	return _glow_material.emission_energy_multiplier


func set_flash(on: bool) -> void:
	_flashing = on
	_model.set_flash(on)


func is_flashing() -> bool:
	return _flashing


func _show_glows() -> void:
	for glow: MeshInstance3D in _glows:
		glow.visible = _charging and not _bays_destroyed
