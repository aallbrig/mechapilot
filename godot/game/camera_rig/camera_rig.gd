class_name CameraRig
extends Node3D
## The side-on camera for the 2.5D view: it looks down -Z at the XY play plane
## from DISTANCE away and follows the mech lazily (LazyFollow). Portrait screens
## pull back so at least MIN_HALF_WIDTH units stay visible either side. A safe
## frame, SAFE_FRAME_SHARE of the visible half extents worked out from the live
## FOV, distance and aspect, is a hard limit the mech never crosses.
## It also carries the camera's share of the juice: trauma shake, kicks and FOV
## punches, which feedback and the stage trigger through its methods.

const FOV: float = 60.0
const DISTANCE: float = 34.0
## Half the visible width, in world units, that portrait screens keep at least.
const MIN_HALF_WIDTH: float = 14.0
## Share of the visible half extents where the mech moves without the camera.
const DEAD_ZONE_SHARE: float = 0.2
## Share of the visible half extents the mech may never leave (the safe frame).
const SAFE_FRAME_SHARE: float = 0.7
const NEAR: float = 0.3
const FAR: float = 200.0
## Shake: trauma decays per second; the offset and roll scale with trauma squared.
const TRAUMA_DECAY: float = 1.5
const SHAKE_OFFSET: float = 2.2
const SHAKE_ROLL: float = 0.08
const SHAKE_SPEED: float = 40.0
const SHAKE_NOISE_FREQUENCY: float = 0.5
## How fast kicks and FOV punches return to rest (1/s).
const KICK_RETURN: float = 18.0
const PUNCH_RETURN: float = 8.0
## Never run the follow on a frame longer than this (s), e.g. after a stall.
const MAX_STEP: float = 0.1
const MIN_TIME_SCALE: float = 0.01

## The mech to follow; the stage sets it.
var target: PlayerMech

var _follow: LazyFollow = LazyFollow.new()
var _camera: Camera3D = Camera3D.new()
var _noise: FastNoiseLite = FastNoiseLite.new()
var _aspect: float = 16.0 / 9.0
var _distance: float = DISTANCE
var _trauma: float = 0.0
var _kick: Vector3 = Vector3.ZERO
var _punch: float = 0.0
var _clock: float = 0.0


func _init() -> void:
	_camera.fov = FOV
	_camera.near = NEAR
	_camera.far = FAR
	_camera.position = Vector3(0.0, 0.0, DISTANCE)
	_noise.frequency = SHAKE_NOISE_FREQUENCY
	add_child(_camera)


func _process(delta: float) -> void:
	var size: Vector2i = DisplayServer.window_get_size()
	if size.y > 0:
		set_view_aspect(float(size.x) / float(size.y))
	if target != null:
		# Real time, so hit-stop and slow-mo never freeze or slur the camera.
		var real_delta: float = delta / maxf(Engine.time_scale, MIN_TIME_SCALE)
		advance(minf(real_delta, MAX_STEP), target.position, target.velocity)


## The camera distance that fits `aspect` (width / height).
static func distance_for_aspect(aspect: float) -> float:
	var tan_half: float = tan(deg_to_rad(FOV * 0.5))
	return maxf(DISTANCE, MIN_HALF_WIDTH / (tan_half * maxf(aspect, 0.01)))


## The dead zone's half extents (world units) at `distance` and `aspect`.
static func dead_zone_for(distance: float, aspect: float) -> Vector2:
	return visible_half_extents(distance, aspect, FOV) * DEAD_ZONE_SHARE


## The safe frame's half extents (world units) on the play plane, for a camera
## `distance` away with a vertical FOV of `fov` degrees at `aspect`.
static func safe_frame_for(distance: float, aspect: float, fov: float) -> Vector2:
	return visible_half_extents(distance, aspect, fov) * SAFE_FRAME_SHARE


## Half the visible width and height (world units) on the play plane. Camera3D
## keeps its height, so `fov` is vertical.
static func visible_half_extents(distance: float, aspect: float, fov: float) -> Vector2:
	var half_h: float = tan(deg_to_rad(fov * 0.5)) * distance
	return Vector2(half_h * aspect, half_h)


func camera() -> Camera3D:
	return _camera


func set_view_aspect(aspect: float) -> void:
	_aspect = aspect
	_distance = distance_for_aspect(aspect)


## Frame `point` at once, with no follow motion (spawn and respawn). Leftover
## shake, kicks and FOV punches are dropped too, so the new life starts centred
## and still.
func snap_to(point: Vector3) -> void:
	_follow.snap(point)
	_trauma = 0.0
	_kick = Vector3.ZERO
	_punch = 0.0
	_place()


func advance(delta: float, target_position: Vector3, target_velocity: Vector3) -> void:
	_clock += delta
	_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * delta)
	_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-KICK_RETURN * delta))
	_punch = lerpf(_punch, 0.0, 1.0 - exp(-PUNCH_RETURN * delta))
	# The safe frame uses this frame's FOV, so an FOV punch narrows it too.
	var _focus: Vector3 = _follow.step(
		target_position,
		target_velocity,
		dead_zone_for(_distance, _aspect),
		delta,
		safe_frame_for(_distance, _aspect, FOV - _punch)
	)
	_place()


## Add screen shake (0..1); it decays on its own.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Shove the camera by `offset` (world units); it springs back.
func kick(offset: Vector3) -> void:
	_kick += offset


## Narrow the FOV by `degrees` for a moment.
func punch_fov(degrees: float) -> void:
	_punch = maxf(_punch, degrees)


## Where the screen point `screen` falls on the play plane (z = 0).
func screen_to_play_plane(screen: Vector2) -> Vector3:
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var normal: Vector3 = _camera.project_ray_normal(screen)
	if absf(normal.z) < 1e-3:
		return Vector3(origin.x, origin.y, 0.0)
	return origin + normal * (-origin.z / normal.z)


func _place() -> void:
	var shake: float = _trauma * _trauma
	var t: float = _clock * SHAKE_SPEED
	var jitter: Vector3 = (
		Vector3(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(0.0, t), 0.0)
		* shake
		* SHAKE_OFFSET
	)
	_camera.position = _follow.focus() + Vector3(0.0, 0.0, _distance) + jitter + _kick
	_camera.rotation = Vector3(0.0, 0.0, _noise.get_noise_2d(t, t) * shake * SHAKE_ROLL)
	_camera.fov = FOV - _punch
