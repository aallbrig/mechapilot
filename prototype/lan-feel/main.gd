extends Node3D
## PROTOTYPE: throwaway LAN feel test for Mecha Fighter. Never merge to main.
## Everything is built in code from primitive meshes. Play plane is XY (z = 0),
## seen side-on by a camera looking along -Z. The mech lives in mech.gd, the HUD in
## hud.gd, the front end in menu.gd and world juice in fx.gd.

enum State { ATTRACT, PLAY, RESPAWN, OVER }

## Global pace: speeds scale by this, accelerations by its square.
const GAME_SPEED := 0.75
const PLAYER_SPEED := 11.0 * GAME_SPEED
## With no move input: gentle fall toward a terminal speed, and horizontal drag.
const COAST_GRAVITY := 7.0
const COAST_TERMINAL_FALL := 6.0
const COAST_DRAG := 0.25
const FIRE_INTERVAL := 0.1
const BULLET_SPEED := 46.0 * GAME_SPEED
const BULLET_LIFE := 1.4 / GAME_SPEED
## Downward pull on player shots, in units/s^2. 0 = laser-straight.
const BULLET_GRAVITY := 20.0 * GAME_SPEED * GAME_SPEED
## Share of the mech's velocity a shot inherits.
const BULLET_INHERIT := 0.6
const SPHERE_RADIUS := 40.0
const SPAWN_DIST := 25.0
## Visual scale of the player mech; the contact radius scales with it.
const MECH_SCALE := 0.85
const CAMERA_DISTANCE := 34.0
## Fraction of the screen (width and height) where the mech moves without the camera.
const CAMERA_DEADZONE := 0.2
## Critically damped follow rate outside the dead zone (1/s). Lower = lazier.
const CAMERA_FOLLOW := 2.3
## Seconds of velocity the camera leads by.
const CAMERA_LOOKAHEAD := 0.25
## Seconds for the camera to settle the mech back to centre once its velocity is steady.
const CAMERA_RECENTER := 1.2
## Right-side touch: a tap is shorter and shorter-travelled than these.
const TAP_TIME := 0.18
const TAP_SLOP := 12.0
const CAM_OFFSET := Vector3(0, 0, CAMERA_DISTANCE)
const START_LIVES := 3
const BONUS_LIFE_SCORE := 100000
## false: the bonus life is awarded once. true: every BONUS_LIFE_SCORE points.
const BONUS_LIFE_REPEATS := false
const INVULN_TIME := 2.0
const RESPAWN_DELAY := 1.6
const ATTRACT_ENEMIES := 3
const WAVE_INTERVAL := 14.0
const COMBO_WINDOW := 1.6
const CLOUD_SPAN := Vector2(230.0, 150.0)
const STICK_RANGE := 70.0
const Mech := preload("res://mech.gd")
const Hud := preload("res://hud.gd")
const Menu := preload("res://menu.gd")
const Fx := preload("res://fx.gd")
const Vapor := preload("res://vapor.gd")
const Bot := preload("res://bot.gd")
const Scores := preload("res://scores.gd")
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


var state := State.ATTRACT
var player: Mech
var hud: Hud
var menu: Menu
var fx: Fx
var vapor: Vapor
var velocity := Vector3.ZERO
var move_dir := Vector3(0, 1, 0)
var aim_dir := Vector3(1, 0, 0)
var facing := 1.0
var thrust := 0.0
var fire_cd := 0.0
var bullets: Array[Bullet] = []
var enemies: Array[Enemy] = []
var clouds: Array[Node3D] = []
var score := 0
var lives := START_LIVES
var next_bonus := BONUS_LIFE_SCORE
var invuln := 0.0
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
var state_timer := 0.0
var fov_punch := 0.0
var cam_kick := Vector3.ZERO
var cam_focus := Vector3.ZERO
var cam_goal := Vector3.ZERO
var cam_vel := Vector3.ZERO
var clock := 0.0
var last_ticks := 0
var mouse_aim := false
var last_touch_time := -10.0
var touch_aim_start := 0.0
var touch_aim_holding := false
var tap_shot := false
var last_velocity := Vector3.ZERO
var steady := 0.0
var touch_move_id := -1
var touch_move_origin := Vector2.ZERO
var touch_move_vec := Vector2.ZERO
var touch_aim_id := -1
var touch_aim_origin := Vector2.ZERO
var touch_aim_vec := Vector2.ZERO
var cam: Camera3D
var muzzle_light: OmniLight3D
var muzzle_flash: MeshInstance3D
var shake_noise := FastNoiseLite.new()
var mat_cache := {}
var autotest := false
var auto_t := 0.0
var auto_screen := -1
var auto_peak := 0.0
## Stills only: --cam=<distance> overrides the camera distance.
var cam_offset := CAM_OFFSET
var cam_lock := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	shake_noise.frequency = 0.5
	last_ticks = Time.get_ticks_usec()
	autotest = OS.get_cmdline_user_args().has("--autotest")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			cam_offset = Vector3(0, 0, arg.trim_prefix("--cam=").to_float())
			cam_lock = true
	_build_world()
	fx = Fx.new()
	add_child(fx)
	vapor = Vapor.new()
	add_child(vapor)
	_build_player()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	menu = Menu.new()
	add_child(menu)
	menu.play_requested.connect(_start_game)
	menu.main_shown.connect(_on_menu_main)
	menu.initials_entered.connect(_on_initials)
	menu.show_main()


func is_playing() -> bool:
	return state == State.PLAY or state == State.RESPAWN


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


func _cyl(
	parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(PI / 2, 0, 0)
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
	for i in 60:
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


func _build_player() -> void:
	player = Mech.new()
	player.scale = Vector3.ONE * MECH_SCALE
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


# ---------------------------------------------------------------- states


func _clear_world() -> void:
	for e in enemies:
		e.node.queue_free()
	enemies.clear()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	slowmo = 0.0
	hitstop = 0.0
	Engine.time_scale = 1.0
	player.position = Vector3.ZERO
	player.reset()
	player.visible = true
	vapor.clear()
	move_dir = Vector3(0, 1, 0)
	aim_dir = Vector3(1, 0, 0)
	facing = 1.0
	velocity = Vector3(5.0 * GAME_SPEED, 0, 0)
	cam_focus = Vector3.ZERO
	cam_goal = Vector3.ZERO
	cam_vel = Vector3.ZERO
	combo = 0
	combo_timer = 0.0
	kills = 0
	wave = 0
	invuln = 0.0
	spawn_cd = 0.0
	spawn_buffer = 1.2


func _on_menu_main() -> void:
	if state != State.ATTRACT:
		_start_attract()


## Live demo behind the menu: AI flies, nobody dies, nothing scores.
func _start_attract() -> void:
	_clear_world()
	state = State.ATTRACT
	spawn_limit = ATTRACT_ENEMIES
	intro = 0.0
	hud.clear()


func _start_game() -> void:
	_clear_world()
	state = State.PLAY
	score = 0
	lives = START_LIVES
	next_bonus = BONUS_LIFE_SCORE
	wave_timer = WAVE_INTERVAL * 0.6
	spawn_limit = 2.0
	intro = 1.6
	hud.clear()
	hud.banner("GET READY", 1.2)
	Events.score_changed.emit(score, combo)
	Events.game_started.emit()
	if autotest:
		print("autotest: play started lives=%d" % lives)


func _player_hit() -> void:
	lives -= 1
	if autotest:
		print("autotest: life lost score=%d lives_left=%d" % [score, lives])
	Events.player_died.emit(player.global_position)
	Events.life_lost.emit(lives)
	var p := player.global_position
	fx.explode(p, Color(0.3, 0.9, 1.0), 90, 1.8)
	fx.explode(p, Color(1.0, 0.6, 0.1), 60, 1.3)
	player.shatter(velocity)
	vapor.clear()
	trauma = 1.0
	slowmo = 0.9
	fov_punch = 14.0
	for i in enemies.size():
		var t := get_tree().create_timer(0.12 + i * 0.07, true, false, true)
		t.timeout.connect(_pop_enemy.bind(enemies[i]))
	if lives > 0:
		state = State.RESPAWN
		state_timer = RESPAWN_DELAY
	else:
		state = State.OVER
		state_timer = 2.2
		hud.banner("GAME OVER", 1.6)


func _respawn() -> void:
	state = State.PLAY
	player.reset()
	player.visible = true
	velocity = Vector3.ZERO
	invuln = INVULN_TIME
	hud.banner("%d LEFT" % lives if lives > 1 else "LAST LIFE", 0.8)


func _after_game_over() -> void:
	hud.clear()
	if Scores.qualifies(score):
		menu.show_initials(score)
	else:
		menu.show_board(-1)


func _on_initials(initials: String) -> void:
	var rank := Scores.submit(initials, score)
	if autotest:
		print("autotest: initials %s rank=%d" % [initials, rank])
	menu.show_board(rank)


func _pop_enemy(e: Enemy) -> void:
	if not is_instance_valid(e.node):
		return
	fx.explode(e.node.position, Color(1, 0.3, 0.4), 30, 0.9)
	trauma = minf(trauma + 0.15, 1.0)
	e.node.queue_free()
	enemies.erase(e)


# ---------------------------------------------------------------- input


func _input(event: InputEvent) -> void:
	if menu.is_open():
		return
	if event.is_action_pressed("ui_cancel") and state != State.ATTRACT:
		get_viewport().set_input_as_handled()
		menu.show_main()
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_touch_time = clock
		mouse_aim = false
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == touch_move_id:
			touch_move_vec = ((sd.position - touch_move_origin) / STICK_RANGE).limit_length(1.0)
		elif sd.index == touch_aim_id:
			touch_aim_vec = ((sd.position - touch_aim_origin) / STICK_RANGE).limit_length(1.0)
			if sd.position.distance_to(touch_aim_origin) > TAP_SLOP:
				touch_aim_holding = true
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		# Browsers send compatibility mouse events after touches; ignore those.
		if clock - last_touch_time > 1.0:
			mouse_aim = true


## Touches are tracked by index. Left half: move stick only, never fires.
## Right half: a quick tap fires one shot at the tapped point; holding turns
## into a stick anchored at the touch-down point.
func _on_touch(st: InputEventScreenTouch) -> void:
	if st.pressed:
		if st.position.x < hud.size.x * 0.5:
			if touch_move_id < 0:
				touch_move_id = st.index
				touch_move_origin = st.position
				touch_move_vec = Vector2.ZERO
		elif touch_aim_id < 0:
			touch_aim_id = st.index
			touch_aim_origin = st.position
			touch_aim_vec = Vector2.ZERO
			touch_aim_start = clock
			touch_aim_holding = false
		return
	if st.index == touch_move_id:
		touch_move_id = -1
		touch_move_vec = Vector2.ZERO
	elif st.index == touch_aim_id:
		var quick := clock - touch_aim_start < TAP_TIME
		if not touch_aim_holding and quick and st.position.distance_to(touch_aim_origin) < TAP_SLOP:
			var hit := _screen_to_plane(st.position)
			var to_tap := hit - player.position
			to_tap.z = 0.0
			if to_tap.length() > 0.3:
				aim_dir = to_tap.normalized()
				tap_shot = true
		touch_aim_id = -1
		touch_aim_vec = Vector2.ZERO
		touch_aim_holding = false


func _screen_to_plane(sp: Vector2) -> Vector3:
	var ro := cam.project_ray_origin(sp)
	var rn := cam.project_ray_normal(sp)
	if absf(rn.z) < 0.01:
		return player.position
	return ro + rn * ((0.0 - ro.z) / rn.z)


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
		var turn := floorf(clock / 0.9) * PI * 0.5
		v = Vector2(cos(turn), sin(turn))
		v *= float(fmod(clock, 3.5) < 2.0)
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
	if touch_aim_id >= 0 and not touch_aim_holding and clock - touch_aim_start > TAP_TIME:
		touch_aim_holding = true
	if touch_aim_holding and touch_aim_vec.length() > 0.15:
		return touch_aim_vec.normalized()
	if mouse_aim and touch_aim_id < 0 and clock - last_touch_time >= 1.0:
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
	if Input.is_physical_key_pressed(KEY_SPACE):
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

	match state:
		State.ATTRACT, State.PLAY:
			_update_player(delta)
			_update_spawning(delta)
			_update_bullets(delta)
			_update_enemies(delta)
			combo_timer -= delta
			if combo_timer <= 0.0 and combo > 0:
				combo = 0
				Events.score_changed.emit(score, combo)
		State.RESPAWN:
			state_timer -= real_dt
			_update_bullets(delta)
			if state_timer <= 0.0:
				_respawn()
		State.OVER:
			_update_bullets(delta)
			if state_timer > 0.0:
				state_timer -= real_dt
				if state_timer <= 0.0:
					_after_game_over()

	if autotest:
		_autotest_step(real_dt)
	_update_effects(delta)
	_update_camera(real_dt)
	_wrap_clouds()


## Drives the whole menu -> play -> lose all lives -> initials -> board loop.
func _autotest_step(real_dt: float) -> void:
	if menu.screen != auto_screen:
		auto_screen = menu.screen
		auto_t = 0.0
		print(
			(
				"autotest: screen=%d state=%d frame=%d"
				% [menu.screen, state, Engine.get_frames_drawn()]
			)
		)
	auto_t += real_dt
	auto_peak = maxf(auto_peak, player.lateral_g)
	if cam_lock and Engine.get_frames_drawn() % 10 == 0:
		print(
			(
				"still: frame=%d fly=%.2f vapor=%.2f"
				% [Engine.get_frames_drawn(), player.fly, vapor.strength]
			)
		)
	if int(clock / 2.0) != int((clock - real_dt) / 2.0):
		print("autotest: peak lateral_g=%.1f vapor=%.2f" % [auto_peak, vapor.strength])
		auto_peak = 0.0
	if menu.screen == Menu.Screen.MAIN and auto_t > 3.0:
		menu.request_play()
	elif menu.screen == Menu.Screen.INITIALS and auto_t > 2.0:
		menu.submit_initials("BOT")
	elif menu.screen == Menu.Screen.BOARD and auto_t > 3.0:
		print("autotest: leaderboard rows=%d" % Scores.load_rows().size())
		menu.show_main()


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
	if invuln > 0.0:
		invuln -= delta
		player.visible = invuln <= 0.0 or fmod(invuln * 10.0, 1.0) > 0.35
	var mv := Bot.move(self, clock) if state == State.ATTRACT else _read_move()
	thrust = mv.length()
	if mv.length() > 0.15:
		move_dir = Vector3(mv.x, -mv.y, 0).normalized()
		var target := Vector3(mv.x, -mv.y, 0) * PLAYER_SPEED
		velocity = velocity.lerp(target, 1.0 - exp(-10.0 * delta))
	else:
		# Coasting: keep horizontal momentum, fall gently toward a terminal speed.
		velocity.x *= exp(-COAST_DRAG * delta)
		velocity.y = maxf(velocity.y - COAST_GRAVITY * delta, -COAST_TERMINAL_FALL)
	player.position += velocity * delta

	if absf(velocity.x) > 2.0 and fire_cd < -0.4:
		facing = signf(velocity.x)

	fire_cd -= delta
	var fire := _read_fire()
	if state == State.ATTRACT:
		fire = Bot.fire(self, clock, BULLET_SPEED, BULLET_GRAVITY)
	if fire.length() > 0.1:
		aim_dir = Vector3(fire.x, -fire.y, 0).normalized()
		if absf(aim_dir.x) > 0.2:
			facing = signf(aim_dir.x)
		if fire_cd <= 0.0:
			_fire()
	elif tap_shot:
		if absf(aim_dir.x) > 0.2:
			facing = signf(aim_dir.x)
		_fire()
	tap_shot = false
	player.step(delta, velocity, facing, thrust)
	vapor.update(
		delta,
		player.global_position,
		velocity,
		player.lateral_g,
		player.wing_tip_positions(),
		MECH_SCALE
	)
	var want := Basis.looking_at(aim_dir, Vector3.BACK)
	player.gun_pivot.basis = (
		player.gun_pivot.basis.slerp(want, 1.0 - exp(-30.0 * delta)).orthonormalized()
	)


func _fire() -> void:
	fire_cd = FIRE_INTERVAL * (1.6 if state == State.ATTRACT else 1.0)
	var dir := aim_dir.rotated(Vector3.BACK, randf_range(-0.04, 0.04))
	var muzzle := player.muzzle_position()
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

	velocity -= dir * 1.6 * GAME_SPEED
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
	e.vel += dir * 6.0 * GAME_SPEED
	if e.hp > 0:
		e.flash = 0.07
		for m in e.meshes:
			m.material_override = _mat(Color(1, 1, 1), 2.0, true)
		e.node.scale = Vector3.ONE * 1.25
		hitstop = maxf(hitstop, 0.02)
		trauma = minf(trauma + 0.08, 1.0)
		fx.explode(e.node.position, Color(1, 0.9, 0.5), 8, 0.5)
		Events.enemy_hit.emit(e.node.position)
	else:
		_kill(e, true)


func _kill(e: Enemy, by_player: bool) -> void:
	var p := e.node.position
	enemies.erase(e)
	e.node.queue_free()
	var col := Color(1.0, 0.6, 0.1) if e.big else Color(1.0, 0.25, 0.35)
	fx.explode(p, col, 46 if e.big else 30, 1.4 if e.big else 1.0)
	fx.explode(p, Color(1, 0.95, 0.6), 14, 0.6)
	fx.ring(p, col, 3.5 if e.big else 2.4)
	var away := player.position - p
	if away.length() < 10.0:
		player.impulse(away.normalized() * (10.0 - away.length()) * 0.25, facing)
	hitstop = maxf(hitstop, 0.09 if e.big else (0.05 if by_player else 0.03))
	trauma = minf(trauma + (0.5 if e.big else 0.28), 1.0)
	fov_punch = maxf(fov_punch, 2.0 + minf(combo, 8))
	if state == State.ATTRACT:
		Events.enemy_killed.emit(p, 0, 1)
		return
	kills += 1
	spawn_limit += 0.34
	spawn_buffer = maxf(0.0, spawn_buffer - 0.08)
	combo = combo + 1 if combo_timer > 0.0 else 1
	combo_timer = COMBO_WINDOW
	var points := 100 * mini(combo, 10) * (3 if e.big else 1)
	score += points
	fx.float_text(p, "+%d" % points, col.lightened(0.3))
	Events.enemy_killed.emit(p, points, combo)
	Events.score_changed.emit(score, combo)
	if score >= next_bonus:
		lives += 1
		next_bonus = next_bonus + BONUS_LIFE_SCORE if BONUS_LIFE_REPEATS else 1 << 62
		fx.float_text(player.position, "1UP!", Color(0.4, 1, 0.5), 110)
		Events.extra_life.emit(lives)


func _update_spawning(delta: float) -> void:
	if intro > 0.0:
		return
	if state == State.PLAY:
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
	var dark := _mat(Color(0.15, 0.17, 0.25))
	e.model = Node3D.new()
	e.model.scale = Vector3.ONE * (1.6 if big else 1.0)
	e.node.add_child(e.model)
	# Forward is +Z, up is +Y (in the play plane), wings span X (edge-on to camera).
	_add_part(e, _cyl(e.model, 0.36, 2.6, Vector3.ZERO, hull))
	_add_part(e, _box(e.model, Vector3(0.3, 0.3, 0.5), Vector3(0, 0, 1.45), hull))
	_add_part(e, _box(e.model, Vector3(0.3, 0.28, 0.7), Vector3(0, 0.32, 0.45), dark))
	_add_part(e, _box(e.model, Vector3(3.4, 0.1, 0.8), Vector3(0, -0.05, 0.1), hull))
	_add_part(e, _box(e.model, Vector3(0.1, 0.9, 0.6), Vector3(0, 0.55, -1.05), hull))
	_add_part(e, _box(e.model, Vector3(1.3, 0.08, 0.45), Vector3(0, 0.05, -1.05), hull))
	_add_part(e, _box(e.model, Vector3(0.28, 0.28, 0.2), Vector3(0, 0, -1.35), glow))
	e.hp = 4 if big else 1
	e.radius = 1.6 if big else 1.1
	e.speed = (randf_range(5.0, 7.0) if big else randf_range(6.0, 12.0)) * GAME_SPEED
	e.turn = (1.5 if big else randf_range(2.0, 4.0)) * GAME_SPEED
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
		if to_p.length() < e.radius + 0.47 * MECH_SCALE:
			_kill(e, false)
			if state == State.PLAY and invuln <= 0.0:
				_player_hit()
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


# ---------------------------------------------------------------- camera and sky


func _update_effects(delta: float) -> void:
	muzzle_light.light_energy = move_toward(muzzle_light.light_energy, 0.0, delta * 60.0)
	if muzzle_flash.visible:
		muzzle_flash.scale *= 0.6
		if muzzle_flash.scale.x < 0.15:
			muzzle_flash.visible = false


func _deadzone_excess(d: float, half: float) -> float:
	if absf(d) <= half:
		return 0.0
	return d - signf(d) * half


## Lazy camera: the goal only moves when the mech leaves a central dead zone, and
## the camera chases the goal with a critically damped spring.
func _update_camera(real_dt: float) -> void:
	if state == State.ATTRACT or state == State.PLAY:
		var half_h := tan(deg_to_rad(30.0)) * CAMERA_DISTANCE
		var aspect := hud.size.x / maxf(hud.size.y, 1.0)
		var dz := Vector2(half_h * aspect, half_h) * CAMERA_DEADZONE
		var desired := player.position + velocity * CAMERA_LOOKAHEAD
		cam_goal.x += _deadzone_excess(desired.x - cam_goal.x, dz.x)
		cam_goal.y += _deadzone_excess(desired.y - cam_goal.y, dz.y)
		# Steady or slow velocity: ease the goal back so the mech returns to centre.
		var smooth := last_velocity.lerp(velocity, 1.0 - exp(-5.0 * real_dt))
		var accel := (smooth - last_velocity).length() / maxf(real_dt, 0.001)
		last_velocity = smooth
		var calm := 1.0 - clampf(accel / (20.0 * GAME_SPEED), 0.0, 1.0)
		calm = maxf(calm, 1.0 - clampf(velocity.length() / 3.0, 0.0, 1.0))
		steady = lerpf(steady, calm, 1.0 - exp(-4.0 * real_dt))
		var rate := 3.0 / CAMERA_RECENTER
		cam_goal = cam_goal.lerp(desired, (1.0 - exp(-rate * real_dt)) * steady)
	if cam_lock:
		cam_goal = player.position
	var w := CAMERA_FOLLOW * (4.0 if cam_lock else 1.0)
	cam_vel += (w * w * (cam_goal - cam_focus) - 2.0 * w * cam_vel) * real_dt
	cam_focus += cam_vel * real_dt
	trauma = maxf(0.0, trauma - real_dt * 1.5)
	var s := trauma * trauma
	var t := clock * 40.0
	var off := Vector3(shake_noise.get_noise_2d(t, 0), shake_noise.get_noise_2d(0, t), 0) * s * 2.2
	cam_kick = cam_kick.lerp(Vector3.ZERO, 1.0 - exp(-18.0 * real_dt))
	cam.position = cam_focus + cam_offset + off + cam_kick
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
