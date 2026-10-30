extends SceneTree
## The palace gardens (1.27, CapitalGardens): the maze's way in is open from the plateau, its outer hedge is solid, its
## heart is clear ground with the statue and chest, and the formal garden's fountain stands.
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


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var G = load("res://scripts/island/capital_gardens.gd")
	var P = load("res://scripts/island/capital_plan.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(4)
		2:
			var m: Rect2 = G.MAZE
			var y: float = P.ground(m.get_center()) + 1.2
			var last_z: float = m.end.y - G.CELL * 0.5
			check("the maze's way in is open (east side, last row)", _ray(isl.city_global(Vector2(m.end.x + 1.5, last_z), y), isl.city_global(Vector2(m.end.x - 1.0, last_z), y)).is_empty())
			check("its outer hedge is solid elsewhere", not _ray(isl.city_global(Vector2(m.end.x + 1.5, m.position.y + G.CELL * 0.5), y), isl.city_global(Vector2(m.end.x - 1.0, m.position.y + G.CELL * 0.5), y)).is_empty())
			var h: Vector3 = G.heart()
			var down := _ray(isl.city_global(Vector2(h.x, h.z) + Vector2(1.2, -1.0), h.y + 4.0), isl.city_global(Vector2(h.x, h.z) + Vector2(1.2, -1.0), h.y - 1.0))
			check("its heart is open ground by the statue", not down.is_empty() and absf(down["position"].y - isl.city_global(Vector2(h.x, h.z), h.y).y) < 0.5)
			var gc: Vector2 = G.GARDEN.get_center()
			var fountain := _ray(isl.city_global(gc, P.ground(gc) + 4.0), isl.city_global(gc, P.ground(gc) - 1.0))
			check("the formal garden's fountain stands", not fountain.is_empty() and fountain["position"].y > isl.city_global(gc, P.ground(gc) + 0.3).y)
			return TK.done(fails)
	step += 1
	return false
