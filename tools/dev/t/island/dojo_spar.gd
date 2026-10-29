extends SceneTree
## 1.26: a chain village's dojo spars for real. Asked in the keeper's talk, the master steps out into the street when the
## talk ends (the keeper's body hidden meanwhile), drills there, asks when you walk up, bows, counts in and fights (an
## ArenaBout "dojo:<village>"). The first win is the lesson (two quests' XP, once per captain); a rematch is practice
## (no XP); after each bout the master goes back to the counter.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var isl
var v
var me
var bout
var before := []
var round := 0
var step := 0
var until := 0
var fails := 0


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
			var U = load("res://scripts/island/unique_places.gd")
			U.force = "dojo"
			load("res://scripts/island/village_layouts.gd").force = "town"
			isl = _island()
			U.force = ""
			load("res://scripts/island/village_layouts.gd").force = ""
			v = isl.get_node("Site_village/Village")
			me = stage.player
			var hc = me.get_node("HealthComponent")
			hc.max_health = 99999.0
			hc.current_health = 99999.0
			until = TK.wait_secs(1.0)
		1:
			check("the village's place is the dojo, its master inside", v.unique == "dojo" and v.keeper_npc != null and v.keeper_npc.interactable.enabled)
			me.global_position = v.dojo_spot() + Vector3(8, 0.5, 0)
			me.reset_physics_interpolation()
			var said: String = load("res://scripts/island/unique_places.gd").act(isl, "dojo", "spar", me)
			check("asked to spar: no fee, the master will step out (%s)" % said, v.spar_asked)
			before = [me.progression.level, me.progression.xp]
			root.get_node("Dialogue").dialogue_ended.emit(isl.save_key("unique"))
			until = TK.wait_secs(0.5)
		2:
			var bouts := get_nodes_in_group("arena_bouts")
			bout = bouts[0] if not bouts.is_empty() else null
			check("the talk over: the master is out on the ground", bout != null and is_instance_valid(bout.rival))
			if bout == null:
				return TK.done(fails + 1)
			var spot: Vector3 = v.dojo_spot()
			var door: Vector2 = v.buildings.filter(func(b): return b["kind"] == "unique")[0]["door"]
			var door_w: Vector3 = isl.to_global(Vector3(door.x, isl.hv(door), door.y))
			print("   spot %s, door %s, rival %s" % [spot, door_w, bout.rival.global_position])
			check("...outside the dojo's door (%.1f m)" % Vector2(spot.x - door_w.x, spot.z - door_w.z).length(), Vector2(spot.x - door_w.x, spot.z - door_w.z).length() < 12.0)
			check("...as its keeper (%s)" % bout.who, bout.who == str(v.keeper_npc.npc_name))
			check("...the keeper's body hidden while they're out", not v.keeper_npc.humanoid.visible and not v.keeper_npc.interactable.enabled)
			check("...waiting, not fighting (%s)" % bout.phase, bout.phase == "wait")
			me.global_position = bout.rival.global_position + Vector3(0, 0, 2.0)
			me.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		3:
			var dlg = root.get_node("Dialogue")
			check("walk up: the master asks if you're ready", dlg.active and dlg._id == "spar")
			dlg.dialogue_event.emit("spar:go")
			dlg._close()
			until = TK.wait_secs(5.5)
		4:
			check("after the bow and the count: the fight (%s)" % bout.phase, bout.phase == "fight" and bout.rival.get_node("Brain").order == "fight")
			bout.rival.health_component.current_health = 1.0
			until = TK.wait_secs(0.5)
		5:
			var now := [me.progression.level, me.progression.xp]
			if round == 0:
				check("first win: the lesson's XP (%s -> %s)" % [before, now], now != before)
				check("...remembered for this captain", root.get_node("GameManager").opened.has(isl.save_key("unique_spar")))
			else:
				check("a rematch won: practice, no XP (%s -> %s)" % [before, now], now == before)
			until = TK.wait_secs(3.5)
		6:
			check("after the bout the master's back at the counter", v.keeper_npc.humanoid.visible and v.keeper_npc.interactable.enabled and get_nodes_in_group("arena_bouts").is_empty())
			if round == 0:
				round = 1
				load("res://scripts/island/unique_places.gd").act(isl, "dojo", "spar", me)
				before = [me.progression.level, me.progression.xp]
				root.get_node("Dialogue").dialogue_ended.emit(isl.save_key("unique"))
				me.global_position = v.dojo_spot() + Vector3(8, 0.5, 0)
				me.reset_physics_interpolation()
				step = 2
				until = TK.wait_secs(0.5)
				return false
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
	gi.name = "DojoIsle"
	gi.position = Vector3(5000.0, 0, 0)
	world.add_child(gi)
	gi.build(n)
	return gi
