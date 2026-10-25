class_name FogPlants
extends RefCounted
## The fog isle's vegetation and rocks for GenIsland's MultiMeshes (FogTheme.meshes): a dark giant wood. Big trees
## are spiral giants twisting up like wrung rope into curling limbs, and gnarled giants snaking their limbs out
## sideways and down to the ground; they come as [body, detail, lean, trunk radius] like ForestPlants' [body,
## detail, lean] (the detail - roots, a hollow, a noose of old rope, lichen - only up close).
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


static func _lean(rng: RandomNumberGenerator, k: float) -> Vector3:
	return Vector3(rng.randf_range(-k, k), 0, rng.randf_range(-k, k))


## A crooked limb from `from` along `dir`, `length` long and `r` thick at its root, splitting `depth` more times;
## each tip's end appended to `ends`. `droop` bends the limbs down toward their tips (a willow's).
static func _limb(mb: MeshBuilder, b: Material, rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, r: float, depth: int,
		ends: Array, droop := 0.0) -> void:
	var kink := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.15, 0.2), rng.randf_range(-0.35, 0.35)) * length
	var mid := from + dir * length * 0.5 + kink * 0.5
	var end := from + dir * length + kink + Vector3.DOWN * droop * length
	mb.add_tube(b, PackedVector3Array([from, mid, end]), r, r * 0.45, _s(5 if r > 0.15 else 4), 0.8)
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


# --------------------------------------------------------------------------
# The giants (Zach, 2026-10-24: "big spooky trees that can make big spooky forests", and a photo of a misty
# gnarled wood): the spiral giant, the forest's main tree, and the gnarled giant mixed in. Dark grey-violet bark,
# limbs ending in tightening curls or sprays of twigs, moss in pale curtains.
# --------------------------------------------------------------------------
## (building a giant's far version: tubes with half their sides, the moss and twigs drawn into a throwaway builder so
## the rng runs the same and the far tree is the same tree)
static var _far := false


static func _s(n: int) -> int:
	return maxi(3, n / 2) if _far else n


## `mb`, or a throwaway builder while building a far version (for the small stuff only seen up close).
static func _near(mb: MeshBuilder) -> MeshBuilder:
	return MeshBuilder.new() if _far else mb


## [the near version's arrays..., its far version]: the giant built twice from the same seed (GenIsland shows the
## full one inside ~180 m and the light one out to the fog's end).
static func _with_far(build: Callable, seed_value: int) -> Array:
	var near: Array = build.call(seed_value)
	_far = true
	var far: Array = build.call(seed_value)
	_far = false
	near.append(far[0])
	return near


static func _gbark() -> Material:
	return PSXMat.lit("bark", Color(0.42, 0.38, 0.44))


## Hanging moss as stringy curtains: two crossed pale cards hung upside down (dense at the limb, thin strands below).
static func _shroud(mb: MeshBuilder, rng: RandomNumberGenerator, at: Vector3, length: float) -> void:
	var m := PSXMat.cutout("fog_grass", Color(0.95, 0.97, 0.92), 0.15, 2.0)
	var L := length * rng.randf_range(0.8, 1.2)
	var w := rng.randf_range(0.9, 1.5)
	var down := Basis(Vector3.FORWARD, PI)
	for k in range(2):
		mb.add_card(m, Transform3D(Basis(Vector3.UP, rng.randf() * PI + k * PI * 0.5) * down, at), w, L)


## A limb that ends in a curl: from `from` along `dir` for `length`, turning ever tighter about the axis across it
## (`up` true curls up and back, false hooks down). Returns the tip.
static func _curl(mb: MeshBuilder, b: Material, rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, r: float, up: bool) -> Vector3:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.05:
		flat = Vector3(1, 0, 0)
	var axis := flat.normalized().cross(Vector3.UP) * (1.0 if up else -1.0)
	var n := 14
	var pts := PackedVector3Array([from])
	var p := from
	var h := dir.normalized()
	for i in range(n):
		var t := float(i) / n
		p += h * length / n * lerpf(1.3, 0.45, t)
		pts.append(p)
		h = h.rotated(axis, lerpf(0.04, 0.55, t * t) + rng.randf_range(-0.03, 0.03))
	mb.add_tube(b, pts, r, 0.02, _s(5 if r > 0.2 else 4), 0.7)
	return p


## A giant's crown of curling limbs from `top`: `n` limbs reaching out and up, each curling at its end, a smaller
## curl or two off each; moss off some tips.
static func _curl_crown(mb: MeshBuilder, b: Material, rng: RandomNumberGenerator, top: Vector3, n: int, reach: float, r: float, ends: Array) -> void:
	var a0 := rng.randf() * TAU
	for k in range(n):
		var a := a0 + TAU * k / n + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var L := reach * rng.randf_range(0.7, 1.0)
		var mid := top + out * L * 0.45 + Vector3.UP * L * rng.randf_range(0.35, 0.7)
		var elbow := top + out * L * 0.7 + Vector3.UP * L * rng.randf_range(0.3, 0.8)
		mb.add_tube(b, MeshBuilder.curve_points(top, mid, elbow, 6), r, r * 0.45, _s(6), 0.6)
		var d := (elbow - mid).normalized()
		ends.append(_curl(mb, b, rng, elbow, d, L * rng.randf_range(0.5, 0.75), r * 0.45, rng.randf() < 0.5))
		for j in range(rng.randi_range(1, 2)):
			var at := top.lerp(elbow, rng.randf_range(0.45, 0.85))
			var side := out.rotated(Vector3.UP, rng.randf_range(-1.2, 1.2))
			ends.append(_curl(mb, b, rng, at, (side + Vector3.UP * rng.randf_range(-0.2, 0.6)).normalized(), L * rng.randf_range(0.3, 0.5),
				r * 0.28, rng.randf() < 0.4))


## Moss curtains off some of the tips, and a black hollow or two in the trunk.
static func _haunt(mb: MeshBuilder, rng: RandomNumberGenerator, ends: Array, odds: float, moss_len: Vector2) -> void:
	for e in ends:
		if rng.randf() < odds:
			_shroud(mb, rng, e, rng.randf_range(moss_len.x, moss_len.y))


## The spiral giant (24-32 m): a massive trunk twisting up like a wrung rope, a crown of six or seven long limbs
## each ending in a curl, moss hanging in long curtains.
static func spiral_giant(seed_value: int) -> Array:
	return _with_far(_spiral_giant, seed_value)


static func _spiral_giant(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var b := _gbark()
	var h := rng.randf_range(24.0, 32.0)
	var r := rng.randf_range(1.8, 2.3)
	var lean := _lean(rng, 1.2)
	var fy := h * rng.randf_range(0.55, 0.65)
	var spin := rng.randf() * TAU
	var tw := rng.randf_range(0.9, 1.4)
	var pts := PackedVector3Array()
	for i in range(8):
		var t := float(i) / 7.0
		pts.append(Vector3(cos(spin + t * 4.0), 0, sin(spin + t * 4.0)) * tw * sin(t * PI) + lean * t + Vector3.UP * (fy * t - 0.3 * (1.0 - t)))
	body.add_tube(b, pts, r, r * 0.55, _s(9), 0.5)
	# two strands wound round the trunk, the twist made visible
	for k in range(2):
		var sp := PackedVector3Array()
		for i in range(12):
			var t := float(i) / 11.0 * 0.85
			var base: Vector3 = pts[0].lerp(pts[pts.size() - 1], t)
			var rr := lerpf(r, r * 0.6, t) * 0.92
			sp.append(base + Vector3(cos(spin + t * 7.0 + PI * k), 0, sin(spin + t * 7.0 + PI * k)) * rr)
		_near(body).add_tube(b, sp, r * 0.28, r * 0.12, 5, 0.6)
	var ends: Array = []
	_curl_crown(body, b, rng, pts[pts.size() - 1], rng.randi_range(6, 7), h - fy + 4.0, r * 0.42, ends)
	_haunt(body, rng, ends, 0.4, Vector2(3.0, 6.0))
	return [body.commit(), _foot(rng, r, b, lean, h, true).commit(), lean, r]




## A snaking limb from a to b: weaving side to side and rising or dipping along the way (`arch` > 0 bows up, < 0
## sags down to the ground and back). Returns its points.
static func _snake(rng: RandomNumberGenerator, a: Vector3, b: Vector3, arch: float, wobble: float) -> PackedVector3Array:
	var d := b - a
	var side := d.cross(Vector3.UP).normalized() if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	var ph := rng.randf() * TAU
	var waves := rng.randf_range(1.2, 2.2)
	var pts := PackedVector3Array()
	for i in range(11):
		var t := float(i) / 10.0
		var env := sin(t * PI)
		pts.append(a + d * t + side * sin(ph + t * TAU * waves) * wobble * env + Vector3.UP * (arch * env + sin(ph * 1.7 + t * TAU * waves * 0.7) * wobble * 0.4 * env))
	return pts


## A spray of fine bare twigs off a point: thin crooked forks, two levels.
static func _twigs(mb: MeshBuilder, b: Material, rng: RandomNumberGenerator, at: Vector3, dir: Vector3, size: float) -> void:
	var ends: Array = []
	for k in range(rng.randi_range(2, 3)):
		var d := (dir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.0, 0.9), rng.randf_range(-0.8, 0.8))).normalized()
		_limb(mb, b, rng, at, d, size * rng.randf_range(0.6, 1.0), 0.09, 1, ends)


## The gnarled giant (18-26 m tall, limbs 10-16 m out), after Zach's photo: two or three twisting trunks splitting
## from one mossy foot, long limbs snaking out sideways, some sagging to the ground and rising again, sprays of fine
## bare twigs along them and at their ends, green moss up the trunks and along the tops of the limbs.
static func gnarl_giant(seed_value: int) -> Array:
	return _with_far(_gnarl_giant, seed_value)


static func _gnarl_giant(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var b := _gbark()
	var moss := PSXMat.lit("moss_stone", Color(0.85, 0.95, 0.75), {"affine": 0.5})
	var h := rng.randf_range(18.0, 26.0)
	var r := rng.randf_range(1.4, 1.8)
	var n := rng.randi_range(2, 3)
	var a0 := rng.randf() * TAU
	var tops: Array = []
	for k in range(n):
		var a := a0 + TAU * k / n + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0, sin(a))
		var top := out * rng.randf_range(3.0, 6.0) + Vector3.UP * h * rng.randf_range(0.75, 0.95)
		var tr := r * (0.75 if k == 0 else 0.55)
		var pts := _snake(rng, Vector3.DOWN * 0.3 + out * 0.3, top, 0.0, rng.randf_range(0.8, 1.6))
		body.add_tube(b, pts, tr, tr * 0.55, _s(8), 0.5)
		for i in range(1, 6):
			var q: Vector3 = pts[i]
			_near(body).add_blob(moss, Transform3D(Basis(Vector3.UP, a), q + out * tr * 0.4 + Vector3.UP * 0.2), Vector3(tr * 0.85, 0.4, tr * 0.7), rng, 0.3, 2, 5, 0.6)
		tops.append([pts, out, tr])
	var ends: Array = []
	for t in tops:
		var pts: PackedVector3Array = t[0]
		var out: Vector3 = t[1]
		var tr: float = t[2]
		for j in range(rng.randi_range(2, 3)):
			var from: Vector3 = pts[rng.randi_range(5, 10)]
			var dir := out.rotated(Vector3.UP, rng.randf_range(-1.4, 1.4))
			var L := rng.randf_range(10.0, 16.0)
			var sag := rng.randf() < 0.35
			var to := from + dir * L + Vector3.UP * (rng.randf_range(-from.y + 1.0, -from.y + 3.0) if sag else rng.randf_range(-3.0, 3.0))
			var lp := _snake(rng, from, to, -from.y * 0.6 if sag else rng.randf_range(0.5, 2.5), rng.randf_range(0.6, 1.4))
			var lr := tr * rng.randf_range(0.55, 0.65)
			body.add_tube(b, lp, lr, lr * 0.3, _s(6), 0.6)
			for i in range(2, 9, 2):
				if rng.randf() < 0.45:
					var q: Vector3 = lp[i]
					_near(body).add_blob(moss, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q + Vector3.UP * lr * 0.6), Vector3(lr * 1.4, lr * 0.5, lr * 1.0), rng, 0.3, 2, 5, 0.6)
				if rng.randf() < 0.3:
					_twigs(_near(body), b, rng, lp[i], (Vector3.UP + dir * 0.5).normalized(), rng.randf_range(3.0, 4.5))
			_twigs(body, b, rng, lp[lp.size() - 1], dir, rng.randf_range(2.0, 3.5))
			ends.append(lp[lp.size() - 1])
		_twigs(body, b, rng, pts[pts.size() - 1], (Vector3.UP + out).normalized(), rng.randf_range(2.5, 4.0))
	var foot := _foot(rng, r, b, Vector3.ZERO, h, true)
	foot.add_blob(moss, Transform3D(Basis(), Vector3.UP * 0.5), Vector3(r * 1.6, 0.9, r * 1.6), rng, 0.3, 3, 7, 0.6)
	return [body.commit(), foot.commit(), (tops[0][1] as Vector3) * 2.0, r * 0.95]
