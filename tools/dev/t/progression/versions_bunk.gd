extends SceneTree
## Variants and the bunk: the iai upgrade bought at katana mastery 12 brings both versions, the first (Through the
## Guard: an iai that can't be blocked) active; the other (Mind's Eye: a faster charge) is switched to only at the
## ship's bunk, and then the first stops counting. A save keeps the active version. At the bunk a tree's purchases
## come back whole for gold (100 + 40 a Captain level): refused without the gold, saying how much.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_versions_bunk.dat"
var SG
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "katana", "water": true, "ship": true})


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
			while pr.level < 6:
				pr.add_xp(pr.xp_to_next(pr.level) - pr.xp)
			while pr.mastery_level("katana") < 12:
				var m: Dictionary = pr.mastery_of("katana")
				pr.add_mastery("katana", pr.mastery_to_next(int(m["lv"])) - int(m["xp"]))
			check("katana 12: 26 katana points", pr.pool("katana") == 26)
			check("the iai upgrade bought: both versions, the first active", pr.buy("k_iai") and pr.version_of("k_iai") == 0 and pr.owns("k_through"))
			check("...its iai can't be blocked, no faster charge", pr.style_stat("unblock", "katana") > 0.0 and pr.stat("iai_speed") == 0.0)
			check("away from the bunk the version stays", not pr.can_respec() and not pr.set_version("k_iai", 1) and pr.version_of("k_iai") == 0)
			check("Deep Draw (off the upgrade) bought", pr.buy("k_deep") and pr.pool("katana") == 20)
			check("away from the bunk no refund (%s)" % pr.respec_why("katana"), not pr.respec_tree("katana") and pr.respec_why("katana") == "Only at a rest spot")
			var ship = stage.ship
			p.global_position = ship.global_transform * (load("res://scripts/ship/ship.gd").BED_AT + Vector3(0.95, 0.1, 0.0))
			p.reset_physics_interpolation()
			check("by the ship's bunk", pr.can_respec())
			check("...Mind's Eye switched in", pr.set_version("k_iai", 1) and pr.version_of("k_iai") == 1 and pr.owns("k_eye") and not pr.owns("k_through"))
			check("...a faster charge, and the iai can be blocked again", is_equal_approx(pr.stat("iai_speed"), 0.3) and pr.style_stat("unblock", "katana") == 0.0)
			check("...a version not reached yet can't be picked", not pr.set_version("k_iai", 5))
			SG = load("res://scripts/game/save_game.gd")
			SG.use_test_file(SAVE)
			SG.save(p)
			pr.from_dict({})
			check("load", SG.load_into(p))
			check("...the active version kept", pr.version_of("k_iai") == 1 and pr.owns("k_eye") and not pr.owns("k_through") and is_equal_approx(pr.stat("iai_speed"), 0.3))
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			p.global_position = ship.global_transform * (load("res://scripts/ship/ship.gd").BED_AT + Vector3(0.95, 0.1, 0.0))
			p.reset_physics_interpolation()
			var inv = p.inventory_component
			inv.remove_item(ItemDB.get_item("gold"), inv.count("gold"))
			check("a katana respec costs 340 gold at Captain 6: refused without it (%s)" % pr.respec_why("katana"), pr.respec_price() == 340 and not pr.respec_tree("katana") and pr.respec_why("katana") == "Needs 340 gold" and pr.owns("k_iai"))
			inv.add_item(ItemDB.get_item("gold"), 400)
			check("...with 400 gold: the katana's purchases back whole, 60 gold left", pr.respec_tree("katana") and not pr.owns("k_iai") and not pr.owns("k_eye") and pr.steps_of("k_deep") == 0 and pr.pool("katana") == 26 and inv.count("gold") == 60)
			check("...nothing left to refund", pr.respec_why("katana") == "Nothing bought")
			return TK.done(fails)
	step += 1
	return false
