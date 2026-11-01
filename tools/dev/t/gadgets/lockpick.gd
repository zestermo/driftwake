extends SceneTree
## The lockpick set (1.28): a locked chest won't open by hand; the picks need one close by (refused from afar, no
## charge spent); at it they click away for the tier's time, then the lock springs and the chest opens into the bag.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var c
var gold0 := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "chest": [["gold", 30]]})


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
			c = stage.chest
			c.rolled = true
			c.locked = "the test holds the key"
			gold0 = p.inventory_component.count("gold")
			c._on_interact(p)
			check("a locked chest won't open by hand", p.inventory_component.count("gold") == gold0 and is_instance_valid(c))
			p.gadgets.give("lockpick", 0)
			p.global_position = c.global_position + Vector3(-6.0, 0.05, 0)
			p.reset_physics_interpolation()
			TK.act("gadget_fire")
			until = TK.wait_ticks(3)
		1:
			check("from afar the picks are refused, no charge spent", p.current_state_name() != "Gadget" and p.gadgets.charges("lockpick") == 2)
			p.global_position = c.global_position + Vector3(-1.5, 0.05, 0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(3)
		2:
			TK.act("gadget_fire")
			until = TK.wait_secs(1.0)
		3:
			check("at it, the picks click away (%s)" % p.current_state_name(), p.current_state_name() == "Gadget" and c.locked != "")
			check("...a charge spent", p.gadgets.charges("lockpick") == 1)
			until = TK.wait_secs(GadgetData.tier_val("lockpick", "pick_secs", 0))
		4:
			check("the lock springs and the chest opens into the bag (%d gold)" % (p.inventory_component.count("gold") - gold0),
				p.inventory_component.count("gold") == gold0 + 30)
			check("...back on your feet", p.current_state_name() != "Gadget")
			return TK.done(fails)
	step += 1
	return false
