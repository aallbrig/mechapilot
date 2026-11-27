class_name FightHarness
extends RefCounted
## Test support: the assembled fight on a private Events bus. The real core/
## rules of a Run (RunHarness), the real player mech linked to that bus
## (PlayerBusLink), its shot pool, a camera, and the RunDirector that wires the
## enemy field, the boss arena, the shot referee and the off-screen indicators
## around them. Spawns come from the test (order()), not the spawn director, so
## each test places exactly the enemies it needs.
## The suite adds `world` to its tree and calls dispose() at the end.

const STEP: float = RunHarness.STEP
const SEED: int = 8484

var run: RunHarness = RunHarness.new()
var bus: EventBus = run.bus
var world: Node3D = Node3D.new()
var mech: PlayerMech = PlayerMech.new()
var input: PlayerInput = PlayerInput.new()
var link: PlayerBusLink = PlayerBusLink.new()
var shots: ShotPool = ShotPool.new()
var camera: Camera3D = Camera3D.new()
var director: RunDirector = RunDirector.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Every player_hit announced, by source, in order.
var player_hits: Array[DamageSource.Source] = []
## enemy_destroyed: id -> cause.
var destroyed: Dictionary[int, DestroyCause.Cause] = {}
var spawn_ids: Array[int] = []


func _init() -> void:
	rng.seed = SEED
	mech.tuning.shot_spread = 0.0
	mech.shots = shots
	camera.position = Vector3(0.0, 0.0, CameraRig.DISTANCE)
	for node: Node in [input, shots, mech, link, camera, director]:
		world.add_child(node)
	link.link(bus, mech, input)
	director.setup(bus, rng, run.levels, mech, shots, camera)
	var subscribed: Array[int] = [
		bus.player.player_hit.connect(_on_player_hit),
		bus.enemy.enemy_destroyed.connect(_on_destroyed),
		bus.enemy.enemy_spawned.connect(_on_spawned),
	]
	Subscriptions.require_ok("FightHarness", subscribed)


## Frees the nodes and the bus. Call once at the end of every test.
func dispose() -> void:
	world.free()
	run.dispose()


## From a fresh harness: start the Run and sit in Level 1's Skirmish.
func reach_skirmish() -> void:
	run.reach_skirmish()


## Asks the field for one enemy of `kind` at `angle` and `distance` from the
## player, as the spawn director would, and returns it.
func order(kind: EnemyKind.Kind, angle: float, distance: float) -> Enemy:
	var before: int = spawn_ids.size()
	bus.enemy.announce_spawn_requested(SpawnOrder.new(kind, angle, distance, 0.0, 1.0, 1.0, false))
	if spawn_ids.size() != before + 1:
		return null
	return director.field().find_enemy(spawn_ids[-1])


## Ticks the rules, the mech under `intent`, its shots and the fight for
## `seconds` in fixed steps, in the order the game runs them.
func advance(seconds: float, intent: PilotIntent = PilotIntent.new()) -> void:
	var left: float = seconds
	while left > 1e-6:
		var step: float = minf(STEP, left)
		run.ledger.tick(step)
		run.progression.tick(step)
		mech.tick(step, intent)
		shots.step(step)
		director.step(step)
		left -= step


func _on_player_hit(source: DamageSource.Source, _position: Vector3, _attack_damage: int) -> void:
	player_hits.append(source)


func _on_destroyed(
	enemy_id: int, _kind: EnemyKind.Kind, _position: Vector3, cause: DestroyCause.Cause
) -> void:
	destroyed[enemy_id] = cause


func _on_spawned(enemy_id: int, _kind: EnemyKind.Kind, _position: Vector3) -> void:
	spawn_ids.append(enemy_id)
