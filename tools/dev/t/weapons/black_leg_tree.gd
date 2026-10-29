extends SceneTree
## The Black Leg tree (SkillTrees "black_leg"): its root and three branches, every node on it, its moves and skills
## real (each a black-leg Technique), its steps 30, one ultimate at 30, heat as its element (its own palette, apart
## from the axe's embers), Nonchalance at 10, the style mapped to it; and with it mastered each technique and the
## ultimate lands on the dummy (Sky Chase needs a foe in the air: t/combat/black_leg_launch), Rising Heel's heel
## going up high over the hips.
const TK := preload("res://tools/dev/test_kit.gd")
const TECHS := ["last_course", "rising_heel", "hailstorm_heels", "sky_chase", "cleaver_kick", "flambe_dash"]
var stage
var p
var taken := 0.0
var heels := -9.0
var ti := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3.0)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if step == 2 and p.body_model.current_action() == "bl_rise":
		var BLA = load("res://scripts/player_states/black_leg_arts.gd")
		heels = maxf(heels, BLA.foot(p, true).y - p.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var STS = load("res://scripts/progression/skill_trees.gd")
			var ST = load("res://scripts/progression/skill_tree.gd")
			var SK = load("res://scripts/progression/skills.gd")
			var fx = load("res://scripts/game/fx.gd")
			var td: Dictionary = STS.tree_def("black_leg")
			check("a Black Leg tree in Combat with a root and three branches", STS.section_of("black_leg") == "combat" and STS.converted("black_leg")
				and STS.node_def(td["root"]).get("kind", "") == "root" and td["branches"].size() == 3)
			var steps := 0
			var ults: Array = []
			var skills: Array = []
			var moves: Array = []
			var bad: Array = []
			for k in STS.nodes_of("black_leg"):
				var n: Dictionary = STS.node_def(k)
				for l in n["links"]:
					if STS.node_def(l).get("tree", "") != "black_leg":
						bad.append(k)
				if n["kind"] == "step":
					steps += int(n["max_steps"])
				if n["kind"] == "ult":
					ults.append(int(n["level"]))
				if str(n["skill"]) != "":
					skills.append(n["skill"])
				for e in n["effects"].keys():
					if str(e).begins_with("mv_"):
						moves.append(str(e).trim_prefix("mv_"))
			check("its links stay on the tree %s" % str(bad), bad.is_empty())
			check("30 steps for its 29 points (%d)" % steps, steps == 30)
			check("two ultimates (1.26), at 30 (%s)" % str(ults), ults == [30, 30])
			check("its moves: Handstand Spin, Arrow Kick, Cyclone Heel (%s)" % str(moves),
				moves.size() == 3 and "handstand_spin" in moves and "arrow_kick" in moves and "cyclone_heel" in moves)
			var techs_ok := skills.size() == 6
			for sk in skills:
				var d: Dictionary = SK.get_skill(sk)
				techs_ok = techs_ok and d.get("styles", []) == ["black_leg"] and d.get("state", "") == "Technique" and d.get("tree", "") == "black_leg"
			check("its six skills are black-leg techniques %s" % str(skills), techs_ok and skills.all(func(x): return x in TECHS))
			check("its element (heat) at 16 and 25", STS.node_def("bl_elem").get("level", 0) == 16 and STS.node_def("bl_elem2").get("level", 0) == 25
				and fx.TREE_FX.has("black_leg"))
			var a: Color = fx.TREE_FX["axe"][1]
			var h: Color = fx.TREE_FX["black_leg"][1]
			check("its heat is red, not the axe's ember orange (green %.2f vs %.2f)" % [h.g, a.g], a.g - h.g > 0.2)
			check("Nonchalance (hands in the pockets) at 10", STS.node_def("bl_pockets").get("level", 0) == 10
				and STS.node_def("bl_pockets")["effects"].has("pockets_black_leg"))
			check("the black-leg style builds its mastery", ST.style_tree("black_leg") == "black_leg")
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(hd, _a): taken += hd.damage)
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.learn_black_leg()
			p.progression.master_all()
			TK.act("ready_weapon")
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.6)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.power.ult = p.power.ULT_MAX
			p.power.energy = 999.0
			taken = 0.0
			p.state_machine.force_state("Technique", {"id": TECHS[ti], "slot": 4 if TECHS[ti] == "last_course" else 0})
			until = TK.wait_secs(2.9 if TECHS[ti] == "last_course" else 1.7)
		2:
			if TECHS[ti] == "sky_chase":
				check("Sky Chase with nothing in the air does nothing and is given back", taken == 0.0 and float(p.power.cooldowns.get("sky_chase", 0.0)) <= 0.0)
			else:
				check("%s lands on the dummy (%.0f damage)" % [TECHS[ti], taken], taken > 0.0)
			if TECHS[ti] == "rising_heel":
				check("Rising Heel swings the heel up high, over the head (%.2f m)" % heels, heels > 1.8)
			ti += 1
			if ti < TECHS.size():
				step = 1
				until = TK.wait_secs(0.4)
				return false
			check("back in the guard after the ultimate, hurtbox on", p.hurtbox.monitorable)
			return TK.done(fails)
	step += 1
	return false
