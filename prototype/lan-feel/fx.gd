extends Node3D
## PROTOTYPE world-space juice: explosions, shock rings and floating score text.

var particle_mesh: BoxMesh


func _ready() -> void:
	particle_mesh = BoxMesh.new()
	particle_mesh.size = Vector3(0.5, 0.5, 0.5)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.vertex_color_use_as_albedo = true
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_mesh.material = pmat


func explode(pos: Vector3, color: Color, amount: int, size: float) -> void:
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


func ring(pos: Vector3, color: Color, radius: float) -> void:
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


func float_text(pos: Vector3, text: String, color: Color, size: int = 72) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
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
