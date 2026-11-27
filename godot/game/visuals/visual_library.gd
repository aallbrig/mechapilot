class_name VisualLibrary
extends RefCounted
## The model scenes logic instances, by id. Enemy ids are EnemyKind.IDS and
## boss ids are the Level data's `boss.id` (BossDefinition.id), both from #73. Every scene's root
## is a VisualRig (see its required_markers() for what logic can rely on).

const PLAYER_MECH: PackedScene = preload("res://game/visuals/player/player_mech.tscn")

const ENEMIES: Dictionary[StringName, PackedScene] = {
	&"fighter": preload("res://game/visuals/enemies/fighter.tscn"),
	&"heavy": preload("res://game/visuals/enemies/heavy.tscn"),
	&"interceptor": preload("res://game/visuals/enemies/interceptor.tscn"),
	&"drone": preload("res://game/visuals/enemies/drone.tscn"),
	&"bomber": preload("res://game/visuals/enemies/bomber.tscn"),
	&"enemy_mech": preload("res://game/visuals/enemies/enemy_mech.tscn"),
}

const BOSSES: Dictionary[StringName, PackedScene] = {
	&"albatross": preload("res://game/visuals/bosses/albatross.tscn"),
	&"thunderhead": preload("res://game/visuals/bosses/thunderhead.tscn"),
	&"hornet": preload("res://game/visuals/bosses/hornet.tscn"),
	&"leviathan": preload("res://game/visuals/bosses/leviathan.tscn"),
	&"crimson_lancer": preload("res://game/visuals/bosses/crimson_lancer.tscn"),
	&"ascendant": preload("res://game/visuals/bosses/ascendant.tscn"),
}


static func player_mech() -> PlayerMechVisual:
	return PLAYER_MECH.instantiate() as PlayerMechVisual


## A new enemy model by id, or null (with an error) if unknown.
static func enemy(enemy_id: StringName) -> EnemyVisual:
	if not ENEMIES.has(enemy_id):
		push_error("VisualLibrary: no enemy with id %s" % enemy_id)
		return null
	return ENEMIES[enemy_id].instantiate() as EnemyVisual


## A new boss model by id, or null (with an error) if unknown.
static func boss(boss_id: StringName) -> BossVisual:
	if not BOSSES.has(boss_id):
		push_error("VisualLibrary: no boss with id %s" % boss_id)
		return null
	return BOSSES[boss_id].instantiate() as BossVisual


## A new enemy model for a kind of the roster.
static func enemy_for(kind: EnemyKind.Kind) -> EnemyVisual:
	return enemy(EnemyKind.id_of(kind))


## A new model of the Level's boss.
static func boss_for(level: LevelDefinition) -> BossVisual:
	return boss(level.boss.id)


static func enemy_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for enemy_id: StringName in ENEMIES:
		out.append(enemy_id)
	return out


static func boss_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for boss_id: StringName in BOSSES:
		out.append(boss_id)
	return out
