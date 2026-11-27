class_name Pace
extends RefCounted
## The global pace of play. Speeds scale by GAME_SPEED and accelerations by its
## square, so the player, enemies and bullets all slow down together (#22, #73).

const GAME_SPEED: float = 0.75
