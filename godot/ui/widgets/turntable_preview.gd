class_name TurntablePreview
extends SubViewportContainer
## The Intel codex's 3D turntable (#73): the entry's shape, slowly turning,
## in its own small world. A locked entry shows as a dark silhouette.
## The shapes are primitive stand-ins in the enemy and boss colours; the
## visuals pass (#27) can hand in its models through show_mesh().

const SIZE: Vector2i = Vector2i(280, 140)
const TURN_SPEED: float = 0.8
const CAMERA_POSITION: Vector3 = Vector3(0.0, 0.6, 4.0)
const ENEMY_COLOR: Color = Color(1.0, 0.35, 0.4)
const BOSS_COLOR: Color = Color(1.0, 0.6, 0.2)
const LOCKED_COLOR: Color = Color(0.05, 0.06, 0.1)

var _viewport: SubViewport
var _pivot: Node3D
var _model: MeshInstance3D
var _locked: bool = true


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	add_child(_viewport)
	var camera: Camera3D = Camera3D.new()
	camera.position = CAMERA_POSITION
	camera.rotation.x = -atan2(CAMERA_POSITION.y, CAMERA_POSITION.z)
	camera.current = true
	_viewport.add_child(camera)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.5, 0.0)
	_viewport.add_child(light)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_model = MeshInstance3D.new()
	_pivot.add_child(_model)


## Shows a stand-in shape for `entry`, lit when unlocked, dark when locked.
func show_entry(entry: IntelEntry, unlocked: bool) -> void:
	show_mesh(_shape_for(entry), BOSS_COLOR if entry.boss else ENEMY_COLOR, unlocked)


## Shows `mesh` in `color`, or as a silhouette when not `unlocked`.
func show_mesh(mesh: Mesh, color: Color, unlocked: bool) -> void:
	_locked = not unlocked
	_model.mesh = mesh
	var surface: StandardMaterial3D = StandardMaterial3D.new()
	surface.albedo_color = color if unlocked else LOCKED_COLOR
	if not unlocked:
		surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_model.material_override = surface


## True when the shown entry is locked.
func is_locked() -> bool:
	return _locked


## The model's current turn, in radians.
func turn() -> float:
	return _pivot.rotation.y


func _process(delta: float) -> void:
	if not TweenFx.reduced_motion:
		_pivot.rotation.y = wrapf(_pivot.rotation.y + TURN_SPEED * delta, 0.0, TAU)


static func _shape_for(entry: IntelEntry) -> Mesh:
	if entry.boss:
		var hull: CapsuleMesh = CapsuleMesh.new()
		hull.radius = 0.6
		hull.height = 2.6
		return hull
	match entry.id:
		&"heavy", &"bomber":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(1.8, 0.8, 1.2)
			return box
		&"drone":
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			return sphere
		&"enemy_mech":
			var body: CapsuleMesh = CapsuleMesh.new()
			body.radius = 0.45
			body.height = 1.8
			return body
		_:
			var dart: PrismMesh = PrismMesh.new()
			dart.size = Vector3(1.2, 1.6, 0.5)
			return dart
