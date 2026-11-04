class_name ShipRooms
extends RefCounted
## (1.30) The brig's and galleon's rooms (HullLayout.rooms), furnished like ShipCabin's great cabin but several
## rooms, as Zach's second reference has them (docs/v1_29_plan.md, Interior vibe): under the quarterdeck a partition
## with a doorway splits the cabin into a lounge forward (the galley's stove, counter and pantry, the storage chest, a
## long mess table, a sofa and armchair round a low table on a rug, a candle chandelier) and, aft, the brig's captain's
## cabin (a curtained bed, bunk beds with a ladder, the chart desk under the stern windows, a wardrobe and a clothes
## rack) or the galleon's crew bunk room (four sets of bunk beds with ladders). The galleon's stateroom up under the poop
## is the library: bookcases, a compass rose in the floor, a chart table, a wardrobe and a rack of coats, a
## chandelier, a long row of stern windows. Her gun deck below (`hold`): hammocks, shot racks, rammers, barrels.
## Two builders as ShipCabin's (`main`, `fine`); Ship hides them while no camera is near.


## Where the partition stands (z): forward the lounge, aft the captain's cabin or bunk room.
static func part_z(L: HullLayout) -> float:
	return L.qd_front + (4.4 if L.cls == "brig" else 5.3)


static func build(L: HullLayout) -> Array:
	var mb := MeshBuilder.new()
	var fine := MeshBuilder.new()
	var m := ShipCabin.mats()
	m["velvet"] = PSXMat.lit("fabric", Color(0.42, 0.16, 0.2))
	m["books"] = PSXMat.lit("leather", Color.WHITE)
	m["tile"] = PSXMat.lit("planks", Color(0.9, 0.82, 0.62))
	# the lounge
	ShipCabin._galley(mb, fine, m, L, 3)
	ShipCabin._store(mb, m, L.storage_at)
	ShipCabin._pantry(mb, fine, m, L)
	ShipCabin._table(mb, fine, m, L, 4)
	ShipCabin._lamp(mb, fine, m, L, 4)
	ShipCabin._panelling(mb, m, L)
	_partition(mb, fine, m, L)
	var s := sofa_at(L)
	_sofa(mb, fine, m, s, 2.0)
	_tea_table(mb, fine, m, s + Vector3(1.05, 0, 0))
	_armchair(mb, m, s + Vector3(2.2, 0, 0), PI * 0.5)
	mb.add_box(m["rug"], Transform3D(Basis(), s + Vector3(1.2, 0.006, 0)), Vector3(2.6, 0.01, 2.8), 0.5)
	_chandelier(mb, fine, m, Vector3(s.x + 1.05, L.qd_y - 0.85, s.z), L.qd_y)
	# aft of the partition
	var pz := part_z(L)
	ShipCabin._stern(mb, fine, m, L, 2)
	if L.cls == "brig":
		ShipCabin._bunk(mb, fine, m, L.bed_at, 3)
		_bed_curtains(mb, m, L.bed_at)
		_bunk_pair(mb, fine, m, Vector3(L.cabin_hw - 0.7, L.cabin_y, L.bed_at.z - 0.1))
		ShipCabin._chart_desk(mb, fine, m, L)
		_wardrobe(mb, fine, m, Vector3(2.4, L.cabin_y, pz + 0.38), PI)
		_coat_rack(mb, fine, m, Vector3(-2.3, L.cabin_y, pz + 0.35), 1.4, 0.0)
		mb.add_box(m["rug"], Transform3D(Basis(), Vector3(0, L.cabin_y + 0.006, (pz + L.qd_back) * 0.5)), Vector3(2.6, 0.01, 2.2), 0.5)
	else:
		for z in bunk_zs(L):
			for sx in [-1.0, 1.0]:
				var at := Vector3(sx * (L.cabin_hw - 0.7), L.cabin_y, z)
				if at.distance_to(L.bed_at) < 0.1:
					ShipCabin._bunk(mb, fine, m, at, 3)
				_bunk_pair(mb, fine, m, at, at.distance_to(L.bed_at) < 0.1)
		for k in range(4):
			_sea_chest(mb, m, Vector3(-1.0 + (k % 2) * 2.0, L.cabin_y, pz + 1.6 + floorf(k / 2.0) * 2.6))
		mb.add_box(m["rug"], Transform3D(Basis(), Vector3(0, L.cabin_y + 0.006, (pz + L.qd_back) * 0.5)), Vector3(1.4, 0.01, 5.0), 0.5)
		_stateroom(mb, fine, m, L)
	# the lantern aft of the partition (its light: lamps)
	var lamp: Vector3 = lamps(L)[0]
	HullBuilder._line(mb, m["iron"], lamp + Vector3(0, 0.15, 0), Vector3(lamp.x, L.qd_y - 0.2, lamp.z), 0.03)
	BeltLantern.model(mb, Transform3D(Basis(), lamp - Vector3(0, 0.3, 0)), 1.2, m["iron"], m["glass"])
	for b in [mb, fine]:
		(b as MeshBuilder).fold_tints()
	return [mb, fine]


## The galleon's bunk sets (z), each a pair either side.
static func bunk_zs(L: HullLayout) -> Array:
	return [L.bed_at.z, L.bed_at.z + 2.6]


static func sofa_at(L: HullLayout) -> Vector3:
	return Vector3(-L.cabin_hw + 0.45, L.cabin_y, part_z(L) - 1.2)


## The partition: boards across the cabin from the floor to the deckhead, a doorway in the middle with its posts and
## a curtain tied back.
static func _partition(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var z := part_z(L)
	var h := L.qd_y - L.cabin_y
	var y := L.cabin_y + h * 0.5
	var w := L.cabin_hw - L.door_hw
	for sgn in [-1.0, 1.0]:
		mb.add_box(m["pale"], Transform3D(Basis(), Vector3(sgn * (L.door_hw + w * 0.5), y, z)), Vector3(w, h, 0.08), 0.5)
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(sgn * (L.door_hw + 0.05), y, z)), Vector3(0.12, h, 0.14), 1.0)
		var k := 1.0
		while k < w - 0.2:
			fine.add_box(m["oak"], Transform3D(Basis(), Vector3(sgn * (L.door_hw + k), y, z)), Vector3(0.04, h, 0.1), 1.0)
			k += 0.9
	var over := h - L.door_h
	mb.add_box(m["pale"], Transform3D(Basis(), Vector3(0, L.cabin_y + L.door_h + over * 0.5, z)), Vector3(L.door_hw * 2.0, over, 0.08), 0.5)
	mb.add_box(m["oak"], Transform3D(Basis(), Vector3(0, L.cabin_y + L.door_h + 0.05, z)), Vector3(L.door_hw * 2.0 + 0.24, 0.12, 0.16), 1.0)
	mb.add_box(m["curtain"], Transform3D(Basis(Vector3.BACK, 0.06), Vector3(-L.door_hw + 0.12, L.cabin_y + L.door_h * 0.55, z + 0.06)), Vector3(0.22, L.door_h * 0.9, 0.04), 1.0)


## A sofa against the port wall, `len` long: a frame, padded seat and back in red velvet, rolled arms.
static func _sofa(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, at: Vector3, len: float) -> void:
	mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(0.05, 0.2, 0)), Vector3(0.8, 0.4, len), 1.0)
	mb.add_box(m["velvet"], Transform3D(Basis(), at + Vector3(0.1, 0.45, 0)), Vector3(0.72, 0.16, len - 0.2), 1.0)
	mb.add_box(m["velvet"], Transform3D(Basis(Vector3.BACK, -0.15), at + Vector3(-0.25, 0.78, 0)), Vector3(0.2, 0.62, len - 0.2), 1.0)
	for sz in [-1.0, 1.0]:
		mb.add_cylinder(m["velvet"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0.1, 0.6, sz * (len * 0.5 - 0.05))), 0.16, 0.16, 0.8, 8, 1.0, Color(0.9, 0.9, 0.9), true, true)
	for k in range(2):
		fine.add_box(m["linen"], Transform3D(Basis(Vector3.BACK, -0.3), at + Vector3(-0.1, 0.72, -0.45 + k * 0.9)), Vector3(0.12, 0.36, 0.4), 1.0, Color(1.0, 0.85, 0.55))
	for sz in [-1.0, 1.0]:
		for sx in [-0.3, 0.4]:
			fine.add_cylinder(m["brass"], Transform3D(Basis(), at + Vector3(sx, 0.0, sz * (len * 0.5 - 0.1))), 0.04, 0.03, 0.06, 5, 1.0)


## A low table on turned legs, a tea pot and cups, a candle.
static func _tea_table(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, at: Vector3) -> void:
	mb.add_cylinder(m["oak"], Transform3D(Basis(), at + Vector3(0, 0.45, 0)), 0.5, 0.5, 0.05, 10, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(m["oak"], Transform3D(Basis(), at), 0.08, 0.06, 0.45, 6, 1.0)
	mb.add_cylinder(m["oak"], Transform3D(Basis(), at), 0.3, 0.25, 0.05, 8, 1.0, Color.WHITE, true, true)
	fine.add_cylinder(m["glaze"], Transform3D(Basis(), at + Vector3(0.1, 0.5, 0.05)), 0.09, 0.07, 0.15, 7, 1.0, Color(0.85, 0.9, 1.0))
	for k in range(3):
		var a := TAU * k / 3.0 + 0.5
		fine.add_cylinder(m["glaze"], Transform3D(Basis(), at + Vector3(cos(a) * 0.3, 0.5, sin(a) * 0.3)), 0.045, 0.04, 0.06, 6, 1.0)
	fine.add_cylinder(m["linen"], Transform3D(Basis(), at + Vector3(-0.2, 0.5, -0.15)), 0.03, 0.03, 0.12, 5, 1.0)
	fine.add_box(m["glass"], Transform3D(Basis(), at + Vector3(-0.2, 0.66, -0.15)), Vector3(0.025, 0.05, 0.025), 1.0)


## A padded armchair, its back to `yaw` (0: facing -z).
static func _armchair(mb: MeshBuilder, m: Dictionary, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	mb.add_box(m["oak"], Transform3D(b, at + b * Vector3(0, 0.2, 0)), Vector3(0.75, 0.4, 0.7), 1.0)
	mb.add_box(m["leather"], Transform3D(b, at + b * Vector3(0, 0.44, -0.03)), Vector3(0.62, 0.1, 0.6), 1.0)
	mb.add_box(m["leather"], Transform3D(b * Basis(Vector3.RIGHT, -0.15), at + b * Vector3(0, 0.78, 0.28)), Vector3(0.7, 0.7, 0.14), 1.0)
	for sx in [-0.34, 0.34]:
		mb.add_box(m["leather"], Transform3D(b, at + b * Vector3(sx, 0.58, 0.0)), Vector3(0.1, 0.22, 0.68), 1.0)


## A ring of candles in a brass hoop on chains from the deckhead at `top`, crystal drops under it.
static func _chandelier(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, at: Vector3, top: float) -> void:
	for k in range(8):
		var a := TAU * k / 8.0
		var p := at + Vector3(cos(a) * 0.45, 0, sin(a) * 0.45)
		fine.add_cylinder(m["linen"], Transform3D(Basis(), p), 0.025, 0.025, 0.1, 5, 1.0)
		mb.add_box(m["glass"], Transform3D(Basis(), p + Vector3(0, 0.14, 0)), Vector3(0.05, 0.08, 0.05), 1.0)
		HullBuilder._line(mb, m["brass"], p - Vector3(0, 0.02, 0), at + Vector3(cos(a + TAU / 8.0) * 0.45, -0.02, sin(a + TAU / 8.0) * 0.45), 0.03)
		fine.add_box(m["pane"], Transform3D(Basis(Vector3.UP, a), p - Vector3(0, 0.14, 0) * 1.0 - Vector3(cos(a), 0, sin(a)) * 0.15), Vector3(0.03, 0.12, 0.03), 1.0)
	for k in range(3):
		var a := TAU * k / 3.0
		HullBuilder._line(mb, m["brass"], at + Vector3(cos(a) * 0.45, 0, sin(a) * 0.45), at + Vector3(0, 0.7, 0), 0.015)
	HullBuilder._line(mb, m["iron"], at + Vector3(0, 0.7, 0), Vector3(at.x, top - 0.15, at.z), 0.025)
	mb.add_cylinder(m["brass"], Transform3D(Basis(), at + Vector3(0, -0.2, 0)), 0.04, 0.12, 0.22, 8, 1.0, Color.WHITE, true, false)


## Curtains on a rail round the captain's bed (posts at its corners, a canopy board).
static func _bed_curtains(mb: MeshBuilder, m: Dictionary, at: Vector3) -> void:
	for sx in [-0.6, 0.6]:
		for sz in [-1.1, 1.1]:
			mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(sx, 0.95, sz)), Vector3(0.08, 1.9, 0.08), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(0, 1.92, 0)), Vector3(1.3, 0.08, 2.3), 1.0)
	mb.add_box(m["velvet"], Transform3D(Basis(), at + Vector3(0, 1.8, 0)), Vector3(1.32, 0.18, 2.32), 1.0)
	for sz in [-0.85, 0.85]:
		mb.add_box(m["velvet"], Transform3D(Basis(), at + Vector3(0.62, 1.05, sz)), Vector3(0.05, 1.5, 0.45), 1.0)


## Two bunks one over the other on posts, a ladder up the foot end, a curtain on the upper. `lower_done`: the lower
## bunk is ShipCabin's (the crew's own rest spot), else a plain one is laid here.
static func _bunk_pair(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, at: Vector3, lower_done: bool = false) -> void:
	var out := -signf(at.x)
	if not lower_done:
		mb.add_box(m["wood"], Transform3D(Basis(), at + Vector3(0, 0.2, 0)), Vector3(1.15, 0.4, 2.15), 1.0)
		mb.add_box(m["linen"], Transform3D(Basis(), at + Vector3(0, 0.46, 0)), Vector3(1.0, 0.14, 2.0), 1.0)
		mb.add_box(m["blanket"], Transform3D(Basis(), at + Vector3(0, 0.55, -0.3)), Vector3(1.04, 0.06, 1.3), 1.0, Color(0.55, 0.75, 1.1))
		mb.add_box(m["linen"], Transform3D(Basis(), at + Vector3(0, 0.6, 0.72)), Vector3(0.7, 0.14, 0.4), 1.0)
	var y := 1.3
	for sx in [-0.55, 0.55]:
		for sz in [-1.04, 1.04]:
			mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(sx, (y + 0.3) * 0.5, sz)), Vector3(0.08, y + 0.3, 0.08), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(0, y, 0)), Vector3(1.15, 0.12, 2.12), 1.0)
	mb.add_box(m["linen"], Transform3D(Basis(), at + Vector3(0, y + 0.12, 0)), Vector3(1.0, 0.12, 1.95), 1.0)
	mb.add_box(m["blanket"], Transform3D(Basis(), at + Vector3(0, y + 0.2, -0.3)), Vector3(1.04, 0.05, 1.25), 1.0, Color(0.9, 0.7, 0.4))
	mb.add_box(m["linen"], Transform3D(Basis(), at + Vector3(0, y + 0.25, 0.72)), Vector3(0.6, 0.12, 0.34), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(out * 0.56, y + 0.22, 0.2)), Vector3(0.05, 0.18, 1.5), 1.0)
	# the ladder up the foot end, on the open side
	var lx := at.x + out * 0.62
	for sz in [-0.2, 0.2]:
		mb.add_box(m["oak"], Transform3D(Basis(Vector3.BACK, out * 0.12), Vector3(lx + out * 0.08, (y + 0.4) * 0.5 + at.y, at.z - 0.8 + sz)), Vector3(0.06, y + 0.4, 0.06), 1.0)
	for k in range(4):
		var ky := 0.3 + k * 0.32
		fine.add_box(m["oak"], Transform3D(Basis(), Vector3(lx + out * (0.17 - ky * 0.12), at.y + ky, at.z - 0.8)), Vector3(0.05, 0.05, 0.44), 1.0)
	HullBuilder._line(fine, m["brass"], at + Vector3(out * 0.62, y + 0.8, -1.0), at + Vector3(out * 0.62, y + 0.8, 1.0), 0.02)
	mb.add_box(m["curtain"], Transform3D(Basis(), at + Vector3(out * 0.63, y + 0.45, 0.65)), Vector3(0.03, 0.66, 0.6), 1.0, Color(0.6, 0.75, 1.0))


## A wardrobe: two doors with brass knobs, a cornice, its back to the wall it stands against (`yaw` PI: facing +z).
static func _wardrobe(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	mb.add_box(m["oak"], Transform3D(b, at + Vector3(0, 1.0, 0)), Vector3(1.3, 2.0, 0.6), 1.0)
	mb.add_box(m["trim"], Transform3D(b, at + Vector3(0, 2.05, 0)), Vector3(1.42, 0.1, 0.7), 1.0)
	for sx in [-0.32, 0.32]:
		mb.add_box(m["pale"], Transform3D(b, at + b * Vector3(sx, 1.05, -0.31)), Vector3(0.56, 1.7, 0.03), 1.0)
		fine.add_cylinder(m["brass"], Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), at + b * Vector3(sx * 0.2, 1.05, -0.34)), 0.03, 0.03, 0.04, 6, 1.0)


## A rack of coats and hats: a rail on two posts, coats hung in a row in the crew's colours, a hat on each post.
static func _coat_rack(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, at: Vector3, len: float, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	for sx in [-0.5, 0.5]:
		mb.add_box(m["oak"], Transform3D(b, at + b * Vector3(sx * len, 0.85, 0)), Vector3(0.07, 1.7, 0.07), 1.0)
		mb.add_box(m["oak"], Transform3D(b, at + b * Vector3(sx * len, 0.03, 0)), Vector3(0.1, 0.06, 0.5), 1.0)
		fine.add_cylinder(m["leather"], Transform3D(b, at + b * Vector3(sx * len, 1.72, 0)), 0.2, 0.2, 0.05, 8, 1.0, Color(0.4, 0.3, 0.25), true, true)
		fine.add_cylinder(m["leather"], Transform3D(b, at + b * Vector3(sx * len, 1.75, 0)), 0.1, 0.12, 0.14, 8, 1.0, Color(0.4, 0.3, 0.25), true, true)
	HullBuilder._line(mb, m["brass"], at + b * Vector3(-0.5 * len, 1.6, 0), at + b * Vector3(0.5 * len, 1.6, 0), 0.03)
	var cols := [Color(0.2, 0.25, 0.5), Color(0.55, 0.12, 0.1), Color(0.25, 0.22, 0.2), Color(0.15, 0.35, 0.25), Color(0.6, 0.5, 0.3)]
	var n := int(len / 0.28)
	for k in range(n):
		var x := -0.5 * len + 0.2 + k * (len - 0.4) / maxf(n - 1, 1)
		mb.add_box(m["linen"], Transform3D(b * Basis(Vector3.UP, 0.1 * (k % 3 - 1)), at + b * Vector3(x, 1.05, 0)), Vector3(0.12, 1.0, 0.5), 1.0, cols[k % cols.size()])


## A sea chest at the foot of the bunks.
static func _sea_chest(mb: MeshBuilder, m: Dictionary, at: Vector3) -> void:
	mb.add_box(m["crate"], Transform3D(Basis(), at + Vector3(0, 0.22, 0)), Vector3(0.9, 0.44, 0.5), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(0, 0.46, 0)), Vector3(0.94, 0.06, 0.54), 1.0)
	for x in [-0.3, 0.3]:
		mb.add_box(m["iron"], Transform3D(Basis(), at + Vector3(x, 0.24, 0)), Vector3(0.05, 0.47, 0.53), 1.0)


## (the galleon) The stateroom under the poop: bookcases down the port wall, a compass rose let into the floor, a
## chart table on it, the captain's wardrobe and a rack of coats to starboard, a row of seven stern windows with a
## window seat, a chandelier.
static func _stateroom(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var y := L.qd_y
	var z0 := L.poop_front
	var z1 := L.qd_back
	var mid := (z0 + z1) * 0.5
	var hw := L.cabin_hw
	# panelled walls to rail height
	for sgn in [-1.0, 1.0]:
		mb.add_box(m["pale"], Transform3D(Basis(), Vector3(sgn * (hw - 0.01), y + 0.5, mid)), Vector3(0.03, 1.0, z1 - z0 - 0.2), 0.5)
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(sgn * (hw - 0.03), y + 1.0, mid)), Vector3(0.06, 0.06, z1 - z0 - 0.2), 1.0)
	# bookcases down the port wall
	var rng := RandomNumberGenerator.new()
	rng.seed = 1300
	for k in range(3):
		var at := Vector3(-hw + 0.22, y, z0 + 1.0 + k * 1.3)
		mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(0, 1.1, 0)), Vector3(0.4, 2.2, 1.2), 1.0)
		for s in range(5):
			var sy := 0.12 + s * 0.42
			mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(0.18, sy, 0)), Vector3(0.06, 0.03, 1.1), 1.0, Color(0.8, 0.8, 0.8))
			var bz := -0.5
			while bz < 0.48:
				var w := rng.randf_range(0.05, 0.1)
				var h := rng.randf_range(0.24, 0.34)
				var c := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.7), rng.randf_range(0.35, 0.8))
				fine.add_box(m["books"], Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06)), at + Vector3(0.12, sy + 0.02 + h * 0.5, bz + w * 0.5)), Vector3(0.24, h, w), 1.0, c)
				bz += w + 0.008
	# the compass rose: a ring of wedges in two woods, the north point gilt
	var c := Vector3(0.6, y + 0.006, mid)
	mb.add_cylinder(m["tile"], Transform3D(Basis(), c - Vector3(0, 0.004, 0)), 1.5, 1.5, 0.008, 16, 1.0, Color(0.55, 0.42, 0.3), true, true)
	for k in range(16):
		var a := TAU * k / 16.0
		var r := 1.35 if k % 4 == 0 else (0.95 if k % 2 == 0 else 0.6)
		var tip := c + Vector3(cos(a), 0.004, sin(a)) * r
		var l := c + Vector3(cos(a - 0.2), 0.004, sin(a - 0.2)) * 0.22
		var rr := c + Vector3(cos(a + 0.2), 0.004, sin(a + 0.2)) * 0.22
		var col := Color(1.0, 0.8, 0.35) if k == 12 else (Color(0.95, 0.9, 0.78) if k % 2 == 0 else Color(0.4, 0.28, 0.2))
		mb.add_tri(m["tile"], c + Vector3(0, 0.004, 0), tip, rr, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0.5, 0.5), Vector2(0.5, 0), Vector2(0.6, 0.5), col, Vector3.UP)
		mb.add_tri(m["tile"], c + Vector3(0, 0.004, 0), l, tip, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0.5, 0.5), Vector2(0.4, 0.5), Vector2(0.5, 0), col.darkened(0.15), Vector3.UP)
	# the chart table on the rose: a chart, dividers, a globe on a stand beside it
	var t := c + Vector3(0, -0.006, 0)
	mb.add_box(m["oak"], Transform3D(Basis(), t + Vector3(0, 0.78, 0)), Vector3(1.6, 0.07, 1.0), 1.0)
	for sx in [-0.7, 0.7]:
		for sz in [-0.4, 0.4]:
			mb.add_box(m["oak"], Transform3D(Basis(), t + Vector3(sx, 0.38, sz)), Vector3(0.08, 0.76, 0.08), 1.0)
	mb.add_box(m["paper"], Transform3D(Basis(Vector3.UP, 0.1), t + Vector3(0, 0.82, 0)), Vector3(1.1, 0.01, 0.75), 1.0, Color(1.0, 0.93, 0.75))
	fine.add_box(m["iron"], Transform3D(Basis(Vector3.UP, 0.7), t + Vector3(0.3, 0.83, 0.1)), Vector3(0.25, 0.01, 0.02), 1.0)
	var g := t + Vector3(1.3, 0, -0.9)
	mb.add_cylinder(m["oak"], Transform3D(Basis(), g), 0.05, 0.05, 0.9, 6, 1.0)
	mb.add_blob(m["paper"], Transform3D(Basis(), g + Vector3(0, 1.1, 0)), Vector3(0.24, 0.24, 0.24), rng, 0.0, 6, 8, 1.0, Color(0.55, 0.75, 0.6))
	HullBuilder._line(fine, m["brass"], g + Vector3(0, 0.82, -0.28), g + Vector3(0, 1.38, 0.28), 0.02)
	# the wardrobe and coats to starboard
	_wardrobe(mb, fine, m, Vector3(hw - 0.35, y, z0 + 1.2), PI * 0.5)
	_coat_rack(mb, fine, m, Vector3(hw - 0.4, y, z0 + 3.2), 1.6, PI * 0.5)
	# seven stern windows over a window seat
	var wz := z1 - 0.16
	var wy := y + 1.55
	for k in range(7):
		var x := -3.3 + k * 1.1
		mb.add_box(m["pane"], Transform3D(Basis(), Vector3(x, wy, wz)), Vector3(0.82, 1.0, 0.04), 1.0)
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x - 0.55, wy, wz - 0.04)), Vector3(0.12, 1.15, 0.08), 1.0)
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x, wy, wz - 0.025)), Vector3(0.05, 1.0, 0.04), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), Vector3(3.85, wy, wz - 0.04)), Vector3(0.12, 1.15, 0.08), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), Vector3(0, wy + 0.62, wz - 0.05)), Vector3(7.9, 0.1, 0.12), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), Vector3(0, y + 0.22, wz - 0.32)), Vector3(7.0, 0.44, 0.6), 1.0)
	mb.add_box(m["velvet"], Transform3D(Basis(), Vector3(0, y + 0.48, wz - 0.32)), Vector3(6.9, 0.1, 0.56), 1.0)
	_chandelier(mb, fine, m, Vector3(0.6, L.poop_y - 0.85, mid), L.poop_y)
	mb.add_box(m["rug"], Transform3D(Basis(), Vector3(-2.0, y + 0.006, mid + 0.4)), Vector3(1.6, 0.01, 2.6), 0.5)


## The cabin's lamp (Ship's CabinLight): over the mess table.
static func lamp_at(L: HullLayout) -> Vector3:
	return Vector3(L.table_at.x, L.qd_y - 1.0, L.table_at.z)


## The other rooms' lamps (lights hung with the cabin): aft of the partition, and the galleon's stateroom.
static func lamps(L: HullLayout) -> Array:
	if not L.rooms:
		return []
	var out: Array = [Vector3(0, L.qd_y - 0.8, (part_z(L) + L.qd_back) * 0.5)]
	if L.has_poop():
		out.append(Vector3(0.6, L.poop_y - 1.0, (L.poop_front + L.qd_back) * 0.5))
	return out


## [top of the seat, height, facing]: round the mess table, the sofa, the armchair, the window seat.
static func seats(L: HullLayout) -> Array:
	var t := L.table_at
	var y := L.cabin_y
	var out: Array = []
	for dz in [-0.8, 0.0, 0.8]:
		out.append([Vector3(t.x - 0.85, y + 0.45, t.z + dz), 0.45, Vector3(1, 0, 0)])
	for dz in [-0.5, 0.5]:
		out.append([Vector3(t.x + 0.85, y + 0.45, t.z + dz), 0.45, Vector3(-1, 0, 0)])
	var s := sofa_at(L)
	for dz in [-0.5, 0.5]:
		out.append([s + Vector3(0.12, 0.5, dz), 0.5, Vector3(1, 0, 0)])
	out.append([s + Vector3(2.2, 0.48, 0), 0.48, Vector3(-1, 0, 0)])
	if L.has_poop():
		for x in [-2.0, 0.0, 2.0]:
			out.append([Vector3(x, L.qd_y + 0.52, L.qd_back - 0.5), 0.52, Vector3(0, 0, -1)])
	return out


## What you can't walk through: [centre, size] (the seats aren't solid).
static func solids(L: HullLayout) -> Array:
	var y := L.cabin_y
	var out: Array = [
		[L.stove_at + Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 0.95)],
		[L.counter_at + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 1.6)],
		[L.storage_at + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.65)],
		[Vector3(L.cabin_hw - 0.22, y + 0.9, L.pantry_at.z), Vector3(0.42, 1.8, 1.05)],
		[L.table_at + Vector3(0, 0.4, 0), Vector3(1.0, 0.8, 2.6)],
		[sofa_at(L) + Vector3(0.0, 0.3, 0), Vector3(0.8, 0.6, 2.0)],
		[sofa_at(L) + Vector3(1.05, 0.25, 0), Vector3(0.9, 0.5, 0.9)],
	]
	var pz := part_z(L)
	var h := L.qd_y - y
	var w := L.cabin_hw - L.door_hw
	for sgn in [-1.0, 1.0]:
		out.append([Vector3(sgn * (L.door_hw + w * 0.5), y + h * 0.5, pz), Vector3(w, h, 0.14)])
	out.append([Vector3(0, y + L.door_h + (h - L.door_h) * 0.5, pz), Vector3(L.door_hw * 2.0, h - L.door_h, 0.14)])
	if L.cls == "brig":
		out.append([L.bed_at + Vector3(0, 0.26, 0), Vector3(1.15, 0.52, 2.15)])
		out.append([Vector3(L.cabin_hw - 0.7, y + 0.8, L.bed_at.z - 0.1), Vector3(1.15, 1.6, 2.15)])
		out.append([ShipCabin.desk_at(L) + Vector3(-0.15, 0.45, 0), Vector3(1.45, 0.9, 0.6)])
		out.append([Vector3(2.4, y + 1.0, pz + 0.38), Vector3(1.3, 2.0, 0.6)])
	else:
		for z in bunk_zs(L):
			for sx in [-1.0, 1.0]:
				out.append([Vector3(sx * (L.cabin_hw - 0.7), y + 0.8, z), Vector3(1.15, 1.6, 2.15)])
		var q := L.qd_y
		var mid := (L.poop_front + L.qd_back) * 0.5
		for k in range(3):
			out.append([Vector3(-L.cabin_hw + 0.22, q + 1.1, L.poop_front + 1.0 + k * 1.3), Vector3(0.4, 2.2, 1.2)])
		out.append([Vector3(0.6, q + 0.4, mid), Vector3(1.6, 0.8, 1.0)])
		out.append([Vector3(L.cabin_hw - 0.35, q + 1.0, L.poop_front + 1.2), Vector3(0.6, 2.0, 1.3)])
		out.append([Vector3(0, q + 0.22, L.qd_back - 0.48), Vector3(7.0, 0.44, 0.6)])
	return out


## (the galleon) Her gun deck's dressing: hammocks slung between the beams amidships, a shot rack, a rammer and a
## bucket by every gun, barrels and coils of rope at the bulkheads.
static func hold(L: HullLayout) -> MeshBuilder:
	var mb := MeshBuilder.new()
	var m := ShipCabin.mats()
	var canvas := PSXMat.lit("canvas", Color(0.92, 0.88, 0.76))
	var rope := PSXMat.lit("rope")
	var lo := L.lower_y
	var hi := L.deck_y - 0.12
	for g in L.gun_spots:
		if not is_equal_approx(float(g[2]), lo):
			continue
		for sgn in [-1.0, 1.0]:
			var at := Vector3(sgn * (float(g[1]) - 0.6), lo, float(g[0]) + 0.8)
			mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(0, 0.09, 0)), Vector3(0.36, 0.18, 0.5), 1.0)
			for k in range(5):
				mb.add_cylinder(m["iron"], Transform3D(Basis(), at + Vector3((k % 2 - 0.5) * 0.15, 0.24 + floorf(k / 4.0) * 0.12, (floorf((k % 4) / 2.0) - 0.5) * 0.2)), 0.075, 0.075, 0.13, 6, 1.0, Color.WHITE, true, true)
			HullBuilder._line(mb, m["wood"], at + Vector3(-sgn * 0.1, 0.05, -1.4), at + Vector3(-sgn * 0.15, 0.05, -0.2), 0.05)
			mb.add_cylinder(m["crate"], Transform3D(Basis(), at + Vector3(-sgn * 0.5, 0, 0)), 0.17, 0.15, 0.3, 7, 1.0)
	# hammocks slung fore and aft between the beams, two rows either side of the middle
	var z := L.mast_z + 2.0
	while z < float(L.hatch[0]) - 2.0:
		for x in [-2.6, -1.6, 1.6, 2.6]:
			var a := Vector3(x, hi - 0.35, z)
			var b := Vector3(x, hi - 0.35, z + 1.6)
			var pts := MeshBuilder.sag_points(a, b, 0.4, 6)
			for i in range(pts.size() - 1):
				var d: Vector3 = pts[i + 1] - pts[i]
				mb.add_box(canvas, Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (pts[i] + pts[i + 1]) * 0.5), Vector3(0.6, 0.04, d.length() + 0.02), 1.0)
			HullBuilder._line(mb, rope, a, a + Vector3(0, 0.25, 0), 0.03)
			HullBuilder._line(mb, rope, b, b + Vector3(0, 0.25, 0), 0.03)
		z += 2.0
	# barrels and rope coils against the forward bulkhead
	for k in range(4):
		var at := Vector3(-2.4 + k * 1.6, lo, L.lower_front + 0.6)
		mb.add_cylinder(m["crate"], Transform3D(Basis(), at), 0.35, 0.35, 0.9, 8, 0.6)
		mb.add_cylinder(m["iron"], Transform3D(Basis(), at + Vector3(0, 0.15, 0)), 0.36, 0.36, 0.04, 8, 1.0)
		mb.add_cylinder(m["iron"], Transform3D(Basis(), at + Vector3(0, 0.72, 0)), 0.36, 0.36, 0.04, 8, 1.0)
	for k in range(2):
		mb.add_cylinder(rope, Transform3D(Basis(), Vector3(-1.0 + k * 2.0, lo, L.lower_back - 0.8)), 0.4, 0.4, 0.22, 10, 1.0, Color.WHITE, true, true)
	mb.fold_tints()
	return mb


## (the galleon) The gun deck's solids (the barrels at the bulkhead).
static func hold_solids(L: HullLayout) -> Array:
	if not L.has_lower():
		return []
	return [[Vector3(0, L.lower_y + 0.45, L.lower_front + 0.6), Vector3(5.6, 0.9, 0.75)]]
