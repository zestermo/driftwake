class_name CapitalModels
extends RefCounted
## The royal capital's architecture, built into MeshBuilders in the city's frame (CapitalPlan: x along the
## harbour, +z to sea, y absolute): white limestone walls and towers with terracotta roofs, town houses whose
## walls are the facade texture (a bay and a storey a tile), arches cut as extruded spandrels over piers, the
## palace, the arena's outer walls, the moles and the lighthouse. Colliders come back as data
## ({"box": size, "xf"} / {"cyl": [r, h], "xf"}: CapitalIsland makes the shapes on the main thread).
## Worker-safe (PSXMat locks its cache).

const STOREY := 3.0
const BAY := 3.0
const ROOF_PITCH := 0.36
const WALLS := [Color(1.0, 1.0, 1.0), Color(0.98, 0.95, 0.88), Color(0.97, 0.9, 0.78), Color(0.97, 0.88, 0.84), Color(0.93, 0.94, 0.92),
	Color(0.99, 0.93, 0.8), Color(0.94, 0.9, 0.86)]
const ROOFS := [Color(1.0, 1.0, 1.0), Color(0.92, 0.86, 0.82), Color(1.04, 0.95, 0.88), Color(0.85, 0.78, 0.74)]
const BLUE := Color(0.18, 0.26, 0.58)
const GOLD := Color(0.86, 0.68, 0.26)


static func mat(kind: String) -> Material:
	match kind:
		"lime":
			return PSXMat.lit("limestone")
		"wash":
			return PSXMat.lit("plaster_wash")
		"roof":
			return PSXMat.lit("roof_tiles", Color.WHITE, {"affine": 0.8})
		"facade_a":
			return PSXMat.lit("capital_facade_a", Color.WHITE, {"emission": Color(1.0, 0.76, 0.42), "emission_energy": 0.55, "emission_tex": "capital_facade_a_glow"})
		"facade_b":
			return PSXMat.lit("capital_facade_b", Color.WHITE, {"emission": Color(1.0, 0.76, 0.42), "emission_energy": 0.55, "emission_tex": "capital_facade_b_glow"})
		"window":
			return PSXMat.lit("window", Color.WHITE, {"emission": Color(0.9, 0.7, 0.35), "emission_energy": 0.31, "emission_tex": "window"})
		"slabs":
			return PSXMat.lit("capital_slabs")
		"dark":
			return PSXMat.lit("planks_dark")
		"iron":
			return PSXMat.lit("metal", Color(0.3, 0.3, 0.33))
		"glow":
			return PSXMat.glow(Color(1.0, 0.82, 0.5), 2.4)
		"gold":
			return PSXMat.flat(GOLD)
		"blue":
			return PSXMat.lit("fabric", BLUE)
		"cloth":
			return PSXMat.lit("canvas")
		"leaves":
			return PSXMat.lit("leaves", Color(0.62, 0.78, 0.56))
	push_error("CapitalModels: no material %s" % kind)
	return null


static func v3(q: Vector2, y: float) -> Vector3:
	return Vector3(q.x, y, q.y)


static func xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


static func yaw_of(d: Vector2) -> float:
	return atan2(d.x, d.y)


static func box(cols: Array, t: Transform3D, size: Vector3) -> void:
	cols.append({"box": size, "xf": t})


static func cyl(cols: Array, base: Vector3, r: float, h: float) -> void:
	cols.append({"cyl": [r, h], "xf": Transform3D(Basis(), base + Vector3(0, h * 0.5, 0))})


## A wall's face mapped as facade bays: a quad from a to b (bottom corners) up h, `out` its outward normal.
static func facade_quad(mb: MeshBuilder, m: Material, a: Vector3, b: Vector3, h: float, out: Vector3, col: Color, storey := STOREY) -> void:
	var bays := maxf(roundf(a.distance_to(b) / BAY), 1.0)
	var rows := h / storey
	mb.add_quad(m, a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0), Vector2(0, rows), Vector2(bays, rows), Vector2(bays, 0), Vector2(0, 0), col, out)


## A box whose four sides are facade (no top or bottom): centre on the ground plane at y0, w along local x, d along z.
static func facade_box(mb: MeshBuilder, m: Material, t: Transform3D, w: float, d: float, y0: float, h: float, col: Color) -> void:
	var c := [Vector3(-w * 0.5, y0, d * 0.5), Vector3(w * 0.5, y0, d * 0.5), Vector3(w * 0.5, y0, -d * 0.5), Vector3(-w * 0.5, y0, -d * 0.5)]
	var outs := [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]
	for i in range(4):
		facade_quad(mb, m, t * (c[i] as Vector3), t * (c[(i + 1) % 4] as Vector3), h, (t.basis * (outs[i] as Vector3)).normalized(), col)


## A town house as massing: a limestone plinth down to the lowest ground, facade walls, a cornice, its roof.
static func house(mb: MeshBuilder, lot: Dictionary, low: float, top: float) -> float:
	var r: Rect2 = lot["r"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lot["seed"])
	var col: Color = WALLS[rng.randi() % WALLS.size()]
	var rcol: Color = ROOFS[rng.randi() % ROOFS.size()]
	var fac := mat("facade_b") if rng.randf() < 0.35 else mat("facade_a")
	var c := r.get_center()
	var t := xf(v3(c, 0.0))
	var w := r.size.x
	var d := r.size.y
	var plinth := top + 0.6
	mb.add_box(mat("lime"), xf(v3(c, (low + plinth) * 0.5)), Vector3(w + 0.12, plinth - low, d + 0.12), 0.5, Color(0.92, 0.9, 0.86), true, true)
	var eaves := top + float(lot["floors"]) * STOREY
	facade_box(mb, fac, t, w, d, plinth, eaves - plinth, col)
	mb.add_box(mat("lime"), xf(v3(c, eaves + 0.12)), Vector3(w + 0.3, 0.24, d + 0.3), 0.6, Color(0.95, 0.93, 0.9), false)
	roof(mb, str(lot["roof"]), t, w, d, eaves + 0.24, rcol, rng)
	return eaves


static func roof(mb: MeshBuilder, kind: String, t: Transform3D, w: float, d: float, y: float, rcol: Color, rng: RandomNumberGenerator) -> void:
	var at := t * Transform3D(Basis(), Vector3(0, y, 0))
	match kind:
		"hip":
			_hip(mb, at, w, d, minf(w, d) * ROOF_PITCH, 0.35, rcol)
		"gable":
			var along_x := w > d
			var rt := at * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO) if along_x else at
			var rw := d if along_x else w
			var rd := w if along_x else d
			mb.add_gable_roof(mat("roof"), rt, rw, rd, rw * ROOF_PITCH, 0.35, 0.5, rcol, mat("wash"))
		_:
			for s in [-1.0, 1.0]:
				mb.add_box(mat("lime"), at * Transform3D(Basis(), Vector3(s * (w * 0.5 - 0.15), 0.4, 0)), Vector3(0.3, 0.8, d), 0.6, Color(0.94, 0.92, 0.88))
				mb.add_box(mat("lime"), at * Transform3D(Basis(), Vector3(0, 0.4, s * (d * 0.5 - 0.15))), Vector3(w - 0.6, 0.8, 0.3), 0.6, Color(0.94, 0.92, 0.88))
			mb.add_quad(mat("slabs"), at * Vector3(-w * 0.5, 0.05, -d * 0.5), at * Vector3(w * 0.5, 0.05, -d * 0.5), at * Vector3(w * 0.5, 0.05, d * 0.5),
				at * Vector3(-w * 0.5, 0.05, d * 0.5), Vector2(0, 0), Vector2(w * 0.4, 0), Vector2(w * 0.4, d * 0.4), Vector2(0, d * 0.4), Color(0.8, 0.74, 0.66), Vector3.UP)
			if rng.randf() < 0.5:
				var px := rng.randf_range(-w * 0.25, w * 0.25)
				var pz := rng.randf_range(-d * 0.25, d * 0.25)
				var pt := at * Transform3D(Basis(), Vector3(px, 0.0, pz))
				mb.add_box(mat("lime"), pt * Transform3D(Basis(), Vector3(0, 1.1, 0)), Vector3(2.2, 2.2, 2.2), 0.5, Color(0.96, 0.94, 0.9))
				_hip(mb, pt * Transform3D(Basis(), Vector3(0, 2.2, 0)), 2.2, 2.2, 0.9, 0.2, rcol)


## A hip roof whose tiles keep the roof texture's scale and shade with `col` (Buildings.add_hip_roof, coloured).
static func _hip(mb: MeshBuilder, t: Transform3D, w: float, d: float, h: float, over: float, col: Color) -> void:
	var hw := w * 0.5 + over
	var hd := d * 0.5 + over
	var along_x := w >= d
	var r := maxf(absf(hw - hd), 0.0)
	var c := [t * Vector3(-hw, 0, -hd), t * Vector3(hw, 0, -hd), t * Vector3(hw, 0, hd), t * Vector3(-hw, 0, hd)]
	var ra := t * (Vector3(-r, h, 0) if along_x else Vector3(0, h, -r))
	var rb := t * (Vector3(r, h, 0) if along_x else Vector3(0, h, r))
	var top := t * Vector3(0, h, 0)
	var up := (t.basis * Vector3.UP).normalized()
	var faces: Array
	if along_x:
		faces = [[c[0], c[1], rb, ra], [c[2], c[3], ra, rb], [c[1], c[2], rb], [c[3], c[0], ra]]
	else:
		faces = [[c[1], c[2], rb, ra], [c[3], c[0], ra, rb], [c[0], c[1], ra], [c[2], c[3], rb]]
	var m := mat("roof")
	for f in faces:
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var mid := (a + b) * 0.5
		var out := mid - top
		out -= up * out.dot(up)
		var n := (out.normalized() * h + up * maxf(hw, hd) * 0.8).normalized()
		var L := a.distance_to(b) * 0.5
		var sl := mid.distance_to(top if f.size() == 3 else ((f[2] as Vector3) + (f[3] as Vector3)) * 0.5) * 0.5
		if f.size() == 4:
			mb.add_quad(m, a, b, f[2], f[3], Vector2(0, sl), Vector2(L, sl), Vector2(L * 0.75, 0), Vector2(L * 0.25, 0), col, n)
			mb.add_quad(m, a, f[3], f[2], b, Vector2(0, sl), Vector2(L * 0.25, 0), Vector2(L * 0.75, 0), Vector2(L, sl), col * 0.55, -n)
		else:
			mb.add_tri(m, a, b, f[2], n, n, n, Vector2(0, sl), Vector2(L, sl), Vector2(L * 0.5, 0), col, n)
			mb.add_tri(m, a, f[2], b, -n, -n, -n, Vector2(0, sl), Vector2(L * 0.5, 0), Vector2(L, sl), col * 0.55, -n)


# --------------------------------------------------------------------------
# Walls, towers, gates
# --------------------------------------------------------------------------
## A curtain wall along `pts` (frame), in pieces about `seg` long: each from below the lowest ground at its ends
## (`ground`: Callable(Vector2) -> float; `low`: the same for how deep the footing goes) up `h` over the ground at
## its middle, `t` thick, merlons along both edges, a walk between.
static func wall_run(mb: MeshBuilder, cols: Array, pts: Array, h: float, t: float, ground: Callable, low: Callable, seg := 7.0, merlons := true) -> void:
	var m := mat("lime")
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(ceili(a.distance_to(b) / seg), 1)
		var dir := (b - a).normalized()
		var yaw := yaw_of(dir)
		for k in range(n):
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, float(k + 1) / n)
			var c := (p0 + p1) * 0.5
			var top: float = ground.call(c) + h
			var bot := minf(minf(low.call(p0), low.call(p1)), low.call(c)) - 2.0
			var L := p0.distance_to(p1) + 0.3
			var bt := xf(v3(c, (top + bot) * 0.5), yaw)
			mb.add_box(m, bt, Vector3(t, top - bot, L), 0.5, Color(0.95, 0.93, 0.89) * (0.96 + 0.04 * float(k % 2)))
			box(cols, bt, Vector3(t, top - bot, L))
			mb.add_box(m, xf(v3(c, top - 0.6), yaw), Vector3(t + 0.24, 0.2, L), 0.6, Color(0.86, 0.84, 0.8), false)
			if not merlons:
				continue
			var mn := maxi(int(L / 1.9), 1)
			for j in range(mn):
				var z := -L * 0.5 + (j + 0.5) * L / mn
				for s in [-1.0, 1.0]:
					mb.add_box(m, xf(v3(c, 0.0), yaw) * Transform3D(Basis(), Vector3(s * (t * 0.5 - 0.22), top + 0.55, z)), Vector3(0.44, 1.1, 0.95), 0.6, Color(0.93, 0.91, 0.87))


## A round tower on ground y0: footing down `deep`, a corbelled crown, then a cone of terracotta (or merlons).
static func round_tower(mb: MeshBuilder, cols: Array, c: Vector2, y0: float, r: float, h: float, roofed := true, deep := 4.0, banner := false) -> void:
	var base := y0 - deep
	mb.add_cylinder(mat("lime"), xf(v3(c, base)), r * 1.08, r, h + deep, 12, 0.5, Color(0.95, 0.93, 0.89), false, false, false)
	cyl(cols, v3(c, base), r * 1.04, h + deep)
	mb.add_cylinder(mat("lime"), xf(v3(c, y0 + h - 0.2)), r * 1.0, r * 1.16, 0.7, 12, 0.6, Color(0.82, 0.8, 0.76), false, false, false)
	mb.add_cylinder(mat("lime"), xf(v3(c, y0 + h + 0.5)), r * 1.16, r * 1.16, 1.1, 12, 0.6, Color(0.95, 0.93, 0.9), true, false, false)
	for k in range(4):
		var a := TAU * (k + 0.5) / 4.0
		var sl := v3(c + Vector2(cos(a), sin(a)) * (r + 0.02), y0 + h * (0.35 + 0.15 * k))
		mb.add_box(mat("dark"), xf(sl, -a + PI * 0.5), Vector3(0.35, 0.9, 0.08), 1.0, Color(0.25, 0.22, 0.2), false)
	if roofed:
		mb.add_cone(mat("roof"), xf(v3(c, y0 + h + 1.6)), r * 1.3, r * 2.3, 12, 0.5)
		mb.add_cylinder(mat("gold"), xf(v3(c, y0 + h + 1.6 + r * 2.3 - 0.2)), 0.08, 0.04, 1.6, 4)
		if banner:
			flag(mb, v3(c, y0 + h + 1.6 + r * 2.3 + 1.0), BLUE)
	else:
		for k in range(10):
			var a := TAU * k / 10.0
			mb.add_box(mat("lime"), xf(v3(c + Vector2(cos(a), sin(a)) * (r * 1.16 - 0.25), y0 + h + 2.05), -a + PI * 0.5), Vector3(1.0, 1.0, 0.45), 0.6, Color(0.93, 0.91, 0.87))


## A square tower: footing, shaft, a crown band, a pyramid roof (or merlons).
static func square_tower(mb: MeshBuilder, cols: Array, c: Vector2, y0: float, w: float, h: float, yaw := 0.0, roofed := true, deep := 4.0) -> void:
	var t := xf(v3(c, 0.0), yaw)
	mb.add_box(mat("lime"), t * Transform3D(Basis(), Vector3(0, y0 + (h - deep) * 0.5, 0)), Vector3(w, h + deep, w), 0.5, Color(0.95, 0.93, 0.89))
	box(cols, t * Transform3D(Basis(), Vector3(0, y0 + (h - deep) * 0.5, 0)), Vector3(w, h + deep, w))
	mb.add_box(mat("lime"), t * Transform3D(Basis(), Vector3(0, y0 + h + 0.4, 0)), Vector3(w + 0.6, 0.8, w + 0.6), 0.6, Color(0.85, 0.83, 0.79), false)
	for s in [-1.0, 1.0]:
		for f in [0, 1]:
			var o := Vector3(s * (w * 0.5 + 0.02), y0 + h * 0.62, 0) if f == 0 else Vector3(0, y0 + h * 0.62, s * (w * 0.5 + 0.02))
			mb.add_box(mat("dark"), t * Transform3D(Basis(Vector3.UP, PI * 0.5 if f == 0 else 0.0), o), Vector3(0.6, 1.4, 0.06), 1.0, Color(0.24, 0.22, 0.2), false)
	if roofed:
		_hip(mb, t * Transform3D(Basis(), Vector3(0, y0 + h + 0.8, 0)), w + 0.4, w + 0.4, w * 0.75, 0.3, Color.WHITE)
		mb.add_cylinder(mat("gold"), t * Transform3D(Basis(), Vector3(0, y0 + h + 0.8 + w * 0.75 - 0.1, 0)), 0.07, 0.03, 1.3, 4)
	else:
		for s in [-1.0, 1.0]:
			for k in range(3):
				var z := -w * 0.5 + (k + 0.5) * w / 3.0
				mb.add_box(mat("lime"), t * Transform3D(Basis(), Vector3(s * (w * 0.5 + 0.05), y0 + h + 1.3, z)), Vector3(0.5, 1.0, 0.9), 0.6, Color(0.93, 0.91, 0.87))
				mb.add_box(mat("lime"), t * Transform3D(Basis(), Vector3(z, y0 + h + 1.3, s * (w * 0.5 + 0.05))), Vector3(0.9, 1.0, 0.5), 0.6, Color(0.93, 0.91, 0.87))


## A pennant on a short staff (a card each side so it reads from both).
static func flag(mb: MeshBuilder, at: Vector3, col: Color) -> void:
	mb.add_cylinder(mat("dark"), xf(at), 0.05, 0.04, 3.0, 4, 1.0, Color(0.4, 0.36, 0.32))
	var m := mat("cloth")
	var a := at + Vector3(0.05, 2.9, 0)
	var b := at + Vector3(2.2, 2.55, 0)
	var c := at + Vector3(0.05, 1.9, 0)
	mb.add_tri(m, a, b, c, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector2(0, 0), Vector2(1, 0.3), Vector2(0, 1), col, Vector3.BACK)
	mb.add_tri(m, a, c, b, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2(0, 0), Vector2(0, 1), Vector2(1, 0.3), col, Vector3.FORWARD)


## A wall `w` wide, `h` tall and `depth` thick (local +z out) with an arch `aw` wide springing at `spring`, its
## crown `aw / 2` higher: two piers and the spandrel over the arch, cut as one extruded outline.
static func arch_wall(mb: MeshBuilder, m: Material, t: Transform3D, w: float, h: float, depth: float, aw: float, spring: float, col := Color.WHITE, segs := 8) -> void:
	var hw := w * 0.5
	var ha := aw * 0.5
	var pier := hw - ha
	if pier > 0.01:
		for s in [-1.0, 1.0]:
			mb.add_box(m, t * Transform3D(Basis(), Vector3(s * (ha + pier * 0.5), spring * 0.5, 0)), Vector3(pier, spring, depth), 0.5, col)
	var outline := PackedVector2Array([Vector2(-hw, spring)])
	for k in range(segs + 1):
		var a := PI - PI * k / segs
		outline.append(Vector2(cos(a) * ha, spring + sin(a) * ha))
	outline.append(Vector2(hw, spring))
	outline.append(Vector2(hw, h))
	outline.append(Vector2(-hw, h))
	mb.add_extrude(m, t, outline, depth, 0.5, col)


## A gatehouse across a wall: `w` along the wall, `d` through it, an arch through (closed by a gate leaf or a
## portcullis when `closed`), two round towers either side with cones; local +z faces out.
static func gatehouse(mb: MeshBuilder, cols: Array, t: Transform3D, w: float, d: float, h: float, aw: float, spring: float, tower_r: float, closed := false) -> void:
	var lime := mat("lime")
	arch_wall(mb, lime, t * Transform3D(Basis(), Vector3(0, 0, d * 0.5 - 0.4)), w, h, 0.8, aw, spring, Color(0.96, 0.94, 0.9))
	arch_wall(mb, lime, t * Transform3D(Basis(), Vector3(0, 0, -d * 0.5 + 0.4)), w, h, 0.8, aw, spring, Color(0.92, 0.9, 0.86))
	for s in [-1.0, 1.0]:
		var side := (w - aw) * 0.5
		mb.add_box(lime, t * Transform3D(Basis(), Vector3(s * (aw * 0.5 + side * 0.5), h * 0.5 - 2.0, 0)), Vector3(side, h + 4.0, d - 1.6), 0.5, Color(0.9, 0.88, 0.84))
		box(cols, t * Transform3D(Basis(), Vector3(s * (aw * 0.5 + side * 0.5), h * 0.5 - 2.0, 0)), Vector3(side, h + 4.0, d))
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, spring + aw * 0.5 + (h - spring - aw * 0.5) * 0.5, 0)), Vector3(aw, h - spring - aw * 0.5, d - 1.6), 0.5, Color(0.88, 0.86, 0.82), false)
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, h + 0.15, 0)), Vector3(w + 0.4, 0.3, d + 0.4), 0.6, Color(0.86, 0.84, 0.8), false)
	for k in range(int(w / 1.9)):
		var x := -w * 0.5 + (k + 0.5) * w / int(w / 1.9)
		for s in [-1.0, 1.0]:
			mb.add_box(lime, t * Transform3D(Basis(), Vector3(x, h + 0.85, s * (d * 0.5 - 0.1))), Vector3(0.9, 1.1, 0.44), 0.6, Color(0.93, 0.91, 0.87))
	var arch_top := spring + aw * 0.5
	var crest := t * Transform3D(Basis(), Vector3(0, arch_top + 1.3, d * 0.5 + 0.06))
	mb.add_box(mat("blue"), crest, Vector3(1.6, 1.6, 0.08), 1.0, Color.WHITE, false)
	mb.add_box(mat("gold"), crest * Transform3D(Basis(), Vector3(0, 0, 0.05)), Vector3(0.7, 0.9, 0.06), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		var tc := t * Vector3(s * (w * 0.5 + tower_r * 0.6), 0, d * 0.5 - tower_r * 0.6)
		round_tower(mb, cols, Vector2(tc.x, tc.z), t.origin.y, tower_r, h + 4.0, true, 4.0, true)
	if closed:
		portcullis(mb, cols, t * Transform3D(Basis(), Vector3(0, 0, d * 0.5 - 0.9)), aw, spring + aw * 0.5)


## A portcullis of iron bars filling an arch `aw` wide up to `top` (its collider closes the way).
static func portcullis(mb: MeshBuilder, cols: Array, t: Transform3D, aw: float, top: float) -> void:
	var iron := mat("iron")
	var n := int(aw / 0.35)
	for k in range(n + 1):
		var x := -aw * 0.5 + aw * k / n
		var ht := top - (aw * 0.5 - sqrt(maxf(aw * aw * 0.25 - x * x, 0.0)))
		mb.add_box(iron, t * Transform3D(Basis(), Vector3(x, ht * 0.5, 0)), Vector3(0.09, ht, 0.09), 1.0, Color.WHITE, false)
	for y in [0.6, 1.8, 3.0, 4.2, 5.4]:
		if y < top - 0.6:
			mb.add_box(iron, t * Transform3D(Basis(), Vector3(0, y, 0)), Vector3(aw, 0.1, 0.12), 1.0, Color.WHITE, false)
	box(cols, t * Transform3D(Basis(), Vector3(0, top * 0.5, 0)), Vector3(aw + 0.2, top, 0.6))


# --------------------------------------------------------------------------
# Landmarks
# --------------------------------------------------------------------------
## The lighthouse on the east mole's head: a tapering limestone shaft, a gallery, the lantern room, a cone.
static func lighthouse(mb: MeshBuilder, cols: Array, c: Vector2, y0: float) -> Vector3:
	round_tower(mb, cols, c, y0, 5.2, 7.0, false, 12.0)
	var y1 := y0 + 9.2
	mb.add_cylinder(mat("lime"), xf(v3(c, y1)), 3.4, 2.4, 18.0, 10, 0.5, Color(0.97, 0.95, 0.92), false, false, false)
	for k in range(3):
		mb.add_cylinder(mat("lime"), xf(v3(c, y1 + 4.0 + k * 5.0)), 3.2 - k * 0.3, 3.15 - k * 0.3, 0.6, 10, 0.6, Color(0.7, 0.3, 0.24), false, false, false)
	var g := y1 + 18.0
	mb.add_cylinder(mat("lime"), xf(v3(c, g)), 3.2, 3.2, 0.4, 10, 0.6, Color(0.86, 0.84, 0.8), true, true, false)
	for k in range(10):
		var a := TAU * k / 10.0
		mb.add_box(mat("iron"), xf(v3(c + Vector2(cos(a), sin(a)) * 3.0, g + 0.9)), Vector3(0.08, 1.0, 0.08), 1.0, Color.WHITE, false)
	mb.add_tube(mat("iron"), _ring(v3(c, g + 1.4), 3.0, 12), 0.05, -1.0, 4)
	mb.add_cylinder(mat("glow"), xf(v3(c, g + 0.4)), 1.6, 1.6, 2.4, 8, 1.0, Color.WHITE, false, false, false)
	for k in range(8):
		var a := TAU * k / 8.0
		mb.add_box(mat("iron"), xf(v3(c + Vector2(cos(a), sin(a)) * 1.65, g + 1.6)), Vector3(0.1, 2.4, 0.1), 1.0, Color.WHITE, false)
	mb.add_cone(mat("iron"), xf(v3(c, g + 2.8)), 2.2, 2.2, 8, 0.6, Color(0.5, 0.42, 0.3))
	mb.add_cylinder(mat("gold"), xf(v3(c, g + 4.9)), 0.12, 0.05, 1.2, 4)
	return v3(c, g + 1.6)


static func _ring(c: Vector3, r: float, n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for k in range(n + 1):
		var a := TAU * k / n
		pts.append(c + Vector3(cos(a) * r, 0, sin(a) * r))
	return pts


## A dome (a lathe) on a drum, a lantern and a gilded finial on top: the temple's, the palace's.
static func dome(mb: MeshBuilder, c: Vector3, r: float, drum_h: float, tint: Color) -> void:
	mb.add_cylinder(mat("lime"), xf(c), r * 1.02, r * 1.02, drum_h, 16, 0.5, Color(0.95, 0.93, 0.9), false, false, false)
	for k in range(8):
		var a := TAU * (k + 0.5) / 8.0
		mb.add_box(mat("dark"), xf(c + Vector3(cos(a) * (r * 1.02 + 0.02), drum_h * 0.55, sin(a) * (r * 1.02 + 0.02)), -a + PI * 0.5), Vector3(0.7, drum_h * 0.5, 0.06), 1.0, Color(0.25, 0.22, 0.2), false)
	mb.add_cylinder(mat("lime"), xf(c + Vector3(0, drum_h - 0.1, 0)), r * 1.12, r * 1.12, 0.4, 16, 0.6, Color(0.84, 0.82, 0.78), true, false, false)
	var rings: Array = []
	for k in range(7):
		var a := PI * 0.5 * k / 6.0
		rings.append([sin(a) * r, cos(a) * r + 0.02, cos(a) * r + 0.02])
	mb.add_loft(mat("roof"), xf(c + Vector3(0, drum_h + 0.3, 0)), rings, MeshBuilder.profile_circle(16), 0.5, tint)
	var top := c + Vector3(0, drum_h + 0.3 + r, 0)
	mb.add_cylinder(mat("lime"), xf(top - Vector3(0, 0.3, 0)), r * 0.18, r * 0.16, r * 0.35, 8, 0.6, Color(0.95, 0.93, 0.9))
	mb.add_cylinder(mat("gold"), xf(top + Vector3(0, r * 0.05, 0)), r * 0.05, 0.02, r * 0.6, 4)


## A cypress (a dark tapering blob on a stub of trunk): the palace hill's and the plaza's.
static func cypress(mb: MeshBuilder, at: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	mb.add_cylinder(mat("dark"), xf(at - Vector3(0, 0.3, 0)), 0.18, 0.14, 1.2, 5, 1.0, Color(0.5, 0.4, 0.3))
	mb.add_blob(mat("leaves"), xf(at + Vector3(0, h * 0.55, 0)), Vector3(h * 0.16, h * 0.5, h * 0.16), rng, 0.15, 4, 6, 0.6, Color(0.55, 0.68, 0.5))


## The arena's outer walls: two tiers of arches round an ellipse, an attic ring, the seating inside as a sloped
## ring and its sand floor; the way in from the arena street (the west side) under a closed portcullis.
static func arena(mb: MeshBuilder, cols: Array, c: Vector2, r: Vector2, y0: float, n := 40) -> void:
	var lime := mat("lime")
	var pts: Array = []
	for k in range(n):
		var a := TAU * (k - 0.5) / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	var tier := 7.0
	for k in range(n):
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[(k + 1) % n]
		var mid := (a + b) * 0.5
		var along := (b - a).normalized()
		var out := Vector2(along.y, -along.x)
		if out.dot(mid - c) < 0.0:
			out = -out
		var L := a.distance_to(b) + 0.15
		var t := xf(v3(mid, y0), yaw_of(out))
		var west := k == n / 2
		mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, -1.5, -0.6)), Vector3(L, 3.0, 3.0), 0.5, Color(0.86, 0.84, 0.8))
		arch_wall(mb, lime, t, L, tier, 1.6, L * 0.56, 3.6, Color(0.95, 0.93, 0.89))
		arch_wall(mb, lime, t * Transform3D(Basis(), Vector3(0, tier, -0.15)), L, tier, 1.4, L * 0.5, 3.8, Color(0.97, 0.95, 0.91))
		mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, tier * 2.0 + 1.6, -0.2)), Vector3(L, 3.2, 1.2), 0.5, Color(0.93, 0.91, 0.87))
		for y in [tier, tier * 2.0]:
			mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, y, 0.25)), Vector3(L, 0.4, 0.5), 0.6, Color(0.82, 0.8, 0.76), false)
		mb.add_box(mat("dark"), t * Transform3D(Basis(), Vector3(0, tier + 1.6, -0.9)), Vector3(L, 3.2, 0.1), 0.5, Color(0.2, 0.18, 0.17), false)
		if west:
			portcullis(mb, cols, t * Transform3D(Basis(), Vector3(0, 0, 0.3)), L * 0.56, 3.6 + L * 0.28)
		else:
			mb.add_box(mat("dark"), t * Transform3D(Basis(), Vector3(0, 1.6, -0.9)), Vector3(L, 3.2, 0.1), 0.5, Color(0.2, 0.18, 0.17), false)
		box(cols, t * Transform3D(Basis(), Vector3(0, tier, -0.4)), Vector3(L, tier * 2.0 + 4.0, 2.0))
		if k % 5 == 0:
			flag(mb, t * Vector3(0, tier * 2.0 + 3.2, -0.2), BLUE if k % 10 == 0 else GOLD)
	var seats := 9
	for i in range(seats):
		var k0 := 0.97 - 0.05 * i
		var rings: Array = []
		for k in range(n + 1):
			var a := TAU * k / n
			rings.append(c + Vector2(cos(a) * r.x * k0, sin(a) * r.y * k0))
		var y := y0 + tier * 2.0 + 1.0 - i * 1.6
		for k in range(n):
			var p0: Vector2 = rings[k]
			var p1: Vector2 = rings[k + 1]
			var q0 := c + (p0 - c) * (k0 - 0.05) / k0
			var q1 := c + (p1 - c) * (k0 - 0.05) / k0
			mb.add_quad(lime, v3(p0, y), v3(p1, y), v3(q1, y), v3(q0, y), Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.84, 0.82, 0.78), Vector3.UP)
			mb.add_quad(lime, v3(q0, y), v3(q1, y), v3(q1, y - 1.6), v3(q0, y - 1.6), Vector2.ZERO, Vector2(1, 0), Vector2(1, 0.8), Vector2(0, 0.8), Color(0.72, 0.7, 0.66), Vector3((c - q0).x, 0, (c - q0).y).normalized())
	var inner := 0.97 - 0.05 * seats
	var sand := PSXMat.lit("sand")
	var fl: Array = []
	for k in range(n + 1):
		var a := TAU * k / n
		fl.append(c + Vector2(cos(a) * r.x * inner, sin(a) * r.y * inner))
	for k in range(n):
		mb.add_tri(sand, v3(c, y0 + 0.4), v3(fl[k], y0 + 0.4), v3(fl[k + 1], y0 + 0.4), Vector3.UP, Vector3.UP, Vector3.UP, Vector2.ZERO, (fl[k] - c) * 0.3, (fl[k + 1] - c) * 0.3, Color.WHITE, Vector3.UP)


## The palace on its hill: a curtain wall round the plateau with round towers, the great hall with its dome, two
## wings round a forecourt facing the harbour, a tall central tower and four slender corner towers with banners.
static func palace(mb: MeshBuilder, cols: Array, c: Vector2, y0: float, ground: Callable, low: Callable) -> void:
	var lime := mat("lime")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var ring: Array = []
	var n := 14
	for k in range(n + 1):
		var a := TAU * k / n + 0.11
		ring.append(c + Vector2(cos(a), sin(a)) * (CapitalPlan.HILL_R0 - 3.0))
	wall_run(mb, cols, ring, 7.0, 2.6, ground, low, 7.0)
	for k in range(n):
		var p: Vector2 = ring[k]
		round_tower(mb, cols, p, ground.call(p), 3.0, 10.0 + 2.0 * float(k % 2), true, 6.0, k % 2 == 0)
	var fwd := Vector2(0, 1)
	var hall := c + Vector2(0, -6)
	var t := xf(v3(hall, 0.0))
	facade_box(mb, mat("facade_b"), t, 38.0, 22.0, y0 + 0.8, 15.0, Color(1.0, 0.98, 0.94))
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, y0 - 1.0 + 0.9, 0)), Vector3(38.6, 3.6, 22.6), 0.5, Color(0.9, 0.88, 0.84), true, true)
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, y0 + 16.0, 0)), Vector3(39.0, 0.5, 23.0), 0.6, Color(0.92, 0.9, 0.86), false)
	_hip(mb, t * Transform3D(Basis(), Vector3(0, y0 + 16.2, 0)), 38.0, 22.0, 6.5, 0.4, Color(0.95, 0.88, 0.84))
	dome(mb, v3(hall, y0 + 19.0), 7.5, 4.0, Color(0.55, 0.62, 0.78))
	box(cols, t * Transform3D(Basis(), Vector3(0, y0 + 8.0, 0)), Vector3(38.0, 16.0, 22.0))
	for s in [-1.0, 1.0]:
		var wc := c + Vector2(s * 16.0, 16.0)
		var wt := xf(v3(wc, 0.0))
		facade_box(mb, mat("facade_a"), wt, 12.0, 26.0, y0 + 0.8, 11.0, Color(0.99, 0.96, 0.9))
		mb.add_box(lime, wt * Transform3D(Basis(), Vector3(0, y0 - 0.1, 0)), Vector3(12.6, 1.8, 26.6), 0.5, Color(0.9, 0.88, 0.84), true, true)
		mb.add_box(lime, wt * Transform3D(Basis(), Vector3(0, y0 + 12.0, 0)), Vector3(12.8, 0.4, 26.8), 0.6, Color(0.92, 0.9, 0.86), false)
		_hip(mb, wt * Transform3D(Basis(), Vector3(0, y0 + 12.2, 0)), 12.0, 26.0, 4.2, 0.4, Color.WHITE)
		box(cols, wt * Transform3D(Basis(), Vector3(0, y0 + 6.0, 0)), Vector3(12.0, 12.0, 26.0))
		round_tower(mb, cols, c + Vector2(s * 21.5, 30.5), y0, 3.4, 30.0, true, 2.0, true)
		round_tower(mb, cols, c + Vector2(s * 20.5, -18.5), y0, 3.0, 26.0, true, 2.0, true)
	var keep := c + Vector2(0, -20.0)
	square_tower(mb, cols, keep, y0, 10.0, 42.0, 0.0, true, 2.0)
	for s in [-1.0, 1.0]:
		mb.add_box(mat("dark"), xf(v3(keep + Vector2(s * 2.2, 5.04), y0 + 35.0)), Vector3(1.4, 3.0, 0.06), 1.0, Color(0.25, 0.22, 0.2), false)
		flag(mb, v3(keep + Vector2(s * 5.4, 0), y0 + 43.2), BLUE)
	var porch := c + Vector2(0, 5.6)
	for k in range(6):
		var x := -7.5 + k * 3.0
		mb.add_cylinder(lime, xf(v3(porch + Vector2(x, 0), y0 + 0.8)), 0.55, 0.48, 9.0, 8, 0.6, Color(0.97, 0.95, 0.92))
	mb.add_box(lime, xf(v3(porch, y0 + 10.2)), Vector3(18.0, 1.4, 3.0), 0.5, Color(0.95, 0.93, 0.89), false)
	mb.add_gable_roof(lime, xf(v3(porch, y0 + 10.9), PI * 0.5), 3.0, 18.0, 2.4, 0.2, 0.5, Color(0.93, 0.91, 0.87), lime)
	for k in range(4):
		mb.add_box(lime, xf(v3(c + Vector2(0, 9.0 + k * 1.2), y0 + 0.4 - k * 0.2)), Vector3(18.0, 0.4, 1.2), 0.5, Color(0.9, 0.88, 0.84))
	for k in range(10):
		var p := c + Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(24.0, 40.0)) * Vector2(1.0, 1.0)
		if absf(p.x) > 6.0:
			cypress(mb, v3(p, ground.call(p)), rng.randf_range(6.0, 9.0), rng)
