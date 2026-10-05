class_name MeshBuilder
extends RefCounted
## Tiny procedural low-poly mesh builder. Accumulates triangles per material and
## commits them into one multi-surface ArrayMesh. UVs are in "texture tiles":
## pass `uv_scale` = tiles per meter so textures stay a consistent pixel density.
##
## Winding: Godot treats clockwise-from-the-front as front facing. Every
## triangle here is given a desired outward normal and auto-oriented, so
## callers never have to think about winding.

var _surfaces: Dictionary = {}  # Material -> {v, n, uv, c, b, w}
var _order: Array[Material] = []
## Skinning: when `skinned` is true, commit() writes ARRAY_BONES/WEIGHTS.
## Each vertex is bound rigidly to one bone (`bone`, or per-vertex via
## add_tri's `vb`), which is all the segmented PS1-style chains need.
var skinned := false
var bone := 0


func _surf(mat: Material) -> Dictionary:
	if not _surfaces.has(mat):
		_surfaces[mat] = {
			"v": PackedVector3Array(),
			"n": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"c": PackedColorArray(),
			"b": PackedInt32Array(),
			"w": PackedFloat32Array(),
		}
		_order.append(mat)
	return _surfaces[mat]


func is_empty() -> bool:
	return _order.is_empty()


## Core primitive. `want` is the desired facing direction (used for winding).
func add_tri(mat: Material, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, col: Color = Color.WHITE, want: Vector3 = Vector3.ZERO,
		vb: PackedInt32Array = PackedInt32Array()) -> void:
	var s := _surf(mat)
	if want == Vector3.ZERO:
		want = na + nb + nc
	var ba := bone; var bb := bone; var bc := bone
	if vb.size() == 3:
		ba = vb[0]; bb = vb[1]; bc = vb[2]
	# Godot front face: (c - a).cross(b - a) points outward.
	if (c - a).cross(b - a).dot(want) < 0.0:
		var t := b; b = c; c = t
		var tn := nb; nb = nc; nc = tn
		var tu := ub; ub = uc; uc = tu
		var tb := bb; bb = bc; bc = tb
	s["v"].append_array([a, b, c])
	s["n"].append_array([na, nb, nc])
	s["uv"].append_array([ua, ub, uc])
	s["c"].append_array([col, col, col])
	s["b"].append_array([ba, 0, 0, 0, bb, 0, 0, 0, bc, 0, 0, 0])
	s["w"].append_array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0])


## Flat-shaded quad a-b-c-d (in order around the edge).
func add_quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col: Color = Color.WHITE, normal: Vector3 = Vector3.ZERO) -> void:
	var n := normal
	if n == Vector3.ZERO:
		n = (b - a).cross(d - a).normalized()
	add_tri(mat, a, b, c, n, n, n, ua, ub, uc, col, n)
	add_tri(mat, a, c, d, n, n, n, ua, uc, ud, col, n)


## Axis-aligned box (in the local frame of `xf`), UVs scaled by world size.
func add_box(mat: Material, xf: Transform3D, size: Vector3, uv_scale: float = 0.5,
		col: Color = Color.WHITE, skip_bottom: bool = true, skip_top: bool = false) -> void:
	var h := size * 0.5
	var p := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	for i in range(8):
		p[i] = xf * p[i]
	var bx := xf.basis
	var sx := size.x * uv_scale
	var sy := size.y * uv_scale
	var sz := size.z * uv_scale
	# +Z (front)
	_face(mat, p[3], p[2], p[6], p[7], Vector2(0, sy), Vector2(sx, sy), Vector2(sx, 0), Vector2(0, 0), col, (bx * Vector3.BACK).normalized())
	# -Z (back)
	_face(mat, p[1], p[0], p[4], p[5], Vector2(0, sy), Vector2(sx, sy), Vector2(sx, 0), Vector2(0, 0), col, (bx * Vector3.FORWARD).normalized())
	# +X
	_face(mat, p[2], p[1], p[5], p[6], Vector2(0, sy), Vector2(sz, sy), Vector2(sz, 0), Vector2(0, 0), col, (bx * Vector3.RIGHT).normalized())
	# -X
	_face(mat, p[0], p[3], p[7], p[4], Vector2(0, sy), Vector2(sz, sy), Vector2(sz, 0), Vector2(0, 0), col, (bx * Vector3.LEFT).normalized())
	if not skip_top:
		_face(mat, p[7], p[6], p[5], p[4], Vector2(0, sz), Vector2(sx, sz), Vector2(sx, 0), Vector2(0, 0), col, (bx * Vector3.UP).normalized())
	if not skip_bottom:
		_face(mat, p[0], p[1], p[2], p[3], Vector2(0, 0), Vector2(sx, 0), Vector2(sx, sz), Vector2(0, sz), col, (bx * Vector3.DOWN).normalized())


func _face(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col: Color, n: Vector3) -> void:
	add_quad(mat, a, b, c, d, ua, ub, uc, ud, col, n)


## Box whose 6 faces all map the full texture once (crates, signs, doors).
func add_box_unit_uv(mat: Material, xf: Transform3D, size: Vector3, col: Color = Color.WHITE) -> void:
	var h := size * 0.5
	var p := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	for i in range(8):
		p[i] = xf * p[i]
	var bx := xf.basis
	var u0 := Vector2(0, 1); var u1 := Vector2(1, 1); var u2 := Vector2(1, 0); var u3 := Vector2(0, 0)
	_face(mat, p[3], p[2], p[6], p[7], u0, u1, u2, u3, col, (bx * Vector3.BACK).normalized())
	_face(mat, p[1], p[0], p[4], p[5], u0, u1, u2, u3, col, (bx * Vector3.FORWARD).normalized())
	_face(mat, p[2], p[1], p[5], p[6], u0, u1, u2, u3, col, (bx * Vector3.RIGHT).normalized())
	_face(mat, p[0], p[3], p[7], p[4], u0, u1, u2, u3, col, (bx * Vector3.LEFT).normalized())
	_face(mat, p[7], p[6], p[5], p[4], u0, u1, u2, u3, col, (bx * Vector3.UP).normalized())


## Cylinder / frustum along local +Y, base at local origin.
func add_cylinder(mat: Material, xf: Transform3D, r_bottom: float, r_top: float, height: float,
		sides: int = 6, uv_scale: float = 0.5, col: Color = Color.WHITE,
		cap_top: bool = true, cap_bottom: bool = false, smooth: bool = true, cap_mat: Material = null) -> void:
	var circ := TAU * maxf(r_bottom, r_top)
	var u_total := maxf(1.0, roundf(circ * uv_scale))
	var v_total := height * uv_scale
	var slope := (r_bottom - r_top) / maxf(height, 0.001)
	for i in range(sides):
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := xf * (d0 * r_bottom)
		var b1 := xf * (d1 * r_bottom)
		var t0 := xf * (d0 * r_top + Vector3.UP * height)
		var t1 := xf * (d1 * r_top + Vector3.UP * height)
		var n0: Vector3
		var n1: Vector3
		if smooth:
			n0 = (xf.basis * (d0 + Vector3.UP * slope)).normalized()
			n1 = (xf.basis * (d1 + Vector3.UP * slope)).normalized()
		else:
			var dm := (d0 + d1).normalized()
			n0 = (xf.basis * (dm + Vector3.UP * slope)).normalized()
			n1 = n0
		var ua := float(i) / sides * u_total
		var ub := float(i + 1) / sides * u_total
		var want := (n0 + n1)
		add_tri(mat, b0, b1, t1, n0, n1, n1, Vector2(ua, v_total), Vector2(ub, v_total), Vector2(ub, 0), col, want)
		add_tri(mat, b0, t1, t0, n0, n1, n0, Vector2(ua, v_total), Vector2(ub, 0), Vector2(ua, 0), col, want)
	var cm := cap_mat if cap_mat else mat
	if cap_top and r_top > 0.001:
		_disc(cm, xf, r_top, height, sides, uv_scale, col, true)
	if cap_bottom and r_bottom > 0.001:
		_disc(cm, xf, r_bottom, 0.0, sides, uv_scale, col, false)


func _disc(mat: Material, xf: Transform3D, r: float, y: float, sides: int, uv_scale: float, col: Color, up: bool) -> void:
	var n := (xf.basis * (Vector3.UP if up else Vector3.DOWN)).normalized()
	var c := xf * Vector3(0, y, 0)
	for i in range(sides):
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var p0 := Vector3(cos(a0) * r, y, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, y, sin(a1) * r)
		add_tri(mat, c, xf * p0, xf * p1, n, n, n,
			Vector2(0.5, 0.5) * r * 2.0 * uv_scale,
			(Vector2(p0.x, p0.z) + Vector2(r, r)) * uv_scale,
			(Vector2(p1.x, p1.z) + Vector2(r, r)) * uv_scale, col, n)


## Cone along +Y.
func add_cone(mat: Material, xf: Transform3D, r: float, height: float, sides: int = 6,
		uv_scale: float = 0.5, col: Color = Color.WHITE) -> void:
	add_cylinder(mat, xf, r, 0.0, height, sides, uv_scale, col, false, false, false)


## Gable roof: ridge along local Z. `w` = width (X), `d` = depth (Z).
## Base sits at local y=0, ridge at y=h. Gable triangles use `gable_mat`.
func add_gable_roof(mat: Material, xf: Transform3D, w: float, d: float, h: float,
		overhang: float = 0.4, uv_scale: float = 0.5, col: Color = Color.WHITE, gable_mat: Material = null) -> void:
	var hw := w * 0.5 + overhang
	var hd := d * 0.5 + overhang
	var drop := overhang * h / (w * 0.5)
	var l0 := xf * Vector3(-hw, -drop, -hd)
	var l1 := xf * Vector3(-hw, -drop, hd)
	var r0 := xf * Vector3(hw, -drop, -hd)
	var r1 := xf * Vector3(hw, -drop, hd)
	var t0 := xf * Vector3(0, h, -hd)
	var t1 := xf * Vector3(0, h, hd)
	var slope_len := Vector2(hw, h + drop).length() * uv_scale
	var dl := hd * 2.0 * uv_scale
	var nl := (xf.basis * Vector3(-h, w * 0.5, 0)).normalized()
	var nr := (xf.basis * Vector3(h, w * 0.5, 0)).normalized()
	add_quad(mat, l0, l1, t1, t0, Vector2(0, slope_len), Vector2(dl, slope_len), Vector2(dl, 0), Vector2(0, 0), col, nl)
	add_quad(mat, r1, r0, t0, t1, Vector2(0, slope_len), Vector2(dl, slope_len), Vector2(dl, 0), Vector2(0, 0), col, nr)
	# underside so the overhang isn't see-through from below
	var nd := (xf.basis * Vector3.DOWN).normalized()
	add_quad(mat, l0, t0, t1, l1, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), col * 0.6, nd)
	add_quad(mat, r0, r1, t1, t0, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), col * 0.6, nd)
	if gable_mat:
		var gw := w * 0.5
		for zs in [-1.0, 1.0]:
			var z: float = zs * d * 0.5
			var n := (xf.basis * Vector3(0, 0, zs)).normalized()
			var a := xf * Vector3(-gw, 0, z)
			var b := xf * Vector3(gw, 0, z)
			var c := xf * Vector3(0, h, z)
			add_tri(gable_mat, a, b, c, n, n, n,
				Vector2(0, h * uv_scale), Vector2(w * uv_scale, h * uv_scale), Vector2(gw * uv_scale, 0), col, n)


## Hip/pyramid roof over a w x d footprint.
func add_pyramid_roof(mat: Material, xf: Transform3D, w: float, d: float, h: float,
		overhang: float = 0.3, uv_scale: float = 0.5, col: Color = Color.WHITE) -> void:
	var hw := w * 0.5 + overhang
	var hd := d * 0.5 + overhang
	var top := xf * Vector3(0, h, 0)
	var corners := [xf * Vector3(-hw, 0, -hd), xf * Vector3(hw, 0, -hd), xf * Vector3(hw, 0, hd), xf * Vector3(-hw, 0, hd)]
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var mid := (a + b) * 0.5
		var out := (mid - xf * Vector3.ZERO)
		out.y = 0
		var n := (out.normalized() * h + (xf.basis * Vector3.UP) * maxf(hw, hd)).normalized()
		var L := a.distance_to(b) * uv_scale
		var sl := mid.distance_to(top) * uv_scale
		add_tri(mat, a, b, top, n, n, n, Vector2(0, sl), Vector2(L, sl), Vector2(L * 0.5, 0), col, n)


## Single quad card centered at xf origin, facing local +Z. uv_rect = (u0,v0,u1,v1).
func add_card(mat: Material, xf: Transform3D, w: float, h: float, uv_rect: Rect2 = Rect2(0, 0, 1, 1),
		col: Color = Color.WHITE, bottom_anchor: bool = true) -> void:
	var y0 := 0.0 if bottom_anchor else -h * 0.5
	var a := xf * Vector3(-w * 0.5, y0, 0)
	var b := xf * Vector3(w * 0.5, y0, 0)
	var c := xf * Vector3(w * 0.5, y0 + h, 0)
	var d := xf * Vector3(-w * 0.5, y0 + h, 0)
	var n := (xf.basis * Vector3.BACK).normalized()
	var u0 := uv_rect.position
	var u1 := uv_rect.end
	add_quad(mat, a, b, c, d, Vector2(u0.x, u1.y), Vector2(u1.x, u1.y), Vector2(u1.x, u0.y), Vector2(u0.x, u0.y), col, n)


## Crossed cards (classic PS1 bush / grass).
func add_cross_cards(mat: Material, xf: Transform3D, w: float, h: float, count: int = 2, col: Color = Color.WHITE) -> void:
	for i in range(count):
		var rot := Basis(Vector3.UP, PI * float(i) / count)
		add_card(mat, xf * Transform3D(rot, Vector3.ZERO), w, h, Rect2(0, 0, 1, 1), col)


## Low-poly jittered blob (rock / canopy). Flat shaded for that faceted look.
func add_blob(mat: Material, xf: Transform3D, radii: Vector3, rng: RandomNumberGenerator,
		jitter: float = 0.18, rings: int = 4, segs: int = 6, uv_scale: float = 0.5,
		col: Color = Color.WHITE, flatten_bottom: float = -1.0) -> void:
	var grid: Array = []
	for r in range(rings + 1):
		var row: Array = []
		var phi := PI * float(r) / rings
		for s in range(segs):
			var th := TAU * float(s) / segs + (0.0 if r % 2 == 0 else PI / segs)
			var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var k := 1.0 + rng.randf_range(-jitter, jitter) if (r > 0 and r < rings) else 1.0
			var p := Vector3(dir.x * radii.x, dir.y * radii.y, dir.z * radii.z) * k
			if flatten_bottom > -1.0 and p.y < flatten_bottom * radii.y:
				p.y = flatten_bottom * radii.y
			row.append(p)
		grid.append(row)
	var circ := TAU * maxf(radii.x, radii.z) * uv_scale
	for r in range(rings):
		for s in range(segs):
			var s1 := (s + 1) % segs
			var a: Vector3 = xf * grid[r][s]
			var b: Vector3 = xf * grid[r][s1]
			var c: Vector3 = xf * grid[r + 1][s1]
			var d: Vector3 = xf * grid[r + 1][s]
			var u0 := float(s) / segs * circ
			var u1 := float(s + 1) / segs * circ
			var v0 := float(r) / rings * radii.y * 2.0 * uv_scale
			var v1 := float(r + 1) / rings * radii.y * 2.0 * uv_scale
			var center := xf * Vector3.ZERO
			if r > 0:
				var n1 := (b - a).cross(c - a).normalized()
				if n1.dot((a + b + c) / 3.0 - center) < 0: n1 = -n1
				add_tri(mat, a, b, c, n1, n1, n1, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), col, n1)
			if r < rings - 1:
				var n2 := (c - a).cross(d - a).normalized()
				if n2.dot((a + c + d) / 3.0 - center) < 0: n2 = -n2
				add_tri(mat, a, c, d, n2, n2, n2, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1), col, n2)


## Unit octagon cross-section (x, z): a square with chamfered corners and flat
## front/back/sides. `a` = where the chamfer meets each side (0.414 = regular
## octagon, larger = boxier, smaller = more diamond-like).
static func profile_oct(a: float = 0.45) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(a, -1), Vector2(1, -a), Vector2(1, a), Vector2(a, 1),
		Vector2(-a, 1), Vector2(-1, a), Vector2(-1, -a), Vector2(-a, -1)])


## Cross-section given as unit points; helper to mirror a right-half outline
## (front center -> back center, x >= 0) into a full loop.
static func profile_mirror(right_half: PackedVector2Array) -> PackedVector2Array:
	var pts := PackedVector2Array(right_half)
	for i in range(right_half.size() - 2, 0, -1):
		pts.append(Vector2(-right_half[i].x, right_half[i].y))
	return pts


## Lofted tube along local +Y. Each ring is [y, half_width, half_depth] with
## optional [.., z_offset, x_offset]; `profile` is the unit cross-section loop
## (x, z), -z = front. Gouraud (smooth) normals unless `flat`. With
## `closed` = false the profile is an open strip (shells: coats, hair, hoods);
## open shells are double sided so their insides don't vanish.
func add_loft(mat: Material, xf: Transform3D, rings: Array, profile: PackedVector2Array = PackedVector2Array(),
		uv_scale: float = 2.0, col: Color = Color.WHITE, cap_bottom: bool = false, cap_top: bool = false,
		closed: bool = true, flat: bool = false, double_sided: bool = false,
		ring_bones: PackedInt32Array = PackedInt32Array(),
		face_mat: Material = null, face_uv: Callable = Callable(), face_pick: Callable = Callable()) -> void:
	if profile.is_empty():
		profile = profile_oct()
	var n := profile.size()
	var segs := n if closed else n - 1
	var nr := rings.size()
	if nr < 2 or segs < 1:
		return
	# positions + ring centers (local)
	var grid: Array = []
	var centers: Array = []
	for r in range(nr):
		var ring: Array = rings[r]
		var y: float = ring[0]
		var hw: float = ring[1]
		var hd: float = ring[2]
		var cz: float = ring[3] if ring.size() > 3 else 0.0
		var cx: float = ring[4] if ring.size() > 4 else 0.0
		# optional per-ring cross-section (same point count), e.g. a bust or a V chin
		var prof: PackedVector2Array = profile
		if ring.size() > 5 and ring[5] is PackedVector2Array and (ring[5] as PackedVector2Array).size() == n:
			prof = ring[5]
		var row := PackedVector3Array()
		for i in range(n):
			row.append(Vector3(cx + prof[i].x * hw, y, cz + prof[i].y * hd))
		grid.append(row)
		centers.append(Vector3(cx, y, cz))
	# face normals (outward = away from the ring axis)
	var fn: Array = []
	for r in range(nr - 1):
		var row_n: Array = []
		for i in range(segs):
			var i1 := (i + 1) % n
			var a: Vector3 = grid[r][i]
			var b: Vector3 = grid[r][i1]
			var c: Vector3 = grid[r + 1][i1]
			var d: Vector3 = grid[r + 1][i]
			var nn := (b - a).cross(d - a)
			if nn.length_squared() < 1e-12:
				nn = (c - b).cross(a - b)
			nn = nn.normalized()
			var mid := (a + b + c + d) * 0.25
			var axis := ((centers[r] as Vector3) + (centers[r + 1] as Vector3)) * 0.5
			var out := mid - Vector3(axis.x, mid.y, axis.z)
			if out.length_squared() < 1e-10:
				out = Vector3(mid.x, 0.0, mid.z)
			if nn.dot(out) < 0.0:
				nn = -nn
			row_n.append(nn)
		fn.append(row_n)
	# smooth vertex normals
	var vn: Array = []
	for r in range(nr):
		var row := PackedVector3Array()
		for i in range(n):
			var acc := Vector3.ZERO
			for rr in [r - 1, r]:
				if rr < 0 or rr >= nr - 1:
					continue
				for ii in [i - 1, i]:
					var si: int = ii
					if closed:
						si = (ii + segs) % segs
					elif ii < 0 or ii >= segs:
						continue
					acc += fn[rr][si]
			row.append(acc.normalized() if acc.length_squared() > 0.0 else Vector3.UP)
		vn.append(row)
	# uv: u = arc length around ring 0, v = height
	var us := PackedFloat32Array()
	us.append(0.0)
	for i in range(segs):
		us.append(us[i] + (grid[0][i] as Vector3).distance_to(grid[0][(i + 1) % n]) * uv_scale)
	var vs := PackedFloat32Array()
	vs.append(0.0)
	for r in range(nr - 1):
		vs.append(vs[r] + absf(float(rings[r + 1][0]) - float(rings[r][0])) * uv_scale)
	var bx := xf.basis
	var bn := bx.inverse().transposed()
	for r in range(nr - 1):
		for i in range(segs):
			var i1 := (i + 1) % n
			var pa := xf * (grid[r][i] as Vector3)
			var pb := xf * (grid[r][i1] as Vector3)
			var pc := xf * (grid[r + 1][i1] as Vector3)
			var pd := xf * (grid[r + 1][i] as Vector3)
			var f: Vector3 = (bn * (fn[r][i] as Vector3)).normalized()
			var na := f; var nb := f; var nc := f; var nd := f
			if not flat:
				na = (bn * (vn[r][i] as Vector3)).normalized()
				nb = (bn * (vn[r][i1] as Vector3)).normalized()
				nc = (bn * (vn[r + 1][i1] as Vector3)).normalized()
				nd = (bn * (vn[r + 1][i] as Vector3)).normalized()
			var ua := Vector2(us[i], vs[r]); var ub := Vector2(us[i + 1], vs[r])
			var uc := Vector2(us[i + 1], vs[r + 1]); var ud := Vector2(us[i], vs[r + 1])
			var b0 := bone
			var b1 := bone
			if ring_bones.size() == nr:
				b0 = ring_bones[r]
				b1 = ring_bones[r + 1]
			var vb1 := PackedInt32Array([b0, b0, b1])
			var vb2 := PackedInt32Array([b0, b1, b1])
			var qm := mat
			# projected decal region (e.g. a face wrapped around a head); the
			# picker may also hand back another material for a quad
			var pk = face_pick.call((grid[r][i] + grid[r][i1] + grid[r + 1][i1] + grid[r + 1][i]) * 0.25) if face_mat != null else false
			if pk is Material:
				qm = pk
			elif pk:
				qm = face_mat
				ua = face_uv.call(grid[r][i]); ub = face_uv.call(grid[r][i1])
				uc = face_uv.call(grid[r + 1][i1]); ud = face_uv.call(grid[r + 1][i])
			add_tri(qm, pa, pb, pc, na, nb, nc, ua, ub, uc, col, f, vb1)
			add_tri(qm, pa, pc, pd, na, nc, nd, ua, uc, ud, col, f, vb2)
			if double_sided or not closed:
				add_tri(mat, pa, pb, pc, -na, -nb, -nc, ua, ub, uc, col * 0.8, -f, vb1)
				add_tri(mat, pa, pc, pd, -na, -nc, -nd, ua, uc, ud, col * 0.8, -f, vb2)
	# Caps are geometric: cap_bottom closes the LOWER end ring and cap_top the
	# UPPER one, whichever order the rings were listed in (limbs are lofted
	# shoulder/hip first, i.e. top-down).
	var keep_bone := bone
	var asc := float(rings[nr - 1][0]) >= float(rings[0][0])
	var lo := 0 if asc else nr - 1
	var hi := nr - 1 if asc else 0
	if closed and cap_bottom:
		if ring_bones.size() == nr:
			bone = ring_bones[lo]
		_loft_cap(mat, xf, grid[lo], centers[lo], (bn * Vector3.DOWN).normalized(), uv_scale, col)
	if closed and cap_top:
		if ring_bones.size() == nr:
			bone = ring_bones[hi]
		_loft_cap(mat, xf, grid[hi], centers[hi], (bn * Vector3.UP).normalized(), uv_scale, col)
	bone = keep_bone


## Double-sided sheet through rows of points (cloth panels: coat-tail and
## skirt sectors). rows[r] is a row of points; row_bones[r] skins each row.
## Normals face away from the vertical axis through `center`.
func add_strip_grid(mat: Material, xf: Transform3D, rows: Array, row_bones: PackedInt32Array = PackedInt32Array(),
		uv_scale: float = 2.0, col: Color = Color.WHITE, center: Vector3 = Vector3.ZERO) -> void:
	var nr := rows.size()
	if nr < 2:
		return
	var bn := xf.basis.inverse().transposed()
	var v_acc := 0.0
	for r in range(nr - 1):
		var top: PackedVector3Array = rows[r]
		var bot: PackedVector3Array = rows[r + 1]
		var dv := absf(top[0].y - bot[0].y) * uv_scale
		var u_acc := 0.0
		for i in range(top.size() - 1):
			var a := top[i]; var b := top[i + 1]; var c := bot[i + 1]; var d := bot[i]
			var nn := (b - a).cross(d - a).normalized()
			var mid := (a + b + c + d) * 0.25
			var out := mid - Vector3(center.x, mid.y, center.z)
			if nn.dot(out) < 0.0:
				nn = -nn
			var du := a.distance_to(b) * uv_scale
			var b0 := row_bones[r] if row_bones.size() == nr else bone
			var b1 := row_bones[r + 1] if row_bones.size() == nr else bone
			var pa := xf * a; var pb := xf * b; var pc := xf * c; var pd := xf * d
			var w := (bn * nn).normalized()
			var ua := Vector2(u_acc, v_acc); var ub := Vector2(u_acc + du, v_acc)
			var uc := Vector2(u_acc + du, v_acc + dv); var ud := Vector2(u_acc, v_acc + dv)
			add_tri(mat, pa, pb, pc, w, w, w, ua, ub, uc, col, w, PackedInt32Array([b0, b0, b1]))
			add_tri(mat, pa, pc, pd, w, w, w, ua, uc, ud, col, w, PackedInt32Array([b0, b1, b1]))
			add_tri(mat, pa, pb, pc, -w, -w, -w, ua, ub, uc, col * 0.78, -w, PackedInt32Array([b0, b0, b1]))
			add_tri(mat, pa, pc, pd, -w, -w, -w, ua, uc, ud, col * 0.78, -w, PackedInt32Array([b0, b1, b1]))
			u_acc += du
		v_acc += dv


## Flat cross-section disc (e.g. a hat brim) at local height y, both sides.
func add_profile_disc(mat: Material, xf: Transform3D, y: float, hw: float, hd: float,
		profile: PackedVector2Array, uv_scale: float = 2.0, col: Color = Color.WHITE) -> void:
	var row := PackedVector3Array()
	for p in profile:
		row.append(Vector3(p.x * hw, y, p.y * hd))
	var bn := xf.basis.inverse().transposed()
	_loft_cap(mat, xf, row, Vector3(0, y, 0), (bn * Vector3.UP).normalized(), uv_scale, col)
	_loft_cap(mat, xf, row, Vector3(0, y, 0), (bn * Vector3.DOWN).normalized(), uv_scale, col * 0.75)


func _loft_cap(mat: Material, xf: Transform3D, row: PackedVector3Array, center: Vector3, nrm: Vector3, uv_scale: float, col: Color) -> void:
	var c := xf * center
	for i in range(row.size()):
		var a := xf * row[i]
		var b := xf * row[(i + 1) % row.size()]
		add_tri(mat, c, a, b, nrm, nrm, nrm,
			Vector2(center.x, center.z) * uv_scale, Vector2(row[i].x, row[i].z) * uv_scale,
			Vector2(row[(i + 1) % row.size()].x, row[(i + 1) % row.size()].z) * uv_scale, col, nrm)


## Append another builder's triangles (so several parts share one mesh).
func merge(other: MeshBuilder) -> void:
	for mat in other._order:
		var src: Dictionary = other._surfaces[mat]
		var dst := _surf(mat)
		dst["v"].append_array(src["v"])
		dst["n"].append_array(src["n"])
		dst["uv"].append_array(src["uv"])
		dst["c"].append_array(src["c"])
		dst["b"].append_array(src["b"])
		dst["w"].append_array(src["w"])


## Commit everything into an ArrayMesh (one surface per material).
func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in _order:
		var s: Dictionary = _surfaces[mat]
		if s["v"].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s["v"]
		arrays[Mesh.ARRAY_NORMAL] = s["n"]
		arrays[Mesh.ARRAY_TEX_UV] = s["uv"]
		arrays[Mesh.ARRAY_COLOR] = s["c"]
		if skinned:
			arrays[Mesh.ARRAY_BONES] = s["b"]
			arrays[Mesh.ARRAY_WEIGHTS] = s["w"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh


## Convenience: commit into a MeshInstance3D.
func to_instance(node_name: String = "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = commit()
	return mi
