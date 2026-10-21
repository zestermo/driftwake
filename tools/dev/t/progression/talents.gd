extends SceneTree
## Captain talents: one of two every 5 levels. Not before its level; the first pick anywhere (Mend: regen out of a
## fight); a change only at the ship's bunk (Iron Stomach: food heals more, Mend gone); a save keeps the pick; the
## level-35 pair is real (Quick Learner: more experience and faster mastery).
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_talents.dat"
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


func to_level(lv: int) -> void:
	while pr.level < lv:
		pr.add_xp(pr.xp_to_next(pr.level) - pr.xp)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			check("talents at 5..40", pr.talent_node(5) != "" and pr.talent_node(40) != "" and pr.talent_node(7) == "")
			check("not before level 5", not pr.pick_talent(5, 0) and pr.talent_at(5) == -1)
			to_level(5)
			check("unpicked at first", pr.talent_at(5) == -1 and not pr.owns("v_mend"))
			check("the first pick anywhere: Mend", not pr.can_respec() and pr.pick_talent(5, 0) and pr.talent_at(5) == 0 and pr.has_flag("regen_hp"))
			check("a change away from the bunk is refused", not pr.pick_talent(5, 1) and pr.talent_at(5) == 0)
			p.global_position = stage.ship.global_transform * (load("res://scripts/ship/ship.gd").BED_AT + Vector3(0.95, 0.1, 0.0))
			p.reset_physics_interpolation()
			check("by the bunk: Iron Stomach instead", pr.can_respec() and pr.pick_talent(5, 1) and pr.owns("v_stomach") and not pr.owns("v_mend"))
			check("...food heals 40% more, Mend's regen gone", is_equal_approx(pr.stat("potion_pct"), 0.4) and pr.stat("regen_hp") == 0.0)
			var SG = load("res://scripts/game/save_game.gd")
			SG.use_test_file(SAVE)
			SG.save(p)
			pr.from_dict({})
			check("load", SG.load_into(p))
			check("...the pick kept", pr.talent_at(5) == 1 and pr.owns("v_stomach"))
			to_level(35)
			var xp0: float = pr.stat("xp_pct")
			check("level 35: Quick Learner", pr.pick_talent(35, 0) and is_equal_approx(pr.stat("xp_pct") - xp0, 0.15) and is_equal_approx(pr.stat("mastery_pct"), 0.15))
			var m0 := int(pr.mastery_of("katana")["xp"])
			pr.add_mastery("katana", 20)
			check("...trees learn 15%% faster (20 -> %d)" % (int(pr.mastery_of("katana")["xp"]) - m0), int(pr.mastery_of("katana")["xp"]) - m0 == 23)
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
