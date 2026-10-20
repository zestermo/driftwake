extends SceneTree
## A format-4 save (the 1.18 trees) loads into the redesign: the katana's bought nodes are dropped and its mastery
## level kept, so its big nodes come back by level and every point is free again; a tree not converted yet (the
## cutlass) keeps what it bought and its points; uses kept; the katana is found (it shows); a refund banner.
## Saved again it loads as it is, steps and all.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_format5_migration.dat"
var SG
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
			SG = load("res://scripts/game/save_game.gd")
			p = stage.player
			pr = p.progression
			SG.use_test_file(SAVE)
			SG.save(p)
			var f := FileAccess.open(SAVE, FileAccess.READ)
			var data: Dictionary = f.get_var()
			f.close()
			data["progression"] = {"format": 4, "level": 7, "xp": 50, "sp": 3,
				"owned": ["origin", "c_agility", "s_root", "s_edge", "k_root", "k_folded", "k_full", "k_saint", "k_petals"],
				"mastery": {"sword": {"lv": 5, "xp": 10, "pts": 2}, "katana": {"lv": 9, "xp": 30, "pts": 0}},
				"tiers": {}, "uses": {"wind_sever": 7}}
			f = FileAccess.open(SAVE, FileAccess.WRITE)
			f.store_var(data)
			f.close()
			pr.from_dict({})
			check("load", SG.load_into(p))
			print("   katana %s free %d owned %s" % [pr.mastery_of("katana"), pr.points_free("katana"), pr.owned.keys()])
			check("katana mastery kept", pr.mastery_level("katana") == 9 and int(pr.mastery_of("katana")["xp"]) == 30)
			check("...what it bought is gone (Folded Steel, the ultimate)", not pr.owns("k_folded") and not pr.owns("k_saint") and not pr.owns("k_petals"))
			check("...its big nodes back by level (Quick Draw 2 .. Iai Counter 8)", pr.owns("k_draw") and pr.owns("k_wind") and pr.owns("k_full") and pr.owns("k_counter") and not pr.owns("k_tiger"))
			check("...every point free: 8", pr.points_free("katana") == 8)
			check("the cutlass (not converted yet) keeps its nodes and points", pr.owns("s_edge") and pr.points("sword") == 2 and pr.skill_points == 3)
			check("uses kept", pr.uses_of("wind_sever") == 7)
			check("the katana shows", "katana" in pr.visible_trees("combat"))
			pr.buy_step("k_keen")
			pr.buy_step("k_keen")
			SG.save(p)
			pr.from_dict({})
			check("load again", SG.load_into(p))
			check("...as it was: two steps, 6 points", pr.steps_of("k_keen") == 2 and pr.points_free("katana") == 6 and pr.owns("k_counter"))
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
