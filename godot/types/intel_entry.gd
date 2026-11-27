class_name IntelEntry
extends RefCounted
## One entry of the Intel codex (#73): an enemy kind or a boss, with what the
## codex shows once it is unlocked. Announced by core/intel_codex.gd with
## profile.intel_catalog_changed.

## The entry's id: an EnemyKind id (&"fighter") or a boss id.
var id: StringName = &""
## The shown name.
var display_name: String = ""
## The one-line description.
var description: String = ""
## Hit points (a boss's full health).
var hit_points: int = 0
## Points for a shot kill (a boss: 5,000 times its Level).
var points: int = 0
## True for a boss.
var boss: bool = false


func _init(
	entry_id: StringName,
	entry_name: String,
	entry_description: String,
	entry_hit_points: int,
	entry_points: int,
	is_boss: bool
) -> void:
	id = entry_id
	display_name = entry_name
	description = entry_description
	hit_points = entry_hit_points
	points = entry_points
	boss = is_boss
