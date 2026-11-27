class_name ShotPool
extends Node3D
## Owns every player shot and recycles them, so firing never allocates nodes in
## play. It steps its live shots on the physics tick; expired shots are parked
## (hidden, on no collision layer) until the next fire() reuses them.

## A shot's life ran out without hitting anything, at `position`.
signal missed(position: Vector3)

var _shots: Array[PlayerShot] = []


func _physics_process(delta: float) -> void:
	step(delta)


## Launch a shot, reusing a parked one when there is one.
func fire(origin: Vector3, velocity: Vector3, life: float, fall_rate: float) -> PlayerShot:
	var shot: PlayerShot = _parked_shot()
	if shot == null:
		shot = PlayerShot.new()
		_watch(shot.expired.connect(_on_shot_expired) as Error)
		_watch(shot.missed.connect(missed.emit) as Error)
		add_child(shot)
		_shots.append(shot)
	shot.launch(origin, velocity, life, fall_rate)
	return shot


func step(delta: float) -> void:
	for shot: PlayerShot in _shots:
		shot.step(delta)


func live_count() -> int:
	var live: int = 0
	for shot: PlayerShot in _shots:
		if shot.is_live():
			live += 1
	return live


func live_shots() -> Array[PlayerShot]:
	var live: Array[PlayerShot] = []
	for shot: PlayerShot in _shots:
		if shot.is_live():
			live.append(shot)
	return live


func pooled_count() -> int:
	return _shots.size()


## Park every shot (a new life or a reset).
func clear() -> void:
	for shot: PlayerShot in _shots:
		shot.park()


func _parked_shot() -> PlayerShot:
	for shot: PlayerShot in _shots:
		if not shot.is_live():
			return shot
	return null


func _on_shot_expired(shot: PlayerShot) -> void:
	shot.park()


func _watch(err: Error) -> void:
	if err != OK:
		push_error("ShotPool: could not watch a shot: %s" % error_string(err))
