class_name CapitalInteriors
extends RefCounted
## The capital's ground floors you can walk into (1.27, docs/v1_27_plan.md C1c): a town house's ground storey hollowed
## (the floor slab, four walls with the doorway open, the ceiling; the storeys above stay solid) and furnished by what it
## is: a shop (a counter across the back, shelves of its wares on the side walls), a home (a table and chairs, a bed, a
## hearth or a cupboard, a rug), or a workshop (a bench, barrels, crates). In the house's own frame (`t`: +z out to the
## street, the front wall at d/2); everything goes into the district piece's mesh and colliders. Returns the room's
## middle (frame, on the floor): where someone inside would stand.

const M := preload("res://scripts/island/capital_models.gd")
const WALL := 0.3
## The roof hatch's shaft (square, m).
const HATCH := 1.3
## (1.27) A first floor's room height.
const UPPER_H := 3.0


static func build(mb: MeshBuilder, cols: Array, t: Transform3D, w: float, d: float, low: float, sill: float, g1: float,
		eaves: float, door_x: float, dw: float, nd: float, kind: String, seed_value: int, pad := Vector2.ZERO, roof_y := -1.0, info: Dictionary = {}) -> Vector3:
	var hw := w * 0.5
	var hd := d * 0.5
	var ceil_y := sill + g1 - 0.05
	# (1.27) a home may have its first floor too: a stair up its side wall (away from the door) through a stairwell to a
	# bedroom over the ground room. Decided first, from its own stream (the room's rng keeps its old sequence).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, 6113])
	var home := kind == "" and rng.randf() < 0.75
	var rx := hw - WALL
	var rz0 := -hd + WALL
	var urng := RandomNumberGenerator.new()
	urng.seed = hash([seed_value, "upper"])
	var up_y := sill + g1 + 0.2
	var steps := ceili((up_y - sill) / 0.21)
	var run := steps * 0.27
	var upper := home and roof_y <= 0.0 and (hd - nd) - rz0 >= run + 1.2 and rx * 2.0 >= 4.6 and eaves - up_y >= UPPER_H + 0.6 \
		and urng.randf() < 0.6
	var side := (-signf(door_x) if absf(door_x) > 0.3 else (1.0 if urng.randf() < 0.5 else -1.0))
	var lane_x := side * (rx - 0.5)
	var foot_z := rz0 + 0.2
	var top_z := foot_z + run
	# (the stairwell: over the stair from where your head would meet the ceiling, to its top)
	var hole := Rect2(minf(side * (rx - 1.0), side * rx), foot_z + run * (g1 - 2.1) / (up_y - sill), 1.0, 0.0)
	hole.size.y = top_z - hole.position.y
	# solid: the plinth under the floor and the storeys over the ceiling (the occluder only up there: one round the room
	# would hide the town from someone inside)
	M.box(cols, t * Transform3D(Basis(), Vector3(0, (low + sill) * 0.5, 0)), Vector3(w, sill - low, d))
	# (a flat-roofed one: a shaft up its back corner through the storeys, a ladder in it, a hatch onto the roof)
	var shaft := Rect2(-hw + WALL, -hd + WALL, HATCH, HATCH)
	if roof_y > 0.0:
		for r in CapitalBellTower._minus(Rect2(-hw, -hd, w, d), shaft):
			M.box(cols, t * Transform3D(Basis(), Vector3(r.get_center().x, (sill + g1 + eaves) * 0.5, r.get_center().y)), Vector3(r.size.x, eaves - sill - g1, r.size.y))
		info["hatch"] = shaft
		# (on the shaft's room side, facing the back: you climb with your back to the room and step off forward onto the roof)
		info["ladder"] = {"xf": t * Transform3D(Basis(Vector3.UP, PI), Vector3(shaft.get_center().x, roof_y, shaft.end.y - 0.12)), "length": roof_y - sill + 0.1, "rail": 0.0}
		mb.add_box(PSXMat.lit("planks_dark"), t * Transform3D(Basis(), Vector3(shaft.get_center().x, sill + g1 - 0.06, shaft.get_center().y)), Vector3(HATCH, 0.04, HATCH), 1.0, Color(0.15, 0.13, 0.12), false)
	elif upper:
		# the floor slab round the stairwell, the upper room's walls, solid again over its ceiling
		for r in CapitalBellTower._minus(Rect2(-hw, -hd, w, d), hole):
			M.box(cols, t * Transform3D(Basis(), Vector3(r.get_center().x, (sill + g1 + up_y) * 0.5, r.get_center().y)), Vector3(r.size.x, up_y - sill - g1, r.size.y))
		var uy := up_y + UPPER_H * 0.5
		M.box(cols, t * Transform3D(Basis(), Vector3(0, uy, -hd + (WALL - pad.y) * 0.5)), Vector3(w + pad.x * 2.0, UPPER_H, WALL + pad.y))
		M.box(cols, t * Transform3D(Basis(), Vector3(0, uy, hd - WALL * 0.5)), Vector3(w, UPPER_H, WALL))
		for s in [-1.0, 1.0]:
			M.box(cols, t * Transform3D(Basis(), Vector3(s * (hw - (WALL - pad.x) * 0.5), uy, 0)), Vector3(WALL + pad.x, UPPER_H, d))
		M.box(cols, t * Transform3D(Basis(), Vector3(0, (up_y + UPPER_H + eaves) * 0.5, 0)), Vector3(w, eaves - up_y - UPPER_H, d))
	else:
		M.box(cols, t * Transform3D(Basis(), Vector3(0, (sill + g1 + eaves) * 0.5, 0)), Vector3(w, eaves - sill - g1, d))
	var occ_y := up_y + UPPER_H if upper else sill + g1
	Occluders.box(cols, t * Transform3D(Basis(), Vector3(0, (occ_y + eaves) * 0.5, -0.4)), Vector3(w, eaves - occ_y, d - 0.8))
	# the walls: the back, the sides, the front either side of the door's niche
	var gy := sill + g1 * 0.5
	M.box(cols, t * Transform3D(Basis(), Vector3(0, gy, -hd + (WALL - pad.y) * 0.5)), Vector3(w + pad.x * 2.0, g1, WALL + pad.y))
	for s in [-1.0, 1.0]:
		M.box(cols, t * Transform3D(Basis(), Vector3(s * (hw - (WALL - pad.x) * 0.5), gy, 0)), Vector3(WALL + pad.x, g1, d))
	var nl := door_x - dw * 0.5 - 0.25
	var nr := door_x + dw * 0.5 + 0.25
	if nl + hw > 0.1:
		M.box(cols, t * Transform3D(Basis(), Vector3((-hw + nl) * 0.5, gy, hd - nd * 0.5)), Vector3(nl + hw, g1, nd))
	if hw - nr > 0.1:
		M.box(cols, t * Transform3D(Basis(), Vector3((nr + hw) * 0.5, gy, hd - nd * 0.5)), Vector3(hw - nr, g1, nd))
	# over the doorway
	M.box(cols, t * Transform3D(Basis(), Vector3(door_x, sill + 2.7 + (g1 - 2.7) * 0.5, hd - nd * 0.5)), Vector3(dw + 0.5, g1 - 2.7, nd))
	# the two steps up into the niche (the street is two steps under the floor)
	var top := sill - 0.32
	for k in range(2):
		var sy := top + (sill - top) * (k + 1) / 3.0
		M.box(cols, t * Transform3D(Basis(), Vector3(door_x, (sy + low) * 0.5, hd - nd + 0.15 + (1 - k) * 0.28)), Vector3(dw, sy - low, 0.3 + (1 - k) * 0.28))
	# the room's surfaces, seen from inside: the floor boards, plastered walls, the beamed ceiling
	var ix := hw - WALL
	var iz0 := -hd + WALL
	var iz1 := hd - nd
	var plank := PSXMat.lit("planks")
	var plaster := PSXMat.lit("plaster_wash")
	var floor_col := Color(0.8, 0.7, 0.58)
	mb.add_quad(plank, t * Vector3(-ix, sill + 0.01, iz0), t * Vector3(ix, sill + 0.01, iz0), t * Vector3(ix, sill + 0.01, iz1), t * Vector3(-ix, sill + 0.01, iz1),
		Vector2(0, 0), Vector2(ix, 0), Vector2(ix, iz1 - iz0), Vector2(0, iz1 - iz0), floor_col, (t.basis * Vector3.UP).normalized())
	var ceil_parts: Array = CapitalBellTower._minus(Rect2(-ix, iz0, ix * 2.0, iz1 - iz0), hole) if upper else [Rect2(-ix, iz0, ix * 2.0, iz1 - iz0)]
	for r: Rect2 in ceil_parts:
		mb.add_quad(plaster, t * Vector3(r.position.x, ceil_y, r.end.y), t * Vector3(r.end.x, ceil_y, r.end.y), t * Vector3(r.end.x, ceil_y, r.position.y), t * Vector3(r.position.x, ceil_y, r.position.y),
			Vector2(0, 0), Vector2(r.size.x * 0.5, 0), Vector2(r.size.x * 0.5, r.size.y), Vector2(0, r.size.y), Color(0.78, 0.74, 0.68), (t.basis * Vector3.DOWN).normalized())
	var wall_col := Color(0.92, 0.88, 0.8)
	var walls := [[Vector3(ix, 0, iz0), Vector3(-ix, 0, iz0), Vector3.BACK], [Vector3(-ix, 0, iz0), Vector3(-ix, 0, iz1), Vector3.RIGHT],
		[Vector3(ix, 0, iz1), Vector3(ix, 0, iz0), Vector3.LEFT]]
	for wl in walls:
		var a: Vector3 = wl[0]
		var b: Vector3 = wl[1]
		var L := a.distance_to(b)
		mb.add_quad(plaster, t * (a + Vector3(0, sill, 0)), t * (b + Vector3(0, sill, 0)), t * (b + Vector3(0, ceil_y, 0)), t * (a + Vector3(0, ceil_y, 0)),
			Vector2(0, g1 * 0.5), Vector2(L * 0.5, g1 * 0.5), Vector2(L * 0.5, 0), Vector2(0, 0), wall_col, (t.basis * (wl[2] as Vector3)).normalized())
	# the front wall's inside, either side of the doorway
	for sg in [[-ix, door_x - dw * 0.5 - 0.25], [door_x + dw * 0.5 + 0.25, ix]]:
		var a: float = sg[0]
		var b: float = sg[1]
		if b - a < 0.05:
			continue
		mb.add_quad(plaster, t * Vector3(b, sill, iz1), t * Vector3(a, sill, iz1), t * Vector3(a, ceil_y, iz1), t * Vector3(b, ceil_y, iz1),
			Vector2(0, g1 * 0.5), Vector2((b - a) * 0.5, g1 * 0.5), Vector2((b - a) * 0.5, 0), Vector2(0, 0), wall_col, (t.basis * Vector3.FORWARD).normalized())
	# beams across the ceiling
	var beam := PSXMat.lit("planks_dark")
	var bz := iz0 + 1.2
	while bz < iz1 - 0.5:
		# (short of the stairwell where one crosses it)
		var cut := upper and bz > hole.position.y - 0.1 and bz < hole.end.y + 0.1
		var bw := ix * 2.0 - (1.05 if cut else 0.0)
		mb.add_box(beam, t * Transform3D(Basis(), Vector3(-side * 0.525 if cut else 0.0, ceil_y - 0.12, bz)), Vector3(bw, 0.22, 0.2), 0.5, Color.WHITE, false)
		bz += 1.8
	var room := Rect2(-ix, iz0, ix * 2.0, iz1 - iz0)
	# (the hatch's corner kept clear: the furniture stands in the rest of the room)
	if roof_y > 0.0:
		room = Rect2(-ix + 1.6, iz0, ix * 2.0 - 1.6, iz1 - iz0)
	# (and the stair's side: the bed's upstairs)
	if upper:
		room = Rect2(-ix + (0.0 if side > 0.0 else 1.2), iz0, ix * 2.0 - 1.2, iz1 - iz0)
	if kind != "":
		_shop(mb, cols, t, room, sill, kind, rng)
	elif home:
		_home(mb, cols, t, room, sill, door_x, rng, side if upper else 0.0)
	else:
		_workshop(mb, cols, t, room, sill, door_x, rng)
	if upper:
		_upstairs(mb, cols, t, hw, hd, sill, up_y, steps, run, lane_x, foot_z, hole, side, seed_value, info)
	return t * Vector3(door_x * 0.5, sill, (iz0 + iz1) * 0.5)


## (1.27) The stair up the side wall and the bedroom over the ground room: its floor round the stairwell, a rail
## round the well, plastered walls and a beamed ceiling, the bed in the far back corner and a chest at its foot.
## info["upper"]: the stair's middle and a point on the upper floor (frame, at their heights).
static func _upstairs(mb: MeshBuilder, cols: Array, t: Transform3D, hw: float, hd: float, sill: float, up_y: float, steps: int, run: float,
		lane_x: float, foot_z: float, hole: Rect2, side: float, seed_value: int, info: Dictionary) -> void:
	var wood := PSXMat.lit("planks_dark")
	var plank := PSXMat.lit("planks")
	var plaster := PSXMat.lit("plaster_wash")
	var tread := run / steps
	for i in range(steps):
		var yt := sill + (i + 1) * (up_y - sill) / steps
		mb.add_box(wood, t * Transform3D(Basis(), Vector3(lane_x, (yt + sill) * 0.5, foot_z + (i + 0.5) * tread)), Vector3(1.0, yt - sill, tread + 0.01), 0.6, Color.WHITE, false)
	# (the feet walk a ramp along the nosings)
	var a3 := t * Vector3(lane_x, sill + 0.1, foot_z)
	var b3 := t * Vector3(lane_x, up_y + 0.1, foot_z + run)
	M.box(cols, Transform3D(Basis.looking_at(b3 - a3, Vector3.UP), (a3 + b3) * 0.5) * Transform3D(Basis(), Vector3(0, -0.2, 0)), Vector3(1.0, 0.4, a3.distance_to(b3) + 0.3))
	var ix := hw - WALL
	var iz0 := -hd + WALL
	var iz1 := hd - WALL
	var top := up_y + UPPER_H
	for r: Rect2 in CapitalBellTower._minus(Rect2(-ix, iz0, ix * 2.0, iz1 - iz0), hole):
		mb.add_quad(plank, t * Vector3(r.position.x, up_y + 0.01, r.position.y), t * Vector3(r.end.x, up_y + 0.01, r.position.y), t * Vector3(r.end.x, up_y + 0.01, r.end.y), t * Vector3(r.position.x, up_y + 0.01, r.end.y),
			Vector2(0, 0), Vector2(r.size.x, 0), Vector2(r.size.x, r.size.y), Vector2(0, r.size.y), Color(0.8, 0.7, 0.58), (t.basis * Vector3.UP).normalized())
	mb.add_quad(plaster, t * Vector3(-ix, top, iz1), t * Vector3(ix, top, iz1), t * Vector3(ix, top, iz0), t * Vector3(-ix, top, iz0),
		Vector2(0, 0), Vector2(ix, 0), Vector2(ix, iz1 - iz0), Vector2(0, iz1 - iz0), Color(0.78, 0.74, 0.68), (t.basis * Vector3.DOWN).normalized())
	var walls := [[Vector3(ix, 0, iz0), Vector3(-ix, 0, iz0), Vector3.BACK], [Vector3(-ix, 0, iz0), Vector3(-ix, 0, iz1), Vector3.RIGHT],
		[Vector3(ix, 0, iz1), Vector3(ix, 0, iz0), Vector3.LEFT], [Vector3(-ix, 0, iz1), Vector3(ix, 0, iz1), Vector3.FORWARD]]
	for wl in walls:
		var a: Vector3 = wl[0]
		var b: Vector3 = wl[1]
		var L := a.distance_to(b)
		mb.add_quad(plaster, t * (a + Vector3(0, up_y, 0)), t * (b + Vector3(0, up_y, 0)), t * (b + Vector3(0, top, 0)), t * (a + Vector3(0, top, 0)),
			Vector2(0, UPPER_H * 0.5), Vector2(L * 0.5, UPPER_H * 0.5), Vector2(L * 0.5, 0), Vector2(0, 0), Color(0.92, 0.88, 0.8), (t.basis * (wl[2] as Vector3)).normalized())
	# the rail round the well (its room side and its back end; you step off its top end)
	var xi := side * (ix - 1.0)
	var rail_l := hole.size.y
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(xi, up_y + 0.5, hole.get_center().y)), Vector3(0.08, 1.0, rail_l), 0.6, Color.WHITE)
	M.box(cols, t * Transform3D(Basis(), Vector3(xi, up_y + 0.5, hole.get_center().y)), Vector3(0.1, 1.0, rail_l))
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(lane_x, up_y + 0.5, hole.position.y)), Vector3(1.0, 1.0, 0.08), 0.6, Color.WHITE)
	M.box(cols, t * Transform3D(Basis(), Vector3(lane_x, up_y + 0.5, hole.position.y)), Vector3(1.0, 1.0, 0.1))
	# the bed in the back corner away from the stair, a chest at its foot
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bedroom"])
	var bt := t * Transform3D(Basis(), Vector3(-side * (ix - 1.0), up_y, iz0 + 1.05))
	_bed(mb, cols, bt, rng)
	mb.add_box(wood, bt * Transform3D(Basis(), Vector3(0, 0.3, 1.45)), Vector3(1.0, 0.6, 0.55), 0.6, Color(0.8, 0.62, 0.45))
	M.box(cols, bt * Transform3D(Basis(), Vector3(0, 0.3, 1.45)), Vector3(1.0, 0.6, 0.55))
	info["upper"] = {"stair": t * Vector3(lane_x, (sill + up_y) * 0.5, foot_z + run * 0.5), "floor": t * Vector3(-side * 0.3, up_y, iz1 - 1.0), "y": up_y}


## A shop: the counter across the back (the keeper's side behind it), shelves of its wares down the side walls.
static func _shop(mb: MeshBuilder, cols: Array, t: Transform3D, room: Rect2, y: float, kind: String, rng: RandomNumberGenerator) -> void:
	var wood := PSXMat.lit("planks_dark")
	var cz := room.position.y + 1.4
	var cw := room.size.x - 1.6
	var ct := t * Transform3D(Basis(), Vector3(0, y + 0.5, cz))
	mb.add_box(wood, ct, Vector3(cw, 1.0, 0.7), 0.6, Color.WHITE)
	mb.add_box(PSXMat.lit("planks"), ct * Transform3D(Basis(), Vector3(0, 0.53, 0)), Vector3(cw + 0.1, 0.06, 0.8), 0.6, Color(0.9, 0.82, 0.7))
	M.box(cols, ct, Vector3(cw, 1.0, 0.7))
	var goods: Array = CapitalStyle.STYLE["goods"]
	for s in [-1.0, 1.0]:
		var sx: float = s * (room.size.x * 0.5 - 0.25)
		var sl := room.size.y - 2.4
		var st := t * Transform3D(Basis(), Vector3(sx, y, room.position.y + 2.2 + sl * 0.5))
		for k in range(3):
			mb.add_box(wood, st * Transform3D(Basis(), Vector3(0, 0.5 + k * 0.6, 0)), Vector3(0.45, 0.05, sl), 0.6, Color.WHITE, false)
			var n := int(sl / 0.4)
			for i in range(n):
				if rng.randf() < 0.3:
					continue
				var gz: float = -sl * 0.5 + 0.2 + i * 0.4
				mb.add_box(M.mat("cloth"), st * Transform3D(Basis(), Vector3(0, 0.66 + k * 0.6, gz)), Vector3(0.28, 0.26, 0.28), 1.0, goods[rng.randi() % goods.size()], false)
		M.box(cols, st * Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(0.45, 2.0, sl))
	# something of the trade on the counter
	for i in range(3):
		var gx: float = rng.randf_range(-cw * 0.4, cw * 0.4)
		mb.add_box(M.mat("cloth"), ct * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(gx, 0.66, 0)), Vector3(0.24, 0.2, 0.24), 1.0, goods[rng.randi() % goods.size()], false)


## A home: a table with two chairs, a bed against the back wall, a hearth or a cupboard on a side wall, a rug.
static func _home(mb: MeshBuilder, cols: Array, t: Transform3D, room: Rect2, y: float, door_x: float, rng: RandomNumberGenerator, upstairs := 0.0) -> void:
	var wood := PSXMat.lit("planks_dark")
	var pale := PSXMat.lit("planks")
	var c := room.get_center()
	var tx := c.x - door_x * 0.4
	var tt := t * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), Vector3(tx, y, c.y))
	mb.add_box(pale, tt * Transform3D(Basis(), Vector3(0, 0.76, 0)), Vector3(1.3, 0.06, 0.8), 0.6, Color(0.92, 0.82, 0.68), false)
	for s in [Vector2(-0.55, -0.32), Vector2(0.55, -0.32), Vector2(-0.55, 0.32), Vector2(0.55, 0.32)]:
		mb.add_box(wood, tt * Transform3D(Basis(), Vector3(s.x, 0.37, s.y)), Vector3(0.07, 0.74, 0.07), 0.6, Color.WHITE, false)
	M.box(cols, tt * Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(1.3, 0.8, 0.8))
	for s in [-1.0, 1.0]:
		var ch := tt * Transform3D(Basis(Vector3.UP, PI * 0.5 * (1.0 - s)), Vector3(s * 0.95, 0, 0))
		mb.add_box(wood, ch * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(0.42, 0.05, 0.42), 0.6, Color.WHITE, false)
		mb.add_box(wood, ch * Transform3D(Basis(), Vector3(0.19, 0.75, 0)), Vector3(0.05, 0.6, 0.42), 0.6, Color.WHITE, false)
	# the bed along the back wall, in a corner (none down here when there's an upstairs: `upstairs` is the stair's side)
	var bs := -1.0 if rng.randf() < 0.5 else 1.0
	if upstairs != 0.0:
		bs = upstairs
	var bt := t * Transform3D(Basis(), Vector3(c.x + bs * (room.size.x * 0.5 - 1.0), y, room.position.y + 1.05))
	if upstairs == 0.0:
		_bed(mb, cols, bt, rng)
	# a hearth or a cupboard on the other side wall
	var hs := -bs
	var ht := t * Transform3D(Basis(Vector3.UP, -hs * PI * 0.5), Vector3(c.x + hs * (room.size.x * 0.5 - 0.35), y, c.y))
	if rng.randf() < 0.5:
		var stone := M.mat("lime")
		mb.add_box(stone, ht * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.6, 1.2, 0.7), 0.6, Color(0.8, 0.76, 0.7))
		mb.add_box(PSXMat.flat(Color(0.08, 0.06, 0.05)), ht * Transform3D(Basis(), Vector3(0, 0.45, 0.3)), Vector3(0.9, 0.7, 0.12), 1.0, Color.WHITE, false)
		mb.add_box(PSXMat.glow(Color(1.0, 0.5, 0.2), 1.6), ht * Transform3D(Basis(), Vector3(0, 0.2, 0.32)), Vector3(0.6, 0.16, 0.1), 1.0, Color.WHITE, false)
		M.box(cols, ht * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.6, 1.2, 0.7))
	else:
		mb.add_box(wood, ht * Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(1.4, 2.0, 0.55), 0.6, Color.WHITE)
		mb.add_box(pale, ht * Transform3D(Basis(), Vector3(0, 1.0, 0.29)), Vector3(1.2, 1.7, 0.03), 0.6, Color(0.9, 0.8, 0.66), false)
		M.box(cols, ht * Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(1.4, 2.0, 0.55))
	# a rug under the table
	var rugs: Array = CapitalStyle.STYLE["pennants"]
	mb.add_box(M.mat("cloth"), t * Transform3D(Basis(), Vector3(tx, y + 0.02, c.y)), Vector3(2.4, 0.02, 1.7), 1.0, (rugs[rng.randi() % rugs.size()] as Color) * 0.7, false)


## A workshop: a bench along one wall with its tools, barrels and crates in the corners.
static func _workshop(mb: MeshBuilder, cols: Array, t: Transform3D, room: Rect2, y: float, door_x: float, rng: RandomNumberGenerator) -> void:
	var wood := PSXMat.lit("planks_dark")
	var bw := room.size.x - 1.4
	var bt := t * Transform3D(Basis(), Vector3(0, y, room.position.y + 0.6))
	mb.add_box(wood, bt * Transform3D(Basis(), Vector3(0, 0.88, 0)), Vector3(bw, 0.1, 0.8), 0.6, Color.WHITE)
	for s in [-1.0, 1.0]:
		mb.add_box(wood, bt * Transform3D(Basis(), Vector3(s * (bw * 0.5 - 0.1), 0.42, 0)), Vector3(0.12, 0.84, 0.7), 0.6, Color.WHITE, false)
	M.box(cols, bt * Transform3D(Basis(), Vector3(0, 0.46, 0)), Vector3(bw, 0.92, 0.8))
	for i in range(4):
		mb.add_box(M.mat("iron"), bt * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-bw * 0.4, bw * 0.4), 0.97, rng.randf_range(-0.2, 0.2))), Vector3(0.4, 0.05, 0.08), 1.0, Color.WHITE, false)
	for k in range(rng.randi_range(2, 4)):
		var cx: float = (room.size.x * 0.5 - 0.6) * (1.0 if k % 2 == 0 else -1.0)
		var cz: float = room.position.y + room.size.y - 0.9 - float(k / 2) * 0.9
		if absf(cx - door_x) < 1.2:
			continue
		var prop := Props.barrel() if k % 2 == 0 else Props.crate(0.7)
		CapitalDistrict.absorb(mb, cols, prop, t * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cx, y, cz)))


## A bed at `bt` (its middle on the floor, the head to the back): frame, blanket, pillow.
static func _bed(mb: MeshBuilder, cols: Array, bt: Transform3D, rng: RandomNumberGenerator) -> void:
	mb.add_box(PSXMat.lit("planks_dark"), bt * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(1.8, 0.5, 2.0), 0.6, Color.WHITE)
	var blanket: Array = CapitalStyle.STYLE["pennants"]
	mb.add_box(M.mat("cloth"), bt * Transform3D(Basis(), Vector3(0, 0.53, 0.15)), Vector3(1.7, 0.08, 1.6), 1.0, (blanket[rng.randi() % blanket.size()] as Color) * 0.85, false)
	mb.add_box(M.mat("cloth"), bt * Transform3D(Basis(), Vector3(0, 0.6, -0.75)), Vector3(1.3, 0.14, 0.4), 1.0, Color(0.94, 0.92, 0.88), false)
	M.box(cols, bt * Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(1.8, 0.6, 2.0))
