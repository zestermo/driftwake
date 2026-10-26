extends SceneTree
## 1.23: a save from before black-leg's juggle set: its Mule Kick and Cartwheel Crescent nodes (bl_mule, bl_wheel) are
## bought back as Rising Heel and Sky Chase (same gates and prices), Heavy Heel's steps hang on Sky Chase now, and the
## bar slots holding the old skills hold the new ones.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_black_leg_rename.dat"
var SG
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
			SG = load("res://scripts/game/save_game.gd")
			p = stage.player
			pr = p.progression
			SG.use_test_file(SAVE)
			SG.save(p)
			var f := FileAccess.open(SAVE, FileAccess.READ)
			var data: Dictionary = f.get_var()
			f.close()
			data["progression"] = {"format": 6, "level": 30, "xp": 0,
				"bought": ["bl_hail", "bl_mule", "bl_wheel"],
				"mastery": {"black_leg": {"lv": 20, "xp": 0}}, "steps": {"bl_heel": 2}, "versions": {}, "found": ["black_leg"],
				"tiers": {}, "uses": {}, "passives": ["", "", ""]}
			data["power"]["loadout"] = ["mule_kick", "cartwheel_crescent", "hailstorm_heels", "", "", ""]
			f = FileAccess.open(SAVE, FileAccess.WRITE)
			f.store_var(data)
			f.close()
			pr.from_dict({})
			check("load", SG.load_into(p))
			print("   bought %s steps %s bar %s" % [pr.bought.keys(), pr.steps, p.power.loadout])
			check("Mule Kick comes back as Rising Heel, Cartwheel Crescent as Sky Chase", pr.owns("bl_rise") and pr.owns("bl_sky") and pr.owns("bl_hail"))
			check("the old nodes are gone", SkillTrees.node_def("bl_mule").is_empty() and SkillTrees.node_def("bl_wheel").is_empty())
			check("Heavy Heel's steps kept, on Sky Chase", int(pr.steps.get("bl_heel", 0)) == 2 and "bl_sky" in SkillTrees.node_def("bl_heel")["links"])
			check("the bar's old skills are the new ones", p.power.loadout[0] == "rising_heel" and p.power.loadout[1] == "sky_chase" and p.power.loadout[2] == "hailstorm_heels")
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
