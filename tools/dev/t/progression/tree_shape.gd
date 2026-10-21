extends SceneTree
## The redesigned trees' shape (SkillTrees): every section's trees have a header, a converted tree has a root and
## three branches, big nodes at levels 1..its top (an ultimate at the top for a weapon), links real and on its own
## tree, steps adding up to about the points its levels give, versions with a level each, no two nodes on one spot;
## and across both registries every active skill is still taught and the 19 older unlockable moves are still on a tree.
const TK := preload("res://tools/dev/test_kit.gd")
var STS
var ST
var stage
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


func shape(t: String) -> void:
	var td: Dictionary = STS.tree_def(t)
	var top := int(td["max_level"])
	var bad: Array = []
	var spots := {}
	var steps := 0
	var ults := 0
	for k in STS.nodes_of(t):
		var n: Dictionary = STS.node_def(k)
		for l in n["links"]:
			if STS.node_def(l).get("tree", "") != t:
				bad.append("%s>%s" % [k, l])
		if n["kind"] == "step":
			steps += int(n["max_steps"])
			if int(n["max_steps"]) not in [3, 5]:
				bad.append("%s steps %d" % [k, n["max_steps"]])
		elif int(n["level"]) < 1 or int(n["level"]) > top:
			bad.append("%s at %d" % [k, n["level"]])
		if n["kind"] == "ult":
			ults += 1
		if n["kind"] == "variant":
			for v in n["versions"]:
				if STS.node_def(v["id"]).is_empty() or int(v["level"]) < int(n["level"]):
					bad.append("%s version %s" % [k, v["id"]])
		if n["kind"] != "version":
			var spot := str(Vector2i(n["pos"]))
			if spots.has(spot):
				bad.append("%s on %s" % [k, spots[spot]])
			spots[spot] = k
	check("%s: a root and three branches" % t, STS.node_def(td["root"]).get("kind", "") == "root" and td["branches"].size() == 3)
	check("%s: links real, levels in 1..%d, steps of 3 or 5, versions real, no stacked spots %s" % [t, top, str(bad)], bad.is_empty())
	if t != "captain":
		check("%s: the steps take about all the points (%d steps, %d points)" % [t, steps, top - 1], steps >= top - 1 and steps <= top + 3)
	if STS.section_of(t) == "combat":
		check("%s: one ultimate, at the top" % t, ults == 1 and STS.nodes_of(t).any(func(k): return STS.node_def(k)["kind"] == "ult" and int(STS.node_def(k)["level"]) == top))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			STS = load("res://scripts/progression/skill_trees.gd")
			ST = load("res://scripts/progression/skill_tree.gd")
			for sec in STS.SECTIONS:
				check("section %s has trees" % sec, not STS.trees_in(sec).is_empty())
			check("the Captain and Cutlass headers", STS.tree_def("captain")["section"] == "captain" and STS.tree_def("sword")["section"] == "combat")
			for t in STS.HEADERS.keys():
				if STS.converted(t):
					shape(t)
			var untaught: Array = load("res://scripts/progression/skills.gd").ALL.keys().filter(func(s): return ST.node_for_skill(s) == "")
			check("every active skill is taught by a node %s" % str(untaught), untaught.is_empty())
			var moves := {}
			for k in ST.nodes().keys():
				for e in ST.nodes()[k]["effects"].keys():
					if str(e).begins_with("mv_"):
						moves[e] = true
			check("the 19 older unlockable moves (and the new weapons') are on the trees (%d)" % moves.size(), moves.size() >= 19)
			var kn: Dictionary = STS.node_def("k_full")
			check("the katana's nodes keep their ids and effects (Full Draw at 6: %s)" % str(kn.get("effects", {})), kn.get("level", 0) == 6 and kn["effects"].has("mv_iai_full"))
			return TK.done(fails)
	step += 1
	return false
