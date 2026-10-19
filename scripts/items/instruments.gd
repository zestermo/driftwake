class_name Instruments
extends RefCounted
## The captains' instruments: items (gear for the equipment slot, one carried at a time; the look key
## "instrument" names the kind, so crewmates' screens know it too), their models (built in code, held
## and played by Jam) and their icons. Nobody starts with one: Corin's music shop on Brinehollow's market street sells all five, a chain
## island's trader sometimes has one (trader_stock). The tunes they play are gen_psx_music.py's JAM_TUNES.

## kind -> [item id, name, price at a shop, worth, description]
const ITEMS := {
	"concertina": ["concertina", "Concertina", 110, 45, "Six-sided, bellows of red leather, buttons worn smooth. Squeezes out a tune and the chords under it."],
	"fiddle": ["fiddle", "Fiddle", 140, 55, "A fiddle and its bow, the varnish rubbed thin under the chin. Every tavern has room for one."],
	"whistle": ["tin_whistle", "Tin Whistle", 35, 14, "A brass whistle with six holes. It fits in the belt and carries over a gale."],
	"bodhran": ["bodhran", "Bodhran", 60, 24, "A goatskin frame drum and its tipper. Keeps the crew in time at the capstan."],
	"gurdy": ["hurdy_gurdy", "Hurdy-Gurdy", 175, 70, "A wheel, a crank, a box of keys and strings that drone like a hive. Nobody sleeps through it."],
}
const KINDS := ["concertina", "fiddle", "whistle", "bodhran", "gurdy"]
## [id, title, beats in a bar, bars, sub-beats (strokes a beat)]: the stems res://assets/audio/jam/<id>_<kind>.ogg.
const TUNES := [["lass", "The Brinehollow Lass", 2, 32, 3], ["haul", "Haul Away the Morrow", 4, 16, 2],
	["bell", "The Drowned Bell", 3, 32, 2], ["rum", "Rum and Rigging", 2, 32, 2]]
## A chain island's trader carries an instrument this often (seeded per island).
const TRADER_CHANCE := 0.45

static var _meshes: Dictionary = {}


static func kind_of(it: ItemData) -> String:
	return str(it.look.get("instrument", "")) if it and it.gear_slot == "equipment" else ""


static func item_id(kind: String) -> String:
	return str(ITEMS[kind][0])


## (ItemDB._load_all) the five instruments into the item table.
static func make_items(items: Dictionary) -> void:
	for kind in KINDS:
		var e: Array = ITEMS[kind]
		var it := ItemData.new()
		it.id = str(e[0])
		it.display_name = str(e[1])
		it.value = int(e[3])
		it.description = str(e[4])
		it.item_type = ItemData.ItemType.GEAR
		it.gear_slot = "equipment"
		it.look = {"instrument": kind}
		it.icon_kind = kind
		it.stackable = false
		it.max_stack = 1
		it.icon = icon(kind)
		items[it.id] = it


static func price(kind: String) -> int:
	return int(ITEMS[kind][2])


## A shop's stock entry for each kind given ([item id, price]).
static func stock(kinds: Array) -> Array:
	var out: Array = []
	for k in kinds:
		out.append([item_id(k), price(k)])
	return out


## A chain island's trader: one instrument now and then, a little dearer than at home (seeded by the shop's id,
## apart from the island's own rng so nothing else on the island changes).
static func trader_stock(shop_key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(shop_key + ":instrument")
	if rng.randf() >= TRADER_CHANCE:
		return []
	var k: String = KINDS[rng.randi() % KINDS.size()]
	return [[item_id(k), int(round(price(k) * 1.15))]]


static func tune_path(tune: int, kind: String) -> String:
	return "res://assets/audio/jam/%s_%s.ogg" % [TUNES[tune][0], kind]


# --------------------------------------------------------------------------
# Models (metres, built by MeshBuilder; Jam places them)
#   concertina: ends along X (button faces out), bellows of length 1 along +X ("bellows"), "end"
#   fiddle: tail at the origin, scroll along -Z, top +Y; "bow": frog at the origin, stick along -Z
#   whistle: mouthpiece at the origin, foot along -Z, holes up (+Y)
#   bodhran: centred, the skin facing +Z; "tipper": its middle at the origin, along Z
#   gurdy: the body centred, length along X (crank +X), keybox up, keys out on -Z; "crank": axle along +X
# --------------------------------------------------------------------------
## The instrument whole (the icon; carried on the back), or one of its moving parts.
static func mesh(kind: String, part: String = "") -> ArrayMesh:
	var key := kind + ":" + part
	if _meshes.has(key):
		return _meshes[key]
	var mb := MeshBuilder.new()
	var o := Transform3D.IDENTITY
	match key:
		"concertina:":
			_concertina_end(mb, Transform3D(Basis(), Vector3(0.072, 0, 0)))
			_concertina_end(mb, Transform3D(Basis(Vector3.UP, PI), Vector3(-0.072, 0, 0)))
			_bellows(mb, Transform3D(Basis().scaled(Vector3(0.104, 1, 1)), Vector3(-0.052, 0, 0)))
		"concertina:end":
			_concertina_end(mb, o)
		"concertina:bellows":
			_bellows(mb, o)
		"fiddle:":
			_fiddle(mb, o)
		"fiddle:bow":
			_bow(mb, o)
		"whistle:":
			_whistle(mb, o)
		"bodhran:":
			_bodhran(mb, o)
		"bodhran:icon":
			_bodhran(mb, o)
			_tipper(mb, Transform3D(Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.UP, PI * 0.5), Vector3(0.05, 0.02, 0.1)))
		"bodhran:tipper":
			_tipper(mb, o)
		"gurdy:":
			_gurdy(mb, o)
			_crank(mb, Transform3D(Basis(), CRANK_AT))
		"gurdy:body":
			_gurdy(mb, o)
		"gurdy:crank":
			_crank(mb, o)
		_:
			push_error("Instruments.mesh: no model \"%s\"" % key)
	var m := mb.commit()
	m.set_meta("model", "instrument:" + kind)
	_meshes[key] = m
	return m


## Where each icon is seen from (see WeaponDesigns.mesh_icon) and turned.
const ICON_VIEW := {
	"concertina": [Vector3(0.35, PI * 0.5, 0.0), 0.0],
	"fiddle": [Vector3(0, 0, -PI * 0.5), -PI * 0.25],
	"whistle": [Vector3(0, 0, 0), -PI * 0.25],
	"bodhran": [Vector3(0, PI * 0.5, 0), 0.0],
	"gurdy": [Vector3(0, 0, -PI * 0.5), PI * 0.2],
}
static var _icons: Dictionary = {}


static func icon(kind: String) -> Texture2D:
	if not _icons.has(kind):
		var v: Array = ICON_VIEW[kind]
		_icons[kind] = WeaponDesigns.mesh_icon(mesh(kind, "icon" if kind == "bodhran" else ""), Basis.from_euler(v[0]), float(v[1]))
	return _icons[kind]


static func _wood(tint: Color) -> Material:
	return PSXMat.lit("planks", tint)


## A box from a to b (in `xf`'s frame): w across, t thick.
static func _bar(mb: MeshBuilder, mat: Material, xf: Transform3D, a: Vector3, b: Vector3, w: float, t: float, col := Color.WHITE) -> void:
	var d := b - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	var bas := Basis.looking_at(d.normalized(), up)
	mb.add_box(mat, Transform3D(xf.basis * bas, xf * ((a + b) * 0.5)), Vector3(w, t, d.length()), 2.0, col, false)


## +Y along +X / -Z / +Z (for cylinders and lofts).
const ALONG_X := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
const ALONG_NZ := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
const ALONG_Z := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))


# ---- concertina ----
const END_R := 0.085
const END_W := 0.044


## One end, centred, its button face at +X (the hand's side), the bellows side at -X.
static func _concertina_end(mb: MeshBuilder, xf: Transform3D) -> void:
	var wood := _wood(Color(0.62, 0.36, 0.2))
	var fret := PSXMat.flat(Color(0.12, 0.08, 0.06))
	var bone := PSXMat.flat(Color(0.9, 0.86, 0.74))
	var brass := PSXMat.flat(Color(0.85, 0.66, 0.28))
	var strap := PSXMat.lit("leather", Color(0.36, 0.22, 0.14))
	var h := END_W * 0.5
	mb.add_cylinder(wood, Transform3D(xf.basis * ALONG_X, xf * Vector3(-h, 0, 0)), END_R, END_R, END_W, 6, 2.0, Color.WHITE, true, true, false)
	mb.add_cylinder(brass, Transform3D(xf.basis * ALONG_X, xf * Vector3(-h - 0.004, 0, 0)), END_R * 0.97, END_R * 0.97, 0.004, 6, 2.0, Color.WHITE, false, false, false)
	mb.add_cylinder(fret, Transform3D(xf.basis * ALONG_X, xf * Vector3(h, 0, 0)), END_R * 0.8, END_R * 0.8, 0.003, 6, 2.0, Color.WHITE, true, false, false)
	for row in range(3):
		for i in range(5 - absi(row - 1)):
			var z := (i - (4 - absi(row - 1)) * 0.5) * 0.016
			mb.add_cylinder(bone, Transform3D(xf.basis * ALONG_X, xf * Vector3(h + 0.003, (row - 1) * 0.022 + 0.008, z)), 0.0055, 0.0055, 0.007, 5, 2.0, Color.WHITE, true, false, false)
	mb.add_box(strap, Transform3D(xf.basis, xf * Vector3(h + 0.011, -0.046, 0)), Vector3(0.014, 0.012, 0.095), 2.0, Color.WHITE, false)


## Leather bellows folded six times, length 1 along +X (Jam stretches it between the ends).
static func _bellows(mb: MeshBuilder, xf: Transform3D) -> void:
	var leather := PSXMat.lit("leather", Color(0.62, 0.12, 0.1))
	var rings: Array = []
	var n := 12
	for i in range(n + 1):
		var r := END_R * (0.94 if i % 2 == 0 else 0.8)
		rings.append([float(i) / n, r, r])
	mb.add_loft(leather, Transform3D(xf.basis * ALONG_X, xf.origin), rings, MeshBuilder.profile_circle(6), 2.0, Color.WHITE, false, false, true, true)


# ---- fiddle ----
## The body's outline, the right half from the tail (y 0) to the neck (y 0.355); x across.
const FIDDLE_HALF := [Vector2(0.0, 0.0), Vector2(0.05, 0.004), Vector2(0.083, 0.02), Vector2(0.1, 0.05), Vector2(0.103, 0.08),
	Vector2(0.095, 0.108), Vector2(0.084, 0.118), Vector2(0.066, 0.124), Vector2(0.057, 0.142), Vector2(0.054, 0.165),
	Vector2(0.057, 0.188), Vector2(0.066, 0.206), Vector2(0.08, 0.212), Vector2(0.086, 0.228), Vector2(0.085, 0.26),
	Vector2(0.077, 0.29), Vector2(0.06, 0.32), Vector2(0.035, 0.345), Vector2(0.0, 0.355)]
## Where the bow crosses the strings and the left hand stops them (fiddle frame).
const FIDDLE_BOWED := Vector3(0, 0.05, -0.165)
const FIDDLE_STOP := Vector3(0, 0.035, -0.43)


## The whole outline from a right half, shrunk by `k` about its middle.
static func _outline(half: Array, k: float = 1.0) -> PackedVector2Array:
	var mid := Vector2(0, 0.1775) * (1.0 - k)
	var pts := PackedVector2Array()
	for p in half:
		pts.append(p * k + mid)
	for i in range(half.size() - 2, 0, -1):
		pts.append(half[i] * Vector2(-k, k) + mid)
	return pts


static func _fiddle(mb: MeshBuilder, xf: Transform3D) -> void:
	var varnish := PSXMat.flat(Color(0.56, 0.24, 0.1))
	var spruce := PSXMat.flat(Color(0.72, 0.38, 0.14))
	var ebony := PSXMat.flat(Color(0.08, 0.07, 0.07))
	var pale := PSXMat.flat(Color(0.62, 0.6, 0.56))
	var light := _wood(Color(1.0, 0.9, 0.66))
	# outlines are drawn (x across, y along); along the fiddle is -Z, the extrusion's depth is up
	var flat := Transform3D(xf.basis * Basis(Vector3.RIGHT, -PI * 0.5), xf.origin)
	mb.add_extrude(varnish, flat, _outline(FIDDLE_HALF), 0.034, 3.0, Color(0.8, 0.8, 0.8))
	mb.add_extrude(spruce, Transform3D(flat.basis, xf * Vector3(0, 0.021, 0)), _outline(FIDDLE_HALF, 0.97), 0.008, 3.0)
	mb.add_extrude(varnish, Transform3D(flat.basis, xf * Vector3(0, -0.021, 0)), _outline(FIDDLE_HALF, 0.97), 0.008, 3.0, Color(0.7, 0.7, 0.7))
	var top := 0.025
	# f-holes, bridge, tailpiece, chinrest
	for s in [-1.0, 1.0]:
		mb.add_box(ebony, Transform3D(xf.basis * Basis(Vector3.UP, s * 0.18), xf * Vector3(s * 0.034, top + 0.0005, -0.16)), Vector3(0.005, 0.002, 0.056), 2.0, Color.WHITE)
	mb.add_box(light, Transform3D(xf.basis, xf * Vector3(0, top + 0.011, -0.12)), Vector3(0.042, 0.022, 0.005), 2.0)
	_bar(mb, ebony, xf, Vector3(0, top + 0.004, -0.012), Vector3(0, top + 0.006, -0.085), 0.03, 0.008)
	mb.add_box(ebony, Transform3D(xf.basis, xf * Vector3(-0.05, top + 0.008, -0.03)), Vector3(0.05, 0.012, 0.045), 2.0)
	# neck, fingerboard, strings, pegbox, pegs, scroll
	mb.add_box(varnish, Transform3D(xf.basis, xf * Vector3(0, 0.02, -0.41)), Vector3(0.026, 0.03, 0.13), 2.0, Color(0.85, 0.85, 0.85), false)
	_bar(mb, ebony, xf, Vector3(0, top + 0.008, -0.2), Vector3(0, top + 0.016, -0.475), 0.036, 0.008)
	_bar(mb, pale, xf, Vector3(0, top + 0.006, -0.085), Vector3(0, top + 0.023, -0.12), 0.014, 0.0015)
	_bar(mb, pale, xf, Vector3(0, top + 0.023, -0.12), Vector3(0, top + 0.021, -0.475), 0.012, 0.0015)
	mb.add_box(varnish, Transform3D(xf.basis, xf * Vector3(0, 0.034, -0.505)), Vector3(0.024, 0.032, 0.06), 2.0, Color.WHITE, false)
	for i in range(4):
		var z := -0.484 - i * 0.013
		mb.add_cylinder(ebony, Transform3D(xf.basis * ALONG_X, xf * Vector3(-0.03, 0.038, z)), 0.0042, 0.0042, 0.06, 5, 2.0, Color.WHITE, true, true)
	mb.add_cylinder(varnish, Transform3D(xf.basis * ALONG_X, xf * Vector3(-0.011, 0.038, -0.548)), 0.018, 0.018, 0.022, 7, 2.0, Color.WHITE, true, true, false)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(varnish, Transform3D(xf.basis * ALONG_X, xf * Vector3(s * 0.011 - (0.002 if s < 0 else 0.0), 0.04, -0.549)), 0.009, 0.009, 0.002, 6, 2.0, Color(0.6, 0.6, 0.6), true, true, false)


## The bow: frog at the origin, the stick along -Z over the hair.
const BOW_LEN := 0.72


static func _bow(mb: MeshBuilder, xf: Transform3D) -> void:
	var stick := _wood(Color(0.55, 0.22, 0.12))
	var ebony := PSXMat.flat(Color(0.08, 0.07, 0.07))
	var hair := PSXMat.flat(Color(0.92, 0.9, 0.84))
	var pts := PackedVector3Array()
	for p in MeshBuilder.curve_points(Vector3(0, 0.018, 0.02), Vector3(0, 0.006, -BOW_LEN * 0.5), Vector3(0, 0.02, -BOW_LEN), 8):
		pts.append(xf * p)
	mb.add_tube(stick, pts, 0.0048, 0.0032, 4, 2.0, Color.WHITE, true, true)
	_bar(mb, hair, xf, Vector3(0, -0.002, -0.02), Vector3(0, 0.006, -BOW_LEN + 0.01), 0.009, 0.0015)
	mb.add_box(ebony, Transform3D(xf.basis, xf * Vector3(0, 0.006, -0.01)), Vector3(0.012, 0.024, 0.042), 2.0, Color.WHITE, false)
	mb.add_box(ebony, Transform3D(xf.basis, xf * Vector3(0, 0.012, -BOW_LEN + 0.002)), Vector3(0.008, 0.02, 0.014), 2.0, Color.WHITE, false)


# ---- tin whistle ----
const WHISTLE_LEN := 0.3


static func _whistle(mb: MeshBuilder, xf: Transform3D) -> void:
	var brass := PSXMat.lit("metal", Color(1.0, 0.85, 0.5))
	var head := PSXMat.flat(Color(0.1, 0.18, 0.12))
	var hole := PSXMat.flat(Color(0.04, 0.03, 0.03))
	var b := xf.basis * ALONG_NZ
	mb.add_cylinder(head, Transform3D(b, xf.origin), 0.0055, 0.009, 0.016, 8, 2.0, Color.WHITE, false, true)
	mb.add_cylinder(head, Transform3D(b, xf * Vector3(0, 0, -0.016)), 0.009, 0.009, 0.056, 8, 2.0)
	mb.add_box(hole, Transform3D(xf.basis, xf * Vector3(0, 0.0085, -0.034)), Vector3(0.007, 0.002, 0.008), 2.0)
	mb.add_cylinder(brass, Transform3D(b, xf * Vector3(0, 0, -0.072)), 0.0068, 0.006, WHISTLE_LEN - 0.072, 8, 2.0, Color.WHITE, true)
	for z in [0.12, 0.14, 0.16, 0.195, 0.215, 0.235]:
		mb.add_box(hole, Transform3D(xf.basis, xf * Vector3(0, 0.0061, -z)), Vector3(0.0045, 0.0015, 0.0045), 2.0)


# ---- bodhran ----
const DRUM_R := 0.22
const DRUM_D := 0.09


static func _bodhran(mb: MeshBuilder, xf: Transform3D) -> void:
	var rim := _wood(Color(0.8, 0.6, 0.38))
	var skin := PSXMat.flat(Color(0.86, 0.78, 0.6))
	var paint := PSXMat.flat(Color(0.5, 0.14, 0.08))
	var bar := _wood(Color(0.45, 0.28, 0.16))
	var brass := PSXMat.flat(Color(0.85, 0.66, 0.28))
	var n := 16
	var seg := 2.0 * DRUM_R * sin(PI / n) + 0.004
	for i in range(n):
		var a := TAU * (i + 0.5) / n
		var radial := Vector3(cos(a), sin(a), 0)
		var tang := Vector3(-sin(a), cos(a), 0)
		mb.add_box(rim, Transform3D(xf.basis * Basis(tang, radial, Vector3.BACK), xf * (radial * (DRUM_R + 0.004))), Vector3(seg, 0.012, DRUM_D), 2.0, Color(0.85, 0.85, 0.85) if i % 2 else Color.WHITE, false, false)
		var t := TAU * i / n
		mb.add_box(brass, Transform3D(xf.basis, xf * Vector3(cos(t) * (DRUM_R + 0.011), sin(t) * (DRUM_R + 0.011), DRUM_D * 0.5 - 0.012)), Vector3(0.006, 0.006, 0.006), 2.0, Color.WHITE, false)
	mb.add_cylinder(skin, Transform3D(xf.basis * ALONG_Z, xf * Vector3(0, 0, DRUM_D * 0.5 - 0.006)), DRUM_R, DRUM_R, 0.004, n, 1.5, Color.WHITE, true, true)
	# a painted knot on the skin: three rings of dots round a centre
	mb.add_cylinder(paint, Transform3D(xf.basis * ALONG_Z, xf * Vector3(0, 0, DRUM_D * 0.5 - 0.0015)), 0.028, 0.028, 0.0015, 8, 2.0, Color.WHITE, true, false, false)
	for k in range(3):
		var a := TAU * k / 3.0 + PI * 0.5
		mb.add_cylinder(paint, Transform3D(xf.basis * ALONG_Z, xf * Vector3(cos(a) * 0.075, sin(a) * 0.075, DRUM_D * 0.5 - 0.0015)), 0.018, 0.018, 0.0015, 8, 2.0, Color.WHITE, true, false, false)
	# the cross-bars inside the open back
	mb.add_box(bar, Transform3D(xf.basis, xf * Vector3(0, 0, -0.025)), Vector3(DRUM_R * 2.0, 0.012, 0.012), 2.0, Color.WHITE, false)
	mb.add_box(bar, Transform3D(xf.basis, xf * Vector3(0, 0, -0.012)), Vector3(0.012, DRUM_R * 2.0, 0.012), 2.0, Color.WHITE, false)


const TIPPER_LEN := 0.2


static func _tipper(mb: MeshBuilder, xf: Transform3D) -> void:
	var wood := _wood(Color(0.9, 0.7, 0.45))
	var b := xf.basis * ALONG_Z
	mb.add_cylinder(wood, Transform3D(b, xf * Vector3(0, 0, -TIPPER_LEN * 0.5)), 0.006, 0.006, TIPPER_LEN, 6, 2.0, Color.WHITE, true, true)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(wood, Transform3D(b, xf * Vector3(0, 0, s * TIPPER_LEN * 0.5 - 0.014)), 0.0095, 0.0095, 0.028, 6, 2.0, Color(0.8, 0.8, 0.8), true, true)


# ---- hurdy-gurdy ----
## The body seen from above, the half on +Z (x along, y across).
const GURDY_HALF := [Vector2(-0.205, 0.0), Vector2(-0.2, 0.05), Vector2(-0.17, 0.085), Vector2(-0.12, 0.095), Vector2(-0.07, 0.083),
	Vector2(-0.035, 0.075), Vector2(0.0, 0.08), Vector2(0.05, 0.098), Vector2(0.11, 0.112), Vector2(0.18, 0.112),
	Vector2(0.22, 0.095), Vector2(0.24, 0.06), Vector2(0.248, 0.0)]
const GURDY_H := 0.11
## The crank's axle comes out of the tail here; the left hand's keys are round KEYS_AT.
const CRANK_AT := Vector3(0.25, 0.02, 0.0)
const CRANK_ARM := 0.065
const KEYS_AT := Vector3(-0.13, 0.09, -0.07)


static func _gurdy(mb: MeshBuilder, xf: Transform3D) -> void:
	var body := _wood(Color(0.78, 0.46, 0.22))
	var top := _wood(Color(1.0, 0.78, 0.48))
	var dark := _wood(Color(0.42, 0.24, 0.13))
	var ebony := PSXMat.flat(Color(0.08, 0.07, 0.07))
	var bone := PSXMat.flat(Color(0.9, 0.86, 0.74))
	var pale := PSXMat.flat(Color(0.86, 0.84, 0.78))
	var half := PackedVector2Array()
	for p in GURDY_HALF:
		half.append(p)
	var outline := PackedVector2Array(half)
	for i in range(half.size() - 2, 0, -1):
		outline.append(Vector2(half[i].x, -half[i].y))
	var lay := Transform3D(xf.basis * Basis(Vector3.RIGHT, PI * 0.5), xf.origin)
	mb.add_extrude(body, lay, outline, GURDY_H, 3.0, Color(0.85, 0.85, 0.85))
	var inner := PackedVector2Array()
	for p in outline:
		inner.append(p * 0.97)
	mb.add_extrude(top, Transform3D(lay.basis, xf * Vector3(0, GURDY_H * 0.5 + 0.003, 0)), inner, 0.008, 3.0)
	# keybox (with its lid), keys out of its far side, the wheel's cover, strings, tailpiece
	mb.add_box(dark, Transform3D(xf.basis, xf * Vector3(-0.12, 0.09, 0)), Vector3(0.36, 0.055, 0.07), 2.0, Color.WHITE, false)
	mb.add_box(dark, Transform3D(xf.basis, xf * Vector3(-0.12, 0.121, 0)), Vector3(0.37, 0.008, 0.078), 2.0, Color(0.75, 0.75, 0.75), false)
	for i in range(12):
		var x := -0.27 + i * 0.025
		var sharp := i % 3 == 1
		var out := 0.03 if sharp else 0.045
		mb.add_box(ebony if sharp else bone, Transform3D(xf.basis, xf * Vector3(x, 0.08 + (0.014 if sharp else 0.0), -0.035 - out * 0.5)), Vector3(0.008, 0.01, out), 2.0, Color.WHITE, false)
		mb.add_box(ebony if sharp else bone, Transform3D(xf.basis, xf * Vector3(x, 0.08 + (0.014 if sharp else 0.0), -0.035 - out)), Vector3(0.013, 0.016, 0.01), 2.0, Color.WHITE, false)
	mb.add_cylinder(dark, Transform3D(xf.basis * ALONG_Z, xf * Vector3(0.15, 0.05, -0.05)), 0.066, 0.066, 0.1, 10, 2.0, Color.WHITE, true, true, false)
	for z in [-0.05, -0.044, 0.044, 0.05]:
		_bar(mb, pale, xf, Vector3(-0.3, 0.068, z), Vector3(0.235, 0.064, z), 0.003, 0.002)
	mb.add_box(ebony, Transform3D(xf.basis, xf * Vector3(0.232, 0.064, 0)), Vector3(0.02, 0.01, 0.12), 2.0, Color.WHITE, false)
	# pegbox and a carved head
	mb.add_box(dark, Transform3D(xf.basis, xf * Vector3(-0.33, 0.09, 0)), Vector3(0.06, 0.06, 0.06), 2.0, Color.WHITE, false)
	for i in range(3):
		mb.add_cylinder(ebony, Transform3D(xf.basis * ALONG_Z, xf * Vector3(-0.345 + i * 0.016, 0.1, -0.05)), 0.005, 0.005, 0.1, 5, 2.0, Color.WHITE, true, true)
	mb.add_blob(dark, Transform3D(xf.basis, xf * Vector3(-0.385, 0.105, 0)), Vector3(0.032, 0.038, 0.03), RandomNumberGenerator.new(), 0.0, 3, 6, 2.0, Color.WHITE)


## The crank: axle along +X from the origin, the arm out along +Y, its handle along +X.
static func _crank(mb: MeshBuilder, xf: Transform3D) -> void:
	var iron := PSXMat.lit("metal", Color(0.55, 0.55, 0.58))
	var wood := _wood(Color(0.42, 0.24, 0.13))
	mb.add_cylinder(iron, Transform3D(xf.basis * ALONG_X, xf.origin), 0.007, 0.007, 0.034, 6, 2.0, Color.WHITE, true)
	mb.add_box(iron, Transform3D(xf.basis, xf * Vector3(0.034, CRANK_ARM * 0.5, 0)), Vector3(0.01, CRANK_ARM + 0.014, 0.012), 2.0, Color.WHITE, false)
	mb.add_cylinder(wood, Transform3D(xf.basis * ALONG_X, xf * Vector3(0.038, CRANK_ARM, 0)), 0.0095, 0.0095, 0.05, 6, 2.0, Color.WHITE, true)
