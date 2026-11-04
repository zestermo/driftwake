class_name HullDecks
extends RefCounted
## (1.30) What the brig's and galleon's layouts (HullLayout) add to HullBuilder's hull, mesh and collision: the masts
## past the main one (shrouds and a top on each), and the galleon's gun deck under the main deck: its floor, the
## inside of the hull round it, the deckhead and its beams, the hatch and the stair down, the gun ports and their lids.
## Nothing for the sloop (or base()): every piece is keyed off the layout having it. Ship-local.

static var _port_m: Material
static var _glass: Material


static func hull(mb: MeshBuilder, m: Dictionary, L: HullLayout, rig: bool) -> void:
	if rig:
		for mast in L.masts:
			_mast(mb, m, L, mast)
	if L.has_lower():
		_lower(mb, m, L)
	if L.rooms:
		_dress(mb, m, L)


## A strake along both sides from z0 (forward) to z1, y0 up to y1, `out` proud of the planking, following the hull.
static func _strake(mb: MeshBuilder, mat: Material, L: HullLayout, z0: float, z1: float, y0: float, y1: float, out: float, col: Color) -> void:
	var n := maxi(int((z1 - z0) / 2.0), 1)
	for sgn in [-1.0, 1.0]:
		for i in range(n):
			var za := lerpf(z0, z1, float(i) / n)
			var zb := lerpf(z0, z1, float(i + 1) / n)
			var a := Vector3(sgn * (L.side_at(za, y0) + out), y0, za)
			var b := Vector3(sgn * (L.side_at(zb, y0) + out), y0, zb)
			var c := Vector3(sgn * (L.side_at(zb, y1) + out), y1, zb)
			var d := Vector3(sgn * (L.side_at(za, y1) + out), y1, za)
			var q := [a, b, c, d] if sgn > 0.0 else [a, d, c, b]
			mb.add_quad(mat, q[0], q[1], q[2], q[3], HullBuilder._side_uv(q[0]), HullBuilder._side_uv(q[1]), HullBuilder._side_uv(q[2]), HullBuilder._side_uv(q[3]), col, Vector3(sgn, -0.2, 0).normalized())


## The brig's and galleon's dress: two heavy wales the length of her (in her hull paint, darker), the galleon's gun
## deck strake in her trim colour (the ports on it), and her stern: lit windows across the transom over each room's,
## mouldings over them, a quarter gallery on either side at each storey.
static func _dress(mb: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var bow := float(L.rings[L.rings.size() - 1][0]) + 1.2
	var st := L.qd_back - 0.05
	for y in [L.deck_y - 0.45, L.deck_y - 1.25]:
		_strake(mb, m["hull"], L, bow + 0.8, st, y - 0.14, y + 0.14, 0.06, Color(0.42, 0.4, 0.38))
	if L.has_lower():
		_strake(mb, m["trim"], L, L.lower_front - 1.0, L.lower_back + 1.0, L.lower_y + 0.42, L.lower_y + 1.4, 0.025, Color(0.9, 0.9, 0.9))
	var glass := _glass_m()
	var trim: Material = m["trim"]
	var z := L.qd_back + 0.03
	var storeys: Array = [[L.cabin_y + 1.7, 5]]
	if L.has_poop():
		storeys.append([L.qd_y + 1.55, 7])
	for s in storeys:
		var y: float = s[0]
		var n: int = s[1]
		var x0 := -(n - 1) * 0.55
		for k in range(n):
			mb.add_box(glass, Transform3D(Basis(), Vector3(x0 + k * 1.1, y + 0.05, z)), Vector3(0.82, 0.85, 0.04), 1.0)
			mb.add_box(trim, Transform3D(Basis(), Vector3(x0 + k * 1.1 - 0.55, y + 0.05, z + 0.03)), Vector3(0.12, 1.0, 0.08), 1.0)
		mb.add_box(trim, Transform3D(Basis(), Vector3(-x0 + 0.55, y + 0.05, z + 0.03)), Vector3(0.12, 1.0, 0.08), 1.0)
		mb.add_box(trim, Transform3D(Basis(), Vector3(0, y + 0.6, z + 0.06)), Vector3(n * 1.1 + 0.4, 0.14, 0.16), 1.0)
		mb.add_box(trim, Transform3D(Basis(), Vector3(0, y - 0.48, z + 0.06)), Vector3(n * 1.1 + 0.3, 0.1, 0.2), 1.0)
	# quarter galleries: a lit box on each quarter per storey, roofed
	var floors: Array = [[L.cabin_y + 0.9, L.qd_y - 0.15]]
	if L.has_poop():
		floors.append([L.qd_y + 0.85, L.poop_y - 0.15])
	var gz0 := L.qd_back - 2.8
	var gz1 := L.qd_back - 0.25
	for f in floors:
		var y0: float = f[0]
		var y1: float = f[1]
		var gy := (y0 + y1) * 0.5
		for sgn in [-1.0, 1.0]:
			var x: float = sgn * (L.side_at((gz0 + gz1) * 0.5, gy) + 0.25)
			mb.add_box(m["hull"], Transform3D(Basis(), Vector3(x, gy, (gz0 + gz1) * 0.5)), Vector3(0.5, y1 - y0, gz1 - gz0), 1.0, Color(0.85, 0.82, 0.8))
			mb.add_box(trim, Transform3D(Basis(), Vector3(x, y1 + 0.08, (gz0 + gz1) * 0.5)), Vector3(0.62, 0.16, gz1 - gz0 + 0.2), 1.0)
			mb.add_box(trim, Transform3D(Basis(), Vector3(x, y0 - 0.06, (gz0 + gz1) * 0.5)), Vector3(0.58, 0.12, gz1 - gz0 + 0.1), 1.0)
			for k in range(3):
				var wz := gz0 + 0.5 + k * (gz1 - gz0 - 1.0) / 2.0
				mb.add_box(glass, Transform3D(Basis(), Vector3(x + sgn * 0.26, gy + 0.05, wz)), Vector3(0.04, (y1 - y0) * 0.55, 0.5), 1.0)


## A mast past the main: [z, foot y, top y, yard y, yard width]; a top (a platform) over its yard, three shrouds a
## side from the rail with ratlines, a stay forward to the bowsprit (the foremast) or the main (the mizzen).
static func _mast(mb: MeshBuilder, m: Dictionary, L: HullLayout, mast: Array) -> void:
	var z := float(mast[0])
	var foot := float(mast[1])
	var top := float(mast[2])
	var yard := float(mast[3])
	var r := L.mast_r * 0.85
	mb.add_cylinder(m["wood"], Transform3D(Basis(), Vector3(0, foot - 0.02, z)), r, r * 0.55, top - foot, 8, 0.8)
	var top_y := yard + 1.3
	mb.add_cylinder(m["trim"], Transform3D(Basis(), Vector3(0, top_y, z)), 1.05, 0.9, 0.16, 10, 1.0, Color.WHITE, true, true)
	for sgn in [-1.0, 1.0]:
		var bot := Vector3(sgn * (L.half_width(z) - 0.12), foot + 0.85, z)
		var head := Vector3(sgn * 0.95, top_y, z)
		for dz in [-0.7, 0.0, 0.7]:
			HullBuilder._line(mb, m["rope"], bot + Vector3(0, -0.4, dz), Vector3(sgn * r, top - 0.6, z + dz * 0.15), 0.045)
		var n := int((head.y - bot.y) / 0.45)
		for i in range(1, n):
			var k := float(i) / n
			var c := bot.lerp(head, k)
			var w := lerpf(0.75, 0.3, k)
			HullBuilder._line(mb, m["rope"], c + Vector3(0, 0, -w), c + Vector3(0, 0, w), 0.035)
	var fore := z < L.mast_z
	var to := Vector3(0, L.sprit_at.y + 0.6, L.stay_z) if fore else Vector3(0, L.yard_y - 1.0, L.mast_z)
	HullBuilder._line(mb, m["rope"], Vector3(0, top - 0.3, z), to, 0.045)
	if fore:
		HullBuilder._line(mb, m["rope"], Vector3(0, top - 0.3, z), Vector3(0, L.yard_y + 1.4, L.mast_z), 0.04)


## Deck planking over a main-deck length (za aft of zb) with the hatch left open: a whole quad where the hatch isn't,
## the ends and the strips either side of it where it is. `down`: the deckhead seen from the gun deck.
static func deck_around_hatch(mb: MeshBuilder, mat: Material, L: HullLayout, za: float, zb: float, y: float, down: bool) -> void:
	var h0 := float(L.hatch[0])
	var h1 := float(L.hatch[1])
	var hx := float(L.hatch[2])
	if zb >= h1 or za <= h0:
		_plank(mb, mat, L, za, zb, -9.0, 9.0, y, down)
		return
	if za > h1:
		_plank(mb, mat, L, za, h1, -9.0, 9.0, y, down)
	if zb < h0:
		_plank(mb, mat, L, h0, zb, -9.0, 9.0, y, down)
	var sa := minf(za, h1)
	var sb := maxf(zb, h0)
	_plank(mb, mat, L, sa, sb, -9.0, -hx, y, down)
	_plank(mb, mat, L, sa, sb, hx, 9.0, y, down)


## Planks from za to zb, x from x0 to x1 (+-9 meaning the hull's side less 0.1).
static func _plank(mb: MeshBuilder, mat: Material, L: HullLayout, za: float, zb: float, x0: float, x1: float, y: float, down: bool) -> void:
	var wa := L.half_width(za) - 0.1
	var wb := L.half_width(zb) - 0.1
	var p := [Vector3(clampf(x0, -wa, wa), y, za), Vector3(clampf(x1, -wa, wa), y, za), Vector3(clampf(x1, -wb, wb), y, zb), Vector3(clampf(x0, -wb, wb), y, zb)]
	if down:
		p.reverse()
	mb.add_quad(mat, p[0], p[1], p[2], p[3], HullBuilder._plank_uv(p[0]), HullBuilder._plank_uv(p[1]), HullBuilder._plank_uv(p[2]), HullBuilder._plank_uv(p[3]),
		Color(0.62, 0.6, 0.58) if down else Color.WHITE, Vector3.DOWN if down else Vector3.UP)


## The z's the gun deck is cut at, aft to fore: its ends, the rings between them.
static func _zs(L: HullLayout) -> Array:
	var zs: Array = [L.lower_back, L.lower_front]
	for r in L.rings:
		if float(r[0]) < L.lower_back and float(r[0]) > L.lower_front:
			zs.append(float(r[0]))
	zs.sort()
	zs.reverse()
	return zs


## The gun deck: its floor, the hull's inside up to the deckhead, the deckhead (the hatch open in it) and its beams,
## the bulkheads at either end, the main mast down through it, the hatch's coaming and stair, the ports.
static func _lower(mb: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var hull_m: Material = m["hull"]
	var deck_m: Material = m["deck"]
	var lo := L.lower_y
	var hi := L.deck_y - 0.12
	var zs := _zs(L)
	for i in range(zs.size() - 1):
		var za: float = zs[i]
		var zb: float = zs[i + 1]
		var fa := L.side_at(za, lo) - 0.06
		var fb := L.side_at(zb, lo) - 0.06
		HullBuilder._deck_quad(mb, deck_m, Vector3(-fa, lo, za), Vector3(fa, lo, za), Vector3(fb, lo, zb), Vector3(-fb, lo, zb), Color(0.8, 0.78, 0.74), Vector3.UP)
		deck_around_hatch(mb, deck_m, L, za, zb, hi, true)
		for sgn in [-1.0, 1.0]:
			var a0 := Vector3(sgn * (L.side_at(za, lo) - 0.06), lo, za)
			var b0 := Vector3(sgn * (L.side_at(zb, lo) - 0.06), lo, zb)
			var b1 := Vector3(sgn * (L.side_at(zb, hi) - 0.06), hi, zb)
			var a1 := Vector3(sgn * (L.side_at(za, hi) - 0.06), hi, za)
			var q := [a0, b0, b1, a1] if sgn > 0.0 else [a0, a1, b1, b0]
			mb.add_quad(hull_m, q[0], q[1], q[2], q[3], HullBuilder._side_uv(q[0]), HullBuilder._side_uv(q[1]), HullBuilder._side_uv(q[2]), HullBuilder._side_uv(q[3]), Color(0.72, 0.7, 0.68), Vector3(-sgn, 0, 0))
	# the bulkheads: forward (facing aft) and aft (facing forward), planked across
	for e in [[L.lower_front, 1.0], [L.lower_back, -1.0]]:
		var z: float = e[0]
		var f: float = e[1]
		var w0 := L.side_at(z, lo)
		var w1 := L.side_at(z, hi)
		var q := [Vector3(-w0, lo, z), Vector3(w0, lo, z), Vector3(w1, hi, z), Vector3(-w1, hi, z)]
		if f < 0.0:
			q.reverse()
		mb.add_quad(hull_m, q[0], q[1], q[2], q[3], HullBuilder._transom_uv(q[0]), HullBuilder._transom_uv(q[1]), HullBuilder._transom_uv(q[2]), HullBuilder._transom_uv(q[3]), Color(0.7, 0.68, 0.66), Vector3(0, 0, f))
	# beams under the deckhead, every 1.6 m, and hanging knees at their ends (none over the hatch's stair)
	var z := L.lower_back - 0.8
	while z > L.lower_front + 0.5:
		if z < float(L.hatch[0]) - 0.1 or z > float(L.hatch[1]) + 0.1:
			var w := L.side_at(z, hi) - 0.06
			mb.add_box(hull_m, Transform3D(Basis(), Vector3(0, hi - 0.1, z)), Vector3(w * 2.0, 0.2, 0.22), 1.0, Color(0.8, 0.8, 0.8))
			for sgn in [-1.0, 1.0]:
				mb.add_box(hull_m, Transform3D(Basis(Vector3.BACK, sgn * 0.75), Vector3(sgn * (w - 0.28), hi - 0.36, z)), Vector3(0.14, 0.62, 0.18), 1.0, Color(0.8, 0.8, 0.8))
		z -= 1.6
	# the main mast down through it to the keelson, iron hoops round it
	if L.mast_z > L.lower_front and L.mast_z < L.lower_back:
		mb.add_cylinder(m["wood"], Transform3D(Basis(), Vector3(0, lo - 0.02, L.mast_z)), L.mast_r + 0.04, L.mast_r, L.deck_y - lo, 8, 0.8)
		for y in [lo + 0.6, lo + 1.5]:
			mb.add_cylinder(m["rope"], Transform3D(Basis(), Vector3(0, y, L.mast_z)), L.mast_r + 0.08, L.mast_r + 0.08, 0.08, 8, 1.0, Color(0.5, 0.5, 0.52))
	_hatch(mb, m, L)
	_ports(mb, m, L)
	# lanterns hung under the beams down the middle (glass that glows; the light is ShipRooms')
	var glass := _glass_m()
	var iron: Material = m["rope"]
	var lz := L.lower_back - 2.4
	while lz > L.lower_front + 1.0:
		if absf(lz - L.mast_z) > 1.0 and (lz < float(L.hatch[0]) - 0.5 or lz > float(L.hatch[1]) + 0.5):
			for sx in [-2.2, 2.2]:
				BeltLantern.model(mb, Transform3D(Basis(), Vector3(sx, hi - 0.75, lz)), 1.0, iron, glass)
				HullBuilder._line(mb, iron, Vector3(sx, hi - 0.45, lz), Vector3(sx, hi - 0.2, lz), 0.02)
		lz -= 5.2


static func _glass_m() -> Material:
	if _glass == null:
		_glass = PSXMat.glow(Color(1.0, 0.78, 0.4), 2.4)
	return _glass


## The hatch: a coaming round it on the main deck, a rail either side and across its after end, the stair down
## inside it (treads and stringers), hand ropes.
static func _hatch(mb: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var h0 := float(L.hatch[0])
	var h1 := float(L.hatch[1])
	var hx := float(L.hatch[2])
	var trim: Material = m["trim"]
	var dy := L.deck_y
	for sgn in [-1.0, 1.0]:
		mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * (hx + 0.06), dy + 0.1, (h0 + h1) * 0.5)), Vector3(0.12, 0.2, h1 - h0 + 0.24), 1.0)
		mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * (hx + 0.06), dy + 0.9, (h0 + h1) * 0.5)), Vector3(0.1, 0.1, h1 - h0), 1.0)
		for z in [h0 + 0.1, (h0 + h1) * 0.5, h1 - 0.05]:
			mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * (hx + 0.06), dy + 0.5, z)), Vector3(0.09, 0.8, 0.09), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, dy + 0.1, h1 + 0.06)), Vector3(hx * 2.0 + 0.24, 0.2, 0.12), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, dy + 0.9, h1 + 0.06)), Vector3(hx * 2.0 + 0.2, 0.1, 0.1), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, dy + 0.06, h0 - 0.06)), Vector3(hx * 2.0 + 0.24, 0.12, 0.12), 1.0)
	var n := 10
	var run := (h1 - h0) / n
	var rise := (dy - L.lower_y) / n
	for i in range(n):
		var y := dy - rise * (i + 1)
		mb.add_box(m["deck"], Transform3D(Basis(), Vector3(0, y - 0.04, h0 + run * (i + 0.5))), Vector3(hx * 2.0 - 0.1, 0.08, run + 0.05), 0.5)
	for sgn in [-1.0, 1.0]:
		var a := Vector3(sgn * (hx - 0.03), dy - 0.05, h0)
		var b := Vector3(sgn * (hx - 0.03), L.lower_y, h1)
		HullBuilder._line(mb, m["hull"], a, b, 0.1)
		HullBuilder._line(mb, m["rope"], a + Vector3(-sgn * 0.08, 0.85, 0.2), b + Vector3(-sgn * 0.08, 0.9, 0), 0.04)


## A port for each gun on the gun deck: the opening (dark, the barrel through it), its lid swung up outside on two
## hinges, a frame round it inside and out.
static func _ports(mb: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	if _port_m == null:
		_port_m = PSXMat.lit("planks_dark", Color(0.07, 0.06, 0.05))
	for g in L.gun_spots:
		if not is_equal_approx(float(g[2]), L.lower_y):
			continue
		var z := float(g[0])
		var y := L.lower_y + ShipCannon.PIVOT_Y
		for sgn in [-1.0, 1.0]:
			var x := L.side_at(z, y)
			var lean: float = atan2(L.side_at(z, y + 0.5) - L.side_at(z, y - 0.5), 1.0) * sgn
			var b := Basis(Vector3.BACK, lean)
			mb.add_box(_port_m, Transform3D(b, Vector3(sgn * (x + 0.035), y, z)), Vector3(0.05, 0.62, 0.72), 1.0)
			mb.add_box(_port_m, Transform3D(b, Vector3(sgn * (x - 0.07), y, z)), Vector3(0.05, 0.62, 0.72), 1.0)
			for e in [[0.37, Vector3(0.09, 0.1, 0.92)], [-0.37, Vector3(0.09, 0.1, 0.92)]]:
				mb.add_box(m["trim"], Transform3D(b, Vector3(sgn * (x + 0.03), y + float(e[0]), z)), e[1], 1.0)
				mb.add_box(m["trim"], Transform3D(b, Vector3(sgn * (x - 0.09), y + float(e[0]), z)), e[1], 1.0)
			# the lid, hinged at the top, swung out and up
			var hinge := Vector3(sgn * (x + 0.06), y + 0.4, z)
			var lid := Basis(Vector3.BACK, sgn * 2.0)
			mb.add_box(m["hull"], Transform3D(lid, hinge + lid * Vector3(0, -0.33, 0)), Vector3(0.08, 0.66, 0.76), 1.0)


## (the galleon) The hull's volume round the gun deck, in place of HullBuilder's solid one: the keel up to the gun
## deck's floor, the bow and the stern solid up to the main deck (the cabin's floor aft), the main deck over the gun
## deck in slabs round the hatch, the hull's sides inside it, the stair down, the rails round the hatch, the mast.
static func volume(body: CollisionObject3D, L: HullLayout) -> void:
	var lo := L.lower_y
	var keel := PackedVector3Array()
	for r in L.rings:
		var z := float(r[0])
		for sgn in [-1.0, 1.0]:
			keel.append(Vector3(sgn * L.side_at(z, lo), lo, z))
			keel.append(Vector3(sgn * float(r[2]), float(r[4]), z))
	_convex(body, keel)
	_block(body, L, L.rings.filter(func(r): return float(r[0]) < L.lower_front).map(func(r): return float(r[0])) + [L.lower_front], L.deck_y)
	_block(body, L, [L.lower_back] + L.rings.filter(func(r): return float(r[0]) > L.lower_back).map(func(r): return float(r[0])), L.cabin_y)
	var h0 := float(L.hatch[0])
	var h1 := float(L.hatch[1])
	var hx := float(L.hatch[2])
	_slab(body, L, L.lower_front, h0, -9.0, 9.0)
	_slab(body, L, h1, L.lower_back, -9.0, 9.0)
	_slab(body, L, h0, h1, -9.0, -hx)
	_slab(body, L, h0, h1, hx, 9.0)
	var zs := _zs(L)
	var mid := (lo + L.deck_y) * 0.5
	for i in range(zs.size() - 1):
		for sgn in [-1.0, 1.0]:
			var a := Vector3(sgn * (L.side_at(zs[i], mid) + 0.1), mid, zs[i])
			var b := Vector3(sgn * (L.side_at(zs[i + 1], mid) + 0.1), mid, zs[i + 1])
			HullBuilder._box(body, a, b, 0.3, L.deck_y - lo)
	_convex(body, PackedVector3Array([Vector3(-hx, L.deck_y, h0), Vector3(hx, L.deck_y, h0), Vector3(-hx, lo, h0), Vector3(hx, lo, h0),
		Vector3(-hx, lo, h1), Vector3(hx, lo, h1)]))
	for sgn in [-1.0, 1.0]:
		HullBuilder._box(body, Vector3(sgn * (hx + 0.06), L.deck_y + 0.45, h0 + 0.1), Vector3(sgn * (hx + 0.06), L.deck_y + 0.45, h1), 0.12, 0.9)
	HullBuilder._cbox(body, Vector3(0, L.deck_y + 0.45, h1 + 0.06), Vector3(hx * 2.0 + 0.2, 0.9, 0.12))
	if L.mast_z > L.lower_front and L.mast_z < L.lower_back:
		var c := CylinderShape3D.new()
		c.radius = L.mast_r
		c.height = L.deck_y - lo
		HullBuilder._shape(body, c, Transform3D(Basis.IDENTITY, Vector3(0, (lo + L.deck_y) * 0.5, L.mast_z)))


## Solid from the gun deck's floor up to `top` through these z's (a length of the bow or the stern).
static func _block(body: CollisionObject3D, L: HullLayout, zs: Array, top: float) -> void:
	var pts := PackedVector3Array()
	for z in zs:
		for sgn in [-1.0, 1.0]:
			pts.append(Vector3(sgn * L.half_width(z), top, z))
			pts.append(Vector3(sgn * L.side_at(z, L.lower_y), L.lower_y, z))
	_convex(body, pts)


## The main deck from z0 to z1 (z0 forward), x from x0 to x1 (+-9: the hull's side), a slab 0.12 deep, its outline
## following the rings between.
static func _slab(body: CollisionObject3D, L: HullLayout, z0: float, z1: float, x0: float, x1: float) -> void:
	var zs: Array = [z0, z1]
	for r in L.rings:
		if float(r[0]) > z0 and float(r[0]) < z1:
			zs.append(float(r[0]))
	var pts := PackedVector3Array()
	for z in zs:
		var w := L.half_width(z)
		for x in [clampf(x0, -w, w), clampf(x1, -w, w)]:
			pts.append(Vector3(x, L.deck_y, z))
			pts.append(Vector3(x, L.deck_y - 0.12, z))
	_convex(body, pts)


static func _convex(body: CollisionObject3D, pts: PackedVector3Array) -> void:
	var s := ConvexPolygonShape3D.new()
	s.points = pts
	HullBuilder._shape(body, s, Transform3D.IDENTITY)


## The masts past the main (no nest: nobody climbs them).
static func collide(body: CollisionObject3D, L: HullLayout, rig: bool) -> void:
	if not rig:
		return
	for mast in L.masts:
		var c := CylinderShape3D.new()
		c.radius = L.mast_r * 0.85 - 0.02
		c.height = float(mast[2]) - float(mast[1])
		HullBuilder._shape(body, c, Transform3D(Basis.IDENTITY, Vector3(0, (float(mast[1]) + float(mast[2])) * 0.5, float(mast[0]))))
