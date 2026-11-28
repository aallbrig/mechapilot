class_name ReadabilityFingerprint
extends RefCounted
## The fingerprint of every file that decides how an enemy or the player mech
## looks in front of a Level's sky in ReadabilityCapture's frames (#135): the
## model scenes and their kit (baker, pieces, materials, shaders), the skies
## (scenes, shaders, clouds, weather), the gameplay camera, the enemy look and
## sizes, the player mech's model and size, the project's render settings and
## the capture tool itself. The captures store the fingerprint they were made
## from, so changing any of these makes them stale until captured again.
## Each path is a literal, as godot-safe-api requires of every FileAccess call.


## A SHA-256 over every input file, in this fixed order; "missing" if one of
## them cannot be read.
static func compute() -> String:
	var files: Array[FileAccess] = [
		FileAccess.open("res://project.godot", FileAccess.READ),
		FileAccess.open("res://tests/visuals/readability/readability_capture.gd", FileAccess.READ),
		FileAccess.open("res://game/camera_rig/camera_rig.gd", FileAccess.READ),
		FileAccess.open("res://game/camera_rig/lazy_follow.gd", FileAccess.READ),
		FileAccess.open("res://game/enemies/enemy_look.gd", FileAccess.READ),
		FileAccess.open("res://game/enemies/enemy_profile.gd", FileAccess.READ),
		FileAccess.open("res://game/player/mech_model.gd", FileAccess.READ),
		FileAccess.open("res://game/player/mech_tuning.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/visual_library.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/kit/flash.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/kit/flash_material.tres", FileAccess.READ),
		FileAccess.open("res://game/visuals/kit/hostile.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/kit/hostile_material.tres", FileAccess.READ),
		FileAccess.open("res://game/visuals/kit/hull.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/kit/hull_material.tres", FileAccess.READ),
		FileAccess.open("res://game/visuals/kit/mesh_baker.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/kit/visual_piece.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/kit/visual_rig.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/enemies/enemy_visual.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/enemies/fighter.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/enemies/heavy.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/enemies/interceptor.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/enemies/drone.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/enemies/bomber.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/enemies/enemy_mech.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/player/player_mech_visual.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/player/player_mech.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/cloud_layer.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/cloud.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/rain.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/sky_common.gdshaderinc", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/sky_environment.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/sky_library.gd", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/dawn.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/dawn.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/storm.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/storm.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/sunset.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/sunset.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/night.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/night.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/stratosphere.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/stratosphere.tscn", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/orbit.gdshader", FileAccess.READ),
		FileAccess.open("res://game/visuals/sky/themes/orbit.tscn", FileAccess.READ),
	]
	var digest: HashingContext = HashingContext.new()
	var _started: Error = digest.start(HashingContext.HASH_SHA256)
	for file: FileAccess in files:
		if file == null:
			return "missing"
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		# Each file's length first, so moving bytes between files changes it.
		var _length: Error = digest.update(("%d:" % bytes.size()).to_utf8_buffer())
		var _bytes: Error = digest.update(bytes)
	return digest.finish().hex_encode()
