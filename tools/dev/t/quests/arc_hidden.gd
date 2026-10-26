extends SceneTree
## 1.23 island arcs' hidden finishes: The Tyrant's Tax won without killing his men ("Mercy") pays the hidden cache
## beside the arc's chest and his men surrender; a reply's wound ("wounded:K") is dealt to the villain once he's in
## the fight.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var isl
var arc
var j
var dlg
var men0 := 0
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
			j.take(arc.key)
			j.jump(arc.key, 0, 1)
			root.get_node("Dialogue").dialogue_event.emit("reply:%s:moment:2" % arc.key)
			until = TK.wait_ticks(4)
		1:
			j.jump(arc.key, 1, 2)
			until = TK.wait_secs(1.0)
		2:
			var v = arc.villain()
			if v == null and tries < 40:
				tries += 1
				until = TK.wait_secs(0.5)
				return false
			stage.player.global_position = v.global_position + Vector3(0, 2.0, 20.0)
			stage.player.reset_physics_interpolation()
			until = TK.wait_secs(1.5)
		3:
			if dlg.active:
				dlg.dialogue_event.emit("reply:%s:meet:2" % arc.key)
				dlg._close()
			var v = arc.villain()
			v.alert(0.0)
			men0 = arc.men().filter(func(g): return not g.is_dead()).size()
			until = TK.wait_secs(1.5)
		4:
			var v = arc.villain()
			var hp: float = v.health.current_health / v.health.max_health
			check("the quartermaster's tip: he starts the fight a quarter down (%.2f)" % hp, hp < 0.8 and hp > 0.7)
			v.health.take_damage(1.0e6)
			until = TK.wait_secs(1.5)
		5:
			check("his men all alive (%d) when he falls: the hidden finish" % men0, men0 > 0 and arc.flag("fell") and arc.flag("hidden"))
			check("...pays the hidden cache beside the arc's chest", arc.has_node("ArcChest") and arc.has_node("ArcCache"))
			until = TK.wait_ticks(4)
		6:
			check("...and his men surrender", arc.men().filter(func(g): return is_instance_valid(g) and not g.is_queued_for_deletion() and not g.is_dead()).is_empty())
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
