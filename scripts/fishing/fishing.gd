class_name Fishing
extends RefCounted
## Fishing (v1.18), Minecraft-style: with a rod in the equipment slot, F facing water (a shore, a pier, a
## ship's rail) casts (FishState): the bobber flies out and floats on the real waves, a wait, a nibble or
## two, then it dips with a splash and bubbles. Reel (F or a click) inside the window and the fish is yours;
## too soon and you pull the hook out of its mouth, too late and it gets away (the line stays in).
## The rod (Rods) sets the reach, how soon they bite, the window and the rare odds; Fishing's perks
## (fish_bite_pct, fish_reel_pct, fish_rare_pct, fish_double) are read here. The catch is the captain's own.

## How far ahead a cast can land (m), how deep the water must be there, how far apart the spots tried are.
const REACH_MIN := 2.5
const DEEP := 0.4
const STEP := 0.75
## The body's moves (ActionSpecs agrees), and when in the cast the bobber leaves the rod.
const CAST_LEN := 1.1
const RELEASE := 0.52
const FLIGHT := 0.6
const REEL_LEN := 1.3
const STRIKE_LEN := 0.8
const LAND_LEN := 1.2
## When the catch goes in the bag during the landing (u).
const BAGGED := 0.85
## Seconds to the bite (before the rod and perks), nibbles first, and the reel window.
const BITE_MIN := 6.0
const BITE_MAX := 15.0
const NIBBLES_MAX := 3
const WINDOW := 0.75
## Fishing mastery for a landed fish, and for one that got away.
const XP := 10
const XP_LOST := 3
## What comes up: [item id, weight]; the rare ones are weighted up by the rod and the rare perk.
const CATCH := [["fish", 60.0], ["crab_meat", 20.0], ["oyster", 12.0], ["sea_urchin", 8.0]]
const RARE := ["oyster", "sea_urchin"]
## How each catch looks on the line: [shape, length m, body, fins] (FishModels.fish).
const LOOKS := {
	"fish": ["slim", 0.34, Color(0.45, 0.55, 0.62), Color(0.3, 0.36, 0.42)],
	"crab_meat": ["flat", 0.22, Color(0.8, 0.3, 0.18), Color(0.6, 0.2, 0.12)],
	"oyster": ["flat", 0.12, Color(0.6, 0.58, 0.55), Color(0.4, 0.38, 0.36)],
	"sea_urchin": ["deep", 0.12, Color(0.25, 0.12, 0.3), Color(0.15, 0.08, 0.2)],
}


## The rod in `p`'s equipment slot ("" = none).
static func rod_of(p) -> String:
	return Rods.tier_of(p.equipment.get_item("equipment"))


## The nearest spot of water ahead of `p` a line can reach (Vector3.INF: none), on the calm sea level.
static func water_ahead(p, reach := 9.0) -> Vector3:
	var d := REACH_MIN
	while d <= reach:
		var at := _ahead(p, d)
		if _wet(p, at):
			return Vector3(at.x, 0.0, at.z)
		d += 1.0
	return Vector3.INF


## Where a cast with `tier` lands: the farthest water ahead within the rod's reach (INF: none).
static func cast_spot(p, tier: String) -> Vector3:
	var d := Rods.stat(tier, "range")
	while d >= REACH_MIN:
		var at := _ahead(p, d)
		if _wet(p, at):
			return Vector3(at.x, 0.0, at.z)
		d -= STEP
	return Vector3.INF


static func _ahead(p, d: float) -> Vector3:
	var fwd: Vector3 = -p.player_model.global_basis.z
	fwd.y = 0.0
	return p.global_position + fwd.normalized() * d


static func _wet(p, at: Vector3) -> bool:
	return p.get_node("/root/Ocean").depth_at(at, [], true) > DEEP


## Can `p` cast now ("" = yes, else why not)?
static func refuse(p) -> String:
	if rod_of(p) == "":
		return "Equip a fishing rod first (the equipment slot)"
	if not (p.is_free() and p.is_on_floor()) or p.is_swimming():
		return "Not now"
	if cast_spot(p, rod_of(p)) == Vector3.INF:
		return "No water in reach - face the water's edge"
	return ""


## Seconds until a fish bites (the rod and Patient Line shorten it).
static func bite_secs(p, tier: String) -> float:
	return randf_range(BITE_MIN, BITE_MAX) * Rods.stat(tier, "bite") * (1.0 - p.progression.stat("fish_bite_pct"))


## How long the bobber stays down for a reel to land it (the rod and Steady Hands widen it).
static func window(p, tier: String) -> float:
	return WINDOW * Rods.stat(tier, "window") * (1.0 + p.progression.stat("fish_reel_pct"))


## What's on the hook (the rod's and the perk's rare odds).
static func roll_catch(p, tier: String) -> String:
	var rare: float = Rods.stat(tier, "rare") * (1.0 + p.progression.stat("fish_rare_pct"))
	var total := 0.0
	for c in CATCH:
		total += float(c[1]) * (rare if c[0] in RARE else 1.0)
	var roll := randf() * total
	for c in CATCH:
		roll -= float(c[1]) * (rare if c[0] in RARE else 1.0)
		if roll <= 0.0:
			return c[0]
	return CATCH[0][0]


## The catch landed: into the bag (two on a Double Catch roll), Fishing mastery, a word. Returns how many.
static func land(p, id: String) -> int:
	var pr = p.progression
	var item := ItemDB.get_item(id)
	var n := 2 if randf() < pr.stat("fish_double") else 1
	pr.add_life("fish", XP)
	if p.inventory_component.room_for(item) < n:
		p.call("_toast", "A %s - but your bag's full, so back it goes" % item.display_name)
		return 0
	p.inventory_component.add_item(item, n)
	p.call("_toast", "Caught %s%s!" % ["two of " if n == 2 else "", item.display_name])
	return n


## The fish got away (too soon or too late): a little Fishing all the same.
static func lost(p) -> void:
	p.progression.add_life("fish", XP_LOST)
