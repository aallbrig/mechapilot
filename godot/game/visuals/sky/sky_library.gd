class_name SkyLibrary
extends RefCounted
## Maps the Level data's `sky` id to its sky scene. The ids are the `sky` enum
## in schemas/level.schema.json, one per level of the 1.0 spec (#73):
## dawn (Dawn Patrol), storm (Storm Front), sunset (Sunset Strike), night (Night
## Raid), stratosphere (Stratosphere) and orbit (Edge of Orbit).

const SCENES: Dictionary[StringName, PackedScene] = {
	&"dawn": preload("res://game/visuals/sky/themes/dawn.tscn"),
	&"storm": preload("res://game/visuals/sky/themes/storm.tscn"),
	&"sunset": preload("res://game/visuals/sky/themes/sunset.tscn"),
	&"night": preload("res://game/visuals/sky/themes/night.tscn"),
	&"stratosphere": preload("res://game/visuals/sky/themes/stratosphere.tscn"),
	&"orbit": preload("res://game/visuals/sky/themes/orbit.tscn"),
}


## Every sky id, in level order.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for sky_id: StringName in SCENES:
		out.append(sky_id)
	return out


static func has_sky(sky_id: StringName) -> bool:
	return SCENES.has(sky_id)


## A new instance of the sky for the id, or null (with an error) if unknown.
static func instantiate(sky_id: StringName) -> SkyEnvironment:
	if not SCENES.has(sky_id):
		push_error("SkyLibrary: no sky with id %s" % sky_id)
		return null
	return SCENES[sky_id].instantiate() as SkyEnvironment
