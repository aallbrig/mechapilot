class_name SfxDirector
extends Node
## Plays a sound for every action (#26, #73), from the synthesized SfxBank, on
## the SFX bus (UI cues on the UI bus), through a fixed set of voices that
## steal the oldest when all are busy. It also runs two timed sounds:
##
##   low-Armor warning  a beep loop while Armor is low and play is running,
##                      until a repair lifts it, the mech is destroyed or play stops
##   boss siren         repeats through the Boss Warning
##
## Nothing plays until unlock() (the AudioUnlock gate), so the browser never
## sees audio before the first user gesture. Explosion booms come from
## play_blast(), which feedback_rig.gd connects to the ExplosionPool, so the
## sound lands with each blast, the boss defeat chain included.

const SFX_VOICES: int = 12
const UI_VOICES: int = 3
## Shots vary their pitch a little, so rapid fire never drones.
const SHOT_PITCH_SPREAD: float = 0.1
## The Combo blip climbs this many semitones per Combo step.
const COMBO_SEMITONES: float = 2.0
## Blasts this size or bigger use the big boom; bigger blasts also pitch down.
const BIG_BLAST: float = 2.0
const BLAST_PITCH_PER_SIZE: float = 0.12
const MIN_BLAST_PITCH: float = 0.6
## Armor at or below this share of the maximum sounds the warning, every
## LOW_ARMOR_INTERVAL seconds.
const LOW_ARMOR_SHARE: float = 0.3
const LOW_ARMOR_INTERVAL: float = 0.7
## The siren sounds every SIREN_PERIOD seconds through the Boss Warning.
const SIREN_PERIOD: float = 1.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _clock: RealClock = RealClock.new()
var _streams: Dictionary[SfxBank.Cue, AudioStreamWAV] = SfxBank.render_all()
var _sfx: Array[AudioStreamPlayer] = []
var _ui: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0
var _next_ui: int = 0
var _unlocked: bool = false
var _phase: GameState.Phase = GameState.Phase.BOOT
var _low_armor: bool = false
var _alarm_wait: float = 0.0
var _sirens_left: int = 0
var _siren_wait: float = 0.0
var _played: Array[SfxBank.Cue] = []
var _played_buses: Array[StringName] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i: int in SFX_VOICES:
		_sfx.append(_voice(AudioBuses.SFX))
	for _i: int in UI_VOICES:
		_ui.append(_voice(AudioBuses.UI))


func _process(_delta: float) -> void:
	advance(_clock.step())


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	(
		BusLinks
		. require_ok(
			"SfxDirector",
			[
				bus.player.player_fired.connect(_on_player_fired),
				bus.enemy.enemy_hit.connect(_on_enemy_hit),
				bus.run.kill_scored.connect(_on_kill_scored),
				bus.player.armor_changed.connect(_on_armor_changed),
				bus.player.repair_collected.connect(_on_repair_collected),
				bus.player.bonus_life_awarded.connect(_on_bonus_life_awarded),
				bus.player.player_destroyed.connect(_on_player_destroyed),
				bus.player.player_respawned.connect(_on_player_respawned),
				bus.boss.boss_warning_started.connect(_on_boss_warning_started),
				bus.boss.boss_hit.connect(_on_boss_hit),
				bus.boss.boss_phase_changed.connect(_on_boss_phase_changed),
				bus.run.level_intro_started.connect(_on_level_intro_started),
				bus.flow.game_state_changed.connect(_on_game_state_changed),
				bus.flow.ui_cue_requested.connect(_on_ui_cue_requested),
			]
		)
	)


## Audio may play from now on (the first user gesture arrived).
func unlock() -> void:
	_unlocked = true


## Play `cue` at `pitch` (1 = as rendered). Ignored until unlock().
func play(cue: SfxBank.Cue, pitch: float) -> void:
	if not _unlocked:
		return
	var player: AudioStreamPlayer
	if SfxBank.is_ui(cue):
		player = _ui[_next_ui]
		_next_ui = (_next_ui + 1) % UI_VOICES
	else:
		player = _sfx[_next_sfx]
		_next_sfx = (_next_sfx + 1) % SFX_VOICES
	player.stream = _streams[cue]
	player.pitch_scale = pitch
	player.play()
	_played.append(cue)
	_played_buses.append(player.bus)


## The boom of a blast `blast_size` times the base size (from ExplosionPool).
func play_blast(_at: Vector3, blast_size: float) -> void:
	var cue: SfxBank.Cue = (
		SfxBank.Cue.BIG_EXPLOSION if blast_size >= BIG_BLAST else SfxBank.Cue.EXPLOSION
	)
	play(cue, maxf(MIN_BLAST_PITCH, 1.0 + BLAST_PITCH_PER_SIZE * (1.0 - blast_size)))


## The charge whine of an enemy's attack telegraph (EnemyField.enemy_telegraphed,
## which main.gd connects once it builds the field).
func play_charge(_at: Vector3, _kind: EnemyKind.Kind) -> void:
	play(SfxBank.Cue.CHARGE, 1.0)


## Run the warning beeps and the siren on by `real_delta` seconds.
func advance(real_delta: float) -> void:
	if _low_armor and GameState.is_play(_phase):
		_alarm_wait -= real_delta
		if _alarm_wait <= 0.0:
			_alarm_wait += LOW_ARMOR_INTERVAL
			play(SfxBank.Cue.LOW_ARMOR, 1.0)
	if _sirens_left > 0:
		_siren_wait -= real_delta
		if _siren_wait <= 0.0:
			_siren_wait += SIREN_PERIOD
			_sirens_left -= 1
			play(SfxBank.Cue.SIREN, 1.0)


## Every cue played so far, oldest first, then forgotten.
func take_played() -> Array[SfxBank.Cue]:
	var played: Array[SfxBank.Cue] = _played
	_played = []
	return played


## The bus of the voice each cue played on, oldest first, then forgotten.
func take_played_buses() -> Array[StringName]:
	var buses: Array[StringName] = _played_buses
	_played_buses = []
	return buses


## How many voices are sounding.
func playing_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _sfx + _ui:
		if player.playing:
			count += 1
	return count


## True while the low-Armor warning is armed.
func low_armor_warning() -> bool:
	return _low_armor


func _voice(bus_name: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player


func _arm_alarm(on: bool) -> void:
	if on and not _low_armor:
		_alarm_wait = 0.0
	_low_armor = on


func _on_player_fired(_origin: Vector3, _direction: Vector3) -> void:
	play(SfxBank.Cue.SHOT, 1.0 + rng.randf_range(-SHOT_PITCH_SPREAD, SHOT_PITCH_SPREAD))


func _on_enemy_hit(_enemy_id: int, _position: Vector3) -> void:
	play(SfxBank.Cue.ENEMY_HIT, 1.0)


func _on_kill_scored(_points: int, multiplier: int, _position: Vector3) -> void:
	play(SfxBank.Cue.COMBO, pow(2.0, COMBO_SEMITONES * float(maxi(multiplier - 1, 0)) / 12.0))


func _on_armor_changed(armor: int, max_armor: int, delta: int) -> void:
	if delta < 0:
		play(SfxBank.Cue.PLAYER_HIT, 1.0)
	_arm_alarm(armor > 0 and float(armor) <= float(max_armor) * LOW_ARMOR_SHARE)


func _on_repair_collected(_position: Vector3) -> void:
	play(SfxBank.Cue.REPAIR, 1.0)


func _on_bonus_life_awarded(_lives: int) -> void:
	play(SfxBank.Cue.ONE_UP, 1.0)


func _on_player_destroyed(_position: Vector3, _cause: DestroyCause.Cause) -> void:
	_arm_alarm(false)
	play(SfxBank.Cue.PLAYER_DESTROYED, 1.0)


func _on_player_respawned() -> void:
	_arm_alarm(false)


func _on_boss_warning_started(_boss_name: String, duration: float) -> void:
	_sirens_left = maxi(ceili(duration / SIREN_PERIOD) - 1, 0)
	_siren_wait = SIREN_PERIOD
	play(SfxBank.Cue.SIREN, 1.0)


func _on_boss_hit(_damage: int, _position: Vector3) -> void:
	play(SfxBank.Cue.BOSS_HIT, 1.0)


func _on_boss_phase_changed(_phase_index: int, _phases: int) -> void:
	play(SfxBank.Cue.BOSS_PHASE, 1.0)


func _on_level_intro_started(
	_level_number: int, _level_name: String, _objective: String, _duration: float
) -> void:
	play(SfxBank.Cue.LEVEL_START, 1.0)


func _on_ui_cue_requested(cue: UiCue.Cue) -> void:
	play(SfxBank.FOR_UI[cue], 1.0)


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to
	if not GameState.is_play(to) and to != GameState.Phase.PAUSED:
		_arm_alarm(false)
		_sirens_left = 0
