extends SceneTree
## The rapier's tree (SkillTrees "rapier"): its root and three branches, its links on the tree, its moves and skills
## real (each a rapier Technique), its steps 30, two ultimates at 30, quicksilver as its element, the style mapped to
## it; and with it mastered each technique and both ultimates land on the dummy, the hurtbox back on after.
const TK := preload("res://tools/dev/test_kit.gd")
const TECHS := ["hall_of_mirrors", "silver_meridian", "needle_rain", "glass_step", "glass_feint", "balestra"]
const ULTS := ["hall_of_mirrors", "silver_meridian"]
var stage
var p
var taken := 0.0
var ti := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3.0), "weapon": "rapier"})


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
			var td: Dictionary = STS.tree_def("rapier")
			check("a Rapier tree in Combat with a root and three branches", STS.section_of("rapier") == "combat" and STS.converted("rapier")
				and STS.node_def(td["root"]).get("kind", "") == "root" and td["branches"].size() == 3)
			var steps := 0
			var ults: Array = []
			var skills: Array = []
			var moves: Array = []
			var bad: Array = []
			for k in STS.nodes_of("rapier"):
				var n: Dictionary = STS.node_def(k)
				for l in n["links"]:
					if STS.node_def(l).get("tree", "") != "rapier":
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
			check("30 steps (%d)" % steps, steps == 30)
			check("two ultimates at 30 (%s)" % str(ults), ults == [30, 30])
			check("its moves: Mercury Flurry, Fleche (%s)" % str(moves), moves.size() == 2 and "mercury_flurry" in moves and "fleche" in moves)
			var ok := skills.size() == TECHS.size()
			for sk in skills:
				var d: Dictionary = SK.get_skill(sk)
				ok = ok and d.get("styles", []) == ["rapier"] and d.get("state", "") == "Technique" and d.get("tree", "") == "rapier"
			check("its skills are rapier techniques %s" % str(skills), ok and skills.all(func(x): return x in TECHS))
			check("its element (quicksilver) at 16 and 25", STS.node_def("rp_elem").get("level", 0) == 16 and STS.node_def("rp_elem2").get("level", 0) == 25
				and load("res://scripts/game/fx.gd").TREE_FX.has("rapier"))
			check("the rapier style builds its mastery", ST.style_tree("rapier") == "rapier")
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			stage.camera_rig.rotation.y = 0.0
			p.progression.master_all()
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
			p.state_machine.force_state("Technique", {"id": TECHS[ti], "slot": 4 if TECHS[ti] in ULTS else 0})
			until = TK.wait_secs(3.0 if TECHS[ti] in ULTS else 1.6)
		2:
			check("%s lands on the dummy (%.0f damage)" % [TECHS[ti], taken], taken > 0.0)
			ti += 1
			if ti < TECHS.size():
				step = 1
				until = TK.wait_secs(0.6)
				return false
			until = TK.wait_secs(0.5)
		3:
			check("back on its feet after them, hurtbox on, enemies collide again", p.hurtbox.monitorable and p.get_collision_mask_value(12))
			return TK.done(fails)
	step += 1
	return false
