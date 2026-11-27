class_name MechDebris
extends Node3D
## The death ragdoll: when the mech is destroyed, every part breaks off as a
## tumbling copy that flies outward with part of the mech's momentum, falls,
## spins and fades. It lives in world space (a sibling of the mech, given to it).

const GRAVITY: float = 24.0 * Pace.GAME_SPEED * Pace.GAME_SPEED
const LIFE: float = 2.2
const LIFE_SPREAD: Vector2 = Vector2(0.8, 1.2)
const DRAG: float = 0.4
## Share of the mech's velocity each piece keeps.
const INHERIT: float = 0.5
## Outward burst speed, extra upward pop, and depth scatter (units/s).
const BURST_SPEED: Vector2 = Vector2(5.0, 12.0)
const POP_SPEED: Vector2 = Vector2(3.0, 9.0)
const DEPTH_SCATTER: float = 2.0
## Tumble rate range (rad/s).
const SPIN: Vector2 = Vector2(5.0, 16.0)
## Pieces closer than this to the centre burst straight up.
const CENTRE_RADIUS: float = 0.05

var _pieces: Array[Piece] = []


class Piece:
	var node: MeshInstance3D
	var material: StandardMaterial3D
	var velocity: Vector3 = Vector3.ZERO
	var axis: Vector3 = Vector3.UP
	var spin: float = 0.0
	var life: float = 0.0


func _process(delta: float) -> void:
	step(delta)


## Break `parts` (centred on `centre`, moving at `velocity`) into tumbling pieces.
func burst(
	parts: Array[MeshInstance3D], centre: Vector3, velocity: Vector3, rng: RandomNumberGenerator
) -> void:
	for part: MeshInstance3D in parts:
		if part.mesh == null:
			continue
		var piece: Piece = Piece.new()
		piece.node = MeshInstance3D.new()
		piece.node.mesh = part.mesh
		piece.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.material = _fading_copy(part.material_override)
		piece.node.material_override = piece.material
		add_child(piece.node)
		piece.node.global_transform = part.global_transform
		var out: Vector3 = piece.node.global_position - centre
		out.z = 0.0
		var dir: Vector3 = out.normalized() if out.length() > CENTRE_RADIUS else Vector3.UP
		piece.velocity = (
			velocity * INHERIT
			+ dir * rng.randf_range(BURST_SPEED.x, BURST_SPEED.y)
			+ Vector3.UP * rng.randf_range(POP_SPEED.x, POP_SPEED.y)
		)
		piece.velocity.z = rng.randf_range(-DEPTH_SCATTER, DEPTH_SCATTER)
		piece.axis = (
			Vector3(
				rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)
			)
			. normalized()
		)
		if piece.axis == Vector3.ZERO:
			piece.axis = Vector3.UP
		piece.spin = rng.randf_range(SPIN.x, SPIN.y)
		piece.life = LIFE * rng.randf_range(LIFE_SPREAD.x, LIFE_SPREAD.y)
		_pieces.append(piece)


## A fading material for a piece drawn with `source`: a copy of a standard
## material, or, for a baked model piece (the shared hull shader), one that
## takes its colours from the mesh's vertex colours as the hull does.
static func _fading_copy(source: Material) -> StandardMaterial3D:
	var standard: StandardMaterial3D = source as StandardMaterial3D
	var out: StandardMaterial3D = null
	if standard != null:
		out = standard.duplicate() as StandardMaterial3D
	else:
		out = StandardMaterial3D.new()
		out.vertex_color_use_as_albedo = true
	out.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return out


func step(delta: float) -> void:
	var kept: Array[Piece] = []
	for piece: Piece in _pieces:
		piece.life -= delta
		if piece.life <= 0.0:
			piece.node.queue_free()
			continue
		piece.velocity.y -= GRAVITY * delta
		piece.velocity *= 1.0 - DRAG * delta
		piece.node.global_position += piece.velocity * delta
		piece.node.global_basis = Basis(piece.axis, piece.spin * delta) * piece.node.global_basis
		piece.material.albedo_color.a = clampf(piece.life, 0.0, 1.0)
		kept.append(piece)
	_pieces = kept


func piece_count() -> int:
	return _pieces.size()


## The pieces' mean height, for tests: the ragdoll falls.
func mean_height() -> float:
	if _pieces.is_empty():
		return 0.0
	var total: float = 0.0
	for piece: Piece in _pieces:
		total += piece.node.global_position.y
	return total / _pieces.size()


func clear() -> void:
	for piece: Piece in _pieces:
		piece.node.queue_free()
	_pieces.clear()
