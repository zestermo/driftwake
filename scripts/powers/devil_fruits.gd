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
}

const CURSE := ["The Sea's Curse", "You can never swim again: deep water drags you under. Fruit powers fizzle waist-deep in the sea."]


static func get_fruit(id: String) -> Dictionary:
	return FRUITS.get(id, {})


static func type_name(id: String) -> String:
	return str(get_fruit(id).get("type", "")).capitalize()
