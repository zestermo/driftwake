extends SceneTree
## 1.25.5 pirate-held villages: a held island's village is the ruins layout with a pirate garrison instead of the bugs
## (riflemen up on roof decks over the ruins, ladders up), townsfolk tied to posts to free (each a lead against the
## arc's villain), and their captain, a captain-style AI with more health, out once a captain walks into the square;
## his fall frees the village (the garrison gone, a flag the host keeps).
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var isl
var v
var h
var leads0 := 0
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
			var P = load("res://scripts/island/pirate_held.gd")
			var n := 0
			for s in range(600):
				if P.roll_seed(s * 7919 + 3):
					n += 1
			check("about one island in six is held (%d of 600)" % n, n > 60 and n < 150)
			P.force = true
			isl = _island()
			P.force = false
			v = isl.get_node("Site_village/Village")
			h = v.get_node_or_null("Held")
			until = TK.wait_secs(1.0)
		1:
			var g = h.garrison
			if g.grunts.size() < g.specs.size() and tries < 40:
				tries += 1
				until = TK.wait_secs(0.5)
				return false
			check("held: the ruins layout with its garrison, no bugs", v.layout == "ruins" and h != null and isl.get_node("Site_village/Burrows").spots.is_empty())
			var decks: Array = isl.find_children("RoofDeck*", "", true, false)
			check("roof decks over the ruins (%d), a ladder up each" % decks.size(), decks.size() >= 2 and decks.all(func(d): return d.has_node("Ladder")))
			var up := 0
			for gr in g.grunts:
				var p: Vector3 = isl.to_local(gr.global_position)
				if p.y - isl.hv(Vector2(p.x, p.z)) > 2.4:
					up += 1
			check("riflemen up on the roofs (%d)" % up, up >= 2)
			check("townsfolk tied to posts (%d)" % h.captives.size(), h.captives.size() >= 2)
			var arc = isl.life.arc
			leads0 = arc.lead_sources() if arc else 0
			h.decide("free", [0], 1)
			until = TK.wait_secs(1.0)
		2:
			check("a captive freed: untied, a lead", h.is_freed(0) and not h.captives[0].get_node("Free").enabled and (isl.life.arc == null or isl.life.arc.lead_sources() == leads0 + 1))
			var c: Vector2 = h.plan["c"]
			stage.player.global_position = isl.to_global(Vector3(c.x, isl.hv(c) + 1.0, c.y + 12.0))
			stage.player.reset_physics_interpolation()
			tries = 0
			until = TK.wait_secs(1.5)
		3:
			var cap = h.get_node_or_null("HeldCaptain")
			if cap == null and tries < 20:
				tries += 1
				until = TK.wait_secs(0.5)
				return false
			check("their captain comes out: a captain-style AI, tougher than a rival (hp x%.1f)" % (cap.hp_k if cap else 0.0), cap != null and cap.is_ai and cap.hp_k > 2.0)
			cap.health_component.take_damage(1.0e7)
			until = TK.wait_secs(1.5)
		4:
			check("his fall frees the village: the flag, the garrison gone", h.captain_down() and h.garrison.alive_count() == 0)
			return TK.done(fails)
	step += 1
	return false


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
	gi.name = "HeldIsle"
	gi.position = Vector3(5000.0, 0, 0)
	world.add_child(gi)
	gi.build(n)
	return gi
