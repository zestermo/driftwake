extends SceneTree
## The reel's timing: reeling before a bite pulls the hook clear (nothing caught, the line comes in); a bite
## left past its window gets away (nothing caught, the float back up and the line still in for another); a
## better rod and Fishing's Steady Hands (fish_reel_pct) give a longer window, a better rod sooner bites;
## moving reels in.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rod
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
	for id in ["fish", "crab_meat", "oyster", "sea_urchin"]:
		n += p.inventory_component.count(id)
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			rod = p.fish_rod
			p.inventory_component.add_item(ItemDB.get_item("rod_driftwood"), 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("rod_driftwood"))
			p.global_position = Vector3(stage.SHORE_X - 1.2, stage.GROUND_Y + 0.1, 0.0)
			p.player_model.rotation.y = -PI * 0.5
			p.reset_physics_interpolation()
			bag0 = catches()
			until = TK.wait_secs(0.5)
		1:
			p.fish()
			until = TK.wait_secs(2.0)
		2:
			check("cast and waiting (%s / %s)" % [state().phase, rod.phase], p.current_state_name() == "Fish" and state().phase == "wait" and rod.phase == "float")
			state()._bite_at = 99.0
			TK.press("interact")
			until = TK.wait_ticks(2)
		3:
			TK.release("interact")
			check("too soon: the strike at nothing, the line comes in (%s)" % p.body_model.current_action(), state().phase == "out" and p.body_model.current_action() == "rod_strike")
			until = TK.wait_secs(1.0)
		4:
			check("...nothing caught, back on your feet, the line put away", catches() == bag0 and p.current_state_name() != "Fish" and rod.phase == "")
			p.fish()
			until = TK.wait_secs(2.0)
		5:
			state()._bite_at = state()._t
			until = TK.wait_ticks(3)
		6:
			check("a bite (%s), window %.2f s" % [state().phase, state()._window], state().phase == "bite")
			until = TK.wait_secs(state()._window + 0.25)
		7:
			check("too late: it got away, the float back up, the line still in (%s / %s)" % [state().phase, rod.phase],
				state().phase == "wait" and rod.phase == "float" and p.current_state_name() == "Fish")
			check("...nothing caught", catches() == bag0)
			var F = load("res://scripts/fishing/fishing.gd")
			var w0: float = F.window(p, "driftwood")
			check("a better rod: a longer window (%.2f -> %.2f s)" % [w0, F.window(p, "master")], F.window(p, "master") > w0 * 1.3)
			var pr = p.progression
			while pr.stat("fish_reel_pct") <= 0.0 and pr.mastery_level("fish") < 30:
				pr.add_life("fish", pr.mastery_to_next(pr.mastery_level("fish")))
			check("Fishing's Steady Hands: a longer window (%.2f -> %.2f s)" % [w0, F.window(p, "driftwood")], F.window(p, "driftwood") > w0)
			seed(7)
			var b0: float = F.bite_secs(p, "driftwood")
			seed(7)
			var b1: float = F.bite_secs(p, "master")
			check("a better rod: sooner bites (%.1f -> %.1f s)" % [b0, b1], b1 < b0 * 0.7)
			TK.press("move_forward")
			until = TK.wait_ticks(4)
		8:
			TK.release("move_forward")
			check("moving reels in and ends it", p.current_state_name() != "Fish" and rod.phase == "")
			return TK.done(fails)
	step += 1
	return false
