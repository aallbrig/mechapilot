class_name MechFeedback
extends Node3D
## The player mech's motion juice: a layered flame on every thruster nozzle, a
## faint trail behind each red eye, and the vapor cone with wingtip ribbons on
## hard turns. It only reacts: main.gd hands it the mech's mounts (plain Node3Ds)
## and connects the mech's motion_sampled signal to on_motion().
## It lives in world space, so the vapor stays where the turn happened.

## Speed above which the eye trails streak (units/s).
const EYE_TRAIL_SPEED: float = 3.0

var _flames: Array[ThrusterFlame] = []
var _eye_trails: Array[CPUParticles3D] = []
var _vapor: VaporCone = VaporCone.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	add_child(_vapor)


## Mount a flame on each nozzle (exhaust along its +Y) and a trail on each eye.
func attach(
	main_nozzles: Array[Node3D],
	main_size: float,
	foot_nozzles: Array[Node3D],
	foot_size: float,
	eyes: Array[Node3D]
) -> void:
	for nozzle: Node3D in main_nozzles:
		_add_flame(nozzle, main_size, true)
	for nozzle: Node3D in foot_nozzles:
		_add_flame(nozzle, foot_size, false)
	for eye: Node3D in eyes:
		var trail: CPUParticles3D = FlameParticles.eye_trail()
		eye.add_child(trail)
		_eye_trails.append(trail)


func on_motion(sample: MechMotionSample) -> void:
	for flame: ThrusterFlame in _flames:
		flame.drive(sample.thrust, sample.delta)
	var streaking: bool = sample.velocity.length() > EYE_TRAIL_SPEED
	for trail: CPUParticles3D in _eye_trails:
		trail.emitting = streaking
	_vapor.on_motion(sample)


## The mech broke apart: no flames, trails or vapor until it respawns.
func on_destroyed() -> void:
	for flame: ThrusterFlame in _flames:
		flame.extinguish()
	for trail: CPUParticles3D in _eye_trails:
		trail.emitting = false
	_vapor.clear()


func on_respawned() -> void:
	for flame: ThrusterFlame in _flames:
		flame.reignite()


func flames() -> Array[ThrusterFlame]:
	return _flames


func eye_trails() -> Array[CPUParticles3D]:
	return _eye_trails


func vapor() -> VaporCone:
	return _vapor


func _add_flame(nozzle: Node3D, flame_size: float, main_engine: bool) -> void:
	var flame: ThrusterFlame = ThrusterFlame.new()
	nozzle.add_child(flame)
	flame.setup(flame_size, main_engine, _rng)
	_flames.append(flame)
