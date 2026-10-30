extends SceneTree
## The Admiralty's stronghold, the place (1.27, StrongholdIsland): one per chain, off the route (nothing leads to it,
## clear of every island); built, it stands on its rock: the quay, the ward up the grand stair, both wings, the keep
## over the chasm by the bridge, each walked at its height; the chasm under the bridge is open sea.
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


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))


## The first surface under frame point q from y down (island space height), or -INF.
func _floor_at(q: Vector2, y: float) -> float:
	var hit := _ray(isl.city_global(q, y), isl.city_global(q, y - 60.0))
	return -INF if hit.is_empty() else isl.to_local(hit["position"]).y


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var P = load("res://scripts/island/stronghold_plan.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			var c = w.c
			var sid: int = c.stronghold_id()
			check("the chain has its stronghold (%s)" % (c.node(sid)["name"] if sid >= 0 else "none"), sid >= 0)
			if sid < 0:
				return TK.done(fails)
			var s: Dictionary = c.node(sid)
			check("...off the route: nothing leads to it, it leads nowhere", s["next"].is_empty() and not c.nodes.any(func(o): return sid in o["next"]))
			var near: float = INF
			for o in c.nodes:
				if int(o["id"]) != sid:
					near = minf(near, (o["pos"] as Vector2).distance_to(s["pos"]))
			check("...clear of every island (%.0f m to the nearest)" % near, near >= c.STRONGHOLD_CLEAR)
			isl = w.build_stronghold(Vector3(900, 0, 900))
			# (long enough for the garrison's bodies to finish building: quitting mid-prebuild hangs the exit, docs/todo.md)
			until = TK.wait_secs(8.0)
		2:
			var off: Array = []
			for d in P.DISTRICTS:
				var q: Vector2 = (d[1] as Rect2).get_center() + Vector2(0, 8)
				var y := _floor_at(q, float(d[2]) + 3.0)
				if absf(y - float(d[2])) > 0.5:
					off.append("%s %.1f (want %.1f)" % [d[0], y, d[2]])
			check("every district walked at its height (%s)" % [off], off.is_empty())
			var ways: Array = []
			for wy in P.WAYS:
				var m: Vector2 = (wy[1] as Vector2).lerp(wy[2], 0.5)
				var want: float = (P._height_near(wy[1]) + P._height_near(wy[2])) * 0.5
				var y := _floor_at(m, want + 3.0)
				if absf(y - want) > 0.8:
					ways.append("%s %.1f (want %.1f)" % [wy[0], y, want])
			check("the stair, the ramps and the bridge walked half way (%s)" % [ways], ways.is_empty())
			var under := _floor_at(Vector2(-12, -31), 14.0)
			check("the chasm beside the bridge is open down to the sea (%.1f)" % under, under < 0.0)
			check("its fortress pieces stand", isl.city.get_child_count() >= 4)
			# (the rooms: in through the door from outside, a floor at its height, a ceiling at its height)
			var rooms: Array = []
			for rm in P.ROOMS:
				var r: Rect2 = rm[2]
				var y: float = rm[3]
				var dv: Vector2 = rm[5]
				var wall: Vector2 = r.get_center() + Vector2(dv.x * r.size.x * 0.5, dv.y * r.size.y * 0.5)
				var inside: Vector2 = wall - dv * 3.0
				if not _ray(isl.city_global(wall + dv * 3.0, y + 1.3), isl.city_global(inside, y + 1.3)).is_empty():
					rooms.append("%s: door shut" % rm[0])
				var fy := _floor_at(inside, y + 2.0)
				if absf(fy - y) > 0.3:
					rooms.append("%s: floor %.1f (want %.1f)" % [rm[0], fy, y])
				var up := _ray(isl.city_global(inside, y + 1.5), isl.city_global(inside, y + float(rm[4]) + 6.0))
				var cy: float = -INF if up.is_empty() else isl.to_local(up["position"]).y
				if absf(cy - (y + float(rm[4]))) > 0.5:
					rooms.append("%s: ceiling %.1f (want %.1f)" % [rm[0], cy, y + float(rm[4])])
			check("every room walked into: its door open, its floor and ceiling (%s)" % [rooms], rooms.is_empty())
			# (the island's shape: a ragged coast, reefs round it, a deep channel in, the cove and its drain)
			var rs: Array = []
			for k in range(72):
				var a := TAU * k / 72.0
				rs.append(P.coast_r(P.LAND_C + Vector2(cos(a), sin(a))))
			check("a ragged coast, not a circle (radius %.0f-%.0f m)" % [rs.min(), rs.max()], rs.max() - rs.min() > 25.0 and rs.min() >= P.COAST_MIN)
			var reefs := 0
			for k in range(360):
				var a := TAU * k / 360.0
				for dd: float in [20.0, 40.0, 60.0]:
					var q: Vector2 = P.LAND_C + Vector2(cos(a), sin(a)) * (P.coast_r(P.LAND_C + Vector2(cos(a), sin(a))) + dd)
					if P.terrain(q) > -1.5 and not P.in_channel(q):
						reefs += 1
			check("reefs and shallows round it (%d spots under 1.5 m)" % reefs, reefs > 60)
			var deep := true
			for z in range(70, 260, 10):
				deep = deep and P.terrain(Vector2(P.BERTH.x, float(z))) < -5.0
			check("...but a deep channel in to the sea gate and the berth", deep)
			var bc: Vector2 = P.BEACH[0]
			check("the west cove's beach at the water (%.1f)" % P.terrain(bc), P.terrain(bc) > -1.0 and P.terrain(bc) < 1.5)
			var dm := _floor_at(P.DRAIN + Vector2(-2.5, 0), P.DRAIN_Y + 4.0)
			check("...the drain's mouth walked up to from it (%.1f)" % dm, absf(dm - P.DRAIN_Y) < 1.2)
			check("the rooms' lanterns are lit (%d)" % isl.city.find_children("RoomLight*", "OmniLight3D", false, false).size(), isl.city.find_children("RoomLight*", "OmniLight3D", false, false).size() == 5)
			return TK.done(fails)
	step += 1
	return false
