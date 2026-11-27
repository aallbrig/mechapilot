class_name LevelIntroCard
extends UiScreen
## The Level Intro card (#73): the Level's number, name and objective, shown
## over the HUD for the Level Intro. It slides in, holds, and fades out just
## before the Skirmish starts.

const FADE_OUT_TIME: float = 0.4

var _number: Label
var _level_name: Label
var _objective: Label
var _panel: Control
var _duration: float = 0.0


func _ready() -> void:
	var content: VBoxContainer = UiBuild.centered_panel(self)
	_panel = content
	_number = UiBuild.label("LEVEL 1", &"HeaderLabel")
	_level_name = UiBuild.paragraph("", &"TitleLabel")
	_objective = UiBuild.paragraph("")
	content.add_child(_number)
	content.add_child(_level_name)
	content.add_child(_objective)


## The card's three lines, for tests: number, name, objective.
func lines() -> PackedStringArray:
	return PackedStringArray([_number.text, _level_name.text, _objective.text])


func _subscribe() -> void:
	var _ok: bool = _require([_bus.run.level_intro_started.connect(_on_level_intro_started)])


func _on_level_intro_started(
	level_number: int, level_name: String, objective: String, duration: float
) -> void:
	_number.text = "LEVEL %d" % level_number
	_level_name.text = level_name.to_upper()
	_objective.text = objective
	_duration = duration


func _on_enter() -> void:
	cue(UiCue.Cue.POP)
	_panel.modulate.a = 1.0
	TweenFx.pop(_number)
	TweenFx.fade(_panel, 0.0, FADE_OUT_TIME, maxf(_duration - FADE_OUT_TIME, 0.0))
