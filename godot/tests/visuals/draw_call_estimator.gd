class_name DrawCallEstimator
extends RefCounted
## Counts the draw calls a scene costs in the Compatibility renderer, headless.
## The headless test run has no GPU (RenderingServer reports 0), so this models
## the renderer instead, and errs high:
## - each visible mesh surface is one draw, plus one per material next_pass;
## - a MultiMesh or CPUParticles3D costs one draw per mesh surface, whatever
##   its instance count (the GPU instances it);
## - a sky background costs one draw, and glow costs two per enabled level
##   plus a composite pass.
## It fails closed. A geometry type it does not know, a shadow-casting light, or
## an omni or spot light (each would add a pass per lit object in this renderer)
## is listed in problems(), and the budget test fails on any problem.
## Cross-checked against the real renderer: see the PR for #27.

const SKY_DRAWS: int = 1
const GLOW_DRAWS_PER_LEVEL: int = 2
const GLOW_COMPOSITE_DRAWS: int = 1
const GLOW_LEVELS: int = 7

var _total: int = 0
var _problems: PackedStringArray = PackedStringArray()


## Estimate the draw calls of everything visible under root.
func measure(root: Node) -> int:
	_total = 0
	_problems.clear()
	_walk(root)
	return _total


## Why the last measure() cannot be trusted (empty when it can).
func problems() -> PackedStringArray:
	return _problems


func _walk(node: Node) -> void:
	var visual: Node3D = node as Node3D
	if visual != null and not visual.is_visible_in_tree():
		return
	_count(node)
	for child: Node in node.get_children():
		_walk(child)


func _count(node: Node) -> void:
	if node is WorldEnvironment:
		_total += _environment_draws((node as WorldEnvironment).environment)
	elif node is Light3D:
		_check_light(node as Light3D)
	elif node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_problem(node, "casts shadows")
		_total += _geometry_draws(geometry)


func _geometry_draws(geometry: GeometryInstance3D) -> int:
	var draws: int = 0
	if geometry is MeshInstance3D:
		draws = _mesh_draws((geometry as MeshInstance3D).mesh, geometry.material_override)
	elif geometry is MultiMeshInstance3D:
		var multi: MultiMesh = (geometry as MultiMeshInstance3D).multimesh
		if multi != null and multi.instance_count > 0 and multi.visible_instance_count != 0:
			draws = _mesh_draws(multi.mesh, geometry.material_override)
	elif geometry is CPUParticles3D:
		draws = _mesh_draws((geometry as CPUParticles3D).mesh, geometry.material_override)
	elif geometry is GPUParticles3D:
		draws = (geometry as GPUParticles3D).draw_passes
	elif geometry is SpriteBase3D or geometry is Label3D:
		draws = 1
	else:
		_problem(geometry, "is a %s, which the estimator does not model" % geometry.get_class())
	return draws


func _mesh_draws(mesh: Mesh, override: Material) -> int:
	if mesh == null:
		return 0
	var draws: int = 0
	for surface: int in mesh.get_surface_count():
		var material: Material = override
		if material == null:
			material = mesh.surface_get_material(surface)
		draws += 1 + _next_passes(material)
	return draws


func _next_passes(material: Material) -> int:
	var passes: int = 0
	var current: Material = material
	while current != null and current.next_pass != null:
		passes += 1
		current = current.next_pass
	return passes


func _environment_draws(environment: Environment) -> int:
	if environment == null:
		return 0
	var draws: int = 0
	if environment.background_mode == Environment.BG_SKY:
		draws += SKY_DRAWS
	if environment.glow_enabled:
		var levels: int = 0
		for level: int in GLOW_LEVELS:
			if environment.get_glow_level(level) > 0.0:
				levels += 1
		draws += levels * GLOW_DRAWS_PER_LEVEL + GLOW_COMPOSITE_DRAWS
	return draws


func _check_light(light: Light3D) -> void:
	if light.shadow_enabled:
		_problem(light, "has shadows enabled")
	if light is OmniLight3D or light is SpotLight3D:
		_problem(light, "is a positional light (one extra pass per lit object)")


func _problem(node: Node, why: String) -> void:
	var _added: bool = _problems.push_back("%s %s" % [node.name, why])
