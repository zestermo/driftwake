extends SceneTree
## A node is bought only once its parent on the map is yours (1.30: the playtest bought a node past one). Every tree is
## one connected map: each node is reached from the root through its links. Katana: Phantom Step waits for Iai
## Counter, Iai Counter for Cut the Shot; a bridge waits for one of its two sides.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var STS
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func to_level(tree: String, lv: int) -> void:
	while pr.mastery_level(tree) < lv:
		var m: Dictionary = pr.mastery_of(tree)
		pr.add_mastery(tree, pr.mastery_to_next(int(m["lv"]), tree) - int(m["xp"]))


## The nodes of `tree` no path of links from its root reaches.
func unreached(tree: String) -> Array:
	var kids := {}
	for k in STS.nodes_of(tree):
		var n: Dictionary = STS.node_def(k)
		for l in n.get("needs_all", n.get("needs", n["links"])):
			if not kids.has(l):
				kids[l] = []
			kids[l].append(k)
		if n.has("parent"):
			if not kids.has(n["parent"]):
				kids[n["parent"]] = []
			kids[n["parent"]].append(k)
	var seen := {STS.tree_def(tree)["root"]: true}
	var todo: Array = [STS.tree_def(tree)["root"]]
	while not todo.is_empty():
		for c in kids.get(todo.pop_back(), []):
			if not seen.has(c):
				seen[c] = true
				todo.append(c)
	return STS.nodes_of(tree).filter(func(k): return not seen.has(k))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			STS = load("res://scripts/progression/skill_trees.gd")
			var loose: Array = []
			for t in STS.HEADERS.keys():
				if t != "captain":
					loose += unreached(t)
			check("every tree is one map from its root (%s)" % str(loose.slice(0, 6)), loose.is_empty())
			to_level("katana", 16)
			pr.gift("katana", 40)
			check("Phantom Step needs Iai Counter first (%s)" % pr.buy_why("k_phantom"), pr.buy_why("k_phantom") == "Needs Iai Counter first" and not pr.buy("k_phantom"))
			check("...Iai Counter needs Cut the Shot (%s)" % pr.buy_why("k_counter"), not pr.buy("k_counter"))
			check("...bought in order: Cut the Shot, Iai Counter, Phantom Step", pr.buy("k_deflect") and pr.buy("k_counter") and pr.buy("k_phantom"))
			var bridge: String = STS.nodes_of("katana").filter(func(k): return STS.node_def(k).get("bridge", false))[0]
			var sides: Array = STS.node_def(bridge)["needs"]
			check("a bridge needs one of its sides (%s: %s)" % [bridge, pr.buy_why(bridge)], pr.parent_why(bridge) == "" if sides.any(func(k): return pr.owns(k)) else pr.parent_why(bridge) != "")
			check("a step on a node you don't own waits (Steel Nerves on Cut the Shot is open now)", pr.parent_why("k_nerves") == "" and pr.parent_why("k_weight") == "")
			check("...Deep Draw waits for the Iai upgrade (%s)" % pr.buy_why("k_deep"), pr.parent_why("k_deep") != "")
			return TK.done(fails)
	step += 1
	return false
