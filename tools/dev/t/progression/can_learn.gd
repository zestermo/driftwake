extends SceneTree
## What can be learned and with what: the Captain tree with skill points, a weapon tree with its own mastery
## points (not skill points), a link first, a level, a Devil Fruit, the element's first node before its second,
## a Seafarer node only once its life skill is high enough, a life skill's perk never.
## And the trees' shape: fewer, bigger nodes, every link real and on its own tree, every node reachable from its
## root, no two nodes on one spot, every active skill and every unlockable move still taught somewhere.
const TK := preload("res://tools/dev/test_kit.gd")
var ST
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


func shape() -> void:
	var nodes: Dictionary = ST.nodes()
	var bad_links: Array = []
	var cut_off: Array = []
	var stacked: Array = []
	var spots := {}
	var moves := {}
	for k in nodes.keys():
		var n: Dictionary = nodes[k]
		for l in n["links"]:
			if not nodes.has(l) or nodes[l]["tree"] != n["tree"]:
				bad_links.append("%s>%s" % [k, l])
		var spot := "%s %s" % [ST.tab_of(n["tree"]) + str(n["req"].get("fruit", "")), str(Vector2i(n["pos"]))]
		if spots.has(spot):
			stacked.append("%s/%s" % [spots[spot], k])
		spots[spot] = k
		for e in n["effects"].keys():
			if str(e).begins_with("mv_"):
				moves[e] = true
	for t in ST.TREES.keys():
		if ST.kind_of(t) == "tab" or t == "fruit":
			continue
		var seen := {ST.root_of(t): true}
		var todo: Array = [ST.root_of(t)]
		while not todo.is_empty():
			for l in ST.neighbors(todo.pop_back()):
				if not seen.has(l):
					seen[l] = true
					todo.append(l)
		for k in nodes.keys():
			if nodes[k]["tree"] == t and not seen.has(k):
				cut_off.append(k)
	check("every link is a node on its own tree %s" % str(bad_links), bad_links.is_empty())
	check("every node reachable from its tree's root %s" % str(cut_off), cut_off.is_empty())
	check("no two nodes on one spot %s" % str(stacked), stacked.is_empty())
	var untaught: Array = load("res://scripts/progression/skills.gd").ALL.keys().filter(func(s): return ST.node_for_skill(s) == "")
	check("every active skill is taught by a node %s" % str(untaught), untaught.is_empty())
	check("all 19 unlockable moves are still on the trees (%d)" % moves.size(), moves.size() == 19)
	var sizes := {}
	for t in ST.TREES.keys():
		if ST.is_weapon_tree(t) or t == "base":
			sizes[t] = nodes.keys().filter(func(k): return nodes[k]["tree"] == t).size()
	print("   nodes per tree: %s" % str(sizes))
	var big := sizes.keys().filter(func(t): return t != "base" and sizes[t] > 19)
	check("weapon trees cut to a few big nodes (19 at most) %s" % str(big), big.is_empty())
	check("the Captain tree under 36 nodes (%d)" % sizes["base"], sizes["base"] < 36)
	var filler: Array = nodes.keys().filter(func(k): return nodes[k]["kind"] in ["stat", "passive"] and ST.is_weapon_tree(nodes[k]["tree"]) and int(nodes[k]["cost"]) < 2)
	check("no 1-point filler in the weapon trees %s" % str(filler), filler.is_empty())


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			ST = load("res://scripts/progression/skill_tree.gd")
			p = stage.player
			pr = p.progression
			shape()
			check("a Captain node costs skill points (%s)" % pr.can_learn("c_agility"), pr.can_learn("c_agility") == "Needs 2 skill points")
			check("an unlinked node waits for a link", pr.can_learn("m_geppo") == "Learn a linked node first")
			pr.skill_points = 2
			check("learned with skill points", pr.learn("c_agility") and pr.skill_points == 0)
			pr.skill_points = 10
			check("a weapon node costs that weapon's mastery points, not skill points (%s)" % pr.can_learn("s_edge"), pr.can_learn("s_edge") == "Needs 2 mastery points")
			pr.mastery_of("sword")["pts"] = 2
			check("...learned with them", pr.learn("s_edge") and pr.points("sword") == 0 and pr.skill_points == 10)
			check("the ultimate waits for its level (%s)" % pr.can_learn("s_kraken"), pr.can_learn("s_kraken") == "Needs level 12")
			pr.level = 16
			pr.mastery_of("sword")["pts"] = 20
			pr.owned["s_flying"] = true
			pr.owned["s_swordfish"] = true
			pr.owned["s_captain"] = true
			check("the element's second node needs its first (%s)" % pr.can_learn("s_elem2"), pr.can_learn("s_elem2") == "Needs Call of the Tide")
			check("a fruit's node needs the fruit", pr.can_learn("e_fist").begins_with("Needs the"))
			check("a Seafarer node needs its life skill first (%s)" % pr.can_learn("f_swim"), pr.learn("c_legs") and pr.can_learn("f_swim") == "Needs Swimming 4")
			while pr.mastery_level("swim") < 4:
				pr.add_life("swim", pr.mastery_to_next(pr.mastery_level("swim")))
			var sp0: float = pr.stat("swim_pct")
			check("...and then it's a choice like any other", pr.learn("f_swim") and is_equal_approx(pr.stat("swim_pct") - sp0, 0.25))
			check("a life skill's perk is never bought (%s)" % pr.can_learn("sw_child"), not pr.learn("sw_child") and pr.can_learn("sw_child") == "Comes at Swimming 15")
			return TK.done(fails)
	step += 1
	return false
