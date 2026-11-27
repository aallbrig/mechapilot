class_name UiBuild
extends RefCounted
## Small constructors for the screens' controls, so every screen gets the same
## theme variations, sizes and focus rules from ui/theme/theme.tres.

## The widest a menu column grows, in UI pixels. The phone portrait layout is
## 640 UI pixels wide (see ui/README.md), so this leaves a margin on both sides.
const COLUMN_WIDTH: float = 520.0
const BUTTON_HEIGHT: float = 64.0
const GAP: int = 14
const SCREEN_MARGIN: int = 24


## A label with a theme variation ("" for the plain Label style).
static func label(text: String, variation: StringName = &"") -> Label:
	var made: Label = Label.new()
	made.text = text
	made.theme_type_variation = variation
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A wrapping label for longer copy, as wide as the menu column.
static func paragraph(text: String, variation: StringName = &"BodyLabel") -> Label:
	var made: Label = label(text, variation)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	return made


## A menu button, full column width, that keyboard and gamepad can focus.
static func button(text: String) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_ALL
	made.custom_minimum_size = Vector2(COLUMN_WIDTH, BUTTON_HEIGHT)
	return made


## A vertical stack with the standard gap.
static func column(gap: int = GAP) -> VBoxContainer:
	var made: VBoxContainer = VBoxContainer.new()
	made.add_theme_constant_override(&"separation", gap)
	made.alignment = BoxContainer.ALIGNMENT_CENTER
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A horizontal row with the standard gap.
static func row(gap: int = GAP) -> HBoxContainer:
	var made: HBoxContainer = HBoxContainer.new()
	made.add_theme_constant_override(&"separation", gap)
	made.alignment = BoxContainer.ALIGNMENT_CENTER
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## Fills `parent` with a margin, a centre box and a themed panel, and returns
## the panel's column, where the screen adds its content.
static func centered_panel(parent: Control) -> VBoxContainer:
	var center: CenterContainer = centered(parent)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"MenuPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var content: VBoxContainer = column()
	panel.add_child(content)
	return content


## Fills `parent` with a margin and a centre box, and returns the box.
static func centered(parent: Control) -> CenterContainer:
	var margin: MarginContainer = full_margin()
	parent.add_child(margin)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	return center


## A full-rect margin container with the screen margin on every side.
static func full_margin() -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, SCREEN_MARGIN)
	return margin
