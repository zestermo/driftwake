extends SceneTree
## A save from before the fists' Power branch: its Suplex and Giant Swing nodes (u_suplex, u_swing) are bought back as
## Cannonball Fist and Meteor Fist (same gates and prices), Stone Skin's steps hang on Cannonball Fist now, and the bar
## slots holding the old skills hold the new ones.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_fist_rename.dat"
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
			data["progression"] = {"format": 7, "level": 30, "xp": 0,
				"bought": ["u_hip", "u_suplex", "u_swing"],
				"mastery": {"unarmed": {"lv": 20, "xp": 0}}, "steps": {"u_skin": 2}, "versions": {}, "found": ["unarmed"],
				"tiers": {}, "uses": {}, "passives": ["", "", ""]}
			data["power"]["loadout"] = ["suplex", "giant_swing", "hip_toss", "", "", ""]
			f = FileAccess.open(SAVE, FileAccess.WRITE)
			f.store_var(data)
			f.close()
			pr.from_dict({})
			check("load", SG.load_into(p))
			print("   bought %s steps %s bar %s" % [pr.bought.keys(), pr.steps, p.power.loadout])
			check("Suplex comes back as Cannonball Fist, Giant Swing as Meteor Fist", pr.owns("u_cannon") and pr.owns("u_meteor_fist") and pr.owns("u_hip"))
			check("the old nodes are gone", SkillTrees.node_def("u_suplex").is_empty() and SkillTrees.node_def("u_swing").is_empty())
			check("Stone Skin's steps kept, on Cannonball Fist", int(pr.steps.get("u_skin", 0)) == 2 and "u_cannon" in SkillTrees.node_def("u_skin")["links"])
			check("the bar's old skills are the new ones", p.power.loadout[0] == "cannonball_fist" and p.power.loadout[1] == "meteor_fist" and p.power.loadout[2] == "hip_toss")
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
