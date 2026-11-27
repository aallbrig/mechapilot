class_name CameraJuice
extends Node
## Decides the camera's share of the juice from Game Events (#26): a kick
## against the aim per shot, shake per kill that grows with the Combo, and
## bigger shakes and FOV punches for hits, the player's death, boss phase
## changes and boss kills. It only decides: main.gd connects its signals to the
## camera rig (game/), which feedback/ may not name. The shake toggle and
## reduced motion silence all of it (JuiceSettings.camera_motion).

## Shake (trauma, 0..1) asked for by `amount`.
signal trauma_requested(amount: float)
## Shove the camera by `offset` (world units).
signal kick_requested(offset: Vector3)
## Narrow the FOV by `degrees` for a moment.
signal fov_punch_requested(degrees: float)

## Per shot: a kick against the aim and a whisper of shake.
const SHOT_KICK: float = 0.25
const SHOT_TRAUMA: float = 0.04
## Per kill: the base shake, what each Combo step adds, and the ceiling.
const KILL_TRAUMA: float = 0.16
const KILL_TRAUMA_PER_COMBO: float = 0.05
const KILL_TRAUMA_MAX: float = 0.6
## Taking a hit.
const HIT_TRAUMA: float = 0.5
const HIT_FOV_PUNCH: float = 4.0
## The player's death.
const DEATH_TRAUMA: float = 1.0
const DEATH_FOV_PUNCH: float = 14.0
## A boss phase change and a boss kill.
const PHASE_TRAUMA: float = 0.45
const BOSS_DEFEAT_TRAUMA: float = 1.0
const BOSS_DEFEAT_FOV_PUNCH: float = 10.0

var _settings: GameSettings = GameSettings.new()


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	(
		BusLinks
		. require_ok(
			"CameraJuice",
			[
				bus.player.player_fired.connect(_on_player_fired),
				bus.run.kill_scored.connect(_on_kill_scored),
				bus.player.armor_changed.connect(_on_armor_changed),
				bus.player.player_destroyed.connect(_on_player_destroyed),
				bus.boss.boss_phase_changed.connect(_on_boss_phase_changed),
				bus.boss.boss_defeated.connect(_on_boss_defeated),
				bus.profile.settings_changed.connect(_on_settings_changed),
			]
		)
	)


## The shake of one kill at Combo `multiplier` (1 to 8).
static func kill_trauma(multiplier: int) -> float:
	return minf(
		KILL_TRAUMA + KILL_TRAUMA_PER_COMBO * float(maxi(multiplier - 1, 0)), KILL_TRAUMA_MAX
	)


func _shake(amount: float, punch: float) -> void:
	if not JuiceSettings.camera_motion(_settings):
		return
	trauma_requested.emit(amount)
	if punch > 0.0:
		fov_punch_requested.emit(punch)


func _on_player_fired(_origin: Vector3, direction: Vector3) -> void:
	if not JuiceSettings.camera_motion(_settings):
		return
	kick_requested.emit(-direction.normalized() * SHOT_KICK)
	trauma_requested.emit(SHOT_TRAUMA)


func _on_kill_scored(_points: int, multiplier: int, _position: Vector3) -> void:
	_shake(kill_trauma(multiplier), 0.0)


func _on_armor_changed(_armor: int, _max_armor: int, delta: int) -> void:
	if delta < 0:
		_shake(HIT_TRAUMA, HIT_FOV_PUNCH)


func _on_player_destroyed(_position: Vector3, _cause: DestroyCause.Cause) -> void:
	_shake(DEATH_TRAUMA, DEATH_FOV_PUNCH)


func _on_boss_phase_changed(_phase: int, _phases: int) -> void:
	_shake(PHASE_TRAUMA, 0.0)


func _on_boss_defeated(_boss_id: StringName, _position: Vector3) -> void:
	_shake(BOSS_DEFEAT_TRAUMA, BOSS_DEFEAT_FOV_PUNCH)


func _on_settings_changed(settings: GameSettings) -> void:
	_settings = settings.copy()
