class_name Fishing
extends RefCounted
## Fishing (v1.18), Minecraft-style: with a rod in the equipment slot, F facing water (a shore, a pier, a
## ship's rail) casts (FishState): the bobber flies out and floats on the real waves, a wait, a nibble or
## two, then it dips with a splash and bubbles. Reel (F or a click) inside the window and the fish is yours;
## too soon and you pull the hook out of its mouth, too late and it gets away (the line stays in).
## The rod (Rods) sets the reach, how soon they bite, the window and the rare odds; the bait on the hook (Bait)
## bites and rare odds too, one used up per catch landed. What bites is FishTable's (the water under the float,
## the coast, the hour). Fishing's perks are read here: fish_bite_pct (Patient Line), fish_reel_pct (Steady
## Hands), fish_bait_save (Bait Saver), fish_rare_pct (Sea Lore), fish_double (Old Salt), fish_legend (Master
## Angler: the legendary odds). The catch is the captain's own; its name rises in its rarity's colour for all.

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
## Fishing mastery for one that got away (a landed catch: FishTable.XP by its rarity).
const XP_LOST := 3
## Night for the fish (Music's dusk and dawn).
const DUSK := 19.0
const DAWN := 5.5


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


## Is it night for the fish?
static func night(p) -> bool:
	var h: float = p.get_node("/root/Weather").hour()
	return h >= DUSK or h < DAWN


## Seconds until a fish bites (the rod, the bait and Patient Line shorten it).
static func bite_secs(p, tier: String, bait := "") -> float:
	return randf_range(BITE_MIN, BITE_MAX) * Rods.stat(tier, "bite") * Bait.bite_k(bait) * (1.0 - p.progression.stat("fish_bite_pct"))


## How long the bobber stays down for a reel to land it (the rod and Steady Hands widen it).
static func window(p, tier: String) -> float:
	return WINDOW * Rods.stat(tier, "window") * (1.0 + p.progression.stat("fish_reel_pct"))


## The rare odds (FishTable.roll's `rare`): the rod's, the bait's and Sea Lore's.
static func rare_k(p, tier: String, bait: String, is_night: bool) -> float:
	return Rods.stat(tier, "rare") * Bait.rare_k(bait, is_night) * (1.0 + p.progression.stat("fish_rare_pct"))


## What's on the hook for a float at `spot`: FishTable's pool for its water, coast and hour, rolled with the
## rod, the bait and the perks.
static func roll_catch(p, tier: String, spot: Vector3, bait := "") -> String:
	var tree: SceneTree = p.get_tree()
	var is_night := night(p)
	var ids := FishTable.pool(FishTable.water_at(tree, spot), FishTable.theme_at(tree, spot), is_night)
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	return FishTable.roll(ids, rare_k(p, tier, bait, is_night), 1.0 + p.progression.stat("fish_legend"), rng)


## The catch landed: into the bag (two on an Old Salt roll), the bait used (unless Bait Saver keeps it), Fishing
## mastery by its rarity, its name in its rarity's colour over the captain's head for everyone, and the first
## legendary teaches a recipe. Returns how many went in the bag.
static func land(p, id: String, bait := "") -> int:
	var pr = p.progression
	var inv = p.inventory_component
	var item := ItemDB.get_item(id)
	var r := FishTable.rarity_of(id)
	pr.add_life("fish", FishTable.XP[r])
	if bait != "" and inv.count(bait) > 0 and randf() >= pr.stat("fish_bait_save"):
		inv.remove_item(ItemDB.get_item(bait), 1)
	Net.fx("float_text", [p.global_position + Vector3.UP * 2.3, item.display_name, item.rarity_color(), 30 if r >= 3 else 24])
	if r >= 3:
		Net.fx("glint", [p.global_position + Vector3.UP * 1.6, item.rarity_color(), 1.2])
	if r == 4 and Food.teach(pr, FishTable.LEGEND_RECIPE):
		p.call("_toast", "A legend of the sea! The old cooks' recipe comes back to you: %s (the galley)" % Food.MEALS[FishTable.LEGEND_RECIPE]["name"])
	var n := 2 if randf() < pr.stat("fish_double") else 1
	if inv.room_for(item) < n:
		p.call("_toast", "A %s - but your bag's full, so back it goes" % item.display_name)
		return 0
	inv.add_item(item, n)
	p.call("_toast", "Caught: %s%s (%s)" % [item.display_name, " x2" if n == 2 else "", item.rarity_name()])
	return n


## The action wheel's Cut bait (order 65; ActionWheel.ensure_builtins). Static method callables, not lambdas.
static func register_wheel() -> void:
	ActionWheel.register("cut_bait", "Cut bait", "", _cut_ok, cut_bait, 65)


static func _cut_ok(p):
	if not ActionWheel.on_foot(p):
		return false
	return ActionWheel.busy(p) if Bait.recipe_for(p.inventory_component) >= 0 else "Needs a crab, a fish, or an urchin and kelp"


## Cut one batch of bait (Bait.CUT) from what `p` carries.
static func cut_bait(p) -> void:
	var inv = p.inventory_component
	var i := Bait.recipe_for(inv)
	if i < 0:
		p.call("_toast", "Nothing to cut bait from")
		return
	var made: Array = Bait.CUT[i][1]
	var item := ItemDB.get_item(str(made[0]))
	if inv.room_for(item) < int(made[1]):
		p.call("_toast", "No room in your bag")
		return
	for need in Bait.CUT[i][0]:
		inv.remove_item(ItemDB.get_item(str(need[0])), int(need[1]))
	inv.add_item(item, int(made[1]))
	p.call("_toast", "Cut %d %s" % [int(made[1]), item.display_name])
	p.gesture("pickup")


## The fish got away (too soon or too late): a little Fishing all the same.
static func lost(p) -> void:
	p.progression.add_life("fish", XP_LOST)
