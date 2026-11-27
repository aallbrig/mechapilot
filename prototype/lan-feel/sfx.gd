extends Node
## PROTOTYPE procedural sound (throwaway). A tiny voice mixer fed into an
## AudioStreamGenerator. Each voice is a decaying square sweep plus filtered noise.

const MIX_RATE := 22050.0
const MAX_VOICES := 10


class Voice:
	var age := 0.0
	var duration := 0.1
	var freq_start := 440.0
	var freq_end := 110.0
	var square := 0.5
	var noise := 0.5
	var volume := 0.3
	var phase := 0.0
	var lowpass := 0.0
	var cutoff := 0.5


var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Voice] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.12
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	Events.shot_fired.connect(_on_shot)
	Events.enemy_hit.connect(_on_hit)
	Events.enemy_killed.connect(_on_killed)
	Events.player_died.connect(_on_player_died)
	Events.wave_started.connect(_on_wave)
	Events.game_started.connect(_on_game_started)
	Events.extra_life.connect(_on_extra_life)
	Events.ui_focus.connect(_on_ui_focus)
	Events.ui_confirm.connect(_on_ui_confirm)


func play(
	duration: float, f0: float, f1: float, square: float, noise: float, volume: float, cutoff: float
) -> void:
	if _voices.size() >= MAX_VOICES:
		_voices.pop_front()
	var v := Voice.new()
	v.duration = duration
	v.freq_start = f0
	v.freq_end = f1
	v.square = square
	v.noise = noise
	v.volume = volume
	v.cutoff = cutoff
	_voices.append(v)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var dt := 1.0 / MIX_RATE
	for i in frames:
		var s := 0.0
		for v in _voices:
			var k := v.age / v.duration
			if k >= 1.0:
				continue
			var env := (1.0 - k) * (1.0 - k)
			var freq := v.freq_start * pow(v.freq_end / v.freq_start, k)
			v.phase = fmod(v.phase + freq * dt, 1.0)
			var sq := 1.0 if v.phase < 0.5 else -1.0
			v.lowpass += (randf_range(-1.0, 1.0) - v.lowpass) * v.cutoff
			s += (sq * v.square + v.lowpass * v.noise) * env * v.volume
			v.age += dt
		s = clampf(s, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))
	_voices = _voices.filter(func(v: Voice) -> bool: return v.age < v.duration)


func _on_shot(_origin: Vector3, _direction: Vector3) -> void:
	play(0.07, randf_range(900.0, 1100.0), 180.0, 0.35, 0.25, 0.18, 0.6)


func _on_hit(_position: Vector3) -> void:
	play(0.05, 300.0, 120.0, 0.4, 0.6, 0.3, 0.8)


func _on_killed(_position: Vector3, _points: int, combo: int) -> void:
	play(0.45, 140.0, 35.0, 0.35, 1.0, 0.55, 0.25)
	var pitch := 440.0 * pow(1.1225, float(mini(combo, 12)))
	play(0.12, pitch, pitch * 1.5, 0.3, 0.0, 0.12, 1.0)


func _on_player_died(_position: Vector3) -> void:
	play(1.6, 220.0, 25.0, 0.4, 1.0, 0.8, 0.12)
	play(0.8, 90.0, 30.0, 0.6, 0.0, 0.4, 1.0)


func _on_wave(_number: int) -> void:
	play(0.25, 330.0, 660.0, 0.4, 0.0, 0.15, 1.0)
	play(0.35, 495.0, 990.0, 0.3, 0.0, 0.12, 1.0)


func _on_game_started() -> void:
	play(0.3, 220.0, 880.0, 0.4, 0.0, 0.15, 1.0)


func _on_extra_life(_lives: int) -> void:
	for i in 4:
		var f := 523.0 * pow(1.26, float(i))
		play(0.12 + i * 0.08, f, f * 1.02, 0.35, 0.0, 0.14, 1.0)


func _on_ui_focus() -> void:
	play(0.04, 1400.0, 1700.0, 0.3, 0.0, 0.06, 1.0)


func _on_ui_confirm() -> void:
	play(0.12, 600.0, 1500.0, 0.35, 0.1, 0.12, 0.8)
