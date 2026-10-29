extends SceneTree
## 1.25.5 fewer bug burrows: the lair site is the burrows on about one island in five, a smugglers' hideout or an
## Admiralty picket otherwise (rolled from the island's seed, the same every time). A built island's hideout and picket:
## four men and a named leader on the hoard, posted on the board as a notice to drive them out, done once they're down.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var IC
var isl
var kinds := ["hideout", "picket"]
var step := 0
var until := 0
var fails := 0
var tries := 0


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
			IC = load("res://scripts/island/island_content.gd")
			var n := {}
			for s in range(400):
				var k: String = IC.lair_roll(s * 7919 + 13)
				n[k] = int(n.get(k, 0)) + 1
			print("   lair kinds over 400 seeds: %s" % [n])
			check("the burrows are rare (%d of 400)" % int(n.get("burrows", 0)), int(n.get("burrows", 0)) > 40 and int(n.get("burrows", 0)) < 120)
			check("hideouts and pickets make up the rest", int(n.get("hideout", 0)) > 140 and int(n.get("picket", 0)) > 80)
			check("the same seed, the same kind", IC.lair_roll(4242) == IC.lair_roll(4242))
			_world()
		1:
			IC.force_lair = kinds[0]
			isl = _island(kinds[0])
			IC.force_lair = ""
			until = TK.wait_secs(1.0)
		2:
			var held = isl.get_node_or_null("Site_lair/Hideout")
			if (held == null or held.grunts.size() < held.specs.size()) and tries < 40:
				tries += 1
				until = TK.wait_secs(0.5)
				return false
			var lead: Array = held.specs.filter(func(s): return s.get("captain", false))
			check("%s: no burrows, four men and a leader (%s)" % [kinds[0], lead[0]["title"] if not lead.is_empty() else "none"],
				not isl.has_node("Site_lair/Burrows") and held.specs.size() == 5 and lead.size() == 1)
			check("%s: on the hoard" % kinds[0], isl.find_children("*", "LootBag", true, false).any(func(b): return b.save_id == isl.save_key("lair_hoard")))
			var notice: Dictionary = {}
			for q in isl.life.notices:
				if str(q["kind"]) == kinds[0]:
					notice = q
			check("%s: a notice on the board (%s)" % [kinds[0], notice.get("title", "none")], not notice.is_empty() and str(notice.get("notice", "")) != "")
			check("%s: not done while they stand" % kinds[0], not notice["clear"].call())
			for g in held.grunts:
				g.health.take_damage(1.0e7)
			until = TK.wait_secs(1.5)
		3:
			var notice: Dictionary = isl.life.notices.filter(func(q): return str(q["kind"]) == kinds[0])[0]
			check("%s: done once they're down" % kinds[0], notice["clear"].call())
			isl.queue_free()
			kinds.pop_front()
			tries = 0
			if not kinds.is_empty():
				step = 1
				until = TK.wait_ticks(2)
				return false
			return TK.done(fails)
	step += 1
	return false


func _world() -> void:
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


func _island(nm: String):
	var n: Dictionary = world.c.node(int(world.c.start_next[0])).duplicate(true)
	n["theme"] = "jungle"
	n["seed"] = 9300
	var t = load("res://scripts/island/themes/island_themes.gd").of("jungle")
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": "Old Grumble", "minis": [t.minis[0]], "roamer": t.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	var gi = load("res://scripts/island/gen_island.gd").new()
	gi.name = "Isle_" + nm
	gi.position = Vector3(5000.0, 0, 0)
	world.add_child(gi)
	gi.build(n)
	return gi
