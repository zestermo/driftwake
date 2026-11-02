extends SceneTree
## The gadget bag (1.28.1): without one the belt carries a single gadget (a second built stays off it), O only says a
## bag carries more and holding it opens no wheel; with a bag carried there are six slots, the built gadgets taken up,
## the bag worn at the left hip clasped shut; a tap of O takes up the next and throws the flap open a moment; held, the
## wheel shows the gadgets with the flap open, and letting go on one takes it up; seven built, six carried; the bag
## put away, back to one.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
var w
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


func _bag_node():
	return p.body_model.torso.get_node_or_null("GadgetBag")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var Bag = load("res://scripts/gadgets/gadget_bag.gd")
	match step:
		0:
			p = stage.player
			b = p.gadgets
			w = p.gadget_wheel
			b.give("smoke", 0)
			b.give("tar", 0)
			check("without a bag the belt carries one gadget (%s)" % str(b.slots), b.slots == ["smoke"] and b.capacity() == 1)
			check("...the second built stays built, off it", b.tier_of("tar") == 0)
			check("...and no bag is worn", _bag_node() == null)
			TK.act("gadget_cycle")
			until = TK.wait_ticks(3)
		1:
			check("O without a bag keeps the one gadget", b.gadget() == "smoke")
			Input.action_press("gadget_cycle")
			until = TK.wait_secs(0.4)
		2:
			check("...and holding it opens no wheel", not w.is_open())
			Input.action_release("gadget_cycle")
			p.inventory_component.add_item(ItemDB.get_item("gadget_bag_mustard"), 1)
			until = TK.wait_ticks(3)
		3:
			check("carrying a bag: six slots (%d)" % b.slots.size(), b.capacity() == 6 and b.slots.size() == 6)
			check("...the built gadgets taken up (%s)" % str(b.slots), "smoke" in b.slots and "tar" in b.slots)
			check("...the bag worn at the left hip", _bag_node() != null and _bag_node().get_node("Skeleton").get_bone_global_pose(0).origin.x < -0.1)
			check("...its strap over the shoulder", p.body_model.torso.get_node_or_null("GadgetBagStrap") != null)
			check("...clasped shut", not Bag.is_open(p.body_model))
			TK.act("gadget_cycle")
			until = TK.wait_secs(0.35)
		4:
			check("a tap of O takes up the next (%s)" % b.gadget(), b.gadget() == "tar")
			check("...and throws the flap open", Bag.is_open(p.body_model))
			check("...the snapshot says so (open, mustard)", int(p.net_pack()[8]) & p.NF_BAG_OPEN and (int(p.net_pack()[8]) & p.NF_BAG) >> p.NF_BAG_SHIFT == 1)
			until = TK.wait_secs(1.2)
		5:
			check("...then clasps it shut again", not Bag.is_open(p.body_model) and not p.body_model.bag_open)
			Input.action_press("gadget_cycle")
			until = TK.wait_secs(0.4)
		6:
			check("held, O opens the gadget wheel with both (%s)" % str(w.entries), w.is_open() and w.entries.size() == 2)
			check("...named (%s)" % w.shown_text(0)[0], w.shown_text(0)[0] == "Smoke Pellet")
			until = TK.wait_secs(0.3)
		7:
			check("...the flap open while it's up", Bag.is_open(p.body_model))
			w.point_at(w.entries.find("smoke"))
			Input.action_release("gadget_cycle")
			until = TK.wait_ticks(3)
		8:
			check("letting go on the smoke pellet takes it up", not w.is_open() and b.gadget() == "smoke")
			for g in ["flash", "pepper", "star", "caltrops", "spike"]:
				b.give(g, 0)
			check("seven built, six carried (%s)" % str(b.slots), b.slots.size() == 6 and not "" in b.slots and b.owned.size() == 7)
			p.inventory_component.remove_item(ItemDB.get_item("gadget_bag_mustard"), 1)
			until = TK.wait_ticks(3)
		9:
			check("the bag put away: one slot again (%s)" % str(b.slots), b.slots.size() == 1 and b.gadget() == "smoke")
			check("...the bag off the body", _bag_node() == null and p.body_model.torso.get_node_or_null("GadgetBagStrap") == null)
			check("...nothing built is lost", b.owned.size() == 7)
			return TK.done(fails)
	step += 1
	return false
