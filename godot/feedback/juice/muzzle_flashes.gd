class_name MuzzleFlashes
extends Node3D
## The muzzle flash of every player shot (#26): a hot, additive burst that pops
## just ahead of the muzzle along the aim. Pooled. Reduced motion turns it off,
## since shots come fast enough to strobe.

const POOL_SIZE: int = 6
## How far ahead of the shot's origin the flash sits (units, along the aim).
const AHEAD: float = 0.35
const PEAK_SIZE: float = 0.9
const SECONDS: float = 0.07
const COLOR: Color = Color(1.0, 0.9, 0.55)

var _flashes: Array[MeshInstance3D] = []
var _tweens: Array[Tween] = []
var _next: int = 0
var _enabled: bool = true


func _init() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.disable_fog = true
	material.albedo_color = COLOR
	sphere.material = material
	for _i: int in POOL_SIZE:
		var flash: MeshInstance3D = MeshInstance3D.new()
		flash.mesh = sphere
		flash.visible = false
		add_child(flash)
		_flashes.append(flash)
		_tweens.append(null)


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	(
		BusLinks
		. require_ok(
			"MuzzleFlashes",
			[
				bus.player.player_fired.connect(_on_player_fired),
				bus.profile.settings_changed.connect(_on_settings_changed),
			]
		)
	)


## How many flashes are on show.
func showing() -> int:
	var count: int = 0
	for flash: MeshInstance3D in _flashes:
		if flash.visible:
			count += 1
	return count


func _on_player_fired(origin: Vector3, direction: Vector3) -> void:
	if not _enabled:
		return
	var index: int = _next
	_next = (_next + 1) % POOL_SIZE
	var flash: MeshInstance3D = _flashes[index]
	flash.position = origin + direction.normalized() * AHEAD
	flash.visible = true
	_tweens[index] = JuiceTween.pop(flash, _tweens[index], PEAK_SIZE, SECONDS)


func _on_settings_changed(settings: GameSettings) -> void:
	_enabled = JuiceSettings.flashes(settings)
