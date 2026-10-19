extends SceneTree
## No two people on one island say the same line: a generated island of each theme built whole, every line its
## people can say gathered (barks, lines over their heads, their dialogue trees) and none said by two of them.
## Each named character has small talk of their own, each villager lines of their own, and the notice board
## posts the village's jobs, each turned in to whoever posted it.
const TK := preload("res://tools/dev/test_kit.gd")
const THEMES := ["jungle", "desert", "snow", "forest"]
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var fails := 0
var step := 0
var until := 0
var world
var isl


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
	if step >= THEMES.size():
		return TK.done(fails)
	_island(THEMES[step], step)
	step += 1
	until = TK.wait_ticks(2)
	return false


func _island(theme: String, k: int) -> void:
	var IT = load("res://scripts/island/themes/island_themes.gd")
	var t = IT.of(theme)
	var n: Dictionary = world.c.node(int(world.c.start_next[0])).duplicate(true)
	n["theme"] = theme
	n["seed"] = 9100 + k
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": "Old Grumble", "minis": [t.minis[0]], "roamer": t.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	isl = load("res://scripts/island/gen_island.gd").new()
	isl.name = "Isle_%s" % theme
	isl.position = Vector3(4000.0 * (k + 1), 0, 0)
	world.add_child(isl)
	isl.build(n)
	var dlg = root.get_node("Dialogue")
	var npcs: Array = isl.find_children("*", "NPC", true, false)
	var said := {}
	var dup: Array = []
	var quiet: Array = []
	for npc in npcs:
		var mine := {}
		for l in npc.barks:
			mine[str(l)] = true
		if npc.get("ambient") != null:
			for pool in npc.ambient.values():
				for l in pool:
					mine[str(l)] = true
		if npc.dialogue_id != "":
			for node in dlg._load(npc.dialogue_id)["nodes"].values():
				if str(node.get("speaker", "")) == "You":
					continue
				var text = node.get("text", "")
				for l in (text if text is Array else [text]):
					if not str(l).begins_with("("):
						mine[str(l)] = true
		if mine.is_empty():
			quiet.append(npc.npc_name)
		for l in mine.keys():
			if said.has(l) and said[l] != npc.npc_name:
				dup.append("%s / %s: %s" % [said[l], npc.npc_name, l])
			said[l] = npc.npc_name
	print("   %s (%s): %d people, %d lines" % [isl.island_name, theme, npcs.size(), said.size()])
	check("[%s] %d people, each with something to say (quiet: %s)" % [theme, npcs.size(), quiet], npcs.size() >= 15 and quiet.is_empty())
	check("[%s] no line said by two people (%s)" % [theme, dup.slice(0, 3)], dup.is_empty())
	var life = isl.life
	var named: Array = life.folk.filter(func(f): return f["named"])
	check("[%s] the named characters' small talk is their own (%s)" % [theme, named.map(func(f): return f["own"]["talk"].size())],
		named.all(func(f): return f["own"]["talk"].size() >= 2 and dlg._load(f["talk"])["nodes"].has("work")))
	var posters: Array = life.notices.map(func(q): return q["giver"])
	var board: Dictionary = dlg._load(isl.save_key("board"))["nodes"]
	var posted := true
	for q in life.notices:
		posted = posted and board.has("q_%s_notice" % q["id"]) and not str(q["notice"]).contains("{") and npcs.any(func(x): return x.npc_name == q["giver"])
	check("[%s] the board posts the village's jobs (%s), each by someone on the island" % [theme, life.notices.map(func(q): return q["title"])],
		life.notices.size() == 3 and posted)
	var reports := 0
	for npc in npcs:
		if npc.dialogue_id != "":
			for q in life.notices:
				if dlg._load(npc.dialogue_id)["nodes"].has("q_%s_pay" % q["id"]):
					reports += 1
					check("[%s] %s is reported to %s, who posted it" % [theme, q["title"], npc.npc_name], npc.npc_name == q["giver"])
	check("[%s] every notice is reported to one person (%s)" % [theme, posters], reports == life.notices.size())
	isl.queue_free()
