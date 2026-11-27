class_name GuidePages
extends RefCounted
## The game guide's How to Play pages (#73, #75): one short illustrated page
## per topic, each with the controls of the current device.

enum Topic { CONTROLS, MOVING, AIMING, ARMOR, LIVES, COMBOS, BOSSES, LEVELS }

const TITLES: Dictionary[Topic, String] = {
	Topic.CONTROLS: "CONTROLS",
	Topic.MOVING: "MOVING",
	Topic.AIMING: "AIMING AND GRAVITY SHOTS",
	Topic.ARMOR: "ARMOR AND REPAIR KITS",
	Topic.LIVES: "LIVES AND THE BONUS LIFE",
	Topic.COMBOS: "COMBOS",
	Topic.BOSSES: "THE BOSS GAUGE AND BOSSES",
	Topic.LEVELS: "LEVELS",
}
## The numbers are RunRules' (test_how_to_play_states_the_rules keeps them in
## step); ui/ may not read core/, so the guide states them as text.
const BODIES: Dictionary[Topic, String] = {
	Topic.CONTROLS:
	(
		"Keyboard, mouse, gamepad or touch: use whichever you like and switch any"
		+ " time. Every prompt follows the device you touched last."
	),
	Topic.MOVING:
	(
		"The sky has no edge: fly anywhere. Let go and your mech coasts, then sinks"
		+ " gently. Arrows at the screen's edge point to enemies out of sight."
	),
	Topic.AIMING:
	(
		"Aim apart from where you fly: dodge one way, shoot another. Shots fall under"
		+ " gravity, so aim above distant targets. Enemy shots fall too."
	),
	Topic.ARMOR:
	(
		"You have 100 Armor. A crash costs 25, a bullet 10, a bomb or missile 20."
		+ " After a hit you blink, safe for a moment. Fly through a Repair Kit for +30."
	),
	Topic.LIVES:
	(
		"Armor 0 costs a life: you return where you fell, at full Armor and safe for"
		+ " 2 seconds. You start with 3 lives and earn one more at 100,000 points."
	),
	Topic.COMBOS:
	(
		"Kills within 1.2 seconds of each other raise the multiplier, up to x8, and"
		+ " every kill scores times it. Taking a hit resets it."
	),
	Topic.BOSSES:
	(
		"Points fill the Boss Gauge; when it is full, the boss arrives. Its attacks"
		+ " glow just before they fire, so move when you see the glow."
	),
	Topic.LEVELS:
	(
		"6 Levels, each with its own sky and boss. Beat the boss to clear the Level:"
		+ " 50 points per Armor left, plus 10,000 if you lost no life."
	),
}


## How many pages there are.
static func count() -> int:
	return Topic.size()


## The controls page `topic` shows for `device`.
static func controls(topic: Topic, device: InputDevice.Kind) -> Array[InputGlyphs.Segment]:
	match topic:
		Topic.CONTROLS:
			return InputGlyphs.every_control(device)
		Topic.MOVING:
			return [InputGlyphs.Segment.new(InputGlyphs.move(device), "move")]
		Topic.ARMOR:
			return [InputGlyphs.Segment.new(InputGlyphs.move(device), "fly through Repair Kits")]
		Topic.LIVES, Topic.LEVELS:
			return [InputGlyphs.Segment.new(InputGlyphs.pause(device), "pause")]
		_:
			return InputGlyphs.aim_and_fire(device)
