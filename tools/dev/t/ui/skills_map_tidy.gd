extends SceneTree
## (1.30.1) Every tree's map is tidy at zoom 1: no node or its name overlaps another's, no link from a node to its map
## parent crosses another such link or runs through a third node, and the root sits in the middle with every node
## further out than its parent.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _parent(ST, n: Dictionary) -> String:
	for key in ["links", "needs_all", "needs"]:
		if not (n.get(key, []) as Array).is_empty():
			return str(n[key][0])
	return str(ST.tree_def(str(n["tree"]))["root"])


## A node and its name as the map draws them at zoom 1 (its level under the name: the tallest it gets).
func _box(STD, font: Font, id: String, n: Dictionary) -> Rect2:
	var p: Vector2 = n["pos"]
	var r: Rect2 = STD.node_rect(id, p, 1.0)
	var nm := str(n["name"]) + (" 0/5" if str(n["kind"]) == "step" else "")
	var tw := minf(font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 120.0)
	return r.merge(Rect2(p.x - tw * 0.5, r.end.y + 2.0, tw, 18.0))


func _cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var o := func(p: Vector2, q: Vector2, r: Vector2) -> float: return (q - p).cross(r - p)
	return o.call(a, b, c) * o.call(a, b, d) < 0.0 and o.call(c, d, a) * o.call(c, d, b) < 0.0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var ST = load("res://scripts/progression/skill_trees.gd")
	var STD = load("res://scripts/ui/skill_tree_draw.gd")
	var font: Font = load("res://assets/fonts/Silkscreen-Regular.woff2")
	var trees := 0
	var far := 0.0
	var bad := {"overlap": [], "cross": [], "through": [], "outward": []}
	for t in ST.HEADERS.keys():
		# (the Captain's page isn't a map)
		if not ST.converted(t) or t == "captain":
			continue
		trees += 1
		var ids: Array = ST.nodes_of(t).filter(func(k): return ST.node_def(k)["kind"] != "version")
		var root := str(ST.tree_def(t)["root"])
		var reach := 0.0
		for id in ids:
			reach = maxf(reach, (ST.node_def(id)["pos"] as Vector2).length())
		var boxes := {}
		for id in ids:
			boxes[id] = _box(STD, font, id, ST.node_def(id))
		var overlaps: Array = []
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				if (boxes[ids[i]] as Rect2).grow(-1.0).intersects((boxes[ids[j]] as Rect2).grow(-1.0)):
					overlaps.append("%s/%s" % [ids[i], ids[j]])
		var edges: Array = []
		var outward := true
		for id in ids:
			if id == root:
				continue
			var par := _parent(ST, ST.node_def(id))
			var a: Vector2 = ST.node_def(par)["pos"]
			var b: Vector2 = ST.node_def(id)["pos"]
			edges.append([par, id, a, b])
			outward = outward and b.length() > a.length() + 1.0
		var crossings: Array = []
		for i in edges.size():
			for j in range(i + 1, edges.size()):
				if _cross(edges[i][2], edges[i][3], edges[j][2], edges[j][3]):
					crossings.append("%s-%s x %s-%s" % [edges[i][0], edges[i][1], edges[j][0], edges[j][1]])
		var through: Array = []
		for e in edges:
			for id in ids:
				if id == e[0] or id == e[1]:
					continue
				var r: Rect2 = STD.node_rect(id, ST.node_def(id)["pos"], 1.0)
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(r.get_center(), e[2], e[3])
				if r.grow(-1.0).has_point(q):
					through.append("%s-%s over %s" % [e[0], e[1], id])
		print("%s: %d nodes, %d px out; overlaps %s; crossings %s; through %s" % [t, ids.size(), int(reach),
			", ".join(overlaps.slice(0, 3)), ", ".join(crossings.slice(0, 3)), ", ".join(through.slice(0, 3))])
		if not overlaps.is_empty():
			bad["overlap"].append(t)
		if not crossings.is_empty():
			bad["cross"].append(t)
		if not through.is_empty():
			bad["through"].append(t)
		if (ST.node_def(root)["pos"] as Vector2) != Vector2.ZERO or not outward:
			bad["outward"].append(t)
		far = maxf(far, reach)
	check("no node or name overlaps another (%s)" % ", ".join(bad["overlap"]), bad["overlap"].is_empty())
	check("no two links cross (%s)" % ", ".join(bad["cross"]), bad["cross"].is_empty())
	check("no link runs through a node (%s)" % ", ".join(bad["through"]), bad["through"].is_empty())
	check("the root in the middle, each node further out than its parent (%s)" % ", ".join(bad["outward"]), bad["outward"].is_empty())
	check("no tree reaches past 960 px from its root (%d)" % int(far), far <= 960.0)
	check("every converted tree checked (%d)" % trees, trees >= 10)
	return TK.done(fails)
