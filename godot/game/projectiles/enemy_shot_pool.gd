class_name EnemyShotPool
extends Node3D
## Owns every enemy and boss projectile and recycles them, so firing never
## allocates nodes in play. step() flies the live shots and checks each against
## the player by distance: a shot that reaches a live player strikes it with
## its spec's damage source and is spent, whether or not the hit lands (the
## mech may be invulnerable). It draws every live shot as one MultiMesh: a unit
## box sized and coloured per instance by its style, so any volley is one draw.

## A shot reached the player, or fizzled at the end of its life (for juice).
signal shot_burst(position: Vector3, style: ShotSpec.Style, struck: bool)

## Instances added at a time when a style's MultiMesh runs out.
const GROW_CHUNK: int = 32

var _shots: Array[EnemyShot] = []
var _drawn: MultiMeshInstance3D = MultiMeshInstance3D.new()
var _dirty: bool = false


func _init() -> void:
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drawn.multimesh = MultiMesh.new()
	_drawn.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_drawn.multimesh.use_colors = true
	_drawn.multimesh.mesh = EnemyShot.unit_mesh()
	_drawn.multimesh.visible_instance_count = 0
	_drawn.material_override = EnemyShot.shared_material()
	add_child(_drawn)


func _process(_delta: float) -> void:
	if _dirty:
		show_shots()


## Launch a shot of `spec` from `origin` along `direction` at the spec's speed
## times `speed_scale` (the Level's bullet speed), plus `inherit` (the
## shooter's velocity share). Reuses a parked shot when there is one.
func fire(
	spec: ShotSpec, origin: Vector3, direction: Vector3, speed_scale: float, inherit: Vector3
) -> EnemyShot:
	var shot: EnemyShot = _parked_shot()
	if shot == null:
		shot = EnemyShot.new()
		add_child(shot)
		_shots.append(shot)
	var dir: Vector3 = Vector3(direction.x, direction.y, 0.0).normalized()
	shot.launch(spec, origin, dir * spec.speed * speed_scale + inherit)
	_dirty = true
	return shot


## Fly every live shot `delta` seconds and resolve hits on `target`.
func step(delta: float, target: CombatTarget) -> void:
	var alive: bool = target != null and target.is_alive()
	var aim: Vector3 = target.position() if target != null else Vector3.ZERO
	for shot: EnemyShot in _shots:
		if not shot.is_live():
			continue
		shot.step(delta, aim, alive)
		if not shot.is_live():
			shot_burst.emit(shot.position, shot.spec.style, false)
			continue
		if alive and _touches(shot, target):
			var _landed: bool = target.strike(
				shot.spec.source, shot.spec.attack_damage, shot.velocity.normalized()
			)
			shot.park()
			shot_burst.emit(shot.position, shot.spec.style, true)
	show_shots()


## Park every shot outside `radius` of `centre` (the Play Sphere).
func cull_outside(centre: Vector3, radius: float) -> void:
	for shot: EnemyShot in _shots:
		if shot.is_live() and _plane_distance(shot.position, centre) > radius:
			shot.park()
	_dirty = true


func live_shots() -> Array[EnemyShot]:
	var live: Array[EnemyShot] = []
	for shot: EnemyShot in _shots:
		if shot.is_live():
			live.append(shot)
	return live


func pooled_count() -> int:
	return _shots.size()


## Park every shot (Level Clear, a new Run).
func clear() -> void:
	for shot: EnemyShot in _shots:
		shot.park()
	show_shots()


## Draw every live shot where it is now: one MultiMesh instance each, sized and
## coloured by its style. The pool's step() calls it; after firing, the next frame does.
func show_shots() -> void:
	_dirty = false
	var live: Array[EnemyShot] = live_shots()
	var multi: MultiMesh = _drawn.multimesh
	if live.size() > multi.instance_count:
		# Resizing clears the buffer; every shown instance is rewritten below.
		multi.instance_count = ceili(live.size() / float(GROW_CHUNK)) * GROW_CHUNK
	for i: int in live.size():
		var shot: EnemyShot = live[i]
		var sized: Transform3D = shot.transform.scaled_local(EnemyShot.STYLE_SIZES[shot.spec.style])
		multi.set_instance_transform(i, sized)
		multi.set_instance_color(i, EnemyShot.shine(shot.spec.style))
	multi.visible_instance_count = live.size()


## How many shots are drawn now.
func drawn_count() -> int:
	return _drawn.multimesh.visible_instance_count


func _touches(shot: EnemyShot, target: CombatTarget) -> bool:
	return _plane_distance(shot.position, target.position()) <= shot.spec.radius + target.radius()


func _parked_shot() -> EnemyShot:
	for shot: EnemyShot in _shots:
		if not shot.is_live():
			return shot
	return null


static func _plane_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length()
