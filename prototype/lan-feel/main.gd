extends Node3D
## PROTOTYPE: throwaway LAN feel test for Mecha Fighter. Never merge to main.
## Everything is built in code from primitive meshes. Play plane is XY (z = 0),
## seen side-on by a camera looking along -Z. The mech itself lives in mech.gd.

enum State { TITLE, PLAY, DEAD }

const PLAYER_SPEED := 11.0
const DRIFT := 0.3
const FIRE_INTERVAL := 0.1
const BULLET_SPEED := 46.0
const BULLET_LIFE := 1.4
## Downward pull on player shots, in units/s^2. 0 = laser-straight.
const BULLET_GRAVITY := 20.0
## Share of the mech's velocity a shot inherits.
const BULLET_INHERIT := 0.6
const SPHERE_RADIUS := 40.0
const SPAWN_DIST := 25.0
const CAM_OFFSET := Vector3(0, 0, 18.0)
const Mech := preload("res://mech.gd")
const WAVE_INTERVAL := 14.0
const COMBO_WINDOW := 1.6
const CLOUD_SPAN := Vector2(150.0, 100.0)
const STICK_RANGE := 70.0
const SKY_SHADER := preload("res://sky.gdshader")


class Enemy:
	var node: Node3D
	var model: Node3D
	var meshes: Array[MeshInstance3D] = []
	var mats: Array[Material] = []
	var vel := Vector3.ZERO
	var speed := 8.0
	var turn := 3.0
	var hp := 1
	var radius := 1.1
	var flash := 0.0
	var big := false


class Bullet:
	var node: Node3D
	var vel := Vector3.ZERO
	var life := BULLET_LIFE


var state := State.TITLE
var player: Mech
var velocity := Vector3.ZERO
var move_dir := Vector3(0, 1, 0)
var aim_dir := Vector3(1, 0, 0)
var facing := 1.0
var fire_cd := 0.0
var bullets: Array[Bullet] = []
var enemies: Array[Enemy] = []
var clouds: Array[Node3D] = []
var score := 0
var best := 0
var combo := 0
var combo_timer := 0.0
var kills := 0
var wave := 0
var wave_timer := 0.0
var spawn_limit := 2.0
var spawn_buffer := 1.2
var spawn_cd := 0.0
var intro := 0.0
var trauma := 0.0
var hitstop := 0.0
var slowmo := 0.0
var dead_timer := 0.0
var fov_punch := 0.0
var cam_kick := Vector3.ZERO
var cam_focus := Vector3.ZERO
var clock := 0.0
var last_ticks := 0
var mouse_aim := false
var touch_move_id := -1
var touch_move_origin := Vector2.ZERO
var touch_move_vec := Vector2.ZERO
var touch_aim_id := -1
var touch_aim_origin := Vector2.ZERO
var touch_aim_vec := Vector2.ZERO
var cam: Camera3D
var muzzle_light: OmniLight3D
var muzzle_flash: MeshInstance3D
var hud: Control
var score_label: Label
var combo_label: Label
var center_label: Label
var sub_label: Label
var shake_noise := FastNoiseLite.new()
var mat_cache := {}
var particle_mesh: BoxMesh
var autotest := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	shake_noise.frequency = 0.5
	last_ticks = Time.get_ticks_usec()
	_build_world()
	_build_player()
	_build_hud()
	Events.score_changed.connect(_on_score_changed)
	Events.wave_started.connect(_on_wave_started)
	_show_title()
	autotest = OS.get_cmdline_user_args().has("--autotest")
	if autotest:
		_start_game()


# ---------------------------------------------------------------- building


func _mat(color: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color, emission, unshaded]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cache[key] = m
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, rot: Vector3, mat: Material):
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.1, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.7)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.35, 0.55, 0.85)
	env.fog_density = 0.01
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_color = Color(1, 0.957, 0.839)
	sun.light_energy = 1.1
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.3
	cam.far = 200.0
	cam.position = CAM_OFFSET
	add_child(cam)

	var sky := MeshInstance3D.new()
	sky.name = "Sky"
	var qm := QuadMesh.new()
	qm.size = Vector2(520, 320)
	sky.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = SKY_SHADER
	sky.material_override = sm
	sky.position = Vector3(0, 0, -90)
	add_child(sky)

	# Parallax cloud layers: perspective does the parallax, deeper = slower.
	for i in 40:
		var c := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 1.0
		sp.height = 2.0
		sp.radial_segments = 14
		sp.rings = 7
		c.mesh = sp
		var depth := randf_range(-62.0, -12.0)
		var near := 1.0 - clampf((-depth - 12.0) / 50.0, 0.0, 1.0)
		var alpha := lerpf(0.45, 0.1, near)
		c.material_override = _mat(Color(1, 1, 1, snappedf(alpha, 0.05)), 0.0, true)
		var s := randf_range(2.0, 6.0) * lerpf(2.0, 1.0, near)
		c.scale = Vector3(s * randf_range(1.6, 3.0), s * 0.45, s * 0.6)
		c.position = Vector3(
			randf_range(-0.5, 0.5) * CLOUD_SPAN.x, randf_range(-0.5, 0.5) * CLOUD_SPAN.y, depth
		)
		add_child(c)
		clouds.append(c)

	particle_mesh = BoxMesh.new()
	particle_mesh.size = Vector3(0.5, 0.5, 0.5)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.vertex_color_use_as_albedo = true
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_mesh.material = pmat


func _build_player() -> void:
	player = Mech.new()
	player.scale = Vector3.ONE * 1.9
	add_child(player)

	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.85, 0.3)
	muzzle_light.omni_range = 9.0
	muzzle_light.light_energy = 0.0
	add_child(muzzle_light)
	muzzle_flash = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.5
	fm.height = 1.0
	muzzle_flash.mesh = fm
	muzzle_flash.material_override = _mat(Color(1.0, 0.95, 0.5), 6.0, true)
	muzzle_flash.visible = false
	add_child(muzzle_flash)


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = maxi(4, size / 6)
	ls.outline_color = Color(0, 0, 0.1)
	ls.shadow_size = 4
	ls.shadow_color = Color(0, 0, 0, 0.5)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)

	score_label = _make_label(44, Color(1, 1, 1))
	score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_label.size = Vector2(500, 60)
	score_label.position = Vector2(-250, 14)
	score_label.pivot_offset = Vector2(250, 30)
	hud.add_child(score_label)

	combo_label = _make_label(30, Color(1, 0.85, 0.2))
	combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	combo_label.size = Vector2(500, 40)
	combo_label.position = Vector2(-250, 72)
	combo_label.pivot_offset = Vector2(250, 20)
	hud.add_child(combo_label)

	center_label = _make_label(84, Color(1, 1, 1))
	center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_label.offset_bottom = -120
	hud.add_child(center_label)

	sub_label = _make_label(26, Color(0.8, 0.9, 1.0))
	sub_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub_label.offset_top = 120
	hud.add_child(sub_label)


# ---------------------------------------------------------------- states


func _show_title() -> void:
	state = State.TITLE
	center_label.text = "MECHA FIGHTER"
	sub_label.text = (
		"PROTOTYPE\n\nWASD / left stick / left thumb: move\n"
		+ "Mouse + click / arrows / right stick / right thumb: aim + fire\n\n"
		+ "Press any key, click or tap to start"
	)
	score_label.text = ""
	combo_label.text = ""


func _start_game() -> void:
	for e in enemies:
		e.node.queue_free()
	enemies.clear()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	state = State.PLAY
	score = 0
	combo = 0
	combo_timer = 0.0
	kills = 0
	wave = 0
	wave_timer = WAVE_INTERVAL * 0.6
	spawn_limit = 2.0
	spawn_buffer = 1.2
	spawn_cd = 0.0
	intro = 1.6
	slowmo = 0.0
	Engine.time_scale = 1.0
	player.position = Vector3.ZERO
	player.reset()
	move_dir = Vector3(0, 1, 0)
	aim_dir = Vector3(1, 0, 0)
	facing = 1.0
	velocity = move_dir * 5.0
	cam_focus = Vector3.ZERO
	center_label.text = "GET READY"
	sub_label.text = ""
	Events.score_changed.emit(score, combo)
	Events.game_started.emit()


func _game_over() -> void:
	state = State.DEAD
	if autotest:
		print("autotest: died score=%d kills=%d wave=%d" % [score, kills, wave])
	dead_timer = 1.4
	best = maxi(best, score)
	Events.player_died.emit(player.global_position)
	var p := player.global_position
	_explode(p, Color(0.3, 0.9, 1.0), 90, 1.8)
	_explode(p, Color(1.0, 0.6, 0.1), 60, 1.3)
	player.shatter(velocity)
	trauma = 1.0
	slowmo = 0.9
	fov_punch = 14.0
	for i in enemies.size():
		var e := enemies[i]
		var t := get_tree().create_timer(0.12 + i * 0.07, true, false, true)
		t.timeout.connect(_pop_enemy.bind(e))
	center_label.text = "GAME OVER"
	sub_label.text = ""


func _pop_enemy(e: Enemy) -> void:
	if not is_instance_valid(e.node):
		return
	_explode(e.node.position, Color(1, 0.3, 0.4), 30, 0.9)
	trauma = minf(trauma + 0.15, 1.0)
	e.node.queue_free()
	enemies.erase(e)


# ---------------------------------------------------------------- input


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _try_begin():
				return
			if st.position.x < hud.size.x * 0.5 and touch_move_id < 0:
				touch_move_id = st.index
				touch_move_origin = st.position
				touch_move_vec = Vector2.ZERO
			elif touch_aim_id < 0:
				touch_aim_id = st.index
				touch_aim_origin = st.position
				touch_aim_vec = Vector2.ZERO
		else:
			if st.index == touch_move_id:
				touch_move_id = -1
				touch_move_vec = Vector2.ZERO
			if st.index == touch_aim_id:
				touch_aim_id = -1
				touch_aim_vec = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == touch_move_id:
			touch_move_vec = ((sd.position - touch_move_origin) / STICK_RANGE).limit_length(1.0)
		elif sd.index == touch_aim_id:
			touch_aim_vec = ((sd.position - touch_aim_origin) / STICK_RANGE).limit_length(1.0)
	elif event is InputEventMouseMotion:
		mouse_aim = true
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			mouse_aim = true
			_try_begin()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.physical_keycode == KEY_ESCAPE and state == State.PLAY:
				_game_over()
				return
			_try_begin()
	elif event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_try_begin()


func _try_begin() -> bool:
	if state == State.TITLE or (state == State.DEAD and dead_timer <= 0.0):
		_start_game()
		return true
	return false


func _key_axis(neg: Key, pos: Key) -> float:
	return float(Input.is_physical_key_pressed(pos)) - float(Input.is_physical_key_pressed(neg))


func _read_move() -> Vector2:
	var v := Vector2(_key_axis(KEY_A, KEY_D), _key_axis(KEY_W, KEY_S))
	var j := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if j.length() > 0.2:
		v += j
	v.x += (
		float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT))
		- float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT))
	)
	v.y += (
		float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN))
		- float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP))
	)
	v += touch_move_vec
	if autotest:
		v = Vector2(signf(sin(clock * 0.9)), cos(clock * 1.3) * 0.7)
	return v.limit_length(1.0)


## Returns the fire direction in screen space, or zero when not firing.
func _read_fire() -> Vector2:
	var k := Vector2(_key_axis(KEY_LEFT, KEY_RIGHT), _key_axis(KEY_UP, KEY_DOWN))
	k += Vector2(_key_axis(KEY_J, KEY_L), _key_axis(KEY_I, KEY_K))
	if autotest:
		k = Vector2(cos(clock * 3.0), sin(clock * 3.0))
	if k.length() > 0.1:
		mouse_aim = false
		return k.normalized()
	var j := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if j.length() > 0.3:
		mouse_aim = false
		return j.normalized()
	if touch_aim_id >= 0 and touch_aim_vec.length() > 0.15:
		return touch_aim_vec.normalized()
	if mouse_aim:
		var mp := hud.get_viewport().get_mouse_position()
		var ro := cam.project_ray_origin(mp)
		var rn := cam.project_ray_normal(mp)
		if absf(rn.z) > 0.01:
			var hit := ro + rn * ((0.0 - ro.z) / rn.z)
			var to_mouse := hit - player.position
			to_mouse.z = 0.0
			if to_mouse.length() > 0.5:
				aim_dir = to_mouse.normalized()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return Vector2(aim_dir.x, -aim_dir.y)
	if autotest or Input.is_physical_key_pressed(KEY_SPACE):
		return Vector2(aim_dir.x, -aim_dir.y)
	return Vector2.ZERO


# ---------------------------------------------------------------- loop


func _process(scaled_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := minf((now - last_ticks) / 1000000.0, 0.1)
	last_ticks = now
	clock += real_dt
	_update_time_scale(real_dt)
	var delta := minf(scaled_delta, 0.05)

	if state == State.PLAY:
		_update_player(delta)
		_update_spawning(delta)
		_update_bullets(delta)
		_update_enemies(delta)
		combo_timer -= delta
		if combo_timer <= 0.0 and combo > 0:
			combo = 0
			Events.score_changed.emit(score, combo)
	elif state == State.DEAD:
		dead_timer -= real_dt
		_update_bullets(delta)
		if dead_timer <= 0.0 and sub_label.text == "":
			sub_label.text = (
				"SCORE %d    BEST %d\n\nPress any key, click or tap to retry" % [score, best]
			)
		if autotest and dead_timer <= 0.0:
			_start_game()
	else:
		player.step(minf(real_dt, 0.05), Vector3.ZERO, facing)
		player.body.rotation.y = -PI / 2.0 + sin(clock * 0.8) * 0.6

	_update_effects(delta)
	_update_camera(real_dt)
	_wrap_clouds()
	hud.queue_redraw()


func _update_time_scale(real_dt: float) -> void:
	if hitstop > 0.0:
		hitstop -= real_dt
		Engine.time_scale = 0.02
	elif slowmo > 0.0:
		slowmo -= real_dt
		Engine.time_scale = lerpf(1.0, 0.2, clampf(slowmo / 0.9, 0.0, 1.0))
	else:
		Engine.time_scale = 1.0


func _update_player(delta: float) -> void:
	if intro > 0.0:
		intro -= delta
		if intro <= 0.0:
			center_label.text = ""
	var mv := _read_move()
	var target: Vector3
	if mv.length() > 0.15:
		move_dir = Vector3(mv.x, -mv.y, 0).normalized()
		target = Vector3(mv.x, -mv.y, 0) * PLAYER_SPEED
	else:
		target = move_dir * PLAYER_SPEED * DRIFT
	velocity = velocity.lerp(target, 1.0 - exp(-10.0 * delta))
	player.position += velocity * delta

	if absf(velocity.x) > 2.0 and fire_cd < -0.4:
		facing = signf(velocity.x)

	fire_cd -= delta
	var fire := _read_fire()
	if fire.length() > 0.1:
		aim_dir = Vector3(fire.x, -fire.y, 0).normalized()
		if absf(aim_dir.x) > 0.2:
			facing = signf(aim_dir.x)
		if fire_cd <= 0.0:
			_fire()
	player.step(delta, velocity, facing)
	var want := Basis.looking_at(aim_dir, Vector3.BACK)
	player.gun_pivot.basis = (
		player.gun_pivot.basis.slerp(want, 1.0 - exp(-30.0 * delta)).orthonormalized()
	)


func _fire() -> void:
	fire_cd = FIRE_INTERVAL
	var dir := aim_dir.rotated(Vector3.BACK, randf_range(-0.04, 0.04))
	var muzzle := player.gun_pivot.global_transform * Vector3(0, 0, -1.6)
	var b := Bullet.new()
	b.node = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.4, 1.6)
	(b.node as MeshInstance3D).mesh = bm
	(b.node as MeshInstance3D).material_override = _mat(Color(1, 0.96, 0.3), 5.0, true)
	add_child(b.node)
	b.node.position = muzzle
	b.vel = dir * BULLET_SPEED + velocity * BULLET_INHERIT
	b.node.basis = Basis.looking_at(b.vel.normalized(), Vector3.BACK)
	bullets.append(b)

	velocity -= dir * 1.6
	player.impulse(-dir, facing)
	cam_kick -= dir * 0.25
	trauma = minf(trauma + 0.04, 1.0)
	muzzle_light.position = muzzle
	muzzle_light.light_energy = 5.0
	muzzle_flash.position = muzzle
	muzzle_flash.scale = Vector3.ONE * randf_range(0.9, 1.4)
	muzzle_flash.visible = true
	Events.shot_fired.emit(muzzle, dir)


func _update_bullets(delta: float) -> void:
	for b: Bullet in bullets.duplicate():
		b.vel.y -= BULLET_GRAVITY * delta
		b.node.position += b.vel * delta
		b.node.basis = Basis.looking_at(b.vel.normalized(), Vector3.BACK)
		b.life -= delta
		var hit: Enemy = null
		for e in enemies:
			var d := e.node.position - b.node.position
			d.z = 0.0
			if d.length() < e.radius + 0.3:
				hit = e
				break
		if hit != null:
			_damage(hit, b.vel.normalized())
		if hit != null or b.life <= 0.0:
			b.node.queue_free()
			bullets.erase(b)


func _damage(e: Enemy, dir: Vector3) -> void:
	e.hp -= 1
	e.vel += dir * 6.0
	if e.hp > 0:
		e.flash = 0.07
		for m in e.meshes:
			m.material_override = _mat(Color(1, 1, 1), 2.0, true)
		e.node.scale = Vector3.ONE * 1.25
		hitstop = maxf(hitstop, 0.02)
		trauma = minf(trauma + 0.08, 1.0)
		_explode(e.node.position, Color(1, 0.9, 0.5), 8, 0.5)
		Events.enemy_hit.emit(e.node.position)
	else:
		_kill(e, true)


func _kill(e: Enemy, by_player: bool) -> void:
	var p := e.node.position
	enemies.erase(e)
	e.node.queue_free()
	kills += 1
	spawn_limit += 0.34
	spawn_buffer = maxf(0.0, spawn_buffer - 0.08)
	combo = combo + 1 if combo_timer > 0.0 else 1
	combo_timer = COMBO_WINDOW
	var points := 100 * mini(combo, 10) * (3 if e.big else 1)
	score += points
	var col := Color(1.0, 0.6, 0.1) if e.big else Color(1.0, 0.25, 0.35)
	_explode(p, col, 46 if e.big else 30, 1.4 if e.big else 1.0)
	_explode(p, Color(1, 0.95, 0.6), 14, 0.6)
	_ring(p, col, 3.5 if e.big else 2.4)
	_float_text(p, "+%d" % points, col.lightened(0.3))
	var away := player.position - p
	if state == State.PLAY and away.length() < 10.0:
		player.impulse(away.normalized() * (10.0 - away.length()) * 0.25, facing)
	hitstop = maxf(hitstop, 0.09 if e.big else (0.05 if by_player else 0.03))
	trauma = minf(trauma + (0.5 if e.big else 0.28), 1.0)
	fov_punch = maxf(fov_punch, 2.0 + minf(combo, 8))
	Events.enemy_killed.emit(p, points, combo)
	Events.score_changed.emit(score, combo)


func _update_spawning(delta: float) -> void:
	if intro > 0.0:
		return
	wave_timer -= delta
	if wave_timer <= 0.0:
		wave += 1
		wave_timer = WAVE_INTERVAL
		Events.wave_started.emit(wave)
		var base := randf() * TAU
		for i in 3 + wave * 2:
			var a := base + randf_range(-0.5, 0.5)
			_spawn_enemy(a, wave >= 2 and i % 5 == 4)
	spawn_cd -= delta
	if enemies.size() < int(spawn_limit) and spawn_cd <= 0.0:
		_spawn_enemy(randf() * TAU, kills > 12 and randf() < 0.15)
		spawn_cd = randf_range(0.1 + spawn_buffer, 0.8 + spawn_buffer)


func _spawn_enemy(angle: float, big: bool) -> void:
	var e := Enemy.new()
	e.big = big
	e.node = Node3D.new()
	var off := Vector3(cos(angle), sin(angle), 0) * randf_range(SPAWN_DIST, SPAWN_DIST + 4.0)
	e.node.position = player.position + off
	e.node.position.z = 0.0
	add_child(e.node)
	var col := Color(1.0, 0.45, 0.1) if big else Color(0.85, 0.15, 0.3)
	var hull := _mat(col)
	var glow := _mat(Color(1, 0.8, 0.2), 5.0)
	var k := 1.6 if big else 1.0
	var dark := _mat(Color(0.15, 0.17, 0.25))
	e.model = Node3D.new()
	e.model.scale = Vector3.ONE * k
	e.node.add_child(e.model)
	# Forward is +Z, up is +Y (in the play plane), wings span X (edge-on to camera).
	_add_part(e, _cyl(e.model, 0.36, 2.6, Vector3.ZERO, Vector3(PI / 2, 0, 0), hull))
	_add_part(e, _box(e.model, Vector3(0.3, 0.3, 0.5), Vector3(0, 0, 1.45), hull))
	_add_part(e, _box(e.model, Vector3(0.3, 0.28, 0.7), Vector3(0, 0.32, 0.45), dark))
	_add_part(e, _box(e.model, Vector3(3.4, 0.1, 0.8), Vector3(0, -0.05, 0.1), hull))
	_add_part(e, _box(e.model, Vector3(0.1, 0.9, 0.6), Vector3(0, 0.55, -1.05), hull))
	_add_part(e, _box(e.model, Vector3(1.3, 0.08, 0.45), Vector3(0, 0.05, -1.05), hull))
	_add_part(e, _box(e.model, Vector3(0.28, 0.28, 0.2), Vector3(0, 0, -1.35), glow))
	e.hp = 4 if big else 1
	e.radius = 1.6 if big else 1.1
	e.speed = randf_range(5.0, 7.0) if big else randf_range(6.0, 12.0)
	e.turn = 1.5 if big else randf_range(2.0, 4.0)
	e.vel = -off.normalized() * e.speed
	e.node.scale = Vector3.ONE * 0.01
	enemies.append(e)


func _update_enemies(delta: float) -> void:
	for e: Enemy in enemies.duplicate():
		if not enemies.has(e):
			continue
		var to_p := player.position - e.node.position
		to_p.z = 0.0
		if to_p.length() > SPHERE_RADIUS:
			e.node.queue_free()
			enemies.erase(e)
			continue
		var want := to_p.normalized() * e.speed
		e.vel = e.vel.lerp(want, 1.0 - exp(-e.turn * delta))
		e.node.position += e.vel * delta
		if e.vel.length() > 0.1:
			var fwd := e.vel.normalized()
			var up := Vector3.BACK.cross(fwd)
			if up.y < 0.0:
				up = -up
			var face := Basis.looking_at(-fwd, up)
			e.model.basis = e.model.basis.orthonormalized().slerp(face, 1.0 - exp(-10.0 * delta))
			e.model.scale = Vector3.ONE * (1.6 if e.big else 1.0)
		e.node.scale = e.node.scale.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))
		if e.flash > 0.0:
			e.flash -= delta
			if e.flash <= 0.0:
				_restore_enemy_mats(e)
		if to_p.length() < e.radius + 1.0:
			_kill(e, false)
			_game_over()
			return
	_enemy_collisions()


func _restore_enemy_mats(e: Enemy) -> void:
	for i in e.meshes.size():
		e.meshes[i].material_override = e.mats[i]


func _add_part(e: Enemy, mi: MeshInstance3D) -> void:
	e.meshes.append(mi)
	e.mats.append(mi.material_override)


func _enemy_collisions() -> void:
	var dead: Array[Enemy] = []
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			var a := enemies[i]
			var b := enemies[j]
			if a.node.scale.x < 0.8 or b.node.scale.x < 0.8:
				continue
			if a.node.position.distance_to(b.node.position) < (a.radius + b.radius) * 0.6:
				if not dead.has(a):
					dead.append(a)
				if not dead.has(b):
					dead.append(b)
	for e in dead:
		_kill(e, false)


# ---------------------------------------------------------------- juice


func _explode(pos: Vector3, color: Color, amount: int, size: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.75
	p.mesh = particle_mesh
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 7.0 * size
	p.initial_velocity_max = 26.0 * size
	p.damping_min = 10.0
	p.damping_max = 20.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 1.5 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0))
	g.add_point(0.25, color)
	p.color_ramp = g
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2, true, false, true).timeout.connect(p.queue_free)

	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 8.0 * size
	light.light_energy = 6.0
	light.position = pos + Vector3(0, 0, 2.5)
	add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(light.queue_free)


func _ring(pos: Vector3, color: Color, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color.lightened(0.4)
	mi.material_override = m
	mi.position = pos
	mi.rotation.x = PI / 2.0
	mi.scale = Vector3.ONE * 0.3
	add_child(mi)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.3).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_EXPO
	)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)


func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.012
	l.outline_size = 16
	l.modulate = color
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos + Vector3(0, 1.0, 2.0)
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 3.5, 0.7).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_CUBIC
	)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _update_effects(delta: float) -> void:
	muzzle_light.light_energy = move_toward(muzzle_light.light_energy, 0.0, delta * 60.0)
	if muzzle_flash.visible:
		muzzle_flash.scale *= 0.6
		if muzzle_flash.scale.x < 0.15:
			muzzle_flash.visible = false


func _update_camera(real_dt: float) -> void:
	var look := velocity * 0.22 + aim_dir * 1.5
	if state == State.PLAY:
		cam_focus = cam_focus.lerp(player.position + look, 1.0 - exp(-4.0 * real_dt))
	trauma = maxf(0.0, trauma - real_dt * 1.5)
	var s := trauma * trauma
	var t := clock * 40.0
	var off := Vector3(shake_noise.get_noise_2d(t, 0), shake_noise.get_noise_2d(0, t), 0) * s * 2.2
	cam_kick = cam_kick.lerp(Vector3.ZERO, 1.0 - exp(-18.0 * real_dt))
	cam.position = cam_focus + CAM_OFFSET + off + cam_kick
	cam.rotation = Vector3(0, 0, shake_noise.get_noise_2d(t, t) * s * 0.08)
	fov_punch = lerpf(fov_punch, 0.0, 1.0 - exp(-8.0 * real_dt))
	cam.fov = 60.0 - fov_punch


func _wrap_clouds() -> void:
	var c := cam_focus
	for cl in clouds:
		var d := cl.position - c
		if d.x > CLOUD_SPAN.x * 0.5:
			cl.position.x -= CLOUD_SPAN.x
		elif d.x < -CLOUD_SPAN.x * 0.5:
			cl.position.x += CLOUD_SPAN.x
		if d.y > CLOUD_SPAN.y * 0.5:
			cl.position.y -= CLOUD_SPAN.y
		elif d.y < -CLOUD_SPAN.y * 0.5:
			cl.position.y += CLOUD_SPAN.y
	var sky := get_node("Sky") as Node3D
	sky.position.x = c.x
	sky.position.y = c.y * 0.6


# ---------------------------------------------------------------- HUD


func _on_score_changed(new_score: int, new_combo: int) -> void:
	score_label.text = "SCORE %d" % new_score
	combo_label.text = "x%d COMBO" % new_combo if new_combo > 1 else ""
	score_label.scale = Vector2.ONE * 1.35
	var tw := create_tween()
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	if new_combo > 1:
		combo_label.scale = Vector2.ONE * (1.2 + 0.05 * new_combo)
		tw.parallel().tween_property(combo_label, "scale", Vector2.ONE, 0.2)


func _on_wave_started(number: int) -> void:
	center_label.text = "WAVE %d" % number
	center_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(center_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_clear_center)


func _clear_center() -> void:
	if state == State.PLAY:
		center_label.text = ""
	center_label.modulate.a = 1.0


func _draw_hud() -> void:
	var rect := Rect2(Vector2.ZERO, hud.size)
	if state == State.PLAY:
		var center := rect.size * 0.5
		var inner := rect.grow(-28.0)
		for e in enemies:
			var sp := cam.unproject_position(e.node.position)
			if rect.has_point(sp):
				continue
			var dir := (sp - center).normalized()
			var edge := _clamp_to_rect(center, dir, inner)
			var dist := player.position.distance_to(e.node.position)
			var sz := clampf(22.0 - dist * 0.35, 9.0, 18.0)
			var col := Color(1, 0.6, 0.1) if e.big else Color(1, 0.3, 0.4)
			var pts := PackedVector2Array(
				[
					edge + dir * sz,
					edge + dir.orthogonal() * sz * 0.6,
					edge - dir.orthogonal() * sz * 0.6
				]
			)
			hud.draw_colored_polygon(pts, col)
		if combo > 1:
			var w := 220.0 * clampf(combo_timer / COMBO_WINDOW, 0.0, 1.0)
			hud.draw_rect(Rect2(center.x - w * 0.5, 112, w, 6), Color(1, 0.85, 0.2, 0.9))
	_draw_stick(touch_move_id, touch_move_origin, touch_move_vec)
	_draw_stick(touch_aim_id, touch_aim_origin, touch_aim_vec)


func _draw_stick(id: int, origin: Vector2, vec: Vector2) -> void:
	if id < 0:
		return
	hud.draw_circle(origin, STICK_RANGE, Color(1, 1, 1, 0.12))
	hud.draw_arc(origin, STICK_RANGE, 0, TAU, 48, Color(1, 1, 1, 0.4), 3.0)
	hud.draw_circle(origin + vec * STICK_RANGE, 30.0, Color(1, 1, 1, 0.45))


func _clamp_to_rect(center: Vector2, dir: Vector2, r: Rect2) -> Vector2:
	var tx := INF
	var ty := INF
	if absf(dir.x) > 0.0001:
		tx = ((r.end.x if dir.x > 0 else r.position.x) - center.x) / dir.x
	if absf(dir.y) > 0.0001:
		ty = ((r.end.y if dir.y > 0 else r.position.y) - center.y) / dir.y
	return center + dir * minf(tx, ty)
