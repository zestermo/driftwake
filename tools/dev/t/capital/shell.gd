extends SceneTree
## The royal capital built (CapitalIsland, piece 1): a dock to board from, the ship's berth in deep water alongside
## the quay with nothing solid in it, the quay a floor you stand on, the palace up on its hill, the arena and the
## walls standing; every walkable floor closed at its edges but where it opens into the palace grounds (1.21) (a wall, a house or another floor: no way out into the
## houses behind); its style ashore; the same city from the same node.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(0, 0, 4000)
var stage
var step := 0
var until := 0
var fails := 0
var w
var isl


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))


func _solid_at(p: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	return not root.world_3d.direct_space_state.intersect_point(q, 1).is_empty()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var P = load("res://scripts/island/capital_plan.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(4)
		2:
			check("a dock to board from", isl.find_child("DockingArea", true, false) != null)
			var berth: Vector2 = isl.from_city(P.BERTH)
			check("the berth is deep (%.1f m)" % isl.height_at(berth.x, berth.y), isl.height_at(berth.x, berth.y) < -4.5)
			var moor: Array = isl.mooring()
			var box := BoxShape3D.new()
			box.size = Vector3(5.0, 3.0, 17.0)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = box
			q.transform = Transform3D(Basis(Vector3.UP, float(moor[1])), (moor[0] as Vector3) + Vector3(0, 2.0, 0))
			check("nothing solid in the ship's berth", root.world_3d.direct_space_state.intersect_shape(q, 4).is_empty())
			var sp: Vector3 = isl.harbour_spawn()
			var hit := _ray(sp + Vector3.UP * 3.0, sp + Vector3.DOWN * 6.0)
			check("the quay by the ship is a floor at its height (%s)" % [hit.get("position")], not hit.is_empty() and absf(hit["position"].y - P.QUAY_Y) < 0.15)
			# (one big mesh shape lost rays over half the quay: the floors are cut into several)
			var holes: Array = []
			for f in P.FLOORS:
				var r: Rect2 = f[1]
				var x: float = r.position.x + 1.0
				while x < r.end.x:
					var z: float = r.position.y + 1.0
					while z < r.end.y:
						var q2 := Vector2(x, z)
						var h := _ray(isl.city_global(q2, P.ground(q2) + 3.0), isl.city_global(q2, P.ground(q2) - 3.0))
						# (a crate or a stall standing on the floor is fine: falling through to the ground under it isn't)
						if h.is_empty() or (str(h["collider"].name).begins_with("Ground") and absf(h["position"].y - P.ground(q2)) > 0.15):
							holes.append("%s %s" % [f[0], q2.round()])
						z += 5.0
					x += 5.0
			check("every floor is solid underfoot (%d holes: %s)" % [holes.size(), holes.slice(0, 8)], holes.is_empty())
			var top := _ray(isl.city_global(P.HILL_C + Vector2(0, 30), 200.0), isl.city_global(P.HILL_C + Vector2(0, 30), 0.0))
			check("the palace's forecourt up on its hill (%.1f)" % (top["position"].y if not top.is_empty() else 0.0), not top.is_empty() and top["position"].y > P.HILL_TOP - 0.5)
			for n in ["Palace", "Arena", "HarbourWall", "SeaWall", "PalaceGrounds", "Quay", "Floors"]:
				check("the %s stands" % n, isl.city.get_node_or_null(n) != null)
			var KS = load("res://scripts/island/kit/kit_style.gd")
			var zone: Array = KS.around(self, isl.city_global(P.PLAZA.get_center(), 6.0))
			check("its own style ashore", zone[0] == "capital" and float(zone[1]) > 0.99 and KS.of("capital")["paving"] == "capital_slabs")
			var open: Array = []
			for f in P.FLOORS:
				var r: Rect2 = f[1]
				var edges := [[r.position, Vector2(r.end.x, r.position.y), Vector2(0, -1)], [Vector2(r.position.x, r.end.y), r.end, Vector2(0, 1)],
					[r.position, Vector2(r.position.x, r.end.y), Vector2(-1, 0)], [Vector2(r.end.x, r.position.y), r.end, Vector2(1, 0)]]
				for e in edges:
					var n: Vector2 = e[2]
					if f[0] == "quay" and n.y > 0.0:
						continue
					var a: Vector2 = e[0]
					var b: Vector2 = e[1]
					var k := int(a.distance_to(b) / 2.0)
					for i in range(k):
						var p: Vector2 = a.lerp(b, (i + 0.5) / k)
						# (another floor, or the plaza's own buildings: the guild's portico opens off the plaza)
						if P.in_floor(p + n * 1.0, 0.6) or P.special_hit(Rect2(p + n * 1.0, Vector2.ZERO).grow(0.1)):
							continue
						# (1.21: the palace grounds and the arena are walked: the avenue's top opens through the gate, the court onto the
						# grounds, the arena's gate onto its sand)
						if (p + n * 1.5).distance_to(P.HILL_C) < P.GROUNDS_R + 4.0 or P.ellipse(p + n * 1.5, P.ARENA_C, P.ARENA_R) < 1.0:
							continue
						var y: float = P.ground(p) + 1.2
						var from: Vector3 = isl.city_global(p - n * 1.5, y)
						if _solid_at(from):
							continue
						# (14 m: a portico's steps lead in under its columns before its wall, and 1.27's open doors into a room
						# that ends at its back wall, closed pockets both)
						if _ray(from, isl.city_global(p + n * 14.0, y)).is_empty():
							open.append("%s %s" % [f[0], p.round()])
			check("every floor closed at its edges (%d open: %s)" % [open.size(), open.slice(0, 12)], open.is_empty())
			var meshes: int = isl.city.find_children("*", "MeshInstance3D", true, false).filter(func(m): return not isl.crowd.is_ancestor_of(m) and not str(m.get_parent().get_script().resource_path if m.get_parent().get_script() else "").ends_with("ladder.gd")).size()  # (1.27: the roof ladders are their own nodes)
			check("the city's pieces are few meshes (%d)" % meshes, meshes < 60)
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
