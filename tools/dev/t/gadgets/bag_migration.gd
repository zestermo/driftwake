extends SceneTree
## Saves from 1.28 (three belt slots) under the one-slot belt (1.28.1): a captain with three gadgets on and no bag keeps
## the first on the belt (selected) and the other two built at their tiers and charges, nothing lost; a gadget bag gained
## later takes them up again; and the new belt's own save round trip keeps the bag's colour.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
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
	match step:
		0:
			p = stage.player
			b = p.gadgets
			# (a 1.28 save's "gadgets", word for word: three slots, the third selected)
			b.from_dict({"known": ["bp_tar", "bp_star"], "owned": {"smoke": {"tier": 1, "charges": 2}, "tar": {"tier": 2, "charges": 4},
				"star": {"tier": 0, "charges": 1}}, "slots": ["smoke", "tar", "star"], "sel": 2})
			check("the first stays on the belt, and it's the one taken up (%s)" % str(b.slots), b.slots == ["smoke"] and b.gadget() == "smoke")
			check("...the others still built at their tiers and charges", b.tier_of("tar") == 2 and b.charges("tar") == 4 and b.tier_of("star") == 0 and b.charges("star") == 1)
			check("...the first keeps its own", b.tier_of("smoke") == 1 and b.charges("smoke") == 2)
			check("...and the blueprints known", b.known.has("bp_tar") and b.known.has("bp_star"))
			b.from_dict({"slots": ["", "tar", "star"], "sel": 1, "owned": {"tar": {"tier": 0, "charges": 3}, "star": {"tier": 0, "charges": 3}}})
			check("an empty first slot: the first filled one stays (%s)" % str(b.slots), b.slots == ["tar"] and b.gadget() == "tar")
			b.from_dict({"known": ["bp_tar", "bp_star"], "owned": {"smoke": {"tier": 1, "charges": 2}, "tar": {"tier": 2, "charges": 4},
				"star": {"tier": 0, "charges": 1}}, "slots": ["smoke", "tar", "star"], "sel": 0})
			p.inventory_component.add_item(ItemDB.get_item("gadget_bag_olive"), 1)
			until = TK.wait_ticks(2)
		1:
			check("a bag gained takes the other two up again (%s)" % str(b.slots), b.slots.size() == 4 and "tar" in b.slots and "star" in b.slots and b.slots[0] == "smoke")
			check("...the olive bag worn", p.body_model.bag_colour == "olive")
			var d: Dictionary = b.to_dict()
			p.inventory_component.add_item(ItemDB.get_item("gadget_bag_navy"), 1)
			b.bag_pref = "navy"
			b.fit()
			check("carrying two, the one picked is worn (%s)" % p.body_model.bag_colour, p.body_model.bag_colour == "navy")
			b.from_dict(d)
			check("the save keeps the bag's colour and the four slots (%s, %s)" % [p.body_model.bag_colour, str(b.slots)], p.body_model.bag_colour == "olive" and b.slots.size() == 4 and "star" in b.slots)
			return TK.done(fails)
	step += 1
	return false
