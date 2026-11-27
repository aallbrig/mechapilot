class_name TitleBackdrop
extends Node3D
## The scene behind the Title menu: the Level 1 sky, with the player's mech
## chasing two enemy fighters through it. The camera and the flight cruise
## forward together, so the clouds stream past and wrap around. The attract-mode
## dogfight (#24) can replace the flight; the sky and camera stay. The flight
## re-origins every REORIGIN_DISTANCE, so coordinates stay small however long
## the title runs.
## It is the Boot and Title view: main.gd shows it there (set_shown) and hides
## the flight stage behind it. Its camera looks through the sky's own
## Environment, so the title shows the dawn sky whichever WorldEnvironment the
## world uses; hidden, it stops, and its camera hands the view back.

## Cruise speed of the whole flight (world units per second, along +X).
const CRUISE_SPEED: float = 6.0
## How far the camera cruises before the scene moves its origin back.
const REORIGIN_DISTANCE: float = 1000.0
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
	_camera.environment = _sky.environment()
	set_shown(true)


## Whether the backdrop is the view in a Game State: Boot and Title.
static func shows_in(phase: GameState.Phase) -> bool:
	return phase == GameState.Phase.BOOT or phase == GameState.Phase.TITLE


## Show the backdrop and look through its camera, or hide it, stop it and let
## another camera (the flight stage's) take the view.
func set_shown(shown: bool) -> void:
	visible = shown
	process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	_camera.current = shown
	if shown:
		_sky.follow(_camera.position)


## Whether the backdrop is showing and its camera is the view.
func is_shown() -> bool:
	return visible and _camera.current


## Where the camera is (the flight moves with it).
func camera_position() -> Vector3:
	return _camera.position


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
	if _camera.position.x >= REORIGIN_DISTANCE:
		var shift: Vector3 = Vector3(_camera.position.x, 0.0, 0.0)
		_camera.position -= shift
		_flight.position -= shift
		_sky.shift_origin(shift)
	_sky.follow(_camera.position)
