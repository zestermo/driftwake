class_name DevilFruits
extends RefCounted
## Devil Fruits. Each is a whole identity: a type (Logia, Zoan or Paramecia)
## with its own built-in passive, starting skills that come free when you eat
## it, and a region of the skill map (SkillTree) with the rest. Every fruit
## carries the sea's curse: you can never swim again.
##
##   Logia      the body becomes an element: the dodge turns you intangible
##              (full i-frames, passing through enemies and gunfire); starts
##              with a ranged and a melee skill.
##   Zoan       shift between human and a hybrid beast form (V); starts with a
##              melee and a movement skill.
##   Paramecia  the weakest early: a passive, a movement skill and either a
##              ranged or a melee skill.

const FRUITS := {
	"ember": {"id": "ember", "name": "Ember Fruit", "type": "logia", "color": Color(1.0, 0.5, 0.15),
		"item": "ember_fruit", "start": ["fire_fist", "fire_ring"],
		"passive": ["Flame Body", "Your dodge turns you to fire: fully untouchable, passing straight through enemies and gunfire."]},
	"wolf": {"id": "wolf", "name": "Wolf Fruit", "type": "zoan", "color": Color(0.75, 0.68, 0.55),
		"item": "wolf_fruit", "start": ["rending_fang", "pounce"],
		"passive": ["Hybrid Form", "Press V to shift into a hybrid wolf form and back: claws instead of weapons, 25% more damage, 15% faster."]},
	"vine": {"id": "vine", "name": "Vine Fruit", "type": "paramecia", "color": Color(0.45, 0.85, 0.3),
		"item": "vine_fruit", "start": ["vine_snare", "vine_swing"],
		"passive": ["Photosynthesis", "Out of combat, on land, you slowly heal and regain energy."]},
	# (1.27) lightning: blinks, chains between foes (docs/v1_27_raids_fruits_plan.md "The six fruit kits"; the Lagoon Prince's)
	"storm": {"id": "storm", "name": "Storm Fruit", "type": "logia", "color": Color(0.55, 0.72, 1.0),
		"item": "storm_fruit", "start": ["thunder_step", "chain_lightning"],
		"passive": ["Static Body", "Lightning in your veins: you move a step quicker, and the air crackles when you're hit."]},
	# (1.27) time on a small scale: rewinds, stops, hastes; little damage of its own (docs/v1_27_raids_fruits_plan.md "The ten Driftfruits")
	"clockwork": {"id": "clockwork", "name": "Clockwork Fruit", "type": "paramecia", "color": Color(0.85, 0.7, 0.35),
		"item": "clockwork_fruit", "start": ["rewind", "time_stop"],
		"passive": ["Borrowed Seconds", "Your skills come back 10% sooner."]},
	# (1.27) sound: where things are, and a note that shatters a line of them (docs/v1_27_raids_fruits_plan.md "The ten Driftfruits")
	"echo": {"id": "echo", "name": "Echo Fruit", "type": "paramecia", "color": Color(0.55, 0.75, 0.85),
		"item": "echo_fruit", "start": ["echo_step", "shatter_note"],
		"passive": ["Resonance", "Shatter Note hits twice as hard on a foe already reeling."]},
	# (1.27) the great bear: huge slow swings, a charge, a roar that stuns (docs/v1_27_raids_fruits_plan.md "The ten Driftfruits")
	"bear": {"id": "bear", "name": "Bear Fruit", "type": "zoan", "color": Color(0.55, 0.4, 0.28),
		"item": "bear_fruit", "start": ["bear_charge", "bear_roar"],
		"passive": ["Hybrid Form", "Press V to shift into a hybrid bear form and back: claws instead of weapons, heavier and harder to stagger."]},
	# (1.27) wind: cones and lines that push and pull, the best of the air (docs/v1_27_raids_fruits_plan.md "The ten Driftfruits")
	"gust": {"id": "gust", "name": "Gust Fruit", "type": "logia", "color": Color(0.7, 0.95, 0.75),
		"item": "gust_fruit", "start": ["gale_dash", "gust_cone"],
		"passive": ["Wind Body", "You fall slowly and jump higher: the wind holds you up."]},
	# (1.27) the joke that isn't: soap and bubbles (docs/v1_27_raids_fruits_plan.md "The six fruit kits")
	"bubble": {"id": "bubble", "name": "Bubble Fruit", "type": "paramecia", "color": Color(0.75, 0.9, 1.0),
		"item": "bubble_fruit", "start": ["bubble_shield", "slick_floor"],
		"passive": ["Soap Skin", "Foes that grab you lose their grip."]},
	# (1.27) the tank's fruit: iron at will (docs/v1_27_raids_fruits_plan.md "The six fruit kits")
	"iron": {"id": "iron", "name": "Iron Fruit", "type": "paramecia", "color": Color(0.58, 0.6, 0.64),
		"item": "iron_fruit", "start": ["iron_guard", "iron_fist"],
		"passive": ["Iron Body", "Heavier than you were: blows push you less, and in deep water you sink like a stone."]},
}

const CURSE := ["The Sea's Curse", "You can never swim again: deep water drags you under. Fruit powers fizzle waist-deep in the sea."]

## Off for now: no fruit is placed in the world's chests until the powers are as polished as the
## rest (Zach, 2026-10-09). The system stays; a captain who already ate one keeps it.
const IN_WORLD := false


static func get_fruit(id: String) -> Dictionary:
	return FRUITS.get(id, {})


## Display names for the type ids (docs/originality_plan.md); the ids stay in saves and co-op.
const TYPE_NAMES := {"logia": "Flux", "zoan": "Feral", "paramecia": "Knack"}


static func type_name(id: String) -> String:
	var t := str(get_fruit(id).get("type", ""))
	return TYPE_NAMES.get(t, t.capitalize())
