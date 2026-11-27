class_name MechTuning
extends Resource
## Every tunable number for the player mech's flight, weapon and damage response.
## The defaults are the LAN prototype's feel (branch prototype/lan-feel) at
## Pace.GAME_SPEED: speeds scale by the pace and accelerations by its square.

@export_group("Flight")
## Top speed under full thrust (units/s).
@export var speed: float = 11.0 * Pace.GAME_SPEED
## How fast thrust pulls the velocity toward the stick (1/s).
@export var thrust_response: float = 10.0
## Move-input magnitude below which the mech coasts.
@export var thrust_deadzone: float = 0.15
## Downward pull while coasting (units/s^2). Gentle: the mech drifts down.
@export var coast_gravity: float = 7.0
## Fastest the mech falls while coasting (units/s).
@export var coast_terminal_fall: float = 6.0
## Horizontal drag while coasting (1/s).
@export var coast_drag: float = 0.25
## Velocity at spawn: drifting forward, so the scene never starts frozen.
@export var spawn_velocity: Vector3 = Vector3(5.0 * Pace.GAME_SPEED, 0.0, 0.0)
## Horizontal speed above which the mech turns to face its travel (units/s).
@export var facing_speed: float = 2.0
## Seconds after the last shot before travel may turn the mech again.
@export var facing_fire_hold: float = 0.4
## Horizontal aim component above which aiming turns the mech.
@export var facing_aim: float = 0.2

@export_group("Weapon")
## Seconds between shots while fire is held.
@export var fire_interval: float = 0.1
## Muzzle speed of a shot (units/s).
@export var shot_speed: float = 46.0 * Pace.GAME_SPEED
## Seconds a shot lives.
@export var shot_life: float = 1.4 / Pace.GAME_SPEED
## Downward pull on shots (units/s^2), so they arc.
@export var shot_gravity: float = 20.0 * Pace.GAME_SPEED * Pace.GAME_SPEED
## Share of the mech's velocity a shot inherits.
@export var shot_inherit: float = 0.6
## Random spread either side of the aim (radians).
@export var shot_spread: float = 0.04
## Speed the mech loses backward along the aim per shot (units/s).
@export var recoil: float = 1.6 * Pace.GAME_SPEED
## How fast the arm cannon swings to the aim (1/s).
@export var gun_turn_rate: float = 30.0

@export_group("Damage")
## Visual scale of the mech; the contact radius scales with it.
@export var mech_scale: float = 0.85
## Contact radius at scale 1 (units).
@export var hit_radius: float = 0.47
## Invulnerability after a hit (s): the RunLedger's window (#73), mirrored for the blink.
@export var hit_invulnerability: float = RunRules.HIT_INVULNERABILITY
## Invulnerability after a respawn (s), from #73.
@export var respawn_invulnerability: float = RunRules.RESPAWN_INVULNERABILITY
## Blink frequency while invulnerable (Hz), and the hidden share of each blink.
@export var blink_rate: float = 10.0
@export var blink_hidden_share: float = 0.35
## Speed a hit adds along its direction (units/s).
@export var knockback: float = 8.0 * Pace.GAME_SPEED
## Seconds the hit flash lasts.
@export var hit_flash_time: float = 0.08


## The contact radius at the mech's visual scale.
func contact_radius() -> float:
	return hit_radius * mech_scale
