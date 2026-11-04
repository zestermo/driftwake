extends SceneTree
## The skills menu draws every path of a tree in view, bought or not (1.30: one map, zoomed and panned): at katana
## mastery 3 the paths round the root are drawn, filled only where both its ends are yours (locked ones grey); buying the
## Keen Edge step fills its path.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gm
var sm
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func expected() -> int:
	var n := 0
	for k in SkillTrees.nodes_of("katana"):
		if SkillTrees.node_def(k)["kind"] != "version":
			n += SkillTrees.node_def(k)["links"].size()
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			pr = stage.player.progression
			pr.mastery_of("katana")["lv"] = 2
			pr.add_mastery("katana", pr.mastery_to_next(2))
			root.size = Vector2i(1920, 1080)
			root.get_node("Story").step = "done"
			gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			sm.set_tab("combat", "katana")
			until = TK.wait_ticks(4)
		1:
			check("the katana map's paths in view are drawn (%d of %d)" % [sm.links.size(), expected()], sm.links.size() > 10 and sm.links.size() <= expected() + 8)
			check("a path is filled exactly when both its ends are yours", sm.links.all(func(l): return l[2] == (pr.owns_node(l[1]) and pr.owns_node(l[0]))))
			check("paths to locked nodes are drawn (grey)", sm.links.any(func(l): return not l[2] and int(SkillTrees.node_def(l[1])["level"]) > pr.tree_level("katana")))
			check("Keen Edge's path starts grey", sm.links.any(func(l): return l[1] == "k_keen" and not l[2]))
			check("a step was bought", pr.buy("k_keen"))
			until = TK.wait_ticks(3)
		2:
			check("the bought step's path fills", sm.links.any(func(l): return l[1] == "k_keen" and l[2]))
			check("the rest stay drawn", sm.links.size() > 10)
			return TK.done(fails)
	step += 1
	return false
