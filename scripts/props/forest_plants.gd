class_name ForestPlants
extends RefCounted
## The forest island's vegetation and rocks for GenIsland's MultiMeshes (ForestTheme.meshes): an
## autumn woodland. Broadleaf trees are a trunk forking into limbs under a crown of leaf blobs
## (maples scarlet and orange, oaks russet, beeches copper on smooth grey trunks, birches gold on
## white), firs dark tiers of needles over them; the big ones come as [body, detail, lean] like
## JunglePlants' giants (the body seen from the sea, the detail - root flares, bracket fungus, dead
## limbs, toadstools at the foot - only up close). Then the mid trees, shore pines and alders,
## autumn shrubs, bracken, dry grass, saplings, stumps and toadstools, leaf piles, cattails and
## mossy granite boulders. Origins on the ground.


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func leaves(tex: String) -> Material:
	return PSXMat.lit(tex, Color.WHITE, {"affine": 0.5})


static func bark(kind := "bark") -> Material:
	match kind:
		"birch":
			return PSXMat.lit("birch_bark", Color.WHITE)
		"beech":
			return PSXMat.lit("beech_bark", Color.WHITE)
	return PSXMat.lit("bark", Color(0.78, 0.7, 0.62))


static func _needles() -> Material:
	return PSXMat.lit("fir_needles", Color.WHITE, {"affine": 0.5})


static func _seg(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, uv := 0.6) -> void:
	var d := b - a
	mb.add_cylinder(mat, Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), a), r0, r1, d.length() + 0.05, sides, uv, Color.WHITE, false)


static func _lean(rng: RandomNumberGenerator, k: float) -> Vector3:
	return Vector3(rng.randf_range(-k, k), 0, rng.randf_range(-k, k))


## A broadleaf tree into `mb`: a trunk `h` tall to its fork (at `fork` of h), `limbs` limbs out and up into a
## crown of leaf blobs `cr` wide and `ch` deep round its middle near the top. `mats` [[material, weight]...]
## the leaf textures by share. Returns the crown's middle.
static func _broadleaf(mb: MeshBuilder, rng: RandomNumberGenerator, h: float, trunk_r: float, fork: float, limbs: int, cr: float, ch: float,
		lean: Vector3, bark_m: Material, mats: Array, blobs: int, blob_r: Array) -> Vector3:
	var fy := h * fork
	var top := lean + Vector3.UP * fy
	mb.add_tube(bark_m, PackedVector3Array([Vector3.DOWN * 0.3, lean * 0.15 + Vector3.UP * fy * 0.35, lean * 0.55 + Vector3.UP * fy * 0.75, top]), trunk_r, trunk_r * 0.7, 7, 0.6)
	var cc := lean * 1.2 + Vector3.UP * (h - ch * 0.5)
	var ends: Array = []
	var a0 := rng.randf() * TAU
	for k in range(limbs):
		var a := a0 + TAU * k / limbs + rng.randf_range(-0.35, 0.35)
		var out := Vector3(cos(a), 0, sin(a))
		var e := cc + out * cr * rng.randf_range(0.45, 0.7) + Vector3.UP * rng.randf_range(-ch * 0.25, ch * 0.2)
		var mid := top.lerp(e, 0.5) + Vector3.UP * rng.randf_range(0.2, 0.9)
		mb.add_tube(bark_m, PackedVector3Array([top - Vector3.UP * 0.3, mid, e]), trunk_r * 0.55, trunk_r * 0.18, 5, 0.8)
		ends.append(e)
	var total := 0.0
	for m in mats:
		total += float(m[1])
	var pick := func() -> Material:
		var roll := rng.randf() * total
		for m in mats:
			roll -= float(m[1])
			if roll <= 0.0:
				return m[0]
		return mats[0][0]
	# a blob on each limb's end, then filler through the crown's ellipsoid, the top lightest, underneath in shade
	var pts: Array = ends.duplicate()
	for k in range(blobs - ends.size()):
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1.0), rng.randf_range(-1, 1))
		if d.length() > 1.0:
			d = d.normalized() * rng.randf_range(0.5, 1.0)
		pts.append(cc + Vector3(d.x * cr * 0.7, d.y * ch * 0.45, d.z * cr * 0.7))
	pts.append(cc + Vector3.UP * ch * 0.35)
	for q in pts:
		var r := rng.randf_range(blob_r[0], blob_r[1])
		var up := clampf(((q as Vector3).y - (cc.y - ch * 0.5)) / ch, 0.0, 1.0)
		var shade := lerpf(0.62, 1.0, up) * rng.randf_range(0.92, 1.05)
		mb.add_blob(pick.call(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q), Vector3(r, r * rng.randf_range(0.65, 0.85), r), rng, 0.22, 3, 6, 0.5,
			Color(shade, shade, shade))
	return cc


## The foot of a big broadleaf: root flares across the ground, bracket fungus on the trunk, a dead limb, toadstools.
static func _foot(rng: RandomNumberGenerator, trunk_r: float, bark_m: Material, lean: Vector3, h: float, fungus := true) -> MeshBuilder:
	var mb := MeshBuilder.new()
	var n := rng.randi_range(4, 6)
	for k in range(n):
		var a := TAU * k / n + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		mb.add_tube(bark_m, PackedVector3Array([d * trunk_r * 0.5 + Vector3.UP * 0.9, d * (trunk_r + 0.5) + Vector3.UP * 0.15, d * (trunk_r + rng.randf_range(1.0, 1.8)) + Vector3.DOWN * 0.15]),
			trunk_r * 0.45, 0.06, 5, 0.8)
	if fungus:
		var cap := PSXMat.flat(Color(0.82, 0.66, 0.42))
		for k in range(rng.randi_range(2, 4)):
			var a := rng.randf() * TAU
			var y := rng.randf_range(0.6, 2.4)
			var at := lean * pow(y / h, 2.0) + Vector3(cos(a) * trunk_r * 0.95, y, sin(a) * trunk_r * 0.95)
			mb.add_cylinder(cap, Transform3D(Basis(Vector3.UP, -a), at), rng.randf_range(0.18, 0.32), rng.randf_range(0.12, 0.2), 0.08, 6, 1.0, Color.WHITE.darkened(rng.randf() * 0.2))
		_toadstools(mb, rng, Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU)) * (trunk_r + 0.9), rng.randi_range(2, 4))
	var y := rng.randf_range(2.2, h * 0.35)
	var a := rng.randf() * TAU
	var at := lean * pow(y / h, 2.0) + Vector3.UP * y
	_seg(mb, bark_m, at, at + Vector3(cos(a), rng.randf_range(0.1, 0.5), sin(a)) * rng.randf_range(1.2, 2.2), 0.09, 0.02, 4)
	return mb


## Toadstools at `c`: red caps flecked white (fly agaric) or brown, on pale stems.
static func _toadstools(mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector3, n: int, red := -1.0) -> void:
	var stem := PSXMat.flat(Color(0.9, 0.86, 0.76))
	var is_red := rng.randf() < 0.6 if red < 0.0 else red > 0.5
	var cap := PSXMat.flat(Color(0.78, 0.12, 0.08) if is_red else Color(0.55, 0.36, 0.2))
	var fleck := PSXMat.flat(Color(0.96, 0.94, 0.88))
	for k in range(n):
		var p := c + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
		var s := rng.randf_range(0.6, 1.3)
		mb.add_cylinder(stem, Transform3D(Basis(), p - Vector3.UP * 0.05), 0.04 * s, 0.035 * s, 0.22 * s, 5, 1.0, Color.WHITE, false)
		mb.add_cylinder(cap, Transform3D(Basis(), p + Vector3.UP * 0.18 * s), 0.14 * s, 0.03 * s, 0.1 * s, 6, 1.0)
		if is_red:
			mb.add_box(fleck, Transform3D(Basis(), p + Vector3(0.03, 0.26, 0.02) * s), Vector3(0.04, 0.02, 0.04) * s)


## A maple (12-17 m): a forked trunk, a dense round crown in scarlet with orange through it (`gold`: a gold maple instead).
static func maple(seed_value: int, gold := false) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(12.0, 17.0)
	var lean := _lean(rng, 0.6)
	var mats := [[leaves("leaves_maple"), 0.75], [leaves("leaves_beech"), 0.25]] if not gold else [[leaves("leaves_birch"), 0.6], [leaves("leaves_beech"), 0.4]]
	_broadleaf(body, rng, h, 0.5, 0.42, rng.randi_range(4, 5), rng.randf_range(5.0, 6.2), rng.randf_range(6.0, 7.5), lean, bark(), mats, 12, [2.0, 3.0])
	return [body.commit(), _foot(rng, 0.5, bark(), lean, h).commit(), lean]


## An oak (11-15 m): a thick short trunk, heavy limbs reaching out sideways under a broad flat-bottomed russet crown.
static func oak(seed_value: int, ancient := false) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var k := 1.35 if ancient else 1.0
	var h := rng.randf_range(11.0, 15.0) * (1.15 if ancient else 1.0)
	var lean := _lean(rng, 0.5)
	var mats := [[leaves("leaves_oak"), 0.8], [leaves("leaves_late"), 0.2]]
	_broadleaf(body, rng, h, 0.85 * k, 0.32, rng.randi_range(5, 6), rng.randf_range(7.0, 8.2) * k, rng.randf_range(5.0, 6.0), lean, bark(), mats, 14, [2.2, 3.2])
	var foot := _foot(rng, 0.85 * k, bark(), lean, h)
	if ancient:
		# a hollow at its foot and moss up one side
		foot.add_blob(PSXMat.flat(Color(0.08, 0.06, 0.05)), Transform3D(Basis(), Vector3(0, 0.7, 0.9 * k)), Vector3(0.45, 0.7, 0.2), rng, 0.1, 3, 6)
		foot.add_blob(PSXMat.lit("leaves_late", Color(0.7, 0.85, 0.6)), Transform3D(Basis(), Vector3(-0.6, 1.6, 0.0)), Vector3(0.35, 1.5, 0.6) * k, rng, 0.2, 3, 6)
	return [body.commit(), foot.commit(), lean]


## A beech (18-24 m): a tall smooth grey trunk, its copper crown high and wide over the rest.
static func beech(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(18.0, 24.0)
	var lean := _lean(rng, 0.5)
	var mats := [[leaves("leaves_beech"), 0.85], [leaves("leaves_birch"), 0.15]]
	_broadleaf(body, rng, h, 0.62, 0.55, rng.randi_range(4, 5), rng.randf_range(6.0, 7.2), rng.randf_range(7.0, 8.5), lean, bark("beech"), mats, 13, [2.2, 3.1])
	return [body.commit(), _foot(rng, 0.62, bark("beech"), lean, h, false).commit(), lean]


## One tier of fir boughs: a star of 2n points round `c` drooping at the tips, up to its top at c + rise, a flat underside.
static func _tier(mb: MeshBuilder, mat: Material, c: Vector3, r: float, rise: float, droop: float, n: int, rng: RandomNumberGenerator, shade := 1.0) -> void:
	var apex := c + Vector3.UP * rise
	var under := c + Vector3.UP * rise * 0.3
	var rim: Array = []
	var off := rng.randf() * TAU
	for k in range(n * 2):
		var a := off + PI * k / n + rng.randf_range(-0.08, 0.08)
		var tip := k % 2 == 0
		var rr := r * (rng.randf_range(0.88, 1.08) if tip else rng.randf_range(0.58, 0.72))
		rim.append(c + Vector3(cos(a) * rr, -droop * (1.0 if tip else 0.3) * rng.randf_range(0.8, 1.2), sin(a) * rr))
	var circ := maxf(1.0, roundf(TAU * r * 0.3))
	var top_col := Color(shade, shade, shade)
	var under_col := Color(0.5, 0.52, 0.5) * shade
	under_col.a = 1.0
	for k in range(rim.size()):
		var a: Vector3 = rim[k]
		var b: Vector3 = rim[(k + 1) % rim.size()]
		var u0 := float(k) / rim.size() * circ
		var u1 := float(k + 1) / rim.size() * circ
		var nt := (b - a).cross(apex - a).normalized()
		if nt.y < 0.0:
			nt = -nt
		mb.add_tri(mat, apex, a, b, nt, nt, nt, Vector2((u0 + u1) * 0.5, 0.0), Vector2(u0, 1.0), Vector2(u1, 1.0), top_col, nt)
		var nu := (b - a).cross(under - a).normalized()
		if nu.y > 0.0:
			nu = -nu
		mb.add_tri(mat, under, a, b, nu, nu, nu, Vector2((u0 + u1) * 0.5, 0.97), Vector2(u0, 0.99), Vector2(u1, 0.99), under_col, nu)


## A conifer into `mb`: `h` tall, its lowest tier `base_r` wide, the trunk bare for `bare` of its height.
static func _conifer(mb: MeshBuilder, rng: RandomNumberGenerator, h: float, base_r: float, bare: float, tiers: int, droop_k: float, lean: Vector3, trunk_r: float, bark_m: Material) -> void:
	var needles := _needles()
	var top := lean + Vector3.UP * h
	_seg(mb, bark_m, Vector3.DOWN * 0.3, lean * 0.5 + Vector3.UP * h * 0.5, trunk_r, trunk_r * 0.62, 6)
	_seg(mb, bark_m, lean * 0.5 + Vector3.UP * h * 0.5, top - Vector3.UP * 0.6, trunk_r * 0.62, trunk_r * 0.2, 5)
	var span := h * (1.0 - bare)
	for i in range(tiers):
		var t := float(i) / tiers
		var y := h * bare + span * t
		var r := base_r * pow(1.0 - t, 0.9) * rng.randf_range(0.9, 1.08) + 0.35
		var c := lean * pow(y / h, 2.0) + Vector3.UP * y
		_tier(mb, needles, c, r, maxf(span / tiers * 1.7, r * 0.5), r * 0.2 * droop_k, clampi(int(r * 2.0) + 5, 5, 11), rng, lerpf(0.7, 1.0, t))
	mb.add_cone(needles, Transform3D(Basis(), top - Vector3.UP * minf(0.4, h * 0.06)), minf(0.45, h * 0.08), minf(1.6, h * 0.25), 5, 0.6, Color.WHITE)


## A fir (20-28 m) over the broadleaves: a dark spire of drooping tiers, a bare trunk under them.
static func fir(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(20.0, 28.0)
	var lean := _lean(rng, 0.35)
	_conifer(body, rng, h, rng.randf_range(4.0, 4.8), 0.22, rng.randi_range(11, 13), 1.2, lean, 0.55, bark())
	var foot := MeshBuilder.new()
	_toadstools(foot, rng, Vector3(1.2, 0, 0.4), rng.randi_range(2, 3), 0.0)
	var b := bark()
	for k in range(rng.randi_range(3, 5)):
		var y := rng.randf_range(1.8, h * 0.2)
		var a := rng.randf() * TAU
		var at := lean * pow(y / h, 2.0) + Vector3.UP * y
		_seg(foot, b, at, at + Vector3(cos(a), rng.randf_range(-0.2, 0.3), sin(a)) * rng.randf_range(0.6, 1.4), 0.07, 0.02, 4)
	return [body.commit(), foot.commit(), lean]


## Crown pieces with no trunk of their own, closing the roof over a fight's clearing (red and gold).
static func crown_roof(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(12.5, 15.5)
	var mats := [leaves("leaves_maple"), leaves("leaves_beech"), leaves("leaves_oak")]
	for k in range(rng.randi_range(5, 7)):
		var a := rng.randf() * TAU
		var c := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 4.5) + Vector3.UP * (h + rng.randf_range(-1.2, 1.4))
		var r := rng.randf_range(2.4, 3.4)
		var s := rng.randf_range(0.7, 1.0)
		body.add_blob(mats[rng.randi() % mats.size()], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c), Vector3(r, r * 0.7, r), rng, 0.22, 3, 6, 0.5, Color(s, s, s))
	var detail := MeshBuilder.new()
	var b := bark()
	for k in range(rng.randi_range(2, 4)):
		var a := rng.randf() * TAU
		var at := Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.0, 4.0) + Vector3.UP * (h - 1.0)
		_seg(detail, b, at, at + Vector3(cos(a + 1.0), -0.3, sin(a + 1.0)) * rng.randf_range(1.5, 3.0), 0.12, 0.04, 4)
	return [body.commit(), detail.commit(), Vector3.ZERO]


## A birch (8-12 m): one to three slender white stems, a light airy gold crown.
static func birch(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var stems := rng.randi_range(1, 3)
	var bm := bark("birch")
	var gold := leaves("leaves_birch")
	for s in range(stems):
		var a := rng.randf() * TAU
		var foot := Vector3(cos(a), 0, sin(a)) * (0.25 if stems > 1 else 0.0)
		var h := rng.randf_range(8.0, 12.0) * (1.0 - s * 0.12)
		var lean := foot * 2.0 + _lean(rng, 0.5)
		var top := foot + lean + Vector3.UP * h
		mb.add_tube(bm, PackedVector3Array([foot + Vector3.DOWN * 0.3, foot + lean * 0.3 + Vector3.UP * h * 0.4, foot + lean * 0.75 + Vector3.UP * h * 0.75, top]), 0.2, 0.07, 6, 0.8)
		for k in range(rng.randi_range(5, 7)):
			var t := rng.randf_range(0.45, 1.0)
			var c := foot + lean * t + Vector3.UP * h * t + Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(-0.4, 0.8), rng.randf_range(-1.4, 1.4)) * t
			var r := rng.randf_range(1.0, 1.6) * (1.2 - t * 0.4)
			var sh := lerpf(0.7, 1.05, t)
			mb.add_blob(gold, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c), Vector3(r, r * 0.8, r), rng, 0.25, 3, 5, 0.5, Color(sh, sh, sh))
	return mb.commit()


## A young maple (6-9 m) for the mid layer: a slim trunk, a small round crown, red or gold.
static func young_maple(seed_value: int, gold := false) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var h := rng.randf_range(6.0, 9.0)
	var mats := [[leaves("leaves_birch" if gold else "leaves_maple"), 1.0]]
	_broadleaf(mb, rng, h, 0.2, 0.45, 3, rng.randf_range(2.4, 3.0), rng.randf_range(3.0, 3.8), _lean(rng, 0.3), bark(), mats, 6, [1.2, 1.7])
	return mb.commit()


## A young fir (5-9 m) among the broadleaves.
static func young_fir(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	_conifer(mb, rng, rng.randf_range(5.0, 9.0), rng.randf_range(1.8, 2.4), rng.randf_range(0.06, 0.15), rng.randi_range(6, 8), 1.3, _lean(rng, 0.2), 0.2, bark())
	return mb.commit()


## A dead snag: a grey crooked trunk, bare limbs, a bracket fungus.
static func snag(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var b := PSXMat.lit("bark", Color(0.66, 0.64, 0.62))
	var h := rng.randf_range(5.0, 9.0)
	var pts := PackedVector3Array()
	var p := Vector3.DOWN * 0.3
	for i in range(5):
		pts.append(p)
		p += Vector3(rng.randf_range(-0.4, 0.4), h / 4.0, rng.randf_range(-0.4, 0.4))
	mb.add_tube(b, pts, 0.3, 0.07, 5, 0.6)
	for k in range(rng.randi_range(3, 5)):
		var from: Vector3 = pts[rng.randi_range(2, 3)]
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), rng.randf_range(0.4, 1.0), sin(a)).normalized()
		var L := rng.randf_range(1.2, 2.6)
		mb.add_tube(b, PackedVector3Array([from, from + dir * L * 0.55 + Vector3(rng.randf_range(-0.3, 0.3), 0, 0), from + dir * L]), 0.1, 0.02, 4, 1.0)
	mb.add_cylinder(PSXMat.flat(Color(0.8, 0.62, 0.38)), Transform3D(Basis(), pts[1] + Vector3(0.28, 0, 0)), 0.3, 0.2, 0.08, 6, 1.0)
	return mb.commit()


## A shore pine (5-8 m): a bent trunk, orange high up, flat-topped tiers swept off the sea.
static func shore_pine(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var needles := _needles()
	var h := rng.randf_range(5.0, 8.0)
	var lean := Vector3(rng.randf_range(0.8, 1.4), 0, rng.randf_range(-0.4, 0.4))
	var pts := PackedVector3Array()
	for i in range(5):
		var t := i / 4.0
		pts.append(lean * pow(t, 1.6) + Vector3.UP * (h * t - 0.3 * (1.0 - t)))
	mb.add_tube(PSXMat.lit("bark", Color(0.95, 0.62, 0.4)), pts, 0.2, 0.07, 5, 0.6)
	for i in range(rng.randi_range(3, 4)):
		var t := 0.6 + i * 0.12
		var c := lean * pow(t, 1.6) + Vector3.UP * h * t + lean.normalized() * 0.4
		var r := rng.randf_range(1.2, 1.9) * (1.15 - t * 0.5)
		_tier(mb, needles, c, r, r * 0.3, r * 0.15, 6, rng, lerpf(0.75, 1.0, t))
	return mb.commit()


## An alder at the shore (5-7 m): several thin stems, a loose olive-gold crown.
static func alder(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var b := bark()
	var mats := [leaves("leaves_late"), leaves("leaves_birch")]
	for s in range(rng.randi_range(2, 3)):
		var a := rng.randf() * TAU
		var foot := Vector3(cos(a), 0, sin(a)) * 0.3
		var h := rng.randf_range(5.0, 7.0)
		var top := foot * 3.0 + Vector3.UP * h
		mb.add_tube(b, PackedVector3Array([foot + Vector3.DOWN * 0.3, foot * 2.0 + Vector3.UP * h * 0.5, top]), 0.14, 0.05, 5, 0.8)
		for k in range(3):
			var r := rng.randf_range(1.0, 1.5)
			var c := top + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.4, 0.2), rng.randf_range(-1.0, 1.0))
			mb.add_blob(mats[rng.randi() % 2], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c), Vector3(r, r * 0.8, r), rng, 0.25, 3, 5, 0.5)
	return mb.commit()


## An autumn shrub (hazel, bramble): crossed cards turning red at the top, a dark mound under them.
static func shrub_card(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := rng.randf_range(1.2, 1.8)
	mb.add_cross_cards(PSXMat.cutout("autumn_bush", Color.WHITE, 0.04, 1.4), Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), s * 1.2, s, 3)
	return mb.commit()


## A low leafy bush: a few blobs of red or gold leaves.
static func leaf_bush(seed_value: int, tex := "leaves_maple") -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := leaves(tex)
	for k in range(rng.randi_range(2, 4)):
		var r := rng.randf_range(0.55, 0.9)
		var c := Vector3(rng.randf_range(-0.5, 0.5), r * 0.55, rng.randf_range(-0.5, 0.5))
		var sh := rng.randf_range(0.75, 1.0)
		mb.add_blob(m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c), Vector3(r, r * 0.75, r), rng, 0.25, 3, 5, 0.5, Color(sh, sh, sh), -0.3)
	return mb.commit()


## Bracken: crossed cards of rust and orange fronds.
static func bracken(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := rng.randf_range(0.9, 1.3)
	mb.add_cross_cards(PSXMat.cutout("bracken", Color.WHITE, 0.06, 1.0), Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), 1.5 * s, 1.0 * s, 2)
	return mb.commit()


static func dry_grass() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.add_cross_cards(PSXMat.cutout("autumn_grass", Color.WHITE, 0.08, 0.7), Transform3D.IDENTITY, 0.8, 0.65, 2)
	return mb.commit()


## A sapling (2-3.5 m) for the understory: a whip of a stem, a few leaf blobs (red, gold or still green).
static func sapling(seed_value: int, tex := "leaves_maple") -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var h := rng.randf_range(2.0, 3.5)
	var lean := _lean(rng, 0.3)
	mb.add_tube(bark(), PackedVector3Array([Vector3.DOWN * 0.2, lean * 0.4 + Vector3.UP * h * 0.5, lean + Vector3.UP * h]), 0.06, 0.03, 4, 1.0)
	var m := leaves(tex)
	for k in range(rng.randi_range(3, 4)):
		var t := rng.randf_range(0.55, 1.0)
		var r := rng.randf_range(0.45, 0.7)
		mb.add_blob(m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), lean * t + Vector3.UP * h * t + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))), Vector3(r, r * 0.8, r), rng, 0.25, 3, 5, 0.5)
	return mb.commit()


## A stump (some cut, some broken), moss on top, bracket fungus, maybe toadstools round it.
static func stump(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var r := rng.randf_range(0.35, 0.6)
	var h := rng.randf_range(0.4, 1.0)
	var cut := rng.randf() < 0.6
	mb.add_cylinder(bark(), Transform3D(Basis(), Vector3.DOWN * 0.2), r * 1.15, r, h + 0.2, 7, 0.8, Color.WHITE, false)
	if cut:
		mb.add_cylinder(PSXMat.flat(Color(0.72, 0.56, 0.36)), Transform3D(Basis(), Vector3.UP * h), r, r, 0.02, 7, 1.0)
	else:
		for k in range(4):
			var a := TAU * k / 4.0 + rng.randf() * 0.5
			mb.add_cone(bark(), Transform3D(Basis(), Vector3(cos(a), 0, sin(a)) * r * 0.5 + Vector3.UP * h), r * 0.45, rng.randf_range(0.3, 0.7), 4)
	mb.add_blob(PSXMat.lit("leaves_late", Color(0.7, 0.85, 0.6)), Transform3D(Basis(), Vector3(r * 0.6, h * 0.6, 0)), Vector3(0.15, h * 0.5, r * 0.6), rng, 0.2, 2, 5)
	if rng.randf() < 0.6:
		_toadstools(mb, rng, Vector3(r + 0.3, 0, 0.2), rng.randi_range(2, 4))
	return mb.commit()


## A cluster of toadstools in the leaf litter.
static func toadstool_ring(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	_toadstools(mb, rng, Vector3.ZERO, rng.randi_range(4, 7))
	return mb.commit()


## A fallen log lying in the litter, its bark half off, moss along its top, fungus on its side.
static func fallen_log(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var L := rng.randf_range(2.5, 4.5)
	var r := rng.randf_range(0.25, 0.4)
	var bend := rng.randf_range(-0.3, 0.3)
	var pts := PackedVector3Array([Vector3(-L * 0.5, r * 0.7, 0), Vector3(0, r * 0.8, bend), Vector3(L * 0.5, r * 0.6, 0)])
	mb.add_tube(bark(), pts, r, r * 0.8, 6, 0.8, Color.WHITE, true, true)
	mb.add_tube(PSXMat.lit("leaves_late", Color(0.62, 0.8, 0.5)), PackedVector3Array([pts[0] + Vector3.UP * r * 0.85, pts[1] + Vector3.UP * r * 0.9, pts[2] + Vector3.UP * r * 0.7]), r * 0.4, r * 0.3, 4, 1.0)
	mb.add_cylinder(PSXMat.flat(Color(0.82, 0.66, 0.42)), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(rng.randf_range(-L * 0.3, L * 0.3), r * 0.7, r * 0.95)), 0.2, 0.14, 0.06, 6, 1.0)
	return mb.commit()


## A heap of fallen leaves (red, orange, gold), low and soft.
static func leaf_pile(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var mats := [leaves("leaves_maple"), leaves("leaves_beech"), leaves("leaves_birch")]
	for k in range(rng.randi_range(2, 3)):
		var r := rng.randf_range(0.5, 0.9)
		mb.add_blob(mats[rng.randi() % 3], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.5, 0.5), 0.02, rng.randf_range(-0.5, 0.5))), Vector3(r, r * 0.3, r * 0.8), rng, 0.2, 2, 6, 0.5, Color.WHITE, 0.0)
	return mb.commit()


## Cattails and reeds at the waterline, brown heads on them.
static func cattails(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := PSXMat.cutout("reeds", Color(1.0, 0.92, 0.75), 0.15, 2.0)
	var s := rng.randf_range(1.4, 2.0)
	for k in range(2):
		var a := rng.randf() * TAU
		mb.add_cross_cards(m, Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3(cos(a), 0, sin(a)) * 0.5 * k), s * 0.6, s, 2)
	var head := PSXMat.flat(Color(0.36, 0.22, 0.12))
	for k in range(rng.randi_range(3, 5)):
		var p := Vector3(rng.randf_range(-0.4, 0.4), s * rng.randf_range(0.75, 0.95), rng.randf_range(-0.4, 0.4))
		mb.add_cylinder(head, Transform3D(Basis(), p), 0.05, 0.05, 0.22, 4, 1.0)
	return mb.commit()


## A granite boulder, moss over its top, a few leaves caught on it.
static func boulder(seed_value: int, radius := 1.0) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var radii := Vector3(radius * rng.randf_range(0.9, 1.3), radius * rng.randf_range(0.6, 0.95), radius * rng.randf_range(0.8, 1.2))
	mb.add_blob(PSXMat.lit("forest_rock", Color.WHITE, {"affine": 0.6}), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, radii.y * 0.45, 0)), radii, rng, 0.22, 4, 7, 0.5, Color.WHITE, -0.5)
	mb.add_blob(PSXMat.lit("leaves_late", Color(0.7, 0.85, 0.55), {"affine": 0.5}), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(radii.x * 0.15, radii.y * 1.05, 0)),
		Vector3(radii.x * 0.6, radii.y * 0.25, radii.z * 0.55), rng, 0.2, 2, 6, 0.5, Color.WHITE, 0.0)
	return mb.commit()
