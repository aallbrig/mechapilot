class_name DamageSource
extends RefCounted
## What hit the player mech. core/run_rules.gd maps each source to its Armor
## damage (#73, "Health and lives").

enum Source { ENEMY_COLLISION, ENEMY_BULLET, BOMB, MISSILE, BOSS_ATTACK }
