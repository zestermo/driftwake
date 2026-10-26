extends SceneTree
## 1.23 island arcs' replies (Replies): a beat-2 moment's reply is the crew's and its outcome applies (the Tyrant's
## quartermaster told to run: two more men wait at the showdown), a price is offered only to a captain who can pay it,
## and the villain's meeting can end the arc another way (paying his tax: the gold goes, the arc is settled without a
## fight, and the island's traders charge more).
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var isl
var arc
var j
var dlg
var gold0 := 0
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
			isl = _island("tyrant")
			arc = isl.life.arc
			j = root.get_node("Journal")
			dlg = root.get_node("Dialogue")
			j.reset()
			j.take(arc.key)
			j.jump(arc.key, 0, 1)
			until = TK.wait_ticks(4)
		1:
			var inv = stage.player.inventory_component
			inv.remove_item(load("res://scripts/loot/item_db.gd").get_item("gold"), inv.count("gold"))
			var priced: Array = arc._replies(arc.T["moment"]).filter(func(r): return r.has("if"))
			check("a reply with a price isn't offered to a captain with no gold", not priced.is_empty() and not priced[0]["if"].call())
			inv.add_item(load("res://scripts/loot/item_db.gd").get_item("gold"), 200)
			check("...and is once they have it", priced[0]["if"].call())
			dlg.dialogue_event.emit("reply:%s:moment:0" % arc.key)
			until = TK.wait_secs(1.0)
		2:
			check("the moment's reply is the crew's (cocky: run and tell him)", arc.flag("moment") and arc.picked("moment") == 0)
			check("a moment's reply doesn't move the arc on by itself", j.step_of(arc.key) == 1)
			j.jump(arc.key, 1, 2)
			until = TK.wait_secs(1.5)
		3:
			var more = arc.get_node_or_null("More")
			check("its outcome: two more of his men wait at the showdown", more != null and more.specs.size() == 2)
			gold0 = stage.player.inventory_component.count("gold")
			dlg.dialogue_event.emit("reply:%s:meet:0" % arc.key)
			until = TK.wait_secs(1.0)
		4:
			var paid: int = gold0 - stage.player.inventory_component.count("gold")
			check("paying his tax takes the gold (%d)" % paid, paid == 150)
			check("...and settles the arc without a fight", arc.flag("settled") and j.is_done(arc.key) and not arc.flag("fell"))
			var marked: Array = j.perks.keys().filter(func(k): return str(k).begins_with("discount:") and float(j.perks[k]) < 0.0)
			check("...and the island's traders charge more (%s)" % [marked], not marked.is_empty())
			dlg.dialogue_event.emit("reply:%s:meet:1" % arc.key)
			until = TK.wait_secs(0.6)
		5:
			check("a meeting already answered can't be answered again", arc.picked("meet") == 0)
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
