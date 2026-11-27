class_name PlayerShot
extends Area3D
## One gravity shot from the player's arm cannon: a glowing bolt that arcs under
## gravity and points along its velocity. ShotPool owns and recycles it, and
## calls step() from its own physics tick so motion is deterministic in tests.
## Enemies (#23) detect it on the PLAYER_SHOTS layer.

## The shot's life ran out; the pool parks it for reuse.
signal expired(shot: PlayerShot)

const RADIUS: float = 0.3
const BOLT_SIZE: Vector3 = Vector3(0.4, 0.4, 1.6)
const BOLT_COLOR: Color = Color(1.0, 0.96, 0.3)
const BOLT_GLOW: float = 5.0
## Hit points a shot takes from an enemy.
const DAMAGE: int = 1

static var _bolt_mesh: BoxMesh
static var _bolt_material: StandardMaterial3D

var velocity: Vector3 = Vector3.ZERO
var fall_rate: float = 0.0
var life_left: float = 0.0


func _init() -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)
	var bolt: MeshInstance3D = MeshInstance3D.new()
	bolt.mesh = _shared_mesh()
	bolt.material_override = _shared_material()
	add_child(bolt)
	monitoring = false
	park()


## Start flying from `origin` at `launch_velocity` for `life` seconds.
func launch(origin: Vector3, launch_velocity: Vector3, life: float, fall_gravity: float) -> void:
	position = origin
	velocity = launch_velocity
	life_left = life
	fall_rate = fall_gravity
	collision_layer = PhysicsLayers.PLAYER_SHOTS
	collision_mask = PhysicsLayers.ENEMIES
	visible = true
	_orient()


## Take the shot out of play: hidden and on no collision layer.
func park() -> void:
	life_left = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	visible = false


func is_live() -> bool:
	return life_left > 0.0


## Spend the shot (it hit something); the pool recycles it.
func spend() -> void:
	if is_live():
		life_left = 0.0
		expired.emit(self)


func step(delta: float) -> void:
	if not is_live():
		return
	velocity = Ballistics.fall(velocity, fall_rate, delta)
	position += velocity * delta
	_orient()
	life_left -= delta
	if life_left <= 1e-6:
		life_left = 0.0
		expired.emit(self)


func _orient() -> void:
	if velocity.length_squared() > 1e-6:
		basis = Basis.looking_at(velocity.normalized(), Vector3.BACK)


static func _shared_mesh() -> BoxMesh:
	if _bolt_mesh == null:
		_bolt_mesh = BoxMesh.new()
		_bolt_mesh.size = BOLT_SIZE
	return _bolt_mesh


static func _shared_material() -> StandardMaterial3D:
	if _bolt_material == null:
		_bolt_material = StandardMaterial3D.new()
		_bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bolt_material.albedo_color = BOLT_COLOR
		_bolt_material.emission_enabled = true
		_bolt_material.emission = BOLT_COLOR
		_bolt_material.emission_energy_multiplier = BOLT_GLOW
	return _bolt_material
