class_name AtollPlants
extends RefCounted
## The coral atoll's plants and rocks for GenIsland's MultiMeshes (AtollTheme.meshes): coconut palms above all (tall
## and curving, leaning out over the water, nuts clustered under the crown), screw pines on their stilt roots, salt
## scrub, beach grass and spider lilies, sprouting coconuts, driftwood and coral rubble, worn coral boulders. Big trees
## come as [body, detail, lean]. Origins on the ground.


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func bark() -> Material:
	return PSXMat.lit("palm_bark", Color(1.0, 0.96, 0.9), {"affine": 0.6})


static func frond() -> Material:
	return PSXMat.cutout("palm_frond", Color(0.92, 1.05, 0.82), 0.25, 9.0)


static func coral() -> Material:
	return PSXMat.lit("atoll_coral", Color.WHITE, {"affine": 0.6})


## A palm's crown: `n` fronds arched out and drooping from `top`, sized by `s`; coconuts under it.
static func crown(mb: MeshBuilder, rng: RandomNumberGenerator, top: Vector3, s: float, n: int, nuts: int) -> void:
	var fm := frond()
	var nut := PSXMat.lit("palm_bark", Color(0.5, 0.42, 0.24))
	for k in range(nuts):
		var a := TAU * k / maxf(nuts, 1) + rng.randf()
		mb.add_blob(nut, Transform3D(Basis(), top + Vector3(cos(a) * 0.24 * s, -0.3 * s, sin(a) * 0.24 * s)), Vector3.ONE * 0.16 * s, rng, 0.1, 2, 5)
	for f in range(n):
		var a := TAU * f / n + rng.randf_range(-0.25, 0.25)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x)
		var w := rng.randf_range(0.7, 0.95) * s
		var p0 := top
		var p1 := top + out * rng.randf_range(1.7, 2.3) * s + Vector3.UP * rng.randf_range(0.2, 0.8) * s
		var p2 := p1 + out * rng.randf_range(1.9, 2.7) * s + Vector3.DOWN * rng.randf_range(1.2, 2.2) * s
		var col := Color.WHITE.darkened(rng.randf_range(0.0, 0.18))
		if rng.randf() < 0.12:
			col = Color(0.95, 0.82, 0.5)
		var n1 := (p1 - p0).cross(side).normalized()
		if n1.y < 0:
			n1 = -n1
		var n2 := (p2 - p1).cross(side).normalized()
		if n2.y < 0:
			n2 = -n2
		mb.add_quad(fm, p0 - side * w * 0.5, p0 + side * w * 0.5, p1 + side * w, p1 - side * w, Vector2(0, 0), Vector2(0, 1), Vector2(0.48, 1), Vector2(0.48, 0), col, n1)
		mb.add_quad(fm, p1 - side * w, p1 + side * w, p2 + side * w * 0.35, p2 - side * w * 0.35, Vector2(0.48, 0), Vector2(0.48, 1), Vector2(1, 1), Vector2(1, 0), col, n2)


## A palm's ringed trunk from the ground along a curve (`lean` the top's offset), tapering; its top.
static func trunk(mb: MeshBuilder, h: float, lean: Vector3, r0: float, r1: float, segs := 8) -> Vector3:
	var b := bark()
	var prev := Vector3.DOWN * 0.3
	for i in range(segs):
		var t1 := float(i + 1) / segs
		var p1 := lean * (t1 * t1) + Vector3.UP * h * t1
		var dir := (p1 - prev).normalized()
		mb.add_cylinder(b, Transform3D(Basis(Quaternion(Vector3.UP, dir)), prev), lerpf(r0, r1, float(i) / segs), lerpf(r0, r1, t1), prev.distance_to(p1) + 0.02, 5, 1.0,
			Color.WHITE.darkened(0.06 * (i % 2)), false, false, true)
		prev = p1
	return prev


## A coconut palm (7-12 m): a slim ringed trunk curving up, `bent` leaning hard out (over the water, off the wind).
static func coconut_palm(seed_value: int, bent := false) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var h := rng.randf_range(7.0, 12.0) * (0.85 if bent else 1.0)
	var lean := Vector3(rng.randf_range(2.6, 4.2) if bent else rng.randf_range(0.6, 1.8), 0, rng.randf_range(-0.6, 0.6))
	var top := trunk(mb, h, lean, 0.26, 0.16)
	crown(mb, rng, top, rng.randf_range(0.95, 1.1), rng.randi_range(8, 11), rng.randi_range(3, 6))
	return mb.commit()


## A great palm grove's tallest (14-19 m): the body a tall trunk and crown, the detail a skirt of dead fronds hanging
## under the crown and fallen nuts and husks round its foot.
static func tall_palm(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(14.0, 19.0)
	var lean := Vector3(rng.randf_range(1.0, 3.0), 0, rng.randf_range(-1.0, 1.0))
	var top := trunk(body, h, lean, 0.34, 0.2, 10)
	crown(body, rng, top, rng.randf_range(1.15, 1.35), rng.randi_range(10, 13), rng.randi_range(5, 8))
	var detail := MeshBuilder.new()
	var dead := PSXMat.cutout("palm_frond", Color(0.8, 0.66, 0.42), 0.25, 9.0)
	for k in range(rng.randi_range(4, 6)):
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x)
		var p0 := top + Vector3.DOWN * 0.3
		var p1 := p0 + out * 0.6 + Vector3.DOWN * rng.randf_range(2.0, 3.2)
		detail.add_quad(dead, p0 - side * 0.4, p0 + side * 0.4, p1 + side * 0.3, p1 - side * 0.3, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color.WHITE, out)
	var husk := PSXMat.lit("palm_bark", Color(0.62, 0.5, 0.3))
	for k in range(rng.randi_range(3, 6)):
		var q := Vector3(rng.randf_range(-1.6, 1.6), 0.1, rng.randf_range(-1.6, 1.6))
		detail.add_blob(husk, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q), Vector3(0.2, 0.15, 0.17), rng, 0.15, 2, 5)
	return [body.commit(), detail.commit(), lean]


## Palm crowns with no trunk of their own (a canopy arena's roof; the atoll's boss ground is open).
static func crown_roof(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	crown(body, rng, Vector3.UP * rng.randf_range(11.0, 13.0), 1.3, 12, 0)
	return [body.commit(), MeshBuilder.new().commit(), Vector3.ZERO]


## A screw pine (3-6 m): a trunk held up on a cone of stilt roots, branching into arms each ending in a spiky tuft of
## long strap leaves, a knobbly orange fruit hanging under one.
static func pandanus(seed_value: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	_pandanus(mb, _rng(seed_value), Vector3.ZERO, 1.0)
	return mb.commit()


static func _pandanus(mb: MeshBuilder, rng: RandomNumberGenerator, o: Vector3, sc: float) -> void:
	var b := PSXMat.lit("bark", Color(0.72, 0.64, 0.52))
	var leaf := PSXMat.cutout("palm_frond", Color(0.78, 0.95, 0.62), 0.25, 9.0)
	var h := rng.randf_range(3.0, 6.0) * sc
	var fork := o + Vector3(rng.randf_range(-0.4, 0.4), h * 0.55, rng.randf_range(-0.4, 0.4))
	for k in range(rng.randi_range(5, 7)):
		var a := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		mb.add_tube(b, PackedVector3Array([o.lerp(fork, 0.45), o + Vector3(cos(a) * 0.5, h * 0.12, sin(a) * 0.5), o + Vector3(cos(a) * 0.95, -0.2, sin(a) * 0.95)]), 0.06, 0.05, 4, 1.0)
	mb.add_tube(b, PackedVector3Array([o + Vector3.UP * h * 0.15, fork]), 0.16, 0.13, 5, 0.6)
	for k in range(rng.randi_range(2, 4)):
		var a := rng.randf() * TAU
		var tip := fork + Vector3(cos(a) * rng.randf_range(0.8, 1.6), rng.randf_range(0.8, 1.8), sin(a) * rng.randf_range(0.8, 1.6))
		mb.add_tube(b, PackedVector3Array([fork, fork.lerp(tip, 0.5) + Vector3.UP * 0.2, tip]), 0.1, 0.07, 4, 0.8)
		for j in range(9):
			var la := TAU * j / 9.0 + rng.randf_range(-0.2, 0.2)
			var out := Vector3(cos(la), 0, sin(la))
			var side := Vector3(-out.z, 0, out.x)
			var e := tip + out * rng.randf_range(1.0, 1.5) + Vector3.UP * rng.randf_range(-0.6, 0.5)
			mb.add_quad(leaf, tip - side * 0.12, tip + side * 0.12, e + side * 0.05, e - side * 0.05, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color.WHITE, Vector3.UP)
		if k == 0:
			mb.add_blob(PSXMat.lit("", Color(0.92, 0.5, 0.18)), Transform3D(Basis(), tip + Vector3.DOWN * 0.35), Vector3(0.22, 0.28, 0.22), rng, 0.3, 3, 6)


## A clump of screw pines for the "bamboo" slot: two or three together.
static func pandanus_clump(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	for k in range(rng.randi_range(2, 3)):
		_pandanus(mb, rng, Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4)), rng.randf_range(0.7, 1.0))
	return mb.commit()


## Salt scrub (beach naupaka): a low mound of fleshy pale-green leaves.
static func scrub(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := rng.randf_range(0.9, 1.3)
	mb.add_cross_cards(PSXMat.cutout("bush", Color(0.72, 0.95, 0.6), 0.2, 1.0), Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), 1.6 * s, 1.0 * s, 3)
	return mb.commit()


## Beach grass.
static func grass() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.add_cross_cards(PSXMat.cutout("atoll_grass", Color.WHITE, 0.06, 0.7), Transform3D.IDENTITY, 0.9, 0.6, 2)
	return mb.commit()


## A beach spider lily.
static func lily(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := rng.randf_range(0.8, 1.2)
	mb.add_cross_cards(PSXMat.cutout("atoll_lily", Color.WHITE, 0.05, 1.0), Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), 1.1 * s, 0.9 * s, 2)
	return mb.commit()


## A sprouting coconut (the "shrub" slot): a nut half in the sand with a young palm's first fronds standing out of it.
static func sprout(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	mb.add_blob(PSXMat.lit("palm_bark", Color(0.6, 0.48, 0.28)), Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(0.22, 0.18, 0.26), rng, 0.15, 2, 6)
	var fm := frond()
	var h := rng.randf_range(0.8, 1.8)
	for k in range(rng.randi_range(3, 5)):
		var a := TAU * k / 4.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x)
		var tip := out * h * 0.6 + Vector3.UP * h
		mb.add_quad(fm, Vector3.UP * 0.1 - side * 0.05, Vector3.UP * 0.1 + side * 0.05, tip + side * 0.35, tip - side * 0.35, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color.WHITE, out)
	return mb.commit()


## A worn coral boulder: pale pitted limestone, a pink crust on its top.
static func coral_rock(seed_value: int, radius := 1.0) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var radii := Vector3(radius * rng.randf_range(0.9, 1.4), radius * rng.randf_range(0.5, 0.9), radius * rng.randf_range(0.8, 1.2))
	mb.add_blob(coral(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, radii.y * 0.4, 0)), radii, rng, 0.32, 3, 7, 0.5, Color.WHITE, -0.5)
	return mb.commit()


## Coral rubble and shells washed up at the waterline (the "mangrove" slot: it goes where the sea reaches).
static func rubble(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var cm := coral()
	for k in range(rng.randi_range(4, 7)):
		var s := rng.randf_range(0.15, 0.4)
		mb.add_blob(cm, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-1.0, 1.0), s * 0.2, rng.randf_range(-1.0, 1.0))), Vector3(s * 1.4, s * 0.6, s),
			rng, 0.35, 2, 5, 0.5, Color.WHITE.lerp(Color(1.0, 0.75, 0.7), rng.randf() * 0.5))
	var shell := PSXMat.flat(Color(0.96, 0.9, 0.82))
	for k in range(rng.randi_range(2, 4)):
		mb.add_cone(shell, Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-1.0, 1.0), 0.08, rng.randf_range(-1.0, 1.0))), 0.1, 0.25, 5)
	return mb.commit()


## Driftwood: a bleached log or a tangle of branches thrown up on the sand.
static func driftwood(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var w := PSXMat.lit("planks_grey", Color(1.15, 1.1, 1.0))
	var L := rng.randf_range(2.0, 4.0)
	var r := rng.randf_range(0.14, 0.28)
	var bend := rng.randf_range(-0.4, 0.4)
	mb.add_tube(w, PackedVector3Array([Vector3(-L * 0.5, r * 0.6, 0), Vector3(0, r * 0.7, bend), Vector3(L * 0.5, r * 0.5, 0)]), r, r * 0.6, 6, 0.8, Color.WHITE, true, true)
	for k in range(rng.randi_range(1, 3)):
		var at := Vector3(rng.randf_range(-L * 0.4, L * 0.4), r * 0.7, bend * 0.5)
		var a := rng.randf() * TAU
		mb.add_tube(w, PackedVector3Array([at, at + Vector3(cos(a), 0.3, sin(a)) * rng.randf_range(0.5, 1.1)]), r * 0.4, 0.03, 4, 1.0)
	return mb.commit()


## A giant clam's empty shells and a coconut or two (the "broadleaf" slot's other pick).
static func beach_litter(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var shell := PSXMat.lit("atoll_coral", Color(1.2, 1.15, 1.05))
	for k in range(rng.randi_range(1, 2)):
		var q := Vector3(rng.randf_range(-0.8, 0.8), 0.1, rng.randf_range(-0.8, 0.8))
		mb.add_blob(shell, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q), Vector3(0.45, 0.14, 0.32), rng, 0.12, 2, 7, 0.5, Color.WHITE, 0.0)
	var nut := PSXMat.lit("palm_bark", Color(0.55, 0.44, 0.26))
	for k in range(rng.randi_range(1, 3)):
		mb.add_blob(nut, Transform3D(Basis(), Vector3(rng.randf_range(-1.0, 1.0), 0.12, rng.randf_range(-1.0, 1.0))), Vector3(0.18, 0.15, 0.2), rng, 0.15, 2, 5)
	return mb.commit()
