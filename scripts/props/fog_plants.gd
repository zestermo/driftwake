class_name FogPlants
extends RefCounted
## The fog isle's vegetation and rocks for GenIsland's MultiMeshes (FogTheme.meshes): a dead wood. Big trees
## are bare grey oaks forking into crooked limbs hung with grey moss, drowned willows weeping strands, dead firs
## standing as spires of broken stubs, a few still holding brown leaves in clumps; the big ones come as [body,
## detail, lean] like ForestPlants' (the detail - roots, a hollow, a noose of old rope, lichen - only up close).
## Then crooked snags, brambles, dead bracken and bog grass, cattails in the black water and dark lichened
## stones. Origins on the ground.


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func bark() -> Material:
	return PSXMat.lit("bark", Color(0.58, 0.57, 0.56))


static func _moss() -> Material:
	return PSXMat.lit("fog_moor", Color(1.35, 1.35, 1.3), {"affine": 0.5})


static func _dead_leaves() -> Material:
	return PSXMat.lit("leaves_oak", Color(0.42, 0.39, 0.36), {"affine": 0.5})


static func _lean(rng: RandomNumberGenerator, k: float) -> Vector3:
	return Vector3(rng.randf_range(-k, k), 0, rng.randf_range(-k, k))


## A crooked limb from `from` along `dir`, `length` long and `r` thick at its root, splitting `depth` more times;
## each tip's end appended to `ends`. `droop` bends the limbs down toward their tips (a willow's).
static func _limb(mb: MeshBuilder, b: Material, rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, r: float, depth: int,
		ends: Array, droop := 0.0) -> void:
	var kink := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.15, 0.2), rng.randf_range(-0.35, 0.35)) * length
	var mid := from + dir * length * 0.5 + kink * 0.5
	var end := from + dir * length + kink + Vector3.DOWN * droop * length
	mb.add_tube(b, PackedVector3Array([from, mid, end]), r, r * 0.45, 5 if r > 0.15 else 4, 0.8)
	if depth <= 0:
		ends.append(end)
		return
	var fork := rng.randi_range(2, 3)
	var a0 := rng.randf() * TAU
	for k in range(fork):
		var a := a0 + TAU * k / fork
		var side := Vector3(cos(a), 0, sin(a))
		var nd := (dir + side * rng.randf_range(0.45, 0.85) + Vector3.UP * rng.randf_range(0.0, 0.3)).normalized()
		_limb(mb, b, rng, end, nd, length * rng.randf_range(0.55, 0.72), r * 0.5, depth - 1, ends, droop)


## Grey moss hanging from a limb's end: a long thin blob or two straight down.
static func _hang(mb: MeshBuilder, m: Material, rng: RandomNumberGenerator, at: Vector3, length: float) -> void:
	for k in range(rng.randi_range(1, 2)):
		var off := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var L := length * rng.randf_range(0.6, 1.1)
		var sh := rng.randf_range(0.8, 1.0)
		mb.add_blob(m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + off + Vector3.DOWN * L * 0.5), Vector3(0.18, L * 0.5, 0.12), rng, 0.25, 3, 4, 0.6,
			Color(sh, sh, sh))


## A dead oak (11-16 m): a thick leaning trunk forking low into crooked bare limbs, grey moss hanging off them,
## now and then a clump of brown leaves the winter never took.
static func dead_oak(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var b := bark()
	var h := rng.randf_range(11.0, 16.0)
	var r := rng.randf_range(0.7, 0.95)
	var lean := _lean(rng, 0.8)
	var fy := h * rng.randf_range(0.3, 0.42)
	var top := lean * 0.6 + Vector3.UP * fy
	body.add_tube(b, PackedVector3Array([Vector3.DOWN * 0.3, lean * 0.2 + Vector3.UP * fy * 0.45, top]), r, r * 0.75, 7, 0.6)
	var ends: Array = []
	var n := rng.randi_range(3, 5)
	var a0 := rng.randf() * TAU
	for k in range(n):
		var a := a0 + TAU * k / n + rng.randf_range(-0.3, 0.3)
		var dir := (Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.6, 1.0) + Vector3.UP * rng.randf_range(0.6, 1.2)).normalized()
		_limb(body, b, rng, top, dir, (h - fy) * rng.randf_range(0.42, 0.55), r * 0.5, 2, ends)
	var moss := _moss()
	var leaves := _dead_leaves()
	for e in ends:
		if rng.randf() < 0.45:
			_hang(body, moss, rng, e, rng.randf_range(1.2, 2.6))
		elif rng.randf() < 0.08:
			var s := rng.randf_range(0.7, 1.1)
			body.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), e), Vector3(s, s * 0.7, s), rng, 0.25, 3, 5, 0.5, Color(0.85, 0.85, 0.85))
	return [body.commit(), _foot(rng, r, b, lean, h, true).commit(), lean]


## A drowned willow (8-12 m): a short split trunk, long limbs arching out and down, moss hanging off every one in
## curtains to the ground.
static func dead_willow(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var b := bark()
	var h := rng.randf_range(8.0, 12.0)
	var r := rng.randf_range(0.55, 0.75)
	var lean := _lean(rng, 0.6)
	var top := lean * 0.5 + Vector3.UP * h * 0.38
	body.add_tube(b, PackedVector3Array([Vector3.DOWN * 0.3, lean * 0.25 + Vector3.UP * h * 0.2, top]), r, r * 0.7, 7, 0.6)
	var ends: Array = []
	var n := rng.randi_range(4, 6)
	var a0 := rng.randf() * TAU
	for k in range(n):
		var a := a0 + TAU * k / n + rng.randf_range(-0.3, 0.3)
		var dir := (Vector3(cos(a), 0, sin(a)) * 0.8 + Vector3.UP * rng.randf_range(0.9, 1.3)).normalized()
		_limb(body, b, rng, top, dir, h * rng.randf_range(0.35, 0.45), r * 0.45, 1, ends, 0.55)
	var moss := _moss()
	for e in ends:
		_hang(body, moss, rng, e, clampf((e as Vector3).y * rng.randf_range(0.45, 0.75), 1.2, 4.5))
	return [body.commit(), _foot(rng, r, b, lean, h, false).commit(), lean]


## A dead fir (16-24 m): a tall bare spire, broken stubs of branches down its length, the top snapped off.
static func dead_fir(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var b := bark()
	var h := rng.randf_range(16.0, 24.0)
	var lean := _lean(rng, 0.5)
	var r := rng.randf_range(0.42, 0.55)
	var top := lean + Vector3.UP * h
	body.add_tube(b, PackedVector3Array([Vector3.DOWN * 0.3, lean * 0.3 + Vector3.UP * h * 0.5, top]), r, 0.08, 6, 0.6)
	var stubs := rng.randi_range(9, 14)
	for k in range(stubs):
		var t := rng.randf_range(0.25, 0.95)
		var at := lean * t * t + Vector3.UP * h * t
		var a := rng.randf() * TAU
		var L := lerpf(2.6, 0.6, t) * rng.randf_range(0.4, 1.0)
		var dir := Vector3(cos(a), rng.randf_range(-0.5, -0.1), sin(a)).normalized()
		body.add_tube(b, PackedVector3Array([at, at + dir * L]), lerpf(0.09, 0.04, t), 0.02, 4, 1.0)
	var foot := _foot(rng, r, b, lean, h, false)
	return [body.commit(), foot.commit(), lean]


## The foot of a big dead tree: root flares, lichen up the trunk, sometimes a black hollow or a frayed rope from a
## low limb.
static func _foot(rng: RandomNumberGenerator, trunk_r: float, b: Material, lean: Vector3, h: float, hollow: bool) -> MeshBuilder:
	var mb := MeshBuilder.new()
	var n := rng.randi_range(4, 6)
	for k in range(n):
		var a := TAU * k / n + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		mb.add_tube(b, PackedVector3Array([d * trunk_r * 0.5 + Vector3.UP * 0.9, d * (trunk_r + 0.5) + Vector3.UP * 0.12, d * (trunk_r + rng.randf_range(1.0, 2.0)) + Vector3.DOWN * 0.2]),
			trunk_r * 0.45, 0.06, 5, 0.8)
	var lichen := PSXMat.flat(Color(0.6, 0.66, 0.56))
	for k in range(rng.randi_range(2, 4)):
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.5, 2.6)
		mb.add_blob(lichen, Transform3D(Basis(Vector3.UP, -a), lean * pow(y / h, 2.0) + Vector3(cos(a), 0, sin(a)) * trunk_r * 0.92 + Vector3.UP * y),
			Vector3(0.22, 0.3, 0.08), rng, 0.2, 2, 4)
	if hollow and rng.randf() < 0.5:
		mb.add_blob(PSXMat.flat(Color(0.05, 0.05, 0.05)), Transform3D(Basis(), Vector3(0, 0.8, trunk_r * 0.95)), Vector3(0.4, 0.65, 0.18), rng, 0.1, 3, 6)
	if rng.randf() < 0.15:
		var a := rng.randf() * TAU
		var at := lean * 0.2 + Vector3(cos(a), 0, sin(a)) * (trunk_r + 1.4) + Vector3.UP * 3.6
		mb.add_tube(PSXMat.lit("rope", Color(0.7, 0.66, 0.6)), PackedVector3Array([at, at + Vector3(0.05, -0.8, 0.02), at + Vector3(0.0, -1.5, 0.05)]), 0.03, 0.03, 3, 1.0)
	return mb


## A crooked snag (4-8 m): a grey trunk twisting up into a few bare forked limbs, moss on one.
static func snag(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var b := bark()
	var h := rng.randf_range(4.0, 8.0)
	var pts := PackedVector3Array()
	var p := Vector3.DOWN * 0.3
	for i in range(5):
		pts.append(p)
		p += Vector3(rng.randf_range(-0.5, 0.5), h / 4.0, rng.randf_range(-0.5, 0.5))
	mb.add_tube(b, pts, 0.28, 0.06, 5, 0.6)
	var ends: Array = []
	for k in range(rng.randi_range(2, 4)):
		var a := rng.randf() * TAU
		_limb(mb, b, rng, pts[rng.randi_range(2, 3)], Vector3(cos(a), rng.randf_range(0.5, 1.0), sin(a)).normalized(), rng.randf_range(1.4, 2.4), 0.1, 1, ends)
	if not ends.is_empty() and rng.randf() < 0.6:
		_hang(mb, _moss(), rng, ends[0], rng.randf_range(0.8, 1.6))
	return mb.commit()


## A leaning dead sapling (2-4 m) for the understory, a whip with two or three twigs.
static func whip(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var b := bark()
	var h := rng.randf_range(2.0, 4.0)
	var lean := _lean(rng, 0.8)
	var top := lean + Vector3.UP * h
	mb.add_tube(b, PackedVector3Array([Vector3.DOWN * 0.2, lean * 0.4 + Vector3.UP * h * 0.5, top]), 0.07, 0.02, 4, 1.0)
	for k in range(rng.randi_range(2, 3)):
		var t := rng.randf_range(0.5, 0.9)
		var at := lean * t + Vector3.UP * h * t
		var a := rng.randf() * TAU
		mb.add_tube(b, PackedVector3Array([at, at + Vector3(cos(a), 0.6, sin(a)) * rng.randf_range(0.5, 1.0)]), 0.03, 0.01, 3, 1.0)
	return mb.commit()


## A bramble: crossed cards of dark thorny canes, grey and leafless.
static func bramble(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := rng.randf_range(0.8, 1.2)
	mb.add_cross_cards(PSXMat.cutout("thornbrush", Color(0.42, 0.38, 0.4), 0.04, 1.0), Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), 1.3 * s, 0.9 * s, 3)
	return mb.commit()


## Pale toadstools in a ring (the fog's: white and grey caps, no red).
static func pale_caps(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var stem := PSXMat.flat(Color(0.86, 0.85, 0.8))
	var cap := PSXMat.flat(Color(0.76, 0.76, 0.72))
	for k in range(rng.randi_range(4, 8)):
		var a := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.3, 0.8)
		var s := rng.randf_range(0.6, 1.4)
		mb.add_cylinder(stem, Transform3D(Basis(), p - Vector3.UP * 0.05), 0.035 * s, 0.03 * s, 0.26 * s, 5, 1.0, Color.WHITE, false)
		mb.add_cylinder(cap, Transform3D(Basis(), p + Vector3.UP * 0.2 * s), 0.12 * s, 0.03 * s, 0.08 * s, 6, 1.0, Color.WHITE.darkened(rng.randf() * 0.25))
	return mb.commit()


## A dark stone, black-green lichen over its top.
static func bog_stone(seed_value: int, radius := 1.0) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var radii := Vector3(radius * rng.randf_range(0.9, 1.3), radius * rng.randf_range(0.55, 0.9), radius * rng.randf_range(0.8, 1.2))
	mb.add_blob(PSXMat.lit("forest_rock", Color(0.55, 0.56, 0.56), {"affine": 0.6}), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, radii.y * 0.45, 0)), radii, rng, 0.24, 4, 7, 0.5,
		Color.WHITE, -0.5)
	mb.add_blob(PSXMat.lit("leaves_late", Color(0.42, 0.5, 0.42), {"affine": 0.5}), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(radii.x * 0.1, radii.y * 1.02, 0)),
		Vector3(radii.x * 0.55, radii.y * 0.22, radii.z * 0.5), rng, 0.2, 2, 6, 0.5, Color.WHITE, 0.0)
	return mb.commit()


## A roof of dead limbs with no trunk of its own, closing over a fight's clearing (grey moss hanging from it).
static func limb_roof(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var b := bark()
	var h := rng.randf_range(11.0, 14.0)
	var ends: Array = []
	for k in range(rng.randi_range(3, 5)):
		var a := rng.randf() * TAU
		var from := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 3.0) + Vector3.UP * h
		_limb(body, b, rng, from, Vector3(cos(a + 1.4), rng.randf_range(-0.1, 0.2), sin(a + 1.4)).normalized(), rng.randf_range(3.0, 4.5), 0.18, 1, ends, 0.2)
	var moss := _moss()
	for e in ends:
		if rng.randf() < 0.7:
			_hang(body, moss, rng, e, rng.randf_range(1.5, 3.0))
	var detail := MeshBuilder.new()
	for k in range(rng.randi_range(2, 3)):
		var a := rng.randf() * TAU
		var at := Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.0, 3.5) + Vector3.UP * (h - 0.4)
		detail.add_tube(b, PackedVector3Array([at, at + Vector3(cos(a + 1.0), -0.4, sin(a + 1.0)) * rng.randf_range(1.2, 2.4)]), 0.08, 0.02, 4, 1.0)
	return [body.commit(), detail.commit(), Vector3.ZERO]


## Withered bracken: crossed cards of grey-brown fronds.
static func bracken(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := rng.randf_range(0.8, 1.2)
	mb.add_cross_cards(PSXMat.cutout("fog_bracken", Color.WHITE, 0.06, 1.0), Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), 1.4 * s, 0.9 * s, 2)
	return mb.commit()


## Pale dead grass.
static func grass() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.add_cross_cards(PSXMat.cutout("fog_grass", Color.WHITE, 0.08, 0.7), Transform3D.IDENTITY, 0.8, 0.6, 2)
	return mb.commit()


## A rotten stump, grey lichen on its broken top, pale caps round its foot.
static func stump(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var b := bark()
	var r := rng.randf_range(0.35, 0.6)
	var h := rng.randf_range(0.4, 1.1)
	mb.add_cylinder(b, Transform3D(Basis(), Vector3.DOWN * 0.2), r * 1.15, r, h + 0.2, 7, 0.8, Color.WHITE, false)
	for k in range(4):
		var a := TAU * k / 4.0 + rng.randf() * 0.5
		mb.add_cone(b, Transform3D(Basis(), Vector3(cos(a), 0, sin(a)) * r * 0.5 + Vector3.UP * h), r * 0.45, rng.randf_range(0.3, 0.7), 4)
	mb.add_blob(PSXMat.flat(Color(0.56, 0.6, 0.52)), Transform3D(Basis(), Vector3(r * 0.6, h * 0.6, 0)), Vector3(0.12, h * 0.45, r * 0.5), rng, 0.2, 2, 5)
	return mb.commit()


## A fallen dead trunk, its bark peeling grey, a beard of grey moss along it.
static func fallen_log(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var L := rng.randf_range(2.5, 4.5)
	var r := rng.randf_range(0.25, 0.4)
	var bend := rng.randf_range(-0.3, 0.3)
	var pts := PackedVector3Array([Vector3(-L * 0.5, r * 0.7, 0), Vector3(0, r * 0.8, bend), Vector3(L * 0.5, r * 0.6, 0)])
	mb.add_tube(bark(), pts, r, r * 0.8, 6, 0.8, Color.WHITE, true, true)
	mb.add_tube(_moss(), PackedVector3Array([pts[0] + Vector3.UP * r * 0.8, pts[1] + Vector3.UP * r * 0.85, pts[2] + Vector3.UP * r * 0.65]), r * 0.35, r * 0.25, 4, 1.0)
	return mb.commit()
