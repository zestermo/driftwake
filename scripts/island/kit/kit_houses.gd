class_name KitHouses
extends RefCounted
## A jungle village's buildings beyond KitContext.house's huts: raised rooms you walk
## into (a home, the trader's store, the cookhouse), the boat-builder's workshop, the
## shrine, the granary on stilts, the well, tiki torches, a woodpile, and the cargo
## meshes the dressing instances (`cargo_mesh`). Front +Z, origin on the ground; a
## spec's "found" is how far its posts or footing reach below the origin.

const DOOR_W := 1.3
const DOOR_H := 2.15
const WALL_T := 0.18
## What the cargo dressing is (KitVillage.build_cargo): kind -> [collider: "box" size | "cyl" r h | none].
const CARGO := {"crate": ["box", 0.7], "barrel": ["cyl", 0.38, 1.0], "jar": ["cyl", 0.24, 0.62], "basket": [], "sack": []}

static var _cargo: Dictionary = {}


static func _body(n: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.collision_layer = 1
	b.collision_mask = 0
	return b


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


static func _box(body: Node3D, size: Vector3, p: Vector3, basis := Basis()) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.transform = Transform3D(basis, p)
	body.add_child(cs)


static func _cyl(body: Node3D, r: float, h: float, p: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	cs.shape = s
	cs.position = p + Vector3(0, h * 0.5, 0)
	body.add_child(cs)


## Steps from `base` up to `top` at z0, running out along +z (treads, and a ramp to walk up).
static func _steps(body: Node3D, mb: MeshBuilder, mat: Material, x: float, z0: float, top: float, width := 1.4, base := 0.0) -> float:
	var rise := top - base
	if rise < 0.2:
		return 0.0
	var n := int(ceil(rise / 0.22))
	var run := n * 0.3
	for i in range(n):
		var y := top - (i + 1) * rise / n
		mb.add_box(mat, _xf(Vector3(x, y + 0.05, z0 + 0.15 + i * 0.3)), Vector3(width, 0.1, 0.32), 0.8, Color.WHITE, false)
		if y - base > 0.05:
			mb.add_box(mat, _xf(Vector3(x, (y + base) * 0.5, z0 + 0.15 + i * 0.3)), Vector3(width - 0.1, y - base, 0.06), 0.8, Color(0.6, 0.6, 0.6))
	_box(body, Vector3(width, 0.1, Vector2(run, rise).length()), Vector3(x, (top + base) * 0.5 - 0.05, z0 + run * 0.5), Basis(Vector3.RIGHT, atan2(rise, run)))
	return run


static func _marker(parent: Node3D, n: String, p: Vector3, yaw := 0.0) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = p
	m.rotation.y = yaw
	parent.add_child(m)


static func _window() -> ShaderMaterial:
	return PSXMat.lit("window", Color.WHITE, {"emission": Color(0.9, 0.7, 0.35), "emission_energy": 0.7, "emission_tex": "window"})


## A window through a wall (both faces lit), its frame, and a woven shutter propped
## open above it outside. `xf` sits in the wall's middle, outward +Z.
static func _wall_window(mb: MeshBuilder, xf: Transform3D, t: float, frame: Material, weave: Material) -> void:
	mb.add_box_unit_uv(_window(), xf, Vector3(0.75, 0.6, t + 0.06))
	for y in [-0.34, 0.34]:
		mb.add_box(frame, xf * _xf(Vector3(0, y, 0)), Vector3(0.95, 0.08, t + 0.14), 1.0, Color.WHITE, false)
	for x in [-0.42, 0.42]:
		mb.add_box(frame, xf * _xf(Vector3(x, 0, 0)), Vector3(0.08, 0.7, t + 0.14), 1.0)
	var hinge := Vector3(0, 0.38, t * 0.5 + 0.06)
	mb.add_box(weave, xf * Transform3D(Basis(Vector3.RIGHT, -0.95), hinge) * _xf(Vector3(0, -0.32, 0.0)), Vector3(0.9, 0.66, 0.04), 1.0, Color(0.9, 0.85, 0.75), false)
	Buildings.beam_between(mb, frame, xf * Vector3(0.3, -0.3, t * 0.5 + 0.05), xf * (Vector3(0.3, 0.38, t * 0.5 + 0.06) + Basis(Vector3.RIGHT, -0.95) * Vector3(0, -0.6, 0)), 0.03)


## A raised room on a timber deck with a veranda and steps up to it (a ramp under them).
## spec: kind "home" / "trade" / "cook", w, d, h, fl (the floor over the origin),
## found, veranda, roof "hip" / "gable", wall, roof_tex, seed, name, steps (false: a walkway meets
## the veranda instead). Markers: Door (at the foot
## of the steps, facing out), Inside, and the kind's own: Bed, Table, Hearth (home);
## Vendor (behind the counter, facing the door) and Customer (trade, cook).
static func room(spec: Dictionary) -> StaticBody3D:
	var w: float = spec.get("w", 6.0)
	var d: float = spec.get("d", 5.0)
	var h: float = spec.get("h", 2.7)
	var fl: float = spec.get("fl", 0.6)
	var found: float = spec.get("found", 0.4)
	var ver: float = spec.get("veranda", 1.5)
	var kind: String = spec.get("kind", "home")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	var body := _body(str(spec.get("name", "Home")))
	var mb := MeshBuilder.new()
	var wall := PSXMat.lit(str(spec.get("wall", "planks_weathered")))
	var deck := PSXMat.lit("planks")
	var beam := PSXMat.lit("planks_dark")
	var palm := _palm()
	var thatch := PSXMat.lit(str(spec.get("roof_tex", "thatch")), Color.WHITE, {"affine": 0.8})
	var weave := PSXMat.lit("straw")
	var rope := PSXMat.lit("rope")
	var t := WALL_T
	var zf := d * 0.5 + ver
	# the deck on its posts, joists under it
	mb.add_box(deck, _xf(Vector3(0, fl - 0.08, (ver - 0.15) * 0.5)), Vector3(w + 0.4, 0.16, d + ver + 0.15), 0.5, Color.WHITE, false)
	for z in [-d * 0.5, d * 0.5, zf - 0.15]:
		mb.add_box(beam, _xf(Vector3(0, fl - 0.24, z)), Vector3(w + 0.5, 0.16, 0.16), 0.6, Color(0.8, 0.8, 0.8), false)
	var xs := [-w * 0.5, w * 0.5] if w < 6.5 else [-w * 0.5, 0.0, w * 0.5]
	for x in xs:
		for z in [-d * 0.5, d * 0.5, zf - 0.15]:
			mb.add_cylinder(palm,_xf(Vector3(x, -found, z)), 0.14, 0.12, found + fl - 0.16, 6, 0.6)
	_box(body, Vector3(w + 0.4, fl + found, d + ver + 0.15), Vector3(0, (fl - found) * 0.5, (ver - 0.15) * 0.5))
	# walls round a doorway in the front, posts at the corners, plates top and bottom
	var walls := [[Vector3(0, 0, -d * 0.5 + t * 0.5), Vector3(w, 0, t)], [Vector3(-w * 0.5 + t * 0.5, 0, 0), Vector3(t, 0, d)],
		[Vector3(w * 0.5 - t * 0.5, 0, 0), Vector3(t, 0, d)]]
	var side_w := (w - DOOR_W) * 0.5
	for s in [-1.0, 1.0]:
		walls.append([Vector3(s * (w * 0.5 - side_w * 0.5), 0, d * 0.5 - t * 0.5), Vector3(side_w, 0, t)])
	for wl in walls:
		var c: Vector3 = wl[0]
		var sz: Vector3 = wl[1]
		Buildings.tiled_box(mb, wall, Vector3(c.x, fl + h * 0.5, c.z), Vector3(sz.x, h, sz.z), 2.4, 0.5, true, false)
		_box(body, Vector3(sz.x, h, sz.z), Vector3(c.x, fl + h * 0.5, c.z))
	mb.add_box(wall, _xf(Vector3(0, fl + DOOR_H + (h - DOOR_H) * 0.5, d * 0.5 - t * 0.5)), Vector3(DOOR_W, h - DOOR_H, t), 0.5, Color.WHITE, false)
	_box(body, Vector3(DOOR_W, h - DOOR_H, t), Vector3(0, fl + DOOR_H + (h - DOOR_H) * 0.5, d * 0.5 - t * 0.5))
	for x in [-w * 0.5, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]:
			mb.add_cylinder(palm,_xf(Vector3(x, fl, z)), 0.15, 0.14, h + 0.1, 6, 0.6)
	for y in [fl + 0.06, fl + h]:
		mb.add_box(beam, _xf(Vector3(0, y, 0)), Vector3(w + 0.12, 0.14, d + 0.12), 0.6, Color.WHITE, false)
	# the doorway: log jambs, a lintel lashed on, the door swung in against the wall
	for s in [-1.0, 1.0]:
		mb.add_cylinder(palm,_xf(Vector3(s * (DOOR_W * 0.5 + 0.05), fl, d * 0.5 + 0.02)), 0.08, 0.08, DOOR_H + 0.1, 5, 0.8)
		mb.add_cylinder(rope, _xf(Vector3(s * (DOOR_W * 0.5 + 0.05), fl + DOOR_H - 0.05, d * 0.5 + 0.02)), 0.1, 0.1, 0.14, 5, 1.5)
	mb.add_box(beam, _xf(Vector3(0, fl + DOOR_H + 0.08, d * 0.5 + 0.04)), Vector3(DOOR_W + 0.5, 0.16, t + 0.12), 0.8, Color.WHITE, false)
	var hinge := Vector3(-DOOR_W * 0.5 + 0.05, fl + DOOR_H * 0.5, d * 0.5 - t - 0.04)
	var door := Buildings.door_leaf()
	mb.add_box_unit_uv(door, Transform3D(Basis(Vector3.UP, 2.55), hinge) * _xf(Vector3(DOOR_W * 0.5 - 0.06, 0, 0)), Vector3(DOOR_W - 0.12, DOOR_H - 0.06, 0.05))
	# windows: each side, either side of the door, the back
	var wins: Array = [_xf(Vector3(-w * 0.5 + t * 0.5, fl + 1.45, 0), -PI * 0.5), _xf(Vector3(w * 0.5 - t * 0.5, fl + 1.45, 0), PI * 0.5),
		_xf(Vector3(w * 0.22, fl + 1.45, -d * 0.5 + t * 0.5), PI)]
	if w >= 5.0:
		for s in [-1.0, 1.0]:
			wins.append(_xf(Vector3(s * (DOOR_W * 0.5 + side_w * 0.5), fl + 1.45, d * 0.5 - t * 0.5)))
	for wx in wins:
		_wall_window(mb, wx, t, beam, weave)
	# the ceiling (dark above it, so no sky shows through the thatch's seams)
	mb.add_quad(beam, Vector3(-w * 0.5, fl + h - 0.02, -d * 0.5), Vector3(w * 0.5, fl + h - 0.02, -d * 0.5), Vector3(w * 0.5, fl + h - 0.02, d * 0.5), Vector3(-w * 0.5, fl + h - 0.02, d * 0.5),
		Vector2.ZERO, Vector2(w * 0.5, 0), Vector2(w * 0.5, d * 0.5), Vector2(0, d * 0.5), Color(0.6, 0.6, 0.6), Vector3.DOWN)
	mb.add_quad(PSXMat.flat(Color(0.1, 0.07, 0.05)), Vector3(-w * 0.5, fl + h + 0.04, -d * 0.5), Vector3(w * 0.5, fl + h + 0.04, -d * 0.5), Vector3(w * 0.5, fl + h + 0.04, d * 0.5), Vector3(-w * 0.5, fl + h + 0.04, d * 0.5),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3.DOWN)
	for x in range(3):
		mb.add_box(palm,_xf(Vector3(-w * 0.3 + x * w * 0.3, fl + h - 0.14, 0)), Vector3(0.16, 0.2, d - t * 2.0), 0.6, Color(0.8, 0.8, 0.8), false, true)
	# the roof: deep thatch with a ridge cap, a lean-to over the veranda on two posts
	var ry := fl + h + 0.1
	var pitch: float = spec.get("pitch", 0.62)
	var top := ry
	if str(spec.get("roof", "hip")) == "gable":
		var rise := d * pitch
		mb.add_gable_roof(thatch, _xf(Vector3(0, ry, 0), PI * 0.5), d, w, rise, 0.75, 0.5, Color.WHITE, wall)
		mb.add_box(PSXMat.lit("thatch", Color(0.7, 0.66, 0.6), {"affine": 0.8}), _xf(Vector3(0, ry + rise + 0.04, 0)), Vector3(w + 1.6, 0.2, 0.34), 0.8)
		top = ry + rise
	else:
		var rise := minf(w, d) * pitch
		Buildings.add_hip_roof(mb, thatch, _xf(Vector3(0, ry, 0)), w, d, rise, 0.75)
		var r := absf(w - d) * 0.5
		mb.add_box(PSXMat.lit("thatch", Color(0.7, 0.66, 0.6), {"affine": 0.8}), _xf(Vector3(0, ry + rise + 0.03, 0)), Vector3(r * 2.0 + 0.5, 0.2, 0.3) if w >= d else Vector3(0.3, 0.2, r * 2.0 + 0.5), 0.8)
		top = ry + rise
	var ly := fl + h - 0.2
	var lf := fl + h - 0.75
	mb.add_quad(thatch, Vector3(-w * 0.5 - 0.3, ly, d * 0.5 + 0.2), Vector3(w * 0.5 + 0.3, ly, d * 0.5 + 0.2), Vector3(w * 0.5 + 0.3, lf, zf + 0.4), Vector3(-w * 0.5 - 0.3, lf, zf + 0.4),
		Vector2.ZERO, Vector2(w * 0.5, 0), Vector2(w * 0.5, 1), Vector2(0, 1), Color.WHITE, Vector3(0, 1, 0.5).normalized())
	mb.add_quad(thatch, Vector3(-w * 0.5 - 0.3, ly, d * 0.5 + 0.2), Vector3(-w * 0.5 - 0.3, lf, zf + 0.4), Vector3(w * 0.5 + 0.3, lf, zf + 0.4), Vector3(w * 0.5 + 0.3, ly, d * 0.5 + 0.2),
		Vector2.ZERO, Vector2(0, 1), Vector2(w * 0.5, 1), Vector2(w * 0.5, 0), Color(0.55, 0.55, 0.55), Vector3(0, -1, -0.5).normalized())
	for s in [-1.0, 1.0]:
		mb.add_cylinder(palm,_xf(Vector3(s * (w * 0.5 + 0.05), fl, zf - 0.15)), 0.1, 0.09, lf - fl + 0.05, 6, 0.8)
		mb.add_cylinder(rope, _xf(Vector3(s * (w * 0.5 + 0.05), lf - 0.25, zf - 0.15)), 0.12, 0.12, 0.16, 5, 1.5)
	mb.add_box(beam, _xf(Vector3(0, lf - 0.06, zf - 0.15)), Vector3(w + 0.4, 0.12, 0.14), 0.8, Color.WHITE, false)
	# the veranda's rail (a gap for the steps) and the steps
	var rail_y := fl + 0.85
	for s in [-1.0, 1.0]:
		var sx: float = s * (w * 0.5 + 0.05)
		mb.add_box(beam, _xf(Vector3(sx, rail_y, d * 0.5 + ver * 0.5)), Vector3(0.08, 0.08, ver), 0.8, Color.WHITE, false)
		_box(body, Vector3(0.12, 0.9, ver), Vector3(sx, fl + 0.45, d * 0.5 + ver * 0.5))
		var fx: float = s * (w * 0.25 + 0.4)
		var fw := w * 0.5 - 0.85
		mb.add_box(beam, _xf(Vector3(fx, rail_y, zf - 0.15)), Vector3(fw, 0.08, 0.08), 0.8, Color.WHITE, false)
		mb.add_box(beam, _xf(Vector3(s * 0.85, (rail_y + fl) * 0.5, zf - 0.15)), Vector3(0.1, rail_y - fl, 0.1), 0.8)
		_box(body, Vector3(fw, 0.9, 0.12), Vector3(fx, fl + 0.45, zf - 0.15))
		for k in range(int(fw / 0.35)):
			mb.add_box(palm,_xf(Vector3(s * (0.95 + k * 0.35), (rail_y + fl) * 0.5, zf - 0.15)), Vector3(0.05, rail_y - fl, 0.05), 1.0)
	var run := _steps(body, mb, beam, 0.0, zf, fl) if spec.get("steps", true) else 0.0
	# outside: a lantern by the door, gourds hung under the veranda roof, a mat on the deck
	Buildings.wall_lantern(mb, Vector3(DOOR_W * 0.5 + 0.45, fl + 1.9, d * 0.5), beam)
	for k in range(3):
		var gp := Vector3(-w * 0.5 + 0.5 + k * 0.35, lf - 0.45 - (k % 2) * 0.12, zf - 0.35)
		mb.add_box(rope, _xf(gp + Vector3(0, 0.25, 0)), Vector3(0.02, 0.4, 0.02), 1.0)
		mb.add_blob(PSXMat.flat(Color(0.72, 0.55, 0.28)), _xf(gp), Vector3(0.11, 0.15, 0.11), rng, 0.1, 3, 6)
	mb.add_quad(weave, Vector3(-0.8, fl + 0.012, d * 0.5 + 0.2), Vector3(0.8, fl + 0.012, d * 0.5 + 0.2), Vector3(0.8, fl + 0.012, d * 0.5 + 1.1), Vector3(-0.8, fl + 0.012, d * 0.5 + 1.1),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 0.6), Vector2(0, 0.6), Color(0.85, 0.75, 0.6), Vector3.UP)
	body.add_child(mb.to_instance())
	# inside (its own mesh, drawn only near)
	var imb := MeshBuilder.new()
	var hang := PSXMat.glow(Color(1.0, 0.75, 0.4), 2.2)
	imb.add_box(rope, _xf(Vector3(0, fl + h - 0.35, 0)), Vector3(0.03, 0.5, 0.03), 1.0)
	imb.add_box(hang, _xf(Vector3(0, fl + h - 0.75, 0)), Vector3(0.2, 0.26, 0.2), 1.0)
	imb.add_pyramid_roof(PSXMat.flat(Color(0.15, 0.13, 0.12)), _xf(Vector3(0, fl + h - 0.62, 0)), 0.24, 0.24, 0.12, 0.02, 1.0)
	match kind:
		"trade":
			_trade_inside(body, imb, w, d, fl, rng)
		"cook":
			_cook_inside(body, imb, w, d, fl, top, rng)
		_:
			_home_inside(body, imb, w, d, fl, rng)
	var inside := imb.to_instance("Furnishing")
	inside.visibility_range_end = 45.0
	body.add_child(inside)
	if kind != "home":
		var smb := MeshBuilder.new()
		_shop_sign(smb, w, zf, lf, kind)
		body.add_child(smb.to_instance("Sign"))
	_marker(body, "Door", Vector3(0, 0, zf + run + 0.7), 0.0)
	_marker(body, "Inside", Vector3(0, fl, 0.4), 0.0)
	return body


## A board hung off the veranda's beam: a fish (the cookhouse) or coins and a bottle (the store).
static func _shop_sign(mb: MeshBuilder, w: float, zf: float, lf: float, kind: String) -> void:
	var x := w * 0.5 - 0.5
	var beam := PSXMat.lit("planks_dark")
	mb.add_box(beam, _xf(Vector3(x, lf - 0.2, zf + 0.25)), Vector3(0.06, 0.06, 0.8), 1.0, Color.WHITE, false)
	if kind == "cook":
		mb.add_box_unit_uv(PSXMat.lit("sign_fish", Color.WHITE, {"vertex_color": false}), _xf(Vector3(x, lf - 0.6, zf + 0.55), PI * 0.5), Vector3(1.0, 0.5, 0.06))
		return
	var board := _xf(Vector3(x, lf - 0.6, zf + 0.55), PI * 0.5)
	mb.add_box(PSXMat.lit("planks"), board, Vector3(1.0, 0.5, 0.06), 1.0)
	var gold := PSXMat.flat(Color(0.95, 0.75, 0.25))
	for s in [-1.0, 1.0]:
		for k in range(2):
			mb.add_cylinder(gold, board * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.25 + k * 0.12, -0.08 + k * 0.1, s * 0.04)), 0.09, 0.09, 0.015, 8, 1.0)
		mb.add_box(PSXMat.flat(Color(0.25, 0.45, 0.2)), board * _xf(Vector3(0.22, 0.0, s * 0.04)), Vector3(0.1, 0.28, 0.015), 1.0)
		mb.add_box(PSXMat.flat(Color(0.25, 0.45, 0.2)), board * _xf(Vector3(0.22, 0.17, s * 0.04)), Vector3(0.04, 0.08, 0.015), 1.0)


static func _clay(rng: RandomNumberGenerator) -> Material:
	return PSXMat.lit("plaster", [Color(0.75, 0.42, 0.25), Color(0.62, 0.36, 0.2), Color(0.82, 0.68, 0.5)][rng.randi() % 3])


## A jar: a belly, a neck and a lip (into mb at xf).
static func _jar(mb: MeshBuilder, mat: Material, xf: Transform3D, s: float) -> void:
	mb.add_cylinder(mat, xf, 0.12 * s, 0.22 * s, 0.25 * s, 7, 1.0, Color.WHITE, false)
	mb.add_cylinder(mat, xf * _xf(Vector3(0, 0.25 * s, 0)), 0.22 * s, 0.1 * s, 0.25 * s, 7, 1.0, Color.WHITE, false)
	mb.add_cylinder(mat, xf * _xf(Vector3(0, 0.5 * s, 0)), 0.1 * s, 0.12 * s, 0.08 * s, 7, 1.0, Color(0.8, 0.8, 0.8))


static func _home_inside(body: Node3D, mb: MeshBuilder, w: float, d: float, fl: float, rng: RandomNumberGenerator) -> void:
	var x0 := -w * 0.5 + WALL_T
	var x1 := w * 0.5 - WALL_T
	var z0 := -d * 0.5 + WALL_T
	var z1 := d * 0.5 - WALL_T
	var planks := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	var cloth := PSXMat.lit("fabric", [Color(0.75, 0.35, 0.28), Color(0.4, 0.55, 0.7), Color(0.85, 0.75, 0.45)][rng.randi() % 3])
	# a sleeping platform with a mat, a rolled blanket and a pillow
	var bed := Vector3(x0 + 1.0, fl, z0 + 0.55)
	mb.add_box(planks, _xf(bed + Vector3(0, 0.18, 0)), Vector3(1.9, 0.36, 1.0), 1.0)
	mb.add_box(cloth, _xf(bed + Vector3(0, 0.39, 0)), Vector3(1.8, 0.06, 0.9), 1.0)
	mb.add_cylinder(cloth, Transform3D(Basis(Vector3.BACK, PI * 0.5), bed + Vector3(0.6, 0.5, 0)), 0.12, 0.12, 0.8, 6, 1.0, Color(0.8, 0.8, 0.8), true, true)
	mb.add_blob(PSXMat.lit("canvas", Color(0.9, 0.86, 0.78)), _xf(bed + Vector3(-0.7, 0.5, 0)), Vector3(0.22, 0.08, 0.3), rng, 0.1, 3, 6)
	_box(body, Vector3(1.9, 0.42, 1.0), bed + Vector3(0, 0.21, 0))
	# a hearth of stones in the front corner, coals, a pot on three sticks
	var hp := Vector3(x0 + 0.7, fl, z1 - 0.8)
	var stone := PSXMat.lit("rock", Color(0.75, 0.72, 0.68))
	for k in range(7):
		var a := TAU * k / 7.0
		mb.add_blob(stone, _xf(hp + Vector3(cos(a) * 0.36, 0.06, sin(a) * 0.36)), Vector3(0.12, 0.09, 0.11), rng, 0.2, 2, 5)
	mb.add_box(PSXMat.glow(Color(1.0, 0.45, 0.12), 2.5), _xf(hp + Vector3(0, 0.04, 0)), Vector3(0.36, 0.05, 0.36), 1.0)
	for k in range(3):
		var a := TAU * k / 3.0 + 0.3
		Buildings.beam_between(mb, dark, hp + Vector3(cos(a) * 0.42, 0.0, sin(a) * 0.42), hp + Vector3(0, 0.75, 0), 0.04)
	mb.add_cylinder(PSXMat.lit("metal", Color(0.25, 0.24, 0.24)), _xf(hp + Vector3(0, 0.25, 0)), 0.16, 0.2, 0.25, 7, 1.0)
	# a low table with bowls and fruit, two stools
	var tp := Vector3(x1 - 1.3, fl, 0.15)
	mb.add_box(planks, _xf(tp + Vector3(0, 0.45, 0)), Vector3(1.1, 0.06, 0.7), 1.0, Color.WHITE, false)
	for x in [-0.45, 0.45]:
		for z in [-0.27, 0.27]:
			mb.add_box(dark, _xf(tp + Vector3(x, 0.21, z)), Vector3(0.06, 0.42, 0.06), 1.0)
	for k in range(2):
		mb.add_cylinder(_clay(rng), _xf(tp + Vector3(-0.25 + k * 0.5, 0.48, -0.1 + k * 0.15)), 0.1, 0.14, 0.07, 7, 1.0)
	mb.add_blob(PSXMat.flat(Color(0.95, 0.8, 0.2)), _xf(tp + Vector3(0.05, 0.55, 0.15)), Vector3(0.07, 0.07, 0.07), rng, 0.15, 2, 4)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(PSXMat.lit("bark"), _xf(tp + Vector3(s * 0.25, 0, 0.75 * s)), 0.17, 0.17, 0.3, 6, 1.0)
		Props.seats().add(body, tp + Vector3(s * 0.25, 0.3, 0.75 * s), 0.3, Vector3(0, 0, -s))
	_box(body, Vector3(1.1, 0.48, 0.7), tp + Vector3(0, 0.24, 0))
	# a shelf of jars on the back wall, a chest by the right wall
	for y in [1.15, 1.6]:
		mb.add_box(planks, _xf(Vector3(x1 - 1.2, fl + y, z0 + 0.18)), Vector3(1.8, 0.05, 0.3), 1.0, Color.WHITE, false)
		for k in range(4):
			_jar(mb, _clay(rng), _xf(Vector3(x1 - 1.9 + k * 0.45, fl + y + 0.03, z0 + 0.18)), rng.randf_range(0.5, 0.75))
	var cp := Vector3(x1 - 0.35, fl, z1 - 0.9)
	mb.add_box(dark, _xf(cp + Vector3(0, 0.25, 0)), Vector3(0.55, 0.5, 0.9), 1.0)
	for z in [-0.3, 0.3]:
		mb.add_box(PSXMat.lit("metal", Color(0.4, 0.38, 0.36)), _xf(cp + Vector3(0, 0.25, z)), Vector3(0.58, 0.52, 0.05), 1.0)
	_box(body, Vector3(0.55, 0.5, 0.9), cp + Vector3(0, 0.25, 0))
	# a woven rug, herbs from the beam
	mb.add_quad(PSXMat.lit("straw", Color(0.95, 0.8, 0.65)), Vector3(-0.9, fl + 0.012, -0.5), Vector3(0.9, fl + 0.012, -0.5), Vector3(0.9, fl + 0.012, 0.9), Vector3(-0.9, fl + 0.012, 0.9),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 0.8), Vector2(0, 0.8), Color.WHITE, Vector3.UP)
	var rope := PSXMat.lit("rope", Color(0.85, 0.8, 0.7))
	for k in range(4):
		var hx := -0.8 + k * 0.5
		mb.add_box(rope, _xf(Vector3(hx, fl + 2.3, -0.9)), Vector3(0.02, 0.3, 0.02), 1.0)
		mb.add_blob(PSXMat.lit("leaves", Color(0.7, 0.85, 0.55)), _xf(Vector3(hx, fl + 2.08, -0.9)), Vector3(0.1, 0.17, 0.1), rng, 0.25, 3, 5)
	_marker(body, "Bed", bed + Vector3(0.3, 0, 0.9), PI)
	_marker(body, "Table", tp + Vector3(-0.25, 0, 0.75), PI)
	_marker(body, "Hearth", hp + Vector3(0.75, 0, -0.1), -PI * 0.5)


static func _trade_inside(body: Node3D, mb: MeshBuilder, w: float, d: float, fl: float, rng: RandomNumberGenerator) -> void:
	var x0 := -w * 0.5 + WALL_T
	var x1 := w * 0.5 - WALL_T
	var z0 := -d * 0.5 + WALL_T
	var z1 := d * 0.5 - WALL_T
	var planks := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	# the counter across the back of the room
	var cz := z0 + 1.45
	var cx0 := x0 + 0.2
	var cx1 := x1 - 1.1
	var cw := cx1 - cx0
	mb.add_box(PSXMat.lit("straw", Color(0.9, 0.8, 0.65)), _xf(Vector3((cx0 + cx1) * 0.5, fl + 0.5, cz + 0.02)), Vector3(cw, 1.0, 0.56), 1.0)
	mb.add_box(dark, _xf(Vector3((cx0 + cx1) * 0.5, fl + 1.04, cz)), Vector3(cw + 0.1, 0.08, 0.75), 1.0, Color.WHITE, false)
	_box(body, Vector3(cw, 1.08, 0.6), Vector3((cx0 + cx1) * 0.5, fl + 0.54, cz))
	var gold := PSXMat.flat(Color(0.95, 0.75, 0.25))
	for k in range(5):
		mb.add_cylinder(gold, _xf(Vector3(cx0 + 0.5 + k * 0.07, fl + 1.08 + k * 0.012, cz + 0.1)), 0.05, 0.05, 0.012, 6, 1.0)
	var iron := PSXMat.lit("metal", Color(0.75, 0.6, 0.3))
	mb.add_box(iron, _xf(Vector3(cx0 + 1.3, fl + 1.3, cz)), Vector3(0.03, 0.45, 0.03), 1.0)
	mb.add_box(iron, _xf(Vector3(cx0 + 1.3, fl + 1.52, cz)), Vector3(0.5, 0.03, 0.03), 1.0)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(iron, _xf(Vector3(cx0 + 1.3 + s * 0.24, fl + 1.3, cz)), 0.09, 0.09, 0.02, 7, 1.0)
	_jar(mb, _clay(rng), _xf(Vector3(cx1 - 0.4, fl + 1.08, cz)), 0.8)
	# shelves on the back wall: jars, bottles, bolts of cloth, baskets
	var cloths := [Color(0.66, 0.14, 0.12), Color(0.2, 0.32, 0.62), Color(0.8, 0.62, 0.2), Color(0.16, 0.42, 0.44)]
	var glass := [PSXMat.flat(Color(0.25, 0.45, 0.2)), PSXMat.flat(Color(0.45, 0.25, 0.1)), PSXMat.flat(Color(0.2, 0.3, 0.45))]
	for row in range(3):
		var sy := fl + 0.8 + row * 0.55
		mb.add_box(dark, _xf(Vector3(0, sy, z0 + 0.2)), Vector3(w - WALL_T * 2.0 - 0.2, 0.05, 0.36), 1.0, Color.WHITE, false)
		var x := x0 + 0.35
		while x < x1 - 0.3:
			match posmod(row + int(x * 3.0), 4):
				0:
					_jar(mb, _clay(rng), _xf(Vector3(x, sy + 0.03, z0 + 0.2)), rng.randf_range(0.6, 0.8))
					x += 0.42
				1:
					for k in range(3):
						mb.add_cylinder(glass[rng.randi() % glass.size()], _xf(Vector3(x + k * 0.12, sy + 0.03, z0 + 0.2)), 0.05, 0.05, 0.24, 5, 1.0)
					x += 0.45
				2:
					mb.add_cylinder(PSXMat.lit("fabric", cloths[rng.randi() % cloths.size()]), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x + 0.25, sy + 0.13, z0 + 0.22)), 0.1, 0.1, 0.5, 6, 1.0, Color.WHITE, true, true)
					x += 0.58
				_:
					mb.add_cylinder(PSXMat.lit("straw"), _xf(Vector3(x + 0.1, sy + 0.03, z0 + 0.2)), 0.15, 0.18, 0.2, 7, 1.0)
					x += 0.45
	# sacks heaped by the door, crates on the right, a weapon rack
	for k in range(3):
		mb.add_blob(PSXMat.lit("canvas", Color(0.82, 0.74, 0.56)), _xf(Vector3(x0 + 0.4 + k * 0.42, fl + 0.28, z1 - 0.45 - (k % 2) * 0.3), rng.randf() * TAU), Vector3(0.26, 0.3, 0.24), rng, 0.2, 3, 6)
	for k in range(2):
		var cp := Vector3(x1 - 0.45, fl, z1 - 0.5 - k * 0.8)
		mb.add_box(planks, _xf(cp + Vector3(0, 0.35, 0), 0.2 * k), Vector3(0.7, 0.7, 0.7), 1.4)
		_box(body, Vector3(0.7, 0.7, 0.7), cp + Vector3(0, 0.35, 0), Basis(Vector3.UP, 0.2 * k))
	var rack := Props.weapon_rack()
	rack.position = Vector3(x1 - 0.2, fl, 0.3 - d * 0.1)
	rack.rotation.y = -PI * 0.5
	body.add_child(rack)
	# a net with floats on the left wall
	var rope := PSXMat.lit("rope", Color(0.85, 0.8, 0.7))
	for k in range(5):
		var z := 0.65 + k * 0.28
		Buildings.beam_between(mb, rope, Vector3(x0 + 0.04, fl + 2.4, z), Vector3(x0 + 0.04, fl + 1.5 + (k % 2) * 0.2, z + 0.2), 0.02)
	for k in range(3):
		mb.add_blob(PSXMat.flat(Color(0.9, 0.55, 0.2) if k % 2 == 0 else Color(0.85, 0.85, 0.8)), _xf(Vector3(x0 + 0.08, fl + 1.75 + k * 0.22, 0.8 + k * 0.4)), Vector3.ONE * 0.09, rng, 0.1, 2, 5)
	_marker(body, "Vendor", Vector3((cx0 + cx1) * 0.5, fl, z0 + 0.75), 0.0)
	_marker(body, "Customer", Vector3((cx0 + cx1) * 0.5, fl, cz + 0.95), PI)


static func _cook_inside(body: Node3D, mb: MeshBuilder, w: float, d: float, fl: float, roof_top: float, rng: RandomNumberGenerator) -> void:
	var x0 := -w * 0.5 + WALL_T
	var x1 := w * 0.5 - WALL_T
	var z0 := -d * 0.5 + WALL_T
	var z1 := d * 0.5 - WALL_T
	var planks := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	var stone := PSXMat.lit("stone_brick", Color(0.85, 0.8, 0.75))
	var iron := PSXMat.lit("metal", Color(0.25, 0.24, 0.24))
	# the hearth in the back corner: a stone bench, coals, the pot, a hood and its stack up through the roof
	var hp := Vector3(x0 + 0.85, fl, z0 + 0.6)
	mb.add_box(stone, _xf(hp + Vector3(0, 0.25, 0)), Vector3(1.5, 0.5, 1.0), 0.6)
	mb.add_box(PSXMat.glow(Color(1.0, 0.45, 0.12), 3.0), _xf(hp + Vector3(0, 0.52, 0.05)), Vector3(0.9, 0.05, 0.6), 1.0)
	mb.add_cylinder(iron, _xf(hp + Vector3(0, 0.55, 0.05)), 0.28, 0.36, 0.45, 8, 1.0, Color.WHITE, false)
	mb.add_cylinder(PSXMat.flat(Color(0.55, 0.32, 0.15)), _xf(hp + Vector3(0, 0.97, 0.05)), 0.33, 0.33, 0.02, 8, 1.0)
	mb.add_cylinder(stone, _xf(hp + Vector3(0, 1.6, 0)), 0.75, 0.28, 0.7, 4, 0.6, Color(0.85, 0.85, 0.85), false, true)
	mb.add_box(stone, _xf(hp + Vector3(0, (roof_top - fl + 0.8 + 2.3) * 0.5, 0)), Vector3(0.5, roof_top - fl + 0.8 - 2.3, 0.5), 0.6, Color.WHITE, true, false)
	_box(body, Vector3(1.5, 0.5, 1.0), hp + Vector3(0, 0.25, 0))
	FX.chimney_smoke(body, hp + Vector3(0, roof_top - fl + 1.0, 0))
	# the counter with bowls, a board of fish, bananas
	var cz := z0 + 1.6
	var cx0 := x0 + 1.9
	var cx1 := x1 - 0.2
	mb.add_box(planks, _xf(Vector3((cx0 + cx1) * 0.5, fl + 0.5, cz)), Vector3(cx1 - cx0, 1.0, 0.56), 1.0)
	mb.add_box(dark, _xf(Vector3((cx0 + cx1) * 0.5, fl + 1.04, cz)), Vector3(cx1 - cx0 + 0.1, 0.08, 0.72), 1.0, Color.WHITE, false)
	_box(body, Vector3(cx1 - cx0, 1.08, 0.6), Vector3((cx0 + cx1) * 0.5, fl + 0.54, cz))
	for k in range(4):
		mb.add_cylinder(_clay(rng), _xf(Vector3(cx0 + 0.3 + k * 0.35, fl + 1.08, cz + 0.12)), 0.09, 0.13, 0.08, 7, 1.0)
	mb.add_box(PSXMat.lit("planks", Color(0.9, 0.8, 0.65)), _xf(Vector3(cx1 - 0.6, fl + 1.1, cz - 0.05)), Vector3(0.6, 0.04, 0.35), 1.0)
	for k in range(2):
		mb.add_box(PSXMat.flat(Color(0.6, 0.65, 0.7)), _xf(Vector3(cx1 - 0.7 + k * 0.22, fl + 1.14, cz - 0.05), 0.3), Vector3(0.1, 0.04, 0.3), 1.0)
	var banana := PSXMat.flat(Color(0.95, 0.85, 0.25))
	for k in range(5):
		mb.add_box(banana, Transform3D(Basis(Vector3.BACK, -0.5 + k * 0.25), Vector3(cx0 + 1.6 + k * 0.05, fl + 1.16, cz + 0.15)), Vector3(0.05, 0.2, 0.05), 1.0)
	# fish and peppers hung on a line along the back wall
	var rope := PSXMat.lit("rope", Color(0.85, 0.8, 0.7))
	mb.add_box(rope, _xf(Vector3((cx0 + cx1) * 0.5, fl + 2.2, z0 + 0.25)), Vector3(cx1 - cx0, 0.03, 0.03), 1.0)
	var fish := [PSXMat.flat(Color(0.6, 0.65, 0.7)), PSXMat.flat(Color(0.75, 0.5, 0.35)), PSXMat.flat(Color(0.75, 0.15, 0.1))]
	var x := cx0 + 0.2
	var k2 := 0
	while x < cx1 - 0.2:
		mb.add_box(fish[k2 % 3], _xf(Vector3(x, fl + 1.95, z0 + 0.25)), Vector3(0.1 if k2 % 3 < 2 else 0.05, 0.42, 0.05), 1.0)
		x += 0.3
		k2 += 1
	# a table and two benches to eat at, in the front corner
	var tp := Vector3(x1 - 1.0, fl, z1 - 1.1)
	mb.add_box(planks, _xf(tp + Vector3(0, 0.76, 0)), Vector3(0.8, 0.06, 1.3), 1.0, Color.WHITE, false)
	for zz in [-0.5, 0.5]:
		mb.add_box(dark, _xf(tp + Vector3(0, 0.37, zz)), Vector3(0.6, 0.74, 0.06), 1.0)
	for s in [-1.0, 1.0]:
		mb.add_box(planks, _xf(tp + Vector3(s * 0.7, 0.44, 0)), Vector3(0.32, 0.06, 1.3), 1.0, Color.WHITE, false)
		mb.add_box(dark, _xf(tp + Vector3(s * 0.7, 0.21, 0)), Vector3(0.26, 0.42, 1.0), 1.0, Color(0.7, 0.7, 0.7))
		mb.add_cylinder(_clay(rng), _xf(tp + Vector3(s * 0.2, 0.79, s * 0.3)), 0.09, 0.12, 0.07, 7, 1.0)
		for z in [-0.35, 0.35]:
			Props.seats().add(body, tp + Vector3(s * 0.7, 0.47, z), 0.47, Vector3(-s, 0, 0))
	_box(body, Vector3(2.0, 0.8, 1.3), tp + Vector3(0, 0.4, 0))
	# baskets and a water jar by the door
	for k in range(2):
		mb.add_cylinder(PSXMat.lit("straw"), _xf(Vector3(x0 + 0.4 + k * 0.5, fl, z1 - 0.4)), 0.2, 0.24, 0.32, 7, 1.0)
		mb.add_blob(PSXMat.flat([Color(0.9, 0.55, 0.1), Color(0.45, 0.7, 0.2)][k]), _xf(Vector3(x0 + 0.4 + k * 0.5, fl + 0.34, z1 - 0.4)), Vector3(0.16, 0.08, 0.16), rng, 0.2, 2, 5)
	_jar(mb, _clay(rng), _xf(Vector3(x0 + 0.4, fl, z1 - 1.0)), 1.1)
	_marker(body, "Vendor", Vector3((cx0 + cx1) * 0.5, fl, z0 + 0.85), 0.0)
	_marker(body, "Customer", Vector3((cx0 + cx1) * 0.5, fl, cz + 0.95), PI)


## The boat-builder's open shed: palm posts under a thatched shed roof, a woven back
## wall hung with tools, a dugout canoe on trestles, the bench, logs, shavings. Markers:
## Worker (at the canoe, facing it), Bench (at the workbench).
static func workshop(spec: Dictionary) -> StaticBody3D:
	var w := 7.5
	var d := 5.0
	var found: float = spec.get("found", 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	var body := _body("Workshop")
	var mb := MeshBuilder.new()
	var palm := _palm()
	var weave := PSXMat.lit("straw")
	var dark := PSXMat.lit("planks_dark")
	var planks := PSXMat.lit("planks")
	var thatch := PSXMat.lit("thatch", Color.WHITE, {"affine": 0.8})
	var iron := PSXMat.lit("metal", Color(0.32, 0.32, 0.34))
	# a floor of packed boards, posts, the roof
	mb.add_box(planks, _xf(Vector3(0, -found * 0.5 + 0.05, 0)), Vector3(w + 0.2, found + 0.1, d + 0.2), 0.5, Color(0.85, 0.85, 0.85), true, false)
	_box(body, Vector3(w + 0.2, found + 0.1, d + 0.2), Vector3(0, -found * 0.5 + 0.05, 0))
	for x in [-w * 0.5, 0.0, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]:
			var ph := 3.35 if z < 0.0 else 2.65
			mb.add_cylinder(palm,_xf(Vector3(x, 0.0, z)), 0.15, 0.13, ph, 6, 0.6)
			_cyl(body, 0.15, ph, Vector3(x, 0.0, z))
	mb.add_box(dark, _xf(Vector3(0, 2.6, d * 0.5)), Vector3(w + 0.3, 0.16, 0.18), 0.6, Color.WHITE, false)
	mb.add_box(dark, _xf(Vector3(0, 3.3, -d * 0.5)), Vector3(w + 0.3, 0.16, 0.18), 0.6, Color.WHITE, false)
	Buildings.add_shed_roof(mb, thatch, weave, _xf(Vector3(0, 2.68, 0)), w, d, 0.75, 0.6)
	# the woven back wall and a low one on the left
	Buildings.tiled_box(mb, weave, Vector3(0, 1.6, -d * 0.5 + 0.08), Vector3(w, 3.2, 0.12), 2.4, 0.5)
	_box(body, Vector3(w, 3.2, 0.14), Vector3(0, 1.6, -d * 0.5 + 0.08))
	Buildings.tiled_box(mb, weave, Vector3(-w * 0.5 + 0.08, 0.6, 0), Vector3(0.12, 1.2, d), 2.4, 0.5)
	_box(body, Vector3(0.14, 1.2, d), Vector3(-w * 0.5 + 0.08, 0.6, 0))
	# the canoe on its trestles, half hollowed
	var cy := 0.95
	var hull := PSXMat.lit("bark", Color(0.85, 0.7, 0.55))
	var along := Basis(Vector3.BACK, PI * 0.5)
	mb.add_cylinder(hull, Transform3D(along.scaled(Vector3(1.0, 0.7, 0.9)), Vector3(1.6, cy, 0.4)), 0.36, 0.36, 3.2, 8, 0.8, Color.WHITE, false, false)
	for s in [-1.0, 1.0]:
		var tip := Basis(Vector3.BACK, -s * PI * 0.5).scaled(Vector3(1.0, 0.7, 0.9))
		mb.add_cylinder(hull, Transform3D(tip, Vector3(s * 1.6, cy, 0.4)), 0.36, 0.04, 0.8, 8, 0.8, Color.WHITE, false, false)
	mb.add_quad(PSXMat.lit("planks", Color(0.75, 0.6, 0.45)), Vector3(-1.4, cy + 0.2, 0.15), Vector3(1.4, cy + 0.2, 0.15), Vector3(1.4, cy + 0.2, 0.65), Vector3(-1.4, cy + 0.2, 0.65),
		Vector2.ZERO, Vector2(2, 0), Vector2(2, 0.5), Vector2(0, 0.5), Color(0.6, 0.6, 0.6), Vector3.UP)
	for x in [-1.1, 1.1]:
		for s in [-1.0, 1.0]:
			Buildings.beam_between(mb, dark, Vector3(x - 0.25 * s, 0.0, 0.4 + s * 0.3), Vector3(x + 0.2 * s, cy - 0.2, 0.4 - s * 0.05), 0.07)
		mb.add_box(dark, _xf(Vector3(x, cy - 0.22, 0.4)), Vector3(0.12, 0.1, 0.8), 0.8, Color.WHITE, false)
	_box(body, Vector3(4.6, 1.2, 0.9), Vector3(0, 0.6, 0.4))
	# the workbench, its tools and a rack of more on the wall
	var bp := Vector3(1.6, 0.0, -d * 0.5 + 0.6)
	mb.add_box(planks, _xf(bp + Vector3(0, 0.85, 0)), Vector3(2.2, 0.08, 0.7), 1.0, Color.WHITE, false)
	for x in [-0.95, 0.95]:
		for z in [-0.25, 0.25]:
			mb.add_box(dark, _xf(bp + Vector3(x, 0.42, z)), Vector3(0.08, 0.84, 0.08), 1.0)
	mb.add_box(iron, _xf(bp + Vector3(-0.6, 0.93, 0.0), 0.4), Vector3(0.25, 0.06, 0.08), 1.0)
	mb.add_box(PSXMat.lit("bark"), _xf(bp + Vector3(-0.45, 0.93, 0.08), 0.4), Vector3(0.05, 0.05, 0.35), 1.0)
	mb.add_box(PSXMat.lit("bark"), _xf(bp + Vector3(0.4, 0.95, 0.05)), Vector3(0.22, 0.12, 0.12), 1.0)
	_box(body, Vector3(2.2, 0.9, 0.7), bp + Vector3(0, 0.45, 0))
	mb.add_box(dark, _xf(Vector3(-0.5, 2.0, -d * 0.5 + 0.18)), Vector3(3.4, 0.08, 0.06), 1.0)
	for k in range(7):
		var x := -2.0 + k * 0.5
		mb.add_box(PSXMat.lit("bark"), _xf(Vector3(x, 1.7, -d * 0.5 + 0.22)), Vector3(0.04, 0.55, 0.04), 1.0)
		mb.add_box(iron, _xf(Vector3(x, 1.47 if k % 2 == 0 else 1.92, -d * 0.5 + 0.23)), Vector3(0.14, 0.07, 0.07), 1.0)
	# paddles against a post, a pile of logs, a block with an axe in it, shavings
	for k in range(3):
		var pp := Vector3(w * 0.5 - 0.25 - k * 0.12, 0.0, d * 0.5 - 0.35)
		mb.add_box(planks, Transform3D(Basis(Vector3.BACK, 0.12 + k * 0.05), pp + Vector3(0, 0.9, 0)), Vector3(0.05, 1.7, 0.05), 1.0)
		mb.add_box(planks, Transform3D(Basis(Vector3.BACK, 0.12 + k * 0.05), pp + Vector3(0.04, 0.3, 0)), Vector3(0.18, 0.55, 0.03), 1.0)
	var bark := PSXMat.lit("bark")
	for row in range(3):
		for k in range(4 - row):
			mb.add_cylinder(palm, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-2.1, 0.3 + row * 0.36, -d * 0.5 + 0.5 + k * 0.4 + row * 0.2)), 0.2, 0.2, 1.55, 6, 0.8, Color.WHITE, true, true)
	_box(body, Vector3(1.6, 1.1, 1.7), Vector3(-2.9, 0.55, -d * 0.5 + 1.1))
	var blk := Vector3(-0.9, 0.0, d * 0.5 - 0.4)
	mb.add_cylinder(bark, _xf(blk), 0.3, 0.32, 0.5, 7, 1.0)
	mb.add_box(iron, Transform3D(Basis(Vector3.BACK, 0.5), blk + Vector3(0.05, 0.55, 0)), Vector3(0.2, 0.12, 0.04), 1.0)
	mb.add_box(bark, Transform3D(Basis(Vector3.BACK, 0.5), blk + Vector3(0.22, 0.75, 0)), Vector3(0.04, 0.5, 0.04), 1.0)
	_cyl(body, 0.32, 0.5, blk)
	var shave := PSXMat.flat(Color(0.85, 0.72, 0.5))
	for k in range(9):
		mb.add_blob(shave, _xf(Vector3(rng.randf_range(-0.6, 2.6), 0.1, rng.randf_range(-0.4, 1.2))), Vector3(0.12, 0.02, 0.08), rng, 0.3, 2, 4)
	body.add_child(mb.to_instance())
	_marker(body, "Worker", Vector3(0.6, 0.0, 1.45), PI)
	_marker(body, "Bench", bp + Vector3(0, 0, 0.8), PI)
	return body


## A small shrine: two stone tiers, painted posts under a thatched hip roof, the idol
## with glowing eyes at the back, offerings, a garland, torches at the steps.
## Markers: Keeper (beside the idol, facing it), Pray (at the foot of the steps).
static func shrine(spec: Dictionary) -> StaticBody3D:
	var found: float = spec.get("found", 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	var body := _body("Shrine")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.8, 0.85, 0.78))
	var rock := PSXMat.lit("rock", Color(0.7, 0.78, 0.7))
	var palm := _palm()
	var thatch := PSXMat.lit("thatch", Color.WHITE, {"affine": 0.8})
	var paint := [PSXMat.flat(Color(0.7, 0.18, 0.12)), PSXMat.flat(Color(0.85, 0.65, 0.2)), PSXMat.flat(Color(0.9, 0.88, 0.8))]
	var t1 := 0.45
	var t2 := 0.85
	mb.add_box(stone, _xf(Vector3(0, (t1 - found) * 0.5, 0)), Vector3(4.6, t1 + found, 4.6), 0.6, Color.WHITE, true, false)
	mb.add_box(stone, _xf(Vector3(0, (t1 + t2) * 0.5, -0.2)), Vector3(3.4, t2 - t1, 3.2), 0.6, Color(0.9, 0.9, 0.9), true, false)
	_box(body, Vector3(4.6, t1 + found, 4.6), Vector3(0, (t1 - found) * 0.5, 0))
	_box(body, Vector3(3.4, t2 - t1, 3.2), Vector3(0, (t1 + t2) * 0.5, -0.2))
	_steps(body, mb, stone, 0.0, 1.4, t2, 1.6, t1)
	_steps(body, mb, stone, 0.0, 2.3, t1, 1.6)
	# posts with painted bands, the roof and its finial
	for x in [-1.45, 1.45]:
		for z in [-1.6, 1.0]:
			mb.add_cylinder(palm, _xf(Vector3(x, t2, z)), 0.13, 0.12, 3.35 - t2, 6, 0.6)
			for k in range(3):
				mb.add_cylinder(paint[k], _xf(Vector3(x, 1.4 + k * 0.45, z)), 0.14, 0.14, 0.12, 6, 1.0, Color.WHITE, false)
			_cyl(body, 0.13, 3.35, Vector3(x, 0.0, z))
	Buildings.add_hip_roof(mb, thatch, _xf(Vector3(0, 3.35, -0.3)), 3.0, 2.6, 1.7, 0.7)
	mb.add_cylinder(palm,_xf(Vector3(0, 3.35 + 1.4, -0.3)), 0.1, 0.06, 0.9, 6, 0.8)
	mb.add_blob(paint[0], _xf(Vector3(0, 3.35 + 2.35, -0.3)), Vector3(0.16, 0.2, 0.16), rng, 0.1, 3, 6)
	# the idol
	var ip := Vector3(0, t2, -1.05)
	mb.add_box(stone, _xf(ip + Vector3(0, 0.25, 0)), Vector3(0.9, 0.5, 0.7), 0.6)
	mb.add_cylinder(rock, _xf(ip + Vector3(0, 0.5, 0)), 0.34, 0.28, 0.85, 7, 0.8)
	mb.add_box(rock, _xf(ip + Vector3(0, 1.6, 0)), Vector3(0.66, 0.58, 0.52), 0.8)
	mb.add_box(rock, _xf(ip + Vector3(0, 1.75, 0.27)), Vector3(0.7, 0.1, 0.08), 1.0, Color(0.8, 0.8, 0.8))
	mb.add_box(PSXMat.flat(Color(0.15, 0.12, 0.1)), _xf(ip + Vector3(0, 1.42, 0.265)), Vector3(0.36, 0.08, 0.02), 1.0)
	var eyes := PSXMat.glow(Color(0.5, 1.0, 0.85), 3.0)
	for s in [-1.0, 1.0]:
		mb.add_box(eyes, _xf(ip + Vector3(s * 0.15, 1.62, 0.265)), Vector3(0.1, 0.07, 0.02), 1.0)
		mb.add_box(rock, _xf(ip + Vector3(s * 0.4, 1.55, 0)), Vector3(0.1, 0.3, 0.16), 1.0)
	for k in range(5):
		var a := -0.9 + k * 0.45
		mb.add_box(paint[k % 2] if k != 2 else PSXMat.flat(Color(0.2, 0.55, 0.3)), Transform3D(Basis(Vector3.BACK, a), ip + Vector3(0, 1.9, -0.05)) * _xf(Vector3(0, 0.3, 0)), Vector3(0.12, 0.6, 0.04), 1.0)
	_box(body, Vector3(0.9, 2.2, 0.7), ip + Vector3(0, 1.1, 0))
	# offerings: fruit in bowls, flowers, candles, shells
	var blooms := [PSXMat.flat(Color(0.95, 0.4, 0.5)), PSXMat.flat(Color(0.98, 0.85, 0.3)), PSXMat.flat(Color(0.95, 0.95, 0.9))]
	var wax := PSXMat.flat(Color(0.93, 0.9, 0.8))
	var flame := PSXMat.glow(Color(1.0, 0.75, 0.35), 3.0)
	for k in range(5):
		var op := ip + Vector3(-0.8 + k * 0.4, 0.0, 0.65 + (k % 2) * 0.2)
		match k % 3:
			0:
				mb.add_cylinder(_clay(rng), _xf(op), 0.1, 0.15, 0.08, 7, 1.0)
				mb.add_blob(PSXMat.flat([Color(0.9, 0.55, 0.1), Color(0.85, 0.15, 0.12)][k % 2]), _xf(op + Vector3(0, 0.12, 0)), Vector3(0.09, 0.08, 0.09), rng, 0.2, 2, 5)
			1:
				mb.add_cylinder(wax, _xf(op), 0.035, 0.03, 0.18, 5, 1.0)
				mb.add_box(flame, _xf(op + Vector3(0, 0.22, 0)), Vector3(0.04, 0.07, 0.04), 1.0)
			_:
				for f in range(3):
					mb.add_blob(blooms[f], _xf(op + Vector3(f * 0.08 - 0.08, 0.05, 0)), Vector3.ONE * 0.06, rng, 0.2, 2, 4)
	# a garland between the front posts
	var g0 := Vector3(-1.45, 2.9, 1.0)
	var g1 := Vector3(1.45, 2.9, 1.0)
	var rope := PSXMat.lit("rope", Color(0.5, 0.7, 0.4))
	var prev := g0
	for k in range(1, 13):
		var tk := k / 12.0
		var p := g0.lerp(g1, tk) - Vector3.UP * 0.5 * 4.0 * tk * (1.0 - tk)
		Buildings.beam_between(mb, rope, prev, p, 0.03)
		mb.add_blob(blooms[k % 3], _xf(p - Vector3(0, 0.05, 0)), Vector3.ONE * 0.07, rng, 0.2, 2, 4)
		prev = p
	# torches either side of the steps
	for s in [-1.0, 1.0]:
		_torch_into(mb, Vector3(s * 1.5, t1, 2.0), 1.7)
	body.add_child(mb.to_instance())
	_marker(body, "Keeper", ip + Vector3(0.85, 0.0, 0.7), atan2(-0.85, -0.7))
	_marker(body, "Pray", Vector3(0, 0.0, 3.6), PI)
	return body


## A tiki torch's mesh at `at` (pole `h` tall, a wrapped head, the flame).
static func _torch_into(mb: MeshBuilder, at: Vector3, h: float) -> void:
	mb.add_cylinder(PSXMat.lit("bark"), _xf(at), 0.06, 0.05, h, 5, 1.0)
	mb.add_cylinder(PSXMat.lit("rope", Color(0.7, 0.6, 0.45)), _xf(at + Vector3(0, h - 0.32, 0)), 0.09, 0.12, 0.32, 6, 1.5)
	mb.add_cylinder(PSXMat.lit("planks_dark"), _xf(at + Vector3(0, h, 0)), 0.13, 0.16, 0.1, 6, 1.0, Color.WHITE, false)
	mb.add_cone(PSXMat.glow(Color(1.0, 0.55, 0.15), 3.0), _xf(at + Vector3(0, h + 0.08, 0)), 0.12, 0.42, 5)
	mb.add_box(PSXMat.glow(Color(1.0, 0.85, 0.4), 3.5), _xf(at + Vector3(0, h + 0.18, 0)), Vector3(0.1, 0.16, 0.1), 1.0)


## A tiki torch (lit after dark only if the caller gives it a light).
static func torch(h := 2.1) -> StaticBody3D:
	var body := _body("Torch")
	var mb := MeshBuilder.new()
	_torch_into(mb, Vector3.ZERO, h)
	var mi := mb.to_instance()
	mi.visibility_range_end = 160.0
	body.add_child(mi)
	_box(body, Vector3(0.16, h, 0.16), Vector3(0, h * 0.5, 0))
	return body


static func _palm() -> ShaderMaterial:
	return PSXMat.lit("palm_bark", Color.WHITE, {"affine": 0.6})


## The granary: a woven hut on four tall stilts with rat guards, a steep thatch, a
## ladder to its door, sacks and baskets in its shade.
static func storehouse(spec: Dictionary) -> StaticBody3D:
	var w := 3.6
	var d := 3.0
	var st := 1.7
	var h := 1.9
	var found: float = spec.get("found", 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	var body := _body("Storehouse")
	var mb := MeshBuilder.new()
	var palm := _palm()
	var weave := PSXMat.lit("straw")
	var dark := PSXMat.lit("planks_dark")
	var thatch := PSXMat.lit("thatch", Color.WHITE, {"affine": 0.8})
	for x in [-w * 0.5 + 0.2, w * 0.5 - 0.2]:
		for z in [-d * 0.5 + 0.2, d * 0.5 - 0.2]:
			mb.add_cylinder(palm,_xf(Vector3(x, -found, z)), 0.15, 0.13, st + found, 6, 0.6)
			mb.add_cylinder(PSXMat.lit("rock", Color(0.8, 0.78, 0.74)), _xf(Vector3(x, st - 0.45, z)), 0.34, 0.34, 0.06, 8, 1.0, Color.WHITE, true, true)
			_cyl(body, 0.15, st + found, Vector3(x, -found, z))
	mb.add_box(PSXMat.lit("planks"), _xf(Vector3(0, st - 0.08, 0)), Vector3(w + 0.3, 0.16, d + 0.3), 0.5, Color.WHITE, false)
	Buildings.tiled_box(mb, weave, Vector3(0, st + h * 0.5, 0), Vector3(w, h, d), 2.4, 0.5, true, true)
	for x in [-w * 0.5, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]:
			mb.add_cylinder(palm,_xf(Vector3(x, st, z)), 0.1, 0.09, h, 5, 0.8)
	mb.add_box(dark, _xf(Vector3(0, st + h, 0)), Vector3(w + 0.1, 0.12, d + 0.1), 0.6, Color.WHITE, false)
	mb.add_gable_roof(thatch, _xf(Vector3(0, st + h + 0.06, 0), PI * 0.5), d, w, d * 0.95, 0.6, 0.5, Color.WHITE, weave)
	mb.add_box(PSXMat.lit("thatch", Color(0.7, 0.66, 0.6), {"affine": 0.8}), _xf(Vector3(0, st + h + d * 0.95 + 0.08, 0)), Vector3(w + 1.4, 0.2, 0.3), 0.8)
	_box(body, Vector3(w + 0.3, h + 0.2, d + 0.3), Vector3(0, st + h * 0.5, 0))
	Buildings.panel_door(mb, _xf(Vector3(0, st, d * 0.5)), 0.75, 1.4, Buildings.door_leaf(), dark)
	# the ladder up to it
	var foot := d * 0.5 + 1.0
	for s in [-1.0, 1.0]:
		Buildings.beam_between(mb, dark, Vector3(s * 0.25, 0.0, foot), Vector3(s * 0.25, st + 0.1, d * 0.5 + 0.2), 0.06)
	for k in range(5):
		var tk := (k + 1) / 6.0
		mb.add_box(dark, _xf(Vector3(0, tk * (st + 0.1), lerpf(foot, d * 0.5 + 0.2, tk))), Vector3(0.5, 0.05, 0.05), 1.0)
	# sacks and baskets underneath
	for k in range(4):
		mb.add_blob(PSXMat.lit("canvas", Color(0.82, 0.74, 0.56)), _xf(Vector3(-0.9 + k * 0.5, 0.26, -0.3 + (k % 2) * 0.4), rng.randf() * TAU), Vector3(0.26, 0.3, 0.22), rng, 0.2, 3, 6)
	for k in range(2):
		mb.add_cylinder(weave, _xf(Vector3(0.9 + k * 0.45, 0.0, 0.5)), 0.2, 0.24, 0.32, 7, 1.0)
	body.add_child(mb.to_instance())
	return body


## The village well: a ring of stones round dark water, palm posts and a little thatch, a bucket on a rope.
static func well() -> StaticBody3D:
	var body := _body("Well")
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("rock", Color(0.8, 0.78, 0.72))
	var palm := _palm()
	var r0 := 1.05
	var r1 := 0.78
	var hh := 0.8
	mb.add_cylinder(rock, Transform3D.IDENTITY, r0 + 0.05, r0, hh, 9, 0.6, Color.WHITE, false)
	for i in range(9):
		var a0 := TAU * i / 9.0
		var a1 := TAU * (i + 1) / 9.0
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		mb.add_quad(rock, o0 * r1 + Vector3.UP * hh, o1 * r1 + Vector3.UP * hh, o1 * r0 + Vector3.UP * hh, o0 * r0 + Vector3.UP * hh,
			Vector2.ZERO, Vector2(1, 0), Vector2(1, 0.3), Vector2(0, 0.3), Color(0.9, 0.9, 0.9), Vector3.UP)
		mb.add_quad(rock, o0 * r1 + Vector3.UP * hh, o0 * r1 + Vector3.UP * 0.2, o1 * r1 + Vector3.UP * 0.2, o1 * r1 + Vector3.UP * hh,
			Vector2.ZERO, Vector2(0, 0.4), Vector2(1, 0.4), Vector2(1, 0), Color(0.6, 0.6, 0.6), -(o0 + o1).normalized())
	mb.add_cylinder(PSXMat.lit("water", Color(0.3, 0.4, 0.42)), _xf(Vector3(0, 0.15, 0)), r1, r1, 0.1, 9, 0.6)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(palm,_xf(Vector3(s * (r0 - 0.05), 0.0, 0)), 0.11, 0.1, 2.3, 6, 0.6)
	mb.add_cylinder(palm,Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(r0 + 0.2, 1.9, 0)), 0.09, 0.09, (r0 + 0.2) * 2.0, 6, 0.8, Color.WHITE, true, true)
	mb.add_cylinder(PSXMat.lit("rope", Color(0.8, 0.75, 0.6)), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.3, 1.9, 0)), 0.13, 0.13, 0.6, 7, 1.5, Color.WHITE, true, true)
	mb.add_box(PSXMat.lit("rope"), _xf(Vector3(0.1, 1.45, 0)), Vector3(0.025, 0.9, 0.025), 1.0)
	mb.add_cylinder(PSXMat.lit("planks_dark"), _xf(Vector3(0.1, 0.85, 0)), 0.14, 0.17, 0.26, 7, 1.0)
	mb.add_gable_roof(PSXMat.lit("thatch", Color.WHITE, {"affine": 0.8}), _xf(Vector3(0, 2.25, 0)), 1.4, 2.6, 0.75, 0.25, 0.6)
	_jar(mb, PSXMat.lit("plaster", Color(0.75, 0.42, 0.25)), _xf(Vector3(r0 + 0.45, 0.0, 0.5)), 1.2)
	body.add_child(mb.to_instance())
	_cyl(body, r0 + 0.05, hh, Vector3.ZERO)
	return body


## Split logs stacked against a frame, a chopping block with a hatchet.
static func woodpile() -> StaticBody3D:
	var body := _body("Woodpile")
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("bark")
	var dark := PSXMat.lit("planks_dark")
	for row in range(4):
		for k in range(5 - (row % 2)):
			mb.add_cylinder(bark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.6 + k * 0.28 + (row % 2) * 0.14, 0.14 + row * 0.24, -0.35)), 0.13, 0.13, 0.7, 6, 1.0, Color.WHITE, true, true)
	for x in [-0.78, 0.78]:
		mb.add_box(dark, _xf(Vector3(x, 0.55, 0)), Vector3(0.08, 1.1, 0.08), 1.0)
	mb.add_cylinder(bark, _xf(Vector3(0.95, 0.0, 0.55)), 0.26, 0.28, 0.45, 7, 1.0)
	mb.add_box(PSXMat.lit("metal", Color(0.4, 0.4, 0.42)), Transform3D(Basis(Vector3.BACK, 0.6), Vector3(0.98, 0.5, 0.55)), Vector3(0.16, 0.1, 0.03), 1.0)
	mb.add_box(bark, Transform3D(Basis(Vector3.BACK, 0.6), Vector3(1.12, 0.66, 0.55)), Vector3(0.04, 0.4, 0.04), 1.0)
	body.add_child(mb.to_instance())
	_box(body, Vector3(1.6, 1.0, 0.75), Vector3(0, 0.5, -0.35))
	return body


## A plank walkway on posts from a to b at height y (island space), rope rails along
## both sides, its posts down to the ground. Added under the context's parent.
static func walkway(ctx: KitContext, a: Vector2, b: Vector2, y: float, w := 1.6) -> StaticBody3D:
	var body := _body("Walkway")
	var mb := MeshBuilder.new()
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var side := Vector2(dir.y, -dir.x)
	var mid := (a + b) * 0.5
	var xf := Transform3D(Basis(Vector3.UP, KitContext.face_yaw(dir)), Vector3(mid.x, y, mid.y))
	mb.add_box(PSXMat.lit("planks"), xf * _xf(Vector3(0, -0.07, 0)), Vector3(w, 0.14, length), 0.5, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb.add_box(PSXMat.lit("planks_dark"), xf * _xf(Vector3(s * (w * 0.5 - 0.05), -0.22, 0)), Vector3(0.14, 0.16, length), 0.6, Color(0.8, 0.8, 0.8), false)
	var n := maxi(int(ceil(length / 2.4)), 1)
	var palm := _palm()
	var rope := PSXMat.lit("rope")
	var prev: Array = []
	for i in range(n + 1):
		var tops: Array = []
		for s in [-1.0, 1.0]:
			var q: Vector2 = a + dir * (length * i / n) + side * float(s) * (w * 0.5 - 0.06)
			var g := ctx.hv(q)
			mb.add_cylinder(palm, _xf(Vector3(q.x, g - 0.3, q.y)), 0.09, 0.08, y + 0.95 - g + 0.3, 5, 0.8)
			tops.append(Vector3(q.x, y, q.y))
		if not prev.is_empty():
			for k in range(2):
				for hh in [0.88, 0.48]:
					Buildings.beam_between(mb, rope, prev[k] + Vector3.UP * hh, tops[k] + Vector3.UP * hh, 0.03)
		prev = tops
	body.add_child(mb.to_instance())
	_box(body, Vector3(w, 0.14, length), Vector3(mid.x, y - 0.07, mid.y), xf.basis)
	for s in [-1.0, 1.0]:
		var rq: Vector2 = mid + side * float(s) * (w * 0.5)
		_box(body, Vector3(0.1, 1.0, length), Vector3(rq.x, y + 0.5, rq.y), xf.basis)
	ctx.add(body)
	return body


## A sloping walkway from `top` (at height y) down to the ground at `foot` (island space).
static func ramp(ctx: KitContext, top: Vector2, foot: Vector2, y: float, w := 2.0) -> StaticBody3D:
	var body := _body("Ramp")
	var mb := MeshBuilder.new()
	var a3 := Vector3(top.x, y, top.y)
	var b3 := Vector3(foot.x, ctx.hv(foot), foot.y)
	var d3 := b3 - a3
	var basis := Basis.looking_at(d3.normalized(), Vector3.UP)
	var mid := (a3 + b3) * 0.5
	mb.add_box(PSXMat.lit("planks"), Transform3D(basis, mid + basis * Vector3(0, -0.07, 0)), Vector3(w, 0.14, d3.length()), 0.5, Color.WHITE, false)
	for k in range(int(d3.length() / 0.5)):
		mb.add_box(PSXMat.lit("planks_dark"), Transform3D(basis, a3.lerp(b3, (k + 0.5) / (d3.length() / 0.5)) + basis * Vector3(0, 0.01, 0)), Vector3(w - 0.1, 0.04, 0.06), 1.0)
	var dir := Vector2(d3.x, d3.z).normalized()
	var side := Vector2(dir.y, -dir.x)
	var palm := _palm()
	for s in [-1.0, 1.0]:
		var pa := a3 + Vector3(side.x, 0, side.y) * float(s) * (w * 0.5 - 0.06)
		var pb := b3 + Vector3(side.x, 0, side.y) * float(s) * (w * 0.5 - 0.06)
		for k in range(3):
			var q := pa.lerp(pb, k / 2.0)
			var g := ctx.hv(Vector2(q.x, q.z))
			mb.add_cylinder(palm, _xf(Vector3(q.x, g - 0.3, q.z)), 0.08, 0.07, q.y + 0.95 - g + 0.3, 5, 0.8)
		Buildings.beam_between(mb, PSXMat.lit("rope"), pa + Vector3.UP * 0.88, pb + Vector3.UP * 0.88, 0.03)
	body.add_child(mb.to_instance())
	_box(body, Vector3(w, 0.14, d3.length()), mid + basis * Vector3(0, -0.07, 0), basis)
	ctx.add(body)
	return body


## An eight-sided deck at height y over c (island space) on posts, railed round but for
## `gaps` (bearings where walkways and ramps meet it).
static func deck(ctx: KitContext, c: Vector2, r: float, y: float, gaps: Array) -> StaticBody3D:
	var body := _body("Deck")
	var mb := MeshBuilder.new()
	var planks := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	var palm := _palm()
	var rope := PSXMat.lit("rope")
	var corners: Array = []
	for i in range(8):
		var a := TAU * (i + 0.5) / 8.0
		corners.append(c + Vector2(cos(a), sin(a)) * r)
	var mid := Vector3(c.x, y, c.y)
	var pts := PackedVector3Array()
	for i in range(8):
		var p0: Vector2 = corners[i]
		var p1: Vector2 = corners[(i + 1) % 8]
		var v0 := Vector3(p0.x, y, p0.y)
		var v1 := Vector3(p1.x, y, p1.y)
		mb.add_tri(planks, mid, v0, v1, Vector3.UP, Vector3.UP, Vector3.UP, c * 0.5, p0 * 0.5, p1 * 0.5, Color.WHITE, Vector3.UP)
		mb.add_tri(planks, mid - Vector3.UP * 0.16, v0 - Vector3.UP * 0.16, v1 - Vector3.UP * 0.16, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, c * 0.5, p0 * 0.5, p1 * 0.5, Color(0.5, 0.5, 0.5), Vector3.DOWN)
		Buildings.beam_between(mb, dark, v0 - Vector3.UP * 0.1, v1 - Vector3.UP * 0.1, 0.2, 0.2)
		pts.append(v0)
		pts.append(v0 - Vector3.UP * 0.3)
		var g := ctx.hv(p0)
		mb.add_cylinder(palm, _xf(Vector3(p0.x, g - 0.3, p0.y)), 0.16, 0.14, y + 1.0 - g + 0.3, 6, 0.6)
		var inner := c + (p0 - c) * 0.45
		mb.add_cylinder(palm, _xf(Vector3(inner.x, ctx.hv(inner) - 0.3, inner.y)), 0.14, 0.13, y - ctx.hv(inner) + 0.2, 6, 0.6)
		var am := TAU * (i + 1) / 8.0
		if gaps.any(func(ga): return absf(angle_difference(am, float(ga))) < 0.4):
			continue
		for hh in [0.95, 0.5]:
			Buildings.beam_between(mb, rope if hh < 0.9 else dark, v0 + Vector3.UP * hh, v1 + Vector3.UP * hh, 0.05 if hh < 0.9 else 0.1)
		var rm := (v0 + v1) * 0.5
		_box(body, Vector3(v0.distance_to(v1), 1.0, 0.12), rm + Vector3.UP * 0.5, Basis(Vector3.UP, KitContext.face_yaw(Vector2(rm.x - c.x, rm.z - c.y))))
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	cs.shape = shape
	body.add_child(cs)
	ctx.add(body)
	return body


## A palisade of sharpened logs round c at radius r along `arcs` ([from, to] bearings,
## increasing), two rails inside; a collider per few metres. Island space.
## A palisade of sharpened logs along `arcs` of the circle (c, r), built in pieces (a frame
## each): palisade_body, then palisade_logs over palisade_angles in order (they share `rng`), then palisade_rails.
static func palisade_angles(r: float, arcs: Array) -> Array:
	var out: Array = []
	for arc in arcs:
		var a0: float = arc[0]
		var a1: float = arc[1]
		var n := maxi(int((a1 - a0) * r / 0.36), 1)
		for i in range(n + 1):
			out.append(a0 + (a1 - a0) * i / n)
	return out


static func palisade_body(ctx: KitContext) -> StaticBody3D:
	var body := _body("Palisade")
	ctx.add(body)
	return body


static func palisade_logs(ctx: KitContext, body: StaticBody3D, c: Vector2, r: float, angles: Array, rng: RandomNumberGenerator) -> void:
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("palm_bark", Color(0.85, 0.8, 0.75), {"affine": 0.6})
	var tip := PSXMat.lit("planks", Color(0.8, 0.7, 0.55))
	for a in angles:
		var q := c + Vector2(cos(a), sin(a)) * r
		var g := ctx.hv(q)
		var h := rng.randf_range(3.0, 3.7)
		var lean := Basis(Vector3(-sin(a), 0, cos(a)), rng.randf_range(-0.04, 0.04))
		mb.add_cylinder(bark, Transform3D(lean, Vector3(q.x, g - 0.4, q.y)), 0.17, 0.15, h + 0.4, 6, 0.6)
		mb.add_cone(tip, Transform3D(lean, Vector3(q.x, g - 0.4, q.y) + lean * Vector3(0, h + 0.4, 0)), 0.15, 0.42, 6, 1.0)
	body.add_child(mb.to_instance())


static func palisade_rails(ctx: KitContext, body: StaticBody3D, c: Vector2, r: float, arcs: Array) -> void:
	var mb := MeshBuilder.new()
	var dark := PSXMat.lit("planks_dark")
	for arc in arcs:
		var a0: float = arc[0]
		var a1: float = arc[1]
		var chunks := maxi(int((a1 - a0) * r / 3.0), 1)
		for k in range(chunks):
			var b0 := a0 + (a1 - a0) * k / chunks
			var b1 := a0 + (a1 - a0) * (k + 1) / chunks
			var q0 := c + Vector2(cos(b0), sin(b0)) * (r - 0.28)
			var q1 := c + Vector2(cos(b1), sin(b1)) * (r - 0.28)
			for hh in [1.0, 2.5]:
				Buildings.beam_between(mb, dark, Vector3(q0.x, ctx.hv(q0) + hh, q0.y), Vector3(q1.x, ctx.hv(q1) + hh, q1.y), 0.12)
			var bm := (b0 + b1) * 0.5
			var qm := c + Vector2(cos(bm), sin(bm)) * r
			_box(body, Vector3((b1 - b0) * r + 0.35, 3.8, 0.45), Vector3(qm.x, ctx.hv(qm) + 1.5, qm.y), Basis(Vector3.UP, KitContext.face_yaw(qm - c)))
	body.add_child(mb.to_instance())


## A gate in a palisade (the way through along local z): two great posts, lintels, a
## carved board, torches on the posts, a little thatch over it.
static func gate(width := 4.4) -> StaticBody3D:
	var body := _body("Gate")
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("palm_bark", Color(0.85, 0.8, 0.75), {"affine": 0.6})
	var dark := PSXMat.lit("planks_dark")
	var hw := width * 0.5 + 0.3
	for s in [-1.0, 1.0]:
		mb.add_cylinder(bark, _xf(Vector3(s * hw, -0.4, 0)), 0.3, 0.26, 5.2, 7, 0.6)
		mb.add_cone(PSXMat.lit("planks", Color(0.8, 0.7, 0.55)), _xf(Vector3(s * hw, 4.8, 0)), 0.27, 0.5, 7, 1.0)
		_cyl(body, 0.3, 5.0, Vector3(s * hw, -0.2, 0))
		_torch_into(mb, Vector3(s * (hw + 0.45), 0.0, 0.55), 2.3)
	mb.add_cylinder(bark, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(hw + 0.6, 4.25, 0)), 0.2, 0.2, hw * 2.0 + 1.2, 7, 0.6, Color.WHITE, true, true)
	mb.add_box(dark, _xf(Vector3(0, 3.75, 0)), Vector3(hw * 2.0 + 0.3, 0.18, 0.22), 0.6, Color.WHITE, false)
	mb.add_gable_roof(PSXMat.lit("thatch", Color.WHITE, {"affine": 0.8}), _xf(Vector3(0, 4.45, 0), PI * 0.5), 1.3, hw * 2.0 + 1.8, 0.55, 0.2, 0.6)
	var board := _xf(Vector3(0, 3.25, 0.16))
	mb.add_box(PSXMat.lit("planks", Color(0.85, 0.75, 0.6)), board, Vector3(1.8, 0.55, 0.06), 1.0)
	var paint := [PSXMat.flat(Color(0.7, 0.18, 0.12)), PSXMat.flat(Color(0.95, 0.85, 0.75))]
	for k in range(5):
		mb.add_box(paint[k % 2], board * _xf(Vector3(-0.6 + k * 0.3, 0.0, 0.04)), Vector3(0.14, 0.32 - (k % 2) * 0.12, 0.02), 1.0)
	for s in [-1.0, 1.0]:
		mb.add_box(PSXMat.lit("rope"), _xf(Vector3(s * 0.7, 3.6, 0.16)), Vector3(0.02, 0.25, 0.02), 1.0)
	body.add_child(mb.to_instance())
	return body


## An abandoned house: its footing, walls broken to stumps (some gone), the roof fallen
## in, vines over what's left, a sapling through the floor. Marker Cache (inside).
static func ruin(spec: Dictionary) -> StaticBody3D:
	var w: float = spec.get("w", 5.0)
	var d: float = spec.get("d", 4.2)
	var h := 2.4
	var found: float = spec.get("found", 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	var body := _body(str(spec.get("name", "Ruin")))
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.7, 0.75, 0.7))
	var wall := PSXMat.lit("planks_weathered")
	var palm := _palm()
	var leaves := PSXMat.lit("leaves", Color(0.7, 0.95, 0.65))
	var fl := 0.35
	mb.add_box(stone, _xf(Vector3(0, (fl - found) * 0.5, 0)), Vector3(w + 0.3, fl + found, d + 0.3), 0.5, Color.WHITE, true, false)
	_box(body, Vector3(w + 0.3, fl + found, d + 0.3), Vector3(0, (fl - found) * 0.5, 0))
	var sides := [[Vector3(0, 0, -d * 0.5), Vector3(1, 0, 0), w], [Vector3(-w * 0.5, 0, 0), Vector3(0, 0, 1), d],
		[Vector3(w * 0.5, 0, 0), Vector3(0, 0, 1), d], [Vector3(0, 0, d * 0.5), Vector3(1, 0, 0), w]]
	for si in range(4):
		var o: Vector3 = sides[si][0]
		var along: Vector3 = sides[si][1]
		var length: float = sides[si][2]
		var strips := int(length / 0.5)
		var sum := 0.0
		for k in range(strips):
			var x := -length * 0.5 + (k + 0.5) * length / strips
			if si == 3 and absf(x) < 0.7:
				continue
			if rng.randf() < 0.18:
				continue
			var edge := 1.0 - absf(x) / (length * 0.5)
			var sh := h * clampf(rng.randf_range(0.15, 0.7) + (1.0 - edge) * 0.4, 0.15, 1.0)
			sum += sh
			var shade := rng.randf_range(0.55, 0.85)
			var tb := Transform3D(Basis(Vector3.UP, 0.0 if along.x > 0.5 else PI * 0.5), o + along * x + Vector3(0, fl + sh * 0.5, 0))
			mb.add_box(wall, tb, Vector3(length / strips + 0.02, sh, 0.16), 0.5, Color(shade, shade, shade))
			if rng.randf() < 0.35:
				mb.add_blob(leaves, _xf(o + along * x + Vector3(0, fl + sh, 0)), Vector3(0.3, 0.22, 0.3), rng, 0.3, 2, 5)
		var avg := sum / strips
		_box(body, Vector3(length if along.x > 0.5 else 0.2, avg, 0.2 if along.x > 0.5 else length), o + Vector3(0, fl + avg * 0.5, 0))
	for x in [-w * 0.5, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]:
			mb.add_cylinder(palm, _xf(Vector3(x, fl, z)), 0.14, 0.12, rng.randf_range(0.8, h + 0.2), 6, 0.6)
	# the roof, fallen in against the back wall, and its rafters
	var roof := Transform3D(Basis(Vector3.RIGHT, 0.55), Vector3(rng.randf_range(-0.4, 0.4), fl + 0.95, -d * 0.1))
	mb.add_box(PSXMat.lit("thatch", Color(0.6, 0.55, 0.45), {"affine": 0.8}), roof, Vector3(w * 0.75, 0.14, d * 0.75), 0.5, Color.WHITE, false)
	var dark := PSXMat.lit("planks_dark")
	for k in range(3):
		var x := -w * 0.35 + k * w * 0.35
		Buildings.beam_between(mb, dark, Vector3(x, fl + h * 0.6, -d * 0.5 + 0.1), Vector3(x + rng.randf_range(-0.5, 0.5), fl + 0.05, d * 0.25 + rng.randf() * 0.6), 0.12)
	# a sapling grown up through the floor, weeds and vines
	var tp := Vector3(w * rng.randf_range(-0.25, 0.25), fl, d * 0.2)
	mb.add_cylinder(PSXMat.lit("bark"), _xf(tp), 0.1, 0.06, 3.4, 5, 1.0)
	mb.add_blob(leaves, _xf(tp + Vector3(0, 3.6, 0)), Vector3(1.3, 0.9, 1.3), rng, 0.3, 3, 7)
	for k in range(5):
		mb.add_blob(leaves, _xf(Vector3(rng.randf_range(-w, w) * 0.45, fl, rng.randf_range(-d, d) * 0.45)), Vector3(0.35, 0.25, 0.35), rng, 0.3, 2, 5)
	body.add_child(mb.to_instance())
	_marker(body, "Cache", Vector3(-w * 0.2, fl, -d * 0.15), 0.0)
	return body


## Broken stone, splintered planks and a staved-in barrel.
static func rubble(seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := _body("Rubble")
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("stone_brick", Color(0.7, 0.75, 0.7))
	for k in range(5):
		mb.add_blob(rock, _xf(Vector3(rng.randf_range(-0.6, 0.6), 0.1, rng.randf_range(-0.5, 0.5))), Vector3.ONE * rng.randf_range(0.18, 0.4), rng, 0.3, 2, 5, 1.0, Color.WHITE, -0.4)
	var wood := PSXMat.lit("planks_weathered")
	for k in range(3):
		mb.add_box(wood, Transform3D(Basis(Vector3.UP, rng.randf() * PI) * Basis(Vector3.BACK, rng.randf_range(-0.3, 0.3)), Vector3(rng.randf_range(-0.4, 0.4), 0.1 + k * 0.06, rng.randf_range(-0.4, 0.4))), Vector3(1.4, 0.06, 0.22), 1.0, Color(0.7, 0.7, 0.7), false)
	mb.add_cylinder(PSXMat.lit("planks_dark"), Transform3D(Basis(Vector3.BACK, 1.3), Vector3(0.5, 0.3, 0.3)), 0.34, 0.38, 0.55, 8, 1.2, Color(0.8, 0.8, 0.8), false)
	body.add_child(mb.to_instance())
	_box(body, Vector3(1.4, 0.5, 1.2), Vector3(0, 0.25, 0))
	return body


## The shared mesh of one kind of cargo (CARGO's keys), built once.
static func cargo_mesh(kind: String) -> ArrayMesh:
	if _cargo.has(kind):
		return _cargo[kind]
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		"crate":
			var s := 0.7
			mb.add_box(PSXMat.lit("planks", Color(0.9, 0.85, 0.75)), _xf(Vector3(0, s * 0.5, 0)), Vector3.ONE * s, 1.0 / s, Color.WHITE, true, false)
			for x in [-1, 1]:
				for z in [-1, 1]:
					mb.add_box(PSXMat.lit("planks_dark"), _xf(Vector3(x * s * 0.47, s * 0.5, z * s * 0.47)), Vector3(0.08, s + 0.02, 0.08), 1.0)
		"barrel":
			var wood := PSXMat.lit("planks_dark")
			var band := PSXMat.lit("metal", Color(0.55, 0.55, 0.6))
			mb.add_cylinder(wood, Transform3D.IDENTITY, 0.34, 0.38, 0.5, 8, 1.2, Color.WHITE, false)
			mb.add_cylinder(wood, _xf(Vector3(0, 0.5, 0)), 0.38, 0.34, 0.5, 8, 1.2, Color.WHITE, true)
			mb.add_cylinder(band, _xf(Vector3(0, 0.15, 0)), 0.36, 0.37, 0.06, 8, 1.0, Color.WHITE, false)
			mb.add_cylinder(band, _xf(Vector3(0, 0.8, 0)), 0.37, 0.36, 0.06, 8, 1.0, Color.WHITE, false)
		"jar":
			_jar(mb, PSXMat.lit("plaster", Color(0.75, 0.42, 0.25)), Transform3D.IDENTITY, 1.1)
		"basket":
			mb.add_cylinder(PSXMat.lit("straw"), Transform3D.IDENTITY, 0.2, 0.26, 0.3, 8, 1.0)
			var fruit := [Color(0.9, 0.55, 0.1), Color(0.85, 0.15, 0.12), Color(0.95, 0.85, 0.2)]
			for k in range(5):
				mb.add_blob(PSXMat.flat(fruit[k % 3]), _xf(Vector3(rng.randf_range(-0.1, 0.1), 0.32, rng.randf_range(-0.1, 0.1))), Vector3.ONE * 0.08, rng, 0.15, 2, 4)
		_:
			var canvas := PSXMat.lit("canvas", Color(0.82, 0.74, 0.56))
			mb.add_blob(canvas, _xf(Vector3(0, 0.28, 0)), Vector3(0.28, 0.3, 0.24), rng, 0.15, 4, 7, 1.5, Color.WHITE, -0.85)
			mb.add_cylinder(canvas, _xf(Vector3(0, 0.55, 0)), 0.09, 0.05, 0.12, 6, 1.0)
			mb.add_cylinder(PSXMat.lit("rope"), _xf(Vector3(0, 0.55, 0)), 0.095, 0.095, 0.03, 6, 1.0)
	_cargo[kind] = mb.commit()
	return _cargo[kind]
