extends SceneTree
## (1.30, playtest 2026-11-02 row 6) Nowhere in the capital to fall through: a ray down over every roof (the district's and
## the back houses' behind it, at the middle and the four corners) and every 2 m of every walkable floor hits something
## solid at or above it.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(900, 0, 900)
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


func _hit_y(q: Vector2, y: float) -> float:
	var a: Vector3 = isl.city_global(q, y + 4.0)
	var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3.DOWN * 10.0))
	return float(hit["position"].y) - (a.y - 4.0) if not hit.is_empty() else -INF


## The middle and the corners 0.7 m in, in frame coordinates (a lot's rect is its house's footprint).
func _spots(r: Rect2) -> Array:
	var g := r.grow(-0.7)
	return [r.get_center(), g.position, g.end, Vector2(g.position.x, g.end.y), Vector2(g.end.x, g.position.y)]


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
			var back: Array = P.lots().filter(func(l): return l.has("solid"))
			var holes: Array = []
			for l in back:
				for q in _spots(l["solid"][0]):
					if _hit_y(q, float(l["solid"][1])) < -0.4:
						holes.append(str((q as Vector2).round()))
			check("the back houses' roofs are solid (%d houses; holes %s)" % [back.size(), holes.slice(0, 6)], back.size() >= 100 and holes.is_empty())
			var tops: Array = load("res://scripts/island/capital_district.gd").lots().filter(func(l): return l.has("top_y"))
			holes = []
			for l in tops:
				var t: Transform3D = l["frame"]
				var wd: Vector2 = l["wd"]
				for f in _spots(Rect2(-wd * 0.5, wd)):
					if l.has("hatch") and (l["hatch"] as Rect2).grow(0.8).has_point(f):
						continue
					var v: Vector3 = t * Vector3(f.x, 0.0, f.y)
					if _hit_y(Vector2(v.x, v.z), float(l["top_y"])) < -0.4:
						holes.append(str(Vector2(v.x, v.z).round()))
			check("the district's roofs are solid at their middles and corners (%d; holes %s)" % [tops.size(), holes.slice(0, 6)], tops.size() >= 45 and holes.is_empty())
			holes = []
			var n := 0
			for f in P.floors():
				var r: Rect2 = f[1]
				var x := r.position.x + 1.0
				while x < r.end.x:
					var z := r.position.y + 1.0
					while z < r.end.y:
						var q := Vector2(x, z)
						n += 1
						if _hit_y(q, P.ground(q)) < -0.4:
							holes.append(str(q.round()))
						z += 2.0
					x += 2.0
			check("every walkable floor is solid every 2 m (%d spots; holes %s)" % [n, holes.slice(0, 6)], n > 1000 and holes.is_empty())
			return TK.done(fails)
	step += 1
	return false
