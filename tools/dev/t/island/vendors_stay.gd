extends SceneTree
## 1.30 (Zach: "the vendors should always be in their shop or at their stall"): on a generated village every trader
## and whoever works a market stall stays at their counter all day and night (one stay, the same spot at every hour),
## a trader without a shop of their own keeps a stall, no stall has two keepers, and the rest of the crowd still
## walks its day.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
const SEEDS := [9100, 9103]
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
	var keepers: Array = []
	var walkers := 0
	for i in life.placed:
		var f: Dictionary = life.folk[i]
		var trader := str(f["role"]).begins_with("vendor:")
		if trader or f["work"] == "stall":
			keepers.append(f)
		elif f["stays"].size() > 1:
			walkers += 1
	var still := true
	var at_counter := true
	for f in keepers:
		var p0: Vector2 = f["stays"][0]["at"]
		still = still and f["stays"].size() == 1 and f["walks"].size() == 1
		at_counter = at_counter and (str(f["work"]).begins_with("vshop_") or f["work"] == "stall")
		var v = life.people.filter(func(x): return x.npc_name == f["name"])[0]
		for h in range(0, 24, 3):
			still = still and (v.spot_at(float(h))[0] as Vector2).distance_to(p0) < 0.01
	var stalls: Array = life.spots.filter(func(s): return s["kind"] == "stall")
	var spots_kept := keepers.map(func(f): return f["stays"][0]["at"])
	var twice := spots_kept.any(func(a): return spots_kept.count(a) > 1)
	print("   seed %d: %d keepers (%s), %d stalls, %d walk their day" % [seed_, keepers.size(), keepers.map(func(f): return f["work"]), stalls.size(), walkers])
	check("[%d] every trader is at their shop or a stall" % seed_, at_counter and keepers.size() >= 2)
	check("[%d] ...and stays there at every hour" % seed_, still)
	check("[%d] no counter has two keepers" % seed_, not twice)
	check("[%d] the rest of the crowd still walks its day (%d)" % [seed_, walkers], walkers >= 6)
	isl.queue_free()
