extends SceneTree
## The gadget belt (1.28): gadgets built onto it show on the HUD and on the captain's back; U fires the selected one
## (a charge spent, the cooldown started, the lob played, the gadget lands), the cooldown and an empty pouch refuse
## a use, O picks the next slot (carrying a gadget bag: 1.28.1), and the belt survives a save round trip.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var b = p.gadgets if p else null
	match step:
		0:
			p = stage.player
			check("an empty belt to start", p.gadgets.gadget() == "")
			p.inventory_component.add_item(ItemDB.get_item("gadget_bag_mustard"), 1)
			p.gadgets.give("smoke", 0)
			p.gadgets.give("tar", 1)
			until = TK.wait_secs(0.3)
		1:
			var hud = root.find_child("GadgetBelt", true, false)
			check("the belt shows on the HUD", hud != null and hud.visible)
			check("the pouch is worn on the back", p.body_model.torso.get_node_or_null("GadgetPouch") != null)
			check("built gadgets fill the slots, the first selected", b.slots == ["smoke", "tar", "", "", "", ""] and b.gadget() == "smoke")
			check("a Mk I smoke pellet holds 3 charges", b.charges("smoke") == 3)
			TK.act("gadget_fire")
			until = TK.wait_ticks(2)
		2:
			check("U spends a charge (%d)" % b.charges("smoke"), b.charges("smoke") == 2)
			check("...starts the cooldown (%.2f)" % b.cooldown_left("smoke"), b.cooldown_left("smoke") > 5.0)
			check("...and lobs it (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gd_lob")
			until = TK.wait_secs(0.6)
		3:
			TK.act("gadget_fire")
			until = TK.wait_ticks(2)
		4:
			check("a use in the cooldown is refused", b.charges("smoke") == 2)
			until = TK.wait_secs(1.0)
		5:
			var zs := get_nodes_in_group("gadget_zones")
			check("the pellet landed and burst (%d zones)" % zs.size(), zs.size() == 1 and zs[0].kind == "smoke")
			b.owned["smoke"]["charges"] = 0
			b.ready_at.clear()
			TK.act("gadget_fire")
			until = TK.wait_ticks(2)
		6:
			check("an empty gadget is refused", b.charges("smoke") == 0 and b.cooldown_left("smoke") == 0.0)
			TK.act("gadget_cycle")
			until = TK.wait_ticks(2)
		7:
			check("O picks the next slot", b.gadget() == "tar")
			check("...O is its own key, not Shift (sprint) + U", InputMap.action_get_events("gadget_cycle").all(func(e): return not (e is InputEventKey) or (not e.shift_pressed and e.physical_keycode == KEY_O)))
			TK.act("gadget_cycle")
			until = TK.wait_ticks(2)
		8:
			check("...skipping the empty one, round to the first", b.gadget() == "smoke")
			var d: Dictionary = b.to_dict()
			b.from_dict({})
			check("a cleared belt wears no pouch", p.body_model.torso.get_node_or_null("GadgetPouch") == null)
			b.from_dict(d)
			check("the belt comes back from its save", b.slots == ["smoke", "tar", "", "", "", ""] and b.tier_of("tar") == 1 and b.charges("smoke") == 0)
			return TK.done(fails)
	step += 1
	return false
