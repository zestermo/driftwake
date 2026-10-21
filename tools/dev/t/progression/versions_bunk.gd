extends SceneTree
## Variants: at katana mastery 12 the iai upgrade comes with both versions owned and the first (Through the Guard:
## an iai that can't be blocked) active; the other (Mind's Eye: a faster charge) is switched to only at the ship's
## bunk, and then the first stops counting. Steps are refunded there too. A save keeps the active version.
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
			while pr.mastery_level("katana") < 12:
				var m: Dictionary = pr.mastery_of("katana")
				pr.add_mastery("katana", pr.mastery_to_next(int(m["lv"])) - int(m["xp"]))
			check("mastery 12: the iai upgrade, the first version active", pr.owns("k_iai") and pr.version_of("k_iai") == 0 and pr.owns("k_through"))
			check("...its iai can't be blocked, no faster charge", pr.style_stat("unblock", "katana") > 0.0 and pr.stat("iai_speed") == 0.0)
			check("away from the bunk the version stays", not pr.can_respec() and not pr.set_version("k_iai", 1) and pr.version_of("k_iai") == 0)
			pr.buy_step("k_deep")
			var ship = stage.ship
			p.global_position = ship.global_transform * (load("res://scripts/ship/ship.gd").BED_AT + Vector3(0.95, 0.1, 0.0))
			p.reset_physics_interpolation()
			check("by the ship's bunk", pr.can_respec())
			check("...Mind's Eye switched in", pr.set_version("k_iai", 1) and pr.version_of("k_iai") == 1 and pr.owns("k_eye") and not pr.owns("k_through"))
			check("...a faster charge, and the iai can be blocked again", is_equal_approx(pr.stat("iai_speed"), 0.3) and pr.style_stat("unblock", "katana") == 0.0)
			check("...a version not reached yet can't be picked", not pr.set_version("k_iai", 5))
			check("...the steps come back as points", pr.respec_steps("katana") and pr.steps_of("k_deep") == 0 and pr.points_free("katana") == 11)
			SG = load("res://scripts/game/save_game.gd")
			SG.use_test_file(SAVE)
			SG.save(p)
			pr.from_dict({})
			check("load", SG.load_into(p))
			check("...the active version kept", pr.version_of("k_iai") == 1 and pr.owns("k_eye") and not pr.owns("k_through") and is_equal_approx(pr.stat("iai_speed"), 0.3))
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
