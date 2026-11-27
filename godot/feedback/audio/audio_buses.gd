class_name AudioBuses
extends Node
## The audio buses (#73): Master, with Music, SFX and UI sending to it, as laid
## out in res://default_bus_layout.tres. Settings drive their volumes: master,
## music and SFX volume map onto their buses, and the UI bus follows the SFX
## volume (the Settings screen has no separate UI slider). A volume of 0 mutes
## its bus.

const MASTER: StringName = &"Master"
const MUSIC: StringName = &"Music"
const SFX: StringName = &"SFX"
const UI: StringName = &"UI"


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	BusLinks.require_ok("AudioBuses", [bus.profile.settings_changed.connect(apply)])


## Set every bus's volume from `settings`.
func apply(settings: GameSettings) -> void:
	_set_volume(MASTER, settings.master_volume)
	_set_volume(MUSIC, settings.music_volume)
	_set_volume(SFX, settings.sfx_volume)
	_set_volume(UI, settings.sfx_volume)


## The linear volume (0..1) of the bus `bus_name`, 0 while it is muted.
static func volume_of(bus_name: StringName) -> float:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0 or AudioServer.is_bus_mute(index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


static func _set_volume(bus_name: StringName, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("AudioBuses: no %s bus (is default_bus_layout.tres loaded?)" % bus_name)
		return
	var linear: float = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_mute(index, linear <= 0.0)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(index, linear_to_db(linear))
