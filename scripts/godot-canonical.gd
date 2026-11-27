extends SceneTree
## Load every text resource and scene in the project and re-save it in place
## with the pinned Godot's own saver. Run by scripts/checks/godot-canonical on a
## private copy of the project, from outside res://. It reports nothing the
## check relies on: the check marks each file before the run, and decides from
## the files themselves afterwards (a marker that survived means the file was
## not re-saved). Only its exit status is read, and a failed load or save makes
## it exit non-zero.

const SKIPPED_DIRS: Array[String] = ["res://addons", "res://.godot"]
const EXTENSIONS: Array[String] = ["tres", "tscn", "escn"]


func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://", paths)
	paths.sort()
	var failures: int = 0
	for path: String in paths:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null or ResourceSaver.save(res, path) != OK:
			printerr("godot-canonical: could not load and re-save %s" % path)
			failures += 1
	quit(1 if failures > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	if SKIPPED_DIRS.has(dir_path.trim_suffix("/")):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	# Hidden directories too: the check judges every file under the project.
	dir.include_hidden = true
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if EXTENSIONS.has(file.get_extension().to_lower()):
			out.append(dir_path.path_join(file))
