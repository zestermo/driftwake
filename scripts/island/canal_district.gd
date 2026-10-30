class_name CanalDistrict
extends RefCounted
## The canal city's streets, made to be lived in (docs/v1_21_plan.md: dense and warm, never large and empty): every
## house on a walkway with its door up a step, coloured shutters, flower boxes, a balcony on some and a shop under an
## awning on others; washing strung across the lanes; boats moored all along the canals at striped poles; each campo's
## well and bench; the piazza's church front, café tables and flagstaffs; the market hall, its stalls and the shops
## on the market bridge; the inn; the arsenal's slipways with hulls on them, its sheds, cranes, timber and the
## master's office. In CanalPlan's frame, merged a mesh an area, built on the worker; colliders as data; the real
## lights and the people's places as lists (CapitalDistrict's output).

const P := preload("res://scripts/island/canal_plan.gd")
const M := preload("res://scripts/island/capital_models.gd")
const D := preload("res://scripts/island/capital_district.gd")
const S := preload("res://scripts/island/canal_shell.gd")
const RANGE := 300.0
const FAR := 900.0
const SHOP_KINDS := ["baker", "cloth", "spice", "potter", "jeweller", "chart", "fruit", "wine", "books"]
const SHUTTERS := [Color(0.3, 0.46, 0.34), Color(0.24, 0.34, 0.5), Color(0.56, 0.24, 0.2), Color(0.42, 0.36, 0.26)]
const AWNINGS := ["awning_blue", "awning_red", "awning_gold", "awning_green"]
const FLOWERS := [Color(0.9, 0.24, 0.3), Color(0.98, 0.84, 0.3), Color(0.82, 0.5, 0.86), Color(0.96, 0.96, 0.92), Color(0.98, 0.5, 0.24)]


static func build(build_ms: Dictionary) -> Dictionary:
	var out := {"pieces": [], "lights": [], "spots": {}, "doors": []}
	for step in [["houses", _houses], ["washing", _washing], ["boats", _boats], ["campi", _campi], ["piazza", _piazza], ["market", _market],
			["inn", _inn], ["arsenal", _arsenal], ["landings", _landings]]:
		var t0 := Time.get_ticks_usec()
		(step[1] as Callable).call(out)
		build_ms["district " + str(step[0])] = int((Time.get_ticks_usec() - t0) / 1000)
	return out


static func _piece(out: Dictionary, piece_name: String, mb: MeshBuilder, cols: Array, range_end := RANGE, shadow := true) -> void:
	mb.fold_tints()
	var split := Occluders.take(cols)
	(out["pieces"] as Array).append({"name": piece_name, "mesh": mb.commit(), "range": range_end, "shadow": shadow, "cols": split[0], "faces": [], "occ": split[1]})


static func _light(out: Dictionary, at: Vector3, energy := 1.6, rng_ := 11.0, always := false) -> void:
	(out["lights"] as Array).append([at, energy, rng_, always])


static func _spot(out: Dictionary, spot_name: String, q: Vector2, y: float, face: Vector2) -> void:
	out["spots"][spot_name] = [M.v3(q, y), M.yaw_of(face)]


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _q(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _fd(t: Transform3D) -> Vector2:
	var f := t.basis * Vector3.BACK
	return Vector2(f.x, f.z).normalized()


# --------------------------------------------------------------------------
# The walkways' houses
# --------------------------------------------------------------------------
## The houses fronting a walkway, a mesh a block: each one a lagoon house (CanalShell.house) dressed at its front.
static func _houses(out: Dictionary) -> void:
	var by := {}
	for l in P.lots():
		if not l["front"]:
			continue
		var key := _block_of(l["c"])
		if not by.has(key):
			by[key] = []
		by[key].append(l)
	var keys := by.keys()
	keys.sort()
	for key in keys:
		var mb := MeshBuilder.new()
		var cols: Array = []
		var i := 0
		for l in by[key]:
			var kind: String = SHOP_KINDS[(int(l["seed"]) >> 3) % SHOP_KINDS.size()] if i % 3 == 0 else ""
			# (1.27) walk-in, hollowed and furnished as the capital's: the city has many more fronts than the capital, so a
			# third of its shops and one house in twelve (about 50 rooms)
			var sd := int(l["seed"])
			var enter: bool = (kind != "" and (sd >> 9) % 3 == 0) or (kind == "" and (sd >> 7) % 12 == 0)
			var h: Array = S.house(mb, cols, l, true, enter)
			var d := _front(mb, cols, l, h[0], h[1], h[2], h[3], kind, enter)
			var ht: Transform3D = h[0]
			l["frame"] = ht
			l["wd"] = Vector2(h[1], h[2])
			l["top_y"] = P.QUAY_Y + 0.4 + float(h[3])
			l["ground_y"] = P.QUAY_Y
			if enter:
				var dx: float = (ht.affine_inverse() * (d["at"] as Vector3)).x
				var cell: Rect2 = l["cell"]
				var face: Vector2 = l["face"]
				var pad := Vector2((cell.size.x if absf(face.y) > 0.5 else cell.size.y) - float(h[1]), (cell.size.y if absf(face.y) > 0.5 else cell.size.x) - float(h[2])) * 0.5
				d["inside"] = CapitalInteriors.build(mb, cols, ht, h[1], h[2], P.QUAY_Y - 1.0, P.QUAY_Y + 0.2, 3.6, P.QUAY_Y + 0.2 + float(h[3]), dx, 1.2, 0.12, kind, int(l["seed"]), pad)
			if P.in_floor(_q(d["at"])):
				(out["doors"] as Array).append(d)
			i += 1
		_piece(out, "Town_" + str(key), mb, cols)
	# (1.27) the roofs made walkable, dressed, planked, laddered up from the calli and campi
	CapitalRoofs.build(out, P.lots().filter(func(l): return l.has("top_y")), P.floors().filter(func(f): return str(f[0]).contains("_c")))


static func _block_of(c: Vector2) -> String:
	for b in P.BLOCKS:
		if (b[1] as Rect2).has_point(c):
			return str(b[0])
	return "edge"


## A walkway house's front: a door up a stone step, windows with coloured shutters on every storey, a flower box under
## some, an iron balcony on some, and a shop under an awning with its wares and sign if `kind`. Returns its door.
static func _front(mb: MeshBuilder, cols: Array, l: Dictionary, t: Transform3D, w: float, d: float, h: float, kind: String, enter := false) -> Dictionary:
	var rng := _rng(int(l["seed"]) + 7)
	var lime := M.mat("lime")
	var y0 := P.QUAY_Y + 0.2
	var hd := d * 0.5
	var hw := w * 0.5
	var shut: Color = SHUTTERS[rng.randi() % SHUTTERS.size()]
	var wood := PSXMat.lit("planks", shut)
	var door_x := clampf(rng.randf_range(-hw * 0.35, hw * 0.35), -hw + 1.0, hw - 1.0)
	var dt := t * Transform3D(Basis(), Vector3(door_x, y0 - 0.2, hd + 0.03))
	mb.add_box(lime, dt * Transform3D(Basis(), Vector3(0, 0.1, 0.35)), Vector3(1.6, 0.2, 0.7), 0.6, Color(0.88, 0.86, 0.82))
	if enter:
		Buildings.panel_door(mb, dt * Transform3D(Basis(Vector3.UP, -1.35), Vector3(-0.55, 0.2, -0.05)) * Transform3D(Basis(), Vector3(0.55, 0, 0)), 1.2, 2.3, Buildings.door_leaf(shut * 0.8), lime)
	else:
		Buildings.panel_door(mb, dt * Transform3D(Basis(), Vector3(0, 0.2, 0)), 1.2, 2.3, Buildings.door_leaf(shut * 0.8), lime)
	# the storeys' windows: shutters either side, a flower box under some
	var storeys := maxi(int(round((h - 3.6) / M.STOREY)), 1)
	for s in range(storeys):
		var wy := y0 + 3.6 + s * M.STOREY + 0.9
		for k in range(maxi(int(w / 3.0), 1)):
			var wx := -hw + (k + 0.5) * w / maxi(int(w / 3.0), 1)
			var wt := t * Transform3D(Basis(), Vector3(wx, wy, hd + 0.04))
			for side in [-1.0, 1.0]:
				mb.add_box(wood, wt * Transform3D(Basis(), Vector3(side * 0.62, 0.6, 0.02)), Vector3(0.42, 1.25, 0.05), 1.0, Color(0.9, 0.9, 0.9), false)
			if rng.randf() < 0.4:
				var fb := wt * Transform3D(Basis(), Vector3(0, -0.12, 0.2))
				mb.add_box(PSXMat.lit("planks_dark"), fb, Vector3(1.0, 0.22, 0.32), 1.0, Color(0.7, 0.55, 0.45), false)
				for j in range(4):
					mb.add_blob(PSXMat.flat(Color.WHITE), fb * Transform3D(Basis(), Vector3(-0.36 + j * 0.24, 0.18, 0)), Vector3(0.13, 0.11, 0.13), rng, 0.3, 2, 4, 1.0,
						FLOWERS[rng.randi() % FLOWERS.size()] if j % 2 == 0 else Color(0.3, 0.5, 0.26))
		if s == 0 and rng.randf() < 0.35 and w >= 4.5:
			D._balcony(mb, t * Transform3D(Basis(), Vector3(0, y0 + 3.6 + 0.05, hd)), minf(w - 1.4, 3.6))
	if kind != "":
		var sx := -hw * 0.5 if door_x > 0.0 else hw * 0.5
		var st := t * Transform3D(Basis(), Vector3(sx, y0 + 0.9, hd + 0.03))
		mb.add_box_unit_uv(M.mat("window"), st * Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(minf(hw - 0.6, 2.0), 1.5, 0.04))
		D._awning(mb, st * Transform3D(Basis(), Vector3(0, 2.0, 0)), minf(hw, 2.6), 1.2, AWNINGS[rng.randi() % AWNINGS.size()])
		D._wares(mb, st * Transform3D(Basis(), Vector3(0, -0.85, 0.6)), minf(hw - 0.6, 1.8), kind, rng)
		D._sign(mb, t * Transform3D(Basis(), Vector3(door_x + (0.9 if door_x < sx else -0.9), y0 + 3.2, hd + 0.03)), kind, rng)
	elif rng.randf() < 0.3:
		# a bench or a pot plant by the door
		if rng.randf() < 0.5:
			mb.add_cylinder(PSXMat.lit("plaster", Color(0.78, 0.46, 0.32)), dt * Transform3D(Basis(), Vector3(1.0, 0.0, 0.4)), 0.22, 0.28, 0.45, 6, 1.0)
			mb.add_blob(PSXMat.flat(Color(0.32, 0.52, 0.28)), dt * Transform3D(Basis(), Vector3(1.0, 0.65, 0.4)), Vector3(0.32, 0.3, 0.32), rng, 0.35, 2, 5)
		else:
			mb.add_box(PSXMat.lit("planks"), dt * Transform3D(Basis(), Vector3(-1.3, 0.25, 0.3)), Vector3(1.2, 0.08, 0.36), 1.0, Color(0.8, 0.7, 0.6))
	D.warmth(mb, int(l["seed"]), t, w, h, hd, door_x, y0)
	return {"at": t * Vector3(door_x, P.QUAY_Y, hd + 0.9), "face": _fd(t), "kind": kind, "inside": Vector3.INF}


# --------------------------------------------------------------------------
## Washing strung across the narrow lanes between the houses either side, now and then.
static func _washing(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var rng := _rng(5521)
	for f in P.floors():
		var name := str(f[0])
		if not (name.contains("_c") and not name.contains("campo")):
			continue
		var r: Rect2 = f[1]
		var along_x := r.size.x > r.size.y
		var L := r.size.x if along_x else r.size.y
		var k := 6.0
		while k < L - 4.0:
			if rng.randf() < 0.55:
				var y := P.QUAY_Y + rng.randf_range(5.5, 8.5)
				var a: Vector2
				var b: Vector2
				if along_x:
					a = Vector2(r.position.x + k, r.position.y - 0.2)
					b = Vector2(r.position.x + k + rng.randf_range(-1.0, 1.0), r.end.y + 0.2)
				else:
					a = Vector2(r.position.x - 0.2, r.position.y + k)
					b = Vector2(r.end.x + 0.2, r.position.y + k + rng.randf_range(-1.0, 1.0))
				D._washing(mb, M.v3(a, y), M.v3(b, y - 0.1), rng)
			k += rng.randf_range(5.0, 9.0)
	_piece(out, "Washing", mb, [], RANGE, false)


# --------------------------------------------------------------------------
## Boats moored along the canals at striped poles (rowboats and the city's long black boats), off the bridges and the
## water taxi landings.
static func _boats(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(8812)
	var pole_cols := [Color(0.82, 0.2, 0.18), Color(0.2, 0.3, 0.62), Color(0.9, 0.78, 0.3)]
	for c in P.CANALS:
		if str(c[0]) == "basin":
			continue
		var r: Rect2 = c[1]
		var along_x := r.size.x > r.size.y
		var L := r.size.x if along_x else r.size.y
		for side in [0, 1]:
			var k := 8.0
			while k < L - 8.0:
				var u := k
				k += rng.randf_range(7.0, 14.0)
				var q: Vector2
				var inward: Vector2
				if along_x:
					q = Vector2(r.position.x + u, r.position.y + 1.6 if side == 0 else r.end.y - 1.6)
					inward = Vector2(0, -1) if side == 0 else Vector2(0, 1)
				else:
					q = Vector2(r.position.x + 1.6 if side == 0 else r.end.x - 1.6, r.position.y + u)
					inward = Vector2(-1, 0) if side == 0 else Vector2(1, 0)
				if P.land_t(q) > -2.0 or _near_bridge(q, 8.0) or _near_landing(q, 7.0) or rng.randf() < 0.3:
					continue
				# a pole or two, striped
				var pc: Color = pole_cols[rng.randi() % pole_cols.size()]
				for j in range(2):
					var pq := q + inward * 0.4 + (Vector2(1, 0) if not along_x else Vector2(0, 1)).orthogonal() * 0.0 + (Vector2(0, 1) if not along_x else Vector2(1, 0)) * (j * 2.6 - 1.3)
					for s in range(4):
						mb.add_cylinder(PSXMat.flat(Color.WHITE), M.xf(M.v3(pq, -0.4 + s * 0.8)), 0.12, 0.11, 0.8, 5, 1.0, pc if s % 2 == 0 else Color(0.95, 0.95, 0.92))
				var yaw := 0.0 if not along_x else PI * 0.5
				if rng.randf() < 0.4:
					_long_boat(mb, M.xf(M.v3(q - inward * 0.6, 0.0), yaw), rng)
				else:
					D.absorb(mb, [], Props.rowboat(), M.xf(M.v3(q - inward * 0.4, -0.15), yaw + rng.randf_range(-0.15, 0.15)))
	_piece(out, "Boats", mb, cols, RANGE, false)


static func _near_bridge(q: Vector2, r: float) -> bool:
	for br in P.BRIDGES:
		if q.distance_to((br[0] as Vector2).lerp(br[1], 0.5)) < r + float(br[2]) * 0.5:
			return true
	return false


static func _near_landing(q: Vector2, r: float) -> bool:
	for l in P.LANDINGS:
		if q.distance_to(l[1]) < r:
			return true
	return false


## The city's long black boat (a lacquered hull rising at both ends, a red cushion, an iron prow): local +z along it.
static func _long_boat(mb: MeshBuilder, t: Transform3D, rng: RandomNumberGenerator) -> void:
	var black := PSXMat.lit("planks_dark", Color(0.18, 0.17, 0.17))
	var rings: Array = []
	for i in range(9):
		var u := float(i) / 8.0
		var z := lerpf(-5.0, 5.0, u)
		var hwid := 0.75 * sin(PI * u) + 0.06
		var ytop := 0.45 + 0.6 * pow(absf(u - 0.5) * 2.0, 3.0)
		rings.append([ytop, hwid, hwid * 0.7, z, 0.0])
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for s in [-1.0, 1.0]:
			mb.add_quad(black, t * Vector3(s * float(a[1]), float(a[0]), float(a[3])), t * Vector3(s * float(b[1]), float(b[0]), float(b[3])),
				t * Vector3(s * float(b[2]), -0.1, float(b[3])), t * Vector3(s * float(a[2]), -0.1, float(a[3])), Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
				Color.WHITE, (t.basis * Vector3(s, 0.3, 0)).normalized())
		mb.add_quad(black, t * Vector3(-float(a[1]) * 0.9, 0.3, float(a[3])), t * Vector3(float(a[1]) * 0.9, 0.3, float(a[3])), t * Vector3(float(b[1]) * 0.9, 0.3, float(b[3])),
			t * Vector3(-float(b[1]) * 0.9, 0.3, float(b[3])), Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.6, 0.5, 0.4), Vector3.UP)
	mb.add_box(PSXMat.lit("fabric", Color(0.6, 0.12, 0.12)), t * Transform3D(Basis(), Vector3(0, 0.42, -0.6)), Vector3(0.9, 0.18, 1.4), 1.0)
	mb.add_box(M.mat("iron"), t * Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 1.0, 4.9)), Vector3(0.05, 0.7, 0.3), 1.0, Color(0.85, 0.85, 0.85))


# --------------------------------------------------------------------------
## Each block's campo: a carved wellhead, a bench, a potted tree; a lamp in a few (the light budget).
static func _campi(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(3317)
	var lit := 0
	for f in P.floors():
		if not str(f[0]).ends_with("_campo"):
			continue
		var r: Rect2 = f[1]
		var c := r.get_center()
		var y := P.QUAY_Y
		var lime := M.mat("lime")
		mb.add_cylinder(lime, M.xf(M.v3(c, y)), 1.0, 1.1, 0.9, 10, 0.6, Color(0.92, 0.9, 0.86), true, false)
		mb.add_cylinder(PSXMat.flat(Color(0.08, 0.1, 0.1)), M.xf(M.v3(c, y + 0.91)), 0.75, 0.75, 0.02, 10, 0.6)
		mb.add_box(M.mat("iron"), M.xf(M.v3(c, y + 1.9)), Vector3(0.08, 1.9, 0.08), 1.0, Color.WHITE, false)
		mb.add_box(M.mat("iron"), M.xf(M.v3(c, y + 2.8)), Vector3(1.6, 0.08, 0.08), 1.0, Color.WHITE, false)
		M.cyl(cols, M.v3(c, y), 1.1, 1.0)
		var tq := c + Vector2(5.0, -5.0)
		mb.add_cylinder(PSXMat.lit("plaster", Color(0.8, 0.5, 0.36)), M.xf(M.v3(tq, y)), 0.55, 0.45, 0.6, 8, 1.0, Color.WHITE, true, false)
		M.cypress(mb, M.v3(tq, y + 0.55), rng.randf_range(2.6, 3.6), rng)
		M.cyl(cols, M.v3(tq, y), 0.55, 1.2)
		_spot(out, str(f[0]), c + Vector2(-3.0, 2.0), y, Vector2(1, 0))
		_spot(out, str(f[0]) + "_bench", c + Vector2(-5.0, -4.0), y, Vector2(0, 1))
		if lit < 4:
			var lq := c + Vector2(-5.0, 5.0)
			D.lamp_post(mb, cols, lq, y)
			_light(out, M.v3(lq, y + 3.5), 1.4, 11.0)
			lit += 1
	_piece(out, "Campi", mb, cols)


# --------------------------------------------------------------------------
## The piazza: the church's front (steps, a rose window, a portal, columns), café tables under umbrellas, two
## flagstaffs, lamps; and its people's places.
static func _piazza(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(4401)
	var lime := M.mat("lime")
	var y := P.QUAY_Y
	var sp: Array = P.SPECIAL["church"]
	var r: Rect2 = sp[0]
	var t := M.xf(M.v3(r.get_center(), 0.0), M.yaw_of(sp[1]))
	var w := r.size.x
	var d := r.size.y
	var h := 13.0
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, y - 0.6, 0)), Vector3(w + 0.2, 1.6, d + 0.2), 0.5, Color(0.9, 0.88, 0.84))
	M.facade_box(mb, M.mat("facade_b"), t, w, d, y + 0.2, h, Color(0.96, 0.9, 0.82))
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, y + h + 0.4, 0)), Vector3(w + 0.4, 0.5, d + 0.4), 0.6, Color(0.94, 0.92, 0.88), false)
	M.roof(mb, "gable", t, w, d, y + h + 0.6, Color(0.92, 0.7, 0.58), rng)
	M.box(cols, t * Transform3D(Basis(), Vector3(0, y + h * 0.5, 0)), Vector3(w, h + 2.0, d))
	Occluders.box(cols, t * Transform3D(Basis(), Vector3(0, y + h * 0.5, 0)), Vector3(w - 0.5, h, d - 0.5))
	var front := t * Transform3D(Basis(), Vector3(0, 0, d * 0.5))
	# a white stone front over the facade: pilasters, a portal under an arch, a rose window, a pediment
	mb.add_box(lime, front * Transform3D(Basis(), Vector3(0, y + h * 0.5, 0.15)), Vector3(w * 0.6, h, 0.3), 0.5, Color(0.98, 0.97, 0.94))
	for k in range(4):
		var x := -w * 0.27 + k * w * 0.18
		mb.add_cylinder(lime, front * Transform3D(Basis(), Vector3(x, y, 0.55)), 0.4, 0.35, h - 1.0, 8, 0.6, Color(0.99, 0.98, 0.96))
	M.arch_wall(mb, lime, front * Transform3D(Basis(), Vector3(0, y, 0.32)), 4.6, 6.0, 0.4, 3.0, 3.6, Color(0.95, 0.93, 0.9))
	Buildings.panel_door(mb, front * Transform3D(Basis(), Vector3(0, y, 0.12)), 2.8, 4.6, Buildings.door_leaf(Color(0.36, 0.22, 0.16)), lime)
	mb.add_cylinder(M.mat("window"), front * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, y + 9.0, 0.35)), 1.5, 1.5, 0.1, 12, 1.0, Color(0.9, 0.85, 1.0), true, true)
	var ped := PackedVector2Array([Vector2(-w * 0.31, 0), Vector2(w * 0.31, 0), Vector2(0, 3.0)])
	mb.add_extrude(lime, front * Transform3D(Basis(), Vector3(0, y + h, 0.0)), ped, 0.6, 0.5, Color(0.97, 0.96, 0.92))
	for k in range(3):
		mb.add_box(lime, front * Transform3D(Basis(), Vector3(0, y - 0.3 + k * 0.17, 1.6 - k * 0.45)), Vector3(w * 0.5 - k * 0.8, 0.6, 0.9), 0.6, Color(0.9, 0.88, 0.84))
	_spot(out, "priest", _q(front * Vector3(-3.4, 0, 2.6)), y, _fd(t))
	# café tables under umbrellas along the piazza's east side, chairs round them
	var pz: Rect2 = P.PIAZZA
	for i in range(6):
		var q := Vector2(pz.end.x - 6.0 - (i % 2) * 5.0, pz.position.y + 6.0 + (i / 2) * 9.0)
		D.absorb(mb, cols, Props.table(), M.xf(M.v3(q, y), rng.randf() * TAU))
		mb.add_box(M.mat("dark"), M.xf(M.v3(q, y + 1.3)), Vector3(0.06, 2.6, 0.06), 1.0, Color.WHITE, false)
		mb.add_cone(PSXMat.lit("canvas", [Color(0.9, 0.86, 0.78), Color(0.62, 0.16, 0.14), Color(0.2, 0.3, 0.52)][i % 3]), M.xf(M.v3(q, y + 2.4)), 1.6, 0.7, 8, 1.0)
		_spot(out, "cafe%d" % i, q + Vector2(1.0, 0.0), y, Vector2(-1, 0))
	# flagstaffs before the church, lamps at the riva's edge
	for s in [-1.0, 1.0]:
		var fq := r.get_center() + Vector2(s * 12.0, d * 0.5 + 6.0)
		mb.add_box(lime, M.xf(M.v3(fq, y + 0.4)), Vector3(1.2, 0.8, 1.2), 0.6, Color(0.92, 0.9, 0.86))
		mb.add_cylinder(M.mat("dark"), M.xf(M.v3(fq, y + 0.8)), 0.12, 0.08, 12.0, 6, 1.0, Color(0.6, 0.5, 0.4))
		M.flag(mb, M.v3(fq, y + 12.8), M.BLUE if s < 0.0 else Color(0.62, 0.16, 0.14))
		M.box(cols, M.xf(M.v3(fq, y + 0.4)), Vector3(1.2, 0.8, 1.2))
	for i in range(2):
		var lq := Vector2(pz.position.x + 20.0 + i * 40.0, P.FRONT_Z - 2.5)
		D.lamp_post(mb, cols, lq, y)
		_light(out, M.v3(lq, y + 3.5), 1.6, 12.0)
	# (1.21's detail pass) the piazza's middle: a two-tier fountain with benches round it, two flower barrows
	var fc := pz.get_center()
	mb.add_cylinder(lime, M.xf(M.v3(fc, y)), 3.2, 3.3, 0.6, 12, 0.6, Color(0.93, 0.91, 0.87), true, false)
	mb.add_cylinder(PSXMat.flat(Color(0.2, 0.42, 0.44)), M.xf(M.v3(fc, y + 0.5)), 2.9, 2.9, 0.02, 12, 0.6)
	mb.add_cylinder(lime, M.xf(M.v3(fc, y + 0.5)), 0.45, 0.35, 1.5, 8, 0.6, Color(0.95, 0.93, 0.9))
	mb.add_cylinder(lime, M.xf(M.v3(fc, y + 1.9)), 0.5, 1.4, 0.35, 10, 0.6, Color(0.95, 0.93, 0.9), true, true)
	mb.add_cylinder(PSXMat.flat(Color(0.24, 0.48, 0.5)), M.xf(M.v3(fc, y + 2.24)), 1.25, 1.25, 0.02, 10, 0.6)
	mb.add_cylinder(lime, M.xf(M.v3(fc, y + 2.25)), 0.16, 0.06, 0.9, 6, 0.6, Color(0.95, 0.93, 0.9))
	M.cyl(cols, M.v3(fc, y), 3.3, 1.0)
	for k in range(4):
		var a := PI * 0.25 + k * PI * 0.5
		var bq := fc + Vector2(cos(a), sin(a)) * 6.2
		D.absorb(mb, cols, Props.bench(), M.xf(M.v3(bq, y), atan2(fc.x - bq.x, fc.y - bq.y)))
	for k in range(2):
		var cq := fc + Vector2(-26.0 + k * 50.0, -12.0 + k * 22.0)
		var ct := M.xf(M.v3(cq, y), rng.randf() * TAU)
		mb.add_box(PSXMat.lit("planks", Color(0.7, 0.5, 0.34)), ct * Transform3D(Basis(), Vector3(0, 0.7, 0)), Vector3(1.6, 0.4, 0.9), 1.0)
		for sx in [-0.9, 0.9]:
			mb.add_cylinder(M.mat("dark"), ct * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx, 0.35, 0)), 0.35, 0.35, 0.08, 8, 1.0, Color(0.6, 0.45, 0.32))
		for j in range(10):
			mb.add_blob(PSXMat.flat(Color.WHITE), ct * Transform3D(Basis(), Vector3(-0.6 + (j % 5) * 0.3, 1.0, -0.2 + (j / 5) * 0.4)), Vector3(0.16, 0.14, 0.16), rng, 0.3, 2, 4, 1.0,
				FLOWERS[rng.randi() % FLOWERS.size()] if j % 3 != 0 else Color(0.3, 0.5, 0.26))
		M.box(cols, ct * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.9, 1.2, 1.0))
	for i in range(4):
		_spot(out, "piazza%d" % i, pz.get_center() + Vector2(-20.0 + i * 12.0, rng.randf_range(-6.0, 6.0)), y, Vector2(0, 1) if i % 2 == 0 else Vector2(1, 0))
	_piece(out, "Piazza", mb, cols, FAR)


# --------------------------------------------------------------------------
## The market by the Grand Canal: an open hall on columns (stalls under it), more stalls along the walkway, and the
## market bridge lined with little shops either side.
static func _market(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(6611)
	var lime := M.mat("lime")
	var y := P.QUAY_Y
	var sp: Array = P.SPECIAL["market"]
	var r: Rect2 = sp[0]
	var t := M.xf(M.v3(r.get_center(), 0.0), M.yaw_of(sp[1]))
	var w := r.size.y
	var d := r.size.x
	for i in range(5):
		for s in [-1.0, 1.0]:
			var cp := t * Vector3(-w * 0.5 + 1.0 + i * (w - 2.0) / 4.0, y, s * (d * 0.5 - 1.0))
			mb.add_cylinder(lime, M.xf(cp), 0.4, 0.34, 5.2, 8, 0.6, Color(0.96, 0.94, 0.9))
			M.cyl(cols, cp, 0.4, 5.2)
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, y + 5.4, 0)), Vector3(w, 0.4, d), 0.6, Color(0.92, 0.9, 0.86), false)
	M._hip(mb, t * Transform3D(Basis(), Vector3(0, y + 5.6, 0)), w + 0.6, d + 0.6, 2.6, 0.5, Color(0.95, 0.75, 0.62))
	for i in range(3):
		var st := Buildings.stall("fruit" if i != 1 else "fish")
		var tt := t * Transform3D(Basis(), Vector3(-w * 0.3 + i * w * 0.3, y, -1.0))
		_spot(out, "stall%d" % i, _q(tt * (st.get_node("Vendor") as Node3D).position), y, _fd(tt))
		D.absorb(mb, cols, st, tt)
	# the market bridge's shops: a row of little roofed booths either side of the deck
	var br: Array = P.BRIDGES[2]
	var a: Vector2 = br[0]
	var c: Vector2 = br[1]
	for s in [-1.0, 1.0]:
		for k in range(3):
			var u := 0.25 + k * 0.25
			var q := a.lerp(c, u) + Vector2(0, s * (float(br[2]) * 0.5 - 1.0))
			var by := P.QUAY_Y + float(br[3]) * sin(PI * u)
			var bt := M.xf(M.v3(q, by), 0.0 if s > 0.0 else PI)
			mb.add_box(PSXMat.lit("planks", Color(0.86, 0.72, 0.56)), bt * Transform3D(Basis(), Vector3(0, 1.3, 0.3)), Vector3(3.2, 2.6, 1.4), 0.8)
			mb.add_box(PSXMat.lit("roof_tiles", Color.WHITE, {"affine": 0.8}), bt * Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 2.8, -0.1)), Vector3(3.5, 0.12, 2.0), 1.0, Color(0.95, 0.7, 0.58))
			D._wares(mb, bt * Transform3D(Basis(), Vector3(0, -0.05, -0.5)), 2.6, SHOP_KINDS[(k * 3 + int(s > 0.0)) % SHOP_KINDS.size()], rng)
			M.box(cols, bt * Transform3D(Basis(), Vector3(0, 1.3, 0.3)), Vector3(3.2, 2.6, 1.4))
	_spot(out, "bridge_seller", a.lerp(c, 0.5) + Vector2(0, -2.0), P.QUAY_Y + float(br[3]), Vector2(0, 1))
	_piece(out, "Market", mb, cols)


# --------------------------------------------------------------------------
## The inn on the Grand Canal: a broad four-storey house with a loggia over its door, lanterns, tables out front.
static func _inn(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(7721)
	var sp: Array = P.SPECIAL["inn"]
	var r: Rect2 = sp[0]
	var l := {"r": r, "cell": r, "c": r.get_center(), "face": sp[1], "seed": 99121, "floors": 4, "roof": "hip"}
	var h: Array = S.house(mb, cols, l, true)
	var t: Transform3D = h[0]
	var d := _front(mb, cols, l, t, h[1], h[2], h[3], "wine")
	var y := P.QUAY_Y
	for s in [-1.0, 1.0]:
		D._lantern(mb, t * Transform3D(Basis(), Vector3(s * 2.2, y + 2.6, float(h[2]) * 0.5 + 0.03)))
	for k in range(2):
		D.absorb(mb, cols, Props.table(), t * Transform3D(Basis(Vector3.UP, rng.randf()), Vector3(-2.0 + k * 4.4, y, float(h[2]) * 0.5 + 2.4)))
	_light(out, t * Vector3(0, y + 2.8, float(h[2]) * 0.5 + 1.0), 1.4, 9.0)
	out["spots"]["inn_door"] = [d["at"], M.yaw_of(d["face"])]
	_spot(out, "innkeeper", _q(t * Vector3(-1.6, 0, float(h[2]) * 0.5 + 1.2)), y, _fd(t))
	_spot(out, "inn_patron0", _q(t * Vector3(-3.0, 0, float(h[2]) * 0.5 + 2.4)), y, Vector2(0, 0) + _fd(t).orthogonal())
	_spot(out, "inn_patron1", _q(t * Vector3(3.4, 0, float(h[2]) * 0.5 + 2.4)), y, -_fd(t).orthogonal())
	_piece(out, "Inn", mb, cols)


# --------------------------------------------------------------------------
## The arsenal: three slipways down into the basin, hulls building on two of them (keels, ribs, a few planks), the
## covered sheds with a hull inside, a crane by the water, timber in stacks, the master's office with its banner.
static func _arsenal(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(2291)
	var y := P.QUAY_Y
	var dark := PSXMat.lit("planks_dark")
	var ar: Rect2 = P.ARSENAL
	for i in range(3):
		var x := ar.position.x + 7.0 + i * 12.0
		var top := Vector2(x, ar.position.y + 14.0)
		var low := Vector2(x, ar.position.y - 12.0)
		var t0 := M.v3(top, y)
		var t1 := M.v3(low, -1.6)
		var st := Transform3D(Basis.looking_at(t1 - t0, Vector3.UP), (t0 + t1) * 0.5)
		mb.add_box(PSXMat.lit("planks_weathered"), st * Transform3D(Basis(), Vector3(0, -0.15, 0)), Vector3(6.0, 0.3, t0.distance_to(t1)), 0.5, Color(0.86, 0.8, 0.72))
		M.box(cols, st * Transform3D(Basis(), Vector3(0, -0.15, 0)), Vector3(6.0, 0.3, t0.distance_to(t1)))
		for s in [-1.0, 1.0]:
			mb.add_box(dark, st * Transform3D(Basis(), Vector3(s * 3.2, 0.1, 0)), Vector3(0.3, 0.5, t0.distance_to(t1)), 0.8)
		if i < 2:
			var keel := top.lerp(low, 0.35)
			var ky := lerpf(y, -1.6, 0.35) + 1.4
			_hull_frame(mb, cols, M.xf(M.v3(keel, ky), 0.0), 16.0 if i == 0 else 12.0, i == 0, rng)
	# the sheds: an open-fronted roof on posts, a smaller hull under it
	var sh: Rect2 = P.SPECIAL["sheds"][0]
	var stt := M.xf(M.v3(sh.get_center(), 0.0), M.yaw_of(P.SPECIAL["sheds"][1]))
	for i in range(4):
		for s in [-1.0, 1.0]:
			var pq := stt * Vector3(-sh.size.y * 0.5 + 1.0 + i * (sh.size.y - 2.0) / 3.0, y, s * (sh.size.x * 0.5 - 0.6))
			mb.add_box(dark, M.xf(pq + Vector3(0, 4.0, 0)), Vector3(0.5, 8.0, 0.5), 0.8)
			M.box(cols, M.xf(pq + Vector3(0, 4.0, 0)), Vector3(0.5, 8.0, 0.5))
	M.roof(mb, "gable", stt, sh.size.y, sh.size.x, y + 8.0, Color(0.85, 0.7, 0.6), rng)
	mb.add_box(PSXMat.lit("planks_weathered"), stt * Transform3D(Basis(), Vector3(0, y + 4.0, -sh.size.x * 0.5 + 0.3)), Vector3(sh.size.y, 8.0, 0.4), 0.5, Color(0.86, 0.8, 0.72))
	M.box(cols, stt * Transform3D(Basis(), Vector3(0, y + 4.0, -sh.size.x * 0.5 + 0.3)), Vector3(sh.size.y, 8.0, 0.4))
	_hull_frame(mb, cols, stt * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, y + 1.2, 0)), 14.0, true, rng)
	# timber, a crane at the basin, rope
	for j in range(4):
		var tq := Vector2(ar.end.x - 5.0, ar.position.y + 24.0 + j * 4.0)
		for k in range(4 - j % 2):
			var lt := M.xf(M.v3(tq + Vector2(0, (k - 1.5) * 0.44), y + 0.22)) * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)
			mb.add_cylinder(PSXMat.lit("bark"), lt * Transform3D(Basis(), Vector3(0, -3.0, 0)), 0.21, 0.2, 6.0, 6, 0.6)
		M.box(cols, M.xf(M.v3(tq, y + 0.45)), Vector3(6.0, 0.9, 1.9))
	D.absorb(mb, cols, Buildings.dock_crane(), M.xf(M.v3(Vector2(ar.end.x + 8.0, -67.5), y), PI))
	# the master's office: a tall house facing the yard with the arsenal's banner and its door
	var ms: Array = P.SPECIAL["masters"]
	var mr: Rect2 = ms[0]
	var ml := {"r": mr, "cell": mr, "c": mr.get_center(), "face": ms[1], "seed": 55121, "floors": 3, "roof": "gable"}
	var mh: Array = S.house(mb, cols, ml, true)
	var mt: Transform3D = mh[0]
	var md := _front(mb, cols, ml, mt, mh[1], mh[2], mh[3], "chart")
	for s in [-1.0, 1.0]:
		D._banner(mb, mt * Transform3D(Basis(), Vector3(s * 5.0, y + 9.0, float(mh[2]) * 0.5 + 0.1)), 1.4, 5.0, Color(0.62, 0.16, 0.14))
	out["spots"]["masters_door"] = [md["at"], M.yaw_of(md["face"])]
	_spot(out, "arsenal_master", _q(mt * Vector3(-2.4, 0, float(mh[2]) * 0.5 + 2.0)), y, _fd(mt))
	for i in range(4):
		_spot(out, "shipwright%d" % i, Vector2(ar.position.x + 4.0 + i * 9.0, ar.position.y + 18.0), y, Vector2(0, -1))
	# the chandler's corner by the yard's way in: a counter of crates, rope coils, a barrel of pitch
	var cq := Vector2(ar.position.x + 2.5, ar.end.y - 5.0)
	var ct := M.xf(M.v3(cq, y), M.yaw_of(Vector2(1, 0)))
	for k in range(2):
		D.absorb(mb, cols, Props.crate(0.85), ct * Transform3D(Basis(), Vector3(-0.5 + k * 1.0, 0, 0.7)))
	D.absorb(mb, cols, Props.rope_coil(), ct * Transform3D(Basis(), Vector3(1.5, 0, 0.4)))
	D.absorb(mb, cols, Props.barrel(), ct * Transform3D(Basis(), Vector3(-1.6, 0, 0.2)))
	_spot(out, "chandler", cq, y, Vector2(1, 0))
	var lq := Vector2(ar.position.x + 18.0, ar.position.y + 28.0)
	D.lamp_post(mb, cols, lq, y)
	_light(out, M.v3(lq, y + 3.5), 1.6, 12.0)
	_piece(out, "Arsenal", mb, cols, FAR)


## A hull on the stocks, `len` long along local +z: a keel on blocks, ribs curving up both sides, a stem and stern
## post; `planked` lays a few strakes over the lower ribs.
static func _hull_frame(mb: MeshBuilder, cols: Array, t: Transform3D, len: float, planked: bool, rng: RandomNumberGenerator) -> void:
	var dark := PSXMat.lit("planks_dark")
	mb.add_box(dark, t * Transform3D(Basis(), Vector3(0, 0, 0)), Vector3(0.4, 0.4, len), 0.8)
	for k in range(4):
		mb.add_box(M.mat("lime"), t * Transform3D(Basis(), Vector3(0, -0.6, -len * 0.4 + k * len * 0.8 / 3.0)), Vector3(1.2, 0.8, 0.6), 0.6, Color(0.8, 0.78, 0.74))
	var n := int(len / 1.4)
	for k in range(n):
		var z := -len * 0.45 + len * 0.9 * k / float(n - 1)
		var beam := 2.6 * sin(PI * (0.12 + 0.76 * k / float(n - 1)))
		for s in [-1.0, 1.0]:
			mb.add_tube(dark, MeshBuilder.curve_points(t * Vector3(0, 0, z), t * Vector3(s * beam * 1.15, 0.8, z), t * Vector3(s * beam, 3.6, z), 5), 0.1, 0.08, 4, 1.0)
	mb.add_tube(dark, MeshBuilder.curve_points(t * Vector3(0, 0, len * 0.5), t * Vector3(0, 1.0, len * 0.5 + 1.2), t * Vector3(0, 4.2, len * 0.5 + 1.4), 5), 0.16, 0.12, 4, 1.0)
	mb.add_box(dark, t * Transform3D(Basis(), Vector3(0, 1.9, -len * 0.5)), Vector3(0.3, 3.8, 0.3), 0.8)
	if planked:
		var wood := PSXMat.lit("planks", Color(0.82, 0.68, 0.5))
		for j in range(3):
			for s in [-1.0, 1.0]:
				mb.add_box(wood, t * Transform3D(Basis(Vector3.BACK, s * (0.5 - j * 0.12)), Vector3(s * (1.7 + j * 0.35), 0.6 + j * 0.55, 0)), Vector3(0.08, 0.5, len * 0.72), 0.6)
	M.box(cols, t * Transform3D(Basis(), Vector3(0, 1.4, 0)), Vector3(5.6, 3.2, len))


# --------------------------------------------------------------------------
## The water taxi landings: steps down into the water (you can climb out there), a mooring pole, a boat and its
## boatman's place.
static func _landings(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(1188)
	var lime := M.mat("lime")
	for i in range(P.LANDINGS.size()):
		var l: Array = P.LANDINGS[i]
		var q: Vector2 = l[1]
		var wd: Vector2 = l[2]
		var t := M.xf(M.v3(q, 0.0), M.yaw_of(wd))
		# steps down from the walkway's edge to the water and below
		var edge := q + wd * (P.WALK * 0.5 if absf(wd.x) > 0.5 else 1.5)
		var et := M.xf(M.v3(edge, 0.0), M.yaw_of(wd))
		for k in range(5):
			mb.add_box(lime, et * Transform3D(Basis(), Vector3(0, P.QUAY_Y - 0.35 - k * 0.45, 0.4 + k * 0.5)), Vector3(2.4, 0.3, 0.5), 0.6, Color(0.86, 0.84, 0.8) * (1.0 - k * 0.05))
		var r0 := et * Vector3(0, P.QUAY_Y, 0.0)
		var r1 := et * Vector3(0, -0.9, 2.8)
		M.box(cols, Transform3D(Basis.looking_at(r1 - r0, Vector3.UP), (r0 + r1) * 0.5) * Transform3D(Basis(), Vector3(0, -0.15, 0)), Vector3(2.4, 0.3, r0.distance_to(r1) + 0.2))
		var bq := edge + wd * 3.6 + wd.orthogonal() * 2.0
		_long_boat(mb, M.xf(M.v3(bq, 0.0), M.yaw_of(wd.orthogonal())), rng)
		for s in range(4):
			mb.add_cylinder(PSXMat.flat(Color.WHITE), M.xf(M.v3(edge + wd * 1.6 - wd.orthogonal() * 1.6, -0.4 + s * 0.8)), 0.12, 0.11, 0.8, 5, 1.0,
				Color(0.2, 0.3, 0.62) if s % 2 == 0 else Color(0.95, 0.95, 0.92))
		_spot(out, "landing%d" % i, q - wd * 0.6 + wd.orthogonal() * 1.6, P.QUAY_Y, wd)
	_piece(out, "Landings", mb, cols)
