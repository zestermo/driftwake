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
	Props.seats().face_all(ctx.place(Props.bench(), p + _rot(Vector2(0, 1.0), yaw), yaw), Vector3(0, 0, -1))
	Props.seats().face_all(ctx.place(Props.bench(), p + _rot(Vector2(0, -1.0), yaw), yaw), Vector3(0, 0, 1))


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
	# (wanted posters go up here once a captain is wanted: Bounty)
	var wp := WantedPoster.new()
	wp.name = "Wanted"
	wp.position = Vector3(0, 1.45, 0.075)
	body.add_child(wp)
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


static func _rot(v: Vector2, yaw: float) -> Vector2:
	return v if yaw == 0.0 else v.rotated(-yaw)


# --------------------------------------------------------------------------
# Streets and dressing planned as data (a worker's prepare may run these), each
# item with its own seed, then made by build_items / build_cargo / build_bunting.
# `occ` is the plan's own occupancy ([centre, radius]); an item is a dictionary
# {"k": kind, "p": Vector2, "yaw", ...}.
# --------------------------------------------------------------------------
## Points every `step` m along a polyline, from `from` to `to` m along it: [point, unit tangent, distance].
static func along(pts: PackedVector2Array, step: float, from := 0.0, to := INF) -> Array:
	var out: Array = []
	var walked := 0.0
	var next := from
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if seg < 0.0001:
			continue
		var t := (pts[i + 1] - pts[i]) / seg
		while next <= walked + seg and next <= to:
			out.append([pts[i] + t * (next - walked), t, next])
			next += step
		walked += seg
	return out


## The stretch of a polyline from `from` to `to` m along it (points every 1.5 m).
static func cut(pts: PackedVector2Array, from: float, to: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for e in along(pts, 1.5, from, to):
		out.append(e[0])
	return out


static func occ_free(occ: Array, p: Vector2, r: float) -> bool:
	for e in occ:
		if p.distance_to(e[0]) < r + float(e[1]):
			return false
	return true


## A building's two circles in `occ`: its body, and the apron in front (porch, steps, the way in).
static func plot_circles(p: Vector2, face: Vector2, w: float, d: float, ext: float) -> Array:
	return [[p, maxf(w, d) * 0.52], [p + face.normalized() * (d * 0.5 + ext * 0.5), maxf(ext * 0.5, 0.6) + 0.7]]


## Can a w x d building (plus `ext` of porch and steps in front, toward `face`) stand at
## p: clear of `occ` by `gap`, its outline `pad` off every path, on land above `min_h`,
## the ground under it rising less than `max_rise`.
static func plot_clear(ctx: KitContext, occ: Array, p: Vector2, face: Vector2, w: float, d: float, ext: float,
		pad := 0.6, gap := 1.0, min_h := 1.8, max_rise := 2.4) -> bool:
	for e in plot_circles(p, face, w, d, ext):
		if not occ_free(occ, e[0], float(e[1]) + gap):
			return false
	var f := face.normalized()
	var s := Vector2(-f.y, f.x)
	var lo := INF
	var hi := -INF
	for u in [-0.5, 0.0, 0.5]:
		for v in [-0.5, 0.0, 0.5]:
			var q: Vector2 = p + s * w * float(u) + f * ((d + ext) * float(v) + ext * 0.5)
			var hq := ctx.hv(q)
			lo = minf(lo, hq)
			hi = maxf(hi, hq)
			if ctx.path_dist(q) < pad:
				return false
	return lo > min_h and hi - lo < max_rise


static func _spot(ctx: KitContext, occ: Array, q: Vector2, r: float, pad := 0.3) -> bool:
	return occ_free(occ, q, r) and ctx.path_dist(q) > pad and ctx.hv(q) > 1.2


## Item `k` at q if there's room (taking it in `occ`).
static func plan_put(ctx: KitContext, items: Array, occ: Array, k: String, q: Vector2, yaw: float, r: float, extra := {}) -> bool:
	if not _spot(ctx, occ, q, r):
		return false
	var it := {"k": k, "p": q, "yaw": yaw}
	it.merge(extra)
	items.append(it)
	occ.append([q, r])
	return true


## A heap of cargo at p (kind, or one at random): crates with one stacked, a pair of
## barrels and a third, jars in a group, sacks, baskets by a jar. Each piece is an
## item {"k": "cargo", "kind", "p", "y", "yaw", "s"} (build_cargo instances them).
static func plan_cargo(ctx: KitContext, items: Array, p: Vector2, yaw: float, rng: RandomNumberGenerator, kind := "") -> void:
	var k: String = kind if kind != "" else ["crate", "barrel", "jar", "sack", "basket"][rng.randi() % 5]
	var fw := Vector2(sin(yaw), cos(yaw))
	var rt := Vector2(fw.y, -fw.x)
	var parts: Array = []
	match k:
		"crate":
			parts = [["crate", Vector2.ZERO, 0.0, 1.0], ["crate", rt * 0.78, 0.0, 0.9], ["crate", rt * 0.35, 0.7, 0.8]]
			if rng.randf() < 0.5:
				parts.append(["barrel", -rt * 0.75 + fw * 0.2, 0.0, 1.0])
		"barrel":
			parts = [["barrel", Vector2.ZERO, 0.0, 1.0], ["barrel", rt * 0.8, 0.0, 1.0], ["barrel", rt * 0.4 + fw * 0.7, 0.0, 0.95]]
		"jar":
			parts = [["jar", Vector2.ZERO, 0.0, 1.0], ["jar", rt * 0.5 + fw * 0.15, 0.0, 0.8], ["jar", -rt * 0.45 + fw * 0.2, 0.0, 0.9], ["jar", fw * 0.5, 0.0, 0.7]]
		"sack":
			parts = [["sack", Vector2.ZERO, 0.0, 1.0], ["sack", rt * 0.55, 0.0, 0.95], ["sack", rt * 0.25 + fw * 0.45, 0.0, 0.9], ["basket", -rt * 0.6, 0.0, 1.0]]
		_:
			parts = [["basket", Vector2.ZERO, 0.0, 1.0], ["basket", rt * 0.6, 0.0, 0.9], ["jar", -rt * 0.55 + fw * 0.1, 0.0, 1.0]]
	for e in parts:
		var q: Vector2 = p + e[1]
		items.append({"k": "cargo", "kind": e[0], "p": q, "y": ctx.hv(q) + float(e[2]), "yaw": yaw + rng.randf_range(-0.5, 0.5), "s": float(e[3])})


## Round a building at p (its door toward `face`, `front` m from p to the foot of its
## steps), where there's room: behind it a washing line, a vegetable plot, a woodpile,
## a fish rack or an upturned canoe; by a side wall cargo or a handcart; at the door
## a bench or jars, and a planter. Things someone works at carry a "spot" {"at", "face"}.
static func plan_yard(ctx: KitContext, items: Array, occ: Array, p: Vector2, face: Vector2, w: float, d: float, front: float, rng: RandomNumberGenerator) -> void:
	var f := face.normalized()
	var s := Vector2(-f.y, f.x)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var back := p - f * (d * 0.5 + 1.9)
	match rng.randi() % 5:
		0:
			var a := back - s * 2.1
			var b := back + s * 2.1
			if _spot(ctx, occ, a, 0.4) and _spot(ctx, occ, b, 0.4) and _spot(ctx, occ, back, 0.9):
				items.append({"k": "laundry", "p": back, "a": a, "b": b, "seed": rng.randi(), "spot": {"at": back + f * 0.9, "face": -f}})
				occ.append_array([[a, 0.4], [b, 0.4], [back, 1.0]])
		1:
			var g := back - f * 0.4
			plan_put(ctx, items, occ, "garden", g, KitContext.face_yaw(f), 2.2, {"w": 3.6, "d": 2.6, "seed": rng.randi(), "spot": {"at": g + f * 1.8, "face": -f}})
		2:
			var q := back + s * side * 0.8
			plan_put(ctx, items, occ, "woodpile", q, KitContext.face_yaw(-f), 1.0, {"spot": {"at": q - f * 1.5, "face": f}})
		3:
			plan_put(ctx, items, occ, "fishrack", back, KitContext.face_yaw(f), 1.2, {"spot": {"at": back + f * 0.9, "face": -f}})
		_:
			plan_put(ctx, items, occ, "canoe", back, KitContext.face_yaw(s), 1.8)
	var bes := p + s * side * (w * 0.5 + 1.2) - f * (d * 0.15)
	if rng.randf() < 0.25:
		plan_put(ctx, items, occ, "cart", bes, KitContext.face_yaw(f), 1.2)
	elif _spot(ctx, occ, bes, 1.0):
		plan_cargo(ctx, items, bes, KitContext.face_yaw(s * side), rng)
		occ.append([bes, 1.1])
	var door := p + f * front
	if rng.randf() < 0.6:
		plan_put(ctx, items, occ, "bench", door - s * side * 2.1 - f * 0.4, KitContext.face_yaw(f), 1.0)
	else:
		var jp := door - s * side * 1.9 - f * 0.3
		if _spot(ctx, occ, jp, 0.8):
			plan_cargo(ctx, items, jp, 0.0, rng, "jar")
			occ.append([jp, 0.8])
	plan_put(ctx, items, occ, "planter", door + s * side * 2.0 - f * 0.3, 0.0, 0.7, {"r": 0.5})


## Along a street (half width hw), every `every` m on alternate sides just past its
## edge, where there's room: torches (every other one lit), planters, cargo, benches
## facing the street, a run of fence.
static func plan_lane(ctx: KitContext, items: Array, occ: Array, pts: PackedVector2Array, hw: float, rng: RandomNumberGenerator,
		every := 8.0, from := 4.0, to := INF) -> void:
	var pick := rng.randi() % 6
	var side := 1.0
	var torches := 0
	for e in along(pts, every, from, to):
		var q: Vector2 = e[0]
		var t: Vector2 = e[1]
		var n := Vector2(-t.y, t.x) * side
		side = -side
		var at := q + n * (hw + 0.9)
		var ok := false
		match pick % 6:
			0, 3:
				ok = plan_put(ctx, items, occ, "torch", at, 0.0, 0.5, {"lit": torches % 2 == 0})
				if ok:
					torches += 1
			1:
				ok = plan_put(ctx, items, occ, "planter", at + n * 0.2, 0.0, 0.8, {"r": 0.55})
			2:
				if _spot(ctx, occ, at + n * 0.4, 1.0):
					plan_cargo(ctx, items, at + n * 0.4, KitContext.face_yaw(t), rng)
					occ.append([at + n * 0.4, 1.0])
					ok = true
			4:
				ok = plan_put(ctx, items, occ, "bench", at + n * 0.2, KitContext.face_yaw(-n), 1.0)
			_:
				var a := at + n * 0.2 - t * 2.2
				if _spot(ctx, occ, a, 0.4) and _spot(ctx, occ, at + n * 0.2, 0.4) and _spot(ctx, occ, at + n * 0.2 + t * 2.2, 0.4):
					items.append({"k": "fence", "p": a, "yaw": KitContext.face_yaw(t), "len": 4.4})
					occ.append_array([[a, 0.4], [at + n * 0.2, 0.4], [at + n * 0.2 + t * 2.2, 0.4]])
					ok = true
		if ok:
			pick += 1


## Bunting poles on a ring (data): `n` spots where they're clear of the paths and `occ`, [angle, point].
static func plan_bunting_ring(ctx: KitContext, occ: Array, c: Vector2, r: float, n := 10, phase := 0.15) -> Array:
	var poles: Array = []
	for k in range(n):
		var a := TAU * k / n + phase
		var q := c + Vector2(cos(a), sin(a)) * r
		if ctx.path_dist(q) > 1.2 and occ_free(occ, q, 0.3):
			poles.append([a, q])
			occ.append([q, 0.4])
	return poles


## Poles from plan_bunting_ring with lines `h` up between neighbours (none across a
## gap wider than `max_gap`), into mb (island space).
static func build_bunting(ctx: KitContext, mb: MeshBuilder, poles: Array, h: float, rng: RandomNumberGenerator, max_gap := PI * 0.45) -> void:
	for pq in poles:
		pole(ctx, mb, pq[1], h + 0.2)
	for i in range(poles.size()):
		var a0: Array = poles[i]
		var a1: Array = poles[(i + 1) % poles.size()]
		if wrapf(float(a1[0]) - float(a0[0]), 0.0, TAU) > max_gap:
			continue
		var p0: Vector2 = a0[1]
		var p1: Vector2 = a1[1]
		bunting(ctx, mb, Vector3(p0.x, ctx.hv(p0) + h, p0.y), Vector3(p1.x, ctx.hv(p1) + h, p1.y), rng)


static func _seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## Makes planned items (all but cargo), in order; their meshes drawn out to `range_end` m.
## Torches marked lit take a light from the budget; an item with a "y" stands at that
## height (on a deck) instead of the ground. Returns [item, node] for the ones
## that are places to be (the caller's work spots and seats).
static func build_items(ctx: KitContext, items: Array, range_end := 130.0) -> Array:
	var out: Array = []
	for it in items:
		var p: Vector2 = it["p"]
		var yaw: float = it.get("yaw", 0.0)
		var n: Node3D = null
		var own: Dictionary = ctx.style["item_models"]
		match str(it["k"]):
			_ when own.has(str(it["k"])):
				n = ctx.place(KitStyle.model(own[it["k"]], _seeded(hash(p)), 1.0), p, yaw, 0.8, 0.0, false)
				if it.get("lit", false):
					KitLights.light(ctx, n, (n.get_node("Flame") as Node3D).position, 1.3, 9.0)
			"laundry":
				laundry(ctx, it["a"], it["b"], _seeded(int(it["seed"])))
			"garden":
				garden(ctx, p, it["w"], it["d"], yaw, _seeded(int(it["seed"])))
			"cart":
				n = ctx.place(handcart(), p, yaw, 1.2, 0.0, false)
			"bench":
				n = ctx.place(Props.bench(), p, yaw, 0.8, 0.0, false)
			"table":
				table_set(ctx, p, yaw)
			"planter":
				n = ctx.place(Buildings.planter(float(it["r"])), p, 0.0, float(it["r"]) + 0.2, 0.0, false)
			"lamp":
				n = KitLights.post(ctx, p, yaw, 0.4, 1.6 if it["lit"] else 0.0, 2.4)
			"torch":
				n = ctx.place(KitHouses.torch(), p, yaw)
				if it["lit"]:
					KitLights.light(ctx, n, Vector3(0, 2.45, 0), 1.3, 9.0)
			"fishrack":
				n = ctx.place(Props.fish_rack(), p, yaw, 1.0, 0.0, false)
			"canoe":
				n = ctx.place(Props.upturned_boat(), p, yaw, 1.6, 0.0, false)
			"woodpile":
				n = ctx.place(KitHouses.woodpile(), p, yaw, 0.8, 0.0, false)
			"sign":
				n = ctx.place(Props.signpost(it["arrows"]), p, 0.0, 0.0)
			"fence":
				n = Props.fence_segment(float(it["len"]), 0.9)
				ctx.put(n, Vector3(p.x, ctx.hv(p), p.y), yaw)
			"well":
				n = ctx.place(KitHouses.well(str(ctx.style["mat"]["thatch"])), p, yaw, 1.2, 0.0, false)
			"rubble":
				n = ctx.place(KitHouses.rubble(int(it["seed"])), p, yaw, 0.8, 0.0, false)
		if n and it.has("y"):
			n.global_position.y = ctx.isl.global_position.y + float(it["y"])
		if n:
			for gi in n.find_children("*", "GeometryInstance3D", true, false):
				if (gi as GeometryInstance3D).visibility_range_end == 0.0:
					(gi as GeometryInstance3D).visibility_range_end = range_end
		out.append([it, n])
	return out


## The planned cargo as one MultiMesh per kind (KitHouses.CARGO) and one body with a
## collider per crate, barrel and jar, under a "Cargo" node; drawn out to `range_end` m.
static func build_cargo(ctx: KitContext, items: Array, range_end := 130.0) -> void:
	var by_kind := {}
	var holder := Node3D.new()
	holder.name = "Cargo"
	var body := StaticBody3D.new()
	body.name = "CargoColliders"
	body.collision_layer = 1
	body.collision_mask = 0
	for it in items:
		if str(it["k"]) != "cargo":
			continue
		var kind: String = it["kind"]
		var s: float = it["s"]
		var at := Vector3(it["p"].x, it["y"], it["p"].y)
		var xf := Transform3D(Basis(Vector3.UP, float(it["yaw"])).scaled(Vector3.ONE * s), at)
		if not by_kind.has(kind):
			by_kind[kind] = []
		by_kind[kind].append(xf)
		var col: Array = KitHouses.CARGO[kind]
		if col.is_empty():
			continue
		var cs := CollisionShape3D.new()
		if col[0] == "box":
			var b := BoxShape3D.new()
			b.size = Vector3.ONE * float(col[1]) * s
			cs.shape = b
			cs.transform = Transform3D(Basis(Vector3.UP, float(it["yaw"])), at + Vector3(0, float(col[1]) * s * 0.5, 0))
		else:
			var c := CylinderShape3D.new()
			c.radius = float(col[1]) * s
			c.height = float(col[2]) * s
			cs.shape = c
			cs.position = at + Vector3(0, c.height * 0.5, 0)
		body.add_child(cs)
	for kind in by_kind.keys():
		var xfs: Array = by_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = KitHouses.cargo_mesh(kind)
		mm.instance_count = xfs.size()
		for i in range(xfs.size()):
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = str(kind).capitalize()
		mmi.multimesh = mm
		mmi.visibility_range_end = range_end
		holder.add_child(mmi)
	# (filled before it joins the tree: each shape added to a body in the tree rebuilds its whole compound)
	holder.add_child(body)
	ctx.add(holder)
