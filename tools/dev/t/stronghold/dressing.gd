extends SceneTree
## (1.30 round 7, the fortress art pass) StrongholdDress: the districts' props are built as MultiMeshes (guns, cargo,
## lamps, flags), none stands on a run anchor (posts, patrols, bells, doors, the winch and lever, ledges, the locks,
## the hoists, the arenas, the ways), the warships lie moored round the harbour with hulls you can't pass through, and
## the cell block's tiers hold a captain on their catwalks.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
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


func _floor_at(q: Vector2, y: float) -> float:
	var a: Vector3 = isl.city_global(q, y + 3.0)
	var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3.DOWN * 8.0))
	return -INF if hit.is_empty() else isl.to_local(hit["position"]).y


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var P = load("res://scripts/island/stronghold_plan.gd")
	var D = load("res://scripts/island/stronghold_dress.gd")
	var acts = load("res://scripts/island/stronghold_acts.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			until = TK.wait_secs(8.0)
		2:
			var kinds := {}
			var on_anchor: Array = []
			var n := 0
			for c in isl.city.get_children():
				if not c is MultiMeshInstance3D or not str(c.name).begins_with("Props_"):
					continue
				var kind := str(c.name).get_slice("_", 2)
				var mm: MultiMesh = c.multimesh
				kinds[kind] = int(kinds.get(kind, 0)) + mm.instance_count
				n += mm.instance_count
				for i in range(mm.instance_count):
					var o := mm.get_instance_transform(i).origin
					var q := Vector2(o.x, o.z)
					# (floor props only: the guns on the walls' tops stand over the anchors' floors)
					if absf(o.y - P.ground(q)) < 0.2 and not D.clear_at(q, 0.0) and P.room_at(q) < 0:
						on_anchor.append("%s %s" % [kind, q.round()])
			check("the props built: %d in %d kinds %s" % [n, kinds.size(), kinds], n > 120 and ["cannon", "crate", "barrel", "lamp", "flag", "shot", "board"].all(func(k): return kinds.has(k)))
			check("...none on a run anchor (%s)" % [on_anchor.slice(0, 6)], on_anchor.is_empty())
			var ships = isl.city.get_node_or_null("MooredWarships")
			check("the warships moored round the harbour, solid", ships != null and ships.get_children().filter(func(c): return c is CollisionShape3D).size() == isl.MOORED.size())
			var hits := 0
			for e: Array in isl.MOORED:
				var a: Vector3 = isl.city_global(e[0], 6.0)
				var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3.DOWN * 10.0))
				if not hit.is_empty() and hit["collider"] == ships:
					hits += 1
			check("...a hull under each (%d)" % hits, hits == isl.MOORED.size())
			var r: Rect2 = acts.CELLS
			var y1: float = 14.0 + acts.CELLS_H + 0.6
			# (past the stair between the tiers, which rises along the lower catwalk's south end)
			var cz := r.end.y - 1.0
			var t2 := _floor_at(Vector2(r.end.x + 0.75, cz), y1)
			var t3 := _floor_at(Vector2(r.end.x + 0.75, cz), y1 + 4.8)
			check("the cell block's catwalks hold a captain (tier 2 at %.1f, tier 3 at %.1f)" % [t2, t3], absf(t2 - y1) < 0.3 and absf(t3 - (y1 + 4.8)) < 0.3)
			return TK.done(fails)
	step += 1
	return false
