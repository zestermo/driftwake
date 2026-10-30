extends SceneTree
## The capital's cathedral is walked into (1.27, CapitalCathedral): its forecourt joins the streets (the floors touch all
## the way from the plaza), the doors are open from the forecourt into the nave, its floor holds the captain, and the
## pews and the altar stand inside.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(900, 0, 900)
var stage
var w
var isl
var p
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
	var CC = load("res://scripts/island/capital_cathedral.gd")
	var P = load("res://scripts/island/capital_plan.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(4)
		2:
			# the floors as a graph (touching rects), from the plaza
			var fl: Array = P.floors()
			var seen := {3: true}
			var todo := [3]
			while not todo.is_empty():
				var i: int = todo.pop_back()
				for j in range(fl.size()):
					if not seen.has(j) and (fl[i][1] as Rect2).grow(0.6).intersects(fl[j][1]):
						seen[j] = true
						todo.append(j)
			var names: Array = seen.keys().map(func(j): return str(fl[j][0]))
			check("the forecourt joins the streets from the plaza", "forecourt" in names and "temple_walk" in names)
			var c: Vector2 = CC.centre()
			var ty: float = P.ground(c)
			var out_q := c + Vector2(CC.W * 0.5 + 3.0, 0)
			var in_q := c + Vector2(CC.W * 0.5 - 3.0, 0)
			check("the doors are open from the forecourt into the nave", _ray(isl.city_global(out_q, ty + 2.5), isl.city_global(in_q, ty + 2.5)).is_empty())
			var pew := _ray(isl.city_global(c + Vector2(-0.5, 5.0), ty + 4.0), isl.city_global(c + Vector2(-0.5, 5.0), ty - 2.0))
			check("the pews stand in the nave", not pew.is_empty() and pew["position"].y > isl.city_global(c, ty + 1.0).y)
			p = stage.player
			var iv: Vector3 = CC.inside(ty)
			p.global_position = isl.city_global(Vector2(iv.x, iv.z) + Vector2(3.0, 0), iv.y + 0.5)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		3:
			var ty: float = P.ground(CC.centre())
			var y0: float = isl.city_global(CC.centre(), ty + 0.8).y
			check("the captain stands on the nave's floor (%.2f over it)" % (p.global_position.y - y0), absf(p.global_position.y - y0) < 0.5)
			return TK.done(fails)
	step += 1
	return false
