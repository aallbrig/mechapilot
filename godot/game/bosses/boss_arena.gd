class_name BossArena
extends Node3D
## Brings in the Level's boss and runs it. On `boss_summoned` it builds the
## Boss from that Level's BossDefinition, which flies in, then fights with the
## patterns of each phase as `boss_phase_changed` arrives, and on
## `boss_defeated` plays its defeat sequence (the Level Clear has begun by
## then; the sequence plays through it) and frees it once it is gone. Player
## shots reach the boss through resolve_shot(). The rules decide health,
## phases and the one defeat (BossHealth); the arena only reports hits.
##
## It shares the enemy field's projectiles and target, and its drones are the
## field's enemies. It runs while in play, in the Level Clear and in Victory
## (the defeat sequence plays through both), holds still while paused, and
## removes the boss at once when the Run ends or a new Level starts.
##
## Listens: flow.game_state_changed, run.level_intro_started,
## boss.boss_summoned, boss.boss_phase_changed and boss.boss_defeated.
## Announces (through Boss): boss.boss_hit.

## The boss flew in and the fight began (health bar full; juice hook).
signal boss_entered(boss_id: StringName)
## One explosion of the defeat chain (juice and SFX hook).
signal boss_burst(position: Vector3, index: int)

var _events: EventBus
var _levels: Array[LevelDefinition] = []
var _field: EnemyField
var _level: LevelDefinition = null
var _phase: GameState.Phase = GameState.Phase.BOOT
var _boss: Boss = null


## Wire the arena: the bus, the Levels (for each boss's data and the player's
## shot damage) and the enemy field whose shots, drones and target it shares.
func setup(events: EventBus, levels: Array[LevelDefinition], field: EnemyField) -> void:
	_events = events
	_levels = levels.duplicate()
	_field = field
	var subscribed: Array[int] = [
		_events.flow.game_state_changed.connect(_on_game_state_changed),
		_events.run.level_intro_started.connect(_on_level_intro_started),
		_events.boss.boss_summoned.connect(_on_boss_summoned),
		_events.boss.boss_phase_changed.connect(_on_boss_phase_changed),
		_events.boss.boss_defeated.connect(_on_boss_defeated),
	]
	if subscribed.count(OK) != subscribed.size():
		push_error("BossArena: could not subscribe to the bus")


func _physics_process(delta: float) -> void:
	advance(delta)


## Advance `delta` seconds if the Game State lets the arena run (in play, the
## Level Clear and Victory). Whoever drives the arena instead of the engine
## calls this.
func advance(delta: float) -> void:
	if (
		GameState.is_play(_phase)
		or _phase == GameState.Phase.LEVEL_CLEAR
		or _phase == GameState.Phase.VICTORY
	):
		step(delta)


## Advance the boss `delta` seconds.
func step(delta: float) -> void:
	if _boss == null or _level == null:
		return
	_boss.step(
		delta, _field.player_target(), _field.shots(), _field, _level.enemy_bullet_speed_scale
	)


## A player shot of contact `shot_radius` at `at`. Returns true when it
## struck the boss, so the caller spends the shot.
func resolve_shot(at: Vector3, shot_radius: float) -> bool:
	return _boss != null and _boss.resolve_shot(at, shot_radius)


## The boss in play, or null.
func boss() -> Boss:
	return _boss


func _remove_boss() -> void:
	if _boss != null:
		_boss.free()
		_boss = null


func _on_boss_summoned(boss_id: StringName, _name: String, _health: int, _phases: int) -> void:
	_remove_boss()
	if _level == null or _level.boss.id != boss_id or BossProfile.of(boss_id) == null:
		push_error("BossArena: no boss %s in the current Level" % boss_id)
		return
	_boss = Boss.new()
	_boss.name = String(boss_id)
	add_child(_boss)
	var errs: Array[int] = [
		_boss.entered.connect(_on_entered),
		_boss.defeat_burst.connect(_on_burst),
		_boss.gone.connect(_on_gone),
	]
	if errs.count(OK) != errs.size():
		push_error("BossArena: could not watch the boss")
	_boss.begin(
		_events, _level.boss, _field.player_target().position(), _level.player.projectile_damage
	)


func _on_boss_phase_changed(phase: int, _phases: int) -> void:
	if _boss != null:
		_boss.enter_phase(phase)


func _on_boss_defeated(_boss_id: StringName, _position: Vector3) -> void:
	if _boss != null:
		_boss.begin_defeat()


func _on_entered(entered_boss: Boss) -> void:
	boss_entered.emit(entered_boss.definition.id)


func _on_burst(at: Vector3, index: int) -> void:
	boss_burst.emit(at, index)


func _on_gone(_gone_boss: Boss) -> void:
	# Freed after the signal returns, never from inside the boss's own step.
	var leaving: Boss = _boss
	_boss = null
	if leaving != null:
		leaving.queue_free()


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to
	if (
		to == GameState.Phase.TITLE
		or to == GameState.Phase.GAME_OVER
		or to == GameState.Phase.SCOREBOARD
	):
		_remove_boss()


func _on_level_intro_started(
	level_number: int, _level_name: String, _objective: String, _duration: float
) -> void:
	_remove_boss()
	if level_number < 1 or level_number > _levels.size():
		_level = null
		return
	_level = _levels[level_number - 1]
