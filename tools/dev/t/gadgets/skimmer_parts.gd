extends SceneTree
## The skimmer's parts and blueprint (1.28.1): coral spar, sea-silk and lagoon pearl are items with icons; bp_skimmer
## is an item that teaches it, kept out of the shops' and loot tables' list (only an atoll places it) and out of the
## parts the merchants roll; Mk I needs all three, and with them a workbench builds it onto the belt.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var G = load("res://scripts/gadgets/gadgets.gd")
	match step:
		0:
			p = stage.player
			for id in ["coral_spar", "sea_silk", "lagoon_pearl", "bp_skimmer"]:
				var it = ItemDB.get_item(id)
				check("%s is an item with an icon" % id, it != null and it.icon != null)
			check("the shops and loot tables don't list the skimmer's blueprint", not "bp_skimmer" in G.blueprint_ids())
			check("...nor its parts", not G.part_ids().has("coral_spar") and not G.part_ids().has("lagoon_pearl"))
			var c: Array = G.cost("skimmer", 0)
			var ids: Array = c.map(func(e): return str(e[0]))
			check("Mk I needs all three atoll parts (%s)" % G.cost_text(c), "coral_spar" in ids and "sea_silk" in ids and "lagoon_pearl" in ids)
			check("the blueprint teaches it", G.teach(p, "bp_skimmer") and G.knows(p, "skimmer"))
			check("without the parts it can't be built", G.build(p, "skimmer").begins_with("Short of"))
			for e in c:
				p.inventory_component.add_item(ItemDB.get_item(str(e[0])), int(e[1]))
			check("with them it's built Mk I", G.build(p, "skimmer") == "" and p.gadgets.tier_of("skimmer") == 0)
			check("...onto the belt", "skimmer" in p.gadgets.slots)
			check("...cooldown only, no charges", p.gadgets.max_charges("skimmer") == 0)
			check("the three tiers' speeds are 11, 13.5, 16 (1.30)", GadgetData.GADGETS["skimmer"]["speed"] == [11.0, 13.5, 16.0])
			return TK.done(fails)
	step += 1
	return false
