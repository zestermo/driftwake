extends SceneTree
## 1.23 island arcs: every template, made on one jungle island (an outpost added so Iron Boot and the Rebellion can
## stand), has its text filled, its contacts and spots on the island, and plays through: each beat-2 step done the way
## a captain would (squads broken, things taken, moments answered, witnesses heard, places reached, lanterns lit, the
## castaway brought home), the showdown's villain turns up and falls, the arc's chest drops and the elder waits.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
const LIST := ["tyrant", "beast", "iron_boot", "heirloom", "festival", "rebellion", "noble", "well", "champion", "treasure"]
var stage
var world
var isl
var arc
var j
var dlg
var A
var ti := -1
var phase := "next"
var tries := 0
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
	if step == 0:
		A = load("res://scripts/island/island_arcs.gd")
		isl = _island()
		j = root.get_node("Journal")
		dlg = root.get_node("Dialogue")
		var MO = load("res://scripts/island/marine_outpost.gd")
		if isl.get_node_or_null("MarineOutpost") == null:
			var v = isl.get_node("Site_village/Village")
			var rng := RandomNumberGenerator.new()
			var o = MO.make(isl, v.plaza["c"], 60.0, "t_outpost", 1, 5, rng)
			var c: Vector2 = v.plaza["c"] + Vector2(30, 0)
			o.position = Vector3(c.x, isl.hv(c), c.y)
		step = 1
		until = TK.wait_ticks(2)
		return false
	match phase:
		"next":
			ti += 1
			if ti >= LIST.size():
				return TK.done(fails)
			_make(LIST[ti])
			phase = "beat"
			until = TK.wait_secs(0.6)
		"beat":
			_beat()
	return false


func _make(id: String) -> void:
	if isl.life.arc:
		isl.life.arc.free()
	A.force = id
	arc = A.make(isl.life, isl.get_node("Site_village/Village"))
	A.force = ""
	isl.life.arc = arc
	j.reset()
	var T: Dictionary = arc.T
	var said: Array = [T["title"], arc.villain_name] + arc.rumours() + arc.fill_all(T["elder"]) + arc.fill_all(T["remind"]) + [arc.fill(T["poster"])]
	said += arc.fill_all(T["thanks"]) + arc.fill_all(T["settled"]) + [arc.fill(T["hidden"]["said"])] + arc.fill_all(T.get("tells", []))
	for m in ["meet", "moment"]:
		if T.has(m):
			said += arc.fill_all(T[m]["lines"])
			for r in arc._replies(T[m]):
				said += [r["text"], r["answer"]]
	for s in j.def(arc.key)["steps"]:
		said += [s["goal"]] + ([s["said"]] if s.has("said") else [])
	var bad: Array = said.filter(func(l): return str(l).contains("{") or str(l) == "")
	check("[%s] every line filled (%s)" % [id, bad], bad.is_empty())
	var beats: int = (T["steps"] as Array).size()
	check("[%s] 1-3 beat-2 steps, a moment%s" % [id, " and a meeting" if T.has("meet") else ""], beats >= 1 and beats <= 3 and T.has("moment"))
	var spots_ok := true
	for s in T["steps"]:
		for a in (s["at"] if s.get("at") is Array else [s.get("at", arc.place)]):
			spots_ok = spots_ok and arc.spots.has(a)
	check("[%s] its places are on the island, its %d contacts too" % [id, arc.contacts.size()], spots_ok and arc.spots.has(arc.place)
		and arc.contacts.all(func(c): return c.is_inside_tree() and c.global_position.is_finite()))
	j.take(arc.key)
	tries = 0


## Do whatever the current step needs, then on to the showdown and the fall.
func _beat() -> void:
	var st: int = j.step_of(arc.key)
	var n: int = arc.showdown()
	var id: String = LIST[ti]
	tries += 1
	if tries > 120:
		check("[%s] stuck on step %d (%s)" % [id, st, j.goal(arc.key)], false)
		phase = "next"
		return
	until = TK.wait_secs(0.5)
	if st < n:
		var s: Dictionary = arc.T["steps"][st]
		match str(s["do"]):
			"squad", "wave":
				var tag := ("S%d" if s["do"] == "squad" else "W%d") % st
				if s["do"] == "wave":
					arc.set_flag("w%d" % st)
				var sq = arc.get_node_or_null(tag)
				if sq:
					for g in (sq.grunts if s["do"] == "squad" else sq.spots.map(func(x): return x["bug"])):
						if g != null and is_instance_valid(g) and not g.is_dead():
							g.health.take_damage(1.0e6)
			"pickup":
				var it = arc.get_node_or_null("Item%d" % st)
				if it:
					it.get_node("Take").interacted.emit(stage.player)
			"pieces":
				for k in range((s["at"] as Array).size()):
					var it = arc.get_node_or_null("Piece%d" % k)
					if it and it.visible:
						it.get_node("Take").interacted.emit(stage.player)
			"talk":
				if not arc.flag("moment"):
					var m: Dictionary = arc.T["moment"]
					var pick := 0
					for i in range(m["replies"].size()):
						if (m["replies"][i]["out"] as Array).has("step"):
							pick = i
					dlg.dialogue_event.emit("reply:%s:moment:%d" % [arc.key, pick])
			"talks":
				for i in s["contacts"]:
					dlg.dialogue_event.emit("arc:%s:told:%d" % [arc.key, i])
			"reach":
				stage.player.global_position = arc.to_global(arc._at(str(s["at"]))) + Vector3.UP * 1.5
				stage.player.reset_physics_interpolation()
			"light":
				for k in range(int(s["n"])):
					root.get_node("Net").arc_ask(root.get_node("Net").key_of(arc), "light", [k])
			"escort":
				arc.contacts[int(s["contact"])].position = arc._v3(arc.spots["village"])
		return
	if st == n:
		var v = arc.villain()
		if v == null or not v.is_inside_tree():
			return
		if not arc.flag("fell"):
			v.health.take_damage(1.0e6)
			return
	check("[%s] the villain (%s) falls: the chest, and the elder waits" % [id, arc.villain_name], arc.flag("fell") and arc.has_node("ArcChest") and j.at_turnin(arc.key))
	for k in GameManager_flags().keys():
		if str(k).begins_with(arc.key):
			GameManager_flags().erase(k)
	phase = "next"


func GameManager_flags() -> Dictionary:
	return root.get_node("GameManager").world_flags


func _island():
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
	return gi
