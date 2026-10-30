extends SceneTree
## The canal city's campanile is climbed (1.27, CapitalBellTower in brick): its door opens off its paving, every flight of the stairs
## round its walls is solid underfoot at its height, the belfry floor holds the captain 22 m up, and the hooded stranger
## has his place there.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(900, 0, 900)
var stage
var w
var isl
var p
var y0 := 0.0
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
	var BT = load("res://scripts/island/capital_bell_tower.gd")
	var c: Vector2 = (load("res://scripts/island/canal_plan.gd").SPECIAL["campanile"][0] as Rect2).get_center()
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_canal(AT)
			until = TK.wait_ticks(4)
		2:
			y0 = load("res://scripts/island/canal_plan.gd").QUAY_Y
			var door_out: Vector3 = isl.city_global(c + Vector2(0, BT.W * 0.5 + 1.5), y0 + 1.3)
			var door_in: Vector3 = isl.city_global(c + Vector2(0, 0.5), y0 + 1.3)
			check("the door opens from its paving into the tower", _ray(door_out, door_in).is_empty())
			var yard_hit := _ray(door_out, door_out + Vector3.DOWN * 3.0)
			check("the paving is laid at the door", not yard_hit.is_empty() and absf(yard_hit["position"].y - isl.city_global(c, y0).y) < 0.5)
			# every flight's middle: a ray down from just over it lands on it
			var a: float = BT.W * 0.5 - BT.WALL
			var corners := [Vector2(-a + 0.55, -a + 0.55), Vector2(a - 0.55, -a + 0.55), Vector2(a - 0.55, a - 0.55), Vector2(-a + 0.55, a - 0.55)]
			var rise: float = BT.BELFRY / BT.FLIGHTS
			var bad: Array = []
			for k in range(BT.FLIGHTS):
				var q: Vector2 = c + ((corners[k % 4] as Vector2) + (corners[(k + 1) % 4] as Vector2)) * 0.5
				var ym := y0 + (k + 0.5) * rise
				var hit := _ray(isl.city_global(q, ym + 1.0), isl.city_global(q, ym - 1.5))
				if hit.is_empty() or absf(hit["position"].y - isl.city_global(q, ym).y) > 0.45:
					bad.append("%d %s" % [k, "nothing" if hit.is_empty() else "%.2f" % (hit["position"].y - isl.city_global(q, ym).y)])
			check("every flight is solid underfoot at its height (%s)" % [bad], bad.is_empty())
			check("the hooded stranger's place up there", isl.spots.has("informant") and absf((isl.spots["informant"][0] as Vector3).y - (y0 + BT.BELFRY)) < 0.3)
			p = stage.player
			var top: Vector3 = BT.top(c, y0)
			p.global_position = isl.city_global(Vector2(top.x, top.z) + Vector2(1.2, 0.8), top.y + 0.5)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		3:
			var yb: float = isl.city_global(c, y0 + 22.0).y
			check("the captain stands in the belfry, 22 m up (%.2f over its floor)" % (p.global_position.y - yb), absf(p.global_position.y - yb) < 0.5)
			return TK.done(fails)
	step += 1
	return false
