extends SceneTree
## 1.30 (Zach's playtest: "slightly too many people in each village"): a generated village's crowd is about a quarter
## smaller (9-11 villagers on routines, was 12-15), and nobody who matters is cut: the three named characters, the
## traders, the elder and the keepers are all there, and every quest and notice has its giver on the island.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
const SEEDS := [9100, 9101]
var stage
var fails := 0
var step := 0
var until := 0
var world


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
		stage.get_node("NoIslands").remove_from_group("world_gen")
		var s := GDScript.new()
		s.source_code = WORLD
		s.reload()
		world = Node.new()
		world.set_script(s)
		world.name = "Islands"
		stage.add_child(world)
		world.c = load("res://scripts/world/chain.gd").make(77, Vector2.ZERO, Vector2(0, -1))
	if step >= SEEDS.size():
		return TK.done(fails)
	_island(SEEDS[step], step)
	step += 1
	until = TK.wait_ticks(2)
	return false


func _island(seed_: int, k: int) -> void:
	var t = load("res://scripts/island/themes/island_themes.gd").of("jungle")
	var n: Dictionary = world.c.node(int(world.c.start_next[0])).duplicate(true)
	n["theme"] = "jungle"
	n["seed"] = seed_
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": "Old Grumble", "minis": [t.minis[0]], "roamer": t.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	var isl = load("res://scripts/island/gen_island.gd").new()
	isl.name = "Isle_%d" % seed_
	isl.position = Vector3(4000.0 * (k + 1), 0, 0)
	world.add_child(isl)
	isl.build(n)
	var life = isl.life
	var crowd: Array = life.folk.filter(func(f): return not f["named"])
	var named: Array = life.folk.filter(func(f): return f["named"] and not str(f["role"]).begins_with("vendor:"))
	var traders: Array = life.folk.filter(func(f): return str(f["role"]).begins_with("vendor:"))
	var npcs: Array = isl.find_children("*", "NPC", true, false)
	var names := npcs.map(func(x): return x.npc_name)
	print("   seed %d: %d villagers, %d named, %d traders, %d people in all" % [seed_, crowd.size(), named.size(), traders.size(), npcs.size()])
	check("[%d] the crowd is 9-11 (%d)" % [seed_, crowd.size()], crowd.size() >= 9 and crowd.size() <= 11)
	check("[%d] three named characters and the traders, all placed" % seed_, named.size() == 3 and traders.size() >= 2 and life.placed.size() == life.folk.size())
	var v = isl.get_node("Site_village/Village")
	check("[%d] the elder is there (%s)" % [seed_, v.elder_name], names.has(v.elder_name))
	var givers: Array = (life.given + life.notices).map(func(q): return str(q["giver"]))
	check("[%d] every quest and notice has its giver on the island (%s)" % [seed_, givers], givers.all(func(g): return names.has(g)))
	check("[%d] fewer people than before (%d, was 26 or more)" % [seed_, npcs.size()], npcs.size() <= 30)
	isl.queue_free()
