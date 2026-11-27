extends GdUnitTestSuite
## The Title's attract mode (#24): a live dogfight that runs only behind the
## Boot and Title screens, and never reports anything to the rules.

const STEP: float = 1.0 / 60.0
const FLY_SECONDS: float = 12.0

var _reported: int = 0


func _on_reported(_enemy_id: int, _kind: EnemyKind.Kind, _position: Vector3) -> void:
	_reported += 1


func test_attract_dogfight_runs_only_on_title() -> void:
	var listening: bool = Events.enemy.enemy_spawned.connect(_on_reported) == OK
	var attract: AttractDogfight = auto_free(AttractDogfight.new())
	add_child(attract)
	Events.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.TITLE)
	var on_title: bool = attract.is_active()
	var steps: int = roundi(FLY_SECONDS / STEP)
	for i: int in steps:
		attract.step(STEP)
	var kills: int = attract.kills()
	Events.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO)
	var in_play: bool = attract.is_active()
	Events.enemy.enemy_spawned.disconnect(_on_reported)
	var _listening: GdUnitAssert = assert_bool(listening).is_true()
	var _active: GdUnitAssert = assert_bool(on_title).is_true()
	var _fights: GdUnitAssert = assert_int(kills).is_greater(0)
	var _idle: GdUnitAssert = assert_bool(in_play).is_false()
	var _silent: GdUnitAssert = assert_int(_reported).is_equal(0)
