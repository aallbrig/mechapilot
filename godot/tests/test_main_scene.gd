extends GdUnitTestSuite
## The assembled game in main.tscn (#84): the attract and flight cameras hand
## off with the Game State, the fight is wired to the stage's mech, and the
## rules' Repair Kit drops land in the sky. Driven through the Events autoload,
## as the screens drive it.

var _main: Node


func before_test() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(_main)


func after_test() -> void:
	_main.free()


func _stage() -> FlightStage:
	return _main.get_node("FlightStage") as FlightStage


func _run() -> RunDirector:
	return _main.get_node("Run") as RunDirector


## The attract mode's own camera (the Title's dogfight builds it).
func _attract_camera() -> Camera3D:
	for child: Node in _main.get_node("Attract").get_children():
		if child is Camera3D:
			return child as Camera3D
	return null


## True when `camera` is the one camera of the two that is current.
func _only_current(camera: Camera3D, other: Camera3D) -> bool:
	return camera.is_current() and not other.is_current()


func test_main_camera_hands_off_between_attract_and_flight() -> void:
	var flight: Camera3D = _stage().camera_rig().camera()
	var attract: Camera3D = _attract_camera()
	var on_boot: bool = _only_current(attract, flight)
	Events.flow.announce_start_requested()
	var on_title: bool = _only_current(attract, flight)
	Events.flow.announce_play_requested()
	var in_play: bool = _only_current(flight, attract)
	Events.flow.announce_pause_requested()
	var paused: bool = _only_current(flight, attract)
	Events.flow.announce_quit_to_title_requested()
	var after_quit: bool = _only_current(attract, flight)
	Events.flow.announce_play_requested()
	var replay: bool = _only_current(flight, attract)
	var _boot: GdUnitAssert = assert_bool(on_boot).is_true()
	var _title: GdUnitAssert = assert_bool(on_title).is_true()
	var _play: GdUnitAssert = assert_bool(in_play).is_true()
	var _pause: GdUnitAssert = assert_bool(paused).is_true()
	var _quit: GdUnitAssert = assert_bool(after_quit).is_true()
	var _again: GdUnitAssert = assert_bool(replay).is_true()


func test_main_fights_the_stage_mech() -> void:
	var player: PlayerMech = _stage().player()
	_stage().player().position = Vector3(3.0, -2.0, 0.0)
	var _target: GdUnitAssert = assert_vector(_run().target().position()).is_equal(
		Vector3(3.0, -2.0, 0.0)
	)
	var _alive: GdUnitAssert = assert_bool(_run().target().is_alive()).is_equal(player.is_alive())
	var _radius: GdUnitAssert = assert_float(_run().target().radius()).is_equal(
		player.contact_radius()
	)


func test_main_drops_repair_kits_in_the_sky() -> void:
	Events.flow.announce_start_requested()
	Events.flow.announce_play_requested()
	Events.player.announce_repair_kit_dropped(Vector3(4.0, 1.0, 0.0))
	var _one_kit: GdUnitAssert = assert_int(_stage().repair_kits().size()).is_equal(1)
