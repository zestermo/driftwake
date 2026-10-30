extends SceneTree
## The capital's ground floors you can walk into (1.27, CapitalInteriors): every shop and about a third of the street
## houses have an open doorway (a clear line from the street through the door into the room), a floor the captain
## stands on, walls round it, and inside what the place is (a shop's counter across the back).
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(900, 0, 900)
var stage
var w
var isl
var p
var room: Dictionary
var upper: Dictionary
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
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(4)
		2:
			var rooms: Array = isl.doors.filter(func(dd): return dd.get("inside", Vector3.INF) != Vector3.INF)
			var shops: Array = rooms.filter(func(dd): return str(dd["kind"]) != "")
			check("rooms to walk into (%d, %d of them shops)" % [rooms.size(), shops.size()], rooms.size() >= 20 and shops.size() >= 8)
			var blocked: Array = []
			var walled: Array = []
			for dd in rooms:
				var at: Vector3 = dd["at"]
				var iv: Vector3 = dd["inside"]
				var fc: Vector2 = dd["face"]
				var from: Vector3 = isl.city_global(Vector2(at.x, at.z) + fc * 0.5, iv.y + 1.3)
				var door_in: Vector3 = isl.city_global(Vector2(at.x, at.z) - fc * 1.8, iv.y + 1.3)
				if not _ray(from, door_in).is_empty():
					blocked.append(str(Vector2(at.x, at.z).round()))
				# (round the room: a wall within 12 m each way)
				var c: Vector3 = isl.city_global(Vector2(iv.x, iv.z), iv.y + 1.3)
				for dir in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
					var toward := Vector2(dir.x, dir.z)
					if toward.dot(Vector2((isl.city_global(Vector2(at.x, at.z), 0) - c).x, (isl.city_global(Vector2(at.x, at.z), 0) - c).z).normalized()) > 0.8:
						continue
					if _ray(c, c + dir * 12.0).is_empty():
						walled.append(str(Vector2(iv.x, iv.z).round()))
						break
			check("every doorway is open into its room (%s)" % [blocked.slice(0, 6)], blocked.is_empty())
			check("every room is walled round (%s)" % [walled.slice(0, 6)], walled.is_empty())
			# (1.27) some homes have a first floor: a stair up the side wall to a bedroom
			var ups: Array = rooms.filter(func(dd): return not (dd.get("upper", {}) as Dictionary).is_empty())
			check("some homes have an upstairs (%d)" % ups.size(), ups.size() >= 2)
			var off: Array = []
			for dd in ups:
				var u: Dictionary = dd["upper"]
				var s: Vector3 = u["stair"]
				var hs := _ray(isl.city_global(Vector2(s.x, s.z), s.y + 2.0), isl.city_global(Vector2(s.x, s.z), s.y - 2.0))
				if hs.is_empty() or absf(isl.to_local(hs["position"]).y - s.y) > 0.5:
					off.append("stair %s" % Vector2(s.x, s.z).round())
				var f: Vector3 = u["floor"]
				var hf := _ray(isl.city_global(Vector2(f.x, f.z), f.y + 1.5), isl.city_global(Vector2(f.x, f.z), f.y - 1.0))
				if hf.is_empty() or absf(isl.to_local(hf["position"]).y - f.y) > 0.15:
					off.append("floor %s" % Vector2(f.x, f.z).round())
			check("...each stair walked half way up and its upper floor under you (%s)" % [off.slice(0, 6)], off.is_empty())
			upper = ups[0] if not ups.is_empty() else {}
			room = shops[0] if not shops.is_empty() else rooms[0]
			p = stage.player
			var iv: Vector3 = room["inside"]
			p.global_position = isl.city_global(Vector2(iv.x, iv.z), iv.y + 0.4)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		3:
			var iv: Vector3 = room["inside"]
			var y0: float = isl.city_global(Vector2(iv.x, iv.z), iv.y).y
			check("the captain stands on the room's floor (%.2f over it)" % (p.global_position.y - y0), absf(p.global_position.y - y0) < 0.4)
			if upper.is_empty():
				return TK.done(fails)
			var f: Vector3 = upper["upper"]["floor"]
			p.global_position = isl.city_global(Vector2(f.x, f.z), f.y + 0.4)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		4:
			var f: Vector3 = upper["upper"]["floor"]
			var y1: float = isl.city_global(Vector2(f.x, f.z), f.y).y
			check("...and upstairs, on the bedroom's floor (%.2f over it)" % (p.global_position.y - y1), absf(p.global_position.y - y1) < 0.4)
			return TK.done(fails)
	step += 1
	return false
