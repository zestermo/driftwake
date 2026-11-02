class_name SkimmerModel
extends RefCounted
## The skimmer's models (1.28.1, built in code, cached per tier): the board and the rig (mast, wishbone boom, sail),
## in the rider's space: the rider stands at the origin facing -Z, the board runs along X with its nose at -X (the
## rider's left), the rig rises from the mast foot in front of the rider's left foot with the sail ahead of them.
##   Mk I   a pale coral-spar board, a plain red sail with one white panel
##   Mk II  a white board with a red rail stripe and footstraps, brass at the mast foot, a red-white-red striped sail
##   Mk III a longer lacquered board with a gold pinstripe and a fin, a pearl in the mast foot, a taller sail in red,
##          white and gold with battens and a clear window

const MAST_FOOT := Vector3(-0.42, 0.0, -0.05)
## Where the boom meets the mast, and its far end (the clew), in the rig's space (mast foot at the origin).
const BOOM_H := 1.3
const CLEW := Vector3(1.9, 1.22, -0.5)
const BOARD_LEN := [2.3, 2.45, 2.6]
const BOARD_W := [0.62, 0.64, 0.66]
const MAST_H := [3.2, 3.4, 3.7]
const SAIL_BANDS := [[Color(0.78, 0.16, 0.12), Color(0.78, 0.16, 0.12), Color(0.95, 0.93, 0.86), Color(0.78, 0.16, 0.12)],
	[Color(0.82, 0.14, 0.1), Color(0.96, 0.95, 0.9), Color(0.82, 0.14, 0.1), Color(0.96, 0.95, 0.9), Color(0.82, 0.14, 0.1)],
	[Color(0.84, 0.12, 0.08), Color(0.97, 0.96, 0.92), Color(0.9, 0.7, 0.22), Color(0.97, 0.96, 0.92), Color(0.84, 0.12, 0.08), Color(0.97, 0.96, 0.92)]]
const BOARD_COL := [Color(0.9, 0.84, 0.74), Color(0.97, 0.96, 0.92), Color(0.95, 0.93, 0.88)]

static var _meshes: Dictionary = {}


static func board(tier: int) -> ArrayMesh:
	var key := "board:%d" % tier
	if _meshes.has(key):
		return _meshes[key]
	_meshes[key] = _board_mb(tier).commit()
	return _meshes[key]


static func _board_mb(tier: int) -> MeshBuilder:
	var mb := MeshBuilder.new()
	var L: float = BOARD_LEN[tier]
	var W: float = BOARD_W[tier]
	var top := PSXMat.lit("plaster", BOARD_COL[tier])
	var under := PSXMat.flat(BOARD_COL[tier].darkened(0.35))
	var flat_up := Basis(Vector3.RIGHT, PI * 0.5)
	# the deck from above: a pointed nose at -X, a broad squared tail
	var hw := W * 0.5
	var outline := PackedVector2Array([Vector2(-L * 0.5, 0.0), Vector2(-L * 0.5 + 0.35, -hw * 0.55), Vector2(-L * 0.12, -hw),
		Vector2(L * 0.32, -hw * 0.94), Vector2(L * 0.5, -hw * 0.6), Vector2(L * 0.5, hw * 0.6), Vector2(L * 0.32, hw * 0.94),
		Vector2(-L * 0.12, hw), Vector2(-L * 0.5 + 0.35, hw * 0.55)])
	mb.add_extrude(top, Transform3D(flat_up, Vector3(0, -0.05, 0)), outline, 0.1, 1.0, Color.WHITE, under)
	# the nose kicked up a little: a wedge over the front of the deck
	mb.add_extrude(top, Transform3D(flat_up, Vector3(0, 0.005, 0)), PackedVector2Array([Vector2(-L * 0.5, 0.0), Vector2(-L * 0.5 + 0.35, -hw * 0.5),
		Vector2(-L * 0.5 + 0.55, 0.0), Vector2(-L * 0.5 + 0.35, hw * 0.5)]), 0.01, 1.0)
	# rail stripes along both sides (Mk II red, Mk III red with a gold pinstripe)
	if tier >= 1:
		for s in [-1.0, 1.0]:
			var a := Vector3(-L * 0.3, 0.003, s * (hw - 0.05))
			var b := Vector3(L * 0.45, 0.003, s * (hw * 0.62 - 0.03))
			mb.add_tube(PSXMat.flat(GadgetModels.LACQUER), PackedVector3Array([a, Vector3(L * 0.2, 0.003, s * (hw * 0.92 - 0.05)), b]), 0.022, 0.022, 3)
			if tier == 2:
				mb.add_tube(PSXMat.lit("metal", GadgetModels.BRASS), PackedVector3Array([a + Vector3(0, 0.002, -s * 0.05), Vector3(L * 0.2, 0.005, s * (hw * 0.92 - 0.1)), b + Vector3(0, 0.002, -s * 0.05)]), 0.008, 0.008, 3)
		# footstraps: two loops of leather where the feet go
		for x in [-0.15, 0.55]:
			var pts := PackedVector3Array()
			for i in range(7):
				var u := float(i) / 6.0
				pts.append(Vector3(x + (u - 0.5) * 0.06, 0.02 + sin(u * PI) * 0.07, (u - 0.5) * 0.22))
			mb.add_tube(PSXMat.flat(GadgetModels.LEATHER), pts, 0.018, 0.018, 3)
	# the mast foot: a cup on the deck (Mk II brass, Mk III brass round a lagoon pearl)
	var cup: Color = [Color(0.55, 0.42, 0.3), GadgetModels.BRASS, GadgetModels.BRASS][tier]
	mb.add_cylinder(PSXMat.lit("metal", cup), Transform3D(Basis(), MAST_FOOT), 0.07, 0.05, 0.05, 8, 4.0)
	if tier == 2:
		mb.add_blob(PSXMat.glow(Color(1.0, 0.9, 0.92), 0.5), Transform3D(Basis(), MAST_FOOT + Vector3(0.09, 0.03, 0)), Vector3(0.035, 0.035, 0.035), RandomNumberGenerator.new(), 0.0, 4, 6, 4.0)
		# a skeg fin under the tail
		mb.add_extrude(PSXMat.flat(GadgetModels.LACQUER), Transform3D(Basis(), Vector3(L * 0.38, -0.1, 0)), PackedVector2Array([Vector2(-0.12, 0.0), Vector2(0.1, 0.0), Vector2(0.06, -0.24)]), 0.025, 1.0)
	else:
		mb.add_extrude(PSXMat.flat(BOARD_COL[tier].darkened(0.4)), Transform3D(Basis(), Vector3(L * 0.38, -0.1, 0)), PackedVector2Array([Vector2(-0.1, 0.0), Vector2(0.08, 0.0), Vector2(0.04, -0.18)]), 0.025, 1.0)
	return mb


## The rig, its origin at the mast foot (so it rakes about it). The mast leans back toward the tail and out over the
## sail's side; the wishbone boom runs either side of the sail at chest height to the clew.
static func rig(tier: int) -> ArrayMesh:
	var key := "rig:%d" % tier
	if _meshes.has(key):
		return _meshes[key]
	var mb := MeshBuilder.new()
	var H: float = MAST_H[tier]
	var top := Vector3(0.45, H, -0.25)
	var foot := Vector3(0.0, 0.05, 0.0)
	var mast_col: Color = [Color(0.85, 0.82, 0.74), Color(0.9, 0.88, 0.82), Color(0.2, 0.18, 0.18)][tier]
	mb.add_tube(PSXMat.lit("planks", mast_col), PackedVector3Array([foot, top]), 0.035, 0.022, 5)
	var at_boom := foot.lerp(top, BOOM_H / H)
	var luff0 := foot.lerp(top, 0.12)
	var clew := CLEW + Vector3(0.18 * tier, 0.0, 0.0)
	var roach := top.lerp(clew, 0.45) + Vector3(0.35 + 0.1 * tier, 0.0, -0.08)
	var bands: Array = SAIL_BANDS[tier]
	var n := bands.size()
	for i in range(n):
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var l0 := luff0.lerp(top, u0)
		var l1 := luff0.lerp(top, u1)
		var e0 := _leech(clew, roach, top, u0)
		var e1 := _leech(clew, roach, top, u1)
		var m := PSXMat.lit("canvas", bands[i])
		if tier == 2 and i == 1:
			# the window: a clear panel near the boom, framed by the band's cloth
			var w0 := l0.lerp(e0, 0.25)
			var w1 := l1.lerp(e1, 0.25)
			var w2 := l1.lerp(e1, 0.6)
			var w3 := l0.lerp(e0, 0.6)
			_sail_quad(mb, m, l0, l1, w1, w0)
			_sail_quad(mb, m, w3, w2, e1, e0)
			_sail_quad(mb, PSXMat.glow(Color(0.6, 0.85, 0.95, 1.0), 0.15), w0, w1, w2, w3)
		else:
			_sail_quad(mb, m, l0, l1, e1, e0)
		if tier == 2 and i > 0:
			mb.add_tube(PSXMat.flat(Color(0.15, 0.12, 0.12)), PackedVector3Array([l0, e0]), 0.008, 0.008, 3)
	# the foot of the sail along to the clew, and the luff sleeve round the mast
	mb.add_tube(PSXMat.lit("canvas", bands[0].darkened(0.2)), PackedVector3Array([luff0, top]), 0.045, 0.03, 5)
	# the wishbone boom: two arms either side of the sail, bowed out, meeting at the mast and the clew
	var boom_col: Color = [Color(0.6, 0.48, 0.34), Color(0.45, 0.33, 0.22), Color(0.12, 0.1, 0.1)][tier]
	var boom_m := PSXMat.lit("planks", boom_col)
	for s in [-1.0, 1.0]:
		var mid := at_boom.lerp(clew, 0.4) + Vector3(0, 0.02, s * 0.2)
		mb.add_tube(boom_m, MeshBuilder.curve_points(at_boom, mid, clew, 7), 0.022, 0.018, 5)
	if tier >= 1:
		mb.add_cylinder(PSXMat.lit("metal", GadgetModels.BRASS), Transform3D(Basis(), at_boom + Vector3(0, -0.05, 0)), 0.05, 0.05, 0.1, 6, 4.0)
	# the uphaul line hanging from the boom to the mast foot
	mb.add_tube(PSXMat.lit("rope"), MeshBuilder.sag_points(at_boom.lerp(clew, 0.08), foot + Vector3(0.05, 0.06, 0), 0.15, 5), 0.008, 0.008, 3)
	_meshes[key] = mb.commit()
	return _meshes[key]


static func _leech(clew: Vector3, roach: Vector3, top: Vector3, u: float) -> Vector3:
	return clew.lerp(roach, u * 2.0) if u < 0.5 else roach.lerp(top, (u - 0.5) * 2.0)


## A sail panel seen from both sides.
static func _sail_quad(mb: MeshBuilder, m: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(d - a).normalized()
	mb.add_quad(m, a, b, c, d, Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Color.WHITE, n)
	mb.add_quad(m, a, d, c, b, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Color(0.82, 0.82, 0.82), -n)


## The whole skimmer as one node: the board, and the rig on its mast foot ("Rig", raked by the ride).
static func make(tier: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Skimmer"
	var b := MeshInstance3D.new()
	b.name = "Board"
	b.mesh = board(tier)
	b.visibility_range_end = 120.0
	root.add_child(b)
	var r := MeshInstance3D.new()
	r.name = "Rig"
	r.mesh = rig(tier)
	r.position = MAST_FOOT
	r.visibility_range_end = 160.0
	root.add_child(r)
	return root


## The skimmer packed (its icon and the bench's picture): the board with the mast laid along it and the sail rolled.
static func folded(tier: int) -> ArrayMesh:
	var key := "folded:%d" % tier
	if _meshes.has(key):
		return _meshes[key]
	var mb := _board_mb(tier)
	var L: float = BOARD_LEN[tier]
	mb.add_tube(PSXMat.lit("planks", Color(0.85, 0.82, 0.74)), PackedVector3Array([Vector3(-L * 0.45, 0.06, 0.08), Vector3(L * 0.45, 0.06, 0.08)]), 0.03, 0.03, 5)
	mb.add_tube(PSXMat.lit("canvas", SAIL_BANDS[tier][0]), PackedVector3Array([Vector3(-L * 0.4, 0.1, -0.06), Vector3(L * 0.4, 0.1, -0.06)]), 0.08, 0.06, 6)
	for x in [-0.4, 0.1, 0.6]:
		mb.add_cylinder(PSXMat.lit("canvas", SAIL_BANDS[tier][1]), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x * L * 0.5 + 0.05, 0.1, -0.06)), 0.085, 0.085, 0.1, 6, 4.0, Color.WHITE, false, false)
	_meshes[key] = mb.commit()
	return _meshes[key]
