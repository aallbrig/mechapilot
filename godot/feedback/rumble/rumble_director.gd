class_name RumbleDirector
extends Node
## Gamepad rumble (#73: on hits and on boss kills, and it can be turned off).
## A hit rumbles more the more Armor it costs; the player's death and a boss
## kill rumble hard. The rumble setting silences it.
##
## It vibrates the connected gamepads only once drive_input() is called
## (main.gd); tests read the `rumbled` signal instead.

## A rumble was decided: motor strengths (0..1) and how long (s).
signal rumbled(weak: float, strong: float, seconds: float)

## A hit: the base strengths, what each Armor point lost adds, and how long.
const HIT_WEAK: float = 0.35
const HIT_STRONG: float = 0.25
const HIT_PER_POINT: float = 0.012
const HIT_SECONDS: float = 0.18
const DEATH_WEAK: float = 0.8
const DEATH_STRONG: float = 1.0
const DEATH_SECONDS: float = 0.6
const BOSS_WEAK: float = 1.0
const BOSS_STRONG: float = 1.0
const BOSS_SECONDS: float = 0.9

var _settings: GameSettings = GameSettings.new()
var _drives_input: bool = false


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	(
		BusLinks
		. require_ok(
			"RumbleDirector",
			[
				bus.player.armor_changed.connect(_on_armor_changed),
				bus.player.player_destroyed.connect(_on_player_destroyed),
				bus.boss.boss_defeated.connect(_on_boss_defeated),
				bus.profile.settings_changed.connect(_on_settings_changed),
			]
		)
	)


## From now on, vibrate the connected gamepads (the game, not tests).
func drive_input() -> void:
	_drives_input = true


func _rumble(weak: float, strong: float, seconds: float) -> void:
	if not JuiceSettings.rumble(_settings):
		return
	var w: float = clampf(weak, 0.0, 1.0)
	var s: float = clampf(strong, 0.0, 1.0)
	rumbled.emit(w, s, seconds)
	if _drives_input:
		for device: int in Input.get_connected_joypads():
			Input.start_joy_vibration(device, w, s, seconds)


func _on_armor_changed(_armor: int, _max_armor: int, delta: int) -> void:
	if delta < 0:
		var extra: float = HIT_PER_POINT * float(-delta)
		_rumble(HIT_WEAK + extra, HIT_STRONG + extra, HIT_SECONDS)


func _on_player_destroyed(_position: Vector3, _cause: DestroyCause.Cause) -> void:
	_rumble(DEATH_WEAK, DEATH_STRONG, DEATH_SECONDS)


func _on_boss_defeated(_boss_id: StringName, _position: Vector3) -> void:
	_rumble(BOSS_WEAK, BOSS_STRONG, BOSS_SECONDS)


func _on_settings_changed(settings: GameSettings) -> void:
	_settings = settings.copy()
	if not JuiceSettings.rumble(_settings) and _drives_input:
		for device: int in Input.get_connected_joypads():
			Input.stop_joy_vibration(device)
