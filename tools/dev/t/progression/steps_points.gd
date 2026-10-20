extends SceneTree
## Steps are bought with the tree's points (one a mastery level), a step at a time, in any order: each step adds
## its effect (Keen Edge: katana damage), a full step stops, no points stops, and the steps are a weapon's own
## (the cutlass doesn't feel the katana's). Away from the ship's bunk they can't be refunded.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "katana"})


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
			pr = p.progression
			check("no points at mastery 1 (%s)" % pr.step_why("k_keen"), not pr.buy_step("k_keen") and pr.step_why("k_keen") != "")
			while pr.mastery_level("katana") < 8:
				var m: Dictionary = pr.mastery_of("katana")
				pr.add_mastery("katana", pr.mastery_to_next(int(m["lv"])) - int(m["xp"]))
			check("mastery 8: 7 points", pr.points_free("katana") == 7)
			var d0: float = pr.style_stat("dmg", "katana")
			var dmg0: float = p.damage_multiplier()
			check("a step of Keen Edge", pr.buy_step("k_keen") and pr.steps_of("k_keen") == 1 and pr.points_free("katana") == 6)
			check("...+5%% katana damage (%.2f)" % (pr.style_stat("dmg", "katana") - d0), is_equal_approx(pr.style_stat("dmg", "katana") - d0, 0.05) and p.damage_multiplier() > dmg0)
			check("...the cutlass doesn't feel it", pr.style_stat("dmg", "sword") == 0.0)
			for i in range(4):
				pr.buy_step("k_keen")
			check("Keen Edge full at 5 (%s)" % pr.step_why("k_keen"), pr.steps_of("k_keen") == 5 and not pr.buy_step("k_keen") and pr.step_why("k_keen") == "Full")
			check("...+25%% in all", is_equal_approx(pr.style_stat("dmg", "katana") - d0, 0.25))
			check("learn() on a step buys one too (the old map)", pr.learn("k_feet") and pr.steps_of("k_feet") == 1)
			check("the last point, anywhere in the tree", pr.buy_step("k_flow"))
			check("out of points", pr.points_free("katana") == 0 and not pr.buy_step("k_whet"))
			check("away from the bunk the steps stay", not pr.can_respec() and not pr.respec_steps("katana") and pr.steps_of("k_keen") == 5)
			check("owns_node reads a bought step", pr.owns_node("k_keen") and not pr.owns_node("k_whet"))
			return TK.done(fails)
	step += 1
	return false
