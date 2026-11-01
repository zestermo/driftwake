class_name BookModels
extends RefCounted
## Book models, built in code and cached: a book (the icon; a rolled chart for charts), the cabin's bookshelf frame
## and its rows of spines (one per book read, in each kind's cover colour). The shelf faces +Z, its back on z = 0.

const SHELF_W := 1.3
const SHELF_H := 1.75
const SHELF_D := 0.32
## Shelves' heights (the top of each board) and how many spines fit a row.
const ROWS := [0.08, 0.5, 0.92, 1.34]
const PER_ROW := 14

static var _meshes := {}


## A closed book (spine along +Y, the cover facing +Z) or a rolled sea chart tied with a cord.
static func book(cover: Color, rolled := false) -> ArrayMesh:
	var key := "book:%s:%s" % [cover.to_html(), rolled]
	if _meshes.has(key):
		return _meshes[key]
	var mb := MeshBuilder.new()
	var skin := PSXMat.lit("leather", cover)
	var paper := PSXMat.flat(Color(0.9, 0.85, 0.7))
	var gold := PSXMat.flat(Color(0.85, 0.68, 0.28))
	if rolled:
		mb.add_cylinder(paper, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), 0.07, 0.07, 0.42, 8, 2.0)
		mb.add_cylinder(skin, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), 0.075, 0.075, 0.05, 8, 2.0)
	else:
		mb.add_box(skin, Transform3D(Basis(), Vector3(0, 0, 0.035)), Vector3(0.28, 0.38, 0.012), 2.0, Color.WHITE, false)
		mb.add_box(skin, Transform3D(Basis(), Vector3(0, 0, -0.035)), Vector3(0.28, 0.38, 0.012), 2.0, Color.WHITE, false)
		mb.add_box(skin, Transform3D(Basis(), Vector3(-0.14, 0, 0)), Vector3(0.016, 0.38, 0.082), 2.0, Color.WHITE, false)
		mb.add_box(paper, Transform3D(Basis(), Vector3(0.006, 0, 0)), Vector3(0.26, 0.36, 0.058), 2.0, Color.WHITE, false)
		mb.add_box(gold, Transform3D(Basis(), Vector3(0, 0.06, 0.042)), Vector3(0.16, 0.025, 0.004), 2.0)
		mb.add_box(gold, Transform3D(Basis(), Vector3(0, -0.1, 0.042)), Vector3(0.1, 0.018, 0.004), 2.0)
	_meshes[key] = mb.commit()
	return _meshes[key]


## The empty shelf: sides, a back, four boards and a crown.
static func shelf() -> ArrayMesh:
	if _meshes.has("shelf"):
		return _meshes["shelf"]
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks", Color(0.52, 0.36, 0.24))
	var dark := PSXMat.lit("planks", Color(0.36, 0.25, 0.17))
	for sx in [-1.0, 1.0]:
		mb.add_box(wood, Transform3D(Basis(), Vector3(sx * (SHELF_W * 0.5 - 0.03), SHELF_H * 0.5, SHELF_D * 0.5)), Vector3(0.06, SHELF_H, SHELF_D), 1.0, Color.WHITE, false)
	mb.add_box(dark, Transform3D(Basis(), Vector3(0, SHELF_H * 0.5, 0.015)), Vector3(SHELF_W - 0.06, SHELF_H, 0.03), 1.0)
	for y in ROWS:
		mb.add_box(wood, Transform3D(Basis(), Vector3(0, float(y) - 0.02, SHELF_D * 0.5)), Vector3(SHELF_W - 0.1, 0.04, SHELF_D - 0.02), 1.0, Color.WHITE, false)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, SHELF_H + 0.03, SHELF_D * 0.5 + 0.01)), Vector3(SHELF_W + 0.06, 0.06, SHELF_D + 0.04), 1.0, Color.WHITE, false)
	# a lip on each board so the books don't slide out in a swell
	for y in ROWS:
		mb.add_box(dark, Transform3D(Basis(), Vector3(0, float(y) + 0.03, SHELF_D - 0.01)), Vector3(SHELF_W - 0.1, 0.04, 0.015), 1.0)
	_meshes["shelf"] = mb.commit()
	return _meshes["shelf"]


## The spines on the shelf for `kinds` (one entry per book read, in shelf order): each a little box in its cover
## colour, heights and lean varied by `seed_value`. Not cached (rebuilt when the collection changes).
static func spines(kinds: Array, seed_value: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var skin := PSXMat.flat(Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var slot := (SHELF_W - 0.16) / float(PER_ROW)
	for i in range(mini(kinds.size(), PER_ROW * ROWS.size())):
		var row := i / PER_ROW
		var col := i % PER_ROW
		var h := rng.randf_range(0.26, 0.36)
		var t := rng.randf_range(0.045, 0.07)
		var x := -SHELF_W * 0.5 + 0.08 + (col + 0.5) * slot
		var c: Color = BookData.COVERS[kinds[i]] * rng.randf_range(0.8, 1.15)
		mb.add_box(skin, Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05)), Vector3(x, float(ROWS[row]) + h * 0.5, SHELF_D * 0.5 + 0.02)),
			Vector3(t, h, rng.randf_range(0.2, 0.25)), 2.0, c)
	return mb.commit()
