class_name VolcanicPlants
extends RefCounted
## The volcanic isle's plants and rocks for GenIsland's MultiMeshes (VolcanicTheme.meshes): sparse and hardy.
## Charred trees burned black with an ember still glowing in a split, ash-dusted pines, scorched giants (few: the
## island has no canopy worth the name), wiry ash grass and fire lilies, grey ash shrubs, sulphur-crusted fumaroles,
## basalt and obsidian. Big trees come as [body, detail, lean]. Origins on the ground.


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func char_bark() -> Material:
	return PSXMat.lit("bark", Color(0.22, 0.2, 0.2))


static func _ember() -> Material:
	return PSXMat.glow(Color(1.0, 0.42, 0.1), 2.4)


static func _needles() -> Material:
	return PSXMat.lit("fir_needles", Color(0.62, 0.64, 0.56))


static func basalt() -> Material:
	return PSXMat.lit("volcanic_basalt", Color.WHITE, {"affine": 0.6})


static func obsidian() -> Material:
	return PSXMat.lit("metal", Color(0.14, 0.1, 0.18))


static func _lean(rng: RandomNumberGenerator, k: float) -> Vector3:
	return Vector3(rng.randf_range(-k, k), 0, rng.randf_range(-k, k))


## A charred tree (4-8 m): a black trunk split and twisted by the fire, a few stubby broken limbs, sometimes an ember
## still glowing in a crack.
static func charred_tree(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var b := char_bark()
	var h := rng.randf_range(4.0, 8.0)
	var pts := PackedVector3Array()
	var p := Vector3.DOWN * 0.3
	for i in range(5):
		pts.append(p)
		p += Vector3(rng.randf_range(-0.4, 0.4), h / 4.0, rng.randf_range(-0.4, 0.4))
	mb.add_tube(b, pts, 0.3, 0.05, 5, 0.6)
	for k in range(rng.randi_range(2, 4)):
		var a := rng.randf() * TAU
		var from: Vector3 = pts[rng.randi_range(1, 3)]
		var to := from + Vector3(cos(a), rng.randf_range(0.2, 0.9), sin(a)) * rng.randf_range(0.8, 2.0)
		mb.add_tube(b, PackedVector3Array([from, from.lerp(to, 0.5) + Vector3.UP * 0.2, to]), 0.11, 0.03, 4, 1.0)
	if rng.randf() < 0.45:
		var y := rng.randf_range(0.6, 1.6)
		var a := rng.randf() * TAU
		mb.add_box(_ember(), Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * 0.22 + Vector3.UP * y), Vector3(0.08, 0.5, 0.1))
	return mb.commit()


## An ash pine (5-9 m): a scrubby conifer dusted grey, thin tiers, a bare lower trunk; `bent` leans it off the sea wind.
static func ash_pine(seed_value: int, bent := false) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var h := rng.randf_range(5.0, 9.0)
	var lean := _lean(rng, 0.3) + (Vector3(1.4, 0, 0.3) if bent else Vector3.ZERO)
	var b := PSXMat.lit("bark", Color(0.42, 0.38, 0.36))
	var top := lean + Vector3.UP * h
	mb.add_tube(b, PackedVector3Array([Vector3.DOWN * 0.3, lean * 0.3 + Vector3.UP * h * 0.5, top]), 0.22, 0.05, 5, 0.6)
	var needles := _needles()
	var tiers := rng.randi_range(4, 6)
	for i in range(tiers):
		var t := float(i) / tiers
		var y := h * 0.35 + h * 0.6 * t
		var r := lerpf(1.8, 0.5, t) * rng.randf_range(0.85, 1.1)
		ForestPlants._tier(mb, needles, lean * pow(y / h, 2.0) + Vector3.UP * y, r, h * 0.6 / tiers * 1.6, r * 0.2, clampi(int(r * 2.0) + 4, 4, 8), rng, lerpf(0.7, 1.0, t))
	return mb.commit()


## A scorched giant (14-20 m): the dead hulk of a great tree, burned black, its crown snapped to a few heavy limbs; the
## detail is cinders and an ember-cracked hollow at its foot.
static func scorched_giant(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var b := char_bark()
	var h := rng.randf_range(14.0, 20.0)
	var r := rng.randf_range(0.9, 1.3)
	var lean := _lean(rng, 0.8)
	var pts := PackedVector3Array()
	for i in range(6):
		var t := float(i) / 5.0
		pts.append(lean * t * t + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)) * sin(t * PI) + Vector3.UP * (h * 0.75 * t - 0.3 * (1.0 - t)))
	body.add_tube(b, pts, r, r * 0.4, 7, 0.5)
	var top: Vector3 = pts[pts.size() - 1]
	for k in range(rng.randi_range(3, 5)):
		var a := rng.randf() * TAU
		var from: Vector3 = pts[rng.randi_range(3, 5)]
		var L := rng.randf_range(3.0, 6.0)
		var to := from + Vector3(cos(a), rng.randf_range(0.3, 1.0), sin(a)).normalized() * L
		body.add_tube(b, MeshBuilder.curve_points(from, from.lerp(to, 0.5) + Vector3.UP * 0.6, to, 4), r * 0.35, r * 0.1, 5, 0.6)
		if rng.randf() < 0.5:
			var a2 := a + rng.randf_range(-1.0, 1.0)
			body.add_tube(b, PackedVector3Array([to, to + Vector3(cos(a2), 0.5, sin(a2)) * L * 0.4]), r * 0.1, 0.03, 4, 1.0)
	body.add_cone(b, Transform3D(Basis(), top), r * 0.4, rng.randf_range(0.8, 1.6), 5)
	var foot := MeshBuilder.new()
	for k in range(rng.randi_range(4, 6)):
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		foot.add_tube(b, PackedVector3Array([d * r * 0.5 + Vector3.UP * 0.8, d * (r + 0.4) + Vector3.UP * 0.1, d * (r + rng.randf_range(0.8, 1.6)) + Vector3.DOWN * 0.2]), r * 0.4, 0.05, 5, 0.8)
	if rng.randf() < 0.6:
		foot.add_blob(_ember(), Transform3D(Basis(), Vector3(0, 0.7, r * 0.92)), Vector3(0.3, 0.5, 0.12), rng, 0.15, 3, 6)
	var ash := PSXMat.lit("volcanic_ash", Color(1.1, 1.1, 1.1), {"affine": 0.6})
	foot.add_blob(ash, Transform3D(Basis(), Vector3(0, 0.0, 0)), Vector3(r * 2.0, 0.3, r * 2.0), rng, 0.3, 2, 7)
	return [body.commit(), foot.commit(), lean]


## A great ash pine (16-22 m) for the low flanks' few stands: grey-dusted tiers on a tall bare trunk.
static func great_pine(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(16.0, 22.0)
	var lean := _lean(rng, 0.4)
	var b := PSXMat.lit("bark", Color(0.4, 0.36, 0.34))
	var top := lean + Vector3.UP * h
	body.add_tube(b, PackedVector3Array([Vector3.DOWN * 0.3, lean * 0.3 + Vector3.UP * h * 0.5, top]), 0.6, 0.12, 6, 0.6)
	var needles := _needles()
	var tiers := rng.randi_range(7, 9)
	for i in range(tiers):
		var t := float(i) / tiers
		var y := h * 0.4 + h * 0.56 * t
		var r := lerpf(3.4, 0.8, t) * rng.randf_range(0.85, 1.1)
		ForestPlants._tier(body, needles, lean * pow(y / h, 2.0) + Vector3.UP * y, r, h * 0.56 / tiers * 1.6, r * 0.2, clampi(int(r * 2.0) + 5, 5, 10), rng, lerpf(0.7, 1.0, t))
	var foot := MeshBuilder.new()
	for k in range(rng.randi_range(2, 4)):
		var y := rng.randf_range(1.5, h * 0.3)
		var a := rng.randf() * TAU
		var at := lean * pow(y / h, 2.0) + Vector3.UP * y
		foot.add_tube(b, PackedVector3Array([at, at + Vector3(cos(a), 0.1, sin(a)) * rng.randf_range(0.6, 1.2)]), 0.07, 0.02, 4, 1.0)
	return [body.commit(), foot.commit(), lean]


## Heavy burned limbs with no trunk of their own (a canopy arena's roof; the volcanic isle's arenas are open).
static func limb_roof(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var b := char_bark()
	var h := rng.randf_range(11.0, 14.0)
	for k in range(rng.randi_range(3, 4)):
		var a := rng.randf() * TAU
		var from := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 3.0) + Vector3.UP * h
		var to := from + Vector3(cos(a + 1.4), rng.randf_range(-0.1, 0.2), sin(a + 1.4)) * rng.randf_range(3.0, 4.5)
		body.add_tube(b, PackedVector3Array([from, from.lerp(to, 0.5) + Vector3.UP * 0.3, to]), 0.2, 0.05, 5, 0.6)
	return [body.commit(), MeshBuilder.new().commit(), Vector3.ZERO]


## Wiry ash grass.
static func grass() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.add_cross_cards(PSXMat.cutout("volcanic_grass", Color.WHITE, 0.06, 0.7), Transform3D.IDENTITY, 0.8, 0.6, 2)
	return mb.commit()


## A fire lily: dark spiky leaves and orange trumpets, the one colour in the ash.
static func fire_lily(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := rng.randf_range(0.8, 1.2)
	mb.add_cross_cards(PSXMat.cutout("volcanic_lily", Color.WHITE, 0.05, 1.0), Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), 1.1 * s, 0.9 * s, 2)
	return mb.commit()


## An ash shrub: grey thorny canes under a dusting of ash.
static func ash_shrub(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := rng.randf_range(0.8, 1.2)
	mb.add_cross_cards(PSXMat.cutout("thornbrush", Color(0.55, 0.53, 0.5), 0.04, 1.0), Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), 1.3 * s, 0.9 * s, 3)
	return mb.commit()


## A charred whip (2-4 m) for the understory: a burned sapling with a twig or two.
static func whip(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var b := char_bark()
	var h := rng.randf_range(2.0, 4.0)
	var lean := _lean(rng, 0.7)
	var top := lean + Vector3.UP * h
	mb.add_tube(b, PackedVector3Array([Vector3.DOWN * 0.2, lean * 0.4 + Vector3.UP * h * 0.5, top]), 0.07, 0.02, 4, 1.0)
	for k in range(rng.randi_range(1, 3)):
		var t := rng.randf_range(0.5, 0.9)
		var at := lean * t + Vector3.UP * h * t
		var a := rng.randf() * TAU
		mb.add_tube(b, PackedVector3Array([at, at + Vector3(cos(a), 0.6, sin(a)) * rng.randf_range(0.4, 0.9)]), 0.03, 0.01, 3, 1.0)
	return mb.commit()


## A basalt rock, faceted and dark, pale ash settled on its top.
static func basalt_rock(seed_value: int, radius := 1.0) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var radii := Vector3(radius * rng.randf_range(0.9, 1.3), radius * rng.randf_range(0.6, 1.0), radius * rng.randf_range(0.8, 1.2))
	mb.add_blob(basalt(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, radii.y * 0.45, 0)), radii, rng, 0.3, 3, 6, 0.5, Color.WHITE, -0.5)
	mb.add_blob(PSXMat.lit("volcanic_ash", Color(1.25, 1.25, 1.2), {"affine": 0.5}), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(radii.x * 0.1, radii.y * 0.98, 0)),
		Vector3(radii.x * 0.5, radii.y * 0.18, radii.z * 0.45), rng, 0.2, 2, 6, 0.5, Color.WHITE, 0.0)
	return mb.commit()


## An obsidian outcrop: black glass shards jutting from a basalt foot.
static func obsidian_rock(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	mb.add_blob(basalt(), Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(1.0, 0.5, 0.9), rng, 0.3, 3, 6, 0.5)
	var glass := obsidian()
	for k in range(rng.randi_range(3, 6)):
		var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.1, 0.6))
		mb.add_cylinder(glass, Transform3D(tilt, Vector3(rng.randf_range(-0.5, 0.5), 0.2, rng.randf_range(-0.5, 0.5))), rng.randf_range(0.15, 0.3), 0.0, rng.randf_range(0.7, 1.6), 4, 1.0)
	return mb.commit()


## A fumarole: a low mound crusted sulphur yellow round a dark vent, white mineral rings.
static func fumarole(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var r := rng.randf_range(0.7, 1.2)
	mb.add_blob(PSXMat.lit("volcanic_ash", Color(1.5, 1.3, 0.6), {"affine": 0.6}), Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(r * 1.4, 0.35, r * 1.3), rng, 0.25, 2, 8)
	mb.add_blob(PSXMat.flat(Color(0.92, 0.8, 0.25)), Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(r * 0.8, 0.22, r * 0.8), rng, 0.3, 2, 7)
	mb.add_cylinder(PSXMat.flat(Color(0.08, 0.07, 0.06)), Transform3D(Basis(), Vector3(0, 0.38, 0)), r * 0.28, r * 0.22, 0.12, 6)
	mb.add_cylinder(PSXMat.flat(Color(0.9, 0.88, 0.8)), Transform3D(Basis(), Vector3(0, 0.33, 0)), r * 0.42, r * 0.36, 0.06, 7)
	return mb.commit()


## Pumice and ash at the waterline: pale porous stones half in the black sand.
static func pumice(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := PSXMat.lit("volcanic_ash", Color(1.5, 1.45, 1.35), {"affine": 0.6})
	for k in range(rng.randi_range(2, 4)):
		var s := rng.randf_range(0.25, 0.6)
		mb.add_blob(m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.8, 0.8), s * 0.3, rng.randf_range(-0.8, 0.8))), Vector3(s, s * 0.7, s * 0.9), rng, 0.35, 2, 6)
	return mb.commit()


## A charred log lying in the ash, cinders along its top.
static func charred_log(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var L := rng.randf_range(2.5, 4.5)
	var r := rng.randf_range(0.25, 0.4)
	var bend := rng.randf_range(-0.3, 0.3)
	mb.add_tube(char_bark(), PackedVector3Array([Vector3(-L * 0.5, r * 0.7, 0), Vector3(0, r * 0.8, bend), Vector3(L * 0.5, r * 0.6, 0)]), r, r * 0.8, 6, 0.8, Color.WHITE, true, true)
	if rng.randf() < 0.4:
		mb.add_box(_ember(), Transform3D(Basis(Vector3.UP, 0.1), Vector3(rng.randf_range(-L * 0.3, L * 0.3), r * 1.4, bend * 0.5)), Vector3(0.5, 0.06, 0.12))
	return mb.commit()


## An ash drift: a low grey heap blown against nothing in particular.
static func ash_drift(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	mb.add_blob(PSXMat.lit("volcanic_ash", Color(1.2, 1.2, 1.18), {"affine": 0.6}), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, 0.05, 0)),
		Vector3(rng.randf_range(1.0, 1.8), rng.randf_range(0.2, 0.4), rng.randf_range(0.7, 1.2)), rng, 0.25, 2, 7)
	return mb.commit()
