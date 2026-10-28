extends SceneTree
## The 1.24 Will paths (WillPaths.OPEN): always open, beside today's three; a tier opens at 4 / 8 Will spent in all
## (a path's five nodes can't reach that alone), a version costs its tier, the passive (2) needs the first ability.
## A tier-3 skill goes on the bar. Iron Will and Sense are still free to pick as the first of their pair.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
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
			pr = p.progression
			pr.gift("will", 30)
			if pr.will_color == "":
				pr.attune("still")
			check("Second Step (Tempo, 1) bought first", pr.buy("w_step_v") and pr.has_will("w_step"))
			check("...one more air step (%d jumps)" % p.max_jumps, p.max_jumps == 2)
			check("Thick Blood waits for Red Mist (%s)" % pr.buy_why("h_blood"), pr.buy_why("h_blood") == "Needs Red Mist first")
			var mv0: float = p.move_speed
			check("Light on Your Feet (2), slotted: +8%% move speed (%.2f -> %.2f)" % [mv0, p.move_speed], pr.buy("h_feet") and pr.passives.has("h_feet") and is_equal_approx(p.move_speed - mv0, p.BASE_MOVE * 0.08))
			check("Rhythm waits for 4 Will spent in all (%s)" % pr.buy_why("w_cancel"), pr.buy_why("w_cancel") == "Needs 4 Edy spent")
			check("Fury is open beside it: Red Mist (1)", pr.buy("w_mist_v") and WillPaths.spent_all(pr) == 4)
			check("...4 spent: Cancel (2)", pr.buy("w_cancel") and pr.has_flag("dash_cancel"))
			check("Iron Will still free to pick (%s)" % pr.buy_why("w_coat_heavy"), pr.buy_why("w_coat_heavy") == "")
			check("Still Point waits for 8 (%s)" % pr.buy_why("w_still_v"), pr.buy_why("w_still_v") == "Needs 8 Edy spent")
			check("Flow (2) bought, Cancel still the one carried", pr.buy("w_flow") and pr.version_of("w_rhythm") == 0 and not pr.has_flag("will_flow"))
			check("8 spent: Still Point (3), its skill on the bar", pr.buy("w_still_v") and pr.knows("will_still_point") and "will_still_point" in p.power.loadout)
			check("Berserk (2) too", pr.buy("w_berserk_v") and pr.knows("will_berserk"))
			check("the points add up: 13 spent", pr.spent("will") == 13 and pr.pool("will") == 17)
			return TK.done(fails)
	step += 1
	return false
