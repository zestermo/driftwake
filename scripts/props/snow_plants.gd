class_name SnowPlants
extends RefCounted
## The snow island's vegetation and rocks for GenIsland's MultiMeshes (SnowTheme.meshes). Conifers
## are stacked tiers of drooping boughs (a star of tips round the trunk, snow lying on each tier's
## top from the pine_snow texture's upper half, dark needles underneath); the big ones come as
## [body, detail, lean] like JunglePlants' giants (the body seen from the sea, the detail - the
## snow banked round the foot, dead stubs, icicles - only up close). Then young pines, dead trees,
## wind-bent shore pines, frozen shrubs and junipers, frosted grass, drifts, snow-capped black
## rocks, ice floes and the ice-crystal clusters that glow blue at night (emission, no lights).
## Origins on the ground.


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _needles() -> Material:
	return PSXMat.lit("pine_snow", Color(0.92, 0.98, 1.0), {"affine": 0.5})


static func _bark() -> Material:
	return PSXMat.lit("bark", Color(0.6, 0.5, 0.46))


static func _snow() -> Material:
	return PSXMat.lit("snow", Color.WHITE, {"affine": 0.5})


static func _crystal() -> Material:
	return PSXMat.lit("ice", Color(0.8, 0.93, 1.0), {"emission": Color(0.25, 0.62, 1.0), "emission_energy": 0.9, "affine": 0.3})


static func _seg(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, uv := 0.6) -> void:
	var d := b - a
	mb.add_cylinder(mat, Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), a), r0, r1, d.length() + 0.05, sides, uv, Color.WHITE, false)


## One tier of boughs: a star of 2n points round `c` (the rim's height), drooping tips and tucked
## notches, up to its top at c + rise; a flat underside back to the trunk. `snow` 0..1 how far
## down the snow lies; `shade` darkens the lower tiers.
static func _tier(mb: MeshBuilder, mat: Material, c: Vector3, r: float, rise: float, droop: float, n: int, snow: float, rng: RandomNumberGenerator, shade := 1.0) -> void:
	var apex := c + Vector3.UP * rise
	var under := c + Vector3.UP * rise * 0.3
	var rim: Array = []
	var off := rng.randf() * TAU
	for k in range(n * 2):
		var a := off + PI * k / n + rng.randf_range(-0.08, 0.08)
		var tip := k % 2 == 0
		var rr := r * (rng.randf_range(0.88, 1.08) if tip else rng.randf_range(0.58, 0.72))
		var y := -droop * (1.0 if tip else 0.3) * rng.randf_range(0.8, 1.2)
		rim.append(c + Vector3(cos(a) * rr, y, sin(a) * rr))
	var vmax := lerpf(1.0, 0.6, snow)
	var circ := maxf(1.0, roundf(TAU * r * 0.3))
	var top_col := Color(shade, shade, shade)
	var under_col := Color(0.42, 0.46, 0.5) * shade
	under_col.a = 1.0
	for k in range(rim.size()):
		var a: Vector3 = rim[k]
		var b: Vector3 = rim[(k + 1) % rim.size()]
		var u0 := float(k) / rim.size() * circ
		var u1 := float(k + 1) / rim.size() * circ
		var nt := (b - a).cross(apex - a).normalized()
		if nt.y < 0.0:
			nt = -nt
		mb.add_tri(mat, apex, a, b, nt, nt, nt, Vector2((u0 + u1) * 0.5, 0.0), Vector2(u0, vmax), Vector2(u1, vmax), top_col, nt)
		var nu := (b - a).cross(under - a).normalized()
		if nu.y > 0.0:
			nu = -nu
		mb.add_tri(mat, under, a, b, nu, nu, nu, Vector2((u0 + u1) * 0.5, 0.97), Vector2(u0, 0.99), Vector2(u1, 0.99), under_col, nu)


## A conifer's trunk and tiers into `mb`: `h` tall, the lowest tier `base_r` wide, the trunk bare
## for `bare` of its height, `tiers` of them, `snow` on them, `droop_k` how heavily they hang.
## Gaps (`gaps` > 0) leave every few tiers out, a cedar's layered look. Returns the trunk's top.
static func _conifer(mb: MeshBuilder, rng: RandomNumberGenerator, h: float, base_r: float, bare: float, tiers: int, snow: float, droop_k: float, lean: Vector3, trunk_r: float, gaps := 0) -> Vector3:
	var needles := _needles()
	var top := lean + Vector3.UP * h
	_seg(mb, _bark(), Vector3.DOWN * 0.3, lean * 0.5 + Vector3.UP * h * 0.5, trunk_r, trunk_r * 0.62, 6)
	_seg(mb, _bark(), lean * 0.5 + Vector3.UP * h * 0.5, top - Vector3.UP * 0.6, trunk_r * 0.62, trunk_r * 0.2, 5)
	var span := h * (1.0 - bare)
	for i in range(tiers):
		if gaps > 0 and i % (gaps + 1) == gaps and i < tiers - 2:
			continue
		var t := float(i) / tiers
		var y := h * bare + span * t
		var r := base_r * pow(1.0 - t, 0.9) * rng.randf_range(0.9, 1.08) + 0.35
		var c := lean * pow(y / h, 2.0) + Vector3.UP * y
		var rise := maxf(span / tiers * 1.7, r * 0.5)
		var n := clampi(int(r * 2.0) + 5, 5, 11)
		_tier(mb, needles, c, r, rise, r * 0.2 * droop_k, n, clampf(snow + rng.randf_range(-0.1, 0.1), 0.0, 1.0), rng, lerpf(0.72, 1.0, t))
	mb.add_cone(needles, Transform3D(Basis(), top - Vector3.UP * minf(0.4, h * 0.06)), minf(0.45, h * 0.08), minf(1.6, h * 0.25), 5, 0.6, Color.WHITE)
	return top


## The foot of a big conifer: snow banked round the trunk, dead stubs on its bare stretch, icicles.
static func _foot(rng: RandomNumberGenerator, trunk_r: float, bare_h: float, lean: Vector3, h: float) -> MeshBuilder:
	var mb := MeshBuilder.new()
	mb.add_blob(_snow(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3.UP * 0.05), Vector3(trunk_r * 3.2, 0.45, trunk_r * 2.8), rng, 0.2, 3, 7, 0.5, Color.WHITE, 0.0)
	var bark := _bark()
	for k in range(rng.randi_range(3, 5)):
		var y := rng.randf_range(1.6, maxf(2.0, bare_h))
		var a := rng.randf() * TAU
		var at := lean * pow(y / h, 2.0) + Vector3.UP * y
		var out := Vector3(cos(a), rng.randf_range(-0.2, 0.3), sin(a)) * rng.randf_range(0.6, 1.3)
		_seg(mb, bark, at, at + out + Vector3(cos(a), 0, sin(a)) * trunk_r, 0.07, 0.02, 4)
	var ice := _crystal()
	for k in range(rng.randi_range(2, 4)):
		var a := rng.randf() * TAU
		var y := rng.randf_range(1.4, 2.4)
		var at := Vector3(cos(a) * trunk_r * 1.1, y, sin(a) * trunk_r * 1.1)
		mb.add_cylinder(ice, Transform3D(Basis(Vector3.RIGHT, PI), at), 0.06, 0.0, rng.randf_range(0.4, 0.8), 4, 1.0, Color.WHITE, false, false, false)
	return mb


static func _lean(rng: RandomNumberGenerator, k: float) -> Vector3:
	return Vector3(rng.randf_range(-k, k), 0, rng.randf_range(-k, k))


## A spruce (15-20 m): the forest's mainstay, dense tiers to the ground, snow on every one.
static func spruce(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(15.0, 20.0)
	var lean := _lean(rng, 0.3)
	_conifer(body, rng, h, rng.randf_range(3.8, 4.6), 0.1, rng.randi_range(10, 12), 0.4, 1.0, lean, 0.42)
	return [body.commit(), _foot(rng, 0.42, h * 0.1 + 1.0, lean, h).commit(), lean]


## A snow-laden fir (12-16 m): rounder, its boughs bent under heavy snow.
static func fir(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(12.0, 16.0)
	var lean := _lean(rng, 0.35)
	_conifer(body, rng, h, rng.randf_range(4.2, 5.0), 0.08, rng.randi_range(8, 10), 0.85, 1.6, lean, 0.38)
	return [body.commit(), _foot(rng, 0.38, h * 0.08 + 1.0, lean, h).commit(), lean]


## A great pine (26-32 m) over the forest: a tall bare trunk, its crown high and narrow.
static func great_pine(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(26.0, 32.0)
	var lean := _lean(rng, 0.5)
	_conifer(body, rng, h, rng.randf_range(4.6, 5.4), 0.38, rng.randi_range(11, 13), 0.5, 1.1, lean, 0.75)
	return [body.commit(), _foot(rng, 0.75, h * 0.38, lean, h).commit(), lean]


## A cedar (22-28 m): flat layered tiers with sky between them, a lean.
static func cedar(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(22.0, 28.0)
	var lean := _lean(rng, 1.2)
	_conifer(body, rng, h, rng.randf_range(5.6, 6.6), 0.3, rng.randi_range(9, 11), 0.65, 0.7, lean, 0.62, 2)
	return [body.commit(), _foot(rng, 0.62, h * 0.3, lean, h).commit(), lean]


## Boughs with no trunk of their own, closing the roof over a fight's clearing (the ring trees
## round it carry them, as far as anyone under them can tell).
static func bough_roof(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var needles := _needles()
	var h := rng.randf_range(12.0, 15.0)
	for k in range(rng.randi_range(4, 6)):
		var a := rng.randf() * TAU
		var c := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 4.0) + Vector3.UP * (h + rng.randf_range(-1.5, 1.5))
		var r := rng.randf_range(3.2, 4.6)
		_tier(body, needles, c, r, r * 0.4, r * 0.25, 8, 0.7, rng, rng.randf_range(0.8, 1.0))
	var detail := MeshBuilder.new()
	var ice := _crystal()
	for k in range(rng.randi_range(4, 7)):
		var a := rng.randf() * TAU
		var at := Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.0, 5.0) + Vector3.UP * (h - 1.6)
		detail.add_cylinder(ice, Transform3D(Basis(Vector3.RIGHT, PI), at), 0.05, 0.0, rng.randf_range(0.5, 1.0), 4, 1.0, Color.WHITE, false, false, false)
	return [body.commit(), detail.commit(), Vector3.ZERO]


## A young pine (5-9 m) for the mid layer; `bare` > 0 lifts its tiers off a longer trunk.
static func young_pine(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var h := rng.randf_range(5.0, 9.0)
	_conifer(mb, rng, h, rng.randf_range(1.9, 2.6), rng.randf_range(0.06, 0.2), rng.randi_range(6, 8), rng.randf_range(0.3, 0.8), 1.2, _lean(rng, 0.2), 0.22)
	return mb.commit()


## A sapling (1.6-3 m) for the forest floor, half buried.
static func sapling(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	_conifer(mb, rng, rng.randf_range(1.6, 3.0), rng.randf_range(0.8, 1.1), 0.05, rng.randi_range(3, 5), rng.randf_range(0.5, 0.9), 1.4, _lean(rng, 0.1), 0.08)
	return mb.commit()


## A dead tree: a grey crooked trunk, bare limbs forking up, snow along their tops.
static func dead_tree(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("bark", Color(0.62, 0.6, 0.6))
	var snow := _snow()
	var h := rng.randf_range(4.0, 8.0)
	var pts := PackedVector3Array()
	var p := Vector3.DOWN * 0.3
	for i in range(5):
		pts.append(p)
		p += Vector3(rng.randf_range(-0.4, 0.4), h / 4.0, rng.randf_range(-0.4, 0.4))
	mb.add_tube(bark, pts, 0.28, 0.06, 5, 0.6, Color.WHITE)
	for k in range(rng.randi_range(4, 6)):
		var from: Vector3 = pts[rng.randi_range(2, 3)]
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), rng.randf_range(0.5, 1.1), sin(a)).normalized()
		var L := rng.randf_range(1.2, 2.6)
		var mid := from + dir * L * 0.55 + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		var end := from + dir * L
		mb.add_tube(bark, PackedVector3Array([from, mid, end]), 0.09, 0.02, 4, 1.0, Color(0.9, 0.9, 0.9))
		mb.add_blob(snow, Transform3D(Basis(Quaternion(Vector3.UP, (end - from).normalized())), mid + Vector3.UP * 0.08), Vector3(0.12, L * 0.3, 0.12), rng, 0.1, 2, 4, 1.0)
	mb.add_blob(snow, Transform3D(Basis(), Vector3.UP * 0.05), Vector3(0.9, 0.3, 0.8), rng, 0.2, 3, 6, 0.5, Color.WHITE, 0.0)
	return mb.commit()


## A wind-bent shore pine (3-5 m): leaning hard off the sea, its tiers swept to one side.
static func bent_pine(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var needles := _needles()
	var h := rng.randf_range(3.5, 5.0)
	var lean := Vector3(rng.randf_range(1.0, 1.6), 0, rng.randf_range(-0.4, 0.4))
	var pts := PackedVector3Array()
	for i in range(5):
		var t := i / 4.0
		pts.append(lean * pow(t, 1.6) + Vector3.UP * (h * t - 0.3 * (1.0 - t)))
	mb.add_tube(_bark(), pts, 0.2, 0.06, 5, 0.6, Color.WHITE)
	for i in range(rng.randi_range(3, 5)):
		var t := 0.45 + i * 0.13
		var c := lean * pow(t, 1.6) + Vector3.UP * h * t + lean.normalized() * 0.5
		var r := rng.randf_range(1.0, 1.6) * (1.2 - t * 0.6)
		_tier(mb, needles, c, r, r * 0.4, r * 0.3, 6, rng.randf_range(0.4, 0.9), rng, lerpf(0.75, 1.0, t))
	return mb.commit()


## A frozen shrub: crossed cards of dark twigs with snow caught in them, on a little mound.
static func frost_shrub(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := rng.randf_range(1.1, 1.7)
	mb.add_cross_cards(PSXMat.cutout("frost_shrub", Color.WHITE, 0.03, 1.4), Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), s * 1.2, s, 3)
	mb.add_blob(_snow(), Transform3D(Basis(), Vector3.UP * 0.02), Vector3(s * 0.45, 0.22, s * 0.4), rng, 0.2, 2, 6, 0.5, Color.WHITE, 0.0)
	return mb.commit()


## A juniper: a low spreading mound of two or three flat snowy tiers.
static func juniper(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var needles := _needles()
	for k in range(rng.randi_range(2, 3)):
		var r := rng.randf_range(0.8, 1.3) * (1.0 - k * 0.25)
		var c := Vector3(rng.randf_range(-0.3, 0.3), 0.25 + k * 0.28, rng.randf_range(-0.3, 0.3))
		_tier(mb, needles, c, r, 0.35, 0.25, 6, rng.randf_range(0.5, 0.9), rng, 0.85 + k * 0.08)
	return mb.commit()


static func frost_grass() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.add_cross_cards(PSXMat.cutout("frost_grass", Color.WHITE, 0.08, 0.7), Transform3D.IDENTITY, 0.8, 0.6, 2)
	return mb.commit()


## A drift: a low wind-carved bank of snow, steep on its lee side, frosted grass poking through.
static func drift(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var L := rng.randf_range(2.2, 3.6)
	mb.add_blob(_snow(), Transform3D(Basis(Vector3.UP, rng.randf() * 0.4), Vector3(0, -0.05, 0)), Vector3(L, rng.randf_range(0.45, 0.75), L * 0.4), rng, 0.15, 3, 8, 0.5, Color.WHITE, 0.0)
	var grass := PSXMat.cutout("frost_grass", Color.WHITE, 0.08, 0.7)
	for k in range(rng.randi_range(1, 3)):
		mb.add_cross_cards(grass, Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3(rng.randf_range(-L, L) * 0.7, 0.1, rng.randf_range(0.3, 0.7) * L * 0.4)), 0.7, 0.5, 2)
	return mb.commit()


## A black rock with snow lying on its top.
static func snow_rock(seed_value: int, radius := 1.0) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var radii := Vector3(radius * rng.randf_range(0.9, 1.3), radius * rng.randf_range(0.6, 0.95), radius * rng.randf_range(0.8, 1.2))
	mb.add_blob(PSXMat.lit("black_rock", Color.WHITE, {"affine": 0.6}), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, radii.y * 0.45, 0)), radii, rng, 0.24, 4, 7, 0.5, Color.WHITE, -0.5)
	mb.add_blob(_snow(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, radii.y * 1.12, 0)), Vector3(radii.x * 0.78, radii.y * 0.32, radii.z * 0.74), rng, 0.15, 3, 7, 0.5, Color.WHITE, 0.0)
	return mb.commit()


## A floe or a grounded chunk of sea ice at the waterline.
static func ice_floe(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var ice := PSXMat.lit("ice", Color(0.9, 0.97, 1.0), {"affine": 0.5})
	for k in range(rng.randi_range(1, 3)):
		var c := Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.0, 0.4), rng.randf_range(-1.2, 1.2))
		var s := rng.randf_range(0.9, 1.8)
		mb.add_blob(ice, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), c), Vector3(s, s * rng.randf_range(0.4, 0.8), s * 0.8), rng, 0.25, 3, 5, 0.4, Color.WHITE, -0.6)
	mb.add_blob(_snow(), Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(1.1, 0.22, 0.9), rng, 0.2, 2, 6, 0.5, Color.WHITE, 0.0)
	return mb.commit()


## A cluster of ice crystals, hexagonal and pointed, leaning out from a frozen root; they
## glow a cold blue (by day they read as pale ice, at night as lights on the slope).
static func crystal_cluster(seed_value: int, size := 1.0) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var ice := _crystal()
	for k in range(rng.randi_range(5, 9)):
		var a := rng.randf() * TAU
		var tilt := rng.randf_range(0.05, 0.6) if k > 0 else 0.05
		var L := (rng.randf_range(2.0, 3.6) if k == 0 else rng.randf_range(0.6, 2.2)) * size
		var r := L * rng.randf_range(0.14, 0.2)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, tilt)
		var foot := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.5) * size + Vector3.DOWN * 0.3
		var shaft := L * 0.78
		mb.add_cylinder(ice, Transform3D(b, foot), r, r * 0.92, shaft, 6, 0.8, Color.WHITE, false, false, false)
		mb.add_cylinder(ice, Transform3D(b, foot + b * Vector3.UP * shaft), r * 0.92, 0.0, L - shaft, 6, 0.8, Color(0.9, 0.95, 1.0), false, false, false)
	mb.add_blob(_snow(), Transform3D(Basis(), Vector3.UP * 0.02), Vector3(0.9, 0.3, 0.9) * size, rng, 0.2, 2, 6, 0.5, Color.WHITE, 0.0)
	return mb.commit()
