extends SceneTree
## 1.26: a pirate-held village's roof decks can be reached and their riflemen fought. On two held islands, every deck's
## ladder takes a captain from its foot up onto the deck's boards; up there, a cutlass reaches the deck's rifleman; and
## running at the crate stairs in front of the first two decks with jumps gets a captain up too.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
const SEEDS := [9300, 4711]
var stage
var world
var isl
var h
var p
var decks: Array = []
var deck_i := 0
var isle_i := 0
var rifle
var hp0 := 0.0
var clicks := 0
var stack_i := 0
var hops := 0
var retry := 0
var step := 0
var until := 0
var fails := 0
var tries := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if step == 8 and hops > 0 and _on_stack_deck():
		TK.release("move_forward")
		TK.release("jump")
		step = 9
		until = TK.wait_secs(0.6)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var hc = p.get_node("HealthComponent")
			hc.max_health = 999999.0
			hc.current_health = 999999.0
			var P = load("res://scripts/island/pirate_held.gd")
			P.force = true
			isl = _island(int(SEEDS[isle_i]))
			P.force = false
			h = isl.get_node("Site_village/Village/Held")
			# (their captain kept in: t/island/pirate_held fights him)
			root.get_node("GameManager").world_flags[isl.save_key("held_captain")] = true
			tries = 0
			until = TK.wait_secs(1.0)
		1:
			if h.garrison.grunts.size() < h.garrison.specs.size() and tries < 40:
				tries += 1
				until = TK.wait_secs(0.5)
				return false
			decks = isl.find_children("RoofDeck*", "", true, false)
			# (everyone but the first deck's rifleman gone: a shot or a bite knocks a climber off)
			var top0: Vector3 = decks[0].to_global(Vector3(0, decks[0].get_node("Ladder").position.y, -0.3))
			for g in get_nodes_in_group("enemies"):
				if isl.is_ancestor_of(g) and g.global_position.distance_to(top0) > 3.5:
					g.queue_free()
			check("seed %d: roof decks (%d)" % [SEEDS[isle_i], decks.size()], decks.size() >= 2)
			deck_i = 0
		2:
			var lad = decks[deck_i].get_node("Ladder")
			var foot: Vector3 = lad.to_global(Vector3(0, -lad.length, 0.7))
			p.global_position = Vector3(foot.x, _ground(foot) + 0.3, foot.z)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		3:
			var lad = decks[deck_i].get_node("Ladder")
			check("seed %d deck %d: in reach of its ladder at the foot" % [SEEDS[isle_i], deck_i], lad.in_reach(p.global_position) and p.is_on_floor())
			print("   at the foot: %s, free %s, floor %s" % [p.current_state_name(), p.is_free(), p.is_on_floor()])
			lad._on_use(p)
			TK.press("move_forward")
			tries = 0
			until = TK.wait_ticks(6)
		4:
			if p.current_state_name() == "Climb" and tries < 200:
				tries += 1
				until = TK.wait_ticks(3)
				return false
			TK.release("move_forward")
			var d = decks[deck_i]
			var lad = d.get_node("Ladder")
			var l: Vector3 = d.to_local(p.global_position)
			var top: float = lad.position.y
			var r: Dictionary = h.plan["roofs"][deck_i]
			print("   deck %d: top %.2f, captain at %s (%s)" % [deck_i, top, l, p.current_state_name()])
			var up := absf(l.y - top) < 0.5 and absf(l.x) < float(r["w"]) * 0.5 and absf(l.z) < float(r["d"]) * 0.5
			if not up and retry < 1:
				# (knocked off by the rifleman up there: a captain tries again)
				retry += 1
				step = 2
				return false
			retry = 0
			check("seed %d deck %d: climbed up onto the boards" % [SEEDS[isle_i], deck_i], absf(l.y - top) < 0.5 and absf(l.x) < float(r["w"]) * 0.5 and absf(l.z) < float(r["d"]) * 0.5)
			if deck_i == 0:
				rifle = null
				var best := 3.5
				for g in h.garrison.grunts:
					if is_instance_valid(g) and not g.is_dead() and g.global_position.distance_to(d.to_global(Vector3(0, top, -0.3))) < best:
						best = g.global_position.distance_to(d.to_global(Vector3(0, top, -0.3)))
						rifle = g
				check("...its rifleman up there with you", rifle != null)
				if rifle == null:
					return TK.done(fails + 1)
				hp0 = rifle.health.current_health
				clicks = 0
			else:
				step = 6
				return false
		5:
			if clicks < 10 and is_instance_valid(rifle) and not rifle.is_dead() and rifle.health.current_health >= hp0:
				var to: Vector3 = rifle.global_position - p.global_position
				stage.camera_rig.rotation.y = atan2(-to.x, -to.z)
				p.global_position = rifle.global_position - Vector3(to.x, 0, to.z).normalized() * 1.2 + Vector3(0, 0.1, 0)
				p.reset_physics_interpolation()
				TK.act("light_attack")
				print("   swing %d: %s armed %s, his hp %.0f, %.1f m" % [clicks, p.current_state_name(), p.armed, rifle.health.current_health, to.length()])
				clicks += 1
				until = TK.wait_secs(0.5)
				return false
			check("...and a cutlass reaches him (%d swings)" % clicks, not is_instance_valid(rifle) or rifle.is_dead() or rifle.health.current_health < hp0)
			if is_instance_valid(rifle):
				rifle.queue_free()
		6:
			deck_i += 1
			if deck_i < decks.size():
				step = 2
				return false
			stack_i = 0
		7:
			# the crate stairs: from the ground out in front, forward and jump, up onto the deck
			var s: Dictionary = h.plan["stacks"][stack_i]
			var out: Vector3 = isl.to_global(Vector3(s["out"].x, 0, s["out"].y)) - isl.global_position
			var foot: Vector2 = (s["p"] as Vector2) + (s["out"] as Vector2) * 4.2
			p.global_position = isl.to_global(Vector3(foot.x, isl.hv(foot) + 0.3, foot.y))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			stage.camera_rig.rotation.y = atan2(out.x, out.z)
			hops = 0
			until = TK.wait_secs(0.6)
		8:
			if hops == 0:
				TK.press("move_forward")
			# (held, not tapped: a tap is a short hop; stopped as soon as they're up, or a jump clears the back rail)
			if hops < 24:
				if hops % 2 == 0:
					TK.press("jump")
				else:
					TK.release("jump")
				hops += 1
				until = TK.wait_ticks(21 if hops % 2 == 1 else 6)
				return false
			TK.release("move_forward")
			TK.release("jump")
			until = TK.wait_secs(0.6)
		9:
			var s: Dictionary = h.plan["stacks"][stack_i]
			var d = decks[int(s["roof"])]
			var l: Vector3 = d.to_local(p.global_position)
			var r: Dictionary = h.plan["roofs"][int(s["roof"])]
			print("   stack %d: captain at %s on deck %d" % [stack_i, l, int(s["roof"])])
			check("seed %d: up the crates onto deck %d" % [SEEDS[isle_i], int(s["roof"])], absf(l.y - float(d.get_node("Ladder").position.y)) < 0.5 and absf(l.x) < float(r["w"]) * 0.5 + 0.2 and absf(l.z) < float(r["d"]) * 0.5 + 0.2)
			stack_i += 1
			if stack_i < h.plan["stacks"].size():
				step = 7
				return false
			isle_i += 1
			if isle_i < SEEDS.size():
				isl.queue_free()
				step = 0
				until = TK.wait_ticks(5)
				return false
			return TK.done(fails)
	step += 1
	return false


func _on_stack_deck() -> bool:
	var dk = decks[int(h.plan["stacks"][stack_i]["roof"])]
	return absf(dk.to_local(p.global_position).y - float(dk.get_node("Ladder").position.y)) < 0.3 and p.is_on_floor()


func _ground(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 6.0, 1)
	var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else at.y


func _island(sd: int):
	if world == null:
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
	n["seed"] = sd
	var t = load("res://scripts/island/themes/island_themes.gd").of("jungle")
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": "Old Grumble", "minis": [t.minis[0]], "roamer": t.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	var gi = load("res://scripts/island/gen_island.gd").new()
	gi.name = "HeldIsle%d" % sd
	gi.position = Vector3(5000.0, 0, 0)
	world.add_child(gi)
	gi.build(n)
	return gi
