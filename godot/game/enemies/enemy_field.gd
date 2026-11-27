class_name EnemyField
extends Node3D
## Every enemy in play, their projectiles and the Play Sphere. It answers each
## `spawn_requested` from the spawn director with exactly one enemy, placed at
## the order's angle and distance from the player, and reports it as
## `enemy_spawned`. Each tick it flies the enemies and their shots, resolves
## contacts by distance (a crash destroys the enemy with cause COLLISION and
## strikes the player with the kind's contact damage), and despawns whatever
## leaves the Play Sphere. Player shots reach enemies through resolve_shot().
## Enemies never collide with each other.
##
## It runs only while the Game State is in play (not paused), clears the field
## at Level Clear and whenever the Run ends, and holds fire while the player is
## destroyed (the director stops spawning meanwhile).
##
## Listens: flow.game_state_changed, run.level_intro_started and
## enemy.spawn_requested. Announces: enemy.enemy_spawned, enemy.enemy_hit,
## enemy.enemy_destroyed and enemy.enemy_left_play_sphere.

## An enemy was destroyed at `position` (explosion juice and SFX hook).
signal enemy_burst(position: Vector3, kind: EnemyKind.Kind, cause: DestroyCause.Cause)
## An enemy started its attack telegraph at `position` (charge SFX hook).
signal enemy_telegraphed(position: Vector3, kind: EnemyKind.Kind)

## Hits one player shot deals to an enemy (Heavy: 4 HP = 4 shots).
const PLAYER_SHOT_HITS: int = 1

var _events: EventBus
var _rng: RandomNumberGenerator
var _levels: Array[LevelDefinition] = []
var _target: CombatTarget
var _level: LevelDefinition = null
var _phase: GameState.Phase = GameState.Phase.BOOT
var _shots: EnemyShotPool = EnemyShotPool.new()
var _sphere: PlaySphere = PlaySphere.new(0.0)
var _enemies: Array[Enemy] = []
var _next_id: int = 1


func _init() -> void:
	_shots.name = "EnemyShots"
	add_child(_shots)


## Wire the field: the bus, its randomness, the Levels (for each Level's Play
## Sphere and bullet speed) and the player it fights. Call once.
func setup(
	events: EventBus,
	rng: RandomNumberGenerator,
	levels: Array[LevelDefinition],
	target: CombatTarget
) -> void:
	_events = events
	_rng = rng
	_levels = levels.duplicate()
	_target = target
	var subscribed: Array[int] = [
		_events.flow.game_state_changed.connect(_on_game_state_changed),
		_events.run.level_intro_started.connect(_on_level_intro_started),
		_events.enemy.spawn_requested.connect(_on_spawn_requested),
	]
	if subscribed.count(OK) != subscribed.size():
		push_error("EnemyField: could not subscribe to the bus")


func _physics_process(delta: float) -> void:
	if GameState.is_play(_phase):
		step(delta)


## Advance the field `delta` seconds.
func step(delta: float) -> void:
	if _target == null or _level == null or delta <= 0.0:
		return
	var target_alive: bool = _target.is_alive()
	_sphere.follow(_target.position())
	var bullet_scale: float = _level.enemy_bullet_speed_scale
	for enemy: Enemy in active_enemies():
		enemy.step(delta, _target, _shots, bullet_scale)
		if _sphere.is_outside(enemy.position):
			enemy.park()
			_events.enemy.announce_enemy_left_play_sphere(enemy.enemy_id)
		elif target_alive and _touches(enemy.position, enemy.radius()):
			var into: Vector3 = FiringSolution.aimed(enemy.position, _target.position())
			var _landed: bool = _target.strike(enemy.profile.contact, 0, into)
			_destroy(enemy, DestroyCause.Cause.COLLISION)
	_shots.step(delta, _target)
	_shots.cull_outside(_sphere.centre, _sphere.radius)


## A player shot of contact `shot_radius` at `at`, travelling along
## `direction`: the first enemy it touches takes PLAYER_SHOT_HITS (reported as
## `enemy_hit`, then `enemy_destroyed` with cause SHOT if that was its last).
## Returns true when it hit, so the caller spends the shot.
func resolve_shot(at: Vector3, shot_radius: float, direction: Vector3) -> bool:
	for enemy: Enemy in _enemies:
		if not enemy.is_active():
			continue
		if _plane_distance(enemy.position, at) > enemy.radius() + shot_radius:
			continue
		_events.enemy.announce_enemy_hit(enemy.enemy_id, enemy.position)
		if enemy.take_hits(PLAYER_SHOT_HITS, direction):
			_destroy(enemy, DestroyCause.Cause.SHOT)
		return true
	return false


## Put an enemy of `kind` in play at `at`, heading along `heading`, and report
## it. Bosses launch drones through this; spawn orders arrive here too.
func launch(kind: EnemyKind.Kind, at: Vector3, heading: Vector3, aggression: float) -> Enemy:
	var speed_scale: float = _level.enemy_speed_scale if _level != null else 1.0
	var fire_scale: float = _level.enemy_fire_rate_scale if _level != null else 1.0
	return _place(kind, at, heading, aggression, speed_scale, fire_scale)


## Every enemy in play.
func active_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for enemy: Enemy in _enemies:
		if enemy.is_active():
			out.append(enemy)
	return out


## The enemy in play with `enemy_id`, or null.
func find_enemy(enemy_id: int) -> Enemy:
	for enemy: Enemy in _enemies:
		if enemy.is_active() and enemy.enemy_id == enemy_id:
			return enemy
	return null


## Enemy nodes made so far, in play or parked.
func pooled_count() -> int:
	return _enemies.size()


func shots() -> EnemyShotPool:
	return _shots


func sphere() -> PlaySphere:
	return _sphere


## The player the field fights.
func player_target() -> CombatTarget:
	return _target


## Park every enemy and shot without reporting them (Level Clear, Run over).
func clear() -> void:
	for enemy: Enemy in _enemies:
		enemy.park()
	_shots.clear()


func _place(
	kind: EnemyKind.Kind,
	at: Vector3,
	heading: Vector3,
	aggression: float,
	speed_scale: float,
	fire_scale: float
) -> Enemy:
	var enemy: Enemy = _parked_enemy()
	if enemy == null:
		enemy = Enemy.new()
		add_child(enemy)
		_enemies.append(enemy)
		var errs: Array[int] = [
			enemy.telegraphed.connect(_on_enemy_telegraphed),
		]
		if errs.count(OK) != errs.size():
			push_error("EnemyField: could not watch an enemy")
	var id: int = _next_id
	_next_id += 1
	enemy.activate(id, kind, at, heading, aggression, speed_scale, fire_scale, _rng)
	_events.enemy.announce_enemy_spawned(id, kind, enemy.position)
	return enemy


func _destroy(enemy: Enemy, cause: DestroyCause.Cause) -> void:
	var at: Vector3 = enemy.position
	enemy.park()
	_events.enemy.announce_enemy_destroyed(enemy.enemy_id, enemy.kind, at, cause)
	enemy_burst.emit(at, enemy.kind, cause)


func _touches(at: Vector3, enemy_radius: float) -> bool:
	return _plane_distance(at, _target.position()) <= enemy_radius + _target.radius()


func _parked_enemy() -> Enemy:
	for enemy: Enemy in _enemies:
		if not enemy.is_active():
			return enemy
	return null


func _on_spawn_requested(order: SpawnOrder) -> void:
	var origin: Vector3 = _target.position() if _target != null else Vector3.ZERO
	var offset: Vector3 = Vector3(cos(order.angle), sin(order.angle), 0.0) * order.distance
	var enemy: Enemy = _place(
		order.kind,
		origin + offset,
		-offset,
		order.aggression,
		order.speed_scale,
		order.fire_rate_scale
	)
	enemy.escort = order.escort


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to
	if not GameState.is_play(to) and to != GameState.Phase.PAUSED:
		clear()


func _on_level_intro_started(
	level_number: int, _level_name: String, _objective: String, _duration: float
) -> void:
	clear()
	if level_number < 1 or level_number > _levels.size():
		_level = null
		return
	_level = _levels[level_number - 1]
	_sphere.radius = _level.play_sphere_radius


func _on_enemy_telegraphed(enemy: Enemy) -> void:
	enemy_telegraphed.emit(enemy.position, enemy.kind)


static func _plane_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length()
