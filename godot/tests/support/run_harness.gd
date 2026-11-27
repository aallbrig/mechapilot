class_name RunHarness
extends RefCounted
## Test support: the core/ rules of a Run wired to a private Events bus, the
## real Level data, and a record of what they announced. Each suite builds one
## per test and calls dispose() at the end (the bus is a Node).

const STEP: float = 1.0 / 60.0

var bus: EventBus = EventBus.new()
var levels: Array[LevelDefinition] = LevelLibrary.all_levels()
var machine: GameStateMachine = GameStateMachine.new(bus)
var ledger: RunLedger = RunLedger.new(bus)
var boss_health: BossHealth = BossHealth.new(bus)
var progression: LevelProgression = LevelProgression.new(bus, machine, ledger, boss_health, levels)
## Every Game State entered, in order.
var states: Array[GameState.Phase] = []
var run_summaries: Array[RunSummary] = []
var tallies: Array[LevelTally] = []
var summoned: Array[StringName] = []
var respawns: int = 0
var _next_enemy_id: int = 1


func _init() -> void:
	var subscribed: Array[int] = [
		bus.flow.game_state_changed.connect(_on_state),
		bus.run.run_ended.connect(_on_run_ended),
		bus.run.level_cleared.connect(_on_level_cleared),
		bus.boss.boss_summoned.connect(_on_boss_summoned),
		bus.player.player_respawned.connect(_on_respawned),
	]
	Subscriptions.require_ok("RunHarness", subscribed)


## Frees the bus. Call once at the end of every test.
func dispose() -> void:
	bus.free()


## Boots, opens the Title and presses Play.
func start_run() -> void:
	machine.boot()
	bus.flow.announce_start_requested()
	bus.flow.announce_play_requested()


## Ticks every rule for `seconds` in fixed steps.
func advance(seconds: float) -> void:
	var left: float = seconds
	while left > 1e-6:
		var step: float = minf(STEP, left)
		ledger.tick(step)
		progression.tick(step)
		left -= step


## Reports a shot kill of `kind` and returns its points (base times combo).
func kill(kind: EnemyKind.Kind) -> int:
	var before: int = ledger.score()
	bus.enemy.announce_enemy_destroyed(_next_enemy_id, kind, Vector3.ZERO, DestroyCause.Cause.SHOT)
	_next_enemy_id += 1
	return ledger.score() - before


## From a fresh harness: start the Run and sit in Level 1's Skirmish.
func reach_skirmish() -> void:
	start_run()
	advance(levels[0].intro_duration + STEP)


## Kills Fighters, spaced out so no combo runs, until the Boss Gauge is full.
func fill_gauge() -> void:
	var guard: int = 0
	while machine.state() == GameState.Phase.SKIRMISH and guard < 1000:
		var _points: int = kill(EnemyKind.Kind.FIGHTER)
		advance(RunRules.COMBO_WINDOW + STEP)
		guard += 1


## From the current Skirmish: fill the gauge and sit through the Boss Warning.
func reach_boss_fight() -> void:
	fill_gauge()
	advance(RunRules.BOSS_WARNING_DURATION + STEP)


## Hits the player with enemy collisions until a life is lost.
func lose_life() -> void:
	var lives: int = ledger.lives()
	var guard: int = 0
	while ledger.lives() == lives and guard < 100:
		bus.player.announce_player_hit(DamageSource.Source.ENEMY_COLLISION, Vector3.ZERO, 0)
		advance(RunRules.HIT_INVULNERABILITY + STEP)
		guard += 1


## Deals the current boss its whole health in one hit.
func defeat_boss() -> void:
	bus.boss.announce_boss_hit(boss_health.health(), Vector3.ZERO)


func _on_state(_from: GameState.Phase, to: GameState.Phase) -> void:
	states.append(to)


func _on_run_ended(summary: RunSummary) -> void:
	run_summaries.append(summary)


func _on_level_cleared(tally: LevelTally) -> void:
	tallies.append(tally)


func _on_boss_summoned(boss_id: StringName, _name: String, _health: int, _phases: int) -> void:
	summoned.append(boss_id)


func _on_respawned() -> void:
	respawns += 1
