class_name Enemy
extends Node3D
## One enemy in play: it flies by its kind's behaviour (EnemySteering), takes
## hits from player shots, and attacks on its AttackCycle, so every shot is
## telegraphed by its look's charge glow first. It knows nothing of the bus:
## EnemyField spawns it, steps it, resolves its contacts and reports its facts.
## Pooled: activate() puts it in play, park() takes it out.

## The attack charge glow started (juice and SFX hook).
signal telegraphed(enemy: Enemy)
## A shot (or volley, or bomb) left the muzzle.
signal fired(enemy: Enemy)

## Seconds the white hit flash shows.
const FLASH_TIME: float = 0.07
## Shot hits push the enemy along the shot (units/s), as in the prototype.
const HIT_PUSH: float = 6.0 * Pace.GAME_SPEED
## The muzzle sits this far ahead of the centre, in units of the contact radius.
const MUZZLE_REACH: float = 1.1
## Share of the shooter's velocity a projectile inherits.
const SHOT_INHERIT: float = 0.3
## A bomber's bombs leave below its belly (units of contact radius).
const BOMB_DROP: float = 0.8
## Seconds before a fresh enemy's first telegraph, as a share of its interval.
const FIRST_SHOT_SHARE: float = 0.5
## Sizes for the grow-in from SPAWN_GROW_TIME.
const SPAWN_SCALE: float = 0.01

var enemy_id: int = 0
var kind: EnemyKind.Kind = EnemyKind.Kind.FIGHTER
var profile: EnemyProfile = EnemyProfile.of(EnemyKind.Kind.FIGHTER)
var velocity: Vector3 = Vector3.ZERO
var hit_points: int = 0
var aggression: float = 0.0
var speed: float = 0.0
var escort: bool = false

var _look: EnemyLook
var _cycle: AttackCycle
var _age: float = 0.0
var _side: float = 1.0
var _flash_left: float = 0.0
var _active: bool = false


## Put this enemy in play as `enemy_kind` at `at`, heading along `heading`.
## `speed_scale` and `fire_rate_scale` are the Level's difficulty; `rng`
## picks its cruise speed within the profile's range.
func activate(
	id: int,
	enemy_kind: EnemyKind.Kind,
	at: Vector3,
	heading: Vector3,
	order_aggression: float,
	speed_scale: float,
	fire_rate_scale: float,
	rng: RandomNumberGenerator
) -> void:
	enemy_id = id
	profile = EnemyProfile.of(enemy_kind)
	if kind != enemy_kind or _look == null:
		_replace_look(enemy_kind)
	kind = enemy_kind
	aggression = clampf(order_aggression, 0.0, 1.0)
	hit_points = profile.hit_points
	speed = (
		rng.randf_range(profile.speed_min, profile.speed_max)
		* speed_scale
		* (1.0 + aggression * EnemyProfile.AGGRESSION_SPEED_GAIN)
	)
	if profile.behaviour == EnemyProfile.Behaviour.HOMING:
		speed = profile.speed_max * speed_scale
	position = Vector3(at.x, at.y, 0.0)
	var dir: Vector3 = Vector3(heading.x, heading.y, 0.0).normalized()
	velocity = dir * speed
	if profile.behaviour == EnemyProfile.Behaviour.HOMING:
		velocity = dir * profile.speed_min
	if profile.behaviour == EnemyProfile.Behaviour.CROSS:
		velocity = Vector3(signf(dir.x) if dir.x != 0.0 else 1.0, 0.0, 0.0) * speed
	_side = -1.0 if dir.x > 0.0 else 1.0
	_age = 0.0
	_flash_left = 0.0
	escort = false
	var interval: float = (
		profile.fire_interval
		/ maxf(fire_rate_scale, LevelDefinition.MIN_SCALE)
		/ (1.0 + aggression * EnemyProfile.AGGRESSION_FIRE_GAIN)
	)
	_cycle = AttackCycle.new(interval, RunRules.MIN_TELEGRAPH, interval * FIRST_SHOT_SHARE)
	_look.set_flash(false)
	_look.set_charge(0.0)
	_look.scale = Vector3.ONE * profile.look_scale * SPAWN_SCALE
	visible = true
	_active = true


## Out of play: hidden and inert until the field reuses it.
func park() -> void:
	_active = false
	visible = false
	velocity = Vector3.ZERO


func is_active() -> bool:
	return _active


## Seconds since it entered play.
func age() -> float:
	return _age


## Its contact radius (units).
func radius() -> float:
	return profile.radius


## True while the attack charge glow shows.
func is_telegraphing() -> bool:
	return _cycle != null and _cycle.is_telegraphing()


func look() -> EnemyLook:
	return _look


## Where its shots leave: ahead of it along its heading (or toward `aim`).
func muzzle(aim: Vector3) -> Vector3:
	return position + aim.normalized() * profile.radius * MUZZLE_REACH


## Fly and attack for `delta` seconds against `target`, firing into `shots`
## with the Level's `bullet_scale`.
func step(delta: float, target: CombatTarget, shots: EnemyShotPool, bullet_scale: float) -> void:
	if not _active or delta <= 0.0:
		return
	_age += delta
	var target_at: Vector3 = target.position()
	velocity = EnemySteering.steer(
		profile, velocity, position, target_at, speed, _age, _side, delta
	)
	position += velocity * delta
	position.z = 0.0
	_look.face(velocity, delta)
	var grow: float = minf(_age / EnemyProfile.SPAWN_GROW_TIME, 1.0)
	_look.scale = Vector3.ONE * profile.look_scale * maxf(grow, SPAWN_SCALE)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_look.set_flash(false)
	if profile.attack == EnemyProfile.Attack.NONE:
		return
	match _cycle.tick(delta, _may_attack(target, bullet_scale)):
		AttackCycle.Step.TELEGRAPH:
			telegraphed.emit(self)
		AttackCycle.Step.FIRE:
			_fire(target, shots, bullet_scale)
			fired.emit(self)
		_:
			pass
	_look.set_charge(_cycle.charge())


## Take `hits` from a player shot travelling along `direction`. Returns true
## when it destroyed the enemy.
func take_hits(hits: int, direction: Vector3) -> bool:
	if not _active:
		return false
	hit_points -= hits
	if hit_points <= 0:
		return true
	velocity += Vector3(direction.x, direction.y, 0.0).normalized() * HIT_PUSH
	_flash_left = FLASH_TIME
	_look.set_flash(true)
	return false


func _may_attack(target: CombatTarget, bullet_scale: float) -> bool:
	if not target.is_alive() or _age < EnemyProfile.SPAWN_GROW_TIME:
		return false
	var gap: Vector3 = target.position() - position
	gap.z = 0.0
	if profile.attack == EnemyProfile.Attack.BOMB:
		# Bombers release only while a bomb dropped now would land on the player.
		var height: float = -gap.y
		if height <= 0.0:
			return false
		var drop_speed: float = profile.shot.speed * bullet_scale
		var fall: float = (
			(-drop_speed + sqrt(drop_speed * drop_speed + 2.0 * profile.shot.gravity * height))
			/ profile.shot.gravity
		)
		return absf(gap.x - velocity.x * fall) < profile.bomb_window
	return gap.length() <= EnemyProfile.ATTACK_RANGE


func _fire(target: CombatTarget, shots: EnemyShotPool, bullet_scale: float) -> void:
	var spec: ShotSpec = profile.shot
	var target_at: Vector3 = target.position()
	var inherit: Vector3 = velocity * SHOT_INHERIT
	match profile.attack:
		EnemyProfile.Attack.AIMED:
			var dir: Vector3 = FiringSolution.aimed(position, target_at)
			var _shot: EnemyShot = shots.fire(spec, muzzle(dir), dir, bullet_scale, inherit)
		EnemyProfile.Attack.ARC:
			var aim: Vector3 = FiringSolution.aimed(position, target_at)
			var from: Vector3 = muzzle(aim)
			var lob: Vector3 = FiringSolution.arc(
				from, target_at, spec.speed * bullet_scale, spec.gravity
			)
			var _shell: EnemyShot = shots.fire(spec, from, lob, bullet_scale, Vector3.ZERO)
		EnemyProfile.Attack.BOMB:
			var drop: Vector3 = position + Vector3.DOWN * profile.radius * BOMB_DROP
			var _bomb: EnemyShot = shots.fire(
				spec, drop, Vector3.DOWN, bullet_scale, Vector3(velocity.x, 0.0, 0.0)
			)
		EnemyProfile.Attack.SPREAD:
			var centre: Vector3 = FiringSolution.aimed(position, target_at)
			for dir: Vector3 in FiringSolution.fan(centre, profile.volley, profile.volley_spread):
				var _bullet: EnemyShot = shots.fire(spec, muzzle(dir), dir, bullet_scale, inherit)
		EnemyProfile.Attack.NONE:
			pass


func _replace_look(enemy_kind: EnemyKind.Kind) -> void:
	if _look != null:
		_look.free()
	_look = EnemyLook.new(enemy_kind, EnemyProfile.of(enemy_kind).look_scale)
	add_child(_look)
