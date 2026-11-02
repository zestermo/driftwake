class_name Figureheads
extends RefCounted
## The crew's figureheads (1.29, ShipKit.FIGURES; the kit's "figure" index): carved and painted, sculpted from lofts,
## lathes, tubes and blobs so each reads at a distance. Model-local: the stem at the origin, the figure looking out
## along -Z, up +Y, about a unit tall; Ship hangs it under the bowsprit at x2.5, tilted along the stem. The first
## four keep their old ids (mermaid, lion, sea serpent, eagle), rebuilt; then a ram (the Merry's nod), a dragon, a
## shark, a kraken curling round the bow, a crowned skull, and a robed maiden holding out a lantern (it glows).

const NAMES := ["None", "Mermaid", "Lion", "Sea serpent", "Eagle", "Ram", "Dragon", "Shark", "Kraken", "Crowned skull", "Maiden with a lantern"]


static func mats() -> Dictionary:
	return {
		"wood": PSXMat.lit("bark", Color(1.6, 1.4, 1.2)),
		"gilt": PSXMat.lit("metal", Color(1.25, 0.95, 0.4)),
		"dark": PSXMat.lit("bark", Color(0.45, 0.36, 0.3)),
		"flesh": PSXMat.lit("", Color(0.95, 0.76, 0.6)),
		"white": PSXMat.lit("", Color(0.94, 0.92, 0.86)),
		"black": PSXMat.lit("", Color(0.1, 0.09, 0.09)),
		"red": PSXMat.lit("", Color(0.7, 0.14, 0.1)),
		"teal": PSXMat.lit("scales", Color(0.45, 0.85, 0.8)),
		"green": PSXMat.lit("scales", Color(0.4, 0.7, 0.35)),
		"grey": PSXMat.lit("", Color(0.55, 0.6, 0.68)),
		"wool": PSXMat.lit("fur_white", Color(1.0, 0.97, 0.9)),
		"mane": PSXMat.lit("fur", Color(1.2, 0.85, 0.45)),
		"purple": PSXMat.lit("", Color(0.55, 0.3, 0.55)),
		"robe": PSXMat.lit("fabric", Color(0.35, 0.45, 0.8)),
		"glow": PSXMat.glow(Color(1.0, 0.78, 0.35), 3.0),
	}


## The figurehead of `kind` (0: none).
static func build(kind: int) -> MeshInstance3D:
	if kind <= 0:
		return null
	var mb := MeshBuilder.new()
	var m := mats()
	match kind:
		1: _mermaid(mb, m)
		2: _lion(mb, m)
		3: _serpent(mb, m)
		4: _eagle(mb, m)
		5: _ram(mb, m)
		6: _dragon(mb, m)
		7: _shark(mb, m)
		8: _kraken(mb, m)
		9: _skull(mb, m)
		10: _maiden(mb, m)
	# the block it's carved from, let into the stem
	mb.add_box(m["dark"], Transform3D(Basis(), Vector3(0, -0.12, 0.1)), Vector3(0.18, 0.32, 0.16), 1.0, Color.WHITE, false)
	mb.fold_tints()
	var mi := mb.to_instance("FigureMesh")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 220.0
	return mi


static func _ball(mb: MeshBuilder, mat: Material, at: Vector3, r: Vector3, col := Color.WHITE) -> void:
	mb.add_blob(mat, Transform3D(Basis(), at), r, RandomNumberGenerator.new(), 0.0, 5, 8, 1.0, col)


## A lathe along `xf`'s +Y through [y, r] rings.
static func _lathe(mb: MeshBuilder, mat: Material, xf: Transform3D, rings: Array, col := Color.WHITE) -> void:
	var rr: Array = []
	for r in rings:
		rr.append([float(r[0]), float(r[1]), float(r[1])])
	mb.add_loft(mat, xf, rr, MeshBuilder.profile_circle(8), 1.0, col, true, true)


static func _tube(mb: MeshBuilder, mat: Material, a: Vector3, ctrl: Vector3, b: Vector3, r0: float, r1: float, n := 8, col := Color.WHITE) -> void:
	mb.add_tube(mat, MeshBuilder.curve_points(a, ctrl, b, n), r0, r1, 6, 1.0, col, true, true)


static func _eyes(mb: MeshBuilder, m: Dictionary, at: Vector3, spread: float, r: float) -> void:
	for sx in [-1.0, 1.0]:
		_ball(mb, m["black"], at + Vector3(sx * spread, 0, 0), Vector3(r, r, r * 0.6))


static func _mermaid(mb: MeshBuilder, m: Dictionary) -> void:
	# leaning out from the stem, arms swept back, hair streaming, the tail curling down and back under her
	var body := Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, 0.25, -0.15))
	mb.add_loft(m["flesh"], body, [[0.0, 0.11, 0.08], [0.18, 0.12, 0.09], [0.32, 0.15, 0.1], [0.46, 0.17, 0.11], [0.56, 0.09, 0.07]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, true, true)
	var neck := body * Vector3(0, 0.6, 0)
	var head := neck + Vector3(0, 0.1, -0.06)
	_ball(mb, m["flesh"], head, Vector3(0.1, 0.12, 0.11))
	_eyes(mb, m, head + Vector3(0, 0.02, -0.1), 0.04, 0.015)
	# hair: gilt locks back over the shoulders
	for k in range(5):
		var x := -0.08 + k * 0.04
		_tube(mb, m["gilt"], head + Vector3(x, 0.08, 0.02), head + Vector3(x * 1.6, 0.05, 0.25), head + Vector3(x * 2.2, -0.25, 0.32), 0.035, 0.012)
	for sx in [-1.0, 1.0]:
		var sh := body * Vector3(sx * 0.15, 0.48, 0)
		_tube(mb, m["flesh"], sh, sh + Vector3(sx * 0.12, -0.05, 0.12), sh + Vector3(sx * 0.1, -0.2, 0.28), 0.035, 0.025, 6)
		_ball(mb, m["gilt"], body * Vector3(sx * 0.07, 0.38, -0.08), Vector3(0.055, 0.05, 0.035))
	# the tail: scales from the hips curling down under her and up the stem to a fluke
	var hip := body * Vector3(0, 0.0, 0)
	var pts := MeshBuilder.curve_points(hip, hip + Vector3(0, -0.45, -0.1), hip + Vector3(0, -0.45, 0.3), 9)
	mb.add_tube(m["teal"], pts, 0.11, 0.04, 8, 2.0, Color.WHITE, false, true)
	var tip: Vector3 = pts[pts.size() - 1]
	var fl := PackedVector2Array([Vector2(0, 0), Vector2(0.22, 0.14), Vector2(0.12, 0.02), Vector2(0.2, -0.12)])
	for sx in [-1.0, 1.0]:
		var o := PackedVector2Array()
		for p in fl:
			o.append(Vector2(p.x * sx, p.y))
		mb.add_extrude(m["teal"], Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), tip + Vector3(0, 0.02, 0.02)), o, 0.03, 2.0, Color(0.85, 1.0, 1.0))


static func _lion(mb: MeshBuilder, m: Dictionary) -> void:
	# a lion's head out of a mane of carved locks, jaws parted
	var h := Vector3(0, 0.45, -0.3)
	for k in range(14):
		var a := TAU * k / 14.0
		var root := h + Vector3(cos(a) * 0.12, sin(a) * 0.14, 0.12)
		_tube(mb, m["mane"], root, root + Vector3(cos(a) * 0.2, sin(a) * 0.2, 0.06), root + Vector3(cos(a) * 0.32, sin(a) * 0.3 - 0.06, 0.18), 0.09, 0.02, 5)
	_ball(mb, m["gilt"], h, Vector3(0.22, 0.24, 0.24))
	_ball(mb, m["gilt"], h + Vector3(0, -0.07, -0.2), Vector3(0.13, 0.1, 0.12))
	_ball(mb, m["dark"], h + Vector3(0, -0.02, -0.31), Vector3(0.05, 0.035, 0.03))
	_ball(mb, m["red"], h + Vector3(0, -0.16, -0.22), Vector3(0.08, 0.04, 0.06))
	for sx in [-1.0, 1.0]:
		_ball(mb, m["gilt"], h + Vector3(sx * 0.18, 0.19, 0.0), Vector3(0.06, 0.07, 0.04))
		_ball(mb, m["gilt"], h + Vector3(sx * 0.08, 0.09, -0.2), Vector3(0.06, 0.03, 0.04))
	_eyes(mb, m, h + Vector3(0, 0.05, -0.21), 0.08, 0.022)
	# a neck down into the stem
	_lathe(mb, m["mane"], Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(0, -0.05, 0.05)), [[0.0, 0.14], [0.3, 0.2], [0.5, 0.22]])


static func _serpent(mb: MeshBuilder, m: Dictionary) -> void:
	# a sea serpent rearing from the stem in an S, jaws wide, a fin down its back
	var a := Vector3(0, -0.2, 0.0)
	var b := Vector3(0, 0.3, -0.25)
	var c := Vector3(0, 0.7, -0.35)
	var body := MeshBuilder.curve_points(a, Vector3(0, 0.15, 0.25), b, 6)
	var neck := MeshBuilder.curve_points(b, Vector3(0, 0.5, -0.6), c, 6)
	var pts := PackedVector3Array(body)
	pts.append_array(neck.slice(1))
	mb.add_tube(m["green"], pts, 0.14, 0.09, 8, 2.0, Color.WHITE, true, false)
	# the head: an upper jaw and a lower one hinged open
	var hd := Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.25), c)
	mb.add_loft(m["green"], hd, [[0.0, 0.1, 0.09], [0.12, 0.11, 0.08], [0.3, 0.07, 0.05], [0.36, 0.03, 0.03]], MeshBuilder.profile_circle(8), 2.0, Color.WHITE, false, true)
	var jaw := Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.75), c + Vector3(0, -0.05, 0))
	mb.add_loft(m["green"], jaw, [[0.0, 0.08, 0.04], [0.26, 0.05, 0.03], [0.3, 0.02, 0.02]], MeshBuilder.profile_circle(6), 2.0, Color(0.85, 0.95, 0.8), false, true)
	_ball(mb, m["red"], c + Vector3(0, -0.06, -0.14), Vector3(0.06, 0.03, 0.12))
	for k in range(4):
		var t := hd * Vector3(0, 0.06 + k * 0.07, -0.0)
		for sx in [-1.0, 1.0]:
			mb.add_cone(m["white"], Transform3D(Basis(Vector3.RIGHT, PI), t + Vector3(sx * 0.06, -0.06, 0)), 0.015, 0.05, 5)
	_eyes(mb, m, c + Vector3(0, 0.08, -0.08), 0.08, 0.02)
	for sx in [-1.0, 1.0]:
		_tube(mb, m["gilt"], c + Vector3(sx * 0.06, 0.08, 0.05), c + Vector3(sx * 0.12, 0.2, 0.15), c + Vector3(sx * 0.1, 0.18, 0.3), 0.025, 0.008, 5)
	# the fin: gilt spines along its back
	for i in range(1, pts.size() - 1, 2):
		var p: Vector3 = pts[i]
		mb.add_cone(m["gilt"], Transform3D(Basis(Vector3.RIGHT, -0.6), p + Vector3(0, 0.06, 0.1)), 0.04, 0.16, 4)


static func _eagle(mb: MeshBuilder, m: Dictionary) -> void:
	# an eagle breasting out, wings swept back along the bow, a hooked beak
	var body := Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.1, -0.1))
	mb.add_loft(m["wood"], body, [[0.0, 0.12, 0.12], [0.2, 0.17, 0.17], [0.4, 0.15, 0.15], [0.55, 0.09, 0.09]], MeshBuilder.profile_circle(8), 2.0, Color(0.6, 0.45, 0.35), true, false)
	var head := body * Vector3(0, 0.62, -0.05)
	_ball(mb, m["white"], head, Vector3(0.1, 0.1, 0.12))
	_tube(mb, m["gilt"], head + Vector3(0, 0.0, -0.1), head + Vector3(0, 0.0, -0.22), head + Vector3(0, -0.09, -0.24), 0.04, 0.008, 5)
	_eyes(mb, m, head + Vector3(0, 0.03, -0.08), 0.06, 0.016)
	var wing := PackedVector2Array([Vector2(0, 0), Vector2(0.15, 0.1), Vector2(0.5, 0.18), Vector2(0.8, 0.12), Vector2(0.7, 0.05),
		Vector2(0.78, -0.02), Vector2(0.62, -0.06), Vector2(0.68, -0.13), Vector2(0.45, -0.12), Vector2(0.2, -0.1)])
	for sx in [-1.0, 1.0]:
		var o := PackedVector2Array()
		for p in wing:
			o.append(Vector2(p.x, p.y))
		var b := Basis(Vector3.UP, -sx * PI * 0.5 + sx * 0.35) * Basis(Vector3.FORWARD, 0.25)
		mb.add_extrude(m["gilt"], Transform3D(b, body * Vector3(sx * 0.13, 0.35, 0.02)), o, 0.04, 2.0)
	for sx in [-1.0, 1.0]:
		_tube(mb, m["gilt"], body * Vector3(sx * 0.06, 0.02, -0.08), body * Vector3(sx * 0.08, -0.1, -0.16), body * Vector3(sx * 0.07, -0.15, -0.24), 0.025, 0.008, 5)


static func _ram(mb: MeshBuilder, m: Dictionary) -> void:
	# a sheep's head (the Merry's nod): a woolly crown, a long pale face, horns curled round either side
	var h := Vector3(0, 0.42, -0.25)
	_ball(mb, m["wool"], h + Vector3(0, 0.06, 0.04), Vector3(0.22, 0.2, 0.22))
	_lathe(mb, m["white"], Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.35), h), [[0.0, 0.13], [0.18, 0.12], [0.3, 0.09], [0.34, 0.05]])
	_ball(mb, m["black"], h + Vector3(0, -0.13, -0.32), Vector3(0.05, 0.03, 0.025))
	_eyes(mb, m, h + Vector3(0, 0.02, -0.13), 0.1, 0.025)
	for sx in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for i in range(14):
			var t := float(i) / 13.0
			var a := t * TAU * 1.05
			var r := 0.17 - t * 0.09
			pts.append(h + Vector3(sx * (0.17 + t * 0.06), 0.05 + sin(a) * r, cos(a) * r - 0.02))
		mb.add_tube(m["gilt"], pts, 0.07, 0.025, 7, 2.0, Color.WHITE, true, true)
		_ball(mb, m["white"], h + Vector3(sx * 0.2, -0.04, 0.02), Vector3(0.03, 0.08, 0.05))
	_lathe(mb, m["wool"], Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, -0.05, 0.05)), [[0.0, 0.14], [0.3, 0.19], [0.48, 0.2]])


static func _dragon(mb: MeshBuilder, m: Dictionary) -> void:
	# a dragon on a long neck: a snouted head, jaws apart, swept horns, a crest of spines
	var a := Vector3(0, -0.15, 0.05)
	var c := Vector3(0, 0.75, -0.3)
	var pts := MeshBuilder.curve_points(a, Vector3(0, 0.35, 0.15), c, 9)
	mb.add_tube(m["red"], pts, 0.13, 0.08, 8, 2.0, Color(0.9, 0.9, 0.9), true, false)
	var hd := Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.1), c)
	mb.add_loft(m["red"], hd, [[0.0, 0.11, 0.1], [0.14, 0.1, 0.08], [0.3, 0.07, 0.05], [0.4, 0.05, 0.04]], MeshBuilder.profile_oct(), 2.0, Color.WHITE, false, true)
	var jaw := Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.55), c + Vector3(0, -0.06, 0))
	mb.add_loft(m["red"], jaw, [[0.0, 0.08, 0.04], [0.32, 0.05, 0.03]], MeshBuilder.profile_oct(), 2.0, Color(0.7, 0.7, 0.7), false, true)
	for k in range(5):
		var t := hd * Vector3(0, 0.08 + k * 0.065, 0)
		for sx in [-1.0, 1.0]:
			mb.add_cone(m["white"], Transform3D(Basis(Vector3.RIGHT, PI), t + Vector3(sx * 0.05, -0.05, 0)), 0.012, 0.045, 4)
	_ball(mb, m["gilt"], c + Vector3(0, 0.07, -0.08), Vector3(0.11, 0.04, 0.06))
	_eyes(mb, m, c + Vector3(0, 0.07, -0.05), 0.08, 0.022)
	for sx in [-1.0, 1.0]:
		_tube(mb, m["gilt"], c + Vector3(sx * 0.07, 0.08, 0.06), c + Vector3(sx * 0.16, 0.2, 0.2), c + Vector3(sx * 0.14, 0.32, 0.38), 0.04, 0.008, 5)
		_ball(mb, m["black"], hd * Vector3(sx * 0.03, 0.4, -0.03), Vector3(0.015, 0.015, 0.015))
	for i in range(1, pts.size() - 1):
		var p: Vector3 = pts[i]
		mb.add_cone(m["gilt"], Transform3D(Basis(Vector3.RIGHT, -0.7), p + Vector3(0, 0.05, 0.1)), 0.035, 0.12, 4)


static func _shark(mb: MeshBuilder, m: Dictionary) -> void:
	# a shark lunging out of the stem, jaws open on rows of teeth, a dorsal fin, a pale belly
	var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.35), Vector3(0, 0.2, 0.05))
	mb.add_loft(m["grey"], xf, [[0.0, 0.1, 0.12], [0.25, 0.17, 0.2], [0.5, 0.17, 0.19], [0.7, 0.13, 0.13], [0.8, 0.07, 0.08]], MeshBuilder.profile_circle(8), 2.0, Color.WHITE, true, false)
	var snout := xf * Vector3(0, 0.8, 0)
	var top := xf.basis * Vector3(0, 0, -1)
	var fwd := xf.basis * Vector3(0, 1, 0)
	_ball(mb, m["grey"], snout + fwd * 0.04 + top * 0.03, Vector3(0.08, 0.06, 0.1))
	_ball(mb, m["white"], xf * Vector3(0, 0.45, 0.13), Vector3(0.13, 0.25, 0.08))
	_ball(mb, m["red"], xf * Vector3(0, 0.66, 0.08), Vector3(0.09, 0.07, 0.06))
	for k in range(7):
		var a := PI * (k + 0.5) / 7.0 - PI * 0.5
		var p := xf * Vector3(sin(a) * 0.1, 0.7, 0.05 + cos(a) * 0.04)
		mb.add_cone(m["white"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p), 0.014, 0.04, 4)
	_eyes(mb, m, xf * Vector3(0, 0.62, -0.08), 0.12, 0.018)
	var fin := PackedVector2Array([Vector2(0, 0), Vector2(0.2, 0), Vector2(0.06, 0.24)])
	mb.add_extrude(m["grey"], Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, 0.0), xf * Vector3(0, 0.35, -0.17)), fin, 0.03, 2.0)
	for sx in [-1.0, 1.0]:
		var pf := PackedVector2Array([Vector2(0, 0), Vector2(0.2 * sx, -0.1), Vector2(0.04 * sx, -0.06)])
		if sx < 0:
			pf.reverse()
		mb.add_extrude(m["grey"], Transform3D(Basis(), xf * Vector3(sx * 0.15, 0.48, 0.05)), pf, 0.025, 2.0)


static func _kraken(mb: MeshBuilder, m: Dictionary) -> void:
	# a kraken's head on the stem, its great eyes, arms curling out round the bow on both sides and up under the
	# bowsprit
	var h := Vector3(0, 0.45, -0.12)
	_ball(mb, m["purple"], h + Vector3(0, 0.12, 0.05), Vector3(0.2, 0.3, 0.2))
	_ball(mb, m["purple"], h + Vector3(0, -0.1, -0.06), Vector3(0.18, 0.13, 0.16))
	for sx in [-1.0, 1.0]:
		_ball(mb, m["gilt"], h + Vector3(sx * 0.12, -0.05, -0.12), Vector3(0.06, 0.06, 0.04))
		_ball(mb, m["black"], h + Vector3(sx * 0.12, -0.05, -0.16), Vector3(0.025, 0.04, 0.02))
	for k in range(8):
		var sx := -1.0 if k % 2 == 0 else 1.0
		var j := floorf(k / 2.0)
		var root := h + Vector3(sx * 0.08, -0.2, -0.02 + j * 0.03)
		var ctrl := root + Vector3(sx * (0.35 + j * 0.05), -0.25 + j * 0.12, 0.25 + j * 0.15)
		var tip := root + Vector3(sx * (0.22 + j * 0.06), 0.15 - j * 0.12, 0.65 + j * 0.1)
		var pts := MeshBuilder.curve_points(root, ctrl, tip, 9)
		mb.add_tube(m["purple"], pts, 0.06, 0.012, 6, 2.0, Color.WHITE, false, true)
		for i in range(2, pts.size() - 1, 2):
			_ball(mb, m["gilt"], (pts[i] as Vector3) + Vector3(0, -0.03, 0), Vector3(0.018, 0.018, 0.018))


static func _skull(mb: MeshBuilder, m: Dictionary) -> void:
	# a great skull wearing a crown: the cranium, sockets and nose cut dark, a jaw of square teeth
	var h := Vector3(0, 0.45, -0.25)
	_ball(mb, m["white"], h, Vector3(0.24, 0.24, 0.27))
	mb.add_box(m["white"], Transform3D(Basis(), h + Vector3(0, -0.2, -0.08)), Vector3(0.26, 0.14, 0.24), 2.0, Color.WHITE, false)
	for sx in [-1.0, 1.0]:
		_ball(mb, m["black"], h + Vector3(sx * 0.09, 0.0, -0.22), Vector3(0.065, 0.07, 0.04))
	_ball(mb, m["black"], h + Vector3(0, -0.1, -0.25), Vector3(0.03, 0.04, 0.02))
	for k in range(6):
		mb.add_box(m["white"], Transform3D(Basis(), h + Vector3(-0.1 + k * 0.04, -0.2, -0.205)), Vector3(0.032, 0.06, 0.02), 2.0, Color(0.9, 0.88, 0.8), false)
	# the crown: a band and five points
	var cr := h + Vector3(0, 0.17, 0)
	_lathe(mb, m["gilt"], Transform3D(Basis(), cr), [[0.0, 0.2], [0.08, 0.21]])
	for k in range(5):
		var a := TAU * k / 5.0 + PI * 0.5
		var p := cr + Vector3(cos(a) * 0.19, 0.06, sin(a) * 0.19)
		mb.add_cone(m["gilt"], Transform3D(Basis(), p), 0.05, 0.13, 4)
		_ball(mb, m["red"], p + Vector3(cos(a) * 0.015, -0.02, sin(a) * 0.015), Vector3(0.02, 0.02, 0.02))
	# crossed bones under it
	for sx in [-1.0, 1.0]:
		var a := h + Vector3(-0.3 * sx, -0.42, -0.08)
		var b := h + Vector3(0.3 * sx, -0.22, -0.02)
		mb.add_tube(m["white"], PackedVector3Array([a, b]), 0.035, 0.035, 6, 2.0, Color.WHITE, true, true)
		for e in [a, b]:
			_ball(mb, m["white"], e, Vector3(0.05, 0.05, 0.05))


static func _maiden(mb: MeshBuilder, m: Dictionary) -> void:
	# a robed maiden leaning out, hood back, one arm holding a lantern ahead (its glass glows)
	var xf := Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, -0.15, -0.05))
	mb.add_loft(m["robe"], xf, [[0.0, 0.2, 0.18], [0.25, 0.15, 0.13], [0.45, 0.12, 0.1], [0.62, 0.14, 0.11], [0.72, 0.08, 0.07]], MeshBuilder.profile_circle(8), 2.0, Color.WHITE, true, true)
	var neck := xf * Vector3(0, 0.75, 0)
	var head := neck + Vector3(0, 0.1, -0.05)
	_ball(mb, m["flesh"], head, Vector3(0.09, 0.11, 0.1))
	_eyes(mb, m, head + Vector3(0, 0.02, -0.09), 0.035, 0.012)
	# the hood fallen back, the hair under it
	_ball(mb, m["robe"], head + Vector3(0, 0.0, 0.07), Vector3(0.12, 0.13, 0.1), Color(0.8, 0.8, 0.8))
	_tube(mb, m["gilt"], head + Vector3(0, 0.06, 0.05), head + Vector3(0, -0.05, 0.2), head + Vector3(0, -0.25, 0.22), 0.06, 0.02)
	# the lantern arm out ahead and up, the other hand at her breast
	var sh := xf * Vector3(0.13, 0.62, 0)
	var hand := sh + Vector3(0.05, 0.12, -0.38)
	_tube(mb, m["robe"], sh, sh + Vector3(0.1, -0.02, -0.15), hand, 0.05, 0.03, 6)
	_ball(mb, m["flesh"], hand, Vector3(0.03, 0.03, 0.03))
	var lamp := hand + Vector3(0, -0.12, 0)
	mb.add_tube(m["dark"], PackedVector3Array([hand, lamp + Vector3(0, 0.06, 0)]), 0.006, 0.006, 4, 1.0)
	mb.add_cylinder(m["dark"], Transform3D(Basis(), lamp + Vector3(0, 0.045, 0)), 0.04, 0.02, 0.03, 6, 1.0, Color.WHITE, true, false)
	mb.add_cylinder(m["glow"], Transform3D(Basis(), lamp - Vector3(0, 0.04, 0)), 0.04, 0.04, 0.085, 6, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(m["dark"], Transform3D(Basis(), lamp - Vector3(0, 0.055, 0)), 0.05, 0.05, 0.015, 6, 1.0, Color.WHITE, true, true)
	var sh2 := xf * Vector3(-0.13, 0.62, 0)
	_tube(mb, m["robe"], sh2, sh2 + Vector3(0.0, -0.15, -0.1), xf * Vector3(-0.02, 0.5, -0.12), 0.05, 0.035, 6)
	# a gilt hem and a sash
	_lathe(mb, m["gilt"], xf, [[0.0, 0.205], [0.03, 0.205]])
	_lathe(mb, m["gilt"], Transform3D(xf.basis, xf * Vector3(0, 0.44, 0)), [[0.0, 0.125], [0.04, 0.125]])
