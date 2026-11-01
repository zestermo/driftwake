extends SceneTree
## The auto-reel (1.28): clipped on (a charge), the next bite strikes itself with no key pressed, reels in faster than
## by hand, lands the catch, and counts down the catches it has left.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var bag0 := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func state():
	return p.state_machine.get_node("Fish")


func catches() -> int:
	var n := 0
	for id in FishTable.CATCHES.keys():
		n += p.inventory_component.count(id)
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.gadgets.give("auto_reel", 0)
			TK.act("gadget_fire")
			p.inventory_component.add_item(ItemDB.get_item("rod_driftwood"), 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("rod_driftwood"))
			p.global_position = Vector3(stage.SHORE_X - 1.2, stage.GROUND_Y + 0.1, 0.0)
			p.player_model.rotation.y = -PI * 0.5
			p.reset_physics_interpolation()
			bag0 = catches()
			until = TK.wait_secs(0.5)
		1:
			check("clipped on: a charge spent, %d catches to reel" % p.gadgets.reel_left,
				p.gadgets.charges("auto_reel") == 2 and p.gadgets.reel_left == GadgetData.tier_val("auto_reel", "catches", 0))
			p.fish()
			until = TK.wait_secs(2.0)
		2:
			state()._bite_at = state()._t
			until = TK.wait_ticks(4)
		3:
			check("the bite strikes itself, no key pressed (%s)" % state().phase, state().phase == "reel")
			check("...reeling faster than by hand (%.2f s)" % state()._reel_len, state()._reel_len < load("res://scripts/fishing/fishing.gd").REEL_LEN * 0.8)
			check("...one catch fewer left on it", p.gadgets.reel_left == GadgetData.tier_val("auto_reel", "catches", 0) - 1)
			until = TK.wait_secs(3.0)
		4:
			check("the catch lands in the bag", catches() > bag0)
			return TK.done(fails)
	step += 1
	return false
