class_name RunLedger
extends RefCounted
## The Run's accounts (#73): score, the combo multiplier, Armor and
## invulnerability, lives and the one-time bonus life, kills, accuracy and Run
## time. It reacts to reported facts on the bus; LevelProgression calls its
## lifecycle methods (start_run, start_level, respawn, award_boss, close_level)
## so the order of Run-level steps never depends on signal order.
##
## Listens: flow.game_state_changed, player.player_fired, player.player_hit,
## player.repair_collected, enemy.enemy_hit, enemy.enemy_destroyed, boss.boss_hit.
## Announces: run.kill_scored, run.score_changed, run.combo_changed,
## player.armor_changed, player.invulnerability_started,
## player.invulnerability_ended, player.player_destroyed, player.life_lost,
## player.lives_changed and player.bonus_life_awarded.
##
## Rules: only shot kills score (a crash scores 0), and only in timed phases
## (GameState.is_timed) while the player is not down. Hits are ignored while
## invulnerable, while down, and outside timed phases. Damage resets the combo.
##
## Developer commands (#116, through DevCommands): developer invulnerability
## (hits are ignored while it is on, and a Run started with it on is
## dev-assisted), award_points(), restore_armor() and award_life(). Any of them
## marks the Run dev-assisted; its summary carries the mark.

var _events: EventBus
var _phase: GameState.Phase = GameState.Phase.BOOT
var _score: int = 0
var _lives: int = RunRules.START_LIVES
var _armor: int = RunRules.MAX_ARMOR
var _bonus_awarded: bool = false
var _down: bool = false
var _invulnerable_left: float = 0.0
var _multiplier: int = 1
var _combo_left: float = 0.0
var _run_time: float = 0.0
var _run_kills: int = 0
var _level_number: int = 1
var _level_kills: int = 0
var _level_shots: int = 0
var _level_hits: int = 0
var _level_life_lost: bool = false
var _dev_invulnerable: bool = false
var _dev_assisted: bool = false


func _init(events: EventBus) -> void:
	_events = events
	var subscribed: Array[int] = [
		_events.flow.game_state_changed.connect(_on_game_state_changed),
		_events.player.player_fired.connect(_on_player_fired),
		_events.player.player_hit.connect(_on_player_hit),
		_events.player.repair_collected.connect(_on_repair_collected),
		_events.enemy.enemy_hit.connect(_on_enemy_hit),
		_events.enemy.enemy_destroyed.connect(_on_enemy_destroyed),
		_events.boss.boss_hit.connect(_on_boss_hit),
	]
	Subscriptions.require_ok("RunLedger", subscribed)


## Resets every account for a new Run and announces the starting values.
func start_run() -> void:
	_score = 0
	_lives = RunRules.START_LIVES
	_armor = RunRules.MAX_ARMOR
	_bonus_awarded = false
	_down = false
	_invulnerable_left = 0.0
	_multiplier = 1
	_combo_left = 0.0
	_run_time = 0.0
	_run_kills = 0
	_dev_assisted = _dev_invulnerable
	start_level(1)
	_events.run.announce_score_changed(_score, 0)
	_events.run.announce_combo_changed(_multiplier)
	_events.player.announce_armor_changed(_armor, RunRules.MAX_ARMOR, 0)
	_events.player.announce_lives_changed(_lives)


## Starts the per-Level accounts (kills, shots, hits, the no-death flag).
func start_level(level_number: int) -> void:
	_level_number = level_number
	_level_kills = 0
	_level_shots = 0
	_level_hits = 0
	_level_life_lost = false


## Brings the player back at full Armor with the respawn invulnerability.
## Does nothing unless the player is down with a life left.
func respawn() -> void:
	if not _down or _lives <= 0:
		return
	_down = false
	var delta: int = RunRules.MAX_ARMOR - _armor
	_armor = RunRules.MAX_ARMOR
	_events.player.announce_armor_changed(_armor, RunRules.MAX_ARMOR, delta)
	_start_invulnerability(RunRules.RESPAWN_INVULNERABILITY)


## Adds the boss score for the current Level (5,000 times the Level number).
func award_boss() -> void:
	_add_points(RunRules.boss_points(_level_number))


## Closes the current Level: adds the Level Clear bonus to the score and
## returns the tally (the caller announces it).
func close_level() -> LevelTally:
	var armor_points: int = (0 if _down else _armor) * RunRules.ARMOR_BONUS_PER_POINT
	var no_death_points: int = 0 if _level_life_lost else RunRules.NO_DEATH_BONUS
	var tally: LevelTally = LevelTally.new(
		_level_number, _level_kills, _level_shots, _level_hits, armor_points, no_death_points
	)
	_add_points(tally.bonus_total())
	return tally


## The Run's summary so far.
func summary(victory: bool) -> RunSummary:
	var made: RunSummary = RunSummary.new(_score, _level_number, _run_time, _run_kills, victory)
	made.dev_assisted = _dev_assisted
	return made


## Turns developer invulnerability on or off and returns the new state. While
## it is on every hit is ignored. Turning it on marks the Run dev-assisted
## (and every Run started while it stays on).
func toggle_dev_invulnerability() -> bool:
	_dev_invulnerable = not _dev_invulnerable
	if _dev_invulnerable:
		mark_dev_assisted()
	return _dev_invulnerable


## Marks the Run dev-assisted until the next start_run().
func mark_dev_assisted() -> void:
	_dev_assisted = true


## True when a developer command changed this Run.
func is_dev_assisted() -> bool:
	return _dev_assisted


## Adds `points` to the score as any award does (the bonus life included),
## without touching the combo or the Boss Gauge. Marks the Run dev-assisted.
func award_points(points: int) -> void:
	if points <= 0:
		return
	mark_dev_assisted()
	_add_points(points)


## Repairs the mech to full Armor, as a Repair Kit does, at any Armor. Returns
## false (and changes nothing) while the player is down or already at full Armor.
## Marks the Run dev-assisted when it repairs.
func restore_armor() -> bool:
	if _down or _armor >= RunRules.MAX_ARMOR:
		return false
	mark_dev_assisted()
	var before: int = _armor
	_armor = RunRules.MAX_ARMOR
	_events.player.announce_armor_changed(_armor, RunRules.MAX_ARMOR, _armor - before)
	return true


## Gives one extra life (not the one-time bonus life). Marks the Run dev-assisted.
func award_life() -> void:
	mark_dev_assisted()
	_lives += 1
	_events.player.announce_lives_changed(_lives)


## Advances the combo window, invulnerability and Run time by `delta` seconds.
## Nothing advances while paused; Run time advances only in timed phases.
func tick(delta: float) -> void:
	if _phase == GameState.Phase.PAUSED or delta <= 0.0:
		return
	if GameState.is_timed(_phase):
		_run_time += delta
	if _combo_left > 0.0:
		_combo_left -= delta
		if _combo_left <= 0.0:
			_reset_combo()
	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
		if _invulnerable_left <= 0.0:
			_invulnerable_left = 0.0
			_events.player.announce_invulnerability_ended()


func score() -> int:
	return _score


func lives() -> int:
	return _lives


func armor() -> int:
	return _armor


## The current combo multiplier, 1 to RunRules.COMBO_MAX_MULTIPLIER.
func multiplier() -> int:
	return _multiplier


## True between losing a life and respawning (or for good, at 0 lives).
func is_down() -> bool:
	return _down


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Seconds of Run time (timed phases only).
func run_time() -> float:
	return _run_time


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to


func _on_player_fired(_origin: Vector3, _direction: Vector3) -> void:
	if GameState.is_timed(_phase) and not _down:
		_level_shots += 1


func _on_enemy_hit(_enemy_id: int, _position: Vector3) -> void:
	if GameState.is_timed(_phase):
		_level_hits += 1


func _on_boss_hit(_damage: int, _position: Vector3) -> void:
	if GameState.is_timed(_phase):
		_level_hits += 1


func _on_enemy_destroyed(
	_enemy_id: int, kind: EnemyKind.Kind, position: Vector3, cause: DestroyCause.Cause
) -> void:
	if cause != DestroyCause.Cause.SHOT or not GameState.is_timed(_phase) or _down:
		return
	_run_kills += 1
	_level_kills += 1
	var before: int = _multiplier
	_multiplier = mini(_multiplier + 1, RunRules.COMBO_MAX_MULTIPLIER) if _combo_left > 0.0 else 1
	_combo_left = RunRules.COMBO_WINDOW
	if _multiplier != before:
		_events.run.announce_combo_changed(_multiplier)
	var points: int = RunRules.kill_points(kind) * _multiplier
	_events.run.announce_kill_scored(points, _multiplier, position)
	_add_points(points)


func _on_player_hit(source: DamageSource.Source, position: Vector3, attack_damage: int) -> void:
	if not GameState.is_timed(_phase) or _down or _invulnerable_left > 0.0 or _dev_invulnerable:
		return
	var damage: int = RunRules.damage_for(source, attack_damage)
	var before: int = _armor
	_armor = maxi(_armor - damage, 0)
	_events.player.announce_armor_changed(_armor, RunRules.MAX_ARMOR, _armor - before)
	_reset_combo()
	if _armor > 0:
		_start_invulnerability(RunRules.HIT_INVULNERABILITY)
		return
	_down = true
	_level_life_lost = true
	_lives -= 1
	var cause: DestroyCause.Cause = (
		DestroyCause.Cause.COLLISION
		if source == DamageSource.Source.ENEMY_COLLISION
		else DestroyCause.Cause.SHOT
	)
	_events.player.announce_player_destroyed(position, cause)
	_events.player.announce_life_lost(_lives)
	_events.player.announce_lives_changed(_lives)


func _on_repair_collected(_position: Vector3) -> void:
	if not GameState.is_play(_phase) or _down or _armor >= RunRules.MAX_ARMOR:
		return
	var before: int = _armor
	_armor = mini(_armor + RunRules.REPAIR_ARMOR, RunRules.MAX_ARMOR)
	_events.player.announce_armor_changed(_armor, RunRules.MAX_ARMOR, _armor - before)


func _add_points(points: int) -> void:
	if points <= 0:
		return
	_score += points
	_events.run.announce_score_changed(_score, points)
	if not _bonus_awarded and _score >= RunRules.BONUS_LIFE_SCORE:
		_bonus_awarded = true
		_lives += 1
		_events.player.announce_bonus_life_awarded(_lives)
		_events.player.announce_lives_changed(_lives)


func _reset_combo() -> void:
	_combo_left = 0.0
	if _multiplier != 1:
		_multiplier = 1
		_events.run.announce_combo_changed(_multiplier)


func _start_invulnerability(duration: float) -> void:
	_invulnerable_left = duration
	_events.player.announce_invulnerability_started(duration)
