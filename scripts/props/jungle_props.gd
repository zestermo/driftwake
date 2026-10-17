class_name JungleProps
extends RefCounted
## The jungle style's props (JungleTheme's style "props" slots, made through ThemeDef.props): woven baskets, clay pots,
## bamboo tiki torches and carved totems. Same conventions as Props: origin on the
## ground, front +Z, a simple collider. Shading is vertex colour on shared materials.

const PAINT := [Color(0.72, 0.2, 0.14), Color(0.16, 0.46, 0.44), Color(0.9, 0.72, 0.2), Color(0.12, 0.1, 0.09), Color(0.88, 0.84, 0.72)]
const CLAY := [Color(0.82, 0.48, 0.32), Color(0.66, 0.38, 0.25), Color(0.74, 0.56, 0.4)]
const FRUIT := [Color(0.98, 0.62, 0.12), Color(0.95, 0.85, 0.25), Color(0.45, 0.3, 0.16), Color(0.92, 0.35, 0.25), Color(0.45, 0.72, 0.2)]


static func _xf(pos: Vector3, rot_y := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y), pos)


## Rope wound round a pole of radius `r` at height `y`.
static func lash(mb: MeshBuilder, at: Vector3, r: float, y: float, h := 0.1) -> void:
	mb.add_cylinder(PSXMat.lit("rope"), _xf(at + Vector3(0, y - h * 0.5, 0)), r + 0.025, r + 0.025, h, 6, 2.0)


## A woven basket, heaped with fruit or lidded.
static func basket(size: float, seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Basket")
	var mb := MeshBuilder.new()
	var weave := PSXMat.lit("straw")
	var s := size / 0.8
	var r := 0.32 * s
	var h := 0.48 * s
	mb.add_cylinder(weave, Transform3D.IDENTITY, r * 0.8, r, h, 8, 1.6, Color.WHITE, false)
	mb.add_cylinder(weave, _xf(Vector3(0, h - 0.06 * s, 0)), r - 0.03, r - 0.03, 0.01, 8, 1.6, Color(0.35, 0.3, 0.25))
	lash(mb, Vector3.ZERO, r, h - 0.02, 0.06 * s)
	if rng.randf() < 0.6:
		var fruit := PSXMat.flat(Color.WHITE)
		for i in range(rng.randi_range(4, 6)):
			var a := rng.randf() * TAU
			var q := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, r * 0.55) + Vector3(0, h - 0.02 + rng.randf() * 0.06 * s, 0)
			mb.add_blob(fruit, _xf(q), Vector3.ONE * 0.1 * s, rng, 0.15, 2, 5, 1.0, FRUIT[rng.randi() % FRUIT.size()])
	else:
		mb.add_cylinder(weave, _xf(Vector3(0, h, 0)), r + 0.02, 0.06 * s, 0.14 * s, 8, 1.6)
	body.add_child(mb.to_instance())
	Props._add_cyl_col(body, r, h, Vector3.ZERO)
	return body


## A clay storage pot: wide belly, narrow neck, a rope sling round it.
static func pot(size: float, seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Pot")
	var mb := MeshBuilder.new()
	var clay := PSXMat.lit("plaster")
	var c: Color = CLAY[rng.randi() % CLAY.size()]
	var s := size * rng.randf_range(0.85, 1.1)
	var rings := [[0.0, 0.17], [0.22, 0.3], [0.36, 0.31], [0.55, 0.2], [0.64, 0.13], [0.7, 0.17]]
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		mb.add_cylinder(clay, _xf(Vector3(0, a[0] * s, 0)), a[1] * s, b[1] * s, (b[0] - a[0]) * s, 8, 1.0, c, false)
	mb.add_cylinder(clay, _xf(Vector3(0, 0.66 * s, 0)), 0.14 * s, 0.14 * s, 0.01, 8, 1.0, Color(0.16, 0.1, 0.07))
	lash(mb, Vector3.ZERO, 0.3 * s, 0.31 * s, 0.05 * s)
	body.add_child(mb.to_instance())
	Props._add_cyl_col(body, 0.3 * s, 0.7 * s, Vector3.ZERO)
	return body


## A bamboo pole lashed with rope, a bowl of fire on top ("Flame" marks where its light goes).
static func torch_post(height: float) -> Node3D:
	var body := Props._body("TorchPost")
	var mb := MeshBuilder.new()
	var bamboo := PSXMat.lit("bamboo")
	mb.add_cylinder(bamboo, Transform3D.IDENTITY, 0.065, 0.055, height, 6, 1.0)
	for y in [0.35, height * 0.55, height - 0.08]:
		lash(mb, Vector3.ZERO, 0.06, y)
	mb.add_cylinder(PSXMat.lit("palm_bark"), _xf(Vector3(0, height - 0.02, 0)), 0.07, 0.17, 0.18, 6, 1.0)
	var flame := PSXMat.glow(Color(1.0, 0.58, 0.22), 2.6)
	mb.add_cone(flame, _xf(Vector3(0, height + 0.14, 0)), 0.13, 0.36, 5)
	mb.add_cone(flame, _xf(Vector3(0.03, height + 0.14, 0.02), 0.6), 0.08, 0.5, 4)
	body.add_child(mb.to_instance())
	var m := Marker3D.new()
	m.name = "Flame"
	m.position = Vector3(0, height + 0.35, 0)
	body.add_child(m)
	Props._add_box_col(body, Vector3(0.2, height, 0.2), Vector3(0, height * 0.5, 0))
	return body


## A carved log of three stacked faces under spread wings, painted.
static func totem(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Totem")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var pick := func() -> Color: return PAINT[rng.randi() % 3]
	mb.add_cylinder(wood, _xf(Vector3(0, -0.3, 0)), 0.32, 0.28, 3.0, 8, 0.8, Color(0.85, 0.72, 0.58))
	for i in range(3):
		var y0 := 0.2 + i * 0.8
		var mask: Color = pick.call()
		# a painted mask: heavy brow, white eyes with dark pupils, a beak of a nose, a wide mouth with teeth
		mb.add_box(wood, _xf(Vector3(0, y0 + 0.36, 0.2)), Vector3(0.62, 0.7, 0.16), 1.0, mask)
		mb.add_box(wood, _xf(Vector3(0, y0 + 0.62, 0.3)), Vector3(0.66, 0.12, 0.12), 1.0, PAINT[3])
		for sx in [-0.15, 0.15]:
			mb.add_box(wood, _xf(Vector3(sx, y0 + 0.48, 0.29)), Vector3(0.18, 0.14, 0.04), 1.0, PAINT[4])
			mb.add_box(wood, _xf(Vector3(sx, y0 + 0.48, 0.31)), Vector3(0.07, 0.08, 0.02), 1.0, PAINT[3])
		mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, y0 + 0.34, 0.33)), Vector3(0.12, 0.24, 0.14), 1.0, mask.darkened(0.25))
		mb.add_box(wood, _xf(Vector3(0, y0 + 0.14, 0.29)), Vector3(0.42, 0.12, 0.04), 1.0, PAINT[3])
		for tx in [-0.12, 0.0, 0.12]:
			mb.add_box(wood, _xf(Vector3(tx, y0 + 0.17, 0.31)), Vector3(0.06, 0.06, 0.02), 1.0, PAINT[4])
	var wing: Color = pick.call()
	mb.add_box(wood, _xf(Vector3(0, 2.62, 0)), Vector3(1.5, 0.16, 0.1), 1.0, wing)
	for sx in [-1.0, 1.0]:
		mb.add_box(wood, Transform3D(Basis(Vector3.BACK, sx * 0.35), Vector3(sx * 0.62, 2.78, 0)), Vector3(0.5, 0.12, 0.09), 1.0, wing)
	mb.add_box(wood, _xf(Vector3(0, 2.6, 0.3)), Vector3(0.12, 0.12, 0.3), 1.0, PAINT[2])
	body.add_child(mb.to_instance())
	Props._add_cyl_col(body, 0.32, 2.8, Vector3.ZERO)
	return body
