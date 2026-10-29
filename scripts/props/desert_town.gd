class_name DesertTown
extends RefCounted
## The desert's town buildings (the royal-city and buried-town refs): flat-roofed plaster boxes in
## pastel washes on sandstone footings, parapets, arched doorways, small deep windows, roof beams
## poking through, domes in gold, green, blue and rose, minarets, striped awnings, outside stairs
## to the roof. One adobe material washed by vertex colour, so a street of colours is one surface.
## Front +Z, origin on the ground; footings reach FOOT below it for slopes. The village's kinds
## (DesertTheme's village_models) with the kit's markers: Door, Inside, Vendor/Customer,
## Bed/Table/Hearth (the rooms, furnished by KitHouses), Worker/Bench, Keeper/Pray, Cache.

const FOOT := 2.2
const WALL_T := 0.18
const DOOR_W := 1.3
const DOOR_H := 2.3
## The plaster washes: lilac, cream, salmon, mint, blue-grey, white, ochre.
const WASH := [Color(0.84, 0.72, 0.96), Color(1.0, 0.92, 0.74), Color(1.0, 0.74, 0.62), Color(0.72, 0.93, 0.78), Color(0.72, 0.83, 0.96),
	Color(1.0, 1.0, 0.97), Color(0.98, 0.8, 0.52)]
## A flat roof's plaster (vertex colour over the adobe).
const ROOF_COL := Color(0.86, 0.8, 0.72)
## Dome glazes: gold, green, blue, rose, turquoise.
const DOMES := [Color(1.0, 0.78, 0.3), Color(0.42, 0.72, 0.5), Color(0.42, 0.6, 0.92), Color(0.95, 0.62, 0.66), Color(0.4, 0.82, 0.85)]
const AWNINGS := ["awning_red", "awning_blue", "awning_gold", "awning_green"]
const STONE_COL := Color(0.92, 0.9, 0.86)
## The doors' wood (Buildings.door_leaf).
const DOOR_PAINT := Color(0.66, 0.5, 0.36)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


static func _body(n: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = n
	body.collision_layer = 1
	body.collision_mask = 0
	return body


static func _box(body: Node3D, size: Vector3, p: Vector3, basis := Basis()) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.transform = Transform3D(basis, p)
	body.add_child(cs)


static func _marker(parent: Node3D, n: String, p: Vector3, yaw := 0.0) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = p
	m.rotation.y = yaw
	parent.add_child(m)


static func _adobe() -> Material:
	return PSXMat.lit("adobe")


static func _stone() -> Material:
	return PSXMat.lit("sandstone")


static func _dark() -> Material:
	return PSXMat.flat(Color(0.12, 0.08, 0.06))


static func _beam() -> Material:
	return PSXMat.lit("planks_dark")


static func _window() -> ShaderMaterial:
	return PSXMat.lit("window", Color.WHITE, {"emission": Color(0.95, 0.72, 0.38), "emission_energy": 0.8, "emission_tex": "window"})


static func _glaze(c: Color) -> Material:
	return PSXMat.lit("glaze", c)


static func _brass() -> Material:
	return PSXMat.lit("metal", Color(1.05, 0.8, 0.42))


## A plaster block in its wash, in pieces no wider than 2.4 m (less texture warp on big faces).
static func _block(mb: MeshBuilder, c: Vector3, size: Vector3, col: Color) -> void:
	var adobe := _adobe()
	var nx := maxi(int(ceil(size.x / 2.4)), 1)
	var nz := maxi(int(ceil(size.z / 2.4)), 1)
	for ix in range(nx):
		for iz in range(nz):
			var p := c + Vector3(-size.x * 0.5 + (ix + 0.5) * size.x / nx, 0, -size.z * 0.5 + (iz + 0.5) * size.z / nz)
			mb.add_box(adobe, _xf(p), Vector3(size.x / nx + 0.002, size.y, size.z / nz + 0.002), 0.5, col)


## A round arch's top from (-w/2, spring) over to (w/2, spring), `n` segments.
static func _arch_top(w: float, spring: float, n := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(n + 1):
		var a := PI - PI * k / n
		pts.append(Vector2(cos(a) * w * 0.5, spring + sin(a) * w * 0.5))
	return pts


## An arched opening's outline: w wide, its crown at h.
static func _arch_shape(w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-w * 0.5, 0.0)])
	pts.append_array(_arch_top(w, h - w * 0.5))
	pts.append(Vector2(w * 0.5, 0.0))
	return pts


## A wall `ww` x `wh` (local x/y, `t` thick along local Z) with arched openings left open: `holes` [x, w, crown].
static func _arched_wall(mb: MeshBuilder, mat: Material, xf: Transform3D, ww: float, wh: float, holes: Array, t: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(-ww * 0.5, 0.0)])
	for hole in holes:
		var ox: float = hole[0]
		var dw: float = hole[1]
		pts.append(Vector2(ox - dw * 0.5, 0.0))
		for q in _arch_top(dw, float(hole[2]) - dw * 0.5):
			pts.append(q + Vector2(ox, 0.0))
		pts.append(Vector2(ox + dw * 0.5, 0.0))
	pts.append(Vector2(ww * 0.5, 0.0))
	pts.append(Vector2(ww * 0.5, wh))
	pts.append(Vector2(-ww * 0.5, wh))
	mb.add_extrude(mat, xf, pts, t, 0.5, col)


## A dark (or lit) arched recess framed in sandstone, a sill under it, on a wall at `xf` (+Z out).
static func _arch_recess(mb: MeshBuilder, xf: Transform3D, w: float, h: float, lit: bool) -> void:
	mb.add_extrude(_window() if lit else _dark(), xf * _xf(Vector3(0, 0, 0.01)), _arch_shape(w, h), 0.04, 1.0 / maxf(w, h))
	var rim := PackedVector3Array()
	for q in _arch_top(w + 0.12, h - w * 0.5, 8):
		rim.append(xf * Vector3(q.x, q.y, 0.04))
	mb.add_tube(_stone(), rim, 0.05, 0.05, 4, 1.0, STONE_COL)
	mb.add_box(_stone(), xf * _xf(Vector3(0, -0.04, 0.05)), Vector3(w + 0.24, 0.08, 0.12), 1.0, STONE_COL, false)


## A dome on a drum, its foot at `at`, `r` its radius: an onion (`onion`) or a round one, a brass finial.
static func dome(mb: MeshBuilder, at: Vector3, r: float, glaze: Color, onion: bool, drum := 0.5) -> void:
	mb.add_cylinder(_adobe(), _xf(at), r * 1.02, r * 1.02, drum, 12, 0.5, Color(0.95, 0.92, 0.88))
	mb.add_cylinder(_stone(), _xf(at + Vector3(0, drum, 0)), r * 1.08, r * 1.08, 0.08, 12, 0.8, STONE_COL, true, true)
	var rings: Array = []
	if onion:
		for e in [[0.0, 1.0], [0.25, 1.12], [0.5, 1.08], [0.75, 0.8], [0.95, 0.42], [1.15, 0.14], [1.3, 0.02]]:
			rings.append([float(e[0]) * r, float(e[1]) * r, float(e[1]) * r])
	else:
		for k in range(7):
			var a := PI * 0.5 * k / 6.0
			rings.append([sin(a) * r * 0.92, maxf(cos(a) * r, 0.02), maxf(cos(a) * r, 0.02)])
	mb.add_loft(_glaze(glaze), _xf(at + Vector3(0, drum + 0.08, 0)), rings, MeshBuilder.profile_circle(12), 0.6)
	var top: float = float(rings[rings.size() - 1][0]) + drum + 0.08
	var brass := _brass()
	mb.add_cylinder(brass, _xf(at + Vector3(0, top - 0.02, 0)), 0.03, 0.02, r * 0.5 + 0.3, 5, 1.0)
	mb.add_blob(brass, _xf(at + Vector3(0, top + r * 0.3, 0)), Vector3(0.08, 0.1, 0.08), _rng(7), 0.0, 3, 6)


## A parapet round a roof w x d centred at z, standing on y; a crenel row along the front now and then.
static func _parapet(mb: MeshBuilder, w: float, d: float, y: float, col: Color, crenel: bool, z := 0.0) -> void:
	var adobe := _adobe()
	var cope := _stone()
	var ph := 0.55
	for s in [-1.0, 1.0]:
		mb.add_box(adobe, _xf(Vector3(0, y + ph * 0.5, z + s * (d * 0.5 - 0.09))), Vector3(w, ph, 0.18), 0.5, col, false)
		mb.add_box(adobe, _xf(Vector3(s * (w * 0.5 - 0.09), y + ph * 0.5, z)), Vector3(0.18, ph, d - 0.36), 0.5, col, false)
		mb.add_box(cope, _xf(Vector3(0, y + ph + 0.03, z + s * (d * 0.5 - 0.09))), Vector3(w + 0.06, 0.06, 0.24), 0.8, STONE_COL)
		mb.add_box(cope, _xf(Vector3(s * (w * 0.5 - 0.09), y + ph + 0.03, z)), Vector3(0.24, 0.06, d - 0.3), 0.8, STONE_COL)
	if crenel:
		var n := int(w / 0.7)
		for k in range(0, n, 2):
			mb.add_box(adobe, _xf(Vector3(-w * 0.5 + (k + 0.5) * w / n, y + ph + 0.22, z + d * 0.5 - 0.09)), Vector3(w / n, 0.38, 0.18), 0.5, col)


## Roof beams poking out of the front wall under the parapet.
static func _vigas(mb: MeshBuilder, w: float, z: float, y: float) -> void:
	var beam := _beam()
	var n := int(w / 0.75)
	for k in range(n):
		mb.add_cylinder(beam, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-w * 0.5 + (k + 0.5) * w / n, y, z - 0.1)), 0.07, 0.07, 0.42, 5, 1.0, Color(0.9, 0.85, 0.8), true, true)


## A striped awning over the front on two poles.
static func _awning(mb: MeshBuilder, tex: String, w: float, z0: float, y: float, out: float, x := 0.0) -> void:
	var cloth := PSXMat.lit(tex, Color.WHITE, {"affine": 0.6})
	var a0 := Vector3(x - w * 0.5, y, z0)
	var a1 := Vector3(x + w * 0.5, y, z0)
	var a2 := Vector3(x + w * 0.5, y - 0.5, z0 + out)
	var a3 := Vector3(x - w * 0.5, y - 0.5, z0 + out)
	var n := Vector3(0, out, 0.5).normalized()
	mb.add_quad(cloth, a0, a1, a2, a3, Vector2.ZERO, Vector2(w * 0.5, 0), Vector2(w * 0.5, 0.9), Vector2(0, 0.9), Color.WHITE, n)
	mb.add_quad(cloth, a0, a3, a2, a1, Vector2.ZERO, Vector2(0, 0.9), Vector2(w * 0.5, 0.9), Vector2(w * 0.5, 0), Color(0.6, 0.6, 0.6), -n)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(_beam(), _xf(Vector3(x + s * w * 0.5, 0.0, z0 + out)), 0.05, 0.05, y - 0.5, 5, 1.0)


## Small deep windows along a wall (`xf` at the wall's foot and middle, +Z out), kept off x = `skip` (the door).
static func _windows(mb: MeshBuilder, xf: Transform3D, w: float, y: float, rng: RandomNumberGenerator, skip := INF, arched := false, lit_p := 0.35) -> void:
	var n := maxi(int(w / 1.9), 1)
	for k in range(n):
		var x := -w * 0.5 + (k + 0.5) * w / n
		if absf(x - skip) < 1.1:
			continue
		var lit := rng.randf() < lit_p
		if arched:
			_arch_recess(mb, xf * _xf(Vector3(x, y - 0.45, 0)), 0.55, 0.95, lit)
		else:
			mb.add_box_unit_uv(_window() if lit else _dark(), xf * _xf(Vector3(x, y, 0.0)), Vector3(0.5, 0.55, 0.05))
			mb.add_box(_stone(), xf * _xf(Vector3(x, y - 0.32, 0.04)), Vector3(0.66, 0.07, 0.12), 1.0, STONE_COL, false)


## A sandstone footing w x d from FOOT below the ground up to `fl`, and its collider.
static func _footing(mb: MeshBuilder, body: Node3D, w: float, d: float, fl: float) -> void:
	mb.add_box(_stone(), _xf(Vector3(0, (fl - FOOT) * 0.5, 0)), Vector3(w, fl + FOOT, d), 0.5, Color(0.88, 0.85, 0.8), true, false)
	_box(body, Vector3(w, fl + FOOT, d), Vector3(0, (fl - FOOT) * 0.5, 0))


## A flat-roofed house in a pastel wash: one storey, or two with the upper set back on the roof terrace;
## a parapet, an arched doorway, small deep windows, roof beams, maybe a dome, a rooftop shade, an awning
## or an outside stair to the roof. spec: w, d, storeys, dome (chance), seed, name; optionally lit (each window's
## chance of a lamp in it, 0.35; an abandoned house's 0).
static func house(spec: Dictionary) -> StaticBody3D:
	var rng := _rng(int(spec["seed"]))
	var w: float = spec["w"]
	var d: float = spec["d"]
	var storeys: int = spec["storeys"]
	var h := rng.randf_range(2.9, 3.4)
	var fl := 0.3
	var col: Color = WASH[rng.randi() % WASH.size()]
	var body := _body(str(spec["name"]))
	var mb := MeshBuilder.new()
	var stone := _stone()
	_footing(mb, body, w + 0.3, d + 0.3, fl)
	_block(mb, Vector3(0, fl + h * 0.5, 0), Vector3(w, h, d), col)
	_box(body, Vector3(w, h, d), Vector3(0, fl + h * 0.5, 0))
	body.add_child(Occluders.box_node(_xf(Vector3(0, fl + h * 0.5, 0)), Vector3(w, h, d)))
	var top := fl + h
	_parapet(mb, w, d, top, col, rng.randf() < 0.35)
	if rng.randf() < 0.6:
		_vigas(mb, w, d * 0.5 + 0.1, top - 0.3)
	# the door, a little off-centre, its arch framed in sandstone, a step before it
	var dx := rng.randf_range(-w * 0.18, w * 0.18)
	_arch_recess(mb, _xf(Vector3(dx, fl, d * 0.5)), DOOR_W - 0.2, DOOR_H, false)
	mb.add_box_unit_uv(Buildings.door_leaf(DOOR_PAINT), _xf(Vector3(dx, fl + 0.95, d * 0.5 + 0.035)), Vector3(DOOR_W - 0.32, 1.9, 0.04))
	Buildings.door_steps(body, mb, stone, dx, d * 0.5 + 0.15, fl, 1.5, 0.45, FOOT)
	var lp: float = spec.get("lit", 0.35)
	_windows(mb, _xf(Vector3(0, fl, d * 0.5 + 0.005)), w, 1.75, rng, dx, rng.randf() < 0.4, lp)
	_windows(mb, _xf(Vector3(-w * 0.5 - 0.005, fl, 0), -PI * 0.5), d, 1.75, rng, INF, false, lp)
	_windows(mb, _xf(Vector3(w * 0.5 + 0.005, fl, 0), PI * 0.5), d, 1.75, rng, INF, false, lp)
	_windows(mb, _xf(Vector3(0, fl, -d * 0.5 - 0.005), PI), w, 1.75, rng, INF, false, lp)
	# the upper storey, set back on the roof terrace
	var roof_y := top
	var rw := w
	var rd := d
	var rx := dx
	var rz := 0.0
	if storeys > 1:
		rw = w * rng.randf_range(0.55, 0.78)
		rd = d * rng.randf_range(0.55, 0.75)
		rz = -(d - rd) * 0.5 + 0.1
		rx = (w - rw) * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf()
		var h2 := rng.randf_range(2.5, 2.9)
		var col2 := col.darkened(0.04)
		_block(mb, Vector3(rx, top + h2 * 0.5, rz), Vector3(rw, h2, rd), col2)
		_box(body, Vector3(rw, h2, rd), Vector3(rx, top + h2 * 0.5, rz))
		var up := _xf(Vector3(rx, top, rz))
		mb.add_box(_dark(), up * _xf(Vector3(0, 1.0, rd * 0.5 + 0.01)), Vector3(0.9, 2.0, 0.04), 1.0)
		_windows(mb, up * _xf(Vector3(0, 0, rd * 0.5 + 0.005)), rw, 1.6, rng, 0.0, true, lp)
		_windows(mb, up * _xf(Vector3(0, 0, -rd * 0.5 - 0.005), PI), rw, 1.6, rng, INF, false, lp)
		_parapet(mb, rw, rd, top + h2, col2, false, rz)
		roof_y = top + h2
	# a dome on the top roof, or a canvas shade on four poles
	if rng.randf() < float(spec["dome"]):
		var dr := minf(rw, rd) * rng.randf_range(0.26, 0.34)
		dome(mb, Vector3(rx * 0.5, roof_y, rz), dr, DOMES[rng.randi() % DOMES.size()], rng.randf() < 0.4, 0.45)
	elif rng.randf() < 0.35:
		var cw := minf(rw, 2.6)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				mb.add_cylinder(_beam(), _xf(Vector3(rx + sx * cw * 0.42, roof_y, rz + sz * cw * 0.32)), 0.04, 0.04, 2.0, 4, 1.0)
		mb.add_box(PSXMat.lit(AWNINGS[rng.randi() % AWNINGS.size()], Color.WHITE, {"affine": 0.6}), _xf(Vector3(rx, roof_y + 2.0, rz)), Vector3(cw, 0.04, cw * 0.8), 0.6, Color.WHITE, false)
	# a striped awning over the door, or an outside stair up to the roof
	if storeys == 1 and rng.randf() < 0.4:
		_stair(mb, body, w, d, fl, top, 1.0 if rng.randf() < 0.5 else -1.0)
	elif rng.randf() < 0.45:
		var aw := minf(w - 0.6, 3.2)
		_awning(mb, AWNINGS[rng.randi() % AWNINGS.size()], aw, d * 0.5 + 0.05, fl + 2.7, 1.5, clampf(dx, -(w - aw) * 0.5 + 0.1, (w - aw) * 0.5 - 0.1))
	body.add_child(mb.to_instance("HouseMesh"))
	return body


## An outside stair along a side wall (side +1 right, -1 left) up to the roof terrace, a ramp under it.
static func _stair(mb: MeshBuilder, body: Node3D, w: float, d: float, fl: float, top: float, side: float) -> void:
	var stone := _stone()
	var x := side * (w * 0.5 + 0.55)
	var n := int(ceil(top / 0.25))
	var run := d * 0.85
	for i in range(n):
		var y := (i + 1) * (top / n)
		mb.add_box(stone, _xf(Vector3(x, y * 0.5, d * 0.5 - 0.2 - (i + 0.5) * run / n)), Vector3(1.0, y, run / n + 0.02), 0.6, STONE_COL)
	_box(body, Vector3(1.0, 0.1, Vector2(run, top).length()), Vector3(x, top * 0.5, d * 0.5 - 0.2 - run * 0.5), Basis(Vector3.RIGHT, atan2(top, run)))


## A room you walk into (a home, the trader's store, the cookhouse): a plaster box on a footing, a flat
## roof and parapet, an arched doorway, windows through the walls, the kit's furnishing (KitHouses).
## Markers: Door, Inside and the kind's own. `size` is its width.
static func room(kind: String, seed_value: int, size: float) -> StaticBody3D:
	var rng := _rng(seed_value)
	var w := size
	var d := snappedf(size * 0.82, 0.1)
	var h := 3.0
	var fl := 0.35
	var t := WALL_T
	var col: Color = WASH[rng.randi() % WASH.size()]
	var body := _body("Home")
	var mb := MeshBuilder.new()
	var adobe := _adobe()
	var stone := _stone()
	_footing(mb, body, w + 0.3, d + 0.3, fl)
	mb.add_quad(PSXMat.lit("planks"), Vector3(-w * 0.5, fl + 0.01, -d * 0.5), Vector3(w * 0.5, fl + 0.01, -d * 0.5), Vector3(w * 0.5, fl + 0.01, d * 0.5), Vector3(-w * 0.5, fl + 0.01, d * 0.5),
		Vector2.ZERO, Vector2(w * 0.5, 0), Vector2(w * 0.5, d * 0.5), Vector2(0, d * 0.5), Color(0.85, 0.8, 0.75), Vector3.UP)
	# the back and the sides as boxes, the front round its arched doorway
	for wl in [[Vector3(0, 0, -d * 0.5 + t * 0.5), Vector3(w, h, t)], [Vector3(-w * 0.5 + t * 0.5, 0, 0), Vector3(t, h, d)], [Vector3(w * 0.5 - t * 0.5, 0, 0), Vector3(t, h, d)]]:
		var c: Vector3 = wl[0]
		_block(mb, Vector3(c.x, fl + h * 0.5, c.z), wl[1], col)
		_box(body, wl[1], Vector3(c.x, fl + h * 0.5, c.z))
	var crown := DOOR_H + 0.25
	_arched_wall(mb, adobe, _xf(Vector3(0, fl, d * 0.5 - t * 0.5)), w, h, [[0.0, DOOR_W, crown]], t, col)
	var side_w := (w - DOOR_W) * 0.5
	for s in [-1.0, 1.0]:
		_box(body, Vector3(side_w, h, t), Vector3(s * (w * 0.5 - side_w * 0.5), fl + h * 0.5, d * 0.5 - t * 0.5))
	_box(body, Vector3(DOOR_W, h - crown, t), Vector3(0, fl + crown + (h - crown) * 0.5, d * 0.5 - t * 0.5))
	var rim := PackedVector3Array()
	for q in _arch_top(DOOR_W + 0.14, crown - DOOR_W * 0.5, 8):
		rim.append(Vector3(q.x, fl + q.y, d * 0.5 + 0.03))
	mb.add_tube(stone, rim, 0.07, 0.07, 4, 1.0, STONE_COL)
	var jamb := crown - DOOR_W * 0.5
	for s in [-1.0, 1.0]:
		mb.add_box(stone, _xf(Vector3(s * (DOOR_W * 0.5 + 0.07), fl + jamb * 0.5, d * 0.5 + 0.03)), Vector3(0.14, jamb, 0.1), 1.0, STONE_COL)
	var run := Buildings.door_steps(body, mb, stone, 0.0, d * 0.5 + 0.15, fl, 1.8, 0.45, FOOT)
	# its door stands open inside, swung back against the wall
	var hinge := Vector3(-DOOR_W * 0.5 + 0.05, fl + 1.0, d * 0.5 - t - 0.04)
	mb.add_box_unit_uv(Buildings.door_leaf(DOOR_PAINT), Transform3D(Basis(Vector3.UP, 2.55), hinge) * _xf(Vector3(DOOR_W * 0.5 - 0.06, 0, 0)), Vector3(DOOR_W - 0.12, 2.0, 0.05))
	# windows through the walls (lit both sides), deep sills outside
	var win := _window()
	for wx in [_xf(Vector3(-w * 0.5 + t * 0.5, fl + 1.55, 0), -PI * 0.5), _xf(Vector3(w * 0.5 - t * 0.5, fl + 1.55, 0), PI * 0.5), _xf(Vector3(w * 0.25, fl + 1.55, -d * 0.5 + t * 0.5), PI)]:
		mb.add_box_unit_uv(win, wx, Vector3(0.6, 0.6, t + 0.06))
		mb.add_box(stone, wx * _xf(Vector3(0, -0.36, 0.12)), Vector3(0.76, 0.07, t + 0.16), 1.0, STONE_COL, false)
	# the roof: a slab, beams across it seen from inside, the parapet round it
	mb.add_box(adobe, _xf(Vector3(0, fl + h + 0.06, 0)), Vector3(w + 0.1, 0.14, d + 0.1), 0.5, ROOF_COL, false)
	for k in range(4):
		mb.add_cylinder(_beam(), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-w * 0.375 + k * w * 0.25, fl + h - 0.1, -d * 0.5)), 0.08, 0.08, d, 5, 1.0, Color(0.8, 0.75, 0.7), false, false)
	_parapet(mb, w, d, fl + h + 0.13, col, rng.randf() < 0.3)
	_vigas(mb, w, d * 0.5 + 0.1, fl + h - 0.3)
	if kind != "home":
		_awning(mb, AWNINGS[rng.randi() % AWNINGS.size()], minf(w - 0.4, 3.6), d * 0.5 + 0.05, fl + 2.85, 1.6)
		_sign(mb, w, d, fl, kind)
	if rng.randf() < 0.3:
		dome(mb, Vector3(-w * 0.2, fl + h + 0.13, -d * 0.15), minf(w, d) * 0.22, DOMES[rng.randi() % DOMES.size()], rng.randf() < 0.5, 0.4)
	Buildings.wall_lantern(mb, Vector3(DOOR_W * 0.5 + 0.5, fl + 2.0, d * 0.5), _beam())
	body.add_child(mb.to_instance("RoomMesh"))
	# inside: the kit's furnishing, a hanging lamp and a kilim (its own mesh, drawn only near)
	var imb := MeshBuilder.new()
	imb.add_box(_brass(), _xf(Vector3(0, fl + h - 0.35, 0)), Vector3(0.03, 0.5, 0.03), 1.0)
	imb.add_box(PSXMat.glow(Color(1.0, 0.75, 0.4), 2.2), _xf(Vector3(0, fl + h - 0.75, 0)), Vector3(0.2, 0.26, 0.2), 1.0)
	imb.add_pyramid_roof(_brass(), _xf(Vector3(0, fl + h - 0.62, 0)), 0.24, 0.24, 0.16, 0.02, 1.0)
	match kind:
		"trade":
			KitHouses._trade_inside(body, imb, w, d, fl, rng)
		"cook":
			KitHouses._cook_inside(body, imb, w, d, fl, fl + h + 0.7, rng)
		"home":
			KitHouses._home_inside(body, imb, w, d, fl, rng)
		_:
			KitShops.inside(kind, body, imb, w, d, fl, h, rng, {"counter": [adobe, col], "top": [stone, STONE_COL]})
	if kind in ["trade", "cook", "home"]:
		imb.add_quad(PSXMat.lit("rug_kilim"), Vector3(-0.9, fl + 0.02, -0.4), Vector3(0.9, fl + 0.02, -0.4), Vector3(0.9, fl + 0.02, 0.9), Vector3(-0.9, fl + 0.02, 0.9),
			Vector2.ZERO, Vector2(1, 0), Vector2(1, 0.7), Vector2(0, 0.7), Color.WHITE, Vector3.UP)
	var inside := imb.to_instance("Furnishing")
	inside.visibility_range_end = 45.0
	body.add_child(inside)
	_marker(body, "Door", Vector3(0, 0, d * 0.5 + 0.15 + run + 0.4), 0.0)
	_marker(body, "Inside", Vector3(0, fl, 0.4), 0.0)
	return body


## A board on a bracket by the door: a fish (the cookhouse) or coins (the store).
static func _sign(mb: MeshBuilder, w: float, d: float, fl: float, kind: String) -> void:
	var x := w * 0.5 - 0.45
	mb.add_box(_beam(), _xf(Vector3(x, fl + 2.55, d * 0.5 + 0.35)), Vector3(0.06, 0.06, 0.7), 1.0, Color.WHITE, false)
	var board := _xf(Vector3(x, fl + 2.2, d * 0.5 + 0.6), PI * 0.5)
	if kind == "cook":
		mb.add_box_unit_uv(PSXMat.lit("sign_fish", Color.WHITE, {"vertex_color": false}), board, Vector3(0.9, 0.45, 0.06))
		return
	mb.add_box(PSXMat.lit("planks"), board, Vector3(0.9, 0.45, 0.06), 1.0)
	var gold := PSXMat.flat(Color(0.95, 0.75, 0.25))
	for s in [-1.0, 1.0]:
		for k in range(3):
			mb.add_cylinder(gold, board * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.22 + k * 0.2, -0.05 + (k % 2) * 0.1, s * 0.04)), 0.08, 0.08, 0.015, 8, 1.0)


## The caravanserai (the inn): a two-storey block behind an arcade of three arches, a gallery on the
## arcade's roof, a dome on the block, lanterns hung in the arches, the tavern's board.
static func inn(seed_value: int, w: float, d: float) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := _body("Inn")
	var mb := MeshBuilder.new()
	var stone := _stone()
	var col: Color = [Color(1.0, 0.95, 0.85), Color(0.98, 0.86, 0.66), Color(1.0, 0.82, 0.72)][rng.randi() % 3]
	var fl := 0.35
	var h1 := 3.2
	var h2 := 2.8
	var ad := 2.2
	var bd := d - ad
	var bz := -ad * 0.5
	_footing(mb, body, w + 0.4, d + 0.4, fl)
	_block(mb, Vector3(0, fl + (h1 + h2) * 0.5, bz), Vector3(w, h1 + h2, bd), col)
	_box(body, Vector3(w, h1 + h2, bd), Vector3(0, fl + (h1 + h2) * 0.5, bz))
	# the arcade: three arches on piers, its sides closed, its roof the gallery's floor
	var aw := w / 3.0
	var holes: Array = []
	for k in range(3):
		holes.append([-w * 0.5 + aw * (k + 0.5), aw - 0.7, h1 - 0.5])
	_arched_wall(mb, _adobe(), _xf(Vector3(0, fl, d * 0.5 - 0.15)), w, h1, holes, 0.3, col)
	for k in range(4):
		var px := clampf(-w * 0.5 + aw * k, -w * 0.5 + 0.35, w * 0.5 - 0.35)
		_box(body, Vector3(0.7, h1, 0.3), Vector3(px, fl + h1 * 0.5, d * 0.5 - 0.15))
	mb.add_box(_adobe(), _xf(Vector3(0, fl + h1 + 0.08, d * 0.5 - ad * 0.5)), Vector3(w, 0.16, ad), 0.5, ROOF_COL, false)
	for s in [-1.0, 1.0]:
		mb.add_box(_adobe(), _xf(Vector3(s * (w * 0.5 - 0.15), fl + h1 * 0.5, d * 0.5 - ad * 0.5)), Vector3(0.3, h1, ad), 0.5, col)
		_box(body, Vector3(0.3, h1, ad), Vector3(s * (w * 0.5 - 0.15), fl + h1 * 0.5, d * 0.5 - ad * 0.5))
	# under the arcade: the door, a bench, a kilim, lanterns hung in the arches
	Buildings.panel_door(mb, _xf(Vector3(0, fl, bz + bd * 0.5)), 1.4, 2.1, Buildings.door_leaf(DOOR_PAINT), stone)
	Buildings.door_steps(body, mb, stone, 0.0, d * 0.5 + 0.2, fl, aw - 0.9, 0.0, FOOT)
	var glow := PSXMat.glow(Color(1.0, 0.75, 0.4), 2.2)
	for hole in holes:
		mb.add_box(_brass(), _xf(Vector3(hole[0], fl + h1 - 0.6, d * 0.5 - 0.3)), Vector3(0.03, 0.4, 0.03), 1.0)
		mb.add_box(glow, _xf(Vector3(hole[0], fl + h1 - 0.95, d * 0.5 - 0.3)), Vector3(0.18, 0.26, 0.18), 1.0)
	mb.add_box(_beam(), _xf(Vector3(-w * 0.3, fl + 0.45, bz + bd * 0.5 + 0.35)), Vector3(w * 0.3, 0.08, 0.4), 1.0, Color.WHITE, false)
	mb.add_quad(PSXMat.lit("rug_kilim"), Vector3(-1.2, fl + 0.02, d * 0.5 - ad + 0.2), Vector3(1.2, fl + 0.02, d * 0.5 - ad + 0.2), Vector3(1.2, fl + 0.02, d * 0.5 - 0.5), Vector3(-1.2, fl + 0.02, d * 0.5 - 0.5),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 0.8), Vector2(0, 0.8), Color.WHITE, Vector3.UP)
	# the gallery: a balustrade along the arcade's roof, arched windows behind it
	var gy := fl + h1 + 0.16
	for k in range(int(w / 0.5)):
		mb.add_cylinder(stone, _xf(Vector3(-w * 0.5 + 0.25 + k * 0.5, gy, d * 0.5 - 0.15)), 0.07, 0.07, 0.75, 5, 1.0, STONE_COL)
	mb.add_box(stone, _xf(Vector3(0, gy + 0.8, d * 0.5 - 0.15)), Vector3(w, 0.1, 0.25), 0.8, STONE_COL)
	_windows(mb, _xf(Vector3(0, gy, bz + bd * 0.5 + 0.005)), w, 1.4, rng, INF, true)
	_windows(mb, _xf(Vector3(0, fl, -d * 0.5 - 0.005), PI), w, 1.6, rng)
	_parapet(mb, w, bd, fl + h1 + h2, col, true, bz)
	dome(mb, Vector3(w * 0.25, fl + h1 + h2, bz - bd * 0.1), minf(w, bd) * 0.28, DOMES[rng.randi() % DOMES.size()], rng.randf() < 0.5, 0.6)
	mb.add_box_unit_uv(PSXMat.lit("sign_tavern", Color.WHITE, {"vertex_color": false}), _xf(Vector3(-w * 0.32, fl + h1 + 0.6, d * 0.5 + 0.02)), Vector3(1.2, 0.6, 0.06))
	body.add_child(mb.to_instance("InnMesh"))
	return body


## The potter's workshop: two wide arches open on its front, a kiln (a mud dome, its mouth aglow) and
## a wheel inside, jars on a shelf and drying on the floor. Markers: Worker (at the wheel), Bench (the jars).
static func workshop(seed_value: int, size: float) -> StaticBody3D:
	var rng := _rng(seed_value)
	var w := maxf(size, 6.0)
	var d := 4.6
	var h := 3.0
	var fl := 0.2
	var col: Color = WASH[rng.randi() % WASH.size()]
	var body := _body("Workshop")
	var mb := MeshBuilder.new()
	_footing(mb, body, w + 0.3, d + 0.3, fl)
	for wl in [[Vector3(0, 0, -d * 0.5 + 0.15), Vector3(w, h, 0.3)], [Vector3(-w * 0.5 + 0.15, 0, 0), Vector3(0.3, h, d)], [Vector3(w * 0.5 - 0.15, 0, 0), Vector3(0.3, h, d)]]:
		var c: Vector3 = wl[0]
		_block(mb, Vector3(c.x, fl + h * 0.5, c.z), wl[1], col)
		_box(body, wl[1], Vector3(c.x, fl + h * 0.5, c.z))
	_arched_wall(mb, _adobe(), _xf(Vector3(0, fl, d * 0.5 - 0.15)), w, h, [[-w * 0.25, w * 0.5 - 0.8, h - 0.4], [w * 0.25, w * 0.5 - 0.8, h - 0.4]], 0.3, col)
	_box(body, Vector3(0.8, h, 0.3), Vector3(0, fl + h * 0.5, d * 0.5 - 0.15))
	for s in [-1.0, 1.0]:
		Buildings.door_steps(body, mb, _stone(), s * w * 0.25, d * 0.5 + 0.15, fl, w * 0.5 - 1.2, 0.0, FOOT)
	mb.add_box(_adobe(), _xf(Vector3(0, fl + h + 0.06, 0)), Vector3(w + 0.1, 0.14, d + 0.1), 0.5, ROOF_COL, false)
	_parapet(mb, w, d, fl + h + 0.13, col, false)
	var kp := Vector3(-w * 0.5 + 1.2, fl, -d * 0.5 + 1.1)
	mb.add_blob(PSXMat.lit("adobe", Color(0.85, 0.6, 0.45)), _xf(kp), Vector3(0.9, 1.0, 0.9), rng, 0.08, 4, 8, 0.6, Color.WHITE, 0.0)
	mb.add_box(PSXMat.glow(Color(1.0, 0.5, 0.15), 2.5), _xf(kp + Vector3(0.0, 0.3, 0.86)), Vector3(0.4, 0.35, 0.05), 1.0)
	_box(body, Vector3(1.8, 1.0, 1.8), kp + Vector3(0, 0.5, 0))
	FX.chimney_smoke(body, kp + Vector3(0, h + 0.8, 0))
	var wp := Vector3(0.6, fl, 0.4)
	mb.add_cylinder(_beam(), _xf(wp), 0.12, 0.12, 0.6, 6, 1.0)
	mb.add_cylinder(PSXMat.lit("planks"), _xf(wp + Vector3(0, 0.6, 0)), 0.4, 0.4, 0.06, 10, 1.0)
	mb.add_cylinder(PSXMat.lit("adobe", Color(0.8, 0.55, 0.4)), _xf(wp + Vector3(0, 0.66, 0)), 0.14, 0.18, 0.22, 8, 1.0)
	_box(body, Vector3(0.8, 0.7, 0.8), wp + Vector3(0, 0.35, 0))
	var bp := Vector3(w * 0.5 - 1.5, fl, -d * 0.5 + 0.45)
	mb.add_box(PSXMat.lit("planks"), _xf(bp + Vector3(0, 0.9, 0)), Vector3(2.2, 0.06, 0.4), 1.0, Color.WHITE, false)
	var clay := PSXMat.lit("adobe", Color(0.85, 0.55, 0.38))
	for k in range(5):
		KitHouses._jar(mb, clay, _xf(bp + Vector3(-0.9 + k * 0.45, 0.93, 0)), 0.8)
		KitHouses._jar(mb, clay, _xf(bp + Vector3(-0.9 + k * 0.45, 0.0, 0.3)), 1.1)
	_box(body, Vector3(2.2, 0.95, 0.6), bp + Vector3(0, 0.47, 0.1))
	body.add_child(mb.to_instance("WorkshopMesh"))
	_marker(body, "Worker", wp + Vector3(0, 0, 0.75), PI)
	_marker(body, "Bench", bp + Vector3(0, 0, 0.9), PI)
	return body


## The shrine: a little white cube open under an arch, corner pinnacles, a dome; a niche and a lamp
## inside, a prayer rug. Markers: Keeper (beside the arch), Pray (before it).
static func shrine(seed_value: int) -> StaticBody3D:
	var rng := _rng(seed_value)
	var s := 3.6
	var h := 3.2
	var fl := 0.3
	var col := Color(1.0, 0.98, 0.94)
	var body := _body("Shrine")
	var mb := MeshBuilder.new()
	var stone := _stone()
	_footing(mb, body, s + 0.6, s + 0.6, fl)
	for wl in [[Vector3(0, 0, -s * 0.5 + 0.15), Vector3(s, h, 0.3)], [Vector3(-s * 0.5 + 0.15, 0, 0), Vector3(0.3, h, s)], [Vector3(s * 0.5 - 0.15, 0, 0), Vector3(0.3, h, s)]]:
		var c: Vector3 = wl[0]
		mb.add_box(_adobe(), _xf(Vector3(c.x, fl + h * 0.5, c.z)), wl[1], 0.5, col)
		_box(body, wl[1], Vector3(c.x, fl + h * 0.5, c.z))
	_arched_wall(mb, _adobe(), _xf(Vector3(0, fl, s * 0.5 - 0.15)), s, h, [[0.0, 1.8, 2.7]], 0.3, col)
	for x in [-1.0, 1.0]:
		_box(body, Vector3(0.9, h, 0.3), Vector3(x * (s * 0.5 - 0.45), fl + h * 0.5, s * 0.5 - 0.15))
	mb.add_box(stone, _xf(Vector3(0, fl + h + 0.06, 0)), Vector3(s + 0.2, 0.14, s + 0.2), 0.5, Color(0.9, 0.88, 0.85), false)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			mb.add_box(_adobe(), _xf(Vector3(cx * (s * 0.5 - 0.15), fl + h + 0.4, cz * (s * 0.5 - 0.15))), Vector3(0.3, 0.7, 0.3), 0.5, col)
	dome(mb, Vector3(0, fl + h + 0.13, 0), s * 0.4, DOMES[rng.randi() % DOMES.size()], rng.randf() < 0.5, 0.4)
	_arch_recess(mb, _xf(Vector3(0, fl + 0.4, -s * 0.5 + 0.31)), 0.9, 1.6, false)
	mb.add_box(PSXMat.glow(Color(1.0, 0.75, 0.4), 2.4), _xf(Vector3(0, fl + 0.6, -s * 0.5 + 0.5)), Vector3(0.16, 0.2, 0.16), 1.0)
	mb.add_quad(PSXMat.lit("rug_kilim"), Vector3(-0.8, fl + 0.02, -0.9), Vector3(0.8, fl + 0.02, -0.9), Vector3(0.8, fl + 0.02, 0.9), Vector3(-0.8, fl + 0.02, 0.9),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3.UP)
	mb.add_box(stone, _xf(Vector3(0, fl * 0.5, s * 0.5 + 0.6)), Vector3(2.2, fl, 1.2), 0.6, Color(0.9, 0.88, 0.85))
	body.add_child(mb.to_instance("ShrineMesh"))
	_marker(body, "Keeper", Vector3(1.3, 0.0, s * 0.5 + 0.9), atan2(-1.3, -0.9))
	_marker(body, "Pray", Vector3(0, 0.0, s * 0.5 + 1.6), PI)
	return body


## A granary: two or three beehive domes of mud, each with a small door.
static func storehouse(seed_value: int, size: float) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := _body("Storehouse")
	var mb := MeshBuilder.new()
	var mud := PSXMat.lit("adobe", Color(0.92, 0.78, 0.6))
	var n := 2 + (1 if rng.randf() < 0.5 else 0)
	for k in range(n):
		var a := TAU * k / n + rng.randf() * 0.5
		var c := Vector3(cos(a), 0, sin(a)) * size * 0.22
		var r := size * rng.randf_range(0.24, 0.3)
		var hh := r * rng.randf_range(1.6, 2.0)
		var sink := FOOT * 0.3
		mb.add_loft(mud, _xf(c - Vector3(0, sink, 0)), [[0.0, r, r], [sink + hh * 0.35, r * 1.02, r * 1.02], [sink + hh * 0.75, r * 0.72, r * 0.72], [sink + hh, r * 0.18, r * 0.18], [sink + hh + 0.05, 0.02, 0.02]],
			MeshBuilder.profile_circle(10), 0.5, Color.WHITE.darkened(rng.randf() * 0.1))
		mb.add_box(_dark(), _xf(c + Vector3(0, hh * 0.45, r * 0.98)), Vector3(r * 0.5, r * 0.55, 0.06), 1.0)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = hh
		cs.shape = cyl
		cs.position = c + Vector3(0, hh * 0.5, 0)
		body.add_child(cs)
	body.add_child(mb.to_instance("GranaryMesh"))
	return body


## A ruin: a plaster house fallen in and half buried in sand, its arch still standing, a roof beam down
## across it. Marker: Cache.
static func ruin(seed_value: int, w: float, d: float) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := _body("Ruin")
	var mb := MeshBuilder.new()
	var col: Color = (WASH[rng.randi() % WASH.size()] as Color).darkened(0.08)
	for e in [[Vector3(0, 0, -d * 0.5), 0.0, w], [Vector3(-w * 0.5, 0, 0), PI * 0.5, d], [Vector3(w * 0.5, 0, 0), PI * 0.5, d]]:
		var o: Vector3 = e[0]
		var b := Basis(Vector3.UP, float(e[1]))
		var length: float = e[2]
		var segs := int(length / 0.9)
		var tot := 0.0
		for k in range(segs):
			var sh := rng.randf_range(0.6, 2.8)
			if rng.randf() < 0.2:
				continue
			tot += sh
			mb.add_box(_adobe(), Transform3D(b, o + b * Vector3(-length * 0.5 + (k + 0.5) * length / segs, sh * 0.5 - 0.4, 0)), Vector3(length / segs + 0.02, sh + 0.4, 0.3), 0.5, col.darkened(rng.randf() * 0.15))
		_box(body, Vector3(length, maxf(tot / segs, 0.5), 0.3), o + Vector3(0, maxf(tot / segs, 0.5) * 0.5, 0), b)
	_arched_wall(mb, _adobe(), _xf(Vector3(0, -0.3, d * 0.5)), w * 0.6, 2.8, [[0.0, 1.3, 2.5]], 0.3, col)
	for s in [-1.0, 1.0]:
		_box(body, Vector3(w * 0.15, 2.5, 0.3), Vector3(s * w * 0.22, 1.0, d * 0.5))
	Buildings.beam_between(mb, _beam(), Vector3(-w * 0.4, 2.2, -d * 0.45), Vector3(w * 0.3, 0.1, d * 0.2), 0.16)
	var sand := PSXMat.lit("desert_sand")
	mb.add_blob(sand, _xf(Vector3(rng.randf_range(-0.5, 0.5), 0.0, -d * 0.1)), Vector3(w * 0.55, 0.9, d * 0.5), rng, 0.15, 3, 8, 0.25, Color.WHITE, 0.0)
	mb.add_blob(sand, _xf(Vector3(w * 0.5, 0.0, 0)), Vector3(1.6, 1.4, d * 0.6), rng, 0.15, 3, 7, 0.25, Color.WHITE, 0.0)
	body.add_child(mb.to_instance("RuinMesh"))
	_marker(body, "Cache", Vector3(-w * 0.2, 0.4, -d * 0.15), 0.0)
	return body


## A minaret `h` tall: a square sandstone base, a banded round shaft, a balcony on its corbel ring, a
## lantern stage, an onion cap.
static func minaret(seed_value: int, h: float) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := _body("Minaret")
	var mb := MeshBuilder.new()
	var stone := _stone()
	var col := Color(1.0, 0.97, 0.92)
	var base := h * 0.22
	_footing(mb, body, 3.0, 3.0, base)
	var shaft := h * 0.55
	mb.add_cylinder(_adobe(), _xf(Vector3(0, base, 0)), 1.15, 0.95, shaft, 10, 0.5, col)
	for k in range(3):
		mb.add_cylinder(stone, _xf(Vector3(0, base + shaft * (k + 1) / 4.0, 0)), 1.12 - k * 0.05, 1.12 - k * 0.05, 0.18, 10, 0.8, Color(0.9, 0.85, 0.75))
	_arch_recess(mb, _xf(Vector3(0, base + shaft * 0.55, 1.08)), 0.4, 0.9, rng.randf() < 0.5)
	var by := base + shaft
	mb.add_cylinder(stone, _xf(Vector3(0, by, 0)), 1.0, 1.5, 0.35, 10, 0.8, Color(0.9, 0.86, 0.8), true, true)
	for k in range(12):
		var a := TAU * k / 12.0
		mb.add_cylinder(stone, _xf(Vector3(cos(a) * 1.4, by + 0.35, sin(a) * 1.4)), 0.05, 0.05, 0.7, 4, 1.0, STONE_COL)
	mb.add_cylinder(stone, _xf(Vector3(0, by + 1.05, 0)), 1.45, 1.45, 0.08, 12, 0.8, STONE_COL, true, true)
	var top := h * 0.15
	mb.add_cylinder(_adobe(), _xf(Vector3(0, by + 0.35, 0)), 0.7, 0.62, top, 8, 0.5, col)
	_arch_recess(mb, _xf(Vector3(0, by + 0.6, 0.66)), 0.35, 0.8, true)
	dome(mb, Vector3(0, by + 0.35 + top, 0), 0.75, DOMES[rng.randi() % DOMES.size()], true, 0.2)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.15
	cyl.height = shaft + top + 0.4
	cs.shape = cyl
	cs.position = Vector3(0, base + (shaft + top + 0.4) * 0.5, 0)
	body.add_child(cs)
	body.add_child(mb.to_instance("MinaretMesh"))
	return body


## The great domed hall over a medina's roofs (the royal city's palace dome): a tall block on a
## sandstone plinth, an arched portal in a raised frame on its front, arched windows, a crenellated
## parapet, corner turrets under little domes and the great onion dome on a windowed drum. Seen,
## not entered. `size` is its width and depth.
static func great_hall(seed_value: int, size := 10.0) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := _body("Hall")
	var mb := MeshBuilder.new()
	var stone := _stone()
	var w := size
	var h := rng.randf_range(6.6, 7.6)
	var fl := 0.6
	var col: Color = [Color(1.0, 0.97, 0.92), Color(1.0, 0.92, 0.78), Color(0.98, 0.84, 0.74)][rng.randi() % 3]
	_footing(mb, body, w + 0.8, w + 0.8, fl)
	_block(mb, Vector3(0, fl + h * 0.5, 0), Vector3(w, h, w), col)
	_box(body, Vector3(w, h, w), Vector3(0, fl + h * 0.5, 0))
	# the portal: a raised frame proud of the front, a deep arch in it, a lamp hung in the arch
	var pw := w * 0.46
	var ph := h + 1.3
	_block(mb, Vector3(0, fl + ph * 0.5, w * 0.5 + 0.2), Vector3(pw, ph, 0.4), col.darkened(0.03))
	mb.add_box(stone, _xf(Vector3(0, fl + ph + 0.05, w * 0.5 + 0.2)), Vector3(pw + 0.2, 0.12, 0.6), 0.8, STONE_COL)
	_arch_recess(mb, _xf(Vector3(0, fl, w * 0.5 + 0.41)), pw - 1.2, ph - 1.3, false)
	Buildings.panel_door(mb, _xf(Vector3(0, fl, w * 0.5 + 0.41)), 1.6, 2.4, Buildings.door_leaf(DOOR_PAINT), stone)
	mb.add_box(PSXMat.glow(Color(1.0, 0.75, 0.4), 2.2), _xf(Vector3(0, fl + ph - 2.4, w * 0.5 + 0.7)), Vector3(0.24, 0.32, 0.24), 1.0)
	Buildings.door_steps(body, mb, stone, 0.0, w * 0.5 + 0.41, fl, pw, 0.6, FOOT)
	_box(body, Vector3(pw, ph, 0.4), Vector3(0, fl + ph * 0.5, w * 0.5 + 0.2))
	# arched windows round the other three sides, two rows
	for yaw in [-PI * 0.5, PI * 0.5, PI]:
		var xf := _xf(Vector3(0, fl, 0), yaw) * _xf(Vector3(0, 0, w * 0.5 + 0.005))
		_windows(mb, xf, w, 2.0, rng, INF, false, 0.25)
		_windows(mb, xf, w, 4.9, rng, INF, true, 0.25)
	_windows(mb, _xf(Vector3(0, fl, w * 0.5 + 0.005)), w, 4.9, rng, 0.0, true, 0.25)
	_parapet(mb, w, w, fl + h, col, true)
	# corner turrets, each under a little dome
	var glaze: Color = DOMES[rng.randi() % DOMES.size()]
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var tp := Vector3(cx * (w * 0.5 - 0.1), fl, cz * (w * 0.5 - 0.1))
			mb.add_cylinder(_adobe(), _xf(tp), 0.6, 0.55, h + 1.6, 8, 0.5, col)
			dome(mb, tp + Vector3(0, h + 1.6, 0), 0.62, glaze, true, 0.1)
	# the drum, ringed with arched windows, and the great dome
	var r := w * 0.3
	var dy := fl + h + 0.15
	var drum := 1.7
	for k in range(8):
		var a := TAU * k / 8.0 + PI / 8.0
		_arch_recess(mb, _xf(Vector3(sin(a) * r * 1.03, dy + 0.35, cos(a) * r * 1.03), a), 0.45, 1.0, rng.randf() < 0.5)
	dome(mb, Vector3(0, dy, 0), r, DOMES[rng.randi() % DOMES.size()], rng.randf() < 0.75, drum)
	body.add_child(mb.to_instance("HallMesh"))
	return body


## The desert's lookout (KitStyle "lookout"): a mud-brick tower narrowing in two setbacks, slit
## windows, beam ends under a crenellated platform at `h` open on its +Z side where the ladder
## arrives, a little domed kiosk on four posts over the platform. KitLandmarks.lookout_tower's
## interface: the platform's top at h, the ladder up the +Z face.
static func watchtower(seed_value: int, h := 6.0) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := _body("LookoutTower")
	var mb := MeshBuilder.new()
	var stone := _stone()
	var col: Color = [Color(0.95, 0.86, 0.7), Color(0.98, 0.9, 0.78), Color(0.9, 0.78, 0.62)][rng.randi() % 3]
	const E := 1.9
	var top := h + 0.09
	_footing(mb, body, 3.8, 3.8, 0.3)
	var hws := [1.75, 1.6, 1.45]
	var y := 0.3
	for i in range(3):
		var hw: float = hws[i]
		var sh := (h - 0.6 - 0.3) / 3.0
		_block(mb, Vector3(0, y + sh * 0.5, 0), Vector3(hw * 2.0, sh, hw * 2.0), col.darkened(i * 0.02))
		_box(body, Vector3(hw * 2.0, sh, hw * 2.0), Vector3(0, y + sh * 0.5, 0))
		if i > 0:
			mb.add_box(stone, _xf(Vector3(0, y + 0.04, 0)), Vector3(hw * 2.0 + 0.36, 0.08, hw * 2.0 + 0.36), 0.8, STONE_COL)
		# a slit window on each side but the ladder's, one lit now and then
		for yaw in [-PI * 0.5, PI * 0.5, PI]:
			var lit := rng.randf() < 0.2
			mb.add_box(_window() if lit else _dark(), _xf(Vector3(0, 0, 0), yaw) * _xf(Vector3(rng.randf_range(-0.4, 0.4), y + sh * 0.55, hw + 0.01)), Vector3(0.2, 0.8, 0.04), 1.0)
		y += sh
	# the platform on a band of beam ends, its slab out to E
	var hw2: float = hws[2]
	_block(mb, Vector3(0, y + 0.3, 0), Vector3(hw2 * 2.0, 0.6, hw2 * 2.0), col.darkened(0.04))
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var b := Basis(Vector3.UP, yaw)
		for k in range(4):
			mb.add_cylinder(_beam(), Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), b * Vector3(-1.05 + k * 0.7, top - 0.42, hw2 - 0.1)), 0.06, 0.06, 0.5, 5, 1.0, Color(0.9, 0.85, 0.8), true, true)
	mb.add_box(stone, _xf(Vector3(0, top - 0.15, 0)), Vector3(E * 2.0, 0.3, E * 2.0), 0.6, STONE_COL, false)
	_box(body, Vector3(E * 2.0, 0.3, E * 2.0), Vector3(0, top - 0.15, 0))
	# the parapet: three sides whole, the +Z side either side of the gap the ladder comes up through
	var adobe := _adobe()
	var pt := 0.22
	var ph := 0.95
	for e in [[Vector3(0, 0, -E + pt * 0.5), Vector3(E * 2.0, ph, pt)], [Vector3(-E + pt * 0.5, 0, 0), Vector3(pt, ph, E * 2.0)], [Vector3(E - pt * 0.5, 0, 0), Vector3(pt, ph, E * 2.0)],
			[Vector3(-1.25, 0, E - pt * 0.5), Vector3(1.3, ph, pt)], [Vector3(1.25, 0, E - pt * 0.5), Vector3(1.3, ph, pt)]]:
		var at: Vector3 = e[0]
		var sz: Vector3 = e[1]
		mb.add_box(adobe, _xf(at + Vector3(0, top + ph * 0.5, 0)), sz, 0.5, col, false)
		_box(body, sz, at + Vector3(0, top + ph * 0.5, 0))
		var n := maxi(int(maxf(sz.x, sz.z) / 0.55), 1)
		for k in range(0, n, 2):
			var off := -maxf(sz.x, sz.z) * 0.5 + (k + 0.5) * maxf(sz.x, sz.z) / n
			var mp := at + (Vector3(off, 0, 0) if sz.x > sz.z else Vector3(0, 0, off))
			mb.add_box(adobe, _xf(mp + Vector3(0, top + ph + 0.15, 0)), Vector3(0.3 if sz.x > sz.z else pt, 0.3, pt if sz.x > sz.z else 0.3), 0.5, col)
	# the kiosk: four posts, a slab, a little dome
	var kq := E - 0.35
	for sx in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			mb.add_cylinder(stone, _xf(Vector3(sx * kq, top, sz2 * kq)), 0.1, 0.09, 2.3, 6, 0.8, STONE_COL)
	mb.add_box(adobe, _xf(Vector3(0, top + 2.38, 0)), Vector3(kq * 2.0 + 0.5, 0.16, kq * 2.0 + 0.5), 0.5, col, false)
	dome(mb, Vector3(0, top + 2.46, 0), 0.95, DOMES[rng.randi() % DOMES.size()], rng.randf() < 0.6, 0.15)
	body.add_child(mb.to_instance("WatchtowerMesh"))
	var lad := Ladder.new()
	lad.length = top
	lad.rail = 0.0
	lad.deck_depth = 1.0
	lad.position = Vector3(0, top, E)
	body.add_child(lad)
	return body


## The bandits' hideout (the desert's camp house, KitStyle "camp_shack"): a squat blockhouse of
## unwashed mud brick, its parapet crumbling, a dark arched doorway, a patched striped lean-to on
## poles out front over a rug, hides drying on the roof, jars and sacks against the walls. Front +Z.
static func bandit_hut(seed_value: int, w := 5.5, d := 4.5) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := _body("Shack")
	var mb := MeshBuilder.new()
	var adobe := _adobe()
	var col := Color(0.86, 0.72, 0.56).darkened(rng.randf() * 0.08)
	var h := rng.randf_range(2.6, 2.9)
	var fl := 0.2
	_footing(mb, body, w + 0.2, d + 0.2, fl)
	_block(mb, Vector3(0, fl + h * 0.5, 0), Vector3(w, h, d), col)
	_box(body, Vector3(w, h, d), Vector3(0, fl + h * 0.5, 0))
	# a parapet in broken stretches
	for s in [-1.0, 1.0]:
		for k in range(4):
			var ph := rng.randf_range(0.15, 0.6)
			mb.add_box(adobe, _xf(Vector3(-w * 0.5 + (k + 0.5) * w / 4.0, fl + h + ph * 0.5, s * (d * 0.5 - 0.1))), Vector3(w / 4.0 + 0.01, ph, 0.2), 0.5, col.darkened(0.05))
		for k in range(3):
			var ph := rng.randf_range(0.15, 0.6)
			mb.add_box(adobe, _xf(Vector3(s * (w * 0.5 - 0.1), fl + h + ph * 0.5, -d * 0.5 + (k + 0.5) * d / 3.0)), Vector3(0.2, ph, d / 3.0 - 0.02), 0.5, col.darkened(0.05))
	_vigas(mb, w, d * 0.5 + 0.1, fl + h - 0.3)
	_arch_recess(mb, _xf(Vector3(-0.6, fl, d * 0.5)), 1.1, 2.1, false)
	for x in [-w * 0.5 + 0.8, w * 0.5 - 0.8]:
		mb.add_box(_dark(), _xf(Vector3(x, fl + 1.6, d * 0.5 + 0.01)), Vector3(0.45, 0.4, 0.04), 1.0)
		mb.add_box(_beam(), _xf(Vector3(x, fl + 1.36, d * 0.5 + 0.06)), Vector3(0.6, 0.06, 0.1), 1.0)
	_windows(mb, _xf(Vector3(0, fl, -d * 0.5 - 0.005), PI), w, 1.6, rng, INF, false, 0.0)
	# the lean-to: patched canvas on two poles, a rug under it
	_awning(mb, ["awning_red", "awning_gold"][rng.randi() % 2], 3.0, d * 0.5 + 0.05, fl + 2.3, 1.8)
	mb.add_box(PSXMat.lit("canvas", Color(0.75, 0.66, 0.52)), _xf(Vector3(0.6, fl + 2.1, d * 0.5 + 1.0), 0.1) * Transform3D(Basis(Vector3.RIGHT, 0.28), Vector3.ZERO), Vector3(0.9, 0.03, 0.8), 1.0, Color.WHITE, false)
	mb.add_quad(PSXMat.lit("rug_kilim"), Vector3(-1.3, 0.03, d * 0.5 + 0.3), Vector3(1.3, 0.03, d * 0.5 + 0.3), Vector3(1.3, 0.03, d * 0.5 + 1.9), Vector3(-1.3, 0.03, d * 0.5 + 1.9),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 0.6), Vector2(0, 0.6), Color(0.8, 0.75, 0.7), Vector3.UP)
	# hides pegged out on the roof
	var hide := PSXMat.lit("leather", Color(0.75, 0.55, 0.38))
	for k in range(2):
		mb.add_box(hide, _xf(Vector3(rng.randf_range(-1.2, 1.2), fl + h + 0.05, rng.randf_range(-1.0, 0.6)), rng.randf() * TAU), Vector3(1.3, 0.04, 0.9), 1.0, Color.WHITE.darkened(k * 0.15), false)
	# jars by the wall, sacks by the door
	var clay := PSXMat.lit("adobe", Color(0.85, 0.55, 0.38))
	for k in range(3):
		KitHouses._jar(mb, clay, _xf(Vector3(-w * 0.5 - 0.35, 0.0, -d * 0.3 + k * 0.6)), rng.randf_range(0.9, 1.2))
	var sack := PSXMat.lit("canvas", Color(0.8, 0.72, 0.56))
	for k in range(3):
		mb.add_blob(sack, _xf(Vector3(w * 0.5 - 0.5 - k * 0.55, 0.3, d * 0.5 + 0.45)), Vector3(0.3, 0.32, 0.26), rng, 0.12, 3, 6, 1.0, Color.WHITE, 0.0)
	_box(body, Vector3(0.5, 1.0, 1.8), Vector3(-w * 0.5 - 0.35, 0.5, 0.3))
	body.add_child(mb.to_instance("ShackMesh"))
	return body


## A low mud-brick garden wall (the desert's fence) `length` along +Z from the origin: stretches
## of uneven height under a sandstone coping, footed below the ground.
static func mud_wall(seed_value: int, length := 4.4) -> StaticBody3D:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var col := (WASH[rng.randi() % WASH.size()] as Color).lerp(Color(0.9, 0.78, 0.62), 0.5)
	var n := 3
	for k in range(n):
		var h := rng.randf_range(0.8, 1.05)
		var z := (k + 0.5) * length / n
		mb.add_box(_adobe(), _xf(Vector3(0, (h - 0.4) * 0.5, z)), Vector3(0.36, h + 0.4, length / n + 0.01), 0.5, col.darkened(rng.randf() * 0.06))
		mb.add_box(_stone(), _xf(Vector3(0, h + 0.03, z)), Vector3(0.44, 0.07, length / n - 0.02), 0.8, STONE_COL)
	var body := _body("Fence")
	body.add_child(mb.to_instance("WallMesh"))
	_box(body, Vector3(0.36, 1.0, length), Vector3(0, 0.5, length * 0.5))
	return body


## A clay pot with an agave in it (the desert's planter); `r` the pot's radius.
static func planter(seed_value: int, r := 0.6) -> StaticBody3D:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var clay := PSXMat.lit("adobe", [Color(0.88, 0.56, 0.4), Color(0.8, 0.5, 0.36), Color(0.95, 0.85, 0.7)][rng.randi() % 3])
	mb.add_loft(clay, Transform3D.IDENTITY, [[0.0, r * 0.7, r * 0.7], [r * 0.5, r, r], [r * 0.95, r * 0.92, r * 0.92], [r * 1.0, r * 1.02, r * 1.02], [r * 1.08, r * 1.0, r * 1.0]],
		MeshBuilder.profile_circle(10), 1.0, Color.WHITE, true)
	mb.add_cylinder(PSXMat.lit("desert_hardpan"), _xf(Vector3(0, r * 0.98, 0)), r * 0.95, r * 0.95, 0.02, 10, 1.0)
	var leaf := PSXMat.flat(Color(0.42, 0.56, 0.44))
	var n := rng.randi_range(9, 13)
	for k in range(n):
		var a := TAU * k / n + rng.randf_range(-0.2, 0.2)
		var up := rng.randf_range(0.5, 1.2)
		var out := Vector3(cos(a), 0, sin(a))
		var base := Vector3(0, r * 1.0, 0)
		mb.add_tube(leaf, MeshBuilder.curve_points(base, base + out * 0.25 + Vector3(0, up * 0.7, 0), base + out * (0.45 + up * 0.25) + Vector3(0, up * 0.75, 0), 4), 0.07, 0.0, 3, 1.0, Color.WHITE.darkened(rng.randf() * 0.2))
	var body := _body("Planter")
	body.add_child(mb.to_instance("PlanterMesh"))
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = r * 1.08
	cs.shape = cyl
	cs.position = Vector3(0, r * 0.54, 0)
	body.add_child(cs)
	return body


## A brazier on an iron tripod (the desert's torch), its coals aglow; "Flame" over them.
static func brazier(h := 1.5) -> StaticBody3D:
	var mb := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.3, 0.26, 0.22))
	for k in range(3):
		var a := TAU * k / 3.0
		Buildings.beam_between(mb, iron, Vector3(cos(a) * 0.4, 0.0, sin(a) * 0.4), Vector3(cos(a) * 0.12, h - 0.15, sin(a) * 0.12), 0.04)
	mb.add_loft(_brass(), _xf(Vector3(0, h - 0.2, 0)), [[0.0, 0.08, 0.08], [0.12, 0.3, 0.3], [0.22, 0.36, 0.36]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, true)
	mb.add_blob(PSXMat.glow(Color(1.0, 0.45, 0.12), 2.6), _xf(Vector3(0, h, 0)), Vector3(0.28, 0.08, 0.28), _rng(7), 0.2, 2, 6)
	var body := _body("Brazier")
	body.add_child(mb.to_instance("BrazierMesh"))
	_box(body, Vector3(0.6, h, 0.6), Vector3(0, h * 0.5, 0))
	_marker(body, "Flame", Vector3(0, h + 0.3, 0))
	return body


## A well: a round sandstone wall, a timber frame with a brass pulley and a rope, a bucket on the rim.
static func well() -> StaticBody3D:
	var mb := MeshBuilder.new()
	var beam := _beam()
	mb.add_loft(_stone(), Transform3D.IDENTITY, [[0.0, 1.0, 1.0], [0.8, 0.95, 0.95], [0.82, 1.05, 1.05], [0.92, 1.05, 1.05]], MeshBuilder.profile_circle(12), 0.6, Color(0.92, 0.88, 0.82), false, true)
	mb.add_cylinder(PSXMat.flat(Color(0.05, 0.04, 0.03)), _xf(Vector3(0, 0.7, 0)), 0.8, 0.8, 0.02, 12, 1.0)
	for s in [-1.0, 1.0]:
		mb.add_box(beam, _xf(Vector3(s * 0.95, 1.3, 0)), Vector3(0.14, 2.6, 0.14), 0.8)
	mb.add_box(beam, _xf(Vector3(0, 2.55, 0)), Vector3(2.1, 0.14, 0.14), 0.8, Color.WHITE, false)
	mb.add_cylinder(_brass(), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.12, 2.38, 0)), 0.14, 0.14, 0.24, 8, 1.0, Color.WHITE, true, true)
	mb.add_box(PSXMat.lit("rope"), _xf(Vector3(0, 1.6, 0)), Vector3(0.03, 1.6, 0.03), 1.0)
	mb.add_cylinder(_beam(), _xf(Vector3(0.75, 0.92, 0.4)), 0.17, 0.2, 0.3, 7, 1.0)
	var body := _body("Well")
	body.add_child(mb.to_instance("WellMesh"))
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.05
	cyl.height = 0.92
	cs.shape = cyl
	cs.position = Vector3(0, 0.46, 0)
	body.add_child(cs)
	return body
