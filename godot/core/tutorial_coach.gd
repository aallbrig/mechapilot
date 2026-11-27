class_name TutorialCoach
extends RefCounted
## The first-flight tutorial rules (#73, #75). In Level 1 of the first Run,
## contextual prompts appear once each, and each dismisses itself once its
## condition is met:
##
##   MOVE           from the Skirmish start, until the player moves
##   AIM_AND_FIRE   after MOVE, until 3 shots
##   SHOTS_DROP     after the first miss, until the next hit (or a while)
##   BOSS_GAUGE     at 25% of the Boss Gauge, until the Boss Warning (or a while)
##   REPAIR_KITS    on the first Repair Kit drop, until one is collected (or a while)
##   BOSS_INCOMING  on the Boss Warning, for a while
##
## One prompt shows at a time; others wait in order. A prompt whose condition
## is met while it waits is done without showing (the player already knows).
## Done prompts persist in TutorialProgress and never show again; leaving
## Level 1 or ending the first Run ends the tutorial for good. Turning
## GameSettings.tutorial_hints off hides every prompt at once.
##
## The mech reports steering once per press, and it flies during the Level
## intro, before any prompt shows. A press during Level 1's intro of the first
## Run therefore completes MOVE when the Skirmish starts, so a pilot who holds
## the stick through the intro is never told to do what they are doing. Any
## other steering (the Title's attract mode, before a Run starts, Levels 2 to
## 6) is ignored by design: it is not the pilot learning to fly in Level 1.
##
## Listens: profile.settings_changed, flow.game_state_changed, run.run_started,
## run.level_intro_completed, run.level_cleared, run.run_ended,
## run.boss_gauge_changed, player.player_moved, player.player_fired,
## player.shot_missed, player.repair_kit_dropped, player.repair_collected,
## enemy.enemy_hit, boss.boss_hit and boss.boss_warning_started.
## Announces: run.tutorial_prompt_shown and run.tutorial_prompt_dismissed.

## Prompts that leave by themselves after this many seconds of play.
const HOLD_TIME: float = 6.0
## Shots that complete "Aim & fire".
const AIM_SHOTS: int = 3
## The Boss Gauge share that shows "Fill the Boss Gauge".
const GAUGE_SHARE: float = 0.25
## The only Level the tutorial runs in.
const TUTORIAL_LEVEL: int = 1
## Prompts that only need to be read: they time out.
const TIMED: Array[TutorialPrompt.Id] = [
	TutorialPrompt.Id.SHOTS_DROP,
	TutorialPrompt.Id.BOSS_GAUGE,
	TutorialPrompt.Id.REPAIR_KITS,
	TutorialPrompt.Id.BOSS_INCOMING,
]
const NONE: int = -1

var _events: EventBus
var _progress: TutorialProgress
var _hints: bool = true
var _first_run: bool = false
var _in_level: bool = false
var _phase: GameState.Phase = GameState.Phase.BOOT
var _current: int = NONE
var _shown_for: float = 0.0
var _queue: Array[TutorialPrompt.Id] = []
var _shots: int = 0
## The pilot steered after this Run started, before Level 1's Skirmish.
var _moved_before_skirmish: bool = false


func _init(events: EventBus, progress: TutorialProgress) -> void:
	_events = events
	_progress = progress
	var subscribed: Array[int] = [
		_events.profile.settings_changed.connect(_on_settings_changed),
		_events.flow.game_state_changed.connect(_on_game_state_changed),
		_events.run.run_started.connect(_on_run_started),
		_events.run.level_intro_completed.connect(_on_level_intro_completed),
		_events.run.level_cleared.connect(_on_level_cleared),
		_events.run.run_ended.connect(_on_run_ended),
		_events.run.boss_gauge_changed.connect(_on_boss_gauge_changed),
		_events.player.player_moved.connect(_on_player_moved),
		_events.player.player_fired.connect(_on_player_fired),
		_events.player.shot_missed.connect(_on_shot_missed),
		_events.player.repair_kit_dropped.connect(_on_repair_kit_dropped),
		_events.player.repair_collected.connect(_on_repair_collected),
		_events.enemy.enemy_hit.connect(_on_enemy_hit),
		_events.boss.boss_hit.connect(_on_boss_hit),
		_events.boss.boss_warning_started.connect(_on_boss_warning_started),
	]
	Subscriptions.require_ok("TutorialCoach", subscribed)


## Advances the shown prompt's clock by `delta` seconds of play (not while
## paused or between phases): timed prompts leave after HOLD_TIME.
func tick(delta: float) -> void:
	if _current == NONE or not GameState.is_play(_phase) or delta <= 0.0:
		return
	_shown_for += delta
	if TIMED.has(_current as TutorialPrompt.Id) and _shown_for >= HOLD_TIME:
		_complete(_current as TutorialPrompt.Id)


## The prompt on screen, or NONE (-1).
func current() -> int:
	return _current


## True while prompts may show: hints on, Level 1 of the first Run.
func is_running() -> bool:
	return _hints and _first_run and _in_level


func _offer(prompt: TutorialPrompt.Id) -> void:
	if not is_running() or _progress.is_done(prompt):
		return
	if _current == prompt or _queue.has(prompt):
		return
	if _current == NONE:
		_show(prompt)
	else:
		_queue.append(prompt)


func _show(prompt: TutorialPrompt.Id) -> void:
	_current = prompt
	_shown_for = 0.0
	_events.run.announce_tutorial_prompt_shown(prompt)


## The condition of `prompt` is met: it is done, shown or not.
func _complete(prompt: TutorialPrompt.Id) -> void:
	if not is_running():
		return
	if _queue.has(prompt):
		_queue.erase(prompt)
		var _new: bool = _progress.mark_done(prompt)
		return
	if _current != prompt:
		return
	var _done: bool = _progress.mark_done(prompt)
	_current = NONE
	_events.run.announce_tutorial_prompt_dismissed(prompt, true)
	_next()


func _next() -> void:
	while not _queue.is_empty():
		var prompt: TutorialPrompt.Id = _queue.pop_front()
		if not _progress.is_done(prompt):
			_show(prompt)
			return


## Hides what is shown without completing it, and forgets the queue.
func _stop() -> void:
	_queue.clear()
	if _current != NONE:
		var prompt: TutorialPrompt.Id = _current as TutorialPrompt.Id
		_current = NONE
		_events.run.announce_tutorial_prompt_dismissed(prompt, false)


func _end_first_run() -> void:
	_stop()
	_in_level = false
	if _first_run:
		_first_run = false
		_progress.mark_first_run_done()


func _on_settings_changed(settings: GameSettings) -> void:
	_hints = settings.tutorial_hints
	if not _hints:
		_stop()


func _on_game_state_changed(from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to
	if from == GameState.Phase.PAUSED and to == GameState.Phase.TITLE:
		# The Run was abandoned: Level 1 may be flown again as the first Run.
		_stop()
		_in_level = false


func _on_run_started(_level_number: int) -> void:
	_stop()
	_first_run = not _progress.is_first_run_done() and not _progress.is_complete()
	_in_level = false
	_shots = 0
	_moved_before_skirmish = false


func _on_level_intro_completed(level_number: int) -> void:
	_in_level = level_number == TUTORIAL_LEVEL
	if _moved_before_skirmish and is_running():
		var _new: bool = _progress.mark_done(TutorialPrompt.Id.MOVE)
	_moved_before_skirmish = false
	_offer(TutorialPrompt.Id.MOVE)
	_offer(TutorialPrompt.Id.AIM_AND_FIRE)


func _on_level_cleared(tally: LevelTally) -> void:
	if tally.level_number == TUTORIAL_LEVEL:
		_end_first_run()


func _on_run_ended(_summary: RunSummary) -> void:
	_end_first_run()


func _on_boss_gauge_changed(points: int, threshold: int) -> void:
	if threshold > 0 and points >= threshold * GAUGE_SHARE:
		_offer(TutorialPrompt.Id.BOSS_GAUGE)


func _on_player_moved() -> void:
	if _first_run and not _in_level and _phase == GameState.Phase.LEVEL_INTRO:
		_moved_before_skirmish = true
	_complete(TutorialPrompt.Id.MOVE)


func _on_player_fired(_origin: Vector3, _direction: Vector3) -> void:
	_shots += 1
	if _shots >= AIM_SHOTS:
		_complete(TutorialPrompt.Id.AIM_AND_FIRE)


func _on_shot_missed(_position: Vector3) -> void:
	_offer(TutorialPrompt.Id.SHOTS_DROP)


func _on_enemy_hit(_enemy_id: int, _position: Vector3) -> void:
	if _current == TutorialPrompt.Id.SHOTS_DROP:
		_complete(TutorialPrompt.Id.SHOTS_DROP)


func _on_boss_hit(_damage: int, _position: Vector3) -> void:
	if _current == TutorialPrompt.Id.SHOTS_DROP:
		_complete(TutorialPrompt.Id.SHOTS_DROP)


func _on_repair_kit_dropped(_position: Vector3) -> void:
	_offer(TutorialPrompt.Id.REPAIR_KITS)


func _on_repair_collected(_position: Vector3) -> void:
	_complete(TutorialPrompt.Id.REPAIR_KITS)


func _on_boss_warning_started(_boss_name: String, _duration: float) -> void:
	_complete(TutorialPrompt.Id.BOSS_GAUGE)
	_offer(TutorialPrompt.Id.BOSS_INCOMING)
