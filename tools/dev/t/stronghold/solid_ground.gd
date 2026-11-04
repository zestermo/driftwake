extends SceneTree
## (1.30, playtest 2026-11-02 row 6) Nowhere in the fortress to fall through: a ray down every 1.5 m over every district's
## cobbles (out to 0.3 m from their edges) and over the stair, the ramps and the bridge hits something solid at or above
## the designed ground, never the terrain sagging under it.
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
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			# (long enough for the garrison's bodies to finish building: quitting mid-prebuild hangs the exit, docs/todo.md)
			until = TK.wait_secs(8.0)
		2:
			var holes: Array = []
			var n := 0
			for d in P.DISTRICTS:
				var r: Rect2 = (d[1] as Rect2).grow(-0.3)
				var x := r.position.x
				while x <= r.end.x + 0.01:
					var z := r.position.y
					while z <= r.end.y + 0.01:
						var q := Vector2(x, z)
						var want: float = P.ground(q)
						n += 1
						if _floor_at(q, want) < want - 0.4:
							holes.append("%s %s %.1f" % [d[0], q.round(), _floor_at(q, want) - want])
						z = minf(z + 1.5, r.end.y) if z < r.end.y else z + 1.0
					x = minf(x + 1.5, r.end.x) if x < r.end.x else x + 1.0
			check("every district's cobbles solid every 1.5 m to their edges (%d spots; holes %s)" % [n, holes.slice(0, 6)], n > 3000 and holes.is_empty())
			holes = []
			for wy in P.WAYS:
				var a: Vector2 = wy[1]
				var b: Vector2 = wy[2]
				var hw: float = wy[3]
				var side := (b - a).normalized().orthogonal()
				var steps := ceili(a.distance_to(b) / 1.0)
				for i in range(steps + 1):
					for s in [-1.0, 0.0, 1.0]:
						var q: Vector2 = a.lerp(b, float(i) / steps) + side * s * (hw - 0.3)
						var want: float = P.ground(q)
						if _floor_at(q, want) < want - 0.4:
							holes.append("%s %s" % [wy[0], q.round()])
			check("the stair, the ramps and the bridge solid along and across (holes %s)" % [holes.slice(0, 6)], holes.is_empty())
			return TK.done(fails)
	step += 1
	return false
