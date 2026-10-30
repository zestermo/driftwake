class_name CapitalGardens
extends RefCounted
## The palace gardens (1.27, docs/v1_27_plan.md C2): on the hilltop plateau inside the ring wall, either side of the
## throne hall. West: a hedge maze rolled from the world's seed (a depth-first maze of 3.5 m cells, 2.4 m hedges), its
## way in on the side toward the hall, a statue and a chest at its far corner. East: the formal garden (clipped cones
## in rows, flower beds, a fountain, benches). Frame coordinates, into the district's own piece.

const M := preload("res://scripts/island/capital_models.gd")
const P := preload("res://scripts/island/capital_plan.gd")
const MAZE := Rect2(-42.0, -180.0, 17.5, 28.0)
const GARDEN := Rect2(24.0, -180.0, 18.0, 28.0)
const CELL := 3.5
const HEDGE_H := 2.4
const HEDGE_T := 0.7


## The maze's heart (frame, on the ground): the far corner from its way in, where the statue and the chest are.
static func heart() -> Vector3:
	var q := MAZE.position + Vector2(CELL * 0.5, CELL * 0.5)
	return M.v3(q, P.ground(q))


static func build(out: Dictionary, world_seed: int) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	_maze(mb, cols, world_seed)
	_garden(mb, cols)
	CapitalDistrict._piece(out, "Gardens", mb, cols)


static func _maze(mb: MeshBuilder, cols: Array, world_seed: int) -> void:
	var nx := int(MAZE.size.x / CELL)
	var nz := int(MAZE.size.y / CELL)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, 70707])
	# walls between cells: wall_e[x][z] (east of cell x,z), wall_s[x][z] (south of it); a depth-first carve opens them
	var open_e := {}
	var open_s := {}
	var seen := {Vector2i(0, 0): true}
	var stack: Array = [Vector2i(0, 0)]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var nexts: Array = []
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + dv
			if nb.x >= 0 and nb.x < nx and nb.y >= 0 and nb.y < nz and not seen.has(nb):
				nexts.append(nb)
		if nexts.is_empty():
			stack.pop_back()
			continue
		var nb: Vector2i = nexts[rng.randi() % nexts.size()]
		if nb.x != cur.x:
			open_e[Vector2i(mini(nb.x, cur.x), cur.y)] = true
		else:
			open_s[Vector2i(cur.x, mini(nb.y, cur.y))] = true
		seen[nb] = true
		stack.append(nb)
	var hedge := PSXMat.lit("leaves", Color(0.36, 0.56, 0.32))
	var y := P.ground(MAZE.get_center())
	var put := func(a: Vector2, b: Vector2) -> void:
		var c := (a + b) * 0.5
		var L := a.distance_to(b) + HEDGE_T
		var along_x := absf(b.x - a.x) > absf(b.y - a.y)
		var size := Vector3(L, HEDGE_H, HEDGE_T) if along_x else Vector3(HEDGE_T, HEDGE_H, L)
		var bt := M.xf(M.v3(c, y + HEDGE_H * 0.5))
		mb.add_box(hedge, bt, size, 0.5, Color(0.9, 0.95, 0.9))
		M.box(cols, bt, size)
	var o := MAZE.position
	# the outer hedge, its way in at the east side's southern cell (toward the hall and the court)
	put.call(o, o + Vector2(MAZE.size.x, 0))
	put.call(o + Vector2(0, MAZE.size.y), o + Vector2(MAZE.size.x, MAZE.size.y))
	put.call(o, o + Vector2(0, MAZE.size.y))
	put.call(o + Vector2(MAZE.size.x, 0), o + Vector2(MAZE.size.x, (nz - 1) * CELL))
	# the inner hedges: every wall the carve left shut
	for x in range(nx):
		for z in range(nz):
			var c0 := o + Vector2(x * CELL, z * CELL)
			if x < nx - 1 and not open_e.has(Vector2i(x, z)):
				put.call(c0 + Vector2(CELL, 0), c0 + Vector2(CELL, CELL))
			if z < nz - 1 and not open_s.has(Vector2i(x, z)):
				put.call(c0 + Vector2(0, CELL), c0 + Vector2(CELL, CELL))
	# the heart: a statue on its plinth, a chest at its feet (the hidden caches fill it: C4)
	var h := heart()
	var hq := Vector2(h.x, h.z)
	mb.add_box(M.mat("lime"), M.xf(M.v3(hq, y + 0.4)), Vector3(1.0, 0.8, 1.0), 0.6, Color(0.92, 0.9, 0.86))
	CapitalDistrict._figure(mb, M.xf(M.v3(hq, y + 0.8), PI * 0.25), 1.8, false)
	M.box(cols, M.xf(M.v3(hq, y + 1.2)), Vector3(1.0, 2.4, 1.0))
	var chest := MeshBuilder.from_mesh(Props.treasure_chest_mesh())
	chest.rebind(M.xf(M.v3(hq + Vector2(1.1, 0.9), y), PI * 0.75), 0)
	mb.merge(chest)
	M.box(cols, M.xf(M.v3(hq + Vector2(1.1, 0.9), y + 0.35), PI * 0.75), Vector3(1.0, 0.7, 0.7))


## The formal garden: rows of clipped cones, flower beds between them, a fountain in the middle, benches facing it.
static func _garden(mb: MeshBuilder, cols: Array) -> void:
	var c := GARDEN.get_center()
	var y := P.ground(c)
	var hedge := PSXMat.lit("leaves", Color(0.36, 0.56, 0.32))
	var lime := M.mat("lime")
	var flowers: Array = [Color(0.9, 0.24, 0.3), Color(0.98, 0.84, 0.3), Color(0.82, 0.5, 0.86), Color(0.96, 0.96, 0.92)]
	for sx in [-1.0, 1.0]:
		for k in range(5):
			var q := c + Vector2(sx * (GARDEN.size.x * 0.5 - 1.5), -GARDEN.size.y * 0.5 + 2.5 + k * 5.6)
			mb.add_cylinder(lime, M.xf(M.v3(q, y)), 0.5, 0.5, 0.4, 8, 0.5, Color(0.9, 0.88, 0.84))
			mb.add_cone(hedge, M.xf(M.v3(q, y + 0.4)), 0.7, 2.4, 8, 1.0, Color(0.9, 0.95, 0.9))
			M.cyl(cols, M.v3(q, y), 0.6, 2.8)
	for sz in [-1.0, 1.0]:
		var bed := M.xf(M.v3(c + Vector2(0, sz * 8.0), y + 0.15))
		mb.add_box(lime, bed, Vector3(9.0, 0.3, 3.0), 0.6, Color(0.88, 0.86, 0.82))
		mb.add_box(PSXMat.lit("dirt") if ResourceLoader.exists("res://assets/textures/psx/dirt.png") else lime, bed * Transform3D(Basis(), Vector3(0, 0.16, 0)), Vector3(8.6, 0.04, 2.6), 0.6, Color(0.5, 0.36, 0.24), false)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4040 + int(sz)
		for i in range(40):
			var fq := Vector3(rng.randf_range(-4.0, 4.0), 0.32, rng.randf_range(-1.1, 1.1))
			mb.add_box(M.mat("cloth"), bed * Transform3D(Basis(), fq), Vector3(0.13, 0.12, 0.13), 1.0, flowers[i % flowers.size()], false)
		M.box(cols, bed, Vector3(9.0, 0.3, 3.0))
	mb.add_cylinder(lime, M.xf(M.v3(c, y)), 2.2, 2.2, 0.6, 14, 0.5, Color(0.94, 0.92, 0.88), true, false)
	mb.add_cylinder(PSXMat.flat(Color(0.3, 0.5, 0.6)), M.xf(M.v3(c, y + 0.5)), 2.0, 2.0, 0.02, 14, 0.5)
	mb.add_cylinder(lime, M.xf(M.v3(c, y + 0.5)), 0.3, 0.25, 1.4, 8, 0.5, Color(0.92, 0.9, 0.86))
	M.cyl(cols, M.v3(c, y), 2.2, 0.7)
	for s in [-1.0, 1.0]:
		var bt := M.xf(M.v3(c + Vector2(s * 4.0, 0), y), PI * 0.5 * s)
		mb.add_box(PSXMat.lit("planks_dark"), bt * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(1.8, 0.08, 0.5), 0.6, Color.WHITE)
		mb.add_box(lime, bt * Transform3D(Basis(), Vector3(0, 0.22, 0)), Vector3(1.6, 0.44, 0.3), 0.6, Color(0.9, 0.88, 0.84), false)
		M.box(cols, bt * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(1.8, 0.5, 0.5))
