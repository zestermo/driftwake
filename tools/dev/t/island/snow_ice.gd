extends SceneTree
## (1.30) The snow's frozen lakes and river walk clean: on three snow islands every face of the ice's collider faces up
## (a ray down from above stops on the ice, not the bed under it), and walking across the river at every station, out
## from each lake on eight bearings and along the river's length, the ground under a captain (the ice or the land,
## whichever is higher) never jumps: the banks rise through the ice, so there's no lip at the edge and no sheet over a drop.
const TK := preload("res://tools/dev/test_kit.gd")
const SEEDS := [4242, 77, 1301]
const STEP := 0.2
const JUMP := 0.35
var stage
var step := 0
var until := 0
var fails := 0
var k := 0
var gi
var SL


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _island(seed_v: int):
	var c = load("res://scripts/world/chain.gd").make(seed_v, Vector2.ZERO, Vector2(0, -1))
	var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
	n.merge({"theme": "snow", "beast": "snow_leopard", "beast_look": 0, "minis": ["frost_alpha"], "roamer": "rimeback"}, true)
	var g = load("res://scripts/island/gen_island.gd").new()
	g.position = Vector3(0, 0, -3000)
	stage.add_child(g)
	g.prepare(n)
	return g


## The ice's top at p (island space) by a ray down, or -INF.
func _ice_y(p: Vector2) -> float:
	var a: Vector3 = gi.to_global(Vector3(p.x, 400.0, p.y))
	var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3.DOWN * 800.0))
	return float(hit["position"].y) if not hit.is_empty() else -INF


## The worst jump in the walking surface along a -> b where the ice is underfoot on one side of it (the land's own
## steps - a place's levelled ground - are not the ice's), where, and the ice and ground either side of it.
func _walk(a: Vector2, b: Vector2) -> Array:
	var n := ceili(a.distance_to(b) / STEP)
	var prev := NAN
	var prev_ice := false
	var was := ""
	var worst := [0.0, a, ""]
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / n)
		var ice := _ice_y(p)
		var on_ice := ice >= float(gi.hv(p))
		var y := maxf(ice, float(gi.hv(p)))
		var now := "ice %.2f ground %.2f" % [ice, gi.hv(p)]
		if y > 0.3 and not is_nan(prev) and prev > 0.3 and (on_ice or prev_ice) and absf(y - prev) > worst[0]:
			worst = [absf(y - prev), p, "%s -> %s" % [was, now]]
		prev = y
		prev_ice = on_ice
		was = now
	return worst


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			load("res://scripts/island/island_theme.gd").meshes("snow")
			SL = load("res://scripts/island/themes/snow_land.gd")
			gi = _island(SEEDS[k])
			SL._ice(gi)
			until = TK.wait_ticks(3)
		1:
			var sv: int = SEEDS[k]
			var body: StaticBody3D = gi.get_node("SnowIce")
			var faces: PackedVector3Array = (body.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D).shape.get_faces()
			var down := 0
			for i in range(0, faces.size(), 3):
				if (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).y >= 0.0:
					down += 1
			check("[%d] every face of the ice's collider faces up (%d of %d down)" % [sv, down, faces.size() / 3], down == 0 and faces.size() > 0)
			var lp: Dictionary = gi.land_plan
			var strip: Array = SL._river_strip(gi, lp)
			var hw: float = float(lp["river_w"]) * 0.5
			var laid := 0
			var held := 0
			var miss := ""
			var worst := [0.0, Vector2.ZERO, ""]
			for i in range(strip.size()):
				var e: Array = strip[i]
				if not e[3]:
					continue
				var p: Vector2 = e[0]
				# (a run's end station is on the ice's edge: a ray there can slip past it)
				var inner: bool = i > 0 and i < strip.size() - 1 and strip[i - 1][3] and strip[i + 1][3]
				laid += 1 if inner else 0
				if not inner:
					pass
				elif absf(_ice_y(p) - float(e[2])) < 0.05:
					held += 1
				elif miss == "":
					miss = " (missed at %s: ice %.2f, laid at %.2f)" % [p, _ice_y(p), e[2]]
				var side: Vector2 = (e[1] as Vector2).normalized()
				var wk := _walk(p - side * (hw + 9.0), p + side * (hw + 9.0))
				if wk[0] > worst[0]:
					worst = wk
			check("[%d] a ray down onto the river stops on its ice (%d of %d stations)%s" % [sv, held, laid, miss], laid > 10 and held == laid)
			check("[%d] walking across the river at every station, the ground never jumps (worst %.2f m at %s: %s)" % [sv, worst[0], worst[1], worst[2]], worst[0] < JUMP)
			var along := [0.0, Vector2.ZERO, ""]
			for j in range(strip.size() - 1):
				var wk := _walk(strip[j][0], strip[j + 1][0])
				if wk[0] > along[0]:
					along = wk
			check("[%d] ...nor walking down the river's length (worst %.2f m at %s: %s)" % [sv, along[0], along[1], along[2]], along[0] < JUMP)
			var lakes := 0
			var lw := [0.0, Vector2.ZERO, ""]
			for lk in lp["lakes"]:
				var c: Vector2 = lk["c"]
				if absf(_ice_y(c) - float(lk["level"])) > 0.05:
					continue
				lakes += 1
				for b in range(8):
					var wk := _walk(c, c + Vector2.from_angle(b * TAU / 8.0) * (float(lk["r"]) + 12.0))
					if wk[0] > lw[0]:
						lw = wk
			check("[%d] walking off each frozen lake (%d iced of %d), the ground never jumps (worst %.2f m at %s: %s)" % [sv, lakes, (lp["lakes"] as Array).size(), lw[0], lw[1], lw[2]],
				lw[0] < JUMP)
			gi.queue_free()
			k += 1
			if k < SEEDS.size():
				step = 0
				until = TK.wait_ticks(2)
				return false
			return TK.done(fails)
	step += 1
	return false
