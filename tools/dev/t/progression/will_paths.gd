extends SceneTree
## Will paths (1.23): Will points buy a path's versions (the tier's price each) and its passive. Either first path is
## free to pick; the second opens at 8 Will spent; a path's tier 2 at 4 spent in it, tier 3 at 8; Captain's Will needs
## 4 in each of the others. The first version bought is carried (its skill on the bar, its effects counting); another
## bought one is switched in only at a rest spot (the ship's bunk). A passive needs the path's first ability. A save
## keeps the points, purchases, carried versions and the colour.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_will_paths.dat"
var SG
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true, "ship": true})


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
			check("no Will at first, nothing to spend", pr.pool("will") == 0 and not pr.has_will("w_coat") and not pr.has_flag("observation"))
			check("...Coat waits for a point (%s)" % pr.buy_why("w_coat_heavy"), pr.buy_why("w_coat_heavy") == "Needs 1 Will point")
			pr.gift("will", 30)
			check("Flash (Sense) bought first: a red flash on foes' attacks", pr.buy("w_flash_long") and pr.has_will("w_flash") and pr.has_flag("observation") and pr.has_flag("flash_early"))
			check("...Iron Will is shut now (%s)" % pr.buy_why("w_coat_heavy"), pr.buy_why("w_coat_heavy") == "A second path opens at 8 Will spent")
			check("Foresight waits for 4 in Sense (%s)" % pr.buy_why("w_fore_sight"), pr.buy_why("w_fore_sight") == "Needs 4 Will spent in Sense")
			check("Instinct (2) needs Flash, which you have", pr.buy("h_instinct") and pr.passives.has("h_instinct"))
			check("two more Flash versions (1 each): 5 in Sense, the first still carried", pr.buy("w_flash_shots") and pr.buy("w_flash_boss") and pr.version_of("w_flash") == 0 and not pr.has_flag("flash_shots"))
			check("Foresight bought (2): its skill on the bar", pr.buy("w_fore_sight") and pr.knows("foresight") and "foresight" in p.power.loadout)
			check("...Slow Sight too (2): 9 in Sense", pr.buy("w_fore_slow") and WillPaths.spent_in(pr, "sense") == 9)
			check("8 spent: Iron Will opens", pr.buy_why("w_coat_heavy") == "" and pr.buy("w_coat_heavy") and pr.knows("armament_coat"))
			check("Captain's Will needs 4 in each (%s)" % pr.buy_why("w_roar_king"), pr.buy_why("w_roar_king") == "Needs 4 Will spent in Iron Will and in Sense")
			check("...Quick Coat and Hardening: 4 in Iron Will", pr.buy("w_coat_quick") and pr.buy("h_harden"))
			check("...Roar opens (2), the ultimate", pr.buy("w_roar_king") and pr.knows("conquerors_haki"))
			check("Clash waits for 4 in Captain's Will (%s)" % pr.buy_why("w_clash"), pr.buy_why("w_clash") == "Needs 4 Will spent in Captain's Will")
			check("bought once", pr.buy_why("w_coat_heavy") == "Learned" and not pr.buy("w_coat_heavy"))
			print("   spent %d left %d" % [pr.spent("will"), pr.pool("will")])
			check("the points add up: 15 spent, 15 left", pr.spent("will") == 15 and pr.pool("will") == 15)
			check("away from a rest spot Quick Coat can't be switched in", not pr.set_version("w_coat", 1) and pr.version_of("w_coat") == 0)
			check("...a version not bought can't be either", not pr.set_version("w_coat", 2))
			p.global_position = stage.ship.global_transform * (load("res://scripts/ship/ship.gd").BED_AT + Vector3(0.95, 0.1, 0.0))
			p.reset_physics_interpolation()
			until = TK.wait_ticks(3)
		1:
			var cd0: float = p.power.skill_cooldown("armament_coat", 1)
			check("by the bunk: Quick Coat switched in", pr.can_respec() and pr.set_version("w_coat", 1) and pr.version_of("w_coat") == 1)
			check("...the coat comes back 30%% sooner (%.1f -> %.1f), the heavier hits gone" % [cd0, p.power.skill_cooldown("armament_coat", 1)],
				is_equal_approx(p.power.skill_cooldown("armament_coat", 1), cd0 * 0.7) and pr.stat("coat_dmg") == 0.0 and pr.knows("armament_coat"))
			check("a colour picked", pr.set_will_color("blue") and pr.will_tint() == WillPaths.COLORS["blue"][1])
			SG = load("res://scripts/game/save_game.gd")
			SG.use_test_file(SAVE)
			SG.save(p)
			pr.from_dict({})
			check("a fresh block forgets it", not pr.has_will("w_coat") and pr.will_color == "")
			check("load", SG.load_into(p))
			check("...the save keeps the purchases, the carried versions and the colour", pr.has_version("w_coat_heavy") and pr.version_of("w_coat") == 1
				and pr.owns("w_coat_quick") and not pr.owns("w_coat_heavy") and pr.has_will("w_roar") and pr.owns("h_harden") and pr.will_color == "blue")
			check("...and the points (earned 0 without the test's gift, 15 spent)", pr.will_earned == 0 and pr.spent("will") == 15)
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
