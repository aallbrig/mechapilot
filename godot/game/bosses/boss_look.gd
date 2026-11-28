class_name BossLook
extends Node3D
## A boss's model, driven by Boss and owning no game logic. It shows the boss's
## merged model from the visual pass (VisualLibrary.boss, #27), scaled so its
## silhouette covers the hull the rules were tuned on (BossProfile.size), with
## that model's phase parts. The drawn hull's box is the rules' body
## (hull_rect()), and the model's markers are the rules' points: its
## turret muzzles are where volleys leave, and its launch bays (the
## Leviathan's) are where drones leave and, while shielded, where shots count
## (turret_points(), bay_points(), in the boss's own frame).
##
## Every one of those points always shows a glow, dim at rest and bright through
## each attack's telegraph, so the player can see where the boss fires from
## and what to shoot. The glows are one MultiMesh (one draw). A glowing core
## shifts colour with each phase. set_flash() shows the shared white hit flash.

const PHASE_CORE_COLORS: Array[Color] = [
	Color(0.3, 0.8, 1.0), Color(1.0, 0.6, 0.1), Color(1.0, 0.15, 0.2)
]
const GLOW_COLOR: Color = Color(1.0, 0.75, 0.2)
## Glow energy at rest (a dim marker) and at full charge; size at full charge.
const GLOW_IDLE: float = 0.6
const GLOW_FULL: float = 9.0
const GLOW_GROW: float = 2.0
const POINT_SIZE: float = 0.5
const CORE_SHARE: float = 0.3
const CORE_GLOW: float = 3.0
## The model's launch bays (the Leviathan's), hidden once they are wrecked.
const BAY_PREFIX: String = "LaunchBay"
const BAY_SPAWN_SUFFIX: String = "Spawn"
## The gun of a boss with no turrets (the Crimson Lancer's arm cannon).
const GUN_MUZZLE: StringName = &"Muzzle"

static var _glow_mesh: SphereMesh
static var _glow_material: StandardMaterial3D

var _model: BossVisual
var _core: MeshInstance3D = MeshInstance3D.new()
var _core_material: StandardMaterial3D = StandardMaterial3D.new()
var _glows: MultiMeshInstance3D = MultiMeshInstance3D.new()
var _hull: Rect2 = Rect2()
var _turret_points: Array[Vector3] = []
var _bay_points: Array[Vector3] = []
var _bays: Array[Node3D] = []
var _energy: float = GLOW_IDLE
var _grow: float = 1.0
var _flashing: bool = false
var _charging: bool = false
var _bays_destroyed: bool = false


func _init(profile: BossProfile) -> void:
	_model = VisualLibrary.boss(profile.id)
	_model.scale = Vector3.ONE * fit_scale(_model.bounds().size, profile.size)
	add_child(_model)
	var drawn: AABB = _model.transform * _model.bounds()
	_hull = Rect2(Vector2(drawn.position.x, drawn.position.y), Vector2(drawn.size.x, drawn.size.y))
	_collect_points()
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
	_glows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glows.multimesh = MultiMesh.new()
	_glows.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_glows.multimesh.use_colors = true
	_glows.multimesh.mesh = _sphere()
	_glows.multimesh.instance_count = _turret_points.size() + _bay_points.size()
	_glows.material_override = _glow_shader()
	add_child(_glows)
	set_phase(0)
	set_charge(0.0)


## The scale that makes a model of `model_size` cover the hull `hull`: the
## larger of the width and height ratios, so neither falls short of the rules.
static func fit_scale(model_size: Vector3, hull: Vector3) -> float:
	if model_size.x <= 0.0 or model_size.y <= 0.0:
		return 1.0
	return maxf(hull.x / model_size.x, hull.y / model_size.y)


## The drawn hull's box relative to the boss, in the play plane: the rules'
## body (shots land and contact hurts inside it).
func hull_rect() -> Rect2:
	return _hull


## The merged model shown (a VisualLibrary boss scene).
func model() -> BossVisual:
	return _model


## Where volleys leave, relative to the boss (play plane): the model's turret
## muzzles, or its gun for a boss without turrets.
func turret_points() -> Array[Vector3]:
	return _turret_points.duplicate()


## The model's launch bays relative to the boss (play plane), or none.
func bay_points() -> Array[Vector3]:
	return _bay_points.duplicate()


## Show the phase (0-based): its core colour and the model's parts of it.
func set_phase(phase: int) -> void:
	var tint: Color = PHASE_CORE_COLORS[clampi(phase, 0, PHASE_CORE_COLORS.size() - 1)]
	_core_material.albedo_color = tint
	_core_material.emission = tint
	_model.set_phase(phase + 1)


## The telegraph on every point: 0 at rest (dim), 1 about to fire.
func set_charge(amount: float) -> void:
	var t: float = clampf(amount, 0.0, 1.0)
	_charging = t > 0.0
	_energy = lerpf(GLOW_IDLE, GLOW_FULL, t)
	_grow = lerpf(1.0, GLOW_GROW, t)
	_show_glows()


## The core's colour now (it shows the phase).
func core_color() -> Color:
	return _core_material.albedo_color


## Wreck the launch bays (the Leviathan): the model's bays and their glows hide.
func set_bays_destroyed(destroyed: bool) -> void:
	_bays_destroyed = destroyed
	for bay: Node3D in _bays:
		bay.visible = not destroyed
	_show_glows()


## True once the bays are wrecked (never for a boss without bays).
func bays_destroyed() -> bool:
	return _bays_destroyed and not _bay_points.is_empty()


## Whether the telegraph is charging (the glows brighten).
func is_glowing() -> bool:
	return _charging


## How many point glows show now (each turret, and each bay until wrecked).
func shown_glows() -> int:
	return _glows.multimesh.visible_instance_count


func glow_energy() -> float:
	return _energy


func set_flash(on: bool) -> void:
	_flashing = on
	_model.set_flash(on)


func is_flashing() -> bool:
	return _flashing


func _collect_points() -> void:
	for i: int in range(1, _model.turret_count + 1):
		_turret_points.append(_point(_model.turret_muzzle(i)))
	for marker_name: StringName in _model.extra_markers:
		var marker_text: String = String(marker_name)
		if marker_text.begins_with(BAY_PREFIX) and not marker_text.ends_with(BAY_SPAWN_SUFFIX):
			var bay: Node3D = _model.marker(marker_name)
			_bays.append(bay)
			_bay_points.append(_point(bay))
	if _turret_points.is_empty() and _model.marker(GUN_MUZZLE) != null:
		_turret_points.append(_point(_model.marker(GUN_MUZZLE)))


## A marker's place relative to the boss, flattened onto the play plane.
func _point(marker: Node3D) -> Vector3:
	var at: Vector3 = _model.transform * _model.to_rig(marker).origin
	return Vector3(at.x, at.y, 0.0)


func _show_glows() -> void:
	var points: Array[Vector3] = _turret_points.duplicate()
	if not _bays_destroyed:
		points.append_array(_bay_points)
	var shine: Color = GLOW_COLOR * _energy
	shine.a = 1.0
	for i: int in points.size():
		var at: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * _grow), points[i])
		_glows.multimesh.set_instance_transform(i, at)
		_glows.multimesh.set_instance_color(i, shine)
	_glows.multimesh.visible_instance_count = points.size()


static func _sphere() -> SphereMesh:
	if _glow_mesh == null:
		_glow_mesh = SphereMesh.new()
		_glow_mesh.radius = POINT_SIZE
		_glow_mesh.height = POINT_SIZE * 2.0
	return _glow_mesh


static func _glow_shader() -> StandardMaterial3D:
	if _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.vertex_color_use_as_albedo = true
	return _glow_material
