extends SceneTree
## The long gun's tree (SkillTrees "long_gun"): its root and three branches, every node on it, its moves and skills real
## (each skill a long gun Technique), its steps 30, one ultimate at 30, starlight as its element, the style mapped to it,
## its nodes buyable with long gun mastery; and with it mastered each technique and the ultimate lands on the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
const TECHS := ["hawkeye", "pin_shot", "powder_burst", "volley_line", "stock_sweep"]
var stage
var p
var taken := 0.0
var ti := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3.0), "weapon": "musket"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var STS = load("res://scripts/progression/skill_trees.gd")
			var ST = load("res://scripts/progression/skill_tree.gd")
			var SK = load("res://scripts/progression/skills.gd")
			var td: Dictionary = STS.tree_def("long_gun")
			check("a Long Gun tree in Combat with a root and three branches", STS.section_of("long_gun") == "combat" and STS.converted("long_gun")
				and STS.node_def(td["root"]).get("kind", "") == "root" and td["branches"].size() == 3)
			var steps := 0
			var ults: Array = []
			var skills: Array = []
			var moves: Array = []
			var bad: Array = []
			for k in STS.nodes_of("long_gun"):
				var n: Dictionary = STS.node_def(k)
				for l in n["links"]:
					if STS.node_def(l).get("tree", "") != "long_gun":
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
			check("its moves: Stock Rush, Sky Shot (%s)" % str(moves), moves.size() == 2 and "stock_rush" in moves and "sky_shot" in moves)
			var techs_ok := skills.size() == TECHS.size()
			for sk in skills:
				var d: Dictionary = SK.get_skill(sk)
				techs_ok = techs_ok and d.get("styles", []) == ["long_gun"] and d.get("state", "") == "Technique" and d.get("tree", "") == "long_gun"
			check("its skills are long gun techniques %s" % str(skills), techs_ok and skills.all(func(x): return x in TECHS))
			check("its element (starlight) at 16 and 25", STS.node_def("lg_elem").get("level", 0) == 16 and STS.node_def("lg_elem2").get("level", 0) == 25
				and load("res://scripts/game/fx.gd").TREE_FX.has("long_gun"))
			check("the long gun style builds its mastery, paid in its own points", ST.style_tree("long_gun") == "long_gun" and STS.pool_of("long_gun") == "long_gun"
				and STS.price("lg_pin") > 0)
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			stage.camera_rig.rotation.y = 0.0
			var pr = p.progression
			pr.add_mastery("long_gun", 1)
			pr.mastery_of("long_gun")["lv"] = 10
			var free0: int = pr.points_free("long_gun")
			check("with long gun mastery 10: Iron Sights, then Pinning Shot, bought from its points (%s)" % pr.buy_why("lg_sights"), pr.buy("lg_sights") and pr.buy("lg_pin")
				and "pin_shot" in pr.known_skills() and pr.points_free("long_gun") < free0)
			check("Hawkeye waits for mastery 30 (%s)" % pr.buy_why("lg_hawk"), not pr.buy("lg_hawk"))
			pr.master_all()
			check("mastered, its nodes are owned (Pinning Shot, Stock Rush)", p.progression.has_move("stock_rush") and "pin_shot" in p.progression.known_skills())
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.6)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.power.ult = p.power.ULT_MAX
			p.power.energy = 999.0
			p._reset_ammo()
			taken = 0.0
			p.state_machine.force_state("Technique", {"id": TECHS[ti], "slot": 4 if TECHS[ti] == "hawkeye" else 0})
			until = TK.wait_secs(2.2)
		2:
			check("%s lands on the dummy (%.0f damage)" % [TECHS[ti], taken], taken > 0.0)
			ti += 1
			if ti < TECHS.size():
				step = 1
				until = TK.wait_secs(0.4)
				return false
			check("back in the guard after the ultimate, hurtbox on", p.hurtbox.monitorable)
			return TK.done(fails)
	step += 1
	return false
