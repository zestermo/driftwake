extends SceneTree
## Passives count only in a passive slot: Clean Line and Empty Mind bought at katana 22 go into free slots by
## themselves (the library lists them), Empty Mind's cooldown cut counts while slotted and not once it's taken
## out, an unowned passive or a slot past the last can't be filled, and a fourth slot opens at level 25.
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
			check("three empty slots", pr.passives.size() == 3 and pr.passives.count("") == 3)
			while pr.mastery_level("katana") < 22:
				var m: Dictionary = pr.mastery_of("katana")
				pr.add_mastery("katana", pr.mastery_to_next(int(m["lv"])) - int(m["xp"]))
			while pr.level < 6:
				pr.add_xp(pr.xp_to_next(pr.level) - pr.xp)
			check("katana 22, Captain 6: Clean Line and Empty Mind bought", pr.buy("k_clean") and pr.buy("k_calm"))
			check("...both passives in the library %s" % str(pr.library()["passives"]), pr.library()["passives"].has("k_clean") and pr.library()["passives"].has("k_calm"))
			check("...slotted by themselves %s" % str(pr.passives), pr.passives.has("k_clean") and pr.passives.has("k_calm"))
			check("...Empty Mind counts: katana techniques 25%% sooner (%.2f)" % pr.stat("cdr_katana"), is_equal_approx(pr.stat("cdr_katana"), 0.25))
			check("taken out", pr.equip_passive("", pr.passives.find("k_calm")) and not pr.passives.has("k_calm"))
			check("...and it stops counting (%.2f)" % pr.stat("cdr_katana"), pr.stat("cdr_katana") == 0.0)
			check("...still in the library", pr.library()["passives"].has("k_calm"))
			check("an unowned passive can't go in", not pr.equip_passive("s_flourish", 0) and not pr.equip_passive("k_eye", 0))
			check("no slot past the last", not pr.equip_passive("k_calm", 3))
			check("back in slot 0 (moving whatever was there out)", pr.equip_passive("k_calm", 0) and pr.passives[0] == "k_calm" and is_equal_approx(pr.stat("cdr_katana"), 0.25))
			check("one passive in one slot only", pr.equip_passive("k_calm", 2) and pr.passives.count("k_calm") == 1 and pr.passives[2] == "k_calm")
			pr.add_xp(999999)
			check("level 25+: a fourth slot (%d)" % pr.passives.size(), pr.level >= 25 and pr.passives.size() == 4 and pr.passives[2] == "k_calm")
			return TK.done(fails)
	step += 1
	return false
