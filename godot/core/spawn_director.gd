class_name SpawnDirector
extends RefCounted
## Decides what spawns, where and when (#73, as in the LAN prototype). It is
## seeded through the injected RandomNumberGenerator, so the same seed and the
## same events give the same decisions.
##
## Skirmish: a trickle of single enemies while fewer than floor(limit) are
## alive, with a delay of rand(delay_min, delay_max) + buffer between them,
## plus a wave of wave_size enemies from one side every wave_interval seconds.
## Every kill in the Skirmish raises the limit (up to limit_max), shrinks the
## buffer (down to buffer_min) and raises aggression (up to aggression_max).
## A kind joins the weighted pick once the Level has its min_kills kills.
## Boss Warning: nothing new spawns; the survivors stay. Boss Fight: escorts
## from the boss's roster, up to its limit. Spawning stops while the player is
## destroyed and resumes when it respawns. Nothing ever exceeds the pool size.
## Each shot kill drops a Repair Kit with RunRules.REPAIR_DROP_CHANCE; a boss
## always drops one.
##
## Listens: flow.game_state_changed, run.level_intro_started, enemy.enemy_spawned,
## enemy.enemy_destroyed, enemy.enemy_left_play_sphere, player.player_destroyed,
## player.player_respawned and boss.boss_defeated.
## Announces: enemy.spawn_requested and player.repair_kit_dropped.

var _events: EventBus
var _rng: RandomNumberGenerator
var _levels: Array[LevelDefinition] = []
var _level: LevelDefinition = null
var _phase: GameState.Phase = GameState.Phase.BOOT
var _player_down: bool = false
var _alive: Dictionary[int, bool] = {}
var _pending: int = 0
var _kills: int = 0
var _limit: float = 0.0
var _buffer: float = 0.0
var _aggression: float = 0.0
var _cooldown: float = 0.0
var _wave_left: float = 0.0
var _waves: int = 0


func _init(events: EventBus, rng: RandomNumberGenerator, levels: Array[LevelDefinition]) -> void:
	_events = events
	_rng = rng
	_levels = levels.duplicate()
	var subscribed: Array[int] = [
		_events.flow.game_state_changed.connect(_on_game_state_changed),
		_events.run.level_intro_started.connect(_on_level_intro_started),
		_events.enemy.enemy_spawned.connect(_on_enemy_spawned),
		_events.enemy.enemy_destroyed.connect(_on_enemy_destroyed),
		_events.enemy.enemy_left_play_sphere.connect(_on_enemy_left_play_sphere),
		_events.player.player_destroyed.connect(_on_player_destroyed),
		_events.player.player_respawned.connect(_on_player_respawned),
		_events.boss.boss_defeated.connect(_on_boss_defeated),
	]
	Subscriptions.require_ok("SpawnDirector", subscribed)


## Advances the spawn clocks by `delta` seconds and announces any spawns due.
func tick(delta: float) -> void:
	if _level == null or _player_down or delta <= 0.0:
		return
	if _phase == GameState.Phase.SKIRMISH:
		_tick_skirmish(delta)
	elif _phase == GameState.Phase.BOSS_FIGHT:
		_tick_escorts(delta)


## Enemies alive or requested and not yet reported spawned.
func live_count() -> int:
	return _alive.size() + _pending


## The live-enemy limit (its floor is the number allowed).
func limit() -> float:
	return _limit


## Seconds added to every trickle delay.
func buffer() -> float:
	return _buffer


## The aggression given to new enemies, 0 to 1.
func aggression() -> float:
	return _aggression


## Kills counted toward the ramp in this Level.
func kills() -> int:
	return _kills


func _tick_skirmish(delta: float) -> void:
	var tuning: LevelDefinition.SpawnTuning = _level.spawn
	_wave_left -= delta
	if _wave_left <= 0.0:
		_wave_left += tuning.wave_interval
		_waves += 1
		var size: int = tuning.wave_size_start + tuning.wave_size_growth * (_waves - 1)
		var side: float = _rng.randf() * TAU
		for _i: int in size:
			_request(
				_level.roster,
				side + _rng.randf_range(-tuning.wave_spread, tuning.wave_spread),
				false
			)
	_cooldown -= delta
	if _cooldown <= 0.0 and live_count() < floori(_limit):
		_request(_level.roster, _rng.randf() * TAU, false)
		_cooldown = _rng.randf_range(tuning.delay_min + _buffer, tuning.delay_max + _buffer)


func _tick_escorts(delta: float) -> void:
	var boss: BossDefinition = _level.boss
	_cooldown -= delta
	if _cooldown <= 0.0 and live_count() < boss.escort_limit:
		_request(boss.escort_roster, _rng.randf() * TAU, true)
		_cooldown = _rng.randf_range(boss.escort_delay_min, boss.escort_delay_max)


## Announces one spawn of a kind picked from `roster`, unless the pool is full.
func _request(roster: Array[LevelDefinition.RosterEntry], angle: float, escort: bool) -> void:
	if live_count() >= _level.spawn.pool:
		return
	var tuning: LevelDefinition.SpawnTuning = _level.spawn
	var distance: float = tuning.spawn_distance + _rng.randf() * tuning.spawn_distance_jitter
	var order: SpawnOrder = SpawnOrder.new(
		_pick(roster),
		wrapf(angle, 0.0, TAU),
		distance,
		tuning.aggression_max if escort else _aggression,
		_level.enemy_speed_scale,
		_level.enemy_fire_rate_scale,
		escort
	)
	_pending += 1
	_events.enemy.announce_spawn_requested(order)


## A weighted pick among the roster entries open at the current kill count.
func _pick(roster: Array[LevelDefinition.RosterEntry]) -> EnemyKind.Kind:
	var total: float = 0.0
	for entry: LevelDefinition.RosterEntry in roster:
		if entry.min_kills <= _kills:
			total += entry.weight
	var roll: float = _rng.randf() * total
	var chosen: EnemyKind.Kind = roster[0].kind
	for entry: LevelDefinition.RosterEntry in roster:
		if entry.min_kills > _kills:
			continue
		chosen = entry.kind
		roll -= entry.weight
		if roll < 0.0:
			break
	return chosen


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to
	if to == GameState.Phase.BOSS_FIGHT and _level != null:
		_cooldown = _level.boss.escort_delay_min
	elif to == GameState.Phase.TITLE:
		_level = null


func _on_level_intro_started(
	level_number: int, _level_name: String, _objective: String, _duration: float
) -> void:
	if level_number < 1 or level_number > _levels.size():
		_level = null
		return
	_level = _levels[level_number - 1]
	var tuning: LevelDefinition.SpawnTuning = _level.spawn
	_alive.clear()
	_pending = 0
	_kills = 0
	_waves = 0
	_limit = tuning.limit_start
	_buffer = tuning.buffer_start
	_aggression = tuning.aggression_start
	_cooldown = 0.0
	_wave_left = tuning.wave_interval
	_player_down = false


func _on_enemy_spawned(enemy_id: int, _kind: EnemyKind.Kind, _position: Vector3) -> void:
	_pending = maxi(_pending - 1, 0)
	_alive[enemy_id] = true


func _on_enemy_destroyed(
	enemy_id: int, _kind: EnemyKind.Kind, position: Vector3, cause: DestroyCause.Cause
) -> void:
	var _was_alive: bool = _alive.erase(enemy_id)
	if _level == null or not GameState.is_timed(_phase):
		return
	if _phase == GameState.Phase.SKIRMISH:
		var tuning: LevelDefinition.SpawnTuning = _level.spawn
		_kills += 1
		_limit = minf(_limit + tuning.limit_per_kill, tuning.limit_max)
		_buffer = maxf(_buffer - tuning.buffer_per_kill, tuning.buffer_min)
		_aggression = minf(_aggression + tuning.aggression_per_kill, tuning.aggression_max)
	if cause == DestroyCause.Cause.SHOT and _rng.randf() < RunRules.REPAIR_DROP_CHANCE:
		_events.player.announce_repair_kit_dropped(position)


func _on_enemy_left_play_sphere(enemy_id: int) -> void:
	var _was_alive: bool = _alive.erase(enemy_id)


func _on_player_destroyed(_position: Vector3, _cause: DestroyCause.Cause) -> void:
	_player_down = true


func _on_player_respawned() -> void:
	_player_down = false


func _on_boss_defeated(_boss_id: StringName, position: Vector3) -> void:
	_events.player.announce_repair_kit_dropped(position)
