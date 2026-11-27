class_name RepairKit
extends Area3D
## A repair kit (+30 armor, #73). Enemies drop it (#23); it drifts down under
## gentle gravity, spins and pulses, blinks in its last seconds and despawns
## after LIFETIME. The player collects it by flying through it.

## Collected: the mech gets the armor (through PlayerMech.repair()).
signal collected(amount: int)

## The Armor a kit restores (the RunLedger applies it on repair_collected).
const AMOUNT: int = RunRules.REPAIR_ARMOR
const LIFETIME: float = 10.0
## Gentle fall: pickups drift instead of dropping like shots (units/s^2, units/s).
const GRAVITY: float = 3.0 * Pace.GAME_SPEED * Pace.GAME_SPEED
const TERMINAL_FALL: float = 2.5 * Pace.GAME_SPEED
const RADIUS: float = 0.6
## The last seconds blink, faster as the kit nears despawn.
const BLINK_FROM: float = 2.5
const BLINK_RATE: float = 8.0
const BLINK_HIDDEN_SHARE: float = 0.4
const SPIN_RATE: float = 2.2
const PULSE_RATE: float = 5.0
const PULSE_SIZE: float = 0.12
const COLOR: Color = Color(0.25, 1.0, 0.45)
const GLOW: float = 3.0
const CASE_SIZE: Vector3 = Vector3(0.7, 0.7, 0.7)
const CROSS_BAR: Vector3 = Vector3(0.75, 0.22, 0.75)

## The mech that can collect it; the spawner sets it.
var collector: PlayerMech
var velocity: Vector3 = Vector3.ZERO

var _age: float = 0.0
var _spent: bool = false
var _look: Node3D = Node3D.new()


func _init() -> void:
	collision_layer = PhysicsLayers.PICKUPS
	collision_mask = PhysicsLayers.PLAYER
	monitoring = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)
	add_child(_look)
	var case_mat: StandardMaterial3D = StandardMaterial3D.new()
	case_mat.albedo_color = Color.WHITE
	var cross_mat: StandardMaterial3D = StandardMaterial3D.new()
	cross_mat.albedo_color = COLOR
	cross_mat.emission_enabled = true
	cross_mat.emission = COLOR
	cross_mat.emission_energy_multiplier = GLOW
	_add_box(CASE_SIZE, Basis.IDENTITY, case_mat)
	_add_box(CROSS_BAR, Basis.IDENTITY, cross_mat)
	_add_box(CROSS_BAR, Basis(Vector3.BACK, PI / 2.0), cross_mat)


func _physics_process(delta: float) -> void:
	step(delta)
	if _spent:
		queue_free()


func step(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age >= LIFETIME - 1e-6:
		_spent = true
		visible = false
		return
	velocity.y = maxf(velocity.y - GRAVITY * delta, -TERMINAL_FALL)
	position += velocity * delta
	position.z = 0.0
	_look.rotation.y += SPIN_RATE * delta
	_look.scale = Vector3.ONE * (1.0 + sin(_age * PULSE_RATE) * PULSE_SIZE)
	var left: float = LIFETIME - _age
	visible = left > BLINK_FROM or fposmod(left * BLINK_RATE, 1.0) > BLINK_HIDDEN_SHARE
	if collector != null and collector.is_alive():
		var reach: float = RADIUS + collector.contact_radius()
		var gap: Vector3 = collector.position - position
		gap.z = 0.0
		if gap.length() <= reach:
			_spent = true
			visible = false
			collector.repair()
			collected.emit(AMOUNT)


## Collected or expired; it frees itself on the next physics tick.
func is_spent() -> bool:
	return _spent


func _add_box(size: Vector3, turn: Basis, mat: Material) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.basis = turn
	_look.add_child(mi)
