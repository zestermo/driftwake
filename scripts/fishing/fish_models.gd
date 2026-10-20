class_name FishModels
extends RefCounted
## Models for fishing, built in code and cached: the bobber, and fish (the snout along -Z, the back up +Y,
## centred on the origin, `length` m long) in a few body shapes, tinted by species.

static var _meshes: Dictionary = {}

## shape -> the body's rings along it (tail root 0 -> snout 1): [along, half width, half height]
const SHAPES := {
	"slim": [[0.0, 0.012, 0.035], [0.15, 0.025, 0.065], [0.4, 0.045, 0.1], [0.65, 0.048, 0.105], [0.82, 0.038, 0.08], [0.93, 0.022, 0.05], [1.0, 0.006, 0.016]],
	"deep": [[0.0, 0.014, 0.05], [0.15, 0.03, 0.12], [0.38, 0.055, 0.22], [0.6, 0.058, 0.23], [0.8, 0.045, 0.16], [0.93, 0.025, 0.08], [1.0, 0.008, 0.02]],
	"long": [[0.0, 0.01, 0.025], [0.2, 0.02, 0.045], [0.5, 0.032, 0.06], [0.75, 0.034, 0.06], [0.9, 0.026, 0.045], [1.0, 0.006, 0.012]],
	"flat": [[0.0, 0.015, 0.02], [0.2, 0.12, 0.035], [0.45, 0.2, 0.05], [0.7, 0.19, 0.05], [0.88, 0.12, 0.035], [1.0, 0.02, 0.01]],
}


static func bobber() -> ArrayMesh:
	if _meshes.has("bobber"):
		return _meshes["bobber"]
	var mb := MeshBuilder.new()
	var circle := MeshBuilder.profile_circle(8)
	mb.add_loft(PSXMat.flat(Color(0.95, 0.93, 0.88)), Transform3D.IDENTITY, [[-0.07, 0.004, 0.004], [-0.05, 0.022, 0.022], [-0.015, 0.034, 0.034], [0.0, 0.036, 0.036]], circle, 2.0)
	mb.add_loft(PSXMat.flat(Color(0.85, 0.12, 0.08)), Transform3D.IDENTITY, [[0.0, 0.036, 0.036], [0.02, 0.03, 0.03], [0.04, 0.012, 0.012], [0.045, 0.004, 0.004]], circle, 2.0)
	mb.add_cylinder(PSXMat.flat(Color(0.85, 0.12, 0.08)), Transform3D(Basis(), Vector3(0, 0.04, 0)), 0.003, 0.002, 0.07, 4, 2.0)
	var m := mb.commit()
	_meshes["bobber"] = m
	return m


## A fish of `shape` (SHAPES), `length` m, its back `body`, its fins `fin`.
static func fish(shape: String, length: float, body: Color, fin: Color) -> ArrayMesh:
	var key := "%s:%.2f:%s:%s" % [shape, length, body.to_html(), fin.to_html()]
	if _meshes.has(key):
		return _meshes[key]
	var mb := MeshBuilder.new()
	var skin := PSXMat.lit("scales", body)
	var fins := PSXMat.flat(fin)
	var L := length
	var rings: Array = []
	for r in SHAPES[shape]:
		rings.append([float(r[0]) * L, float(r[1]) * L, float(r[2]) * L])
	var lens := MeshBuilder.profile_mirror(PackedVector2Array([Vector2(0, -1), Vector2(0.7, -0.7), Vector2(1, 0), Vector2(0.7, 0.75), Vector2(0, 1)]))
	# along +Y turned to -Z (the snout forward), the profile's z up
	mb.add_loft(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, L * 0.5)), rings, lens, 6.0, Color.WHITE, true, true)
	# the fins stand in the fish's own plane (outline x along the fish +Z, y up; extruded across, X)
	var side := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	var h0: float = float(SHAPES[shape][0][2]) * L
	var hm: float = float(SHAPES[shape][3][2]) * L
	var tail := PackedVector2Array([Vector2(0.48 * L, h0), Vector2(0.72 * L, hm * 1.3), Vector2(0.64 * L, 0.0), Vector2(0.72 * L, -hm * 1.3), Vector2(0.48 * L, -h0)])
	var dorsal := PackedVector2Array([Vector2(-0.12 * L, hm * 0.92), Vector2(0.02 * L, hm * 1.55), Vector2(0.24 * L, hm * 0.85)])
	var belly := PackedVector2Array([Vector2(0.05 * L, -hm * 0.9), Vector2(0.2 * L, -hm * 1.3), Vector2(0.24 * L, -hm * 0.8)])
	for o in [tail, dorsal, belly]:
		mb.add_extrude(fins, Transform3D(side, Vector3.ZERO), o, 0.006, 4.0)
	# eyes
	var ey: float = float(SHAPES[shape][5][2]) * L * 0.35
	var ex: float = float(SHAPES[shape][5][1]) * L
	for s in [-1.0, 1.0]:
		mb.add_box(PSXMat.flat(Color(0.05, 0.05, 0.06)), Transform3D(Basis(), Vector3(s * ex, ey, -0.38 * L)), Vector3(0.012, 0.014, 0.014), 4.0, Color.WHITE, false)
	var m := mb.commit()
	_meshes[key] = m
	return m
