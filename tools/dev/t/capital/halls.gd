extends SceneTree
## The capital's library and theatre are walked into (1.27, CapitalHalls): each door open from its floor into the hall,
## each floor holds the captain, and the library's hidden room is reached through the gap at the end of its back shelf
## (and nowhere else along it).
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(900, 0, 900)
var stage
var w
var isl
var p
var halls := ["library", "theatre"]
var hi := 0
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


func _g(t: Transform3D, v: Vector3) -> Vector3:
	var f: Vector3 = t * v
	return isl.city_global(Vector2(f.x, f.z), f.y)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var H = load("res://scripts/island/capital_halls.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(4)
		2:
			var key: String = halls[hi]
			var fr: Array = H.frame(key)
			var t: Transform3D = fr[0]
			var d: float = fr[2]
			var wd: float = fr[1]
			var fy: float = H.ground(key) + H.RISE
			check("%s: the door is open from its floor into the hall" % key, _ray(_g(t, Vector3(0, fy + 1.6, d * 0.5 + 2.0)), _g(t, Vector3(0, fy + 1.6, d * 0.5 - 2.0))).is_empty())
			if key == "library":
				var back: float = -(d * 0.5 - H.WALL) + 3.2
				var ix: float = wd * 0.5 - H.WALL
				var through_gap := _ray(_g(t, Vector3(ix - 0.45, fy + 1.4, back + 1.0)), _g(t, Vector3(ix - 0.45, fy + 1.4, back - 1.0)))
				var through_shelf := _ray(_g(t, Vector3(0, fy + 1.4, back + 1.0)), _g(t, Vector3(0, fy + 1.4, back - 1.0)))
				check("library: the hidden room is reached through the gap at the shelf's end", through_gap.is_empty())
				check("library: ...and the rest of the back shelf is solid", not through_shelf.is_empty())
			p = stage.player
			var iv: Vector3 = H.inside(key)
			p.global_position = isl.city_global(Vector2(iv.x, iv.z), iv.y + 0.5)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		3:
			var key: String = halls[hi]
			var iv: Vector3 = H.inside(key)
			var y0: float = isl.city_global(Vector2(iv.x, iv.z), iv.y).y
			check("%s: the captain stands on its floor (%.2f over it)" % [key, p.global_position.y - y0], absf(p.global_position.y - y0) < 0.5)
			hi += 1
			if hi < halls.size():
				step = 2
				return false
			return TK.done(fails)
	step += 1
	return false
