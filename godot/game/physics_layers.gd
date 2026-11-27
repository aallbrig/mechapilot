class_name PhysicsLayers
extends RefCounted
## Collision layer bits for 3D physics, named in project.godot [layer_names].
## Shots and pickups are Areas: each sits on its own layer and masks what it hits.

const PLAYER: int = 1 << 0
const PLAYER_SHOTS: int = 1 << 1
const ENEMIES: int = 1 << 2
const ENEMY_SHOTS: int = 1 << 3
const PICKUPS: int = 1 << 4
