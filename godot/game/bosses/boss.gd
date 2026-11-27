class_name Boss
extends Node3D
## The Level's boss in play. Its health and phases are the rules' (BossHealth):
## the boss only reports shot hits as `boss_hit`, switches its attacks when
## told its phase changed, and plays its sequences.
##
##   Entering  it flies in from off screen to its station; shots glance off.
##   Fighting  it holds station on the player (weaving), and runs every attack
##             of its phase on its own AttackCycle, so each is telegraphed by
##             the turret glow first (at least RunRules.MIN_TELEGRAPH).
##   Defeated  no attacks; it falls, flashing, in a chain of explosions.
##   Gone      the sequence is over; BossArena frees it.
##
## Touching it hurts: its body counts as an enemy collision, and a dash or a
## lance charge as that attack's boss damage.

## The entry finished: the fight starts (the health bar is full).
signal entered(boss: Boss)
## An attack's telegraph started, and it fired (juice and SFX hooks).
signal telegraphed(attack_id: StringName)
signal fired(attack_id: StringName)
## One explosion of the defeat chain, the `index`-th.
signal defeat_burst(position: Vector3, index: int)
## The defeat sequence ended.
signal gone(boss: Boss)

enum State { ENTERING, FIGHTING, DEFEATED, GONE }

## Seconds the white hit flash shows.
const FLASH_TIME: float = 0.05
## Seconds before the first attack of a phase, and the stagger between attacks.
const FIRST_ATTACK_DELAY: float = 0.8
const ATTACK_STAGGER: float = 0.6
## Launched drones fly at full aggression.
const LAUNCH_AGGRESSION: float = 1.0
## Launched drones leave fanned over this angle (radians).
const LAUNCH_FAN: float = 1.2
## The vertical weave runs this much faster than the horizontal one, so the
## path never repeats into a simple loop.
const WEAVE_Y_RATIO: float = 1.7
## The defeat explosions walk over the hull: offsets per burst, in hull sizes.
const BURST_WALK: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(-0.35, 0.2),
	Vector2(0.3, -0.25),
	Vector2(-0.15, -0.3),
	Vector2(0.4, 0.3),
	Vector2(-0.45, -0.1),
	Vector2(0.15, 0.35),
	Vector2(0.0, 0.0),
]

var definition: BossDefinition
var profile: BossProfile

var _events: EventBus
var _look: BossLook
var _state: State = State.ENTERING
var _phase: int = 0
var _attacks: Array[BossDefinition.Attack] = []
var _patterns: Array[BossPattern] = []
var _specs: Array[ShotSpec] = []
var _cycles: Array[AttackCycle] = []
var _shot_damage: int = 0
var _clock: float = 0.0
var _entry_left: float = 0.0
var _dash_left: float = 0.0
var _dash_velocity: Vector3 = Vector3.ZERO
var _dash_damage: int = 0
var _fall: Vector3 = Vector3.ZERO
var _defeat_left: float = 0.0
var _burst_left: float = 0.0
var _bursts: int = 0
var _flash_left: float = 0.0


## Bring `boss_definition`'s boss in for a player at `player_at`. Each player
## shot that lands deals `shot_damage`.
func begin(
	events: EventBus, boss_definition: BossDefinition, player_at: Vector3, shot_damage: int
) -> void:
	_events = events
	definition = boss_definition
	profile = BossProfile.of(boss_definition.id)
	_shot_damage = shot_damage
	_look = BossLook.new(profile)
	add_child(_look)
	_state = State.ENTERING
	_entry_left = BossProfile.ENTRY_TIME
	position = _station(player_at) + BossProfile.ENTRY_OFFSET
	enter_phase(0)


func state() -> State:
	return _state


## The current phase, 0-based.
func phase() -> int:
	return _phase


## The attack ids of the current phase.
func attack_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for attack: BossDefinition.Attack in _attacks:
		out.append(attack.id)
	return out


func is_dashing() -> bool:
	return _dash_left > 0.0


## True while any attack's telegraph shows.
func is_telegraphing() -> bool:
	for cycle: AttackCycle in _cycles:
		if cycle.is_telegraphing():
			return true
	return false


func look() -> BossLook:
	return _look


## Switch to `phase_index`'s attacks (BossHealth announced the change).
func enter_phase(phase_index: int) -> void:
	_phase = clampi(phase_index, 0, definition.phases.size() - 1)
	_attacks = definition.phases[_phase].attacks.duplicate()
	_patterns.clear()
	_specs.clear()
	_cycles.clear()
	for i: int in _attacks.size():
		var attack: BossDefinition.Attack = _attacks[i]
		var pattern: BossPattern = BossPattern.of(attack.id)
		_patterns.append(pattern)
		_specs.append(pattern.shot.as_boss_attack(attack.damage) if pattern.shot != null else null)
		_cycles.append(
			AttackCycle.new(
				attack.interval, attack.telegraph, FIRST_ATTACK_DELAY + i * ATTACK_STAGGER
			)
		)
	_look.set_phase(_phase)


## Start the defeat sequence (BossHealth announced the defeat).
func begin_defeat() -> void:
	if _state == State.DEFEATED or _state == State.GONE:
		return
	_state = State.DEFEATED
	_defeat_left = BossProfile.DEFEAT_TIME
	_burst_left = 0.0
	_bursts = 0
	_dash_left = 0.0
	_fall = Vector3.ZERO
	_look.set_charge(0.0)


## A player shot of `shot_radius` at `at`. Returns true when it struck the
## boss (the caller spends it): while fighting it reports `boss_hit`; while
## entering it glances off. A defeated boss lets shots through.
func resolve_shot(at: Vector3, shot_radius: float) -> bool:
	if _state == State.DEFEATED or _state == State.GONE:
		return false
	if Vector2(at.x - position.x, at.y - position.y).length() > profile.hit_radius + shot_radius:
		return false
	if _state == State.FIGHTING:
		_events.boss.announce_boss_hit(_shot_damage, Vector3(at.x, at.y, 0.0))
		_flash_left = FLASH_TIME
		_look.set_flash(true)
	return true


## Advance `delta` seconds against `target`, firing into `shots` at the
## Level's `bullet_scale`, launching drones into `field`.
func step(
	delta: float, target: CombatTarget, shots: EnemyShotPool, field: EnemyField, bullet_scale: float
) -> void:
	if delta <= 0.0 or _state == State.GONE:
		return
	_clock += delta
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_look.set_flash(false)
	match _state:
		State.ENTERING:
			_step_entry(delta, target)
		State.FIGHTING:
			_step_fight(delta, target, shots, field, bullet_scale)
		State.DEFEATED:
			_step_defeat(delta)
		State.GONE:
			pass


func _step_entry(delta: float, target: CombatTarget) -> void:
	_entry_left = maxf(_entry_left - delta, 0.0)
	var t: float = 1.0 - _entry_left / BossProfile.ENTRY_TIME
	position = (
		_station(target.position()) + BossProfile.ENTRY_OFFSET * (1.0 - smoothstep(0.0, 1.0, t))
	)
	if _entry_left <= 0.0:
		_state = State.FIGHTING
		entered.emit(self)


func _step_fight(
	delta: float, target: CombatTarget, shots: EnemyShotPool, field: EnemyField, bullet_scale: float
) -> void:
	if is_dashing():
		_dash_left -= delta
		position += _dash_velocity * delta
	else:
		var want: Vector3 = _station(target.position())
		position = position.lerp(want, 1.0 - exp(-profile.follow * delta))
	position.z = 0.0
	var alive: bool = target.is_alive()
	if (
		alive
		and _plane_distance(position, target.position()) <= profile.hit_radius + target.radius()
	):
		var into: Vector3 = FiringSolution.aimed(position, target.position())
		if is_dashing():
			var _lanced: bool = target.strike(DamageSource.Source.BOSS_ATTACK, _dash_damage, into)
		else:
			var _rammed: bool = target.strike(DamageSource.Source.ENEMY_COLLISION, 0, into)
	var charge: float = 0.0
	for i: int in _cycles.size():
		match _cycles[i].tick(delta, alive and not is_dashing()):
			AttackCycle.Step.TELEGRAPH:
				telegraphed.emit(_attacks[i].id)
			AttackCycle.Step.FIRE:
				_fire(i, target, shots, field, bullet_scale)
				fired.emit(_attacks[i].id)
			_:
				pass
		charge = maxf(charge, _cycles[i].charge())
	_look.set_charge(charge)


func _step_defeat(delta: float) -> void:
	_defeat_left -= delta
	_burst_left -= delta
	_fall = Ballistics.fall(_fall, BossProfile.DEFEAT_FALL, delta)
	position += _fall * delta
	_look.set_flash(fposmod(_defeat_left, BossProfile.DEFEAT_BURST_GAP) < FLASH_TIME)
	if _burst_left <= 0.0:
		_burst_left += BossProfile.DEFEAT_BURST_GAP
		var walk: Vector2 = BURST_WALK[_bursts % BURST_WALK.size()]
		var at: Vector3 = position + Vector3(walk.x * profile.size.x, walk.y * profile.size.y, 0.0)
		defeat_burst.emit(at, _bursts)
		_bursts += 1
	if _defeat_left <= 0.0:
		_state = State.GONE
		visible = false
		gone.emit(self)


func _fire(
	index: int, target: CombatTarget, shots: EnemyShotPool, field: EnemyField, bullet_scale: float
) -> void:
	var pattern: BossPattern = _patterns[index]
	var spec: ShotSpec = _specs[index]
	var player: Vector3 = target.position()
	match pattern.kind:
		BossPattern.Kind.VOLLEY:
			for muzzle: Vector3 in _muzzles():
				var centre: Vector3 = FiringSolution.aimed(muzzle, player)
				if pattern.lobbed:
					centre = FiringSolution.arc(
						muzzle, player, spec.speed * bullet_scale, spec.gravity
					)
				for dir: Vector3 in FiringSolution.fan(centre, pattern.count, pattern.spread):
					var _shot: EnemyShot = shots.fire(spec, muzzle, dir, bullet_scale, Vector3.ZERO)
		BossPattern.Kind.CARPET:
			for i: int in pattern.count:
				var along: float = (float(i) / maxf(pattern.count - 1, 1) - 0.5) * pattern.spread
				var from: Vector3 = position + Vector3(along, -profile.size.y * 0.5, 0.0)
				var _bomb: EnemyShot = shots.fire(
					spec, from, Vector3.DOWN, bullet_scale, Vector3.ZERO
				)
		BossPattern.Kind.RING:
			for dir: Vector3 in FiringSolution.ring(pattern.count, _clock):
				var _ring_shot: EnemyShot = shots.fire(
					spec, position, dir, bullet_scale, Vector3.ZERO
				)
		BossPattern.Kind.CURTAIN:
			for i: int in pattern.count:
				var across: float = (float(i) / maxf(pattern.count - 1, 1) - 0.5) * pattern.spread
				var drop: Vector3 = player + Vector3(across, BossPattern.CURTAIN_HEIGHT, 0.0)
				var _drop: EnemyShot = shots.fire(
					spec, drop, Vector3.DOWN, bullet_scale, Vector3.ZERO
				)
		BossPattern.Kind.DASH:
			_dash_velocity = FiringSolution.aimed(position, player) * pattern.speed
			_dash_left = pattern.duration
			_dash_damage = _attacks[index].damage
		BossPattern.Kind.LAUNCH:
			var bays: Array[Vector3] = _muzzles()
			var centre: Vector3 = FiringSolution.aimed(position, player)
			var dirs: Array[Vector3] = FiringSolution.fan(centre, pattern.count, LAUNCH_FAN)
			for i: int in dirs.size():
				var bay: Vector3 = bays[i % bays.size()]
				var _drone: Enemy = field.launch(
					EnemyKind.Kind.DRONE, bay, dirs[i], LAUNCH_AGGRESSION
				)


## Where the turrets are now, in the play plane.
func _muzzles() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for turret: Vector3 in profile.turrets:
		out.append(position + turret)
	if out.is_empty():
		out.append(position)
	return out


func _station(player_at: Vector3) -> Vector3:
	var weave: Vector3 = Vector3(
		sin(_clock * profile.weave_rate) * profile.weave.x,
		sin(_clock * profile.weave_rate * WEAVE_Y_RATIO) * profile.weave.y,
		0.0
	)
	return Vector3(player_at.x, player_at.y, 0.0) + profile.station + weave


static func _plane_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length()
