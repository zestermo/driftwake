extends SceneTree
## Occlusion culling in the city (Occluders): the project has it on; the city's walls, towers, the town houses and
## the massing behind them carry occluders (one OccluderInstance3D a piece, its boxes as one mesh); none sticks out
## where you could see past it: every corner of a district or shell occluder is inside the solid stone it stands in
## (its colliders), and none of the massing's stands over a walkable floor. A plain house (Buildings.house) has
## one box inside its walls.
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


func _solid_at(p: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	return not root.world_3d.direct_space_state.intersect_point(q, 1).is_empty()


## Each box of an occluder's mesh (8 corners a box, Occluders._add) as its world corners.
func _boxes(oi: OccluderInstance3D) -> Array:
	var v: PackedVector3Array = (oi.occluder as ArrayOccluder3D).vertices
	var out: Array = []
	for b in range(v.size() / 8):
		var c: Array = []
		for k in range(8):
			c.append(oi.global_transform * v[b * 8 + k])
		out.append(c)
	return out


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var P = load("res://scripts/island/capital_plan.gd")
	match step:
		0:
			check("occlusion culling is on", bool(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling")))
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(4)
		2:
			var occs: Array = isl.city.find_children("*", "OccluderInstance3D", true, false)
			var by := {}
			var boxes := 0
			for oi in occs:
				by[str(oi.get_parent().name)] = _boxes(oi)
				boxes += (by[str(oi.get_parent().name)] as Array).size()
			for n in ["SeaWall", "HarbourWall", "PalaceGrounds", "Palace", "Landmarks", "Quay", "Barriers", "PlazaHalls", "Town_plaza", "Town_street"]:
				check("the %s has occluders (%d boxes)" % [n, (by.get(n, []) as Array).size()], (by.get(n, []) as Array).size() > 0)
			var massing: Array = by.keys().filter(func(k): return str(k).begins_with("Houses_"))
			var mboxes := 0
			for k in massing:
				mboxes += (by[k] as Array).size()
			check("the massing's houses have them (%d boxes in %d chunks)" % [mboxes, massing.size()], mboxes > 400 and massing.size() > 10)
			check("none on the arena (its arcades are open) nor the floors", not by.has("Arena") and not by.has("Floors"))
			var out: Array = []
			for k in by.keys():
				if str(k).begins_with("Houses_"):
					continue
				for c in by[k]:
					var mid: Vector3 = (c as Array).reduce(func(a, b): return a + b, Vector3.ZERO) / 8.0
					for p in c:
						# (a hair in: the corner itself is on the face of the stone)
						if not _solid_at((p as Vector3).lerp(mid, 0.01)):
							out.append("%s %s" % [k, (p as Vector3).round()])
							break
			check("every wall's and house's occluder is inside its stone (%d of %d out: %s)" % [out.size(), boxes, out.slice(0, 6)], out.is_empty())
			var over: Array = []
			for k in massing:
				for c in by[k]:
					for p in c:
						var l: Vector3 = isl.city.to_local(p)
						if P.in_floor(Vector2(l.x, l.z), -0.2):
							over.append("%s %s" % [k, Vector2(l.x, l.z).round()])
							break
			check("no massing occluder over a street (%d: %s)" % [over.size(), over.slice(0, 6)], over.is_empty())
			isl.queue_free()
			var h: Node3D = load("res://scripts/props/buildings.gd").house({"w": 6.0, "d": 5.0, "floors": 2, "seed": 4})
			root.add_child(h)
			var ho: Array = h.find_children("*", "OccluderInstance3D", false, false)
			check("a house has one occluder", ho.size() == 1)
			var inside := true
			for p in _boxes(ho[0])[0]:
				inside = inside and absf(p.x) < 3.0 and absf(p.z) < 2.5 and p.y > 0.3 and p.y < 0.3 + 2.6 + 2.3 + 0.1
			check("...inside its walls", inside)
			h.queue_free()
			return TK.done(fails)
	step += 1
	return false
