class_name KitVillage
extends RefCounted
## A village's houses and the dressing passes that make it lived in: benches round
## a well, tables outside the inn, bunting round the plaza, washing lines, a fenced
## vegetable plot, a notice board, handcarts, lamps along the main road. Houses
## themselves are KitContext.house (Buildings.house specs); where they go is the
## island's layout (Brinehollow's are hand-placed). `dress_houses` is the generic
## pass for any island's houses.


## A table with a bench either side (along local z, turned `yaw`).
static func table_set(ctx: KitContext, p: Vector2, yaw := 0.0) -> void:
	ctx.place(Props.table(), p, yaw, 1.0)
	ctx.place(Props.bench(), p + _rot(Vector2(0, 1.0), yaw), yaw)
	ctx.place(Props.bench(), p + _rot(Vector2(0, -1.0), yaw), yaw)


## `n` benches round c at radius r facing in (skipping any on a path).
static func benches_round(ctx: KitContext, c: Vector2, r: float, n := 4, phase := PI * 0.25) -> void:
	for k in range(n):
		var a := phase + k * TAU / n
		var bp := c + Vector2(cos(a), sin(a)) * r
		if ctx.path_dist(bp) < 1.5:
			continue
		ctx.place(Props.bench(), bp, KitContext.face_yaw(c - bp) + PI * 0.5, 1.0)


## A pole for bunting (into `mb`, island space), reserved.
static func pole(ctx: KitContext, mb: MeshBuilder, q: Vector2, h: float) -> void:
	mb.add_box(PSXMat.lit("planks_dark"), Transform3D(Basis(), Vector3(q.x, ctx.hv(q) + h * 0.5, q.y)), Vector3(0.12, h, 0.12), 1.0)
	ctx.reserve(q, 0.8)


## Bunting round a plaza: `n` poles on a ring (where they're clear of paths and of
## small things already placed), lines strung between neighbours `h` up, none
## across a gap wider than `max_gap` (radians). Into `mb` (island space).
static func bunting_ring(ctx: KitContext, mb: MeshBuilder, c: Vector2, r: float, rng: RandomNumberGenerator, n := 10, phase := 0.15, h := 4.0, max_gap := PI * 0.45) -> void:
	var poles: Array = []
	for k in range(n):
		var a := TAU * k / n + phase
		var q := c + Vector2(cos(a), sin(a)) * r
		if ctx.path_dist(q) > 1.2 and not ctx.excluded(q, 0.2, 12.0):
			poles.append([a, q])
	for pq in poles:
		var q: Vector2 = pq[1]
		pole(ctx, mb, q, h + 0.2)
	for i in range(poles.size()):
		var a0: Array = poles[i]
		var a1: Array = poles[(i + 1) % poles.size()]
		if wrapf(float(a1[0]) - float(a0[0]), 0.0, TAU) > max_gap:
			continue
		var p0: Vector2 = a0[1]
		var p1: Vector2 = a1[1]
		bunting(ctx, mb, Vector3(p0.x, ctx.hv(p0) + h, p0.y), Vector3(p1.x, ctx.hv(p1) + h, p1.y), rng)


## A sagging line between a and b hung with little triangular flags (the style's pennants).
static func bunting(ctx: KitContext, mb: MeshBuilder, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var pennants: Array = ctx.style["pennants"]
	var rope := PSXMat.lit("rope")
	var n := maxi(int(a.distance_to(b) / 0.55), 2)
	var sag := a.distance_to(b) * 0.08
	var prev := a
	var dir := (b - a).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t)
		Buildings.beam_between(mb, rope, prev, p, 0.025)
		if k < n:
			var col := PSXMat.flat(pennants[rng.randi() % pennants.size()])
			var l := p - dir * 0.2
			var r := p + dir * 0.2
			var tip := p + Vector3.DOWN * 0.38 + side * rng.randf_range(-0.03, 0.03)
			mb.add_tri(col, l, r, tip, side, side, side, Vector2.ZERO, Vector2(1, 0), Vector2(0.5, 1), Color.WHITE, side)
			mb.add_tri(col, l, tip, r, -side, -side, -side, Vector2.ZERO, Vector2(0.5, 1), Vector2(1, 0), Color(0.8, 0.8, 0.8), -side)
		prev = p


## Two posts, a line, and the washing out on it (the style's cloths).
static func laundry(ctx: KitContext, a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_weathered")
	var ya := ctx.hv(a)
	var yb := ctx.hv(b)
	for q in [Vector3(a.x, ya, a.y), Vector3(b.x, yb, b.y)]:
		mb.add_box(wood, Transform3D(Basis(), q + Vector3(0, 1.1, 0)), Vector3(0.1, 2.2, 0.1), 1.0)
	var pa := Vector3(a.x, ya + 2.05, a.y)
	var pb := Vector3(b.x, yb + 2.05, b.y)
	Buildings.beam_between(mb, PSXMat.lit("rope"), pa, pb, 0.02)
	var dir := (pb - pa).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var cloths: Array = ctx.style["washing"]
	var x := 0.4
	var len := pa.distance_to(pb)
	while x < len - 0.6:
		var cw := rng.randf_range(0.4, 0.8)
		var ch := rng.randf_range(0.45, 0.9)
		var p0 := pa + dir * x - Vector3.UP * 0.05
		var p1 := pa + dir * (x + cw) - Vector3.UP * 0.05
		var col := PSXMat.lit("fabric", cloths[rng.randi() % cloths.size()])
		var lean := side * rng.randf_range(-0.08, 0.08)
		mb.add_quad(col, p0, p1, p1 + Vector3.DOWN * ch + lean, p0 + Vector3.DOWN * ch + lean, Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, side)
		mb.add_quad(col, p0, p0 + Vector3.DOWN * ch + lean, p1 + Vector3.DOWN * ch + lean, p1, Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color(0.8, 0.8, 0.8), -side)
		x += cw + rng.randf_range(0.15, 0.4)
	ctx.add(mb.to_instance("Washing"))
	ctx.reserve(a, 0.8)
	ctx.reserve(b, 0.8)


## A fenced vegetable plot: rows of crops on tilled earth, a gap in the front fence.
static func garden(ctx: KitContext, c: Vector2, w: float, d: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	node.name = "Garden"
	var mb := MeshBuilder.new()
	var soil := PSXMat.lit("dirt", Color(0.75, 0.62, 0.5))
	var leaf := PSXMat.lit("leaves", Color(0.75, 1.0, 0.7))
	var veg := [PSXMat.flat(Color(0.95, 0.55, 0.15)), PSXMat.flat(Color(0.75, 0.15, 0.2)), PSXMat.flat(Color(0.85, 0.85, 0.4))]
	var rows := int(d / 0.8)
	for r in range(rows):
		var z := -d * 0.5 + 0.4 + r * 0.8
		mb.add_box(soil, Transform3D(Basis(), Vector3(0, 0.06, z)), Vector3(w - 0.6, 0.18, 0.45), 1.0)
		var vm: Material = veg[r % veg.size()]
		for k in range(int((w - 0.8) / 0.45)):
			var x := -w * 0.5 + 0.6 + k * 0.45
			mb.add_blob(leaf, Transform3D(Basis(), Vector3(x, 0.24, z)), Vector3(0.16, 0.13, 0.16), rng, 0.3, 2, 5, 1.0)
			if (k + r) % 3 == 0:
				mb.add_blob(vm, Transform3D(Basis(), Vector3(x + 0.05, 0.2, z + 0.1)), Vector3.ONE * 0.07, rng, 0.2, 2, 4, 1.0)
	node.add_child(mb.to_instance())
	ctx.place(node, c, yaw, maxf(w, d) * 0.5)
	for seg in [[Vector2(-w * 0.5, -d * 0.5), 0.0, d], [Vector2(w * 0.5, -d * 0.5), 0.0, d], [Vector2(-w * 0.5, -d * 0.5), PI * 0.5, w],
			[Vector2(-w * 0.5, d * 0.5), PI * 0.5, w * 0.4], [Vector2(w * 0.1, d * 0.5), PI * 0.5, w * 0.4]]:
		var local: Vector2 = seg[0]
		var wp := c + local.rotated(-yaw)
		ctx.put(Props.fence_segment(float(seg[2]), 0.8), Vector3(wp.x, ctx.hv(wp), wp.y), yaw + float(seg[1]))


## Lantern posts every `every` points of a path from point `start`, alternating
## sides `off` metres out (unlit: the road's light is the plaza's).
static func road_lamps(ctx: KitContext, path: PackedVector2Array, start := 3, every := 5, off := 2.9) -> void:
	for i in range(start, path.size(), every):
		var a := path[i]
		var b := path[mini(i + 1, path.size() - 1)]
		var tangent := (b - a).normalized()
		var side := Vector2(-tangent.y, tangent.x) * (off if i % 2 == 0 else -off)
		var lp := ctx.place(Props.lantern_post(), a + side, KitContext.face_yaw(-side), 0.4)
		lp.rotation.y = KitContext.face_yaw(-side) - PI * 0.5


## A notice board: two posts, a little roof, papers pinned up.
static func notice_board(rng: RandomNumberGenerator) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "NoticeBoard"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	for x in [-0.8, 0.8]:
		mb.add_box(wood, Transform3D(Basis(), Vector3(x, 1.1, 0)), Vector3(0.12, 2.2, 0.12), 1.0)
	mb.add_box(PSXMat.lit("planks"), Transform3D(Basis(), Vector3(0, 1.45, 0.02)), Vector3(1.5, 1.0, 0.06), 1.0)
	mb.add_gable_roof(PSXMat.lit("thatch"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 2.2, 0)), 0.6, 1.9, 0.35, 0.1)
	var papers := [Color(0.9, 0.86, 0.72), Color(0.95, 0.93, 0.85), Color(0.85, 0.78, 0.6)]
	for k in range(6):
		var pp := Vector3(-0.55 + (k % 3) * 0.55 + rng.randf_range(-0.08, 0.08), 1.7 - (k / 3) * 0.48, 0.06)
		mb.add_box(PSXMat.flat(papers[k % 3]), Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12)), pp), Vector3(0.36, 0.42, 0.01), 1.0)
		mb.add_box(PSXMat.flat(Color(0.3, 0.25, 0.2)), Transform3D(Basis(), pp + Vector3(0, 0.08, 0.008)), Vector3(0.24, 0.03, 0.005), 1.0)
		mb.add_box(PSXMat.flat(Color(0.75, 0.15, 0.12)), Transform3D(Basis(), pp + Vector3(0, 0.19, 0.01)), Vector3(0.03, 0.03, 0.01), 1.0)
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.2, 0.3)
	cs.shape = box
	cs.position = Vector3(0, 1.1, 0)
	body.add_child(cs)
	return body


## A hand cart with sacks in it.
static func handcart() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Handcart"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.2, 0.1, 1.6), 1.0)
	for s in [-1.0, 1.0]:
		mb.add_box(wood, Transform3D(Basis(), Vector3(s * 0.6, 0.8, 0)), Vector3(0.06, 0.35, 1.6), 1.0)
		mb.add_cylinder(dark, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.72, 0.42, 0.2)), 0.42, 0.42, 0.07, 10, 1.0, Color.WHITE, true, true)
		Buildings.beam_between(mb, dark, Vector3(s * 0.45, 0.6, 0.8), Vector3(s * 0.45, 0.15, 2.0), 0.07)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for k in range(3):
		mb.add_blob(PSXMat.lit("canvas", Color(0.8, 0.72, 0.55)), Transform3D(Basis(), Vector3(-0.3 + k * 0.3, 0.88, -0.3 + (k % 2) * 0.5)), Vector3(0.28, 0.22, 0.32), rng, 0.2, 3, 6)
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.0, 1.7)
	cs.shape = box
	cs.position = Vector3(0, 0.5, 0)
	body.add_child(cs)
	return body


## The generic dressing pass for any island's houses (`houses`: [node, point,
## the way its door faces]): round each, where the ground is clear, one of a
## washing line across the back yard, a vegetable plot beside it, cargo by the
## wall (barrels, a crate), a handcart by the door; at the door a lit lamp (every
## other house, while the budget lasts) or a bench, and a planter.
static func dress_houses(ctx: KitContext, houses: Array, rng: RandomNumberGenerator) -> void:
	for i in range(houses.size()):
		var p: Vector2 = houses[i][1]
		var f: Vector2 = (houses[i][2] as Vector2).normalized()
		var s := Vector2(-f.y, f.x)
		var r := 3.6
		var back := p - f * (r + 1.6)
		var beside := p + s * (r + 1.8) * (1.0 if i % 2 == 0 else -1.0)
		var door := p + f * (r + 0.6)
		match i % 4:
			0:
				if not ctx.excluded(back, 0.4):
					laundry(ctx, back - s * 2.0, back + s * 2.0, rng)
			1:
				if not ctx.excluded(beside, 0.5):
					garden(ctx, beside, 3.2, 2.6, KitContext.face_yaw(f), rng)
			2:
				if not ctx.excluded(beside, 0.3):
					ctx.place(Props.barrel(), beside, 0.0, 0.5)
					ctx.place(Props.barrel(), beside + f * 0.8, 0.0, 0.5)
					ctx.place(Props.crate(0.7), beside - f * 0.9, rng.randf() * TAU, 0.6)
			_:
				if not ctx.excluded(beside, 0.6):
					ctx.place(handcart(), beside, KitContext.face_yaw(f), 1.2)
		if i % 2 == 0:
			var lp := door + s * 2.2 + f * 0.4
			if not ctx.excluded(lp, 0.2):
				KitLights.post(ctx, lp, KitContext.face_yaw(-s) - PI * 0.5, 0.4, 1.4, 2.4)
		var bench_p := door + s * 1.6
		if not ctx.excluded(bench_p, 0.2):
			ctx.place(Props.bench(), bench_p, KitContext.face_yaw(s), 0.8)
		var pl := door - s * 1.6
		if not ctx.excluded(pl, 0.2):
			ctx.place(Buildings.planter(0.5), pl, 0.0, 0.6)


## Phase 1's proof that the kit isn't Brinehollow-only (not in the game: the
## fidelity tools run it with FID_KIT=1): a built generated island's village
## dressed by `dress_houses` round its huts, benches and bunting round its plaza,
## in the jungle style, lamps from a budget of 4. Its pieces go under Site_village.
static func dress_generated_village(gi: GenIsland) -> void:
	var v: IslandVillage = gi.get_node("Site_village/Village")
	var ctx := KitContext.make(gi, int(gi.node["seed"]), "jungle", 4, gi.build_ms).under(gi.site_node("village"))
	ctx.own_reserves = true
	ctx.taken.append_array(v.taken)
	ctx.timed("kit dressing", func():
		var c: Vector2 = gi.sites["village"]
		dress_houses(ctx, v.huts, ctx.rng(1))
		benches_round(ctx, c, 6.5, 4, PI * 0.25)
		var mb := MeshBuilder.new()
		bunting_ring(ctx, mb, c, 12.5, ctx.rng(2), 10, 0.15, 4.0)
		ctx.add(mb.to_instance("Bunting")))


static func _rot(v: Vector2, yaw: float) -> Vector2:
	return v if yaw == 0.0 else v.rotated(-yaw)
