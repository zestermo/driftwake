extends RefCounted
## The coral atoll's reef under the water (1.28.1, Zach: "a dense fun area to explore deeply"): coral gardens over the
## lagoon floor, thickest on the coral heads and along the reef flat and drop-off outside the ring (branch and brain
## coral, sea fans, tube sponges, anemones, kelp), giant clams on the deeper floor to open for a Lagoon Pearl, coral
## outcrops to break a Coral Spar off (the skimmer's atoll parts: GadgetData), and big life gliding over it all: eagle
## rays and sea turtles on the shoal shader. The gardens are MultiMeshes by kind, colour and CELL-metre cell, each at its
## cell's middle so its range (SEE) is measured from where its corals are (no collision), the clams and outcrops Interactables usable in the water, each taken once (GameManager.opened).
## Everything comes from the island's seed: the same reef on every screen. The build step: AtollTheme.steps.

const D := preload("res://scripts/island/themes/atoll_data.gd")
const SHOALS := preload("res://scripts/island/themes/atoll_shoals.gd")
const DIVE := preload("res://scripts/swim/dive_sites.gd")

## How far a garden is drawn (m), how many places are tried, and the most corals put down.
const SEE := 110.0
const CELL := 60.0
const TRIES := 9000
## The garden patches: how many, how far apart at least, their radius and how many corals each; the scatter between.
const PATCHES := 75
const PATCH_GAP := 22.0
const PATCH_R := [4.0, 9.0]
const PATCH_N := [30, 60]
const SCATTER := 900
## The chance a tried spot gets a garden patch: on a coral head, on the lagoon floor, on the reef outside the ring.
const ON_HEAD := 0.85
const ON_FLOOR := 0.32
const ON_REEF := 0.55
## Corals by kind: [name, weight on a head, on the floor, on the reef, two colours].
const KINDS := [
	["branch", 3.0, 1.0, 2.0, [Color(1.0, 0.55, 0.62), Color(0.95, 0.82, 0.72)]],
	["brain", 2.0, 1.5, 2.0, [Color(0.85, 0.75, 0.35), Color(0.55, 0.78, 0.5)]],
	["fan", 1.5, 0.4, 2.5, [Color(0.75, 0.35, 0.85), Color(1.0, 0.45, 0.3)]],
	["tube", 1.5, 0.8, 1.5, [Color(1.0, 0.65, 0.2), Color(0.45, 0.6, 1.0)]],
	["anemone", 1.0, 1.0, 0.6, [Color(1.0, 0.4, 0.55), Color(0.55, 1.0, 0.85)]],
	["kelp", 0.3, 1.6, 2.0, [Color(0.35, 0.6, 0.25), Color(0.55, 0.62, 0.22)]],
]
const CLAMS := 8
const OUTCROPS := 10
## What each gives: [item id, least, most]; ids nobody has made yet (the skimmer's parts before they land) are skipped.
const CLAM_LOOT := [["lagoon_pearl", 1, 1], ["pearl", 0, 1]]
const SPAR_LOOT := [["coral_spar", 2, 2]]

static var _meshes := {}


static func build(isl) -> void:
	var L = isl._theme.LAND_FEATURES
	var lp: Dictionary = isl.land_plan
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "atoll_reef"])
	var node := Node3D.new()
	node.name = "AtollReef"
	isl.add_child(node)
	if _meshes.is_empty():
		_make_meshes()
	var reach := float(isl.radius) + D.REEF_FLAT + D.DROP
	# the gardens: dense patches (on the heads, along the reef, now and then on the lagoon floor) and a scatter between
	var lists := {}
	var centres: Array = []
	for i in range(TRIES):
		if centres.size() >= PATCHES:
			break
		var q := Vector2.from_angle(rng.randf() * TAU) * reach * sqrt(rng.randf())
		var h: float = isl.hv(q)
		if h > -0.9 or h < -12.0:
			continue
		var inside: bool = q.length() < float(L.ring_r(isl, q.angle())[1])
		var head := inside and h > D.HEADS_Y - 0.6
		if rng.randf() > (ON_HEAD if head else (ON_FLOOR if inside else ON_REEF)):
			continue
		if centres.any(func(c): return Vector2(c[0].x, c[0].z).distance_to(q) < PATCH_GAP):
			continue
		centres.append([Vector3(q.x, h, q.y), 1 if head else (2 if inside else 3)])
	for c in centres:
		var at: Vector3 = c[0]
		var r := rng.randf_range(PATCH_R[0], PATCH_R[1])
		for k in range(rng.randi_range(PATCH_N[0], PATCH_N[1])):
			var off := Vector2.from_angle(rng.randf() * TAU) * r * sqrt(rng.randf())
			var q := Vector2(at.x, at.z) + off
			var h: float = isl.hv(q)
			if h > -0.75:
				continue
			_put(lists, rng, int(c[1]), q, h, rng.randf_range(0.8, 2.2) * (1.0 - 0.4 * off.length() / r))
	for i in range(SCATTER):
		var q := Vector2.from_angle(rng.randf() * TAU) * reach * sqrt(rng.randf())
		var h: float = isl.hv(q)
		if h > -0.75 or h < -16.0:
			continue
		var inside: bool = q.length() < float(L.ring_r(isl, q.angle())[1])
		_put(lists, rng, 2 if inside else 3, q, h, rng.randf_range(0.6, 1.4))
	for key in lists:
		var parts: PackedStringArray = (key as String).split("_")
		var mid := Vector3((int(parts[2]) + 0.5) * CELL, 0.0, (int(parts[3]) + 0.5) * CELL)
		_garden(node, _meshes["%s_%s" % [parts[0], parts[1]]], lists[key], mid)
	# the clams and outcrops inside the gardens: the outcrops on the heads' and reef's patches, the clams on the floor's
	# (or any patch deep enough), a little off each patch's middle
	var sid := int(isl.node["seed"])
	var deep: Array = centres.filter(func(c): return (c[0] as Vector3).y < -1.6)
	var high: Array = centres.filter(func(c): return int(c[1]) != 2)
	for i in range(mini(CLAMS, deep.size())):
		var c: Vector3 = deep[(i * 7) % deep.size()][0]
		var q := Vector2(c.x, c.z) + Vector2.from_angle(rng.randf() * TAU) * 1.8
		_clam(node, Vector3(q.x, isl.hv(q), q.y), "atoll%d_clam%d" % [sid, i], rng)
	for i in range(mini(OUTCROPS, high.size())):
		var c: Vector3 = high[(i * 5 + 3) % high.size()][0]
		var q := Vector2(c.x, c.z) + Vector2.from_angle(rng.randf() * TAU) * 1.2
		_outcrop(node, Vector3(q.x, isl.hv(q), q.y), "atoll%d_spar%d" % [sid, i], rng)
	# the big life: eagle rays and sea turtles gliding round the lagoon
	for i in range(4):
		var a := rng.randf() * TAU
		var q := Vector2.from_angle(a) * float(L.ring_r(isl, a)[1]) * rng.randf_range(0.2, 0.8)
		var h: float = isl.hv(q)
		if h > -1.8:
			continue
		var turtle := i % 2 == 1
		SHOALS._add(node, _meshes["turtle" if turtle else "ray"], 0, Vector3(q.x, h + 0.9, q.y), rng.randi_range(1, 3), rng.randf_range(7.0, 14.0), 0.5,
			Color(0.5, 0.42, 0.28) if turtle else Color(0.22, 0.26, 0.32), rng, SEE)


## One MultiMesh of a coral kind and colour over one cell, placed at the cell's middle `mid`.
static func _garden(node: Node3D, mesh: Mesh, xfs: Array, mid: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in range(xfs.size()):
		var xf: Transform3D = xfs[i]
		xf.origin -= mid
		mm.set_instance_transform(i, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Corals%d" % node.get_child_count()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = SEE
	node.add_child(mmi)
	mmi.position = mid


## A giant clam half open on the floor, a pearl glowing inside: F to take it (once).
static func _clam(node: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "Clam_" + key
	node.add_child(holder)
	holder.position = at
	var opened: bool = node.get_node("/root/GameManager").opened.has(key)
	var mb := MeshBuilder.new()
	var shell := PSXMat.lit("", Color(0.92, 0.88, 0.8))
	var lip := PSXMat.lit("", Color.WHITE)
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	mb.add_blob(shell, Transform3D(b, Vector3(0, 0.12, 0)), Vector3(0.75, 0.25, 0.5), rng, 0.12, 3, 8)
	mb.add_blob(shell, Transform3D(b * Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.32, 0) + b * Vector3(0, 0, 0.22)), Vector3(0.75, 0.22, 0.5), rng, 0.12, 3, 8)
	mb.add_blob(lip, Transform3D(b, Vector3(0, 0.24, -0.05)), Vector3(0.66, 0.08, 0.4), rng, 0.05, 2, 8, 1.0, Color(0.2, 0.75, 1.0))
	var m := mb.to_instance("Clam")
	DIVE._quiet(m)
	holder.add_child(m)
	var pearl := MeshBuilder.new()
	pearl.add_blob(PSXMat.glow(Color(1.0, 0.95, 0.88), 0.7), Transform3D(Basis(), Vector3(0, 0.3, -0.05)), Vector3.ONE * 0.09, rng, 0.0, 3, 6)
	var pm := pearl.to_instance("Pearl")
	DIVE._quiet(pm)
	pm.visible = not opened
	holder.add_child(pm)
	var it := DIVE._pickup_area(holder, "Open the giant clam", 1.6)
	it.interacted.connect(func(player: Player): _take(player, key, CLAM_LOOT, "The clam gives up its pearl.", pm))


## A coral outcrop of pale branching coral on a head: F to break a spar off (once).
static func _outcrop(node: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "Spar_" + key
	node.add_child(holder)
	holder.position = at
	var opened: bool = node.get_node("/root/GameManager").opened.has(key)
	var mb := MeshBuilder.new()
	var coral := PSXMat.lit("", Color.WHITE)
	_branches(mb, coral, rng, 1.6, Color(0.96, 0.9, 0.86))
	var m := mb.to_instance("Outcrop")
	DIVE._quiet(m)
	holder.add_child(m)
	var tip := MeshBuilder.new()
	tip.add_tube(coral, PackedVector3Array([Vector3(0.3, 0.2, 0.0), Vector3(0.45, 0.9, 0.1), Vector3(0.5, 1.6, 0.05)]), 0.07, 0.03, 4, 1.0, Color(1.0, 0.75, 0.8))
	var tm := tip.to_instance("Spar")
	DIVE._quiet(tm)
	tm.visible = not opened
	holder.add_child(tm)
	var it := DIVE._pickup_area(holder, "Break off a coral spar", 1.8)
	it.interacted.connect(func(player: Player): _take(player, key, SPAR_LOOT, "A spar of coral snaps off clean.", tm))


## One coral at `q` (ground height h), its kind picked by where it is (`col`: 1 a head, 2 the floor, 3 the reef).
static func _put(lists: Dictionary, rng: RandomNumberGenerator, col: int, q: Vector2, h: float, s: float) -> void:
	var tot := 0.0
	for k in KINDS:
		tot += float(k[col])
	var x := rng.randf() * tot
	var ki := 0
	while ki < KINDS.size() - 1 and x > float(KINDS[ki][col]):
		x -= float(KINDS[ki][col])
		ki += 1
	var cell := Vector2i(floori(q.x / CELL), floori(q.y / CELL))
	var key := "%d_%d_%d_%d" % [ki, rng.randi() % 2, cell.x, cell.y]
	if not lists.has(key):
		lists[key] = []
	(lists[key] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(q.x, h - 0.05, q.y)))


## Take `table`'s roll once for `key` (only items the game has), the shown piece hidden after.
static func _take(player: Player, key: String, table: Array, line: String, shown: Node3D) -> void:
	var gm := player.get_node("/root/GameManager")
	if gm.opened.has(key):
		player.call("_toast", "Nothing left here")
		return
	# (a part the game doesn't have yet becomes a plain pearl, as many)
	var have: Array = table.map(func(e): return e if ItemDB.get_item(str(e[0])) != null else ["pearl", e[1], e[2]])
	DIVE._take(player, key, have, shown.global_position, line, shown)
	if gm.opened.has(key):
		shown.visible = false
		player.get_node("/root/FX").bubbles(shown.global_position, 8)


# --------------------------------------------------------------------------
# The meshes (built once)
# --------------------------------------------------------------------------
static func _make_meshes() -> void:
	var mat := PSXMat.lit("", Color.WHITE)
	for ki in range(KINDS.size()):
		for ci in range(2):
			var rng := RandomNumberGenerator.new()
			rng.seed = 501 + ki * 7 + ci
			var col: Color = KINDS[ki][4][ci]
			var mb := MeshBuilder.new()
			match str(KINDS[ki][0]):
				"branch":
					_branches(mb, mat, rng, 0.9, col)
				"brain":
					mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(0.55, 0.42, 0.5), rng, 0.08, 3, 9, 1.0, col)
					for g in range(4):
						var a := g * PI / 4.0
						mb.add_box(mat, Transform3D(Basis(Vector3.UP, a), Vector3(0, 0.42, 0)), Vector3(0.9, 0.04, 0.05), 0.5, col.darkened(0.25), false)
				"fan":
					# a sea fan: a lattice of thin branches spread up and out in one plane from a short stalk
					mb.add_cylinder(mat, Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.05, 0.04, 0.25, 4, 0.5, col.darkened(0.3))
					for t in range(9):
						var a := lerpf(-1.2, 1.2, t / 8.0)
						var tip := Vector3(sin(a) * 0.65, 0.25 + cos(a) * 0.75, 0.0)
						mb.add_tube(mat, PackedVector3Array([Vector3(0, 0.22, 0), tip * 0.55 + Vector3(0, 0.1, 0.02), tip]), 0.025, 0.012, 3, 1.0, col)
					for r in [0.45, 0.7]:
						var arc := PackedVector3Array()
						for t in range(7):
							var a := lerpf(-1.1, 1.1, t / 6.0)
							arc.append(Vector3(sin(a) * 0.65 * r, 0.25 + cos(a) * 0.75 * r, 0.0))
						mb.add_tube(mat, arc, 0.015, 0.015, 3, 1.0, col.lightened(0.15))
				"tube":
					for t in range(4):
						var off := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
						var hh := rng.randf_range(0.35, 0.85)
						mb.add_cylinder(mat, Transform3D(Basis(), off + Vector3(0, hh * 0.5, 0)), 0.1, 0.12, hh, 6, 0.5, col, false, false)
						mb.add_cylinder(mat, Transform3D(Basis(), off + Vector3(0, hh, 0)), 0.07, 0.07, 0.02, 6, 0.5, col.darkened(0.5))
				"anemone":
					mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0.12, 0)), Vector3(0.28, 0.14, 0.28), rng, 0.05, 2, 7, 1.0, col.darkened(0.3))
					for t in range(12):
						var a := t * TAU / 12.0
						var p0 := Vector3(cos(a) * 0.2, 0.2, sin(a) * 0.2)
						mb.add_tube(mat, PackedVector3Array([p0, p0 * 1.6 + Vector3(0, 0.25, 0), p0 * 1.9 + Vector3(0, 0.45, 0)]), 0.035, 0.012, 3, 1.0, col)
				"kelp":
					for t in range(3):
						var off := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
						var hh := rng.randf_range(1.4, 2.6)
						mb.add_tube(mat, PackedVector3Array([off, off + Vector3(0.15, hh * 0.5, 0.05), off + Vector3(-0.1, hh, 0.1)]), 0.06, 0.03, 3, 1.0, col)
			_meshes["%d_%d" % [ki, ci]] = mb.commit()
	_meshes["ray"] = _ray()
	_meshes["turtle"] = _turtle()


## Branching coral: a few tubes forking up from a base.
static func _branches(mb: MeshBuilder, mat: Material, rng: RandomNumberGenerator, h: float, col: Color) -> void:
	for b in range(6):
		var a := rng.randf() * TAU
		var p0 := Vector3(cos(a) * 0.1, 0.0, sin(a) * 0.1)
		var p1 := p0 + Vector3(cos(a) * 0.25, h * rng.randf_range(0.4, 0.6), sin(a) * 0.25)
		var p2 := p1 + Vector3(cos(a + 0.6) * 0.15, h * rng.randf_range(0.3, 0.45), sin(a + 0.6) * 0.15)
		mb.add_tube(mat, PackedVector3Array([p0, p1, p2]), 0.06 * h, 0.025, 4, 1.0, col)
		mb.add_tube(mat, PackedVector3Array([p1, p1 + Vector3(cos(a - 0.8) * 0.2, h * 0.25, sin(a - 0.8) * 0.2)]), 0.035 * h, 0.02, 4, 1.0, col)


## An eagle ray: a broad flat diamond with a long thin tail (nose -z, for the shoal shader).
static func _ray() -> ArrayMesh:
	var v := PackedVector3Array([
		Vector3(0, 0, -0.5), Vector3(-0.9, 0.05, 0.1), Vector3(0, 0.08, 0.3), Vector3(0.9, 0.05, 0.1),
		Vector3(-0.02, 0, 0.3), Vector3(0.02, 0, 0.3), Vector3(0, 0, 1.4)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## A sea turtle: a domed shell and four flippers (nose -z).
static func _turtle() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var mat := PSXMat.lit("", Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	mb.add_blob(mat, Transform3D(), Vector3(0.45, 0.18, 0.6), rng, 0.05, 2, 8)
	mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0.0, -0.7)), Vector3(0.14, 0.12, 0.18), rng, 0.0, 2, 6)
	for s in [-1.0, 1.0]:
		mb.add_box(mat, Transform3D(Basis(Vector3.UP, s * 0.5), Vector3(s * 0.55, 0, -0.25)), Vector3(0.5, 0.04, 0.16), 0.5)
		mb.add_box(mat, Transform3D(Basis(Vector3.UP, -s * 0.4), Vector3(s * 0.4, 0, 0.45)), Vector3(0.3, 0.04, 0.12), 0.5)
	return mb.commit()
