extends SceneTree
## The greatsword's tree (SkillTrees "greatsword"): its root and three branches, every node on it, its moves and
## skills real (each skill a greatsword Technique), its steps 30, one ultimate at 30, wind as its element, the style
## mapped to it; and with it mastered each technique and the ultimate lands on the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
const TECHS := ["skysplitter", "guardbreaker", "crescent_gale", "tempest_turns", "updraft", "gatekeeper"]
var stage
var p
var taken := 0.0
var ti := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3.0), "weapon": "greatsword"})


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
			var td: Dictionary = STS.tree_def("greatsword")
			check("a Greatsword tree in Combat with a root and three branches", STS.section_of("greatsword") == "combat" and STS.converted("greatsword")
				and STS.node_def(td["root"]).get("kind", "") == "root" and td["branches"].size() == 3)
			var steps := 0
			var ults: Array = []
			var skills: Array = []
			var moves: Array = []
			var bad: Array = []
			for k in STS.nodes_of("greatsword"):
				var n: Dictionary = STS.node_def(k)
				for l in n["links"]:
					if STS.node_def(l).get("tree", "") != "greatsword":
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
			check("one ultimate, at 30 (%s)" % str(ults), ults == [30])
			check("its moves: Gale Turn, Running Cleave, Falling Cleave (%s)" % str(moves),
				moves.size() == 3 and "gale_turn" in moves and "running_cleave" in moves and "falling_cleave" in moves)
			var techs_ok := skills.size() == 6
			for sk in skills:
				var d: Dictionary = SK.get_skill(sk)
				techs_ok = techs_ok and d.get("styles", []) == ["greatsword"] and d.get("state", "") == "Technique" and d.get("tree", "") == "greatsword"
			check("its six skills are greatsword techniques %s" % str(skills), techs_ok and skills.all(func(x): return x in TECHS))
			check("its element (wind) at 16 and 25", STS.node_def("gs_elem").get("level", 0) == 16 and STS.node_def("gs_elem2").get("level", 0) == 25
				and load("res://scripts/game/fx.gd").TREE_FX.has("greatsword"))
			check("the greatsword style builds its mastery", ST.style_tree("greatsword") == "greatsword")
			p = stage.player
			# (the dummy heals to full when it would die: count what lands instead)
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
			p.state_machine.force_state("Technique", {"id": TECHS[ti], "slot": 4 if TECHS[ti] == "skysplitter" else 0})
			until = TK.wait_secs(2.6 if TECHS[ti] in ["skysplitter", "updraft"] else 1.9)
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
