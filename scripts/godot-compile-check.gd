extends SceneTree
## Compile every project script and scene under the project's own warning
## settings, and fail if any warning is set below Error.
##
## Run by scripts/godot-compile-check from outside res://, so it never reloads
## itself (reloading the running script crashes the VM). `--check-only` and a
## failing `-s` script both exit 0, so the wrapper also requires the summary line.

const SKIPPED_DIRS: Array[String] = ["res://addons", "res://.godot"]
const WARNING_PREFIX: String = "debug/gdscript/warnings/"
const ERROR_LEVEL: int = 2


func _initialize() -> void:
	var failures: int = _check_warning_levels()
	var paths: Array[String] = []
	_collect("res://", paths)
	var scripts: int = 0
	var scenes: int = 0
	for path: String in paths:
		var ext: String = path.get_extension()
		if ext != ext.to_lower():
			# Godot loads X.GD as a script; lowercase-only tooling would skip it.
			printerr("compile-check: FAIL %s (extension must be lowercase)" % path)
			failures += 1
		if ext.to_lower() == "gd":
			scripts += 1
			if not _script_compiles(path):
				failures += 1
		else:
			scenes += 1
			if not _scene_loads(path):
				failures += 1
	if failures == 0:
		print("compile-check: ok scripts=%d scenes=%d" % [scripts, scenes])
	else:
		printerr("compile-check: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check_warning_levels() -> int:
	var failures: int = 0
	var levels: int = 0
	for prop: Dictionary in ProjectSettings.get_property_list():
		var name: String = prop["name"]
		var hint: String = prop["hint_string"]
		if not name.begins_with(WARNING_PREFIX) or hint != "Ignore,Warn,Error":
			continue
		levels += 1
		var level: int = ProjectSettings.get_setting(name, 0)
		if level != ERROR_LEVEL:
			printerr("compile-check: %s is %d, must be %d (Error)" % [name, level, ERROR_LEVEL])
			failures += 1
	if levels == 0:
		printerr("compile-check: found no GDScript warning settings")
		failures += 1
	return failures


func _collect(dir_path: String, out: Array[String]) -> void:
	if SKIPPED_DIRS.has(dir_path.trim_suffix("/")):
		return
	if FileAccess.file_exists(dir_path.path_join(".gdignore")):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		printerr("compile-check: cannot open %s" % dir_path)
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.get_extension().to_lower() in ["gd", "tscn"]:
			out.append(dir_path.path_join(file))


func _script_compiles(path: String) -> bool:
	var script: GDScript = (
		ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	)
	if script == null or not script.can_instantiate():
		printerr("compile-check: FAIL %s" % path)
		return false
	return true


func _scene_loads(path: String) -> bool:
	var scene: PackedScene = (
		ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	)
	if scene == null or not scene.can_instantiate():
		printerr("compile-check: FAIL %s" % path)
		return false
	return true
