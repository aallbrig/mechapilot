class_name ExplosionPool
extends Node3D
## Every explosion in the sky, from a fixed pool (#9's fix: explosions are
## pooled and released). Enemy kills blast in their kind's colour and size, the
## player's death blasts big, and a boss kill sets off a chain of blasts around
## the boss before the last, biggest one (the defeat sequence). When the pool
## is spent, the oldest blast is reused. `detonated` reports each blast so the
## SFX play in step with it, chains included.

## A blast went off at `at`, `blast_size` times the base size.
signal detonated(at: Vector3, blast_size: float)

const CAPACITY: int = 16
## Blast size and colour per EnemyKind.Kind (FIGHTER, HEAVY, INTERCEPTOR,
## DRONE, BOMBER, ENEMY_MECH).
const KIND_SIZE: Array[float] = [1.0, 1.5, 0.9, 0.7, 1.8, 1.4]
const KIND_COLOR: Array[Color] = [
	Color(1.0, 0.55, 0.15),
	Color(1.0, 0.4, 0.1),
	Color(0.5, 0.75, 1.0),
	Color(0.85, 0.45, 1.0),
	Color(1.0, 0.75, 0.2),
	Color(1.0, 0.3, 0.25),
]
const PLAYER_SIZE: float = 2.2
const PLAYER_COLOR: Color = Color(1.0, 0.85, 0.5)
## The boss defeat chain: how many blasts, over how long (s), how far from the
## boss they scatter (units), their size, then the final blast's size.
const CHAIN_COUNT: int = 7
const CHAIN_SECONDS: float = 1.4
const CHAIN_SPREAD: float = 4.0
const CHAIN_SIZE: float = 1.3
const FINAL_SIZE: float = 3.2
const BOSS_COLOR: Color = Color(1.0, 0.6, 0.2)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _idle: Array[Explosion] = []
var _active: Array[Explosion] = []
var _pending: Array[PendingBlast] = []
var _flashes: bool = true


class PendingBlast:
	extends RefCounted
	var delay: float
	var at: Vector3
	var blast_size: float
	var color: Color


func _init() -> void:
	for _i: int in CAPACITY:
		var blast: Explosion = Explosion.new()
		add_child(blast)
		var err: int = blast.finished.connect(_on_finished)
		BusLinks.require_ok("ExplosionPool", [err])
		_idle.append(blast)


func _process(delta: float) -> void:
	advance(delta)


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	(
		BusLinks
		. require_ok(
			"ExplosionPool",
			[
				bus.enemy.enemy_destroyed.connect(_on_enemy_destroyed),
				bus.player.player_destroyed.connect(_on_player_destroyed),
				bus.boss.boss_defeated.connect(_on_boss_defeated),
				bus.profile.settings_changed.connect(_on_settings_changed),
			]
		)
	)


## Set off a blast now, reusing the oldest one if the pool is spent.
func spawn(at: Vector3, blast_size: float, color: Color) -> Explosion:
	var blast: Explosion
	if _idle.is_empty():
		blast = _active.pop_front()
	else:
		blast = _idle.pop_back()
	_active.append(blast)
	blast.play(at, blast_size, color, _flashes)
	detonated.emit(at, blast_size)
	return blast


## Set off `count` blasts scattered around `center` over `seconds`, then a
## final blast of `final_size` at the centre.
func chain(center: Vector3, count: int, seconds: float, final_size: float) -> void:
	for i: int in count:
		var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf() * CHAIN_SPREAD
		_queue(
			seconds * float(i) / float(count), center + Vector3(offset.x, offset.y, 0.0), CHAIN_SIZE
		)
	_queue(seconds, center, final_size)


## Run every blast and every queued chain blast on by `delta` seconds.
func advance(delta: float) -> void:
	var due: Array[PendingBlast] = []
	for pending: PendingBlast in _pending:
		pending.delay -= delta
		if pending.delay <= 0.0:
			due.append(pending)
	for pending: PendingBlast in due:
		_pending.erase(pending)
		var _blast: Explosion = spawn(pending.at, pending.blast_size, pending.color)
	for blast: Explosion in _active.duplicate():
		blast.advance(delta)


func active_count() -> int:
	return _active.size()


func idle_count() -> int:
	return _idle.size()


func pending_count() -> int:
	return _pending.size()


## Every blast the pool owns, active or idle.
func blasts() -> Array[Explosion]:
	var all: Array[Explosion] = []
	all.append_array(_active)
	all.append_array(_idle)
	return all


func _queue(delay: float, at: Vector3, blast_size: float) -> void:
	var pending: PendingBlast = PendingBlast.new()
	pending.delay = delay
	pending.at = at
	pending.blast_size = blast_size
	pending.color = BOSS_COLOR
	if delay <= 0.0:
		var _blast: Explosion = spawn(at, blast_size, BOSS_COLOR)
	else:
		_pending.append(pending)


func _on_finished(blast: Explosion) -> void:
	_active.erase(blast)
	if not _idle.has(blast):
		_idle.append(blast)


func _on_enemy_destroyed(
	_enemy_id: int, kind: EnemyKind.Kind, at: Vector3, _cause: DestroyCause.Cause
) -> void:
	var _blast: Explosion = spawn(at, KIND_SIZE[kind], KIND_COLOR[kind])


func _on_player_destroyed(at: Vector3, _cause: DestroyCause.Cause) -> void:
	var _blast: Explosion = spawn(at, PLAYER_SIZE, PLAYER_COLOR)


func _on_boss_defeated(_boss_id: StringName, at: Vector3) -> void:
	chain(at, CHAIN_COUNT, CHAIN_SECONDS, FINAL_SIZE)


func _on_settings_changed(settings: GameSettings) -> void:
	_flashes = JuiceSettings.flashes(settings)
