extends SceneTree
## Re-save every text resource and scene in the project with the pinned
## Godot's own saver, in place, and report each file whose saved bytes differ
## from the committed original. Run by scripts/checks/godot-canonical on a
## private copy of the project, from outside res://. The originals are read from
## --original=<dir> (the real project, read-only), so nothing that touched the
## copy before this run (an import, project code) can launder a file. The final
## line carries --nonce=<value>, which project code cannot read (godot-safe-api
## bans command-line access), so it cannot forge the summary.
## Output: "canonical: differs <path>", "canonical: unloadable <path>",
## "canonical: unsavable <path>" and "canonical: checked <n> <nonce>".

const SKIPPED_DIRS: Array[String] = ["res://addons", "res://.godot"]
const EXTENSIONS: Array[String] = ["tres", "tscn", "escn"]


func _initialize() -> void:
	var original: String = ""
	var nonce: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--original="):
			original = arg.trim_prefix("--original=")
		elif arg.begins_with("--nonce="):
			nonce = arg.trim_prefix("--nonce=")
	if original == "" or nonce == "":
		printerr("canonical: needs --original=<dir> and --nonce=<value>")
		quit(1)
		return
	var paths: Array[String] = []
	_collect("res://", paths)
	paths.sort()
	var checked: int = 0
	for path: String in paths:
		var before: PackedByteArray = FileAccess.get_file_as_bytes(
			original.path_join(path.trim_prefix("res://"))
		)
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			print("canonical: unloadable %s" % path)
			continue
		var err: Error = ResourceSaver.save(res, path)
		if err != OK:
			print("canonical: unsavable %s (%s)" % [path, error_string(err)])
			continue
		var after: PackedByteArray = FileAccess.get_file_as_bytes(path)
		checked += 1
		if before != after:
			print("canonical: differs %s" % path)
	print("canonical: checked %d %s" % [checked, nonce])
	quit()


func _collect(dir_path: String, out: Array[String]) -> void:
	if SKIPPED_DIRS.has(dir_path.trim_suffix("/")):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if EXTENSIONS.has(file.get_extension().to_lower()):
			out.append(dir_path.path_join(file))
