extends SceneTree
## The canal city walked into and climbed (1.27: CapitalInteriors and CapitalRoofs on its houses): every shop and about a
## third of the houses have an open doorway into a furnished room, the flat roofs are solid at their slabs, ladders climb
## from the calli, and the captain stands in a room and on a roof.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(900, 0, 900)
var stage
var w
var isl
var p
var room: Dictionary
var roof: Dictionary
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var P = load("res://scripts/island/canal_plan.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_canal(AT)
			until = TK.wait_ticks(4)
		2:
			var rooms: Array = isl.doors.filter(func(dd): return dd.get("inside", Vector3.INF) != Vector3.INF)
			check("rooms to walk into (%d)" % rooms.size(), rooms.size() >= 15)
			var blocked: Array = []
			for dd in rooms:
				var at: Vector3 = dd["at"]
				var iv: Vector3 = dd["inside"]
				var fc: Vector2 = dd["face"]
				if not _ray(isl.city_global(Vector2(at.x, at.z) + fc * 0.5, iv.y + 1.3), isl.city_global(Vector2(at.x, at.z) - fc * 1.8, iv.y + 1.3)).is_empty():
					blocked.append(str(Vector2(at.x, at.z).round()))
			check("every doorway is open into its room (%s)" % [blocked.slice(0, 6)], blocked.is_empty())
			var flats: Array = P.lots().filter(func(l): return l.has("top_y") and str(l["roof"]) == "flat")
			var holes: Array = []
			for l in flats:
				var a: Vector3 = isl.city_global(l["c"], float(l["top_y"]) + 6.0)
				var hit := _ray(a, a + Vector3.DOWN * 12.0)
				var dy: float = (hit["position"].y if not hit.is_empty() else -INF) - isl.city_global(l["c"], float(l["top_y"])).y
				if dy < -0.35:
					holes.append("%s %.1f" % [(l["c"] as Vector2).round(), dy])
			check("flat roofs to stand on (%d), every one solid (%s)" % [flats.size(), holes.slice(0, 6)], flats.size() >= 10 and holes.is_empty())
			check("ladders up from the calli (%d)" % isl.city.find_children("*", "Ladder", true, false).size(), isl.city.find_children("*", "Ladder", true, false).size() >= 2)
			room = rooms[0]
			roof = flats[flats.size() / 2]
			p = stage.player
			var iv: Vector3 = room["inside"]
			p.global_position = isl.city_global(Vector2(iv.x, iv.z), iv.y + 0.4)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		3:
			var iv: Vector3 = room["inside"]
			var y0: float = isl.city_global(Vector2(iv.x, iv.z), iv.y).y
			check("the captain stands in a room (%.2f over its floor)" % (p.global_position.y - y0), absf(p.global_position.y - y0) < 0.4)
			p.global_position = isl.city_global(roof["c"], float(roof["top_y"]) + 0.6)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		4:
			var y0: float = isl.city_global(roof["c"], float(roof["top_y"])).y
			check("...and on a flat roof (%.2f over it)" % (p.global_position.y - y0), absf(p.global_position.y - y0) < 0.5)
			return TK.done(fails)
	step += 1
	return false
