class_name CapitalRoofs
extends RefCounted
## The capital's rooftops (1.27, docs/v1_27_plan.md C1b; Zach: "players will reach the roofs; make it polished, walkable,
## detailed"). After the town houses are built (each lot keeps its roof's frame, size and height: CapitalDistrict.
## townhouse), every roof you can reach is solid: a flat roof's slabs and parapets, a pitched roof's two slopes (36
## degrees: under the captain's 50 degree walkable limit). Flat roofs are dressed as places people use (water barrels,
## crates, washing on a line, potted plants, a skylight, a chair and a table); planks cross a lane where two flat roofs
## face each other near the same height; ladders go up from the lanes, the alleys and the courtyards (Ladder nodes,
## made on the main thread from `out["ladders"]`). Pure data and meshes: safe on the worker.

const M := preload("res://scripts/island/capital_models.gd")
const P := preload("res://scripts/island/capital_plan.gd")
## A flat roof's parapet: its height and thickness (CapitalModels.roof draws the same).
const PARAPET := 0.8
const PARAPET_T := 0.3
## How likely a flat roof on a rolled floor gets a ladder up its front, and how many planks a lane may carry.
const LADDER_P := 0.4
const PLANK_W := 0.9
## A plank only between roofs this close in height (m).
const PLANK_DY := 1.6


static func build(out: Dictionary, lots: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var ladders: Array = []
	var flats: Array = []
	for l in lots:
		if not l.has("top_y"):
			continue
		var t: Transform3D = l["frame"]
		var wd: Vector2 = l["wd"]
		var y: float = l["top_y"]
		if str(l["roof"]) == "flat":
			_flat(mb, cols, t, wd.x, wd.y, y, int(l["seed"]))
			flats.append(l)
			if _on_rolled(l) and _roll(int(l["seed"]), 3) < LADDER_P:
				var lx := (wd.x * 0.5 - 0.9) * (1.0 if _roll(int(l["seed"]), 5) < 0.5 else -1.0)
				ladders.append({"xf": t * Transform3D(Basis(), Vector3(lx, y, wd.y * 0.5 + 0.02)), "length": y - float(l["ground_y"]) + 0.2,
					"rail": PARAPET})
		else:
			_slopes(cols, t, wd.x, wd.y, y)
	_planks(mb, cols, flats)
	out["ladders"] = ladders
	CapitalDistrict._piece(out, "Rooftops", mb, cols)


## A flat roof: its slab and parapets solid (the house's own box stops at the eaves), and what's kept up there.
static func _flat(mb: MeshBuilder, cols: Array, t: Transform3D, w: float, d: float, y: float, seed_value: int) -> void:
	M.box(cols, t * Transform3D(Basis(), Vector3(0, y - 0.1, 0)), Vector3(w, 0.3, d))
	for s in [-1.0, 1.0]:
		M.box(cols, t * Transform3D(Basis(), Vector3(s * (w * 0.5 - PARAPET_T * 0.5), y + PARAPET * 0.5, 0)), Vector3(PARAPET_T, PARAPET, d))
		M.box(cols, t * Transform3D(Basis(), Vector3(0, y + PARAPET * 0.5, s * (d * 0.5 - PARAPET_T * 0.5))), Vector3(w - PARAPET_T * 2.0, PARAPET, PARAPET_T))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, 4447])
	var used: Array = []
	var spot := func(r: float) -> Vector3:
		for _i in range(8):
			var p := Vector3(rng.randf_range(-w * 0.5 + 0.6 + r, w * 0.5 - 0.6 - r), y + 0.05, rng.randf_range(-d * 0.5 + 0.6 + r, d * 0.5 - 0.6 - r))
			if used.all(func(u): return Vector2(u.x, u.z).distance_to(Vector2(p.x, p.z)) > float(u.y) + r):
				used.append(Vector3(p.x, r, p.z))
				return p
		return Vector3.INF
	var lime := M.mat("lime")
	for k in range(rng.randi_range(2, 4)):
		match rng.randi() % 6:
			0:
				# a water tank: a barrel on a timber stand
				var p: Vector3 = spot.call(0.8)
				if p != Vector3.INF:
					var st := t * Transform3D(Basis(), p)
					mb.add_box(PSXMat.lit("planks"), st * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(1.3, 0.5, 1.3), 0.5, Color.WHITE)
					CapitalDistrict.absorb(mb, cols, Props.barrel(), st * Transform3D(Basis(), Vector3(0, 0.5, 0)))
					M.box(cols, st * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(1.3, 0.5, 1.3))
			1:
				var p: Vector3 = spot.call(0.6)
				if p != Vector3.INF:
					CapitalDistrict.absorb(mb, cols, Props.crate(rng.randf_range(0.6, 0.8)), t * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
			2:
				# washing on a line between two poles
				var p: Vector3 = spot.call(1.3)
				if p != Vector3.INF:
					var a := rng.randf() * PI
					var dir := Vector3(cos(a), 0, sin(a))
					var p0 := p - dir * 1.2
					var p1 := p + dir * 1.2
					for q in [p0, p1]:
						mb.add_box(PSXMat.lit("planks"), t * Transform3D(Basis(), q + Vector3(0, 0.9, 0)), Vector3(0.08, 1.8, 0.08), 0.5, Color.WHITE)
					Buildings.beam_between(mb, M.mat("dark"), t * (p0 + Vector3(0, 1.75, 0)), t * (p1 + Vector3(0, 1.75, 0)), 0.015)
					var pal: Array = CapitalStyle.STYLE["pennants"]
					for i in range(3):
						var q: Vector3 = p0.lerp(p1, 0.25 + i * 0.25) + Vector3(0, 1.45, 0)
						mb.add_box(M.mat("cloth"), t * Transform3D(Basis(Vector3.UP, a), q), Vector3(0.5, 0.6, 0.02), 1.0, pal[(seed_value + i) % pal.size()])
			3:
				# potted plants in a row
				var p: Vector3 = spot.call(0.9)
				if p != Vector3.INF:
					for i in range(3):
						var q := p + Vector3(-0.6 + i * 0.6, 0, 0)
						mb.add_cylinder(PSXMat.flat(Color(0.72, 0.4, 0.28)), t * Transform3D(Basis(), q), 0.2, 0.15, 0.32, 8, 0.5, Color(0.72, 0.4, 0.28))
						mb.add_cylinder(M.mat("leaves"), t * Transform3D(Basis(), q + Vector3(0, 0.32, 0)), 0.18, 0.28, 0.42, 6, 0.5, Color(0.4, 0.62, 0.3))
			4:
				# a skylight: a low lime box with a glazed top
				var p: Vector3 = spot.call(0.9)
				if p != Vector3.INF:
					mb.add_box(lime, t * Transform3D(Basis(), p + Vector3(0, 0.25, 0)), Vector3(1.2, 0.5, 1.2), 0.5, Color(0.94, 0.92, 0.88))
					mb.add_box(M.mat("window"), t * Transform3D(Basis(), p + Vector3(0, 0.52, 0)), Vector3(1.0, 0.04, 1.0), 1.0, Color.WHITE)
					M.box(cols, t * Transform3D(Basis(), p + Vector3(0, 0.27, 0)), Vector3(1.2, 0.54, 1.2))
			_:
				# a table and a chair: someone takes the evening air up here
				var p: Vector3 = spot.call(0.8)
				if p != Vector3.INF:
					var tt := t * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)
					mb.add_box(PSXMat.lit("planks"), tt * Transform3D(Basis(), Vector3(0, 0.72, 0)), Vector3(0.8, 0.05, 0.8), 0.6, Color.WHITE)
					mb.add_box(PSXMat.lit("planks"), tt * Transform3D(Basis(), Vector3(0, 0.36, 0)), Vector3(0.1, 0.72, 0.1), 0.6, Color.WHITE)
					mb.add_box(PSXMat.lit("planks"), tt * Transform3D(Basis(), Vector3(0.7, 0.42, 0)), Vector3(0.42, 0.06, 0.42), 0.6, Color.WHITE)
					mb.add_box(PSXMat.lit("planks"), tt * Transform3D(Basis(), Vector3(0.9, 0.7, 0)), Vector3(0.05, 0.6, 0.42), 0.6, Color.WHITE)
					M.box(cols, tt * Transform3D(Basis(), Vector3(0, 0.38, 0)), Vector3(0.8, 0.76, 0.8))


## A pitched roof's two slopes as tilted slabs along its ridge (the longer side, as CapitalModels.roof lays it; a hip
## roof's ends are close enough): walk up one and down the other.
static func _slopes(cols: Array, t: Transform3D, w: float, d: float, y: float) -> void:
	var along_x := w >= d
	var length := maxf(w, d) + 0.7
	var span := minf(w, d)
	var h := span * M.ROOF_PITCH
	var a := atan2(h, span * 0.5)
	var slope := (span * 0.5 + 0.35) / cos(a)
	for s in [-1.0, 1.0]:
		var off := span * 0.25 + 0.0875
		var b: Basis
		var c: Vector3
		if along_x:
			b = Basis(Vector3.RIGHT, s * a)
			c = Vector3(0, y + h * 0.5 - 0.12, s * off)
		else:
			b = Basis(Vector3.FORWARD, s * a)
			c = Vector3(s * off, y + h * 0.5 - 0.12, 0)
		var size := Vector3(length, 0.24, slope) if along_x else Vector3(slope, 0.24, length)
		M.box(cols, t * Transform3D(b, c), size)


## Planks across a lane: two flat roofs facing each other over a rolled floor, near the same height; the plank rests on
## the parapets' tops with a step inside each end.
static func _planks(mb: MeshBuilder, cols: Array, flats: Array) -> void:
	var done := {}
	for i in range(flats.size()):
		var a: Dictionary = flats[i]
		if done.has(i):
			continue
		for j in range(i + 1, flats.size()):
			if done.has(j):
				continue
			var b: Dictionary = flats[j]
			var fa: Vector2 = a["face"]
			var fb: Vector2 = b["face"]
			if fa.dot(fb) > -0.9 or absf(float(a["top_y"]) - float(b["top_y"])) > PLANK_DY:
				continue
			var ca: Vector2 = a["c"]
			var cb: Vector2 = b["c"]
			var ab := cb - ca
			# facing each other across a lane: the gap along their faces' axis, their frontages overlapping
			if ab.dot(fa) < 0.0 or absf(ab.dot(Vector2(fa.y, -fa.x))) > 2.0:
				continue
			var ra: Rect2 = a["r"]
			var rb: Rect2 = b["r"]
			var gap := absf(ab.dot(fa)) - (ra.size.y if absf(fa.y) > 0.5 else ra.size.x) * 0.5 - (rb.size.y if absf(fb.y) > 0.5 else rb.size.x) * 0.5
			if gap < 2.0 or gap > 6.0 or _roll(int(a["seed"]) ^ int(b["seed"]), 7) > 0.5:
				continue
			var ya := float(a["top_y"]) + PARAPET + 0.04
			var yb := float(b["top_y"]) + PARAPET + 0.04
			var ea := ca + fa * ((ra.size.y if absf(fa.y) > 0.5 else ra.size.x) * 0.5 - 0.6)
			var eb := cb + fb * ((rb.size.y if absf(fb.y) > 0.5 else rb.size.x) * 0.5 - 0.6)
			var pa := M.v3(ea, ya)
			var pb := M.v3(eb, yb)
			var mid := (pa + pb) * 0.5
			var dir := (pb - pa)
			var yaw := M.yaw_of(Vector2(dir.x, dir.z).normalized())
			var tilt := atan2(dir.y, Vector2(dir.x, dir.z).length())
			var tr := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt), mid)
			mb.add_box(PSXMat.lit("planks"), tr, Vector3(PLANK_W, 0.08, dir.length() + 0.4), 0.5, Color(0.86, 0.8, 0.7))
			M.box(cols, tr, Vector3(PLANK_W, 0.12, dir.length() + 0.4))
			# a step inside each parapet up to the plank
			for e in [[ea, fa, float(a["top_y"])], [eb, fb, float(b["top_y"])]]:
				var sq: Vector2 = (e[0] as Vector2) - (e[1] as Vector2) * 0.7
				var st := M.xf(M.v3(sq, float(e[2]) + 0.22), M.yaw_of(e[1]))
				mb.add_box(M.mat("lime"), st, Vector3(1.0, 0.44, 0.6), 0.5, Color(0.9, 0.88, 0.84))
				M.box(cols, st, Vector3(1.0, 0.44, 0.6))
			done[i] = true
			done[j] = true
			break


## A house on one of the rolled floors (a lane, an alley, a courtyard), not the fixed streets.
static func _on_rolled(l: Dictionary) -> bool:
	var r: Rect2 = (l["r"] as Rect2).grow(1.5)
	for f in P.rolled():
		if (f[1] as Rect2).intersects(r):
			return true
	return false


static func _roll(seed_value: int, salt: int) -> float:
	return float(absi(hash([seed_value, salt])) % 10000) / 10000.0
