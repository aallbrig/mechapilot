extends CanvasLayer
## PROTOTYPE front end: title with Play / Leaderboard / Credits, the leaderboard,
## credits, and a touch-friendly three-initials picker. All juice is tween_fx.gd.

signal play_requested
signal main_shown
signal initials_entered(initials: String)

enum Screen { NONE, MAIN, BOARD, CREDITS, INITIALS }

const TweenFx := preload("res://tween_fx.gd")
const Scores := preload("res://scores.gd")
const Hud := preload("res://hud.gd")
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const NAV_SIZE := Vector2(420, 92)
const CREDITS_TEXT := (
	"MECHA FIGHTER  -  LAN PROTOTYPE\n"
	+ "A throwaway build for testing feel. Not the real game.\n\n"
	+ "Design and code: the Mecha Fighter project\n"
	+ "Engine: Godot Engine 4.7 (MIT licence)\n"
	+ "Font: Godot's default font, Open Sans (SIL Open Font Licence 1.1)\n"
	+ "Art: primitive meshes built in code; no external assets\n"
	+ "Sound: procedural synth generated at runtime\n"
	+ "Kenney assets (CC0): none used in this prototype\n\n"
	+ "Inspired by the arcade classic Time Pilot"
)

var screen := Screen.NONE
var root: Control
var title: Label
var pages := {}
var nav_buttons: Array[Button] = []
var board_rows: Array[Label] = []
var letter_labels: Array[Label] = []
var initials_header: Label
var letters: Array[int] = [0, 0, 0]
var slot := 0
var busy := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.02, 0.12, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	title = Hud.make_label(96, Color(1, 1, 1))
	title.text = "MECHA FIGHTER"
	_place(title, Vector2(0, -250), Vector2(1000, 120))
	root.add_child(title)
	_build_main()
	_build_board()
	_build_credits()
	_build_initials()
	_show(Screen.NONE)


func is_open() -> bool:
	return screen != Screen.NONE


# ---------------------------------------------------------------- building


func _make_theme() -> Theme:
	var t := Theme.new()
	t.set_font_size("font_size", "Button", 38)
	t.set_color("font_color", "Button", Color(0.9, 0.97, 1))
	t.set_color("font_hover_color", "Button", Color(1, 1, 0.8))
	t.set_color("font_focus_color", "Button", Color(1, 1, 0.8))
	t.set_color("font_pressed_color", "Button", Color(0.08, 0.08, 0.2))
	t.set_color("font_hover_pressed_color", "Button", Color(0.08, 0.08, 0.2))
	t.set_stylebox("normal", "Button", _sb(Color(0.04, 0.1, 0.28, 0.88), Color(0.2, 0.8, 1), 3))
	t.set_stylebox("hover", "Button", _sb(Color(0.1, 0.25, 0.55, 0.95), Color(1, 0.85, 0.2), 3))
	t.set_stylebox("pressed", "Button", _sb(Color(1, 0.85, 0.2), Color(1, 1, 1), 3))
	t.set_stylebox("hover_pressed", "Button", _sb(Color(1, 0.85, 0.2), Color(1, 1, 1), 3))
	t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), Color(1, 0.85, 0.2), 5))
	return t


func _sb(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(18)
	s.set_content_margin_all(12)
	return s


## Anchor a control to the screen centre with a centre offset and a fixed size.
func _place(c: Control, at: Vector2, sz: Vector2) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.offset_left = at.x - sz.x * 0.5
	c.offset_right = at.x + sz.x * 0.5
	c.offset_top = at.y - sz.y * 0.5
	c.offset_bottom = at.y + sz.y * 0.5
	c.pivot_offset = sz * 0.5
	c.set_meta("home", Rect2(at, sz))


func _restore(c: Control) -> void:
	var home: Rect2 = c.get_meta("home")
	_place(c, home.position, home.size)


func _page() -> Control:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	return p


func _button(parent: Control, text: String, at: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	_place(b, at, sz)
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	b.mouse_entered.connect(_hover.bind(b, true))
	b.mouse_exited.connect(_hover.bind(b, false))
	b.focus_entered.connect(_hover.bind(b, true))
	b.focus_exited.connect(_hover.bind(b, false))
	b.button_down.connect(func() -> void: TweenFx.scale_to(b, 0.9, 0.06))
	b.pressed.connect(_press.bind(b, cb))
	return b


func _hover(b: Button, on: bool) -> void:
	TweenFx.scale_to(b, 1.08 if on else 1.0, 0.12)
	if on:
		Events.ui_focus.emit()


func _press(b: Button, cb: Callable) -> void:
	TweenFx.punch_scale(b, 0.18, 0.3)
	Events.ui_confirm.emit()
	if b.get_meta("instant", false):
		cb.call()
		return
	if busy:
		return
	busy = true
	get_tree().create_timer(0.14, true, false, true).timeout.connect(cb)


func _build_main() -> void:
	var p := _page()
	pages[Screen.MAIN] = p
	nav_buttons.append(_button(p, "PLAY", Vector2(0, -60), NAV_SIZE, _on_play))
	nav_buttons.append(_button(p, "LEADERBOARD", Vector2(0, 50), NAV_SIZE, show_board.bind(-1)))
	nav_buttons.append(_button(p, "CREDITS", Vector2(0, 160), NAV_SIZE, show_credits))
	var hint := Hud.make_label(20, Color(0.8, 0.9, 1.0, 0.85))
	hint.text = (
		"WASD / left stick / left thumb: fly      "
		+ "Mouse / arrows / right stick / right thumb: aim + fire      Esc: menu"
	)
	_place(hint, Vector2(0, 290), Vector2(1200, 40))
	p.add_child(hint)


func _build_board() -> void:
	var p := _page()
	pages[Screen.BOARD] = p
	var head := Hud.make_label(64, Color(1, 0.85, 0.2))
	head.text = "LEADERBOARD"
	_place(head, Vector2(0, -275), Vector2(800, 80))
	p.add_child(head)
	for i in Scores.SIZE:
		var row := Hud.make_label(30, Color(1, 1, 1))
		_place(row, Vector2(0, -200 + i * 38), Vector2(640, 36))
		p.add_child(row)
		board_rows.append(row)
	_button(p, "BACK", Vector2(0, 250), Vector2(300, 80), show_main)


func _build_credits() -> void:
	var p := _page()
	pages[Screen.CREDITS] = p
	var head := Hud.make_label(64, Color(1, 0.85, 0.2))
	head.text = "CREDITS"
	_place(head, Vector2(0, -275), Vector2(800, 80))
	p.add_child(head)
	var body := Hud.make_label(26, Color(0.9, 0.95, 1))
	body.text = CREDITS_TEXT
	_place(body, Vector2(0, -20), Vector2(1100, 380))
	p.add_child(body)
	_button(p, "BACK", Vector2(0, 250), Vector2(300, 80), show_main)


func _build_initials() -> void:
	var p := _page()
	pages[Screen.INITIALS] = p
	initials_header = Hud.make_label(54, Color(1, 0.85, 0.2))
	_place(initials_header, Vector2(0, -260), Vector2(1000, 120))
	p.add_child(initials_header)
	for i in 3:
		var x := (i - 1) * 170.0
		var up := _button(p, "", Vector2(x, -120), Vector2(130, 84), _bump.bind(i, 1))
		up.set_meta("instant", true)
		up.draw.connect(_draw_arrow.bind(up, true))
		var l := Hud.make_label(110, Color(1, 1, 1))
		_place(l, Vector2(x, 0), Vector2(150, 130))
		p.add_child(l)
		letter_labels.append(l)
		var down := _button(p, "", Vector2(x, 120), Vector2(130, 84), _bump.bind(i, -1))
		down.set_meta("instant", true)
		down.draw.connect(_draw_arrow.bind(down, false))
	_button(p, "OK", Vector2(0, 245), Vector2(300, 84), _confirm_initials)


func _draw_arrow(b: Button, up: bool) -> void:
	var c := b.size * 0.5
	var s := 20.0
	var d := -1.0 if up else 1.0
	var pts := PackedVector2Array(
		[
			c + Vector2(0, s * d),
			c + Vector2(s * 1.2, -s * 0.6 * d),
			c + Vector2(-s * 1.2, -s * 0.6 * d)
		]
	)
	b.draw_colored_polygon(pts, Color(1, 1, 1))


# ---------------------------------------------------------------- screens


func _show(s: Screen) -> void:
	screen = s
	busy = false
	root.visible = s != Screen.NONE
	for k: Screen in pages:
		(pages[k] as Control).visible = k == s
	title.visible = s == Screen.MAIN


func hide_menu() -> void:
	_show(Screen.NONE)


func show_main() -> void:
	_show(Screen.MAIN)
	main_shown.emit()
	await get_tree().process_frame
	_restore(title)
	TweenFx.pop(title, 0.3, 0.6)
	for i in nav_buttons.size():
		var b := nav_buttons[i]
		_restore(b)
		b.scale = Vector2.ONE
		var side := -1.0 if i % 2 == 0 else 1.0
		TweenFx.slide_in(b, Vector2(700 * side, 0), 0.12 + i * 0.09, 0.55)
	nav_buttons[0].grab_focus()


func show_board(highlight: int = -1) -> void:
	_show(Screen.BOARD)
	var rows := Scores.load_rows()
	for i in board_rows.size():
		var l := board_rows[i]
		if i < rows.size():
			l.text = "%2d.    %s    %8d" % [i + 1, rows[i]["initials"], int(rows[i]["score"])]
		else:
			l.text = "%2d.    ---    %8s" % [i + 1, "-"]
		l.modulate = Color(1, 0.9, 0.3) if i == highlight else Color(1, 1, 1)
	if rows.is_empty():
		board_rows[0].text = "No scores yet. Go fly!"
	await get_tree().process_frame
	for i in board_rows.size():
		_restore(board_rows[i])
		TweenFx.slide_in(board_rows[i], Vector2(0, 40), i * 0.04, 0.4)
	if highlight >= 0:
		var hl := board_rows[highlight]
		var tw := hl.create_tween().set_ignore_time_scale(true).set_loops(3)
		tw.tween_interval(0.5)
		tw.tween_callback(func() -> void: TweenFx.punch_scale(hl, 0.25, 0.4))


func show_credits() -> void:
	_show(Screen.CREDITS)


func show_initials(score: int) -> void:
	_show(Screen.INITIALS)
	letters = [0, 0, 0]
	slot = 0
	initials_header.text = "NEW HIGH SCORE!\n%d" % score
	_refresh_letters()
	await get_tree().process_frame
	_restore(initials_header)
	TweenFx.pop(initials_header, 0.3, 0.6)


func _on_play() -> void:
	hide_menu()
	play_requested.emit()


## Autotest hook.
func request_play() -> void:
	_on_play()


# ---------------------------------------------------------------- initials


func _bump(i: int, dir: int) -> void:
	slot = i
	letters[i] = posmod(letters[i] + dir, ALPHABET.length())
	_refresh_letters()
	TweenFx.punch_scale(letter_labels[i], 0.25, 0.3)


func _refresh_letters() -> void:
	for i in 3:
		letter_labels[i].text = ALPHABET[letters[i]]
		letter_labels[i].modulate = Color(1, 0.85, 0.2) if i == slot else Color(1, 1, 1)


func _initials() -> String:
	return ALPHABET[letters[0]] + ALPHABET[letters[1]] + ALPHABET[letters[2]]


func _confirm_initials() -> void:
	initials_entered.emit(_initials())


## Autotest hook.
func submit_initials(text: String) -> void:
	for i in 3:
		letters[i] = maxi(0, ALPHABET.find(text[i]))
	_confirm_initials()


func _input(event: InputEvent) -> void:
	if screen == Screen.INITIALS:
		_initials_input(event)
	elif screen == Screen.BOARD or screen == Screen.CREDITS:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			show_main()


func _initials_input(event: InputEvent) -> void:
	var handled := true
	if event is InputEventKey and (event as InputEventKey).pressed and not event.is_echo():
		var code := (event as InputEventKey).keycode
		if code >= KEY_A and code <= KEY_Z:
			letters[slot] = code - KEY_A
			TweenFx.punch_scale(letter_labels[slot], 0.25, 0.3)
			slot = mini(slot + 1, 2)
			_refresh_letters()
			Events.ui_focus.emit()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_left"):
		slot = posmod(slot - 1, 3)
		_refresh_letters()
	elif event.is_action_pressed("ui_right"):
		slot = posmod(slot + 1, 3)
		_refresh_letters()
	elif event.is_action_pressed("ui_up"):
		_bump(slot, 1)
	elif event.is_action_pressed("ui_down"):
		_bump(slot, -1)
	elif event.is_action_pressed("ui_accept"):
		Events.ui_confirm.emit()
		_confirm_initials()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
