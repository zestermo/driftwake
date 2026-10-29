extends SceneTree
## 1.25.5 the island loop: side work is a lead against the arc's villain. The weak spot heard, the island's quests done
## and its miniboss down each give one (intel, a lieutenant gone, a wound, an ally, in that order); at the showdown he's
## down a man, starts wounded and an ally from the village stands by; the elder's "now" opens the showdown any time and
## the turn-in pays four quests' XP.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var isl
var arc
var j
var dlg
var men_full := 0
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
			check("no leads yet: the elder says so", arc.leads().is_empty() and arc.lead_summary().begins_with("You've nothing"))
			check("the arc pays four quests' XP", float(arc.def["reward"].get("xp", 1.0)) == 4.0)
			check("a named villager tells the villain's weak spot", arc._gossip.has("gossip"))
			dlg.dialogue_event.emit("arc:%s:gossip:Someone" % arc.key)
			until = TK.wait_secs(1.2)
		1:
			check("the weak spot heard is a lead (intel first)", arc.leads() == ["intel"])
			var qs: Array = arc.life.given + arc.life.notices
			for q in qs.slice(0, 2):
				j.take(q["id"])
				var n: int = (q["steps"] as Array).size()
				if n > 1:
					j.jump(q["id"], 0, n - 1)
				j.turn_in(q["id"], Vector3.ZERO)
			until = TK.wait_secs(1.2)
		2:
			check("two quests done: two more leads (a lieutenant, a wound)", arc.leads() == ["intel", "lieutenant", "wound"])
			var m: String = arc._minis()[0]
			var b = arc._mini_body(m)
			b.health.take_damage(1.0e7)
			until = TK.wait_secs(1.5)
		3:
			check("the miniboss down: an ally (%s)" % str(arc.leads()), arc.leads() == ["intel", "lieutenant", "wound", "ally"])
			check("the elder tells of them", arc.lead_summary().begins_with("4 leads"))
			j.take(arc.key)
			dlg.dialogue_event.emit("arc:%s:now" % arc.key)
			until = TK.wait_ticks(4)
		4:
			check("the elder's 'now' opens the showdown at once", j.step_of(arc.key) == arc.showdown())
			until = TK.wait_secs(1.0)
		5:
			var v = arc.villain()
			if (v == null or arc._villain_camp().grunts.size() < arc._villain_camp().specs.size()) and tries < 40:
				tries += 1
				until = TK.wait_secs(0.5)
				return false
			stage.player.global_position = v.global_position + Vector3(0, 2.0, 20.0)
			stage.player.reset_physics_interpolation()
			men_full = arc._villain_camp().specs.size() - 1
			until = TK.wait_secs(1.5)
		6:
			if dlg.active:
				dlg.dialogue_event.emit("reply:%s:meet:2" % arc.key)
				dlg._close()
			arc.villain().alert(0.0)
			until = TK.wait_secs(1.5)
		7:
			var v = arc.villain()
			var hp: float = v.health.current_health / v.health.max_health
			var men: int = arc.men().filter(func(g): return is_instance_valid(g) and not g.is_queued_for_deletion() and not g.is_dead()).size()
			check("a lieutenant gone: %d of %d men at the showdown" % [men, men_full], men == men_full - 1)
			check("the wound: he starts the fight a tenth down (%.2f)" % hp, hp <= 0.91 and hp > 0.8)
			check("an ally from the village stands by", arc.has_node("Ally0") and arc.allies.size() == 1)
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
