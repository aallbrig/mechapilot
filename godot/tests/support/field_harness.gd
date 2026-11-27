class_name FieldHarness
extends RefCounted
## Test support: an EnemyField on a private Events bus, the real Level data, a
## stand-in player, and a record of every enemy and player event announced.
## The suite adds field() to its tree and calls dispose() at the end.

const STEP: float = 1.0 / 60.0
const SEED: int = 2323

var bus: EventBus = EventBus.new()
var levels: Array[LevelDefinition] = LevelLibrary.all_levels()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var target: StandInTarget = StandInTarget.new(bus)
var field: EnemyField = EnemyField.new()
## enemy_spawned payloads: id -> kind, and the spawn positions in order.
var spawned: Dictionary[int, EnemyKind.Kind] = {}
var spawn_positions: Array[Vector3] = []
var spawn_ids: Array[int] = []
var hits: Array[int] = []
## enemy_destroyed: id -> cause.
var destroyed: Dictionary[int, DestroyCause.Cause] = {}
var left_sphere: Array[int] = []
## player_hit sources, in order.
var player_hits: Array[DamageSource.Source] = []
var repair_drops: int = 0


func _init() -> void:
	rng.seed = SEED
	field.setup(bus, rng, levels, target)
	var subscribed: Array[int] = [
		bus.enemy.enemy_spawned.connect(_on_spawned),
		bus.enemy.enemy_hit.connect(_on_hit),
		bus.enemy.enemy_destroyed.connect(_on_destroyed),
		bus.enemy.enemy_left_play_sphere.connect(_on_left),
		bus.player.player_hit.connect(_on_player_hit),
		bus.player.repair_kit_dropped.connect(_on_repair_drop),
	]
	Subscriptions.require_ok("FieldHarness", subscribed)


## Frees the bus and the field. Call once at the end of every test.
func dispose() -> void:
	field.free()
	bus.free()


## Opens `level_number`'s Skirmish (the field loads the Level on its intro).
func enter_level(level_number: int) -> void:
	var level: LevelDefinition = levels[level_number - 1]
	bus.run.announce_level_intro_started(
		level_number, level.display_name, level.objective, level.intro_duration
	)
	bus.flow.announce_game_state_changed(GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH)


## Asks the field for one enemy of `kind` at `angle` and `distance` from the
## player, as the spawn director would, and returns it.
func order(kind: EnemyKind.Kind, angle: float, distance: float, aggression: float = 0.0) -> Enemy:
	var before: int = spawn_positions.size()
	bus.enemy.announce_spawn_requested(
		SpawnOrder.new(kind, angle, distance, aggression, 1.0, 1.0, false)
	)
	if spawn_positions.size() != before + 1:
		return null
	return field.find_enemy(spawn_ids[-1])


## Steps the field for `seconds` in fixed ticks.
func advance(seconds: float) -> void:
	var left: float = seconds
	while left > 1e-6:
		field.step(minf(STEP, left))
		left -= STEP


func _on_spawned(enemy_id: int, kind: EnemyKind.Kind, position: Vector3) -> void:
	spawned[enemy_id] = kind
	spawn_ids.append(enemy_id)
	spawn_positions.append(position)


func _on_hit(enemy_id: int, _position: Vector3) -> void:
	hits.append(enemy_id)


func _on_destroyed(
	enemy_id: int, _kind: EnemyKind.Kind, _position: Vector3, cause: DestroyCause.Cause
) -> void:
	destroyed[enemy_id] = cause


func _on_left(enemy_id: int) -> void:
	left_sphere.append(enemy_id)


func _on_player_hit(source: DamageSource.Source, _position: Vector3, _attack_damage: int) -> void:
	player_hits.append(source)


func _on_repair_drop(_position: Vector3) -> void:
	repair_drops += 1
