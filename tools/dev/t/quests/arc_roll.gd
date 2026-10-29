extends SceneTree
## 1.23 island arcs: an island's template fits what it has (an outpost or a cave when it needs one, none without a
## village), the same facts roll the same template, and neighbouring islands of a chain roll different ones. Then a
## jungle island built from the chain: its arc is made, its quest has the template's beats plus the showdown and the
## turn-in with every token filled, the elder and the board offer it, and the folk tell of it.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var isl
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			_rolls()
			isl = _island("")
			until = TK.wait_ticks(2)
		1:
			_built()
			return TK.done(fails)
	step += 1
	return false


func _rolls() -> void:
	var A = load("res://scripts/island/island_arcs.gd")
	var ok_fit := true
	var same := true
	var none_ok := true
	var differ := 0
	var seen := {}
	for chain in [11, 4242, 90001]:
		var prev := ""
		for id in range(1, 13):
			for outpost in [false, true]:
				for cave in [false, true]:
					var f := {"id": id, "theme": "jungle", "outpost": outpost, "cave": cave, "burrows": cave, "village": true, "chain": chain}
					var t: String = A.pick(f)
					same = same and t == A.pick(f.duplicate())
					ok_fit = ok_fit and t != "" and A.fits(f, t)
					seen[t] = true
					var nf := f.duplicate()
					nf["village"] = false
					none_ok = none_ok and A.pick(nf) == ""
			var t2: String = A.pick({"id": id, "theme": "jungle", "outpost": true, "cave": true, "burrows": true, "village": true, "chain": chain})
			if prev != "" and t2 != prev:
				differ += 1
			prev = t2
	check("every roll fits its island's facts", ok_fit)
	check("the same facts roll the same template", same)
	check("no village: no arc", none_ok)
	var fog := true
	for id in range(1, 13):
		var f := {"id": id, "theme": "fog", "outpost": id % 2 == 0, "cave": true, "burrows": false, "village": true, "chain": 11}
		fog = fog and A.pick(f) == "festival"
		var nf := f.duplicate()
		nf["theme"] = "jungle"
		fog = fog and A.pick(nf) != "festival"
	seen["festival"] = fog
	check("the fog isle rolls the Cursed Festival, and only the fog isle", fog)
	check("neighbouring islands mostly roll different templates (%d of 33)" % differ, differ >= 22)
	check("every template turns up (%s)" % [seen.keys()], seen.size() == A.TEMPLATES.size())


func _island(force: String):
	var A = load("res://scripts/island/island_arcs.gd")
	A.force = force
	var stub: Node = stage.get_node("NoIslands")
	stub.remove_from_group("world_gen")
	var s := GDScript.new()
	s.source_code = WORLD
	s.reload()
	world = Node.new()
	world.set_script(s)
	world.name = "Islands"
	stage.add_child(world)
	world.c = load("res://scripts/world/chain.gd").make(77, Vector2.ZERO, Vector2(0, -1))
	var n: Dictionary = world.c.node(int(world.c.start_next[0])).duplicate(true)
	n["theme"] = "jungle"
	n["seed"] = 9300
	var t = load("res://scripts/island/themes/island_themes.gd").of("jungle")
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": "Old Grumble", "minis": [t.minis[0]], "roamer": t.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	var gi = load("res://scripts/island/gen_island.gd").new()
	gi.name = "ArcIsle"
	gi.position = Vector3(5000.0, 0, 0)
	world.add_child(gi)
	gi.build(n)
	A.force = ""
	return gi


func _built() -> void:
	var A = load("res://scripts/island/island_arcs.gd")
	var arc = isl.life.arc
	check("the island has its arc", arc != null)
	if arc == null:
		return
	var f: Dictionary = A.facts(isl, isl.get_node_or_null("MarineOutpost") != null)
	check("its template (%s) fits the island" % arc.arc, A.fits(f, arc.arc))
	var j = root.get_node("Journal")
	var q: Dictionary = j.def(arc.key)
	var beats: int = (A.TEMPLATES[arc.arc]["steps"] as Array).size()
	check("its quest: %d-3 beat-2 steps, then the showdown and the turn-in (%s)" % [beats, q.get("steps", []).map(func(s): return s["goal"])],
		beats >= 2 and beats <= 3 and q["steps"].size() == beats + 2 and q["steps"][beats]["do"] == "villain" and q["steps"][beats + 1]["do"] == "turnin")
	var said: Array = [q["title"]]
	for s in q["steps"]:
		said.append_array([s["goal"], s.get("said", "")])
	said.append_array(arc.rumours())
	check("no token left unfilled in its quest or its rumours", not said.any(func(l): return str(l).contains("{")))
	var dlg = root.get_node("Dialogue")
	var v = isl.get_node("Site_village/Village")
	var elder: Dictionary = dlg._load(v._key("elder"))["nodes"]
	var board: Dictionary = dlg._load(v._key("board"))["nodes"]
	check("the elder tells of it and the board has its poster", elder.has("arc_tell") and elder.has("arc_pay") and board.has("arc_poster"))
	var told := false
	for fo in isl.life.folk:
		for l in fo.get("own", {}).get("heard", []) + fo.get("own", {}).get("day", []):
			told = told or arc.rumours().has(l)
	check("the folk tell of it", told)
	check("the elder shows '!' for it until it's taken", j.marker_for(v.elder_name) == "!")
