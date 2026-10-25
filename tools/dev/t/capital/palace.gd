extends SceneTree
## The capital's palace walked (1.21 piece 2): the grounds' gate open, the road up the hill a surface you walk on (its
## slabs, not the terrain under them), the ring wall's gate at the top open, the court a floor, a ramp up the porch's
## steps, the throne hall's door open and its walls closed, its floor under you, the dais walked up to the throne.
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


## The height of the first surface under frame point q (from `top` down), or -INF.
func _floor_at(q: Vector2, top: float) -> float:
	var hit := _ray(isl.city_global(q, top), isl.city_global(q, top - 12.0))
	return -INF if hit.is_empty() else isl.to_local(hit["position"]).y


## Is the way from a to b (frame, at height y) clear?
func _clear(a: Vector2, b: Vector2, y: float) -> bool:
	return _ray(isl.city_global(a, y), isl.city_global(b, y)).is_empty()


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
			var g: Vector2 = P.PALACE_GATE
			# (through the gatehouse only: the ground rises past it to the road's foot)
			check("the grounds' gate is open", _clear(g + Vector2(0, 6.0), g - Vector2(0, 4.2), P.ground(g) + 1.5))
			var road := [Vector2(0, -72), Vector2(-36, -84), Vector2(30, -100), Vector2(-20, -113), Vector2(0, -120)]
			var off: Array = []
			for i in range(road.size() - 1):
				var q: Vector2 = (road[i] as Vector2).lerp(road[i + 1], 0.5)
				var y := _floor_at(q, P.ground(q) + 4.0)
				if absf(y - (P.ground(q) + 0.45)) > 0.3:
					off.append("%s: %.2f, the road %.2f" % [q.round(), y, P.ground(q) + 0.45])
			check("the road up the hill is walked on its slabs (%s)" % [off], off.is_empty())
			var top: float = P.HILL_TOP
			check("the ring wall's gate is open", _clear(Vector2(0, -110.0), Vector2(0, -126.0), top + 1.5))
			var court := Vector2(0, -138.0)
			check("the court is a floor (%.2f)" % _floor_at(court, top + 4.0), absf(_floor_at(court, top + 4.0) - P.ground(court)) < 0.3)
			var fy: float = P.hall_floor()
			var ramp := _floor_at(Vector2(4.0, P.HILL_C.y + 10.8), fy + 3.0)
			check("a ramp up the porch's steps (%.2f between %.2f and %.2f)" % [ramp, top, fy], ramp > top + 0.05 and ramp < fy - 0.05)
			check("the porch at the hall's floor", absf(_floor_at(Vector2(4.0, P.HILL_C.y + 7.0), fy + 3.0) - fy) < 0.15)
			var door_z: float = P.HALL_C.y + P.HALL_D * 0.5
			check("the throne hall's door is open", _clear(Vector2(0, door_z + 3.0), Vector2(0, door_z - 3.0), fy + 1.5))
			check("...and its front wall closed beside it", not _clear(Vector2(8.0, door_z + 3.0), Vector2(8.0, door_z - 3.0), fy + 1.5))
			check("the hall's floor under you (%.2f)" % _floor_at(P.HALL_C, fy + 4.0), absf(_floor_at(P.HALL_C, fy + 4.0) - fy) < 0.15)
			check("its walls closed", not _clear(P.HALL_C + Vector2(12.0, 0), P.HALL_C + Vector2(24.0, 0), fy + 2.0) and not _clear(P.HALL_C, P.HALL_C - Vector2(0, 14.0), fy + 2.0))
			var qv: Vector3 = isl.spots["queen"][0]
			var qq := Vector2(qv.x, qv.z)
			# (beside her: the ray would meet the Queen herself)
			var dais := _floor_at(qq + Vector2(1.4, 0), fy + 4.0)
			check("the Queen stands on her dais (%.2f)" % dais, absf(dais - (fy + 0.9)) < 0.2)
			var dramp := _floor_at(qq + Vector2(2.0, 1.8), fy + 4.0)
			check("...walked up to over a ramp (%.2f)" % dramp, dramp > fy + 0.05 and dramp < fy + 0.85)
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
