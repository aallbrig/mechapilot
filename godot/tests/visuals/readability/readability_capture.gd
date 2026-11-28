class_name ReadabilityCapture
extends Node
## Renders the enemy readability frames (#135) with the game's real renderer:
## every enemy kind and the player mech, one at a time, in front of every
## Level's sky (its SkyLibrary scene: the Environment's sky, ambient light,
## fog and glow, the sun and the cloud layers), seen through the gameplay
## CameraRig at a phone's portrait aspect, at three heights on screen. A second
## viewport renders the same subject from the same camera in the flat hit-flash
## white on a transparent background: that matte says which pixels are the
## silhouette. The pixels of the silhouette and of a ring of sky around it are
## saved for ReadabilityFrames, with ReadabilityFingerprint's fingerprint.
##
## The headless tests have no GPU, so this runs only through
## scripts/godot-capture-readability (`task godot:capture:readability`), on a
## machine with a display. It writes user://readability_captures.json, a
## labelled contact sheet of the frames (worst contrast first) to
## user://readability_contact_sheet.png, and user://readability_done.txt last.

## The phone portrait viewport the frames are rendered at (9:19.5).
const VIEW_SIZE: Vector2i = Vector2i(720, 1560)
## Where the subject sits on the play plane, relative to the camera's focus:
## high, level and low on screen (the sky's gradient runs top to bottom).
const SPOTS: Array[Vector2] = [Vector2(0.0, 16.0), Vector2(0.0, 0.0), Vector2(0.0, -16.0)]
## Frames to let a new subject settle (bake, glow) before reading the frame.
const SETTLE_FRAMES: int = 4
## The ring of sky measured around the silhouette, in pixels from its edge.
const RING_INNER: int = 3
const RING_OUTER: int = 14
## The most pixels kept of each silhouette and ring (evenly strided).
const MAX_PIXELS: int = 400
## A matte pixel at or above this alpha is part of the silhouette.
const MATTE_ALPHA: int = 128
## Contact sheet: square crops this size, in this many columns.
const TILE: int = 160
const SHEET_COLUMNS: int = 9

var _rows: Array[String] = []
var _tiles: Array[Dictionary] = []


func _ready() -> void:
	await _run()


func _run() -> void:
	var errors: Array[String] = []
	var levels: Array[LevelDefinition] = LevelLibrary.all_levels(errors)
	for error: String in errors:
		push_error("ReadabilityCapture: %s" % error)
	for level: LevelDefinition in levels:
		await _capture_level(level)
	_write_captures()
	await _write_sheet()
	_report()
	var done: FileAccess = FileAccess.open("user://readability_done.txt", FileAccess.WRITE)
	if done != null:
		var _stored: bool = done.store_line("%d samples" % _rows.size())
		done.close()


func _capture_level(level: LevelDefinition) -> void:
	var scene: SubViewport = _viewport(false)
	var matte: SubViewport = _viewport(true)
	add_child(scene)
	add_child(matte)
	var sky: SkyEnvironment = SkyLibrary.for_level(level)
	scene.add_child(sky)
	var rig: CameraRig = CameraRig.new()
	# The rig reads the window's aspect every frame; this viewport has its own.
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	scene.add_child(rig)
	rig.set_view_aspect(float(VIEW_SIZE.x) / float(VIEW_SIZE.y))
	rig.snap_to(Vector3.ZERO)
	var camera: Camera3D = rig.camera()
	camera.current = true
	sky.follow(camera.global_position)
	var matte_camera: Camera3D = Camera3D.new()
	matte.add_child(matte_camera)
	matte_camera.global_transform = camera.global_transform
	matte_camera.fov = camera.fov
	matte_camera.near = camera.near
	matte_camera.far = camera.far
	matte_camera.current = true
	for spot: int in SPOTS.size():
		for subject: StringName in subjects():
			var shown: Node3D = _subject(subject)
			var outline: Node3D = _subject(subject)
			shown.position = Vector3(SPOTS[spot].x, SPOTS[spot].y, 0.0)
			outline.position = shown.position
			scene.add_child(shown)
			matte.add_child(outline)
			_flash(outline)
			for _frame: int in SETTLE_FRAMES:
				await RenderingServer.frame_post_draw
			var frame: Image = scene.get_texture().get_image()
			var mask: Image = matte.get_texture().get_image()
			_keep(level, subject, spot, frame, mask)
			shown.free()
			outline.free()
	scene.free()
	matte.free()


## Every enemy id (EnemyKind.IDS) and then the player.
static func subjects() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(EnemyKind.IDS)
	out.append(ReadabilityFrames.PLAYER)
	return out


func _viewport(transparent: bool) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return viewport


## The subject as the game builds it: an enemy's EnemyLook at its kind's
## look_scale, or the player's MechModel at the tuning's mech_scale, facing +X.
func _subject(subject: StringName) -> Node3D:
	if subject == ReadabilityFrames.PLAYER:
		var mech: MechModel = MechModel.new()
		mech.scale = Vector3.ONE * MechTuning.new().mech_scale
		mech.body.rotation.y = MechModel.yaw_for(1.0)
		return mech
	var kind: EnemyKind.Kind = EnemyKind.from_id(subject)
	return EnemyLook.new(kind, EnemyProfile.of(kind).look_scale)


## Turn a subject into its matte: the flat, unshaded hit-flash white.
func _flash(subject: Node3D) -> void:
	var mech: MechModel = subject as MechModel
	if mech != null:
		mech.set_flash(true)
	var look: EnemyLook = subject as EnemyLook
	if look != null:
		look.set_flash(true)


## Measure one frame against its matte and keep the sample.
func _keep(
	level: LevelDefinition, subject: StringName, spot: int, frame: Image, mask: Image
) -> void:
	frame.convert(Image.FORMAT_RGBA8)
	mask.convert(Image.FORMAT_RGBA8)
	var box: Rect2i = _matte_box(mask)
	if box.size == Vector2i.ZERO:
		push_error("ReadabilityCapture: level %d %s is off screen" % [level.number, subject])
		return
	var area: Rect2i = box.grow(RING_OUTER + 1).intersection(Rect2i(Vector2i.ZERO, VIEW_SIZE))
	var inside: PackedByteArray = PackedByteArray()
	var _sized: int = inside.resize(area.size.x * area.size.y)
	for y: int in area.size.y:
		for x: int in area.size.x:
			var alpha: int = mask.get_pixel(area.position.x + x, area.position.y + y).a8
			inside[y * area.size.x + x] = 1 if alpha >= MATTE_ALPHA else 0
	var distance: PackedInt32Array = _distance_from(inside, area.size)
	var silhouette: PackedColorArray = PackedColorArray()
	var sky: PackedColorArray = PackedColorArray()
	for y: int in area.size.y:
		for x: int in area.size.x:
			var i: int = y * area.size.x + x
			var pixel: Color = frame.get_pixel(area.position.x + x, area.position.y + y)
			if inside[i] == 1 and _is_core(inside, area.size, x, y):
				var _s: bool = silhouette.push_back(pixel)
			elif distance[i] >= RING_INNER and distance[i] <= RING_OUTER:
				var _k: bool = sky.push_back(pixel)
	var sample: ReadabilityFrames.Sample = ReadabilityFrames.Sample.new()
	sample.level = level.number
	sample.theme = level.sky_theme
	sample.subject = subject
	sample.spot = spot
	sample.silhouette = _strided(silhouette)
	sample.sky = _strided(sky)
	var row: Dictionary = {
		"level": sample.level,
		"theme": String(sample.theme),
		"subject": String(sample.subject),
		"spot": sample.spot,
		"silhouette": ReadabilityFrames.encode(sample.silhouette),
		"sky": ReadabilityFrames.encode(sample.sky),
	}
	_rows.append(JSON.stringify(row))
	var centre: Vector2i = box.get_center()
	var crop: Rect2i = Rect2i(centre - Vector2i(TILE >> 1, TILE >> 1), Vector2i(TILE, TILE))
	crop.position = crop.position.clamp(Vector2i.ZERO, VIEW_SIZE - crop.size)
	_tiles.append({"sample": sample, "image": frame.get_region(crop)})


## The bounding box of the matte's drawn pixels (empty if none).
static func _matte_box(mask: Image) -> Rect2i:
	return mask.get_used_rect()


## Each pixel's chessboard distance (in pixels) to the nearest inside pixel.
static func _distance_from(inside: PackedByteArray, size: Vector2i) -> PackedInt32Array:
	var far: int = size.x + size.y
	var d: PackedInt32Array = PackedInt32Array()
	var _sized: int = d.resize(inside.size())
	for i: int in inside.size():
		d[i] = 0 if inside[i] == 1 else far
	for y: int in size.y:
		for x: int in size.x:
			var i: int = y * size.x + x
			for n: Vector2i in [
				Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0)
			]:
				var nx: int = x + n.x
				var ny: int = y + n.y
				if nx >= 0 and nx < size.x and ny >= 0:
					d[i] = mini(d[i], d[ny * size.x + nx] + 1)
	for y: int in range(size.y - 1, -1, -1):
		for x: int in range(size.x - 1, -1, -1):
			var i: int = y * size.x + x
			for n: Vector2i in [Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 0)]:
				var nx: int = x + n.x
				var ny: int = y + n.y
				if nx >= 0 and nx < size.x and ny < size.y:
					d[i] = mini(d[i], d[ny * size.x + nx] + 1)
	return d


## Whether an inside pixel's four neighbours are inside too (off its edge,
## where the frame blends the model into the sky).
static func _is_core(inside: PackedByteArray, size: Vector2i, x: int, y: int) -> bool:
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + n.x
		var ny: int = y + n.y
		if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y or inside[ny * size.x + nx] == 0:
			return false
	return true


static func _strided(pixels: PackedColorArray) -> PackedColorArray:
	if pixels.size() <= MAX_PIXELS:
		return pixels
	var out: PackedColorArray = PackedColorArray()
	var step: float = float(pixels.size()) / float(MAX_PIXELS)
	for i: int in MAX_PIXELS:
		var _added: bool = out.push_back(pixels[floori(i * step)])
	return out


func _write_captures() -> void:
	var file: FileAccess = FileAccess.open("user://readability_captures.json", FileAccess.WRITE)
	if file == null:
		push_error("ReadabilityCapture: cannot write the captures")
		return
	var api: String = "gl_compatibility %s" % RenderingServer.get_video_adapter_api_version()
	var text: String = (
		'{\n"fingerprint": %s,\n"renderer": %s,\n"view": [%d, %d],\n"samples": [\n%s\n]\n}\n'
		% [
			JSON.stringify(ReadabilityFingerprint.compute()),
			JSON.stringify(api),
			VIEW_SIZE.x,
			VIEW_SIZE.y,
			",\n".join(_rows),
		]
	)
	var _stored: bool = file.store_string(text)
	file.close()


## The tiles, worst contrast (normal vision) first, each labelled.
func _write_sheet() -> void:
	_tiles.sort_custom(_worse_first)
	var viewport: SubViewport = SubViewport.new()
	var rows: int = ceili(float(_tiles.size()) / float(SHEET_COLUMNS))
	viewport.size = Vector2i(SHEET_COLUMNS * (TILE + 4), rows * (TILE + 40))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var grid: GridContainer = GridContainer.new()
	grid.columns = SHEET_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 0)
	viewport.add_child(grid)
	for tile: Dictionary in _tiles:
		var sample: ReadabilityFrames.Sample = tile["sample"]
		var cell: VBoxContainer = VBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 0)
		var picture: TextureRect = TextureRect.new()
		var image: Image = tile["image"]
		picture.texture = ImageTexture.create_from_image(image)
		cell.add_child(picture)
		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(TILE, 40)
		label.clip_text = true
		label.add_theme_font_size_override(&"font_size", 12)
		label.text = (
			"L%d %s %s s%d\n%.2f:1 (d %.2f p %.2f)"
			% [
				sample.level,
				sample.theme,
				sample.subject,
				sample.spot,
				sample.contrast(ReadabilityFrames.Vision.NORMAL),
				sample.contrast(ReadabilityFrames.Vision.DEUTERANOPIA),
				sample.contrast(ReadabilityFrames.Vision.PROTANOPIA),
			]
		)
		cell.add_child(label)
		grid.add_child(cell)
	for _frame: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var sheet: Image = viewport.get_texture().get_image()
	var _saved: Error = sheet.save_png("user://readability_contact_sheet.png")
	viewport.free()


## The contrast table, worst first, on stdout (one sample per line).
func _report() -> void:
	for tile: Dictionary in _tiles:
		var sample: ReadabilityFrames.Sample = tile["sample"]
		print(
			(
				"readability: %d\t%s\t%s\t%d\t%.2f\t%.2f\t%.2f"
				% [
					sample.level,
					sample.theme,
					sample.subject,
					sample.spot,
					sample.contrast(ReadabilityFrames.Vision.NORMAL),
					sample.contrast(ReadabilityFrames.Vision.DEUTERANOPIA),
					sample.contrast(ReadabilityFrames.Vision.PROTANOPIA),
				]
			)
		)


static func _worse_first(a: Dictionary, b: Dictionary) -> bool:
	var first: ReadabilityFrames.Sample = a["sample"]
	var second: ReadabilityFrames.Sample = b["sample"]
	return (
		first.contrast(ReadabilityFrames.Vision.NORMAL)
		< second.contrast(ReadabilityFrames.Vision.NORMAL)
	)
