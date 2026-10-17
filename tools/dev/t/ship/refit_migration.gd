extends SceneTree
## A save from before the upgrade lines (one-time refits as bools) loads as the lines' matching levels and
## nothing bought is lost: the iron straps' 40% hull, the third pair of guns, the larger sail's 15%, the
## rudder's 30%. Levels already saved as numbers stay, too high is clamped.
const TK := preload("res://tools/dev/test_kit.gd")
var KIT
var SG
const SAVE := "user://t_refit_migration.dat"
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			KIT = load("res://scripts/ship/ship_kit.gd")
			SG = load("res://scripts/game/save_game.gd")
			var m: Dictionary = KIT.merged({"armour": true, "guns": false, "sails": 3, "rudder": 99})
			check("old bools become levels, numbers stay, too high is clamped", m["armour"] == 5 and m["guns"] == 0 and m["sails"] == 3 and m["rudder"] == 5)
			var p = stage.player
			var ship = stage.ship
			var gm = root.get_node("GameManager")
			SG.use_test_file(SAVE)
			SG.save(p)
			var f := FileAccess.open(SAVE, FileAccess.READ)
			var data: Dictionary = f.get_var()
			f.close()
			data["ship_kit"] = {"armour": true, "guns": true, "sails": true, "rudder": true, "hull": 2, "figure": 1}
			f = FileAccess.open(SAVE, FileAccess.WRITE)
			f.store_var(data)
			f.close()
			gm.ship_kit = KIT.fresh()
			ship.apply_kit(gm.ship_kit)
			SG.load_into(p)
			var k: Dictionary = gm.ship_kit
			check("the old refits load as levels (armour %s, guns %s, sails %s, rudder %s)" % [k["armour"], k["guns"], k["sails"], k["rudder"]],
				k["armour"] == 5 and k["guns"] == 2 and k["sails"] == 5 and k["rudder"] == 5 and k["hull"] == 2 and k["figure"] == 1)
			print("   hull %.0f, guns %d, speed x%.2f, turn x%.2f" % [ship.max_hull, ship.cannons.size(), ship._top_k, ship._turn_k])
			check("...and she keeps what was bought: 40% hull, three guns a side, 15% speed, 30% turning",
				is_equal_approx(ship.max_hull, 560.0) and ship.cannons.size() == 6 and is_equal_approx(ship._top_k, 1.15) and is_equal_approx(ship._turn_k, 1.3))
			check("...with every level's parts on her", ship.parts.pieces("armour") == 5 and ship.parts.pieces("sails") == 5)
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
