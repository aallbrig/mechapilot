class_name Hud
extends UiScreen
## The in-play HUD (#73): Armor bar, lives icons, score with a punch, the
## combo, the Boss Gauge and, in the Boss Fight, the boss's health bar. Plus
## the on-screen pause button for touch, and the pause keys (Esc, P, Start).
## Everything but the pause button lets the pointer through to the game.

const BAR_SIZE: Vector2 = Vector2(220.0, 24.0)
const WIDE_BAR_SIZE: Vector2 = Vector2(360.0, 22.0)
const PAUSE_SIZE: Vector2 = Vector2(72.0, 72.0)
const BAR_TWEEN_TIME: float = 0.25
const HIT_SHAKE: float = 10.0
const HIT_SHAKE_TIME: float = 0.3
const HIT_FLASH: Color = Color(1.0, 0.35, 0.35)
const SCORE_PUNCH: float = 0.3
const COMBO_PUNCH: float = 0.15
const COMBO_PUNCH_PER_STEP: float = 0.04
const ONE_UP_POP: float = 0.1
const ONE_UP_HOLD: float = 0.8
const ONE_UP_FADE: float = 0.4
const GAUGE_FULL_PUNCH: float = 0.2

var _armor_bar: ProgressBar
var _lives: LifeIcons
var _score: Label
var _combo: Label
var _gauge_row: Control
var _gauge_bar: ProgressBar
var _boss_row: Control
var _boss_name: Label
var _boss_bar: ProgressBar
var _one_up: Label
var _pause_button: Button


func _ready() -> void:
	var margin: MarginContainer = UiBuild.full_margin()
	add_child(margin)
	var layout: VBoxContainer = UiBuild.column(8)
	layout.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(layout)
	var top: HBoxContainer = UiBuild.row(16)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	layout.add_child(top)
	top.add_child(_build_status())
	top.add_child(_build_score())
	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.custom_minimum_size = PAUSE_SIZE
	_pause_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_pause_button.tooltip_text = "Pause"
	if _pause_button.pressed.connect(_request_pause) != OK:
		push_error("Hud: could not wire the pause button")
	top.add_child(_pause_button)
	_gauge_row = _bar_row("BOSS GAUGE", &"GaugeBar")
	_gauge_bar = _gauge_row.get_child(1) as ProgressBar
	layout.add_child(_gauge_row)
	_boss_row = _bar_row("BOSS", &"BossBar")
	_boss_name = _boss_row.get_child(0) as Label
	_boss_bar = _boss_row.get_child(1) as ProgressBar
	layout.add_child(_boss_row)
	_one_up = UiBuild.label("1UP!", &"TitleLabel")
	_one_up.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_one_up.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_one_up.grow_vertical = Control.GROW_DIRECTION_BOTH
	_one_up.visible = false
	add_child(_one_up)
	_reset()


## The score shown, as displayed.
func score_text() -> String:
	return _score.text


## The combo shown ("" when there is no combo).
func combo_text() -> String:
	return _combo.text if _combo.visible else ""


## The Armor the bar is heading to.
func armor_value() -> float:
	return _armor_bar.value


## The lives shown.
func lives_shown() -> int:
	return _lives.lives()


## Boss Gauge fill, 0 to 1.
func gauge_ratio() -> float:
	return _gauge_bar.ratio if _gauge_row.visible else 0.0


## True while the boss's health bar is shown.
func boss_bar_shown() -> bool:
	return _boss_row.visible


## Boss health, 0 to 1.
func boss_ratio() -> float:
	return _boss_bar.ratio


## The on-screen pause button (touch and mouse).
func pause_button() -> Button:
	return _pause_button


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and UiInput.is_pause(event):
		_request_pause()


func _subscribe() -> void:
	var _ok: bool = _require(
		[
			_bus.run.run_started.connect(_on_run_started),
			_bus.run.level_intro_started.connect(_on_level_intro_started),
			_bus.run.score_changed.connect(_on_score_changed),
			_bus.run.combo_changed.connect(_on_combo_changed),
			_bus.run.boss_gauge_changed.connect(_on_boss_gauge_changed),
			_bus.player.armor_changed.connect(_on_armor_changed),
			_bus.player.lives_changed.connect(_on_lives_changed),
			_bus.player.bonus_life_awarded.connect(_on_bonus_life_awarded),
			_bus.boss.boss_summoned.connect(_on_boss_summoned),
			_bus.boss.boss_damaged.connect(_on_boss_damaged),
			_bus.boss.boss_defeated.connect(_on_boss_defeated),
		]
	)


func _request_pause() -> void:
	_bus.flow.announce_pause_requested()


func _reset() -> void:
	_score.text = UiFormat.score(0)
	_combo.visible = false
	_gauge_bar.value = 0.0
	_gauge_row.visible = true
	_boss_row.visible = false
	_armor_bar.value = _armor_bar.max_value


func _on_run_started(_level_number: int) -> void:
	_reset()


func _on_level_intro_started(
	_level_number: int, _level_name: String, _objective: String, _duration: float
) -> void:
	_boss_row.visible = false
	_gauge_row.visible = true


func _on_score_changed(total: int, _delta: int) -> void:
	_score.text = UiFormat.score(total)
	TweenFx.punch(_score, SCORE_PUNCH)


func _on_combo_changed(multiplier: int) -> void:
	_combo.visible = multiplier > 1
	_combo.text = "x%d COMBO" % multiplier
	if multiplier > 1:
		TweenFx.punch(_combo, COMBO_PUNCH + COMBO_PUNCH_PER_STEP * multiplier)


func _on_boss_gauge_changed(points: int, threshold: int) -> void:
	_gauge_bar.max_value = maxi(threshold, 1)
	_tween_bar(_gauge_bar, points)
	if points >= threshold and threshold > 0:
		TweenFx.punch(_gauge_bar, GAUGE_FULL_PUNCH)


func _on_armor_changed(armor: int, max_armor: int, delta: int) -> void:
	_armor_bar.max_value = maxi(max_armor, 1)
	_tween_bar(_armor_bar, armor)
	if delta < 0:
		TweenFx.shake(_armor_bar, HIT_SHAKE, HIT_SHAKE_TIME)
		_armor_bar.modulate = HIT_FLASH
		var tween: Tween = TweenFx.make(_armor_bar)
		var _flash: PropertyTweener = tween.tween_property(
			_armor_bar, "modulate", Color.WHITE, HIT_SHAKE_TIME
		)
	elif delta > 0:
		TweenFx.punch(_armor_bar, COMBO_PUNCH)


func _on_lives_changed(lives: int) -> void:
	_lives.show_lives(lives)


func _on_bonus_life_awarded(_lives_now: int) -> void:
	cue(UiCue.Cue.POP)
	_one_up.visible = true
	_one_up.modulate.a = 1.0
	TweenFx.pop(_one_up, ONE_UP_POP)
	TweenFx.fade(_one_up, 0.0, ONE_UP_FADE, ONE_UP_HOLD)


func _on_boss_summoned(
	_boss_id: StringName, boss_name: String, max_health: int, _phases: int
) -> void:
	_gauge_row.visible = false
	_boss_row.visible = true
	_boss_name.text = boss_name.to_upper()
	_boss_bar.max_value = maxi(max_health, 1)
	_boss_bar.value = _boss_bar.max_value
	TweenFx.pop(_boss_row)


func _on_boss_damaged(health: int, max_health: int) -> void:
	_boss_bar.max_value = maxi(max_health, 1)
	_tween_bar(_boss_bar, health)


func _on_boss_defeated(_boss_id: StringName, _position: Vector3) -> void:
	_boss_row.visible = false


## Sets the bar's value at once (tests and logic read it) and tweens what it
## shows through a short overshoot-free ease.
func _tween_bar(bar: ProgressBar, to: float) -> void:
	var from: float = bar.value
	bar.value = to
	if TweenFx.reduced_motion or is_equal_approx(from, to):
		return
	var fill: float = clampf(to / bar.max_value, 0.0, 1.0)
	var tween: Tween = TweenFx.make(bar)
	bar.self_modulate = Color(1.0, 1.0, 1.0, 0.75 + 0.25 * fill)
	var _ease: PropertyTweener = tween.tween_property(
		bar, "self_modulate", Color.WHITE, BAR_TWEEN_TIME
	)


func _build_status() -> Control:
	var status: VBoxContainer = UiBuild.column(6)
	status.alignment = BoxContainer.ALIGNMENT_BEGIN
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var holder: Control = Control.new()
	holder.custom_minimum_size = BAR_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armor_bar = _bar(&"ArmorBar")
	_armor_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_armor_bar)
	status.add_child(UiBuild.label("ARMOR", &"HintLabel"))
	status.add_child(holder)
	_lives = LifeIcons.new()
	status.add_child(_lives)
	for child: Node in status.get_children():
		(child as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return status


func _build_score() -> Control:
	var center: VBoxContainer = UiBuild.column(0)
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score = UiBuild.label("0", &"ScoreLabel")
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo = UiBuild.label("", &"ComboLabel")
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center.add_child(_score)
	center.add_child(_combo)
	return center


func _bar_row(title: String, variation: StringName) -> Control:
	var bar_row: VBoxContainer = UiBuild.column(2)
	bar_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(UiBuild.label(title, &"HintLabel"))
	var bar: ProgressBar = _bar(variation)
	bar.custom_minimum_size = WIDE_BAR_SIZE
	bar_row.add_child(bar)
	return bar_row


func _bar(variation: StringName) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar
