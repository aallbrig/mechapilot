class_name EnemyLook
extends Node3D
## An enemy's model, driven by Enemy and owning no game logic. Until the model
## kit (#27) lands, it builds a placeholder from shared primitive meshes: a hull
## in the kind's colour, wings, and a muzzle glow that brightens through the
## attack telegraph. It keeps the model kit's contract: the nose points along
## +X, the top along +Y, and set_flash() swaps in a white hit flash.

## Hull colours per kind, and the shared glow colour of muzzles and telegraphs.
const HULL_COLORS: Dictionary[EnemyKind.Kind, Color] = {
	EnemyKind.Kind.FIGHTER: Color(0.85, 0.15, 0.3),
	EnemyKind.Kind.HEAVY: Color(0.55, 0.3, 0.2),
	EnemyKind.Kind.INTERCEPTOR: Color(0.25, 0.45, 0.9),
	EnemyKind.Kind.DRONE: Color(0.9, 0.75, 0.15),
	EnemyKind.Kind.BOMBER: Color(0.35, 0.4, 0.3),
	EnemyKind.Kind.ENEMY_MECH: Color(0.6, 0.1, 0.15),
}
const GLOW_COLOR: Color = Color(1.0, 0.8, 0.2)
const FLASH_COLOR: Color = Color.WHITE
## Muzzle glow energy idle and at full charge; the glow's size at full charge.
const GLOW_IDLE: float = 0.5
const GLOW_FULL: float = 8.0
const GLOW_GROW: float = 2.2
const HULL_SIZE: Vector3 = Vector3(2.4, 0.6, 0.6)
const WING_SIZE: Vector3 = Vector3(0.8, 0.1, 3.0)
const FIN_SIZE: Vector3 = Vector3(0.5, 0.8, 0.1)
const GLOW_SIZE: float = 0.35
const NOSE: Vector3 = Vector3(1.3, 0.0, 0.0)
const TAIL: Vector3 = Vector3(-1.0, 0.4, 0.0)
## How fast the model turns to its heading (1/s).
const TURN_RATE: float = 10.0

static var _boxes: Dictionary[Vector3, BoxMesh] = {}
static var _hulls: Dictionary[EnemyKind.Kind, StandardMaterial3D] = {}
static var _flash: StandardMaterial3D

var _pivot: Node3D = Node3D.new()
var _parts: Array[MeshInstance3D] = []
var _hull_material: StandardMaterial3D
var _glow: MeshInstance3D = MeshInstance3D.new()
var _glow_material: StandardMaterial3D = StandardMaterial3D.new()
var _flashing: bool = false


## A placeholder model of `kind` at `size` times its base scale.
func _init(kind: EnemyKind.Kind, size: float) -> void:
	scale = Vector3.ONE * size
	add_child(_pivot)
	_hull_material = _hull_for(kind)
	_add_part(HULL_SIZE, Vector3.ZERO)
	_add_part(WING_SIZE, Vector3.ZERO)
	_add_part(FIN_SIZE, TAIL)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = GLOW_SIZE
	sphere.height = GLOW_SIZE * 2.0
	_glow.mesh = sphere
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.albedo_color = GLOW_COLOR
	_glow_material.emission_enabled = true
	_glow_material.emission = GLOW_COLOR
	_glow.material_override = _glow_material
	_glow.position = NOSE
	_pivot.add_child(_glow)
	set_charge(0.0)


## Show the white hit flash, or the normal colours.
func set_flash(on: bool) -> void:
	_flashing = on
	for part: MeshInstance3D in _parts:
		part.material_override = _flash_material() if on else _hull_material


func is_flashing() -> bool:
	return _flashing


## The attack telegraph: 0 is idle, 1 is about to fire.
func set_charge(amount: float) -> void:
	var t: float = clampf(amount, 0.0, 1.0)
	_glow_material.emission_energy_multiplier = lerpf(GLOW_IDLE, GLOW_FULL, t)
	_glow.scale = Vector3.ONE * lerpf(1.0, GLOW_GROW, t)


## The telegraph glow's brightness now (for tests and juice).
func glow_energy() -> float:
	return _glow_material.emission_energy_multiplier


## Turn smoothly toward `heading` (a play-plane direction) over `delta` seconds,
## keeping the top up.
func face(heading: Vector3, delta: float) -> void:
	if heading.length() < FiringSolution.MIN_DISTANCE:
		return
	var angle: float = atan2(heading.y, heading.x)
	var want: Basis = Basis(Vector3.BACK, angle)
	if heading.x < 0.0:
		# Roll over so the top stays up when flying left.
		want = want * Basis(Vector3.RIGHT, PI)
	_pivot.basis = _pivot.basis.slerp(want, 1.0 - exp(-TURN_RATE * delta)).orthonormalized()


func _add_part(size: Vector3, at: Vector3) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = _box(size)
	part.material_override = _hull_material
	part.position = at
	_pivot.add_child(part)
	_parts.append(part)


static func _box(size: Vector3) -> BoxMesh:
	if not _boxes.has(size):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		_boxes[size] = mesh
	return _boxes[size]


static func _hull_for(kind: EnemyKind.Kind) -> StandardMaterial3D:
	if not _hulls.has(kind):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = HULL_COLORS[kind]
		_hulls[kind] = mat
	return _hulls[kind]


static func _flash_material() -> StandardMaterial3D:
	if _flash == null:
		_flash = StandardMaterial3D.new()
		_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash.albedo_color = FLASH_COLOR
	return _flash
