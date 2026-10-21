extends SceneTree
## Will comes from bosses, not levels: the Brood Queen beaten first is remembered but Sense waits for Iron Will;
## beating Captain Morrow brings Iron Will (heavies can't be blocked) and its passive (Hardening, in the library and
## a slot), and then Sense too; Captain's Will needs every other Will. A save keeps them. A grunt is no Will boss.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_will_bosses.dat"
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -12), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			until = TK.wait_ticks(10)
		1:
			p = stage.player
			pr = p.progression
			check("no Will at first", not pr.has_will("h_arm") and not pr.has_flag("armament"))
			pr.beat("queen")
			check("the queen beaten first: remembered, but Sense waits for Iron Will", pr.beaten.has("queen") and not pr.has_will("h_obs"))
			pr.beat("morrow")
			check("Morrow beaten: Iron Will", pr.has_will("h_arm") and pr.has_flag("armament"))
			check("...its passive in the library, slotted", pr.library()["passives"].has("h_harden") and pr.passives.has("h_harden") and pr.stat("defense") >= 8.0)
			check("...and Sense opens now (the queen's)", pr.has_will("h_obs") and pr.has_flag("observation"))
			pr.beat("sea_king")
			check("Captain's Will needs every other Will", not pr.has_will("h_conq"))
			pr.beat("ape")
			pr.beat("arena")
			check("...then a Sea King already beaten counts: Conqueror's Will known", pr.has_will("h_conq") and pr.knows("conquerors_haki"))
			var SG = load("res://scripts/game/save_game.gd")
			SG.use_test_file(SAVE)
			SG.save(p)
			pr.from_dict({})
			check("a fresh block forgets it", not pr.has_will("h_arm"))
			check("load", SG.load_into(p))
			check("...a save keeps the Wills and their passives", pr.has_will("h_arm") and pr.has_will("h_conq") and pr.owns("h_harden") and pr.knows("armament_coat"))
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			var g = p.get_tree().get_nodes_in_group("enemies")[0]
			check("a plain grunt is no Will boss", pr.boss_kind(g) == "")
			g.add_to_group("bosses")
			check("...flagged a boss it's elite (x3 kill share), still no Will boss", pr.is_elite(g) and pr.boss_kind(g) == "")
			return TK.done(fails)
	step += 1
	return false
