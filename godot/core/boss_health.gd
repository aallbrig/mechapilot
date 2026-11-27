class_name BossHealth
extends RefCounted
## The current boss's health pool and phases (#73, #74). LevelProgression arms
## it when the boss is summoned and disarms it when the Level ends or the Run
## is abandoned. Losing a life never touches it, so the boss keeps its damage.
##
## Listens: boss.boss_hit (ignored unless armed).
## Announces: boss.boss_damaged on every hit, boss.boss_phase_changed for each
## phase threshold crossed (in order, even several in one hit), and
## boss.boss_defeated exactly once, when health reaches 0.

var _events: EventBus
var _boss: BossDefinition = null
var _health: int = 0
var _phase: int = 0
var _armed: bool = false


func _init(events: EventBus) -> void:
	_events = events
	var subscribed: Array[int] = [_events.boss.boss_hit.connect(_on_boss_hit)]
	Subscriptions.require_ok("BossHealth", subscribed)


## Starts tracking `boss` at full health in its first phase.
func arm(boss: BossDefinition) -> void:
	_boss = boss
	_health = boss.health
	_phase = 0
	_armed = true


## Stops reacting to hits (Level over or Run abandoned).
func disarm() -> void:
	_armed = false


func is_armed() -> bool:
	return _armed


func health() -> int:
	return _health


## The current phase, 0-based.
func phase() -> int:
	return _phase


func _on_boss_hit(damage: int, position: Vector3) -> void:
	if not _armed or damage <= 0:
		return
	_health = maxi(_health - damage, 0)
	_events.boss.announce_boss_damaged(_health, _boss.health)
	var target: int = _boss.phase_for(_health)
	while _phase < target:
		_phase += 1
		_events.boss.announce_boss_phase_changed(_phase, _boss.phases.size())
	if _health == 0:
		_armed = false
		_events.boss.announce_boss_defeated(_boss.id, position)
