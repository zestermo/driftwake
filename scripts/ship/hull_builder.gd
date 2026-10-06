class_name HullBuilder
extends RefCounted
## The sloop's hull, deck, mast and sails as a reusable model (enemy pirate
## ships use it), plus its collision (deck you can walk on, waist-high
## bulwarks, cabin, mast). Same shape as the crew's ship, so boarding and
## cannon positions work the same on both.

const DECK_Y := 0.32
## Hull cross-sections along Z (stern at +Z, bow at -Z):
## [z, top half-width, bottom half-width, top y, bottom y]
const RINGS := [
	[6.6, 2.7, 1.5, 0.35, -1.6],
	[3.0, 2.95, 1.6, 0.25, -1.9],
	[-2.0, 2.95, 1.5, 0.25, -1.9],
	[-5.5, 2.4, 1.0, 0.35, -1.7],
	[-8.4, 0.25, 0.1, 0.8, -0.9],
]

static var _jolly_tex: ImageTexture
static var _jolly_mat: ShaderMaterial
static var _marine_mat: ShaderMaterial


## Half the deck's width at `z` (ship-local).
static func half_width(z: float) -> float:
	for i in range(RINGS.size() - 1):
		var a: Array = RINGS[i]
		var b: Array = RINGS[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			var t := (float(a[0]) - z) / (float(a[0]) - float(b[0]))
			return lerpf(float(a[1]), float(b[1]), t)
	return 0.3


## Build the model under `parent`. opts: hull (Color), sail (Color),
## trim (Color), emblem ("jolly": skull and crossbones on the sail and flag,
## "marine": the Marines' blue gull; the node is "Jolly" either way).
static func build(parent: Node3D, opts: Dictionary = {}) -> Node3D:
	var mb := MeshBuilder.new()
	var hull := PSXMat.lit("planks_dark", opts.get("hull", Color.WHITE), {"affine": 0.6})
	var deck := PSXMat.lit("planks", opts.get("deck", Color.WHITE), {"affine": 0.6})
	var trim := PSXMat.lit("planks", opts.get("trim", Color(0.85, 0.65, 0.35)))
	var canvas := PSXMat.lit("canvas", opts.get("sail", Color(0.95, 0.92, 0.82)), {"affine": 0.6})
	var canvas_back := PSXMat.lit("canvas", (opts.get("sail", Color(0.95, 0.92, 0.82)) as Color).darkened(0.2), {"affine": 0.6})
	var wood := PSXMat.lit("bark")
	var flag := PSXMat.lit("cloth_red", opts.get("flag", Color.WHITE))
	var glass := PSXMat.glow(Color(1.0, 0.8, 0.4), 2.5)
	for i in range(RINGS.size() - 1):
		var a: Array = RINGS[i]
		var b: Array = RINGS[i + 1]
		var a_tl := Vector3(-a[1], a[3], a[0]); var a_bl := Vector3(-a[2], a[4], a[0])
		var a_tr := Vector3(a[1], a[3], a[0]); var a_br := Vector3(a[2], a[4], a[0])
		var b_tl := Vector3(-b[1], b[3], b[0]); var b_bl := Vector3(-b[2], b[4], b[0])
		var b_tr := Vector3(b[1], b[3], b[0]); var b_br := Vector3(b[2], b[4], b[0])
		var L: float = absf(float(a[0]) - float(b[0])) * 0.5
		var Ha: float = (float(a[3]) - float(a[4])) * 0.5
		mb.add_quad(hull, a_tl, a_bl, b_bl, b_tl, Vector2(0, 0), Vector2(0, Ha), Vector2(L, Ha), Vector2(L, 0), Color.WHITE, Vector3(-1, -0.3, 0).normalized())
		mb.add_quad(hull, a_tr, b_tr, b_br, a_br, Vector2(0, 0), Vector2(L, 0), Vector2(L, Ha), Vector2(0, Ha), Color.WHITE, Vector3(1, -0.3, 0).normalized())
		mb.add_quad(hull, a_bl, a_br, b_br, b_bl, Vector2(0, 0), Vector2(1, 0), Vector2(1, L), Vector2(0, L), Color(0.7, 0.7, 0.7), Vector3.DOWN)
		var dy := DECK_Y
		mb.add_quad(deck, Vector3(-a[1] + 0.1, dy, a[0]), Vector3(a[1] - 0.1, dy, a[0]), Vector3(b[1] - 0.1, dy, b[0]), Vector3(-b[1] + 0.1, dy, b[0]),
			Vector2(0, 0), Vector2(a[1], 0), Vector2(b[1], L * 2.0), Vector2(0, L * 2.0), Color.WHITE, Vector3.UP)
		for sgn in [-1.0, 1.0]:
			var p0 := Vector3(sgn * float(a[1]), float(a[3]) + 0.35, float(a[0]))
			var p1 := Vector3(sgn * float(b[1]), float(b[3]) + 0.35, float(b[0]))
			var dir := (p1 - p0)
			mb.add_box(trim, Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (p0 + p1) * 0.5), Vector3(0.14, 0.12, dir.length() + 0.1), 1.0)
	var st: Array = RINGS[0]
	mb.add_quad(hull, Vector3(-st[1], st[3], st[0]), Vector3(st[1], st[3], st[0]), Vector3(st[2], st[4], st[0]), Vector3(-st[2], st[4], st[0]),
		Vector2(0, 0), Vector2(2.7, 0), Vector2(2.0, 1.0), Vector2(0.7, 1.0), Color.WHITE, Vector3.BACK)
	for z in [-4.0, -1.0, 2.0, 5.5]:
		for sgn in [-1.0, 1.0]:
			mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * 2.8, 0.5, z)), Vector3(0.12, 0.4, 0.12), 1.0)
	# mast, yard, sail (two panels, both faces), flag, bowsprit
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, 0.3, -1.2)), 0.2, 0.13, 11.0, 6, 0.8)
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(3.0, 9.2, -1.2)), 0.08, 0.08, 6.0, 5, 0.8)
	var sn := Vector3(0, 0, 1)
	mb.add_quad(canvas, Vector3(-2.8, 9.1, -1.05), Vector3(2.8, 9.1, -1.05), Vector3(2.6, 6.2, -0.75), Vector3(-2.6, 6.2, -0.75),
		Vector2(0, 0), Vector2(2.0, 0), Vector2(2.0, 1.0), Vector2(0, 1.0), Color.WHITE, sn)
	mb.add_quad(canvas, Vector3(-2.6, 6.2, -0.75), Vector3(2.6, 6.2, -0.75), Vector3(2.4, 3.4, -1.0), Vector3(-2.4, 3.4, -1.0),
		Vector2(0, 1.0), Vector2(2.0, 1.0), Vector2(2.0, 2.0), Vector2(0, 2.0), Color.WHITE, sn)
	mb.add_quad(canvas_back, Vector3(-2.8, 9.1, -1.05), Vector3(-2.6, 6.2, -0.75), Vector3(2.6, 6.2, -0.75), Vector3(2.8, 9.1, -1.05),
		Vector2(0, 0), Vector2(0, 1.0), Vector2(2.0, 1.0), Vector2(2.0, 0), Color.WHITE, -sn)
	mb.add_quad(canvas_back, Vector3(-2.6, 6.2, -0.75), Vector3(-2.4, 3.4, -1.0), Vector3(2.4, 3.4, -1.0), Vector3(2.6, 6.2, -0.75),
		Vector2(0, 1.0), Vector2(0, 2.0), Vector2(2.0, 2.0), Vector2(2.0, 1.0), Color.WHITE, -sn)
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 11.0, -0.75)), 0.9, 0.5, Rect2(0, 0, 0.5, 0.5))
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 11.0, -0.75)), 0.9, 0.5, Rect2(0, 0, 0.5, 0.5))
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-70)), Vector3(0, 0.7, -8.2)), 0.1, 0.06, 3.0, 5, 0.8)
	# stern cabin with lit windows, a lantern
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, DECK_Y + 0.75, 5.85)), Vector3(4.2, 1.5, 1.3), 0.6, Color.WHITE, true, false)
	mb.add_box(deck, Transform3D(Basis(), Vector3(0, 1.9, 5.85)), Vector3(4.5, 0.12, 1.6), 0.6, Color.WHITE, false, false)
	mb.add_box_unit_uv(PSXMat.lit("door", Color.WHITE, {"vertex_color": false}), Transform3D(Basis(), Vector3(0, DECK_Y + 0.6, 5.18)), Vector3(0.7, 1.2, 0.05))
	mb.add_box(glass, Transform3D(Basis(), Vector3(1.6, 1.4, 5.15)), Vector3(0.3, 0.3, 0.06), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(-1.6, 1.4, 5.15)), Vector3(0.3, 0.3, 0.06), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(0, 2.25, 6.4)), Vector3(0.25, 0.32, 0.25), 1.0, Color.WHITE, false)
	# a ship's wheel (fixed) and some cargo on deck
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.75, 3.35)), Vector3(0.14, 0.9, 0.14), 1.0)
	mb.add_cylinder(trim, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.25, 3.28)), 0.42, 0.42, 0.06, 8, 1.0, Color.WHITE, true, true, false)
	var crate := PSXMat.lit("planks", Color(0.8, 0.65, 0.45))
	mb.add_box(crate, Transform3D(Basis(Vector3.UP, 0.3), Vector3(1.4, DECK_Y + 0.3, 1.6)), Vector3(0.6, 0.6, 0.6), 1.0)
	mb.add_box(crate, Transform3D(Basis(Vector3.UP, -0.2), Vector3(-1.5, DECK_Y + 0.25, -3.0)), Vector3(0.5, 0.5, 0.5), 1.0)
	var inst := mb.to_instance("PSXModel")
	parent.add_child(inst)
	var emblem := str(opts.get("emblem", ""))
	if emblem != "":
		var j := MeshBuilder.new()
		var jm := jolly_material() if emblem == "jolly" else marine_material()
		# on the sail's front (+Z faces the stern... the sail's shown face is
		# toward the bow, -Z): a big emblem, and both sides of the flag
		j.add_card(jm, Transform3D(Basis(Vector3.UP, PI), Vector3(0, 6.6, -1.0)), 3.0, 3.0, Rect2(0, 0, 1, 1))
		j.add_card(jm, Transform3D(Basis.IDENTITY, Vector3(0, 6.6, -0.72)), 3.0, 3.0, Rect2(0, 0, 1, 1))
		j.add_card(jm, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.01, 11.0, -0.75)), 0.7, 0.45, Rect2(0, 0, 1, 1))
		j.add_card(jm, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.01, 11.0, -0.75)), 0.7, 0.45, Rect2(0, 0, 1, 1))
		parent.add_child(j.to_instance("Jolly"))
	return inst


## A skull and crossbones (painted at runtime), white on transparent.
static func jolly_material() -> ShaderMaterial:
	if _jolly_mat:
		return _jolly_mat
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var white := Color(0.95, 0.93, 0.86, 1.0)
	var c := Vector2(32, 26)
	for y in range(n):
		for x in range(n):
			var p := Vector2(x, y)
			var on := false
			# cranium and jaw
			if p.distance_to(c) < 12.0:
				on = true
			if absf(x - 32) < 7 and y > 30 and y < 42:
				on = true
			# eye sockets and nose
			if p.distance_to(Vector2(27, 26)) < 3.6 or p.distance_to(Vector2(37, 26)) < 3.6:
				on = false
			if absf(x - 32) < 1.6 and y > 31 and y < 35:
				on = false
			# teeth gaps
			if y > 37 and y < 42 and (x == 29 or x == 32 or x == 35):
				on = false
			# crossbones under it
			for s in [-1.0, 1.0]:
				var a := Vector2(14, 46 if s > 0 else 58)
				var b := Vector2(50, 58 if s > 0 else 46)
				var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
				if p.distance_to(a.lerp(b, t)) < 2.6:
					on = true
				for e in [a, b]:
					if p.distance_to(e + Vector2(0, -2.5)) < 2.6 or p.distance_to(e + Vector2(0, 2.5)) < 2.6:
						on = true
			if on:
				img.set_pixel(x, y, white)
	_jolly_tex = ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = PSXMat.CUTOUT_SHADER
	m.set_shader_parameter("albedo_tex", _jolly_tex)
	m.set_shader_parameter("albedo_color", Color.WHITE)
	m.set_shader_parameter("wind_strength", 0.0)
	m.set_shader_parameter("sway_height", 1.0)
	_jolly_mat = m
	return m


## The Marines' seagull (painted at runtime), blue on transparent.
static func marine_material() -> ShaderMaterial:
	if _marine_mat:
		return _marine_mat
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blue := Color(0.16, 0.3, 0.62, 1.0)
	for y in range(n):
		for x in range(n):
			var on := false
			# two swept wings meeting at the body
			for cx: float in [21.0, 43.0]:
				var u := (x - cx) / 13.0
				if absf(u) <= 1.0:
					var wy := 24.0 + 9.0 * u * u * (1.0 if (x - cx) * (cx - 32.0) > 0.0 else 0.35)
					if absf(y - wy) < 2.8 - absf(u) * 1.2:
						on = true
			# body and head
			if Vector2(x, y).distance_to(Vector2(32, 30)) < 3.6 or Vector2(x, y).distance_to(Vector2(32, 25)) < 2.4:
				on = true
			# a bar of "MARINE" blue under it
			if y > 44 and y < 49 and x > 14 and x < 50:
				on = true
			if on:
				img.set_pixel(x, y, blue)
	var m := ShaderMaterial.new()
	m.shader = PSXMat.CUTOUT_SHADER
	m.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("albedo_color", Color.WHITE)
	m.set_shader_parameter("wind_strength", 0.0)
	m.set_shader_parameter("sway_height", 1.0)
	_marine_mat = m
	return m


## Collision for a hull built with `build` (call on the body).
static func collide(body: CollisionObject3D) -> void:
	var rings := [[6.6, 2.7, 1.5, -1.6], [3.0, 2.95, 1.6, -1.9], [-2.0, 2.95, 1.5, -1.9], [-5.5, 2.4, 1.0, -1.7], [-8.4, 0.25, 0.1, -0.9]]
	var pts := PackedVector3Array()
	for r in rings:
		for sgn in [-1.0, 1.0]:
			pts.append(Vector3(sgn * float(r[1]), DECK_Y, float(r[0])))
			pts.append(Vector3(sgn * float(r[2]), float(r[3]), float(r[0])))
	var hull := ConvexPolygonShape3D.new()
	hull.points = pts
	_shape(body, hull, Transform3D.IDENTITY)
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for sgn in [-1.0, 1.0]:
			var p0 := Vector3(sgn * (float(a[1]) - 0.05), DECK_Y, float(a[0]))
			var p1 := Vector3(sgn * (float(b[1]) - 0.05), DECK_Y, float(b[0]))
			var dir := p1 - p0
			var box := BoxShape3D.new()
			box.size = Vector3(0.16, 0.75, dir.length() + 0.2)
			_shape(body, box, Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (p0 + p1) * 0.5 + Vector3(0, 0.37, 0)))
	var transom := BoxShape3D.new()
	transom.size = Vector3(5.4, 0.75, 0.16)
	_shape(body, transom, Transform3D(Basis.IDENTITY, Vector3(0, DECK_Y + 0.37, 6.6)))
	var cabin := BoxShape3D.new()
	cabin.size = Vector3(4.5, 1.62, 1.6)
	_shape(body, cabin, Transform3D(Basis.IDENTITY, Vector3(0, DECK_Y + 0.83, 5.85)))
	var mast := CylinderShape3D.new()
	mast.radius = 0.22
	mast.height = 11.0
	_shape(body, mast, Transform3D(Basis.IDENTITY, Vector3(0, DECK_Y + 5.5, -1.2)))


static func _shape(body: CollisionObject3D, shape: Shape3D, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)
