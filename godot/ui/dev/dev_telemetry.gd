class_name DevTelemetry
extends RefCounted
## What the Developer console (#116) shows: the live state it hears on the
## Events bus (Game State, Level, score, Armor, lives, combo, Boss Gauge,
## device, developer status), the latest raw input events and active touch
## points (fed by the console), and a timestamped log of every bus
## announcement. It only listens: it never announces and never calls the rules.
##
## Timestamps are seconds since the telemetry started, on its own clock
## (advance()), so tests are deterministic and nothing reads the host clock.

const EVENT_LOG_SIZE: int = 10
const INPUT_LOG_SIZE: int = 5
## Built-in actions that are not this game's (ui_* except accept and cancel).
const UI_PREFIX: String = "ui_"
const SHOWN_UI_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel"]
## Where a touch lands, as the touch controls (#25) split the screen.
const ROLE_MOVE: String = "move stick"
const ROLE_AIM: String = "aim stick / tap shot"
const ROLE_CONSOLE: String = "console button"

var _now: float = 0.0
var _phase: GameState.Phase = GameState.Phase.BOOT
var _level: int = 0
var _score: int = 0
var _armor: int = 0
var _max_armor: int = 0
var _lives: int = 0
var _combo: int = 1
var _gauge: int = 0
var _gauge_threshold: int = 0
var _boss_health: int = 0
var _boss_max: int = 0
var _device: InputDevice.Kind = InputDevice.Kind.KEYBOARD
var _invulnerable: bool = false
var _dev_assisted: bool = false
var _events: Array[String] = []
var _last_event: String = ""
var _repeats: int = 0
var _inputs: Array[String] = []
var _touches: Dictionary[int, String] = {}


func _init(bus: EventBus) -> void:
	var subscribed: Array[int] = [
		bus.flow.game_state_changed.connect(_on_game_state_changed),
		bus.flow.input_device_changed.connect(_on_input_device_changed),
		bus.run.level_intro_started.connect(_on_level_intro_started),
		bus.run.score_changed.connect(_on_score_changed),
		bus.run.combo_changed.connect(_on_combo_changed),
		bus.run.boss_gauge_changed.connect(_on_boss_gauge_changed),
		bus.player.armor_changed.connect(_on_armor_changed),
		bus.player.lives_changed.connect(_on_lives_changed),
		bus.boss.boss_damaged.connect(_on_boss_damaged),
		bus.dev.dev_status_changed.connect(_on_dev_status_changed),
	]
	subscribed.append_array(_log_flow(bus.flow))
	subscribed.append_array(_log_run(bus.run))
	subscribed.append_array(_log_player(bus.player))
	subscribed.append_array(_log_enemy(bus.enemy))
	subscribed.append_array(_log_boss(bus.boss))
	subscribed.append_array(_log_profile(bus.profile))
	subscribed.append_array(_log_dev(bus.dev))
	if subscribed.count(OK) != subscribed.size():
		push_error("DevTelemetry: could not hear the bus")


## Moves the telemetry clock on by `delta` seconds.
func advance(delta: float) -> void:
	_now += maxf(delta, 0.0)


## The Game State heard last.
func phase() -> GameState.Phase:
	return _phase


## Records one raw input event. `screen` is the console's size (for touch
## roles); `on_console` is true when the event landed on a console button.
func note_input(event: InputEvent, screen: Vector2, on_console: bool) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			var role: String = ROLE_CONSOLE if on_console else touch_role(touch.position, screen)
			_touches[touch.index] = "#%d %s %s" % [touch.index, role, _point(touch.position)]
		else:
			var _gone: bool = _touches.erase(touch.index)
		_note("touch #%d %s" % [touch.index, "down" if touch.pressed else "up"])
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if _touches.has(drag.index):
			var held: String = _touches[drag.index]
			_touches[drag.index] = (
				"%s %s" % [held.substr(0, held.rfind(" ")), _point(drag.position)]
			)
		return
	var pressed: bool = (
		(event is InputEventKey and event.is_pressed() and not event.is_echo())
		or (event is InputEventJoypadButton and event.is_pressed())
		or (event is InputEventMouseButton and event.is_pressed())
	)
	if pressed:
		var actions: Array[String] = _actions(event)
		var named: String = event.as_text()
		_note(named if actions.is_empty() else "%s -> %s" % [named, ", ".join(actions)])


## The role of a touch at `at` on a screen of `screen` size: the left half
## steers (move stick), the right half aims and fires (aim stick or tap shot).
static func touch_role(at: Vector2, screen: Vector2) -> String:
	return ROLE_MOVE if at.x < screen.x * 0.5 else ROLE_AIM


## The live state, one field per line.
func state_lines(fps: float) -> Array[String]:
	var lines: Array[String] = [
		"FPS %d" % roundi(fps),
		"State %s" % GameState.Phase.keys()[_phase],
		"Level %d" % _level,
		"Score %d" % _score,
		"Armor %d/%d" % [_armor, _max_armor],
		"Lives %d" % _lives,
		"Combo x%d" % _combo,
		"Gauge %d/%d" % [_gauge, _gauge_threshold],
		"Boss %d/%d" % [_boss_health, _boss_max],
		"Device %s" % InputDevice.Kind.keys()[_device],
		"Invulnerable %s" % ("ON" if _invulnerable else "off"),
		"Assisted %s" % ("YES" if _dev_assisted else "no"),
	]
	return lines


## The active touch points, by finger, with their role.
func touch_lines() -> Array[String]:
	var lines: Array[String] = []
	for finger: int in _touches:
		lines.append(_touches[finger])
	return lines


## The latest raw input events, oldest first.
func input_log() -> Array[String]:
	return _inputs.duplicate()


## The latest bus announcements, oldest first, each stamped with its time.
func event_log() -> Array[String]:
	return _events.duplicate()


## Everything above as plain text, for the clipboard.
func snapshot(fps: float, build: String) -> String:
	var parts: Array[String] = ["Mecha Fighter diagnostics", build]
	parts.append_array(state_lines(fps))
	parts.append("Touches:")
	parts.append_array(touch_lines())
	parts.append("Input:")
	parts.append_array(_inputs)
	parts.append("Events:")
	parts.append_array(_events)
	return "\n".join(parts)


func _actions(event: InputEvent) -> Array[String]:
	var matched: Array[String] = []
	for action: StringName in InputMap.get_actions():
		var builtin: bool = String(action).begins_with(UI_PREFIX)
		if builtin and not SHOWN_UI_ACTIONS.has(action):
			continue
		if event.is_action_pressed(action):
			matched.append(String(action))
	return matched


func _note(line: String) -> void:
	_inputs.append("%6.2f  %s" % [_now, line])
	while _inputs.size() > INPUT_LOG_SIZE:
		_inputs.remove_at(0)


func _log(event_name: String, payload: Array) -> void:
	var parts: Array[String] = []
	for value: Variant in payload:
		parts.append(_text(value))
	var body: String = event_name if parts.is_empty() else "%s %s" % [event_name, " ".join(parts)]
	if body == _last_event and not _events.is_empty():
		_repeats += 1
		_events[-1] = "%6.2f  %s  x%d" % [_now, body, _repeats]
		return
	_last_event = body
	_repeats = 1
	_events.append("%6.2f  %s" % [_now, body])
	while _events.size() > EVENT_LOG_SIZE:
		_events.remove_at(0)


static func _text(value: Variant) -> String:
	if value is float:
		return "%.2f" % value
	if value is Vector3:
		var at: Vector3 = value
		return "(%.0f,%.0f)" % [at.x, at.y]
	if value is Array:
		var items: Array = value
		return "[%d]" % items.size()
	if value is RunSummary:
		var summary: RunSummary = value
		return "score=%d assisted=%s" % [summary.score, summary.dev_assisted]
	if value is LevelTally:
		var tally: LevelTally = value
		return "level=%d bonus=%d" % [tally.level_number, tally.bonus_total()]
	if value is SpawnOrder:
		var order: SpawnOrder = value
		return EnemyKind.Kind.keys()[order.kind]
	if value is Object:
		return "{}"
	return str(value)


static func _point(at: Vector2) -> String:
	return "(%d,%d)" % [roundi(at.x), roundi(at.y)]


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to


func _on_input_device_changed(device: InputDevice.Kind) -> void:
	_device = device


func _on_level_intro_started(level_number: int, _n: String, _o: String, _d: float) -> void:
	_level = level_number
	_boss_health = 0
	_boss_max = 0


func _on_score_changed(total: int, _delta: int) -> void:
	_score = total


func _on_combo_changed(multiplier: int) -> void:
	_combo = multiplier


func _on_boss_gauge_changed(points: int, threshold: int) -> void:
	_gauge = points
	_gauge_threshold = threshold


func _on_armor_changed(armor: int, max_armor: int, _delta: int) -> void:
	_armor = armor
	_max_armor = max_armor


func _on_lives_changed(lives: int) -> void:
	_lives = lives


func _on_boss_damaged(health: int, max_health: int) -> void:
	_boss_health = health
	_boss_max = max_health


func _on_dev_status_changed(invulnerable: bool, dev_assisted: bool) -> void:
	_invulnerable = invulnerable
	_dev_assisted = dev_assisted


func _log_flow(c: EventBus.FlowChannel) -> Array[int]:
	return [
		c.start_requested.connect(_log.bind("flow.start_requested", [])),
		c.play_requested.connect(_log.bind("flow.play_requested", [])),
		c.pause_requested.connect(_log.bind("flow.pause_requested", [])),
		c.resume_requested.connect(_log.bind("flow.resume_requested", [])),
		c.quit_to_title_requested.connect(_log.bind("flow.quit_to_title_requested", [])),
		c.continue_requested.connect(_log.bind("flow.continue_requested", [])),
		c.scoreboard_requested.connect(_log.bind("flow.scoreboard_requested", [])),
		c.title_requested.connect(_log.bind("flow.title_requested", [])),
		c.game_state_changed.connect(_on_state_logged),
		c.input_device_changed.connect(_on_device_logged),
		c.ui_cue_requested.connect(_on_one.bind("flow.ui_cue_requested")),
	]


func _log_run(c: EventBus.RunChannel) -> Array[int]:
	return [
		c.run_started.connect(_on_one.bind("run.run_started")),
		c.level_intro_started.connect(_on_four.bind("run.level_intro_started")),
		c.level_intro_completed.connect(_on_one.bind("run.level_intro_completed")),
		c.boss_gauge_changed.connect(_on_two.bind("run.boss_gauge_changed")),
		c.level_cleared.connect(_on_one.bind("run.level_cleared")),
		c.run_ended.connect(_on_one.bind("run.run_ended")),
		c.kill_scored.connect(_on_three.bind("run.kill_scored")),
		c.score_changed.connect(_on_two.bind("run.score_changed")),
		c.combo_changed.connect(_on_one.bind("run.combo_changed")),
	]


func _log_player(c: EventBus.PlayerChannel) -> Array[int]:
	return [
		c.player_fired.connect(_on_two.bind("player.player_fired")),
		c.player_hit.connect(_on_three.bind("player.player_hit")),
		c.armor_changed.connect(_on_three.bind("player.armor_changed")),
		c.invulnerability_started.connect(_on_one.bind("player.invulnerability_started")),
		c.invulnerability_ended.connect(_log.bind("player.invulnerability_ended", [])),
		c.player_destroyed.connect(_on_two.bind("player.player_destroyed")),
		c.life_lost.connect(_on_one.bind("player.life_lost")),
		c.lives_changed.connect(_on_one.bind("player.lives_changed")),
		c.bonus_life_awarded.connect(_on_one.bind("player.bonus_life_awarded")),
		c.player_respawned.connect(_log.bind("player.player_respawned", [])),
		c.repair_kit_dropped.connect(_on_one.bind("player.repair_kit_dropped")),
		c.repair_collected.connect(_on_one.bind("player.repair_collected")),
	]


func _log_enemy(c: EventBus.EnemyChannel) -> Array[int]:
	return [
		c.spawn_requested.connect(_on_one.bind("enemy.spawn_requested")),
		c.enemy_spawned.connect(_on_three.bind("enemy.enemy_spawned")),
		c.enemy_hit.connect(_on_two.bind("enemy.enemy_hit")),
		c.enemy_destroyed.connect(_on_four.bind("enemy.enemy_destroyed")),
		c.enemy_left_play_sphere.connect(_on_one.bind("enemy.enemy_left_play_sphere")),
	]


func _log_boss(c: EventBus.BossChannel) -> Array[int]:
	return [
		c.boss_warning_started.connect(_on_two.bind("boss.boss_warning_started")),
		c.boss_summoned.connect(_on_four.bind("boss.boss_summoned")),
		c.boss_hit.connect(_on_two.bind("boss.boss_hit")),
		c.boss_damaged.connect(_on_two.bind("boss.boss_damaged")),
		c.boss_phase_changed.connect(_on_two.bind("boss.boss_phase_changed")),
		c.boss_defeated.connect(_on_two.bind("boss.boss_defeated")),
	]


func _log_profile(c: EventBus.ProfileChannel) -> Array[int]:
	return [
		c.initials_submitted.connect(_on_one.bind("profile.initials_submitted")),
		c.settings_change_requested.connect(_on_one.bind("profile.settings_change_requested")),
		c.settings_reset_requested.connect(_log.bind("profile.settings_reset_requested", [])),
		c.scoreboard_qualified.connect(_on_one.bind("profile.scoreboard_qualified")),
		c.scoreboard_saved.connect(_on_two.bind("profile.scoreboard_saved")),
		c.scoreboard_changed.connect(_on_two.bind("profile.scoreboard_changed")),
		c.settings_changed.connect(_on_one.bind("profile.settings_changed")),
		c.intel_unlocked.connect(_on_one.bind("profile.intel_unlocked")),
		c.intel_changed.connect(_on_one.bind("profile.intel_changed")),
	]


func _log_dev(c: EventBus.DevChannel) -> Array[int]:
	return [
		c.dev_command_requested.connect(_on_command_logged),
		c.dev_status_changed.connect(_on_two.bind("dev.dev_status_changed")),
		c.enemies_purge_ordered.connect(_log.bind("dev.enemies_purge_ordered", [])),
	]


func _on_state_logged(from: GameState.Phase, to: GameState.Phase) -> void:
	_log(
		"flow.game_state_changed",
		[GameState.Phase.keys()[from] + " -> " + GameState.Phase.keys()[to]]
	)


func _on_device_logged(device: InputDevice.Kind) -> void:
	_log("flow.input_device_changed", [InputDevice.Kind.keys()[device]])


func _on_command_logged(command: DevCommand.Command) -> void:
	_log("dev.dev_command_requested", [DevCommand.Command.keys()[command]])


func _on_one(a: Variant, event_name: String) -> void:
	_log(event_name, [a])


func _on_two(a: Variant, b: Variant, event_name: String) -> void:
	_log(event_name, [a, b])


func _on_three(a: Variant, b: Variant, c: Variant, event_name: String) -> void:
	_log(event_name, [a, b, c])


func _on_four(a: Variant, b: Variant, c: Variant, d: Variant, event_name: String) -> void:
	_log(event_name, [a, b, c, d])
