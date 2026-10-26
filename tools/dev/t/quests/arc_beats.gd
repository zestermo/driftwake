extends SceneTree
## 1.23 island arcs, The Tyrant's Tax end to end: taken from the elder's telling, its collectors' squad turns up on the
## road and breaking it moves the arc on; the strongbox taken back brings the showdown; the villain's first meeting
## asks the nearest captain for a reply; his fall drops the arc's chest, raises the bounty and leaves the turn-in,
## and the elder's thanks close it with their reward.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var isl
var arc
var j
var dlg
var bounty0 := 0
var will0 := 0
var gold0 := 0
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
			isl = _island("tyrant")
			arc = isl.life.arc
			j = root.get_node("Journal")
			dlg = root.get_node("Dialogue")
			j.reset()
			dlg.dialogue_event.emit("arc:%s:take" % arc.key)
			until = TK.wait_secs(1.2)
		1:
			var sq = arc.get_node_or_null("S0")
			if sq == null or sq.alive_count() < 3:
				tries += 1
				if tries < 40:
					until = TK.wait_secs(0.5)
					return false
			check("taken from the elder: the arc is the crew's, on its first beat", j.step_of(arc.key) == 0)
			check("the collectors' squad is on the road (3 men)", sq != null and sq.alive_count() == 3)
			for g in sq.grunts:
				g.health.take_damage(1.0e6)
			until = TK.wait_secs(1.5)
		2:
			check("the collectors broken: on to the strongbox", j.step_of(arc.key) == 1)
			var it = arc.get_node_or_null("Item1")
			check("the strongbox waits at the camp's edge", it != null and it.visible)
			it.get_node("Take").interacted.emit(stage.player)
			until = TK.wait_secs(1.2)
		3:
			check("the strongbox taken back: the showdown", j.step_of(arc.key) == 2)
			tries = 0
			var v = arc.villain()
			stage.player.global_position = v.global_position + Vector3(0, 2.0, 20.0)
			stage.player.reset_physics_interpolation()
			bounty0 = int(stage.player.bounty)
			will0 = int(stage.player.progression.will_earned)
			until = TK.wait_secs(1.5)
		4:
			check("his first meeting: the nearest captain is asked for a reply", dlg.active)
			dlg.dialogue_event.emit("reply:%s:meet:2" % arc.key)
			until = TK.wait_secs(1.0)
		5:
			check("the reply is the crew's (cocky: fight now)", arc.flag("meet") and arc.picked("meet") == 2)
			if dlg.active:
				dlg._close()
			arc.villain().health.take_damage(1.0e6)
			until = TK.wait_secs(1.5)
		6:
			check("he falls: the arc's chest by the camp", arc.flag("fell") and arc.has_node("ArcChest"))
			check("the bounty rises for it (%d -> %d)" % [bounty0, int(stage.player.bounty)], int(stage.player.bounty) > bounty0)
			check("...and two Will points (%d -> %d)" % [will0, int(stage.player.progression.will_earned)], int(stage.player.progression.will_earned) == will0 + 2)
			check("the elder waits to hear it's over", j.at_turnin(arc.key))
			gold0 = stage.player.inventory_component.count("gold")
			dlg.dialogue_event.emit("arc:%s:pay" % arc.key)
			until = TK.wait_secs(1.0)
		7:
			check("the elder's thanks close it, with their reward", j.is_done(arc.key) and stage.player.inventory_component.count("gold") > gold0)
			return TK.done(fails)
	step += 1
	return false


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
