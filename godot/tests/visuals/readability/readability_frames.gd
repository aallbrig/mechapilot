class_name ReadabilityFrames
extends RefCounted
## The enemy readability captures (#135) and the measures taken from them.
##
## The headless test run has no GPU (its renderer is a dummy), so the frames are
## rendered by ReadabilityCapture with the game's real renderer, sky, lighting,
## fog, glow and gameplay camera (`task godot:capture:readability`), and saved
## as data in CAPTURES: for every Level, spot on screen and subject (each enemy
## kind and the player mech), the rendered pixels of the subject's silhouette
## and of the sky in a ring around it. The captures carry the fingerprint of the
## render inputs they were made from (ReadabilityFingerprint): when a model,
## material, shader, sky or the camera changes, the captures are stale and the
## readability tests fail until they are captured again.
##
## Pixels are 8-bit sRGB as rendered. Luminance is WCAG relative luminance (of
## linear RGB), and contrast is the WCAG ratio (L1 + 0.05) / (L2 + 0.05).

## Colour vision used to view a frame: normal, or a full-severity dichromacy
## simulated with Machado, Oliveira and Fernandes (2009).
enum Vision { NORMAL, DEUTERANOPIA, PROTANOPIA }

const PLAYER: StringName = &"player"
## Saturation and value a pixel needs to count towards a dominant hue.
const HUE_MIN_SATURATION: float = 0.25
const HUE_MIN_VALUE: float = 0.12
## Width of the hue histogram's bins (degrees).
const HUE_BIN: float = 15.0
## Share of the weighted hue histogram the peak needs to be a dominant hue.
const HUE_MIN_SHARE: float = 0.05
## Machado et al. (2009), severity 1.0, rows of a 3x3 matrix on linear RGB.
const DEUTERANOPIA_MATRIX: PackedFloat32Array = [
	0.367322,
	0.860646,
	-0.227968,
	0.280085,
	0.672501,
	0.047413,
	-0.011820,
	0.042940,
	0.968881,
]
const PROTANOPIA_MATRIX: PackedFloat32Array = [
	0.152286,
	1.052583,
	-0.204868,
	0.114503,
	0.786281,
	0.099216,
	-0.003882,
	-0.048116,
	1.051998,
]

## The fingerprint of the render inputs the captures were made from.
var fingerprint: String = ""
## What rendered them (adapter, Godot version), for the record.
var renderer: String = ""
var samples: Array[Sample] = []
## Problems reading the captures (none when they loaded).
var errors: Array[String] = []


## One captured subject in front of one Level's sky.
class Sample:
	extends RefCounted
	var level: int = 0
	var theme: StringName = &""
	## An enemy id (EnemyKind.IDS) or PLAYER.
	var subject: StringName = &""
	## Which spot on screen (ReadabilityCapture.SPOTS).
	var spot: int = 0
	var silhouette: PackedColorArray = PackedColorArray()
	var sky: PackedColorArray = PackedColorArray()

	func is_player() -> bool:
		return subject == PLAYER

	func label() -> String:
		return "level %d %s, %s at spot %d" % [level, theme, subject, spot]

	## The contrast between the silhouette and the sky around it.
	func contrast(vision: Vision) -> float:
		return ReadabilityFrames.contrast_ratio(
			ReadabilityFrames.mean_luminance(silhouette, vision),
			ReadabilityFrames.mean_luminance(sky, vision)
		)


## The committed captures.
static func committed() -> ReadabilityFrames:
	var frames: ReadabilityFrames = ReadabilityFrames.new()
	var file: FileAccess = _open_captures()
	if file == null:
		frames.errors.append("no captures (run: task godot:capture:readability)")
		return frames
	frames.read_json(file.get_as_text())
	return frames


static func _open_captures() -> FileAccess:
	return FileAccess.open("res://tests/visuals/readability/captures.json", FileAccess.READ)


## Fill these captures from their JSON text (ReadabilityCapture writes it).
func read_json(text: String) -> void:
	var data: Dictionary = {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		data = parsed
	else:
		errors.append("captures are not a JSON object")
		return
	fingerprint = str(_field(data, "fingerprint", ""))
	renderer = str(_field(data, "renderer", ""))
	var found: Variant = _field(data, "samples", [])
	if not found is Array:
		errors.append("captures have no samples")
		return
	var rows: Array = found
	for row: Variant in rows:
		if not row is Dictionary:
			errors.append("a sample is not a JSON object")
			continue
		var entry: Dictionary = row
		var sample: Sample = Sample.new()
		sample.level = _number(_field(entry, "level", 0))
		sample.theme = StringName(str(_field(entry, "theme", "")))
		sample.subject = StringName(str(_field(entry, "subject", "")))
		sample.spot = _number(_field(entry, "spot", -1))
		sample.silhouette = decode(str(_field(entry, "silhouette", "")))
		sample.sky = decode(str(_field(entry, "sky", "")))
		if sample.silhouette.is_empty() or sample.sky.is_empty():
			errors.append("%s has no pixels" % sample.label())
		samples.append(sample)


## The samples of one Level, optionally of one subject only.
func of_level(level: int, subject: StringName = &"") -> Array[Sample]:
	var out: Array[Sample] = []
	for sample: Sample in samples:
		if sample.level == level and (subject == &"" or sample.subject == subject):
			out.append(sample)
	return out


## Every pixel of one subject's silhouettes in one Level, all spots pooled.
func silhouette_of(level: int, subject: StringName) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray()
	for sample: Sample in of_level(level, subject):
		out.append_array(sample.silhouette)
	return out


## Pixels as hex: three bytes (R, G, B) per pixel.
static func encode(pixels: PackedColorArray) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	var _sized: int = bytes.resize(pixels.size() * 3)
	for i: int in pixels.size():
		bytes[i * 3] = pixels[i].r8
		bytes[i * 3 + 1] = pixels[i].g8
		bytes[i * 3 + 2] = pixels[i].b8
	return bytes.hex_encode()


static func decode(hex: String) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray()
	if hex.length() % 6 != 0:
		return out
	var bytes: PackedByteArray = hex.hex_decode()
	for i: int in range(0, bytes.size() - 2, 3):
		var _added: bool = out.push_back(Color8(bytes[i], bytes[i + 1], bytes[i + 2]))
	return out


## sRGB channel (0..1) to linear light.
static func to_linear(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)


## Linear RGB of an sRGB pixel, as seen with `vision`.
static func seen(pixel: Color, vision: Vision) -> Vector3:
	var rgb: Vector3 = Vector3(to_linear(pixel.r), to_linear(pixel.g), to_linear(pixel.b))
	match vision:
		Vision.DEUTERANOPIA:
			return _transform(DEUTERANOPIA_MATRIX, rgb)
		Vision.PROTANOPIA:
			return _transform(PROTANOPIA_MATRIX, rgb)
		_:
			return rgb


## WCAG relative luminance of an sRGB pixel, as seen with `vision`.
static func luminance(pixel: Color, vision: Vision = Vision.NORMAL) -> float:
	var rgb: Vector3 = seen(pixel, vision)
	return 0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z


## The mean relative luminance of some pixels (0 for none).
static func mean_luminance(pixels: PackedColorArray, vision: Vision = Vision.NORMAL) -> float:
	if pixels.is_empty():
		return 0.0
	var total: float = 0.0
	for pixel: Color in pixels:
		total += luminance(pixel, vision)
	return total / pixels.size()


## The WCAG contrast ratio of two relative luminances (1 to 21).
static func contrast_ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## The dominant hue of some pixels in degrees (0..360), or -1 when too few of
## them are coloured to have one. Each pixel with enough saturation and value
## votes for its hue's bin, weighted by its saturation; the peak bin's
## weighted mean hue wins.
static func dominant_hue(pixels: PackedColorArray) -> float:
	var bins: int = roundi(360.0 / HUE_BIN)
	var weights: PackedFloat32Array = PackedFloat32Array()
	var sines: PackedFloat32Array = PackedFloat32Array()
	var cosines: PackedFloat32Array = PackedFloat32Array()
	var _w: int = weights.resize(bins)
	var _s: int = sines.resize(bins)
	var _c: int = cosines.resize(bins)
	var total: float = 0.0
	for pixel: Color in pixels:
		if pixel.s < HUE_MIN_SATURATION or pixel.v < HUE_MIN_VALUE:
			continue
		var hue: float = pixel.h * TAU
		var bin: int = clampi(floori(pixel.h * bins), 0, bins - 1)
		weights[bin] += pixel.s
		sines[bin] += sin(hue) * pixel.s
		cosines[bin] += cos(hue) * pixel.s
		total += pixel.s
	var best: int = -1
	for bin: int in bins:
		if best < 0 or weights[bin] > weights[best]:
			best = bin
	if pixels.is_empty() or total <= 0.0 or weights[best] < HUE_MIN_SHARE * pixels.size():
		return -1.0
	return fposmod(rad_to_deg(atan2(sines[best], cosines[best])), 360.0)


## The distance between two hues around the colour wheel (0..180 degrees).
static func hue_distance(a: float, b: float) -> float:
	var d: float = fposmod(a - b, 360.0)
	return minf(d, 360.0 - d)


static func _transform(matrix: PackedFloat32Array, rgb: Vector3) -> Vector3:
	return Vector3(
		clampf(matrix[0] * rgb.x + matrix[1] * rgb.y + matrix[2] * rgb.z, 0.0, 1.0),
		clampf(matrix[3] * rgb.x + matrix[4] * rgb.y + matrix[5] * rgb.z, 0.0, 1.0),
		clampf(matrix[6] * rgb.x + matrix[7] * rgb.y + matrix[8] * rgb.z, 0.0, 1.0)
	)


static func _field(entry: Dictionary, key: String, fallback: Variant) -> Variant:
	return entry[key] if entry.has(key) else fallback


## A JSON number as an int (JSON numbers parse as floats); -1 if not a number.
static func _number(value: Variant) -> int:
	if value is float:
		var number: float = value
		return roundi(number)
	if value is int:
		var whole: int = value
		return whole
	return -1
