extends SceneTree
## Where Will points come from (1.23): a big fight in reach (Net.bounty): a boss 2, a hunter 2, a Leviathan 2, a rival
## captain 1, an officer 1, a miniboss (a boss at under full scale) 1; a sunk ship or one out of reach none. Meditating
## (Downtime "meditate") gives a point every 3 game days of it. An older save's Wills (format 7) come back as 2 points
## each; Squall Step is gone from the bar until bought in Acrobatics.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_will_points.dat"
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
			p = stage.player
			pr = p.progression
			var net = root.get_node("Net")
			var at: Vector3 = p.global_position
			net.bounty("boss", at + Vector3(5, 0, 0), 60.0)
			check("a boss beaten in reach: 2 Will", pr.will_earned == 2 and pr.pool("will") == 2)
			net.bounty("boss", at + Vector3(500, 0, 0), 60.0)
			check("...out of reach: none", pr.will_earned == 2)
			net.bounty("rival", at, 60.0, 2.0)
			net.bounty("hunter", at, 60.0)
			net.bounty("officer", at, 60.0)
			net.bounty("leviathan", at, 120.0)
			check("a rival captain 1, a hunter 2, an officer 1, a Leviathan 2 (%d)" % pr.will_earned, pr.will_earned == 8)
			net.bounty("boss", at, 70.0, 0.4)
			check("a miniboss 1", pr.will_earned == 9)
			net.bounty("ship", at, 160.0)
			check("a ship sunk: none", pr.will_earned == 9)
			var k: float = pr.meditate(WillPaths.MEDITATE_SECS * 0.5)
			check("half of 3 game days meditating: half a point", is_equal_approx(k, 0.5) and pr.will_earned == 9)
			pr.meditate(WillPaths.MEDITATE_SECS * 0.75)
			check("...the rest of it: a point, a quarter toward the next", pr.will_earned == 10 and is_equal_approx(float(pr.downtime["meditate_s"]), WillPaths.MEDITATE_SECS * 0.25))
			var DT = load("res://scripts/game/downtime.gd")
			check("meditation is on the downtime wheel, aboard or at camp", DT.KINDS.has("meditate") and DT.pose_of(p, "meditate") == "dt_meditate")
			SG = load("res://scripts/game/save_game.gd")
			SG.use_test_file(SAVE)
			SG.save(p)
			var f := FileAccess.open(SAVE, FileAccess.READ)
			var data: Dictionary = f.get_var()
			f.close()
			data["progression"] = {"format": 7, "level": 16, "xp": 0, "bought": [], "mastery": {}, "steps": {}, "versions": {},
				"found": [], "tiers": {}, "uses": {"soru": 20}, "passives": ["h_harden", "", ""], "will": ["h_arm", "h_coat", "h_obs"], "beaten": ["morrow", "ape", "queen"],
				"owned": ["c_root", "m_soru", "h_arm", "h_coat", "h_obs", "h_harden"]}
			data["power"]["loadout"] = ["soru", "armament_coat", "", "", "", ""]
			f = FileAccess.open(SAVE, FileAccess.WRITE)
			f.store_var(data)
			f.close()
			pr.from_dict({})
			check("load a format-7 save", SG.load_into(p))
			print("   will %d bought %s bar %s" % [pr.will_earned, pr.bought.keys(), p.power.loadout])
			check("its three Wills came back as 6 Will points, nothing bought", pr.will_earned == 6 and pr.pool("will") == 6 and not pr.has_will("w_coat") and not pr.owns("h_harden"))
			check("...Squall Step and the coat off the bar, the passive slot empty", not ("soru" in p.power.loadout) and not ("armament_coat" in p.power.loadout) and not pr.passives.has("h_harden"))
			check("...Squall Step's uses kept", pr.uses_of("soru") == 20)
			SG.save(p)
			pr.from_dict({})
			check("load again", SG.load_into(p))
			check("...still 6, not refunded twice", pr.will_earned == 6)
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
