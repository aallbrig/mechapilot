class_name RunDirector
extends Node3D
## The fight of a Run, assembled around the player mech (#84): the enemy field,
## the boss arena, the shot referee and the off-screen indicators. main.gd
## hands it the bus, the Levels and the stage's mech, shot pool and camera;
## nothing here knows the screens or the feedback.
##
## Each physics tick it advances, in this order, the enemy field, the boss
## arena and then the referee, which runs every live player shot past the boss
## and the enemies. The field and the arena gate themselves on the Game State
## (EnemyField.advance(), BossArena.advance()); the referee runs in play only.
## The mech is seen through a PlayerTarget, so CombatTarget.strike() is the one
## place a hit becomes `player_hit`.
##
## It also prints the PlayMarkers the web smoke test watches for.
##
## Seams for the other 1.0 parts: field() and arena() carry the juice and sound
## hooks (enemy_burst, enemy_telegraphed, boss_entered, boss_burst), and each
## Enemy and Boss builds its own model, so the visual pass swaps models there.
##
## Listens: flow.game_state_changed (indicators show in play only).

## The off-screen arrows draw above the world and below the screens (UI layer 10).
const INDICATOR_LAYER: int = 5

var _field: EnemyField = EnemyField.new()
var _arena: BossArena = BossArena.new()
var _indicator_layer: CanvasLayer = CanvasLayer.new()
var _indicators: OffscreenIndicators = OffscreenIndicators.new()
var _markers: PlayMarkers = PlayMarkers.new()
var _shots: ShotPool
var _target: PlayerTarget
var _phase: GameState.Phase = GameState.Phase.BOOT


func _init() -> void:
	_field.name = "EnemyField"
	_arena.name = "BossArena"
	_indicator_layer.name = "Indicators"
	_indicator_layer.layer = INDICATOR_LAYER
	_indicators.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# This node drives them, in a fixed order, instead of the engine.
	_field.set_physics_process(false)
	_arena.set_physics_process(false)
	add_child(_field)
	add_child(_arena)
	_indicator_layer.add_child(_indicators)
	add_child(_indicator_layer)
	_markers.name = "PlayMarkers"
	add_child(_markers)
	_show_indicators(false)


## Wire the fight: the bus, its randomness, the Levels, the player `mech`, its
## `shots` and the `camera` the indicators project through. Call once.
func setup(
	events: EventBus,
	rng: RandomNumberGenerator,
	levels: Array[LevelDefinition],
	mech: PlayerMech,
	shots: ShotPool,
	camera: Camera3D
) -> void:
	_shots = shots
	_target = PlayerTarget.new(events, mech)
	_field.setup(events, rng, levels, _target)
	_arena.setup(events, levels, _field)
	_indicators.field = _field
	_indicators.projector = CameraProjector.new(camera)
	_markers.setup(events, mech)
	if events.flow.game_state_changed.connect(_on_game_state_changed) != OK:
		push_error("RunDirector: could not hear game_state_changed")


func _physics_process(delta: float) -> void:
	step(delta)


## Advance the fight `delta` seconds: the field, the arena, then the referee.
func step(delta: float) -> void:
	if _target == null or delta <= 0.0:
		return
	_field.advance(delta)
	_arena.advance(delta)
	if GameState.is_play(_phase):
		var _struck: int = ShotReferee.resolve(_shots, _arena, _field)


func field() -> EnemyField:
	return _field


func arena() -> BossArena:
	return _arena


func indicators() -> OffscreenIndicators:
	return _indicators


## What enemies and bosses fight: the player mech.
func target() -> CombatTarget:
	return _target


func _show_indicators(on: bool) -> void:
	_indicator_layer.visible = on
	_indicators.visible = on
	_indicators.set_process(on)


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to
	_show_indicators(GameState.is_play(to))
