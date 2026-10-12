extends SceneTree
## Generated harbours (GenHarbour): each kind (stilts, cove, wharf, ruins) forced
## on a chain island built far out to sea: a harbour district at its dock (7+
## buildings, 20+ props in fidelity's harbour district), lamps within the budget,
## deep water off the pier's head and the "Board ship" area, the ship's berth
## clear of everything built, a captain stands on the pier's head and on the
## harbour's walkways; the same node plans the same harbour twice; the seeds roll
## different kinds.
const KINDS := ["stilts", "cove", "wharf", "ruins", "landing"]
## Each kind's least: [buildings, props] in fidelity's harbour district (a bare landing has next to nothing).
const LEAST := {"stilts": [7, 20], "cove": [7, 20], "wharf": [7, 20], "ruins": [7, 20], "landing": [0, 4]}
var t := 0.0
var step := 0
var wait := 0.0
var p
var w
var gh
var isl
var job := 0
var fails := 0


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


func _process(d: float) -> bool:
	t += d
	if t > 240.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5:
				return false
			w = root.get_node("World/Islands")
			if not w.chain_ready():
				return false
			w.set_process(false)
			p = get_first_node_in_group("player")
			gh = load("res://scripts/island/kit/kit_harbour_gen.gd")
			step = 1
		1:
			var c = w.chain()
			var n: Dictionary = c.node(int(c.start_next[0]))
			var kind: String = KINDS[job]
			gh.force = kind
			isl = load("res://scripts/island/gen_island.gd").new()
			isl.name = "HarbourTestIsle"
			isl.position = Vector3(40000.0, 0.0, 40000.0 + job * 3000.0)
			w.add_child(isl)
			isl.build(n)
			gh.force = ""
			var hb = isl.harbour
			check("[%s] the harbour is the kind asked for" % kind, hb.kind == kind)
			var site: Node3D = isl.get_node("Site_harbour")
			var r: Dictionary = load("res://tools/dev/fidelity.gd").measure(isl)
			var dh: Dictionary = r["d"]["districts"]["harbour"]
			print("   %s: harbour district %s, shore %.0f..%.0f, %d steps, build %s ms" % [kind, dh, hb.f.s0, hb.f.s1, hb.steps().size(), isl.build_ms.get("harbour", 0)])
			check("[%s] a harbour district: %d+ buildings (%d)" % [kind, LEAST[kind][0], int(dh["buildings"])], int(dh["buildings"]) >= int(LEAST[kind][0]))
			check("[%s] ...and %d+ props (%d)" % [kind, LEAST[kind][1], int(dh["props"])], int(dh["props"]) >= int(LEAST[kind][1]))
			var lights := site.find_children("*", "NightLight", true, false).size()
			check("[%s] lamps lit from the budget: 2-%d NightLights (%d)" % [kind, hb.LIGHTS, lights], lights >= 2 and lights <= hb.LIGHTS)
			var de: Vector2 = isl.sites["dock_end"]
			check("[%s] deep water off the pier's head (%.1f m)" % [kind, isl.height_at(de.x, de.y)], isl.height_at(de.x, de.y) < -3.5)
			check("[%s] a pier to board from" % kind, site.find_child("DockingArea", true, false) != null)
			p.state_machine.force_state("Idle", {})
			p.global_position = isl.to_global(Vector3(de.x - isl.dock_dir.x * 3.0, isl.DOCK_DECK_Y + 0.5, de.y - isl.dock_dir.y * 3.0))
			p.reset_physics_interpolation()
			wait = 1.2
			step = 2
		2:
			var ground: float = isl.to_global(Vector3(0, isl.DOCK_DECK_Y, 0)).y
			check("[%s] a captain stands on the pier's head (%.2f m over the deck)" % [KINDS[job], p.global_position.y - ground], p.is_on_floor() and absf(p.global_position.y - ground) < 0.3)
			# the berth: a hull's box where the ship lies alongside touches nothing of the harbour's
			var moor: Array = isl.mooring()
			var q := PhysicsShapeQueryParameters3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(7.2, 3.0, 17.4)
			q.shape = box
			q.transform = Transform3D(Basis(Vector3.UP, moor[1]), moor[0] + Vector3(0, 1.5, 0))
			q.collision_mask = 1
			var hits: Array = []
			for h in root.get_world_3d().direct_space_state.intersect_shape(q, 16):
				if isl.is_ancestor_of(h["collider"]):
					hits.append(str(h["collider"].name))
			check("[%s] the ship's berth is clear %s" % [KINDS[job], hits], hits.is_empty())
			# the harbour's longest level walkway, halfway along its first stretch
			var best := 0.0
			var wp: Vector2 = isl.dock_shore + isl.dock_dir * 8.0
			for walk in isl.harbour._walks:
				var pts: PackedVector2Array = walk["pts"]
				if not (walk["ys"] as PackedFloat32Array).is_empty() or pts[0].distance_to(pts[1]) <= best:
					continue
				best = pts[0].distance_to(pts[1])
				wp = (pts[0] + pts[1]) * 0.5
			set_meta("walk_y", isl.to_global(Vector3(0, isl.DOCK_DECK_Y, 0)).y)
			p.state_machine.force_state("Idle", {})
			p.global_position = isl.to_global(Vector3(wp.x, isl.DOCK_DECK_Y + 0.5, wp.y))
			p.reset_physics_interpolation()
			wait = 1.2
			step = 3
		3:
			var y: float = get_meta("walk_y")
			check("[%s] ...and on its walkways (%.2f m over the deck)" % [KINDS[job], p.global_position.y - y], p.is_on_floor() and absf(p.global_position.y - y) < 0.3)
			isl.queue_free()
			isl = null
			job += 1
			step = 1 if job < KINDS.size() else 4
			wait = 0.2
		4:
			# the same node plans the same harbour; the seeds roll their own kinds
			var c = w.chain()
			var n: Dictionary = c.node(int(c.start_next[0]))
			var a = load("res://scripts/island/gen_island.gd").new()
			var b = load("res://scripts/island/gen_island.gd").new()
			a.prepare(n)
			b.prepare(n)
			check("the same node plans the same harbour (%s)" % a.harbour.kind, a.harbour.kind == b.harbour.kind and a.harbour.spots == b.harbour.spots
				and a.harbour.steps().size() == b.harbour.steps().size() and a.exclusions.size() == b.exclusions.size())
			a.free()
			b.free()
			var gm = root.get_node("GameManager")
			var seen := {}
			for s in [777, 31337, 4242, 99, 1234, 5150]:
				gm.chain_seed = s
				var cc = w.chain()
				var g = load("res://scripts/island/gen_island.gd").new()
				g.prepare(cc.node(int(cc.start_next[0])))
				seen[g.harbour.kind] = true
				g.free()
			print("   kinds rolled by six seeds: %s" % [seen.keys()])
			check("the seeds roll different kinds of harbour", seen.size() >= 2)
			finish()
	return false
