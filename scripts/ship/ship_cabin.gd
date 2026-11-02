class_name ShipCabin
extends RefCounted
## The crew's cabin furnished (1.29 'Shipshape'), from the ship's layout (HullLayout: its floor, walls and the
## quarterdeck over it) at her Quarters level (ShipLines "quarters"). Quarters 0 is plain: the bunk, the storage
## chest's crates, a table and two stools, small stern windows, a lantern. 1 panels the walls and sets benches at the
## table; 2 a row of stern windows and a chart desk; 3 a partition round the captain's cot, a rug, a hanging lamp; 4
## the great cabin, a cozy lounge (the Going Merry's): the partition gone, a long mess table under a checked cloth with
## a padded bench and stools, a brick back wall to the galley with a sink and a bottle rack, a dresser of crockery
## behind a curtain, brass portholes, a wall clock, barrels, a candle lantern. The galley's stove and counter are in
## every room; the Galley & bunks line's pieces are ShipParts'. Two builders: `main` (what reads across the room)
## and `fine` (clutter, close up only); Ship hides both while no camera is near the cabin.

const WALL_T := 0.12


static func mats() -> Dictionary:
	return {
		"wood": PSXMat.lit("bark"),
		"oak": PSXMat.lit("planks_dark", Color(0.85, 0.7, 0.55)),
		"pale": PSXMat.lit("planks", Color(1.0, 0.86, 0.66)),
		"trim": PSXMat.lit("planks", Color(0.85, 0.65, 0.35)),
		"crate": PSXMat.lit("planks", Color(0.8, 0.65, 0.45)),
		"linen": PSXMat.lit("fabric", Color(0.9, 0.86, 0.75)),
		"blanket": PSXMat.lit("fabric", Color(0.55, 0.12, 0.1)),
		"iron": PSXMat.lit("metal", Color(0.25, 0.24, 0.23)),
		"brass": PSXMat.lit("metal", Color(1.0, 0.78, 0.4)),
		"fire": PSXMat.glow(Color(1.0, 0.45, 0.12), 3.0),
		"glass": PSXMat.glow(Color(1.0, 0.8, 0.4), 2.5),
		# (sea and sky through the glass: a soft blue-green, never a blown-out white)
		"pane": PSXMat.glow(Color(0.36, 0.56, 0.66), 0.8),
		"brick": PSXMat.lit("brick_pink", Color(1.0, 0.82, 0.72)),
		"check": PSXMat.lit("fabric_check", Color(1.0, 0.5, 0.45)),
		"rug": PSXMat.lit("rug_kilim"),
		"curtain": PSXMat.lit("drape_fabric", Color(0.8, 0.42, 0.32)),
		"leather": PSXMat.lit("leather", Color(0.75, 0.32, 0.22)),
		"glaze": PSXMat.lit("glaze", Color(0.9, 0.92, 1.0)),
		"paper": PSXMat.lit("canvas", Color(1.0, 0.95, 0.8)),
		"bottle": PSXMat.lit("", Color(0.25, 0.45, 0.3)),
		"orange": PSXMat.lit("", Color(1.0, 0.52, 0.1)),
	}


## The room at Quarters `q` into [main, fine].
static func build(L: HullLayout, q: int) -> Array:
	var mb := MeshBuilder.new()
	var fine := MeshBuilder.new()
	var m := mats()
	_bunk(mb, fine, m, L.bed_at, q)
	_galley(mb, fine, m, L, q)
	_store(mb, m, L.storage_at)
	_pantry(mb, fine, m, L)
	_table(mb, fine, m, L, q)
	_stern(mb, fine, m, L, q)
	_lamp(mb, fine, m, L, q)
	if q >= 1:
		_panelling(mb, m, L)
	if q >= 2:
		_chart_desk(mb, fine, m, L)
	if q == 3:
		_partition(mb, m, L)
	if q >= 3:
		_rug(mb, m, L, q)
	if q >= 4:
		_lounge(mb, fine, m, L)
	for b in [mb, fine]:
		(b as MeshBuilder).fold_tints()
	return [mb, fine]


## Where its seats go: [top of the seat, height, facing] (ship-local).
static func seats(L: HullLayout, q: int) -> Array:
	var t := table_at(L, q)
	var out: Array = []
	var y := L.cabin_y
	if q >= 4:
		# the padded bench along the mess table's port side, stools to starboard and at its head
		for dz in [-0.8, 0.0, 0.8]:
			out.append([Vector3(t.x - 0.85, y + 0.45, t.z + dz), 0.45, Vector3(1, 0, 0)])
		for dz in [-0.5, 0.5]:
			out.append([Vector3(t.x + 0.85, y + 0.45, t.z + dz), 0.45, Vector3(-1, 0, 0)])
	elif q >= 1:
		for sx in [-0.45, 0.45]:
			out.append([Vector3(t.x + sx, y + 0.45, t.z - 0.75), 0.45, Vector3(0, 0, 1)])
			out.append([Vector3(t.x + sx, y + 0.45, t.z + 0.75), 0.45, Vector3(0, 0, -1)])
	else:
		for sx in [-0.4, 0.5]:
			out.append([Vector3(t.x + sx, y + 0.45, t.z - 0.75), 0.45, Vector3(0, 0, 1)])
	return out


## What you can't walk through: [centre, size] boxes (ship-local; the stools and benches are seats, not solid).
static func solids(L: HullLayout, q: int) -> Array:
	var out: Array = [
		[L.bed_at + Vector3(0, 0.26, 0), Vector3(1.15, 0.52, 2.15)],
		[L.stove_at + Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 0.95)],
		[L.counter_at + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 1.6)],
		[L.storage_at + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.65)],
		[Vector3(L.cabin_hw - 0.22, L.cabin_y + 0.9, L.pantry_at.z), Vector3(0.42, 1.8, 1.05)],
	]
	var t := table_at(L, q)
	out.append([t + Vector3(0, 0.4, 0), Vector3(1.0, 0.8, 2.6) if q >= 4 else Vector3(1.5, 0.8, 0.9)])
	if q >= 2:
		out.append([desk_at(L) + Vector3(-0.15, 0.45, 0), Vector3(1.45, 0.9, 0.6)])
	if q == 3:
		var z := L.bed_at.z - 1.3
		var x1 := L.bed_at.x + 1.05
		out.append([Vector3((-L.cabin_hw + x1) * 0.5 - 0.25, L.cabin_y + 1.0, z), Vector3(x1 + L.cabin_hw - 0.5, 2.0, 0.08)])
	if q >= 4:
		out.append([Vector3(L.cabin_hw - 0.25, L.cabin_y + 0.9, L.counter_at.z - 1.55), Vector3(0.48, 1.8, 1.2)])
		out.append([L.bed_at + Vector3(0, 0.26, -2.35), Vector3(1.15, 0.52, 2.15)])
		out.append([Vector3(-L.cabin_hw + 0.68, L.cabin_y + 0.42, L.storage_at.z - 0.68), Vector3(1.2, 0.85, 0.65)])
	return out


## The table's middle on the floor: across the cabin's middle, the mess table (4) along it.
static func table_at(L: HullLayout, q: int) -> Vector3:
	return Vector3(0.0, L.cabin_y, 6.9) if q >= 4 else L.table_at


static func _bunk(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, at: Vector3, q: int) -> void:
	# frame, mattress, pillow, a red blanket turned down, a headboard; a shelf over it with a candle
	mb.add_box(m["wood"], Transform3D(Basis(), at + Vector3(0, 0.2, 0)), Vector3(1.15, 0.4, 2.15), 1.0)
	mb.add_box(m["linen"], Transform3D(Basis(), at + Vector3(0, 0.46, 0)), Vector3(1.0, 0.14, 2.0), 1.0)
	mb.add_box(m["linen"], Transform3D(Basis(), at + Vector3(0, 0.6, 0.72)), Vector3(0.7, 0.14, 0.4), 1.0)
	mb.add_box(m["blanket"], Transform3D(Basis(), at + Vector3(0, 0.55, -0.3)), Vector3(1.04, 0.06, 1.3), 1.0)
	mb.add_box(m["linen"], Transform3D(Basis(), at + Vector3(0, 0.57, 0.38)), Vector3(1.02, 0.05, 0.16), 1.0)
	mb.add_box(m["wood"], Transform3D(Basis(), at + Vector3(0, 0.45, 1.05)), Vector3(1.15, 0.9, 0.08), 1.0)
	for sz in [-1.05, 1.05]:
		mb.add_box(m["wood"], Transform3D(Basis(), at + Vector3(0.55, 0.35, sz)), Vector3(0.08, 0.7, 0.08), 1.0)
	if q >= 1:
		# a lee board along its open side
		mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(0.56, 0.5, 0)), Vector3(0.05, 0.2, 2.0), 1.0)
	var shelf := at + Vector3(-0.56, 1.25, 0)
	mb.add_box(m["oak"], Transform3D(Basis(), shelf), Vector3(0.24, 0.04, 1.6), 1.0)
	fine.add_cylinder(m["linen"], Transform3D(Basis(), shelf + Vector3(0, 0.02, 0.5)), 0.03, 0.03, 0.14, 5, 1.0)
	fine.add_box(m["glass"], Transform3D(Basis(), shelf + Vector3(0, 0.17, 0.5)), Vector3(0.02, 0.04, 0.02), 1.0)
	for k in range(3):
		fine.add_box(m["blanket" if k % 2 == 0 else "paper"], Transform3D(Basis(Vector3.RIGHT, 0.1 * k), shelf + Vector3(0, 0.12, -0.5 + k * 0.09)), Vector3(0.16, 0.2, 0.06), 1.0)


## The stove and the counter (every room): an iron stove with fire behind its door and its pipe up through the
## deckhead, a counter with a pot, a pan and a cutting board, a water barrel; at 4 a brick back wall, a sink and a
## bottle rack.
static func _galley(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, L: HullLayout, q: int) -> void:
	var st := L.stove_at
	var ct := L.counter_at
	mb.add_box(m["iron"], Transform3D(Basis(), st + Vector3(0, 0.45, 0)), Vector3(0.9, 0.9, 0.9), 1.0)
	mb.add_box(m["iron"], Transform3D(Basis(), st + Vector3(0, 0.92, 0)), Vector3(0.96, 0.05, 0.96), 1.0)
	mb.add_box(m["fire"], Transform3D(Basis(), st + Vector3(-0.46, 0.35, 0)), Vector3(0.04, 0.3, 0.45), 1.0)
	for sz in [-0.26, 0.26]:
		mb.add_box(m["iron"], Transform3D(Basis(), st + Vector3(-0.465, 0.35, sz)), Vector3(0.03, 0.34, 0.05), 1.0)
	mb.add_cylinder(m["iron"], Transform3D(Basis(), st + Vector3(0.1, 0.9, 0.1)), 0.09, 0.09, L.qd_y - L.cabin_y - 0.9, 6, 1.0)
	fine.add_cylinder(m["iron"], Transform3D(Basis(), st + Vector3(-0.15, 0.95, -0.2)), 0.17, 0.15, 0.2, 8, 1.0)
	fine.add_box(m["iron"], Transform3D(Basis(), st + Vector3(-0.15, 1.2, -0.2)), Vector3(0.02, 0.05, 0.3), 1.0)
	mb.add_box(m["trim"], Transform3D(Basis(), ct + Vector3(0, 0.45, 0)), Vector3(0.75, 0.9, 1.55), 0.6)
	mb.add_box(m["oak"], Transform3D(Basis(), ct + Vector3(0, 0.92, 0)), Vector3(0.8, 0.05, 1.6), 1.0)
	mb.add_cylinder(m["iron"], Transform3D(Basis(), ct + Vector3(0, 0.94, 0.35)), 0.2, 0.2, 0.25, 8, 1.0)
	mb.add_cylinder(m["iron"], Transform3D(Basis(), ct + Vector3(-0.05, 0.94, -0.35)), 0.14, 0.12, 0.18, 8, 1.0)
	fine.add_box(m["pale"], Transform3D(Basis(Vector3.UP, 0.2), ct + Vector3(-0.1, 0.96, -0.05)), Vector3(0.3, 0.03, 0.42), 1.0)
	for k in range(3):
		fine.add_box(m["pale" if k == 1 else "glaze"], Transform3D(Basis(), ct + Vector3(-0.25, 0.97 + k * 0.012, 0.65)), Vector3(0.2, 0.012, 0.2), 1.0)
	mb.add_cylinder(m["crate"], Transform3D(Basis(), ct + Vector3(0.1, 0.0, -1.25)), 0.35, 0.35, 0.9, 8, 0.6)
	for y in [0.15, 0.75]:
		fine.add_cylinder(m["iron"], Transform3D(Basis(), ct + Vector3(0.1, y, -1.25)), 0.36, 0.36, 0.04, 8, 1.0)
	if q < 4:
		return
	# the great cabin's galley corner: brick behind the stove up to the deckhead, a sink in the counter's fore end, a
	# rack of bottles on the wall over it
	var wall_x := L.cabin_hw - 0.02
	var top := L.qd_y - 0.15
	mb.add_box(m["brick"], Transform3D(Basis(), Vector3(wall_x - 0.03, (L.cabin_y + top) * 0.5, st.z - 0.1)), Vector3(0.06, top - L.cabin_y, 1.5), 0.5)
	mb.add_box(m["brick"], Transform3D(Basis(), Vector3(st.x - 0.1, (L.cabin_y + top) * 0.5, L.qd_back - 0.18)), Vector3(1.3, top - L.cabin_y, 0.06), 0.5)
	var sink := ct + Vector3(-0.05, 0.94, -0.45)
	mb.add_box(m["glaze"], Transform3D(Basis(), sink + Vector3(0, -0.06, 0)), Vector3(0.5, 0.14, 0.45), 1.0, Color(0.85, 0.9, 0.95))
	fine.add_cylinder(m["brass"], Transform3D(Basis(Vector3.BACK, 1.2), sink + Vector3(0.28, 0.12, 0)), 0.02, 0.02, 0.22, 5, 1.0)
	var rack := Vector3(wall_x - 0.12, L.cabin_y + 1.55, ct.z + 0.1)
	mb.add_box(m["oak"], Transform3D(Basis(), rack), Vector3(0.24, 0.5, 0.9), 1.0)
	for r in range(2):
		for k in range(5):
			fine.add_cylinder(m["bottle"], Transform3D(Basis(Vector3.BACK, -PI * 0.5), rack + Vector3(-0.1, -0.1 + r * 0.22, -0.34 + k * 0.17)), 0.05, 0.05, 0.26, 6, 1.0, Color(1.0 - 0.2 * (k % 2), 0.9, 0.8))


## The pantry (1.29) against the starboard wall forward: open shelves of jars, sacks and a crate of fruit, a string
## of onions hung from the top (its cold box and more shelves are the Galley & bunks line's: ShipParts).
static func _pantry(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var at := L.pantry_at
	var x := L.cabin_hw - 0.22
	for sz in [-0.5, 0.5]:
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x, at.y + 0.9, at.z + sz)), Vector3(0.4, 1.8, 0.05), 1.0)
	for y in [0.08, 0.6, 1.1, 1.6]:
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x, at.y + y, at.z)), Vector3(0.4, 0.04, 1.0), 1.0, Color.WHITE, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 129
	# jars on the top two shelves
	for y in [1.12, 1.62]:
		for k in range(4):
			var p := Vector3(x - 0.05, at.y + y, at.z - 0.36 + k * 0.24)
			var h := rng.randf_range(0.14, 0.24)
			fine.add_cylinder(m["glaze"], Transform3D(Basis(), p), 0.06, 0.055, h, 6, 1.0, Color(rng.randf_range(0.6, 1.0), rng.randf_range(0.6, 0.9), rng.randf_range(0.4, 0.8)), true, false)
			fine.add_cylinder(m["oak"], Transform3D(Basis(), p + Vector3(0, h, 0)), 0.05, 0.05, 0.03, 6, 1.0, Color.WHITE, true, false)
	# sacks of flour and rice on the middle shelf, a crate of fruit on the bottom
	for k in range(2):
		mb.add_blob(m["linen"], Transform3D(Basis(), Vector3(x - 0.02, at.y + 0.76, at.z - 0.22 + k * 0.42)), Vector3(0.15, 0.15, 0.17), rng, 0.12, 4, 6, 0.5, Color(0.95, 0.9, 0.75))
	mb.add_box(m["crate"], Transform3D(Basis(), Vector3(x - 0.02, at.y + 0.25, at.z + 0.1)), Vector3(0.34, 0.3, 0.55), 1.0)
	for k in range(5):
		fine.add_blob(m["orange"], Transform3D(Basis(), Vector3(x - 0.05 + (k % 2) * 0.08, at.y + 0.42, at.z - 0.1 + k * 0.1)), Vector3(0.05, 0.05, 0.05), rng, 0.0, 3, 5, 1.0)
	# a string of onions
	var top := Vector3(x - 0.18, at.y + 1.75, at.z - 0.3)
	HullBuilder._line(fine, m["iron"], top, top - Vector3(0, 0.5, 0), 0.015)
	for k in range(5):
		fine.add_blob(m["linen"], Transform3D(Basis(), top - Vector3(0, 0.12 + k * 0.09, 0)), Vector3(0.045, 0.045, 0.045), rng, 0.0, 3, 5, 1.0, Color(0.85, 0.6, 0.35))


## Crates and a barrel round the storage chest.
static func _store(mb: MeshBuilder, m: Dictionary, sc: Vector3) -> void:
	mb.add_box(m["crate"], Transform3D(Basis(Vector3.UP, 0.2), sc + Vector3(-0.4, 0.3, 1.0)), Vector3(0.6, 0.6, 0.6), 1.0)
	mb.add_box(m["crate"], Transform3D(Basis(Vector3.UP, -0.3), sc + Vector3(-0.45, 0.85, 1.0)), Vector3(0.45, 0.45, 0.45), 1.0)
	mb.add_cylinder(m["crate"], Transform3D(Basis(), sc + Vector3(0.9, 0.0, -0.05)), 0.32, 0.32, 0.8, 8, 0.6)


## The table: plain with two stools (0), with benches either side (1-3), the long mess table under a checked cloth (4).
static func _table(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, L: HullLayout, q: int) -> void:
	var t := table_at(L, q)
	if q >= 4:
		var len := 2.6
		mb.add_box(m["oak"], Transform3D(Basis(), t + Vector3(0, 0.76, 0)), Vector3(1.0, 0.06, len), 1.0)
		mb.add_box(m["check"], Transform3D(Basis(), t + Vector3(0, 0.795, 0)), Vector3(1.08, 0.012, len - 0.3), 0.6)
		for sz in [-1.0, 1.0]:
			mb.add_box(m["oak"], Transform3D(Basis(), t + Vector3(0, 0.37, sz * (len * 0.5 - 0.25))), Vector3(0.8, 0.74, 0.1), 1.0)
		mb.add_box(m["oak"], Transform3D(Basis(), t + Vector3(0, 0.15, 0)), Vector3(0.1, 0.1, len - 0.5), 1.0)
		# the padded bench to port (a back against the room), stools to starboard and at the head
		var b := t + Vector3(-0.85, 0, 0)
		mb.add_box(m["oak"], Transform3D(Basis(), b + Vector3(0, 0.2, 0)), Vector3(0.45, 0.4, len), 1.0)
		mb.add_box(m["leather"], Transform3D(Basis(), b + Vector3(0, 0.44, 0)), Vector3(0.46, 0.08, len - 0.05), 1.0)
		mb.add_box(m["oak"], Transform3D(Basis(), b + Vector3(-0.22, 0.65, 0)), Vector3(0.06, 0.5, len), 1.0)
		mb.add_box(m["leather"], Transform3D(Basis(Vector3.BACK, -0.12), b + Vector3(-0.17, 0.7, 0)), Vector3(0.07, 0.36, len - 0.1), 1.0)
		for dz in [-0.5, 0.5]:
			_stool(mb, m, t + Vector3(0.85, 0, dz))
		_stool(mb, m, t + Vector3(0, 0, len * 0.5 + 0.45))
		# laid for supper: plates, mugs, a loaf, a jug, a candle
		for k in range(5):
			var p := t + Vector3(-0.3 if k < 3 else 0.3, 0.81, -0.8 + (k % 3) * 0.8 if k < 3 else -0.5 + (k - 3) * 1.0)
			fine.add_cylinder(m["glaze"], Transform3D(Basis(), p), 0.12, 0.13, 0.02, 8, 1.0, Color.WHITE, true, true)
			fine.add_cylinder(m["oak"], Transform3D(Basis(), p + Vector3(0.18 * signf(-p.x + t.x) * -1.0, 0, 0.12)), 0.045, 0.045, 0.11, 6, 1.0)
		fine.add_blob(m["crate"], Transform3D(Basis(), t + Vector3(0, 0.86, 0.3)), Vector3(0.16, 0.08, 0.1), RandomNumberGenerator.new())
		fine.add_cylinder(m["glaze"], Transform3D(Basis(), t + Vector3(0.05, 0.8, -0.3)), 0.08, 0.06, 0.24, 7, 1.0, Color(0.85, 0.6, 0.45))
		fine.add_cylinder(m["linen"], Transform3D(Basis(), t + Vector3(0, 0.8, 0.0)), 0.035, 0.035, 0.18, 5, 1.0)
		fine.add_box(m["glass"], Transform3D(Basis(), t + Vector3(0, 1.0, 0.0)), Vector3(0.025, 0.05, 0.025), 1.0)
		return
	mb.add_box(m["wood"], Transform3D(Basis(), t + Vector3(0, 0.78, 0)), Vector3(1.5, 0.07, 0.9), 1.0)
	for sx in [-0.6, 0.6]:
		for sz in [-0.35, 0.35]:
			mb.add_box(m["wood"], Transform3D(Basis(), t + Vector3(sx, 0.38, sz)), Vector3(0.08, 0.76, 0.08), 1.0)
	fine.add_cylinder(m["oak"], Transform3D(Basis(), t + Vector3(0.3, 0.815, 0.1)), 0.05, 0.05, 0.12, 6, 1.0)
	fine.add_cylinder(m["glaze"], Transform3D(Basis(), t + Vector3(-0.2, 0.815, -0.1)), 0.13, 0.14, 0.02, 8, 1.0, Color.WHITE, true, true)
	if q >= 1:
		for sz in [-0.75, 0.75]:
			mb.add_box(m["oak"], Transform3D(Basis(), t + Vector3(0, 0.42, sz)), Vector3(1.4, 0.06, 0.32), 1.0)
			for sx in [-0.6, 0.6]:
				mb.add_box(m["oak"], Transform3D(Basis(), t + Vector3(sx, 0.2, sz)), Vector3(0.06, 0.4, 0.28), 1.0)
		return
	for sx in [-0.4, 0.5]:
		_stool(mb, m, t + Vector3(sx, 0, -0.75))


static func _stool(mb: MeshBuilder, m: Dictionary, at: Vector3) -> void:
	mb.add_cylinder(m["wood"], Transform3D(Basis(), at), 0.2, 0.18, 0.45, 6, 1.0)


## The stern wall: two small windows (0-1), a row of five with mullions over a window seat (2+); the stern lantern.
static func _stern(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, L: HullLayout, q: int) -> void:
	var z := L.qd_back - 0.16
	var y := L.cabin_y + 1.7
	if q < 2:
		# three round ports: a brass rim, the glass set back in it, the dogs that close it
		var b := Basis(Vector3.RIGHT, -PI * 0.5)
		for sx in [-1.6, 0.0, 1.6]:
			var p := Vector3(sx, y, z)
			mb.add_cylinder(m["brass"], Transform3D(b, p + Vector3(0, 0, 0.02)), 0.25, 0.25, 0.07, 10, 1.0, Color.WHITE, false, false)
			for k in range(10):
				var a0 := TAU * (k + 0.5) / 10.0
				mb.add_box(m["brass"], Transform3D(Basis(Vector3.BACK, a0), p + Vector3(cos(a0), sin(a0), 0) * 0.215 - Vector3(0, 0, 0.05)), Vector3(0.07, 0.15, 0.02), 1.0)
			mb.add_cylinder(m["pane"], Transform3D(b, p - Vector3(0, 0, 0.02)), 0.19, 0.19, 0.01, 10, 1.0, Color.WHITE, true, true)
			for k in range(3):
				var a := TAU * (k + 0.25) / 3.0
				fine.add_box(m["iron"], Transform3D(Basis(Vector3.BACK, a), p + Vector3(cos(a) * 0.24, sin(a) * 0.24, -0.07)), Vector3(0.05, 0.03, 0.03), 1.0)
		return
	for k in range(5):
		var x := -2.2 + k * 1.1
		mb.add_box(m["pane"], Transform3D(Basis(), Vector3(x, y + 0.05, z)), Vector3(0.82, 0.8, 0.04), 1.0)
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x, y + 0.05, z - 0.025)), Vector3(0.05, 0.8, 0.04), 1.0)
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x, y + 0.05, z - 0.025)), Vector3(0.82, 0.05, 0.04), 1.0)
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x - 0.55, y + 0.05, z - 0.04)), Vector3(0.12, 0.95, 0.08), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), Vector3(2.75, y + 0.05, z - 0.04)), Vector3(0.12, 0.95, 0.08), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), Vector3(0, y + 0.52, z - 0.05)), Vector3(5.7, 0.1, 0.12), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), Vector3(0, y - 0.4, z - 0.12)), Vector3(5.7, 0.06, 0.26), 1.0)
	# brass catches and a pair of tied-back curtains
	for k in range(5):
		fine.add_box(m["brass"], Transform3D(Basis(), Vector3(-2.2 + k * 1.1 + 0.3, y + 0.05, z - 0.05)), Vector3(0.04, 0.06, 0.03), 1.0)
	for sx in [-1.0, 1.0]:
		mb.add_box(m["curtain"], Transform3D(Basis(Vector3.BACK, sx * 0.08), Vector3(sx * 2.95, y + 0.05, z - 0.08)), Vector3(0.22, 1.0, 0.04), 1.0)


## The lantern hung from the beam over the table (a hanging brass lamp from 3, a candle lantern over the mess table at 4).
static func _lamp(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, L: HullLayout, q: int) -> void:
	var at := lamp_at(L, q)
	HullBuilder._line(mb, m["iron"], at + Vector3(0, 0.15, 0), Vector3(at.x, L.qd_y - 0.2, at.z), 0.03)
	if q >= 4:
		# a ring of candles in an iron hoop, a glass chimney over each
		for k in range(6):
			var a := TAU * k / 6.0
			var p := at + Vector3(cos(a) * 0.32, 0, sin(a) * 0.32)
			fine.add_cylinder(m["linen"], Transform3D(Basis(), p), 0.025, 0.025, 0.1, 5, 1.0)
			mb.add_box(m["glass"], Transform3D(Basis(), p + Vector3(0, 0.14, 0)), Vector3(0.05, 0.08, 0.05), 1.0)
			HullBuilder._line(mb, m["iron"], p + Vector3(0, 0.05, 0), at + Vector3(0, 0.6, 0), 0.015)
		for k in range(12):
			var a0 := TAU * k / 12.0
			var a1 := TAU * (k + 1) / 12.0
			HullBuilder._line(mb, m["iron"], at + Vector3(cos(a0) * 0.32, 0, sin(a0) * 0.32), at + Vector3(cos(a1) * 0.32, 0, sin(a1) * 0.32), 0.025)
		return
	if q >= 3:
		mb.add_cylinder(m["brass"], Transform3D(Basis(), at + Vector3(0, -0.05, 0)), 0.12, 0.08, 0.1, 8, 1.0)
		mb.add_box(m["glass"], Transform3D(Basis(), at + Vector3(0, 0.12, 0)), Vector3(0.14, 0.2, 0.14), 1.0)
		mb.add_cylinder(m["brass"], Transform3D(Basis(), at + Vector3(0, 0.22, 0)), 0.16, 0.04, 0.1, 8, 1.0)
		return
	# a ship's candle lantern on its chain: an iron frame and cap round the glass, a candle inside
	BeltLantern.model(mb, Transform3D(Basis(), at - Vector3(0, 0.3, 0)), 1.0, m["iron"], m["glass"])
	fine.add_cylinder(m["linen"], Transform3D(Basis(), at - Vector3(0, 0.24, 0)), 0.025, 0.025, 0.09, 5, 1.0)


## Where the cabin's lamp hangs (its light: Ship's CabinLight sits on it).
static func lamp_at(L: HullLayout, q: int) -> Vector3:
	var t := table_at(L, q)
	return Vector3(t.x, L.qd_y - (1.0 if q >= 4 else 0.65), t.z - (0.0 if q >= 4 else 1.1))


## Panelled walls (1+): a wainscot of boards round the sides and the front wall to rail height, a moulded rail on
## top, beaded uprights.
static func _panelling(mb: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var h := 1.0
	var y := L.cabin_y + h * 0.5
	for sgn in [-1.0, 1.0]:
		var x: float = sgn * (L.cabin_hw - 0.01)
		mb.add_box(m["pale"], Transform3D(Basis(), Vector3(x, y, (L.qd_front + L.qd_back) * 0.5)), Vector3(0.03, h, L.qd_back - L.qd_front - 0.2), 0.5)
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x - sgn * 0.02, L.cabin_y + h, (L.qd_front + L.qd_back) * 0.5)), Vector3(0.06, 0.06, L.qd_back - L.qd_front - 0.2), 1.0)
		var z := L.qd_front + 0.6
		while z < L.qd_back - 0.3:
			mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x - sgn * 0.015, y, z)), Vector3(0.03, h, 0.05), 1.0)
			z += 0.75
		# the front wall's either side of the door
		var fx: float = sgn * (L.door_hw + 0.3 + (L.cabin_hw - L.door_hw - 0.3) * 0.5)
		mb.add_box(m["pale"], Transform3D(Basis(), Vector3(fx, y, L.qd_front + 0.13)), Vector3(L.cabin_hw - L.door_hw - 0.3, h, 0.02), 0.5)
		mb.add_box(m["oak"], Transform3D(Basis(), Vector3(fx, L.cabin_y + h, L.qd_front + 0.15)), Vector3(L.cabin_hw - L.door_hw - 0.3, 0.06, 0.06), 1.0)


## The chart desk under the stern windows, port of the middle (2+): a slanted top with a chart on it, dividers, an
## inkwell and a brass lamp, a bin of rolled charts beside it, a stool.
static func desk_at(L: HullLayout) -> Vector3:
	return Vector3(-1.5, L.cabin_y, L.qd_back - 0.45)


static func _chart_desk(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var at := desk_at(L)
	mb.add_box(m["oak"], Transform3D(Basis(), at + Vector3(0, 0.36, 0)), Vector3(1.1, 0.72, 0.6), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(Vector3.RIGHT, 0.18), at + Vector3(0, 0.78, -0.02)), Vector3(1.16, 0.05, 0.66), 1.0)
	mb.add_box(m["paper"], Transform3D(Basis(Vector3.RIGHT, 0.18), at + Vector3(0.05, 0.81, -0.04)), Vector3(0.8, 0.01, 0.5), 1.0, Color(1.0, 0.95, 0.8))
	for sx in [-0.42, 0.42]:
		mb.add_box(m["trim"], Transform3D(Basis(), at + Vector3(sx, 0.36, -0.305)), Vector3(0.18, 0.56, 0.01), 1.0)
	fine.add_box(m["iron"], Transform3D(Basis(Vector3.UP, 0.5), at + Vector3(0.2, 0.84, -0.1)), Vector3(0.2, 0.01, 0.02), 1.0)
	fine.add_cylinder(m["bottle"], Transform3D(Basis(), at + Vector3(-0.42, 0.86, 0.05)), 0.04, 0.035, 0.06, 6, 1.0, Color(0.2, 0.2, 0.25))
	fine.add_cylinder(m["brass"], Transform3D(Basis(), at + Vector3(0.45, 0.86, 0.15)), 0.07, 0.05, 0.08, 6, 1.0)
	fine.add_box(m["glass"], Transform3D(Basis(), at + Vector3(0.45, 1.0, 0.15)), Vector3(0.08, 0.12, 0.08), 1.0)
	var bin := at + Vector3(-0.8, 0, 0.05)
	mb.add_cylinder(m["oak"], Transform3D(Basis(), bin), 0.17, 0.17, 0.45, 8, 1.0)
	for k in range(5):
		var a := TAU * k / 5.0
		fine.add_cylinder(m["paper"], Transform3D(Basis(Vector3.BACK, 0.12 * cos(a)), bin + Vector3(cos(a) * 0.08, 0.1, sin(a) * 0.08)), 0.035, 0.035, 0.7, 5, 1.0)
	_stool(mb, m, at + Vector3(0, 0, -0.65))


## The captain's corner (3): a partition of boards across the port aft corner round the cot, a curtain in its doorway.
static func _partition(mb: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var z := L.bed_at.z - 1.3
	var x0 := -L.cabin_hw
	var x1 := L.bed_at.x + 1.05
	var h := L.qd_y - 0.2 - L.cabin_y
	mb.add_box(m["pale"], Transform3D(Basis(), Vector3((x0 + x1) * 0.5 - 0.25, L.cabin_y + h * 0.5, z)), Vector3(x1 - x0 - 0.5, h, 0.06), 0.5)
	mb.add_box(m["oak"], Transform3D(Basis(), Vector3(x1 - 0.25, L.cabin_y + h * 0.5, z)), Vector3(0.08, h, 0.08), 1.0)
	mb.add_box(m["curtain"], Transform3D(Basis(), Vector3(x1 - 0.12, L.cabin_y + h * 0.55, z + 0.25)), Vector3(0.03, h * 0.9, 0.45), 1.0)


## A rug under the table (3+).
static func _rug(mb: MeshBuilder, m: Dictionary, L: HullLayout, q: int) -> void:
	var t := table_at(L, q)
	var size := Vector3(2.0, 0.01, 3.4) if q >= 4 else Vector3(2.4, 0.01, 1.8)
	mb.add_box(m["rug"], Transform3D(Basis(), t + Vector3(0, 0.006, 0)), size, 0.5)


## The great cabin's lounge (4): a dresser of crockery behind a curtain, brass portholes, a wall clock, barrels, a
## second bunk along the port wall.
static func _lounge(mb: MeshBuilder, fine: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	# the dresser against the starboard wall forward of the counter: cupboards under, plates stood on shelves over,
	# a curtain drawn half across
	var d := Vector3(L.cabin_hw - 0.25, L.cabin_y, L.counter_at.z - 1.55)
	mb.add_box(m["oak"], Transform3D(Basis(), d + Vector3(0, 0.42, 0)), Vector3(0.48, 0.84, 1.2), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), d + Vector3(0.1, 1.35, 0)), Vector3(0.28, 1.0, 1.2), 1.0)
	for y in [1.05, 1.4, 1.75]:
		mb.add_box(m["oak"], Transform3D(Basis(), d + Vector3(-0.08, y, 0)), Vector3(0.3, 0.03, 1.2), 1.0)
		for k in range(4):
			fine.add_cylinder(m["glaze"], Transform3D(Basis(Vector3.BACK, PI * 0.5 - 0.15), d + Vector3(-0.02, y + 0.13, -0.42 + k * 0.28)), 0.12, 0.12, 0.02, 8, 1.0, Color(0.8 + 0.2 * (k % 2), 0.9, 1.0), true, true)
	for sz in [-0.3, 0.3]:
		fine.add_box(m["brass"], Transform3D(Basis(), d + Vector3(-0.245, 0.55, sz)), Vector3(0.02, 0.05, 0.05), 1.0)
	mb.add_box(m["curtain"], Transform3D(Basis(Vector3.UP, 0.05), d + Vector3(-0.27, 1.38, 0.42)), Vector3(0.03, 0.95, 0.36), 1.0, Color(0.85, 0.85, 0.85))
	HullBuilder._line(mb, m["brass"], d + Vector3(-0.27, 1.88, -0.6), d + Vector3(-0.27, 1.88, 0.6), 0.02)
	# brass portholes down both walls
	for sgn in [-1.0, 1.0]:
		for z in [L.qd_front + 2.4, L.qd_front + 4.2]:
			if sgn > 0.0 and absf(z - d.z) < 0.9:
				continue
			var p := Vector3(sgn * (L.cabin_hw - 0.02), L.cabin_y + 1.55, z)
			var b := Basis(Vector3.BACK, PI * 0.5)
			mb.add_cylinder(m["brass"], Transform3D(b, p), 0.2, 0.2, 0.05, 10, 1.0, Color.WHITE, true, true)
			mb.add_cylinder(m["pane"], Transform3D(b, p + Vector3(-sgn * 0.03, 0, 0)), 0.14, 0.14, 0.02, 10, 1.0, Color.WHITE, true, true)
			for k in range(4):
				var a := TAU * (k + 0.5) / 4.0
				fine.add_box(m["iron"], Transform3D(Basis(), p + Vector3(-sgn * 0.03, sin(a) * 0.17, cos(a) * 0.17)), Vector3(0.02, 0.03, 0.03), 1.0)
	# a wall clock on the front wall, port of the door
	var c := Vector3(-L.door_hw - 0.9, L.cabin_y + 1.9, L.qd_front + 0.14)
	mb.add_cylinder(m["oak"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c), 0.22, 0.22, 0.06, 10, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(m["paper"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(0, 0, 0.065)), 0.17, 0.17, 0.005, 10, 1.0, Color.WHITE, true, true)
	fine.add_box(m["iron"], Transform3D(Basis(Vector3.BACK, 0.6), c + Vector3(0.03, 0.04, 0.075)), Vector3(0.015, 0.11, 0.005), 1.0)
	fine.add_box(m["iron"], Transform3D(Basis(Vector3.BACK, -1.9), c + Vector3(0.05, -0.02, 0.075)), Vector3(0.015, 0.15, 0.005), 1.0)
	mb.add_box(m["oak"], Transform3D(Basis(), c + Vector3(0, -0.4, 0)), Vector3(0.16, 0.5, 0.08), 1.0)
	fine.add_cylinder(m["brass"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(0, -0.52, 0.05)), 0.05, 0.05, 0.01, 8, 1.0, Color.WHITE, true, true)
	# barrels in the port fore corner, past the storage chest
	for e in [[Vector3(-L.cabin_hw + 0.4, 0, L.storage_at.z - 0.65), 0.3], [Vector3(-L.cabin_hw + 0.95, 0, L.storage_at.z - 0.7), 0.27]]:
		var at: Vector3 = Vector3(e[0].x, L.cabin_y, e[0].z)
		var r: float = e[1]
		mb.add_cylinder(m["crate"], Transform3D(Basis(), at), r, r, 0.85, 8, 0.6)
		for y in [0.15, 0.7]:
			fine.add_cylinder(m["iron"], Transform3D(Basis(), at + Vector3(0, y, 0)), r + 0.01, r + 0.01, 0.04, 8, 1.0)
	# a second bunk along the port wall forward of the first, its own curtain
	var b2 := L.bed_at + Vector3(0, 0, -2.35)
	_bunk(mb, fine, m, b2, 4)
	# its curtain on a rod between two posts at the open side
	for sz in [-1.05, 1.05]:
		mb.add_box(m["wood"], Transform3D(Basis(), b2 + Vector3(0.55, 0.75, sz)), Vector3(0.07, 1.5, 0.07), 1.0)
	HullBuilder._line(mb, m["brass"], b2 + Vector3(0.6, 1.45, -1.05), b2 + Vector3(0.6, 1.45, 1.05), 0.025)
	mb.add_box(m["curtain"], Transform3D(Basis(), b2 + Vector3(0.6, 0.98, 0.75)), Vector3(0.03, 0.92, 0.45), 1.0, Color(0.85, 0.85, 0.85))
