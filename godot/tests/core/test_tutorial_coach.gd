extends GdUnitTestSuite
## The first-flight tutorial rules (#75): prompts show once each in Level 1 of
## the first Run, dismiss themselves when their condition is met, persist, and
## can be turned off.

var _bus: EventBus
var _store: MemoryDocumentStore
var _progress: TutorialProgress
var _coach: TutorialCoach
var _shown: Array[TutorialPrompt.Id] = []
var _dismissed: Array[Array] = []


func before_test() -> void:
	_bus = EventBus.new()
	_store = MemoryDocumentStore.new()
	var subscribed: Array[int] = [
		_bus.run.tutorial_prompt_shown.connect(_on_shown),
		_bus.run.tutorial_prompt_dismissed.connect(_on_dismissed),
	]
	var _ok: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(subscribed.size())
	_new_coach()


func after_test() -> void:
	_bus.free()


func _new_coach() -> void:
	_shown.clear()
	_dismissed.clear()
	_progress = TutorialProgress.new(_store)
	_progress.restore()
	_coach = TutorialCoach.new(_bus, _progress)


func _on_shown(prompt: TutorialPrompt.Id) -> void:
	_shown.append(prompt)


func _on_dismissed(prompt: TutorialPrompt.Id, completed: bool) -> void:
	_dismissed.append([prompt, completed])


## Starts a Run and reaches Level `level`'s Skirmish.
func _fly(level: int = 1) -> void:
	_bus.run.announce_run_started(1)
	_bus.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO)
	_bus.flow.announce_game_state_changed(GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH)
	_bus.run.announce_level_intro_completed(level)


func _fire(times: int) -> void:
	for i: int in times:
		_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)


func test_tutorial_prompt_dismisses_on_condition() -> void:
	_fly()
	var first: int = _coach.current()
	_bus.player.announce_player_moved()
	var after_move: int = _coach.current()
	_fire(2)
	var after_two: int = _coach.current()
	_fire(1)
	_bus.player.announce_shot_missed(Vector3.ZERO)
	var after_miss: int = _coach.current()
	_bus.enemy.announce_enemy_hit(1, Vector3.ZERO)
	_bus.run.announce_boss_gauge_changed(1000, 4000)
	var at_quarter: int = _coach.current()
	_bus.player.announce_repair_kit_dropped(Vector3.ZERO)
	_bus.boss.announce_boss_warning_started("Albatross", 3.0)
	var queued: int = _coach.current()
	_bus.player.announce_repair_collected(Vector3.ZERO)
	var incoming: int = _coach.current()
	_bus.flow.announce_game_state_changed(GameState.Phase.BOSS_WARNING, GameState.Phase.BOSS_FIGHT)
	_coach.tick(TutorialCoach.HOLD_TIME + 0.1)
	var _move: GdUnitAssert = assert_int(first).is_equal(TutorialPrompt.Id.MOVE)
	var _aim: GdUnitAssert = assert_int(after_move).is_equal(TutorialPrompt.Id.AIM_AND_FIRE)
	var _three: GdUnitAssert = assert_int(after_two).is_equal(TutorialPrompt.Id.AIM_AND_FIRE)
	var _drop: GdUnitAssert = assert_int(after_miss).is_equal(TutorialPrompt.Id.SHOTS_DROP)
	var _gauge: GdUnitAssert = assert_int(at_quarter).is_equal(TutorialPrompt.Id.BOSS_GAUGE)
	var _kits: GdUnitAssert = assert_int(queued).is_equal(TutorialPrompt.Id.REPAIR_KITS)
	var _boss: GdUnitAssert = assert_int(incoming).is_equal(TutorialPrompt.Id.BOSS_INCOMING)
	var _cleared: GdUnitAssert = assert_int(_coach.current()).is_equal(TutorialCoach.NONE)
	var _all_once: GdUnitAssert = (
		assert_array(_shown)
		. is_equal(
			[
				TutorialPrompt.Id.MOVE,
				TutorialPrompt.Id.AIM_AND_FIRE,
				TutorialPrompt.Id.SHOTS_DROP,
				TutorialPrompt.Id.BOSS_GAUGE,
				TutorialPrompt.Id.REPAIR_KITS,
				TutorialPrompt.Id.BOSS_INCOMING,
			]
		)
	)
	var _complete: GdUnitAssert = assert_bool(_progress.is_complete()).is_true()


func test_tutorial_timed_prompt_leaves_after_hold_but_not_while_paused() -> void:
	_fly()
	_bus.player.announce_player_moved()
	_fire(3)
	_bus.player.announce_repair_kit_dropped(Vector3.ZERO)
	_bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.PAUSED)
	_coach.tick(TutorialCoach.HOLD_TIME * 2.0)
	var while_paused: int = _coach.current()
	_bus.flow.announce_game_state_changed(GameState.Phase.PAUSED, GameState.Phase.SKIRMISH)
	_coach.tick(TutorialCoach.HOLD_TIME + 0.1)
	var _held: GdUnitAssert = assert_int(while_paused).is_equal(TutorialPrompt.Id.REPAIR_KITS)
	var _gone: GdUnitAssert = assert_int(_coach.current()).is_equal(TutorialCoach.NONE)
	var _done: GdUnitAssert = (
		assert_bool(_progress.is_done(TutorialPrompt.Id.REPAIR_KITS)).is_true()
	)


func test_tutorial_progress_persists_and_can_be_disabled() -> void:
	_fly()
	_bus.player.announce_player_moved()
	var hints_off: GameSettings = GameSettings.new()
	hints_off.tutorial_hints = false
	_bus.profile.announce_settings_changed(hints_off)
	var hidden: Array = _dismissed.back()
	_bus.player.announce_repair_kit_dropped(Vector3.ZERO)
	var while_off: int = _coach.current()
	# A new session from the same store: MOVE stays done.
	_new_coach()
	_fly()
	var resumed: int = _coach.current()
	# Leaving Level 1 ends the first Run's tutorial for good.
	_bus.run.announce_level_cleared(LevelTally.new(1, 0, 0, 0, 0, 0))
	_new_coach()
	_fly()
	var after_first_run: int = _coach.current()
	var _hidden: GdUnitAssert = assert_array(hidden).is_equal(
		[TutorialPrompt.Id.AIM_AND_FIRE, false]
	)
	var _silent: GdUnitAssert = assert_int(while_off).is_equal(TutorialCoach.NONE)
	var _not_again: GdUnitAssert = assert_int(resumed).is_equal(TutorialPrompt.Id.AIM_AND_FIRE)
	var _never: GdUnitAssert = assert_int(after_first_run).is_equal(TutorialCoach.NONE)
	var _kept: GdUnitAssert = assert_bool(_progress.is_first_run_done()).is_true()


func test_tutorial_runs_only_in_level_one() -> void:
	_fly(2)
	var _none: GdUnitAssert = assert_int(_coach.current()).is_equal(TutorialCoach.NONE)
	var _quiet: GdUnitAssert = assert_array(_shown).is_empty()
