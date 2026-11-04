extends SceneTree
## Strike speed (1.30, docs/v1_30_previews.md section 3): Quick Hands, a step chain off every melee weapon's root, each
## step opening at its mastery (the katana's 5 x +4% at 3, 7, 11, 15, 19; the greatsword's 3 x +3%); it counts only
## with that weapon in hand. Flowing Edge (the katana's slot passive at 20): +10% for 3 s after a perfect dodge or an Iai
## Counter. Strike speed tops out at +35%. Light attacks play faster with it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var STS
var step := 0
var until := 0
var fails := 0
var t0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func to_level(tree: String, lv: int) -> void:
	while pr.mastery_level(tree) < lv:
		var m: Dictionary = pr.mastery_of(tree)
		pr.add_mastery(tree, pr.mastery_to_next(int(m["lv"]), tree) - int(m["xp"]))


func speed() -> float:
	return p.state_machine.states["lightattack"].strike_speed()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			STS = load("res://scripts/progression/skill_trees.gd")
			var trees: Array = STS.QUICK_HANDS.keys()
			check("every melee tree has Quick Hands, no gun's (%d)" % trees.size(), trees.size() == 16 and not ("pistol" in trees) and trees.all(func(t): return STS.node_def(STS.ELEMENTS[t][0] + "_qhands").get("max_steps", 0) > 0))
			check("...the katana's 5 x 4%, the greatsword's 3 x 3%", STS.node_def("k_qhands")["max_steps"] == 5 and is_equal_approx(STS.node_def("k_qhands")["effects"]["aspd_katana"], 0.04)
				and STS.node_def("gs_qhands")["max_steps"] == 3 and is_equal_approx(STS.node_def("gs_qhands")["effects"]["aspd_greatsword"], 0.03))
			pr.gift("katana", 30)
			check("no strike speed yet (%.2f)" % speed(), is_zero_approx(speed()))
			check("Quick Hands waits for mastery 3 (%s)" % pr.buy_why("k_qhands"), pr.buy_why("k_qhands") == "Needs Katana 3")
			to_level("katana", 3)
			check("mastery 3: a step bought, +4%", pr.buy("k_qhands") and is_equal_approx(speed(), 0.04))
			check("...the second waits for 7 (%s)" % pr.buy_why("k_qhands"), pr.buy_why("k_qhands") == "Next step at Katana 7")
			to_level("katana", 19)
			for i in 4:
				pr.buy("k_qhands")
			check("mastery 19: all five, +20%% (%.2f)" % speed(), pr.steps_of("k_qhands") == 5 and is_equal_approx(speed(), 0.2) and pr.buy_why("k_qhands") == "Full")
			to_level("katana", 20)
			check("Flowing Edge at 20 after Clean Line", pr.buy("k_deflect") and pr.buy("k_draw") and pr.buy("k_wind") and pr.buy("k_arc") and pr.buy("k_clean") and pr.buy("k_flowing"))
			pr.equip_passive("k_flowing", 0)
			p.state_machine.states["dodge"].flowing_edge()
			check("...a perfect dodge with it slotted: +10%% for 3 s (%.2f)" % speed(), is_equal_approx(speed(), 0.3))
			pr.gear = {"attack_speed_pct": 0.2}
			check("strike speed tops out at +35%% (%.2f)" % speed(), is_equal_approx(speed(), 0.35))
			pr.gear = {}
			TK.act("light_attack")
			until = TK.wait_ticks(2)
		1:
			check("a light attack plays faster with it", p.current_state_name() == "LightAttack" and p.state_machine.current_state._spd > 1.25)
			return TK.done(fails)
	step += 1
	return false
