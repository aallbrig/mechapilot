class_name TitleBackdrop
extends Node3D
## The scene behind the Title menu: the Level 1 sky, with the player's mech
## chasing two enemy fighters through it. The camera and the flight cruise
## forward together, so the clouds stream past and wrap around. The attract-mode
## dogfight (#24) can replace the flight; the sky and camera stay.

## Cruise speed of the whole flight (world units per second, along +X).
const CRUISE_SPEED: float = 6.0
## Gentle bob of each flyer: amplitude (units) and angular speed (rad/s).
const BOB_AMPLITUDE: float = 0.35
const BOB_SPEED: float = 1.3
## A streamlined flying pose for the mech, in the prototype's joint angles.
const WING_POSE: float = 0.35
const ARM_POSE: float = -0.75
const THIGH_POSE: float = -0.6
const SHIN_POSE: float = -0.08
const BODY_LEAN: float = -0.5

var _clock: float = 0.0
var _rest: Dictionary[Node3D, Vector3] = {}

@onready var _sky: SkyEnvironment = $Sky
@onready var _camera: Camera3D = $Camera
@onready var _flight: Node3D = $Flight
@onready var _mech: PlayerMechVisual = $Flight/Mech


func _ready() -> void:
	_pose_side(PlayerMechVisual.LEFT)
	_pose_side(PlayerMechVisual.RIGHT)
	_mech.body().rotation.x = BODY_LEAN
	_rest.clear()
	for child: Node in _flight.get_children():
		var flyer: Node3D = child as Node3D
		if flyer != null:
			_rest[flyer] = flyer.position
	_sky.follow(_camera.position)


func _pose_side(side: int) -> void:
	_mech.wing(side).rotation.x = WING_POSE
	_mech.arm(side).rotation.x = ARM_POSE
	_mech.thigh(side).rotation.x = THIGH_POSE
	_mech.shin(side).rotation.x = SHIN_POSE


func _process(delta: float) -> void:
	_clock += delta
	var advance: Vector3 = Vector3(CRUISE_SPEED * delta, 0.0, 0.0)
	_camera.position += advance
	_flight.position += advance
	var phase: float = 0.0
	for flyer: Node3D in _rest:
		var bob: float = sin(_clock * BOB_SPEED + phase) * BOB_AMPLITUDE
		flyer.position = _rest[flyer] + Vector3(0.0, bob, 0.0)
		phase += 1.0
	_sky.follow(_camera.position)
