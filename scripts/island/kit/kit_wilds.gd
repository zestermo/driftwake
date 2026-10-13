class_name KitWilds
extends RefCounted
## More of a generated island's landmarks (KitLandmarks.KINDS rolls from them
## all): an overgrown stone watchtower you climb inside floor by floor, a
## crashed sky-ship under its fallen envelope, a grove of carved totems round a
## fire pit, a hermit's hut, an abandoned mine in a rock face, a broken aqueduct
## striding over the jungle, a gorge cut across the land with a rope bridge.
## Planned on the worker (`plan`), built a step a frame (`steps`), through
## KitLandmarks' helpers; each place's data goes to Island.places.

static func plan(isl: GenIsland, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var pl: Dictionary
	match kind:
		"watchtower":
			pl = _spot(isl, rng, avoid, 12.0, 0.3, 5.0, 6.0, true)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 5.0, 9.0)
				pl["h"] = maxf(16.0, KitLandmarks.canopy(isl.theme) * 1.15)
				pl["keep"] = [[Vector2.ZERO, 5.0]]
		"sky_wreck":
			pl = _spot(isl, rng, avoid, 16.0, 0.25, 3.0, 8.0, false)
			if not pl.is_empty():
				pl["keep"] = [[Vector2.ZERO, 6.5]]
				pl["hang"] = maxf(11.0, KitLandmarks.canopy(isl.theme) * 0.85)
		"totem_grove":
			pl = _spot(isl, rng, avoid, 13.0, 0.2, 3.0, 8.0, false)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 8.0, 12.0)
				pl["keep"] = [[Vector2.ZERO, 8.5]]
		"hermit_hut":
			pl = _spot(isl, rng, avoid, 12.0, 0.25, 3.0, 8.0, false)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 6.0, 10.0)
				pl["keep"] = [[Vector2.ZERO, 5.5], [Vector2(4.5, 3.0), 3.0]]
		"mine":
			pl = _plan_mine(isl, rng, avoid)
		"aqueduct":
			pl = _plan_aqueduct(isl, rng, avoid)
		"gorge_bridge":
			pl = _plan_gorge(isl, rng, avoid)
	if pl.is_empty():
		return {}
	pl["kind"] = kind
	pl["role"] = "landmark"
	pl["seed"] = rng.randi()
	return pl


## An inland spot of radius r, flattest (or highest, `high`), off the paths, facing the nearest one.
static func _spot(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array, r: float, max_s: float, min_h: float, path_gap: float, high: bool) -> Dictionary:
	var best := {}
	var best_s := -INF
	for k in range(50):
		var p := KitLandmarks.rand_inland(isl, rng, 0.15, 0.75)
		var h := isl.hv(p)
		var s := KitLandmarks.grad(isl, p, r * 0.6).length()
		if h < min_h or s > max_s or not KitLandmarks.clear_of(p, r, avoid) or isl.path_dist(p) < path_gap:
			continue
		var score := h if high else -s
		if score > best_s:
			best_s = score
			best = {"at": p, "y": h}
	if best.is_empty():
		return {}
	var p: Vector2 = best["at"]
	var face := (KitSetPieces._nearest_path(isl, p) - p).normalized()
	best.merge({"face": face, "r": r, "door": p + face * (r * 0.8)})
	return best


static func steps(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> Array:
	match str(pl["kind"]):
		"watchtower":
			return [func(): _watchtower(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _watchtower_floors(isl, ctx, pl)]
		"sky_wreck":
			return [func(): _sky_wreck(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"totem_grove":
			return [func(): _totems(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"hermit_hut":
			return [func(): _hermit(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"mine":
			return [func(): _mine(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _mine_dressing(isl, ctx, pl)]
		"aqueduct":
			return [func(): _aqueduct(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"gorge_bridge":
			return [func(): _gorge(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _gorge_bridge(isl, ctx, pl)]
	push_error("KitWilds: no landmark %s" % pl["kind"])
	return []


static func _stone(ctx: KitContext) -> Array:
	return [PSXMat.lit("stone_brick", ctx.style["temple_stone"], {"affine": 0.6}), PSXMat.lit("stone_brick", ctx.style["moss_tint"], {"affine": 0.6})]


# ==========================================================================
# The overgrown watchtower: a round stone tower, floors inside, ladders up
# ==========================================================================
const TOWER_R := 3.3
const TOWER_IN := 2.7
## A half floor reaches past the middle by this much; its ladder hangs off that edge.
const FLOOR_EDGE := 1.3


## The heights of its floors (the last is the open top).
static func tower_floors(pl: Dictionary) -> Array:
	var h: float = pl["h"]
	var n := maxi(int(h / 5.2), 2)
	var out: Array = []
	for k in range(1, n + 1):
		out.append(h * k / n)
	return out


static func _watchtower(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var mats := _stone(ctx)
	var inner := PSXMat.lit("stone_brick", (ctx.style["temple_stone"] as Color).darkened(0.35), {"affine": 0.6})
	var vine_m := PSXMat.lit("leaves", Color(0.5, 0.72, 0.38))
	var h: float = pl["h"]
	var mb := MeshBuilder.new()
	var n := 20
	var door := PI * 0.5
	for i in range(n):
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var am := (a0 + a1) * 0.5
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var top := h + 1.2
		if i % 7 == 3:
			top = h - rng.randf_range(0.6, 2.4)
		var bottom := 2.6 if absf(angle_difference(am, door)) < 0.3 else -1.0
		var m: Material = mats[1] if rng.randf() < 0.35 else mats[0]
		var y := bottom
		while y < top - 0.01:
			var y1 := minf(y + 2.6, top)
			var shade := rng.randf_range(0.82, 1.0)
			mb.add_quad(m, d0 * TOWER_R + Vector3(0, y, 0), d1 * TOWER_R + Vector3(0, y, 0), d1 * TOWER_R + Vector3(0, y1, 0), d0 * TOWER_R + Vector3(0, y1, 0),
				Vector2(a0 * TOWER_R, -y) * 0.4, Vector2(a1 * TOWER_R, -y) * 0.4, Vector2(a1 * TOWER_R, -y1) * 0.4, Vector2(a0 * TOWER_R, -y1) * 0.4, Color(shade, shade, shade), (d0 + d1).normalized())
			mb.add_quad(inner, d1 * TOWER_IN + Vector3(0, y, 0), d0 * TOWER_IN + Vector3(0, y, 0), d0 * TOWER_IN + Vector3(0, y1, 0), d1 * TOWER_IN + Vector3(0, y1, 0),
				Vector2(a1 * TOWER_IN, -y) * 0.4, Vector2(a0 * TOWER_IN, -y) * 0.4, Vector2(a0 * TOWER_IN, -y1) * 0.4, Vector2(a1 * TOWER_IN, -y1) * 0.4, Color(0.7, 0.7, 0.7), -(d0 + d1).normalized())
			y = y1
		mb.add_quad(mats[0], d0 * TOWER_IN + Vector3(0, top, 0), d1 * TOWER_IN + Vector3(0, top, 0), d1 * TOWER_R + Vector3(0, top, 0), d0 * TOWER_R + Vector3(0, top, 0),
			Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 0.3), Vector2(0, 0.3), Color(0.9, 0.9, 0.9), Vector3.UP)
		if bottom > 0.0:
			mb.add_quad(inner, d0 * TOWER_IN + Vector3(0, bottom, 0), d1 * TOWER_IN + Vector3(0, bottom, 0), d1 * TOWER_R + Vector3(0, bottom, 0), d0 * TOWER_R + Vector3(0, bottom, 0),
				Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 0.3), Vector2(0, 0.3), Color(0.6, 0.6, 0.6), Vector3.DOWN)
		else:
			for e in [[a0, d0], [a1, d1]]:
				var ea: float = e[0]
				if absf(angle_difference(ea, door)) < 0.35 and absf(angle_difference(am, door)) < 0.6:
					var ed: Vector3 = e[1]
					var side := Vector3(-ed.z, 0, ed.x) * signf(angle_difference(door, ea))
					mb.add_quad(inner, ed * TOWER_IN + Vector3(0, 0, 0), ed * TOWER_R, ed * TOWER_R + Vector3(0, 2.6, 0), ed * TOWER_IN + Vector3(0, 2.6, 0),
						Vector2(0, 0), Vector2(0.3, 0), Vector2(0.3, 1.0), Vector2(0, 1.0), Color(0.7, 0.7, 0.7), side)
		if i % 2 == 0 and top > h:
			var mc := (d0 + d1).normalized() * (TOWER_R + TOWER_IN) * 0.5
			mb.add_box(mats[0], Transform3D(Basis(Vector3.UP, -am), mc + Vector3(0, top + 0.4, 0)), Vector3(0.6, 0.8, 0.95), 0.4, Color(0.9, 0.9, 0.9))
		if rng.randf() < 0.55:
			KitLandmarks.vine(mb, vine_m, (d0 + d1).normalized() * (TOWER_R + 0.12) + Vector3(0, top - 0.1, 0), rng.randf_range(2.5, minf(9.0, top)), (d0 + d1).normalized(), rng)
	var bark := PSXMat.lit("bark")
	for k in range(5):
		var a := rng.randf() * TAU
		var d := Vector3(cos(a), 0, sin(a))
		var r0 := d * TOWER_R + Vector3(0, rng.randf_range(1.0, 3.0), 0)
		var r1 := d * (TOWER_R + rng.randf_range(2.0, 4.0))
		r1.y = KitLandmarks.gy(ctx, pl, r1.x, r1.z) - 0.2
		mb.add_tube(bark, MeshBuilder.curve_points(r0, r0 + d * 0.8 + Vector3(0, -0.4, 0), r1, 5), 0.16, 0.07, 5, 0.8)
	var b := KitLandmarks.body("Watchtower")
	var mesh := mb.commit()
	var mi := MeshInstance3D.new()
	mi.name = "TowerMesh"
	mi.mesh = mesh
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	b.add_child(cs)
	node.add_child(b)


## A half floor on joists across the tower at y, covering x * s > -FLOOR_EDGE (its planks kept inside the wall).
static func _half_floor(mb: MeshBuilder, b: StaticBody3D, planks: Material, beam_m: Material, y: float, s: float, hole := false) -> void:
	var bands: Array = [[-FLOOR_EDGE, 0.8, 2.55], [0.8, 1.9, 2.0], [1.9, 2.65, 1.3]]
	if hole:
		bands = [[-2.65, -1.9, 1.3], [-1.9, -0.8, 2.0], [-0.8, 0.8, 2.55], [0.8, 1.9, 2.0], [1.9, 2.65, 1.3]]
	for e in bands:
		var x0: float = e[0]
		var x1: float = e[1]
		var hz: float = e[2]
		var parts: Array = [[-hz, hz]]
		if hole and x0 < 0.0 and x1 > 0.0:
			parts = [[-hz, -0.8], [0.8, hz]]
		for z in parts:
			var cz := (float(z[0]) + float(z[1])) * 0.5
			var c := Vector3((x0 + x1) * 0.5 * s, y - 0.09, cz)
			var size := Vector3(x1 - x0, 0.18, float(z[1]) - float(z[0]))
			mb.add_box(planks, Transform3D(Basis(), c), size, 0.5, Color.WHITE, false)
			KitLandmarks.box_col(b, size, c)
	for z in [-1.6, 0.0, 1.6]:
		KitLandmarks.beam(mb, beam_m, Vector3(-TOWER_IN, y - 0.3, z), Vector3(TOWER_IN, y - 0.3, z), 0.18)


static func _watchtower_floors(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> void:
	var node := KitLandmarks.node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var planks := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.6})
	var beam_m := PSXMat.lit("planks_dark")
	var b := KitLandmarks.body("TowerFloors")
	var mb := MeshBuilder.new()
	var floors := tower_floors(pl)
	var below := 0.0
	for k in range(floors.size()):
		var y: float = floors[k]
		var s := 1.0 if k % 2 == 0 else -1.0
		var top := k == floors.size() - 1
		_half_floor(mb, b, planks, beam_m, y, s, top)
		var lad := Ladder.new()
		lad.length = y - below + 0.05
		lad.rail = 0.0
		lad.deck_depth = 1.0
		if top:
			var ps := -1.0 if k % 2 == 1 else 1.0
			lad.position = Vector3(0.8 * ps, y + 0.08, 0)
			lad.rotation.y = atan2(-ps, 0.0)
		else:
			lad.position = Vector3(-FLOOR_EDGE * s, y + 0.08, 0)
			lad.rotation.y = atan2(-s, 0.0)
		b.add_child(lad)
		below = y
	var mats := _stone(ctx)
	mb.add_cylinder(mats[0], Transform3D(Basis(), Vector3(0, -0.3, 0)), TOWER_IN, TOWER_IN, 0.35, 12, 0.4, Color(0.8, 0.8, 0.8))
	b.add_child(KitLandmarks.far_off(mb.to_instance("FloorsMesh")))
	node.add_child(b)
	var h: float = pl["h"]
	var bowl := MeshBuilder.new()
	var flame := PSXMat.glow(Color(1.0, 0.55, 0.15), 2.4)
	var bp := Vector3(1.6, h, -1.4)
	bowl.add_loft(PSXMat.lit("metal", Color(0.45, 0.4, 0.35)), Transform3D(Basis(), bp), [[0.0, 0.15, 0.15], [0.5, 0.2, 0.2], [0.75, 0.5, 0.5], [0.9, 0.55, 0.55]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, true, false)
	for j in range(3):
		bowl.add_card(flame, Transform3D(Basis(Vector3.UP, j * PI / 3.0), bp + Vector3(0, 0.95, 0)), 0.6, 0.7)
	var brazier := bowl.to_instance("Brazier")
	node.add_child(brazier)
	KitLandmarks.puffs(node, bp + Vector3(0, 1.4, 0), Color(0.4, 0.38, 0.36, 0.35), 6, 0.9, 0.5, 0.2)
	KitLights.light(ctx, brazier, bp + Vector3(0, 1.3, 0), 1.4, 12.0)
	KitLandmarks.chest(ctx, pl, Vector3(-1.5, h + 0.05, 1.2), PI * 0.5, "watch_chest", KitLandmarks.loot(isl, rng, true), 0.85)


# ==========================================================================
# The crashed sky-ship: a gondola nosed into the ground, its envelope draped
# over the trees it brought down
# ==========================================================================
static func _sky_wreck(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var hull_c: Color = ctx.style["wreck_hull"]
	var planks := PSXMat.lit("planks_dark", hull_c.lightened(0.1), {"affine": 0.6})
	var trim := PSXMat.lit("planks", Color(0.75, 0.55, 0.3))
	var brass := PSXMat.lit("metal", Color(0.85, 0.65, 0.3))
	var stripe_a := PSXMat.lit("canvas", Color(0.9, 0.86, 0.74), {"affine": 0.6})
	var stripe_b := PSXMat.lit("cloth_red", Color(0.95, 0.85, 0.8), {"affine": 0.6})
	var rope := PSXMat.lit("rope")
	var bark := PSXMat.lit("bark", Color(0.8, 0.75, 0.7))
	var hang: float = pl["hang"]
	var gxf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)) * Basis(Vector3.RIGHT, -0.38) * Basis(Vector3.BACK, rng.randf_range(-0.15, 0.15)), Vector3(0, 1.1, 0))
	var g := MeshBuilder.new()
	g.add_loft(planks, gxf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), [[-4.6, 0.1, 0.1], [-3.6, 1.0, 0.8], [-1.5, 1.5, 1.1], [1.5, 1.5, 1.1], [3.8, 1.2, 0.9], [4.4, 0.6, 0.5]],
		MeshBuilder.profile_mirror(PackedVector2Array([Vector2(0, -1), Vector2(0.75, -0.75), Vector2(1, 0), Vector2(0.9, 0.6), Vector2(0, 0.62)])), 0.5, Color.WHITE, false, true, true, true)
	g.add_box(planks, gxf * Transform3D(Basis(), Vector3(0, 0.75, 0.8)), Vector3(2.4, 0.12, 5.6), 0.5, Color(0.9, 0.9, 0.9))
	g.add_box(trim, gxf * Transform3D(Basis(), Vector3(0, 1.75, 1.6)), Vector3(2.0, 2.0, 2.4), 0.5)
	g.add_gable_roof(trim, gxf * Transform3D(Basis(), Vector3(0, 2.75, 1.6)), 2.0, 2.4, 0.6, 0.15, 0.6)
	g.add_box(PSXMat.lit("window", Color.WHITE, {"vertex_color": false}), gxf * Transform3D(Basis(), Vector3(1.01, 1.9, 1.6)), Vector3(0.04, 0.6, 0.8), 1.0)
	for s in [-1.0, 1.0]:
		KitLandmarks.beam(g, trim, gxf * Vector3(s * 1.35, 1.3, -2.5), gxf * Vector3(s * 1.35, 1.3, 3.8), 0.09)
		for z in [-2.0, -0.5, 1.0, 2.5]:
			KitLandmarks.beam(g, trim, gxf * Vector3(s * 1.35, 0.75, z), gxf * Vector3(s * 1.35, 1.3, z), 0.07)
	var hub := gxf * Vector3(0, 0.6, 4.6)
	g.add_cylinder(brass, gxf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.6, 4.2)), 0.12, 0.12, 0.6, 6, 1.0)
	for k in range(4):
		var ba := Basis(gxf.basis.z, k * PI * 0.5 + 0.3)
		var blade := ba * (gxf.basis.y * (0.8 if k == 2 else 1.6))
		KitLandmarks.beam(g, trim, hub, hub + blade, 0.12)
	var gb := KitLandmarks.body("SkyGondola")
	var gm := g.commit()
	var gmi := MeshInstance3D.new()
	gmi.mesh = gm
	gmi.name = "GondolaMesh"
	gb.add_child(gmi)
	var gcs := CollisionShape3D.new()
	gcs.shape = gm.create_trimesh_shape()
	gb.add_child(gcs)
	node.add_child(gb)
	var tp := Vector3(rng.randf_range(-2.0, 2.0), 0, -11.0)
	tp.y = KitLandmarks.gy(ctx, pl, tp.x, tp.z) - 0.5
	var e := MeshBuilder.new()
	e.add_cylinder(bark, Transform3D(Basis(), tp), 0.7, 0.45, hang + 0.5, 7, 0.5)
	for k in range(4):
		var a := TAU * k / 4.0 + rng.randf()
		e.add_cone(bark, Transform3D(Basis(), tp + Vector3(cos(a) * 0.3, hang + 0.45, sin(a) * 0.3)), 0.22, rng.randf_range(0.6, 1.4), 4, 0.8)
	var cols := 9
	var rows := 7
	var grid: Array = []
	for j in range(rows):
		var row: Array = []
		var tz := float(j) / (rows - 1)
		for i in range(cols):
			var tx := float(i) / (cols - 1) * 2.0 - 1.0
			var x := tx * lerpf(7.0, 9.0, tz)
			var z := lerpf(-12.5, 6.5, tz)
			var ground := KitLandmarks.gy(ctx, pl, x, z)
			var drape := lerpf(hang + 0.8, 0.0, pow(tz, 0.8)) * (1.0 - 0.75 * tx * tx)
			var y := maxf(ground + 0.15, ground + drape + 0.6 * sin(i * 1.7 + j * 2.3))
			if tz > 0.55 and absf(x) < 3.0:
				y = maxf(y, (gxf * Vector3(x * 0.4, 3.2, z - 1.0)).y)
			row.append(Vector3(x, y, z))
		grid.append(row)
	for j in range(rows - 1):
		for i in range(cols - 1):
			if (i + j * 3) % 11 == 5:
				continue
			var m: Material = stripe_a if i % 2 == 0 else stripe_b
			var a: Vector3 = grid[j][i]
			var b2: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			var nrm := (b2 - a).cross(d - a).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			e.add_quad(m, a, b2, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, nrm)
			e.add_quad(m, a, d, c, b2, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color(0.6, 0.6, 0.6), -nrm)
	for i in [1, 4, 7]:
		var pts := PackedVector3Array()
		for j in range(rows):
			pts.append((grid[j][i] as Vector3) + Vector3(0, 0.12, 0))
		e.add_tube(brass, pts, 0.05, 0.05, 4, 1.0)
	for k in range(6):
		var top: Vector3 = grid[rows - 2 - k % 2][1 + k]
		var low := gxf * Vector3((k % 2) * 2.0 - 1.0, 1.3, -1.5 + k * 0.8)
		e.add_tube(rope, MeshBuilder.sag_points(top, low, 0.4, 5), 0.03, 0.03, 4, 1.0)
	var sack := PSXMat.lit("canvas", Color(0.7, 0.62, 0.48))
	for k in range(7):
		var q := Vector3(rng.randf_range(-6.0, 6.0), 0, rng.randf_range(-3.0, 7.0))
		q.y = KitLandmarks.gy(ctx, pl, q.x, q.z) + 0.15
		e.add_blob(sack, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q), Vector3(0.35, 0.22, 0.25), rng, 0.1, 3, 6, 1.0)
	var envelope := e.to_instance("Envelope")
	node.add_child(envelope)
	var tb := KitLandmarks.body("SnappedTree")
	KitLandmarks.cyl_col(tb, 0.7, hang, tp + Vector3(0, hang * 0.5, 0))
	node.add_child(tb)
	KitLandmarks.chest(ctx, pl, gxf * Vector3(0, 0.85, 1.6), float(rng.randf_range(-0.3, 0.3)), "sky_chest", KitLandmarks.loot(isl, rng, true), 0.85)


# ==========================================================================
# The totem grove: carved poles in a ring round a fire pit and an altar
# ==========================================================================
static func _totem(mb: MeshBuilder, wood: Material, paint: Array, dark: Material, at: Vector3, face: float, h: float, rng: RandomNumberGenerator) -> void:
	var xf := Transform3D(Basis(Vector3.UP, face) * Basis(Vector3.BACK, rng.randf_range(-0.06, 0.06)), at)
	mb.add_cylinder(wood, xf * Transform3D(Basis(), Vector3(0, -0.8, 0)), 0.42, 0.36, h + 0.8, 8, 0.6)
	var y := 0.6
	var k := 0
	while y < h - 1.0:
		var fh := rng.randf_range(0.9, 1.3)
		var c := y + fh * 0.5
		mb.add_box(wood, xf * Transform3D(Basis(), Vector3(0, c, 0.22)), Vector3(0.95, fh, 0.42), 0.8, Color(0.9, 0.9, 0.9))
		var p: Material = paint[(k + rng.randi()) % paint.size()]
		mb.add_box(p, xf * Transform3D(Basis(), Vector3(0, c + fh * 0.25, 0.45)), Vector3(0.8, 0.12, 0.04), 1.0)
		for s in [-1.0, 1.0]:
			mb.add_box(dark, xf * Transform3D(Basis(), Vector3(s * 0.22, c + fh * 0.08, 0.44)), Vector3(0.2, 0.14, 0.04), 1.0)
		mb.add_box(dark, xf * Transform3D(Basis(), Vector3(0, c - fh * 0.28, 0.44)), Vector3(0.45, 0.1 + 0.08 * (k % 2), 0.04), 1.0)
		mb.add_extrude(wood, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, c - 0.05, 0.47)), PackedVector2Array([Vector2(0, 0), Vector2(0.28, 0), Vector2(0, 0.32)]), 0.16, 1.0)
		y += fh + 0.12
		k += 1
	if rng.randf() < 0.6:
		for s in [-1.0, 1.0]:
			mb.add_extrude(paint[0] if s > 0 else paint[1 % paint.size()], xf * Transform3D(Basis(Vector3.FORWARD, s * 0.25), Vector3(s * 0.9, h - 0.6, 0.1)),
				PackedVector2Array([Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0.4 * s + 0.3, 0.7), Vector2(-0.2, 0.35)]), 0.12, 1.0)
	mb.add_box(wood, xf * Transform3D(Basis(), Vector3(0, h - 0.3, 0.1)), Vector3(0.7, 0.6, 0.7), 0.8)


static func _totems(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var wood := PSXMat.lit("planks_dark", Color(0.82, 0.68, 0.55))
	var dark := PSXMat.flat(Color(0.1, 0.09, 0.08))
	var paint := [PSXMat.flat(Color(0.75, 0.22, 0.16)), PSXMat.flat(Color(0.95, 0.85, 0.35)), PSXMat.flat(Color(0.2, 0.45, 0.6))]
	var mats := KitLandmarks.rock_mats(ctx)
	var bone := PSXMat.lit("plaster", ctx.style["bone"])
	var rope := PSXMat.lit("rope")
	var b := KitLandmarks.body("Totems")
	var mb := MeshBuilder.new()
	var n := rng.randi_range(7, 9)
	var tops: Array = []
	for k in range(n):
		var a := TAU * k / n + rng.randf_range(-0.12, 0.12)
		if absf(angle_difference(a, PI * 0.5)) < 0.3:
			continue
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(6.0, 7.0)
		p.y = KitLandmarks.gy(ctx, pl, p.x, p.z)
		var h := rng.randf_range(3.6, 6.2)
		_totem(mb, wood, paint, dark, p, atan2(-p.x, -p.z), h, rng)
		KitLandmarks.cyl_col(b, 0.45, h, p + Vector3(0, h * 0.5, 0))
		tops.append(p + Vector3(0, h - 0.5, 0))
	var feather := PSXMat.lit("canvas", Color(0.5, 0.4, 0.3))
	for k in range(tops.size()):
		var a: Vector3 = tops[k]
		var c: Vector3 = tops[(k + 1) % tops.size()]
		var pts := MeshBuilder.sag_points(a, c, 1.1, 8)
		mb.add_tube(rope, pts, 0.025, 0.025, 3, 1.0)
		for j in range(2, 7, 2):
			var q: Vector3 = pts[j]
			mb.add_tube(rope, PackedVector3Array([q, q + Vector3(0, -0.5, 0)]), 0.015, 0.015, 3, 1.0)
			if j % 4 == 0:
				mb.add_blob(bone, Transform3D(Basis(), q + Vector3(0, -0.62, 0)), Vector3(0.11, 0.1, 0.13), rng, 0.05, 3, 5, 1.0)
			else:
				mb.add_card(feather, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q + Vector3(0, -0.95, 0)), 0.14, 0.45)
	for k in range(9):
		var a := TAU * k / 9.0
		mb.add_blob(mats[0], Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 1.15, KitLandmarks.gy(ctx, pl, 0, 0) + 0.12, sin(a) * 1.15)), Vector3(0.32, 0.22, 0.28), rng, 0.15, 3, 6, 0.8)
	var embers := PSXMat.glow(Color(1.0, 0.4, 0.1), 2.0)
	var flame := PSXMat.glow(Color(1.0, 0.65, 0.2), 2.6)
	var cy := KitLandmarks.gy(ctx, pl, 0, 0)
	mb.add_blob(embers, Transform3D(Basis(), Vector3(0, cy + 0.05, 0)), Vector3(0.8, 0.15, 0.8), rng, 0.2, 2, 7, 1.0)
	for j in range(3):
		mb.add_card(flame, Transform3D(Basis(Vector3.UP, j * PI / 3.0), Vector3(0, cy + 0.1, 0)), 0.9, 1.1)
	var ap := Vector3(0, KitLandmarks.gy(ctx, pl, 0, -4.2), -4.2)
	mb.add_box(mats[0], Transform3D(Basis(), ap + Vector3(0, 0.45, 0)), Vector3(2.4, 0.9, 1.2), 0.5)
	mb.add_box(mats[1], Transform3D(Basis(), ap + Vector3(0, 0.98, 0)), Vector3(2.7, 0.16, 1.45), 0.5)
	KitLandmarks.box_col(b, Vector3(2.6, 1.0, 1.4), ap + Vector3(0, 0.5, 0))
	for k in range(3):
		mb.add_blob(bone, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)), ap + Vector3(-0.8 + k * 0.8, 1.2, 0.2)), Vector3(0.14, 0.13, 0.16), rng, 0.05, 3, 6, 1.0)
	for s in [-1.0, 1.0]:
		var sp := Vector3(s * 1.6, 0, 7.4)
		sp.y = KitLandmarks.gy(ctx, pl, sp.x, sp.z)
		KitLandmarks.beam(mb, wood, sp + Vector3(0, -0.3, 0), sp + Vector3(0, 2.1, 0), 0.08)
		mb.add_blob(bone, Transform3D(Basis(), sp + Vector3(0, 2.25, 0)), Vector3(0.17, 0.16, 0.19), rng, 0.05, 3, 6, 1.0)
	b.add_child(mb.to_instance("TotemMesh"))
	node.add_child(b)
	KitLandmarks.puffs(node, Vector3(0, cy + 0.8, 0), Color(0.45, 0.42, 0.4, 0.4), 8, 1.2, 0.6, 0.4)
	KitLandmarks.loop_sound(node, "campfire_loop.wav", Vector3(0, cy + 0.4, 0), 4.0, 28.0, -6.0)
	KitLights.light(ctx, node, Vector3(0, cy + 1.0, 0), 1.6, 12.0)
	KitLandmarks.chest(ctx, pl, ap + Vector3(0, 0.0, -1.1), PI, "totem_offering", KitLandmarks.loot(isl, rng, true), 0.9)


# ==========================================================================
# The hermit's hut: a stilt shack with all a castaway's makeshifts round it
# ==========================================================================
static func _hermit(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var c := ctx.under(node)
	var at: Vector2 = pl["at"]
	var fwd := KitLandmarks.lp(pl, 0, 1) - at
	var side := KitLandmarks.lp(pl, 1, 0) - at
	var hut := c.house({"w": 4.4, "d": 3.8, "h": 2.3, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch", "porch": 1.3,
		"flowers": false, "trim": Color(0.4, 0.36, 0.3), "lean_to": "left", "lamp_light": true, "seed": int(pl["seed"]) % 1000, "name": "HermitHut"}, at, fwd, true, false)
	var mark := Marker3D.new()
	mark.name = "Hermit"
	hut.add_child(mark)
	mark.position = Vector3(1.2, 0.0, 3.2)
	c.place(Props.fish_rack(), at + side * 4.8 + fwd * 2.5, KitContext.face_yaw(-side))
	KitCamps.campfire(c, at + fwd * 5.0 - side * 1.5, 1.2)
	KitVillage.garden(c, at - side * 4.5 + fwd * 1.0, 3.2, 2.4, KitContext.face_yaw(fwd), rng)
	c.place(Props.barrel(), at + side * 2.6 - fwd * 1.2)
	c.place(Props.rowboat(), at - fwd * 4.5 + side * 3.0, KitContext.face_yaw(side) + 0.3, 0.0, -0.1)
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("bark")
	var logs := PSXMat.lit("bark", Color(0.8, 0.72, 0.6))
	for k in range(7):
		var lq := Vector3(2.9, 0.18 + (k / 3) * 0.3, -0.6 + (k % 3) * 0.35 - 1.5)
		mb.add_cylinder(logs, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(lq.x, lq.y + KitLandmarks.gy(ctx, pl, lq.x, lq.z), lq.z - 0.7)), 0.16, 0.16, 1.4, 6, 1.0, Color.WHITE, true, true)
	var h0 := Vector3(-3.4, 0, 3.6)
	var h1 := Vector3(-0.4, 0, 5.4)
	for q in [h0, h1]:
		var qy := KitLandmarks.gy(ctx, pl, q.x, q.z)
		mb.add_cylinder(wood, Transform3D(Basis(), Vector3(q.x, qy - 0.4, q.z)), 0.11, 0.09, 2.2, 6, 1.0)
	var ha := h0 + Vector3(0, KitLandmarks.gy(ctx, pl, h0.x, h0.z) + 1.5, 0)
	var hb := h1 + Vector3(0, KitLandmarks.gy(ctx, pl, h1.x, h1.z) + 1.5, 0)
	mb.add_tube(PSXMat.lit("canvas", Color(0.6, 0.66, 0.5)), MeshBuilder.sag_points(ha, hb, 0.6, 6), 0.22, 0.22, 5, 1.0)
	var shell := PSXMat.lit("plaster", Color(0.95, 0.88, 0.8))
	var rope := PSXMat.lit("rope")
	var cb := Vector3(2.2, KitLandmarks.gy(ctx, pl, 2.2, 2.6) + 2.4, 2.6)
	for k in range(5):
		var q := cb + Vector3(-0.4 + k * 0.2, 0, 0)
		mb.add_tube(rope, PackedVector3Array([q, q + Vector3(0, -0.5 - 0.1 * (k % 2), 0)]), 0.012, 0.012, 3, 1.0)
		mb.add_blob(shell, Transform3D(Basis(), q + Vector3(0, -0.6 - 0.1 * (k % 2), 0)), Vector3(0.07, 0.09, 0.03), rng, 0.05, 2, 5, 1.0)
	KitLandmarks.beam(mb, wood, cb + Vector3(-0.6, 0, 0), cb + Vector3(0.6, 0, 0), 0.06)
	node.add_child(KitLandmarks.far_off(mb.to_instance("HermitDressing")))
	KitLandmarks.chest(ctx, pl, Vector3(-1.6, KitLandmarks.gy(ctx, pl, -1.6, -3.0), -3.0), 0.0, "hermit_stash", KitLandmarks.loot(isl, rng, false), 0.8)


# ==========================================================================
# The abandoned mine: an adit timbered into a rock face, its rails, its cart
# ==========================================================================
const MINE_OFF := 8.0
const MINE_FACE := 4.6
const ADIT_HW := 1.3
const ADIT_H := 2.4
const ADIT_LEN := 7.5


static func _plan_mine(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var best := {}
	var best_s := -INF
	for k in range(60):
		var p := KitLandmarks.rand_inland(isl, rng, 0.18, 0.75)
		var h := isl.hv(p)
		var g := KitLandmarks.grad(isl, p, 6.0)
		var s := g.length()
		if h < 4.0 or s < 0.08 or s > 0.55:
			continue
		var u := g / s
		if not KitLandmarks.clear_of(p + u * 4.0, 14.0, avoid) or isl.path_dist(p) < 6.0 or isl.path_dist(p + u * MINE_OFF) < 7.0:
			continue
		if s > best_s:
			best_s = s
			best = {"at": p, "y": h, "u": u}
	if best.is_empty():
		return {}
	var p: Vector2 = best["at"]
	var u: Vector2 = best["u"]
	KitLandmarks.level(isl, p, best["y"], 5.0, 9.0)
	return {"at": p, "y": best["y"], "face": -u, "r": 14.0, "keep": [[Vector2.ZERO, 5.0], [Vector2(0, -MINE_OFF), 8.0]], "door": p - u * 8.0,
		"top": rng.randf_range(7.5, 10.0) + maxf(isl.hv(p + u * MINE_OFF) - float(best["y"]), 0.0)}


static func _mine(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var noise := KitLandmarks.rock_noise(int(pl["seed"]), 0.2)
	var mats := KitLandmarks.rock_mats(ctx)
	var pick := KitLandmarks.rock_pick(noise, mats[0], mats[1], mats[2])
	var top: float = pl["top"]
	var cz := -MINE_OFF
	var front := PI * 0.5
	var na := 36
	var rows := 7
	var pts: Array = []
	for i in range(na):
		var a := TAU * i / na
		var f := 1.0 - GenIsland._smooth(0.3, 1.0, absf(angle_difference(a, front)))
		var rr := lerpf(rng.randf_range(7.0, 8.5) + noise.get_noise_1d(a * 8.0), MINE_FACE, f)
		var hh := top + 1.5 * noise.get_noise_1d(a * 6.0 + 30.0)
		var d := Vector3(cos(a), 0, sin(a))
		var foot := Vector3(0, 0, cz) + d * rr
		var fy := KitLandmarks.gy(ctx, pl, foot.x, foot.z) - 1.2
		var col: Array = []
		for j in range(rows):
			var t := float(j) / (rows - 1)
			var r := rr * lerpf(1.04, lerpf(0.45, 0.9, f), pow(t, 0.8))
			var y := fy + (hh - fy) * pow(t, 0.9) if j > 0 else fy
			if j == 1:
				y = maxf(y, ADIT_H + 0.15) if f > 0.9 else y
			var q := Vector3(0, 0, cz) + d * r + Vector3(0, y, 0)
			col.append(q + d * noise.get_noise_3dv(q * 0.6) * (0.6 if j > 0 and j < rows - 1 else 0.2) * (1.0 - f * 0.8))
		pts.append(col)
	var mouth := func(i: int, j: int) -> bool:
		return j == 0 and absf(angle_difference(TAU * (i + 0.5) / na, front)) < 0.2
	var mb := MeshBuilder.new()
	KitLandmarks.rock_grid(mb, pts, Vector3(0, top + 0.4, cz), pick, 0.32, noise, false, mouth)
	var wall := PSXMat.lit("rock", (ctx.style["rock_tint"] as Color).darkened(0.25), {"affine": 0.6})
	var z0 := cz + MINE_FACE + 0.6
	var z1 := z0 - ADIT_LEN
	for s in [-1.0, 1.0]:
		var x: float = s * ADIT_HW
		mb.add_quad(wall, Vector3(x, -0.3, z0), Vector3(x, -0.3, z1), Vector3(x, ADIT_H, z1), Vector3(x, ADIT_H, z0),
			Vector2(z0, 0.3) * 0.4, Vector2(z1, 0.3) * 0.4, Vector2(z1, -ADIT_H) * 0.4, Vector2(z0, -ADIT_H) * 0.4, Color(0.75, 0.75, 0.75), Vector3(-s, 0, 0))
	mb.add_quad(wall, Vector3(-ADIT_HW, ADIT_H, z0), Vector3(-ADIT_HW, ADIT_H, z1), Vector3(ADIT_HW, ADIT_H, z1), Vector3(ADIT_HW, ADIT_H, z0),
		Vector2(0, 0), Vector2(0, 3), Vector2(1, 3), Vector2(1, 0), Color(0.6, 0.6, 0.6), Vector3.DOWN)
	mb.add_quad(wall, Vector3(-ADIT_HW, -0.3, z1), Vector3(ADIT_HW, -0.3, z1), Vector3(ADIT_HW, ADIT_H, z1), Vector3(-ADIT_HW, ADIT_H, z1),
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Color(0.55, 0.55, 0.55), Vector3.BACK)
	for k in range(6):
		mb.add_blob(mats[0], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-1.0, 1.0), 0.2, z1 + rng.randf_range(0.3, 1.4))), Vector3(0.5, 0.4, 0.45) * rng.randf_range(0.7, 1.3), rng, 0.2, 3, 6, 0.6)
	var b := KitLandmarks.body("Mine")
	var mesh := mb.commit()
	var mi := MeshInstance3D.new()
	mi.name = "MineRock"
	mi.mesh = mesh
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	b.add_child(cs)
	node.add_child(b)


## Timber sets down the adit and a frame at its mouth, rails out onto the spoil
## heap, the cart tipped over, tools, ore, a lantern, the cache at the far end.
static func _mine_dressing(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> void:
	var node := KitLandmarks.node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var timber := PSXMat.lit("planks_dark", Color(0.85, 0.75, 0.6))
	var iron := PSXMat.lit("metal", ctx.style["rust"])
	var dirt := PSXMat.lit("dirt", Color(0.8, 0.72, 0.6), {"affine": 0.6})
	var ore := PSXMat.glow(Color(0.95, 0.8, 0.35), 0.6)
	var mb := MeshBuilder.new()
	var z0 := -MINE_OFF + MINE_FACE + 0.6
	var z1 := z0 - ADIT_LEN
	var z := z0 + 0.2
	while z > z1 + 0.5:
		for s in [-1.0, 1.0]:
			mb.add_box(timber, Transform3D(Basis(), Vector3(s * (ADIT_HW - 0.12), ADIT_H * 0.5 - 0.15, z)), Vector3(0.22, ADIT_H + 0.3, 0.22), 0.8)
		mb.add_box(timber, Transform3D(Basis(), Vector3(0, ADIT_H - 0.12, z)), Vector3(ADIT_HW * 2.0 + 0.2, 0.26, 0.26), 0.8, Color.WHITE, false)
		z -= 1.6
	for s in [-1.0, 1.0]:
		mb.add_box(timber, Transform3D(Basis(), Vector3(s * (ADIT_HW + 0.05), ADIT_H * 0.5, z0 + 0.4)), Vector3(0.32, ADIT_H + 0.6, 0.32), 0.8)
	mb.add_box(timber, Transform3D(Basis(), Vector3(0, ADIT_H + 0.25, z0 + 0.4)), Vector3(ADIT_HW * 2.0 + 1.0, 0.4, 0.4), 0.8, Color.WHITE, false)
	mb.add_box(PSXMat.lit("planks", Color(0.8, 0.75, 0.65)), Transform3D(Basis(Vector3.BACK, 0.06), Vector3(0, ADIT_H + 0.75, z0 + 0.62)), Vector3(1.8, 0.5, 0.06), 1.0)
	var out := 7.0
	for s in [-0.45, 0.45]:
		var ra := Vector3(s, 0.06, z1 + 0.6)
		var rb := Vector3(s, KitLandmarks.gy(ctx, pl, s, out) + 0.1, out)
		KitLandmarks.beam(mb, iron, ra, Vector3(s, maxf(0.06, KitLandmarks.gy(ctx, pl, s, z0)) + 0.06, z0), 0.07)
		KitLandmarks.beam(mb, iron, Vector3(s, maxf(0.06, KitLandmarks.gy(ctx, pl, s, z0)) + 0.06, z0), rb, 0.07)
	var sz := z1 + 0.8
	while sz < out:
		var sy := maxf(0.02, KitLandmarks.gy(ctx, pl, 0, sz)) if sz > z0 else 0.02
		mb.add_box(timber, Transform3D(Basis(), Vector3(0, sy, sz)), Vector3(1.4, 0.08, 0.2), 1.0, Color(0.8, 0.8, 0.8))
		sz += 0.75
	var heap := Vector3(rng.randf_range(-1.0, 1.0), 0, out + 2.5)
	heap.y = KitLandmarks.gy(ctx, pl, heap.x, heap.z)
	mb.add_blob(dirt, Transform3D(Basis(), heap), Vector3(3.2, 1.3, 2.6), rng, 0.25, 3, 8, 0.5, Color.WHITE, -0.3)
	var cp := heap + Vector3(-2.2, 0.55, -1.2)
	var cxf := Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.BACK, 1.3), cp)
	mb.add_box(iron, cxf, Vector3(1.0, 0.7, 1.4), 1.0, Color(0.9, 0.9, 0.9))
	for wx in [-0.55, 0.55]:
		for wz in [-0.45, 0.45]:
			mb.add_cylinder(iron, cxf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(wx, -0.4, wz)), 0.18, 0.18, 0.08, 8, 1.0, Color(0.6, 0.6, 0.6), true, true)
	for k in range(9):
		var q := cp + Vector3(rng.randf_range(-0.4, 1.6), -0.45, rng.randf_range(-0.8, 0.8))
		mb.add_blob(ore if k % 3 == 0 else PSXMat.lit("rock", ctx.style["rock_tint"]), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q), Vector3(0.18, 0.14, 0.16), rng, 0.2, 2, 5, 1.0)
	for s in [-1.0, 1.0]:
		var hp := Vector3(s * (ADIT_HW + 0.6), 0, z0 + 0.8)
		var tip := hp + Vector3(s * 0.15, 1.0, -0.25)
		KitLandmarks.beam(mb, timber, hp + Vector3(0, 0.05, 0), tip, 0.06)
		mb.add_extrude(iron, Transform3D(Basis.looking_at((tip - hp).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), tip),
			PackedVector2Array([Vector2(-0.4, -0.03), Vector2(0.4, -0.03), Vector2(0.3, 0.06), Vector2(-0.3, 0.06)]), 0.06, 1.0)
	node.add_child(KitLandmarks.far_off(mb.to_instance("MineDressing")))
	var lantern := Props.lantern_post(2.0)
	node.add_child(lantern)
	lantern.position = Vector3(ADIT_HW + 1.2, KitLandmarks.gy(ctx, pl, ADIT_HW + 1.2, z0 + 1.2), z0 + 1.2)
	KitLights.light(ctx, lantern, Vector3(0.55, 1.5, 0.0), 1.2, 9.0)
	KitLandmarks.chest(ctx, pl, Vector3(0, 0.0, z1 + 1.9), 0.0, "mine_cache", KitLandmarks.loot(isl, rng, true), 0.9)


# ==========================================================================
# The aqueduct: a run of stone arches over the jungle, one span fallen
# ==========================================================================
static func _plan_aqueduct(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	for k in range(50):
		var p := KitLandmarks.rand_inland(isl, rng, 0.15, 0.7)
		var d := Vector2.from_angle(rng.randf() * TAU)
		var length := rng.randf_range(44.0, 60.0)
		if not KitLandmarks.clear_of(p, length * 0.5 + 3.0, avoid):
			continue
		var lo := INF
		var hi := -INF
		for i in range(9):
			var h := isl.hv(p + d * length * (i / 8.0 - 0.5))
			lo = minf(lo, h)
			hi = maxf(hi, h)
		if lo < 2.5 or hi - lo > 9.0:
			continue
		var face := d.orthogonal()
		var keep: Array = []
		var n := int(length / 9.0) + 1
		for i in range(n + 1):
			keep.append([Vector2(length * (float(i) / n - 0.5), 0.0), 2.2])
		return {"at": p, "y": isl.hv(p), "face": face, "r": length * 0.5 + 3.0, "keep": keep, "door": p + face * 6.0,
			"len": length, "top": hi + rng.randf_range(6.5, 9.0) - isl.hv(p), "piers": n, "broken": rng.randi_range(1, n - 2)}
	return {}


static func _aqueduct(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var mats := _stone(ctx)
	var vine_m := PSXMat.lit("leaves", Color(0.5, 0.72, 0.38))
	var water := KitLandmarks.flow_mat("water", ctx.style["water_tint"], Vector2(0.6, 0.0))
	var length: float = pl["len"]
	var top: float = pl["top"]
	var n: int = pl["piers"]
	var broken: int = pl["broken"]
	var span := length / n
	var hw := 1.3
	var b := KitLandmarks.body("Aqueduct")
	var mb := MeshBuilder.new()
	var w := MeshBuilder.new()
	for i in range(n + 1):
		var x := length * (float(i) / n - 0.5)
		var g := minf(KitLandmarks.gy(ctx, pl, x, -hw), KitLandmarks.gy(ctx, pl, x, hw)) - 0.8
		var ph := top - 1.2 - g
		var m: Material = mats[1] if rng.randf() < 0.3 else mats[0]
		Buildings.tiled_box(mb, m, Vector3(x, g + ph * 0.5, 0), Vector3(1.8, ph, hw * 2.0 + 0.3), 2.6, 0.4)
		mb.add_box(mats[0], Transform3D(Basis(), Vector3(x, g + 0.5, 0)), Vector3(2.3, 1.0, hw * 2.0 + 0.8), 0.4, Color(0.85, 0.85, 0.85))
		KitLandmarks.box_col(b, Vector3(1.8, ph, hw * 2.0 + 0.3), Vector3(x, g + ph * 0.5, 0))
	for i in range(n):
		var x0 := length * (float(i) / n - 0.5) + 0.9
		var x1 := length * (float(i + 1) / n - 0.5) - 0.9
		if i == broken:
			for e in [[x0, 1.0], [x1, -1.0]]:
				var ex: float = e[0]
				var es: float = e[1]
				mb.add_box(mats[0], Transform3D(Basis(Vector3.FORWARD, es * 0.2), Vector3(ex + es * 0.9, top - 0.8, 0)), Vector3(1.8, 1.3, hw * 2.0 + 0.3), 0.4)
			for k in range(12):
				var q := Vector3(lerpf(x0, x1, rng.randf()), 0, rng.randf_range(-2.5, 2.5))
				q.y = KitLandmarks.gy(ctx, pl, q.x, q.z) + 0.3
				mb.add_box(mats[rng.randi() % 2], Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)), q), Vector3(rng.randf_range(0.6, 1.2), rng.randf_range(0.4, 0.8), rng.randf_range(0.5, 1.0)), 0.5)
			continue
		var spring := top - 1.2 - (x1 - x0) * 0.5 - 0.6
		var outline := PackedVector2Array([Vector2(x0, top - 0.4), Vector2(x0, spring)])
		for k in range(1, 10):
			var t := PI * k / 10.0
			outline.append(Vector2((x0 + x1) * 0.5 - cos(t) * (x1 - x0) * 0.5, spring + sin(t) * (x1 - x0) * 0.5))
		outline.append(Vector2(x1, spring))
		outline.append(Vector2(x1, top - 0.4))
		mb.add_extrude(mats[0] if i % 2 == 0 else mats[1], Transform3D(), outline, hw * 2.0 + 0.3, 0.4)
		KitLandmarks.box_col(b, Vector3(x1 - x0, 0.6, hw * 2.0 + 0.3), Vector3((x0 + x1) * 0.5, top - 0.7, 0))
		mb.add_box(mats[0], Transform3D(Basis(), Vector3((x0 + x1) * 0.5, top - 0.25, 0)), Vector3(x1 - x0 + 1.8, 0.3, hw * 2.0 + 0.3), 0.4)
		for s in [-1.0, 1.0]:
			mb.add_box(mats[1] if rng.randf() < 0.4 else mats[0], Transform3D(Basis(), Vector3((x0 + x1) * 0.5, top + 0.3, s * hw)), Vector3(x1 - x0 + 1.8, 0.8, 0.3), 0.4)
			KitLandmarks.box_col(b, Vector3(x1 - x0 + 1.8, 0.8, 0.3), Vector3((x0 + x1) * 0.5, top + 0.3, s * hw))
			for v in range(2):
				KitLandmarks.vine(mb, vine_m, Vector3(lerpf(x0, x1, rng.randf()), top - 0.1, s * (hw + 0.2)), rng.randf_range(2.0, top * 0.6), Vector3(0, 0, s), rng)
		KitLandmarks.box_col(b, Vector3(x1 - x0 + 1.8, 0.3, hw * 2.0), Vector3((x0 + x1) * 0.5, top - 0.25, 0))
		KitLandmarks.ribbon(w, water, PackedVector3Array([Vector3(x0 - 0.9, top - 0.08, 0), Vector3(x1 + 0.9, top - 0.08, 0)]), 0.9, 0.9, Vector3(0, 0, 1), Vector3.UP, 0.5)
	var e0 := -length * 0.5
	var foot := Vector3(e0 - 7.0, 0, 0)
	foot.y = KitLandmarks.gy(ctx, pl, foot.x, 0)
	var rise := Vector3(e0 + 0.6, top - 0.1, 0) - foot
	KitLandmarks.box_col_xf(b, Vector3(rise.length(), 0.5, 2.2), Transform3D(Basis(Vector3.BACK, atan2(rise.y, rise.x)), foot + rise * 0.5 + Vector3(0, -0.25, 0)))
	for k in range(14):
		var t := (k + 0.5) / 14.0
		var q := foot + rise * t + Vector3(0, -0.35, rng.randf_range(-0.6, 0.6))
		mb.add_box(mats[rng.randi() % 2], Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * Basis(Vector3.BACK, atan2(rise.y, rise.x) * 0.5), q), Vector3(1.4, 0.8, 1.6), 0.5, Color(0.9, 0.9, 0.9))
	b.add_child(mb.to_instance("AqueductMesh"))
	node.add_child(b)
	var wmi := w.to_instance("AqueductWater")
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(KitLandmarks.far_off(wmi))
	var bx := length * (float(broken) / n - 0.5) - 1.6
	KitLandmarks.chest(ctx, pl, Vector3(bx, top - 0.1, 0.2), PI * 0.5, "aqueduct_cache", KitLandmarks.loot(isl, rng, true), 0.85)


# ==========================================================================
# The gorge: a cleft cut across the land, a stream at its foot, a rope bridge over
# ==========================================================================
const GORGE_LEN := 52.0
const GORGE_DEPTH := 9.0
## Half its width at the floor and at the rim.
const GORGE_IN := 2.6
const GORGE_OUT := 6.8


static func _plan_gorge(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	for k in range(50):
		var p := KitLandmarks.rand_inland(isl, rng, 0.2, 0.6)
		var along := Vector2.from_angle(rng.randf() * TAU)
		if not KitLandmarks.clear_of(p, GORGE_LEN * 0.5 + 4.0, avoid):
			continue
		var ok := true
		for i in range(11):
			var q := p + along * GORGE_LEN * (i / 10.0 - 0.5)
			if isl.hv(q) < GORGE_DEPTH + 2.5 or isl.path_dist(q) < GORGE_OUT + 3.0:
				ok = false
				break
		if not ok:
			continue
		var a := p - along * GORGE_LEN * 0.5
		var c := p + along * GORGE_LEN * 0.5
		KitLandmarks.shape(isl, p, GORGE_LEN * 0.5 + GORGE_OUT + 2.0, func(h: float, _d: float, q: Vector2) -> float:
			var ab := c - a
			var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var dseg := q.distance_to(a + ab * t)
			var ends := GenIsland._smooth(0.0, 0.18, t) * GenIsland._smooth(0.0, 0.18, 1.0 - t)
			return h - GORGE_DEPTH * ends * (1.0 - GenIsland._smooth(GORGE_IN, GORGE_OUT, dseg)))
		var face := along.orthogonal()
		var keep: Array = []
		for i in range(9):
			keep.append([Vector2(GORGE_LEN * (i / 8.0 - 0.5), 0.0), GORGE_OUT])
		return {"at": p, "y": isl.hv(p) + GORGE_DEPTH, "face": face, "r": GORGE_LEN * 0.5 + 2.0, "keep": keep, "door": p + face * (GORGE_OUT + 5.0)}
	return {}


static func _gorge(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var noise := KitLandmarks.rock_noise(int(pl["seed"]), 0.2)
	var mats := KitLandmarks.rock_mats(ctx)
	var pick := KitLandmarks.rock_pick(noise, mats[0], mats[1], mats[2])
	var mb := MeshBuilder.new()
	# (rock faces over the terrain's slope: its 3 m cells can't make a cliff)
	var n := 22
	for s in [-1.0, 1.0]:
		var rows: Array = []
		for i in range(n + 1):
			var x := GORGE_LEN * 0.82 * (float(i) / n - 0.5)
			var col: Array = []
			for j in range(5):
				var t := j / 4.0
				var z: float = s * lerpf(GORGE_OUT - 0.4, GORGE_IN - 0.3, t)
				var y := lerpf(KitLandmarks.gy(ctx, pl, x, s * (GORGE_OUT + 0.6)) + 0.2, KitLandmarks.gy(ctx, pl, x, 0.0) - 0.4, pow(t, 1.2))
				var q := Vector3(x, y, z)
				col.append(q + Vector3(0, 0, s) * noise.get_noise_3dv(q * 0.5) * 0.7)
			rows.append(col)
		for i in range(n):
			for j in range(4):
				var a: Vector3 = rows[i][j]
				var b: Vector3 = rows[i + 1][j]
				var c: Vector3 = rows[i + 1][j + 1]
				var d: Vector3 = rows[i][j + 1]
				var hint := Vector3(0, 0.4, -s)
				KitLandmarks.rock_facet(mb, a, b, c, hint, pick, 0.32, noise)
				KitLandmarks.rock_facet(mb, a, c, d, hint, pick, 0.32, noise)
	var at: Array = []
	for k in range(10):
		var x := rng.randf_range(-GORGE_LEN * 0.4, GORGE_LEN * 0.4)
		var z := rng.randf_range(-1.6, 1.6)
		at.append(Vector3(x, KitLandmarks.gy(ctx, pl, x, z), z))
	KitLandmarks.boulders(mb, mats, at, rng, 0.5, 1.3)
	var b := KitLandmarks.body("Gorge")
	var mesh := mb.commit()
	var mi := MeshInstance3D.new()
	mi.name = "GorgeRock"
	mi.mesh = mesh
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	b.add_child(cs)
	node.add_child(b)
	var w := MeshBuilder.new()
	var line := PackedVector3Array()
	for i in range(13):
		var x := GORGE_LEN * 0.8 * (i / 12.0 - 0.5)
		line.append(Vector3(x, KitLandmarks.gy(ctx, pl, x, 0.0) + 0.15, 0.4 * sin(i * 1.3)))
	KitLandmarks.ribbon(w, KitLandmarks.flow_mat("water", ctx.style["water_tint"], Vector2(0.0, -0.5)), line, 2.6, 2.6, Vector3(0, 0, 1), Vector3.UP, 0.4)
	var wmi := w.to_instance("Stream")
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(wmi)
	KitLandmarks.loop_sound(node, "hull_gurgle_loop.wav", Vector3(0, KitLandmarks.gy(ctx, pl, 0, 0) + 0.5, 0), 5.0, 35.0, -8.0, 0.9)


## The rope bridge over at the middle on timber landings, vines down the walls,
## the bones and the pack of one who didn't make it across.
static func _gorge_bridge(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> void:
	var node := KitLandmarks.node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var planks := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.6})
	var timber := PSXMat.lit("planks_dark")
	var rope := PSXMat.lit("rope")
	var vine_m := PSXMat.lit("leaves", Color(0.5, 0.75, 0.38))
	var bx := rng.randf_range(-6.0, 6.0)
	var ya := KitLandmarks.gy(ctx, pl, bx, -GORGE_OUT - 1.5)
	var yb := KitLandmarks.gy(ctx, pl, bx, GORGE_OUT + 1.5)
	var y := minf(ya, yb) + 0.3
	var b := KitLandmarks.body("GorgeBridge")
	var mb := MeshBuilder.new()
	for s in [-1.0, 1.0]:
		var z: float = s * (GORGE_OUT + 1.6)
		var gl := KitLandmarks.gy(ctx, pl, bx, z)
		mb.add_box(planks, Transform3D(Basis(), Vector3(bx, y - 0.1, z)), Vector3(2.4, 0.2, 2.4), 0.5, Color.WHITE, false)
		KitLandmarks.box_col(b, Vector3(2.4, 0.2, 2.4), Vector3(bx, y - 0.1, z))
		for px in [-1.0, 1.0]:
			for pz in [-1.0, 1.0]:
				var post := Vector3(bx + px * 1.1, 0, z + pz * 1.1)
				mb.add_box(timber, Transform3D(Basis(), Vector3(post.x, (gl - 0.6 + y + 1.3) * 0.5, post.z)), Vector3(0.2, y + 1.3 - gl + 0.6, 0.2), 0.8)
		var back := Vector3(bx, 0, z + s * 1.2)
		var gb := KitLandmarks.gy(ctx, pl, back.x, back.z + s * 1.5)
		var rise := Vector3(0, y - gb, -s * 1.5)
		KitLandmarks.box_col_xf(b, Vector3(1.6, 0.2, rise.length() + 0.2), Transform3D(Basis.looking_at(rise.normalized(), Vector3.UP), back + Vector3(0, gb, s * 1.5) + rise * 0.5))
		mb.add_box(planks, Transform3D(Basis.looking_at(rise.normalized(), Vector3.UP), back + Vector3(0, gb, s * 1.5) + rise * 0.5), Vector3(1.6, 0.12, rise.length() + 0.2), 0.6, Color(0.85, 0.85, 0.85), false)
	KitLandmarks.bridge(mb, b, planks, rope, Vector3(bx, y, -GORGE_OUT - 0.4), Vector3(bx, y, GORGE_OUT + 0.4), 0.7)
	for k in range(14):
		var s := 1.0 if k % 2 == 0 else -1.0
		var x := rng.randf_range(-GORGE_LEN * 0.38, GORGE_LEN * 0.38)
		var z: float = s * (GORGE_OUT - 0.3)
		KitLandmarks.vine(mb, vine_m, Vector3(x, KitLandmarks.gy(ctx, pl, x, s * (GORGE_OUT + 0.5)), z), rng.randf_range(3.0, GORGE_DEPTH * 0.8), Vector3(0, 0, -s), rng)
	b.add_child(KitLandmarks.far_off(mb.to_instance("BridgeMesh")))
	node.add_child(b)
	var fx := rng.randf_range(-12.0, 12.0)
	KitLandmarks.chest(ctx, pl, Vector3(fx, KitLandmarks.gy(ctx, pl, fx, 1.6), 1.6), rng.randf() * TAU, "gorge_cache", KitLandmarks.loot(isl, rng, true), 0.9)
