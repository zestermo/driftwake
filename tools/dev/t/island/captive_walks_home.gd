extends SceneTree
## 1.26: a freed captive in a pirate-held village thanks you over their head, walks off from the post across the square
## towards the survivors' hamlet and goes, for good; one freed while nobody saw (the flag already set: a reload, a late
## joiner) is simply gone.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var isl
var h
var npc
var post := Vector3.ZERO
var step := 0
var until := 0
var fails := 0
var tries := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


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
			P.force = true
			isl = _island()
			P.force = false
			h = isl.get_node("Site_village/Village/Held")
			until = TK.wait_secs(1.0)
		1:
			if h.captives.size() < 2 and tries < 40:
				tries += 1
				until = TK.wait_secs(0.5)
				return false
			npc = h.captives[0]
			post = npc.global_position
			var hc = stage.player.get_node("HealthComponent")
			hc.max_health = 99999.0
			hc.current_health = 99999.0
			stage.player.global_position = post + Vector3(2.0, 1.0, 0.0)
			stage.player.reset_physics_interpolation()
			until = TK.wait_secs(0.5)
		2:
			h.decide("free", [0], 1)
			until = TK.wait_secs(0.5)
		3:
			check("freed: untied, thanking you over their head", npc.has_node("SpeechBubble") and not npc.get_node("Free").enabled)
			until = TK.wait_secs(3.0)
		4:
			var moved: float = npc.global_position.distance_to(post)
			check("...still there, walking off (%.1f m from the post)" % moved, not npc.away and npc.humanoid.visible and moved > 3.0)
			tries = 0
			until = TK.wait_secs(1.0)
		5:
			if not npc.away and tries < 60:
				tries += 1
				until = TK.wait_secs(1.0)
				return false
			var moved: float = npc.global_position.distance_to(post)
			check("...and gone once they're past the square (%.1f m off, after %d s)" % [moved, tries], npc.away and moved > 12.0)
			root.get_node("GameManager").world_flags[h.freed_flag(1)] = true
			until = TK.wait_secs(1.0)
		6:
			check("one freed unseen (a reload, a late joiner) is simply gone", h.captives[1].away and not h.captives[1].get_node("Free").enabled)
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
