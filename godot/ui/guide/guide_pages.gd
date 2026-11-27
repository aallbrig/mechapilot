class_name GuidePages
extends RefCounted
## The game guide's How to Play pages (#73, #75): one short illustrated page
## per topic, each with the controls of the current device.

enum Topic { MOVING, AIMING, ARMOR, LIVES, BOSSES, COMBOS }

const TITLES: Dictionary[Topic, String] = {
	Topic.MOVING: "MOVING",
	Topic.AIMING: "AIMING AND GRAVITY SHOTS",
	Topic.ARMOR: "ARMOR AND REPAIR KITS",
	Topic.LIVES: "LIVES AND THE BONUS LIFE",
	Topic.BOSSES: "THE BOSS GAUGE AND BOSSES",
	Topic.COMBOS: "COMBOS",
}
const BODIES: Dictionary[Topic, String] = {
	Topic.MOVING: "Fly anywhere in the open sky. Let go and your mech coasts, then sinks gently.",
	Topic.AIMING:
	(
		"Aim and fire in any direction. Your shots fall under gravity, so aim above"
		+ " distant targets."
	),
	Topic.ARMOR:
	(
		"You have 100 Armor. Crashes, bullets and bombs wear it down. Fly through a"
		+ " Repair Kit for +30."
	),
	Topic.LIVES:
	(
		"Armor 0 costs a life. You start with 3, and earn one more at 100,000 points."
		+ " Losing them all ends the Run."
	),
	Topic.BOSSES:
	(
		"Points fill the Boss Gauge. When it is full, the boss arrives. Watch for"
		+ " glowing attacks: they fire a moment later."
	),
	Topic.COMBOS:
	(
		"Kills within 1.2 seconds of each other raise the multiplier, up to x8."
		+ " Taking a hit resets it."
	),
}


## How many pages there are.
static func count() -> int:
	return Topic.size()


## The controls page `topic` shows for `device`.
static func controls(topic: Topic, device: InputDevice.Kind) -> Array[InputGlyphs.Segment]:
	match topic:
		Topic.MOVING:
			return [InputGlyphs.Segment.new(InputGlyphs.move(device), "move")]
		Topic.ARMOR:
			return [InputGlyphs.Segment.new(InputGlyphs.move(device), "fly through Repair Kits")]
		Topic.LIVES:
			return [InputGlyphs.Segment.new(InputGlyphs.pause(device), "pause")]
		_:
			return InputGlyphs.aim_and_fire(device)
