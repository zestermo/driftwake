class_name ClothSheet
extends Node3D
## (1.30.3 piece 2, docs/v1_30_3_clothing_plan.md) A connected sheet of cloth: a grid of points (rows down, columns
## across) linked to their neighbours along and across the rows (and diagonally, and two apart to resist bending), so
## panels can't part: a skirt is one closed ring, a coat's tails one sheet with its front left open and a vent cut up
## the back. Position-based dynamics in substeps against the anchor (the hips), its top row pinned, every point tethered
## to its column's top so nothing stretches past its length, the body's capsules kept out of the points and of the
## edges between them (so a leg can't slip between two columns). Each point is a bone; each vertex follows its point,
## turned with the sheet there (so its lighting turns too). GDScript for the lab: the C++ port follows Zach's OK.
##
## Built by BodyBuilder._cloth_lattice (BodyBuilder.cloth_lattice, cycled in the cloth stage), stepped by Humanoid
## beside its SpringChains.

## How heavy it swings: damping (as SpringChains: velocity lost a 60 Hz step), the pull back to the cut shape (a 60 Hz
## step), how much of the body's own motion it feels (0: rides with the body, 1: hangs in the world), substeps a frame.
var damping := 0.29
var rest_k := 0.02
var inertia := 0.4
var substeps := 4
## Stiffness of the links (0..1 a pass): along/across, diagonals, two apart.
var k_struct := 1.0
var k_shear := 0.5
var k_bend := 0.12
## Kept this far off the capsules' surfaces, and how much sliding along them is lost on contact.
var thickness := 0.012
var friction := 0.35
var gravity := Vector3(0, -9.8, 0)
## name -> {node, a, b, r}, as SpringChains.colliders; `collide` the names this sheet stays out of.
var colliders: Dictionary = {}
var collide: PackedStringArray = PackedStringArray()

var skel: Skeleton3D
var mb: MeshBuilder
var nr := 0
var nc := 0
var closed := false
var rest := PackedVector3Array()
var pinned := PackedByteArray()
var x := PackedVector3Array()
var v := PackedVector3Array()
var _p := PackedVector3Array()
var _la := PackedInt32Array()
var _lb := PackedInt32Array()
var _ll := PackedFloat32Array()
var _lk := PackedFloat32Array()
var _ea := PackedInt32Array()
var _eb := PackedInt32Array()
var _root := PackedInt32Array()
var _reach := PackedFloat32Array()
## Per point, its neighbours for its frame: left, right, up, down (itself where there's none).
var _nl := PackedInt32Array()
var _nr := PackedInt32Array()
var _nu := PackedInt32Array()
var _nd := PackedInt32Array()
var _rest_basis: Array = []
var _g_prev := Transform3D()
var _g_step := Transform3D()
var _g_last := Transform3D()
var _acc := 0.0
## The points at the step before the last (drawn blended toward `x`).
var _xl := PackedVector3Array()
var _fresh := true
const STEP := 1.0 / 60.0
const MAX_STEPS := 4
var _ca := PackedVector3Array()
var _cb := PackedVector3Array()
var _cr := PackedFloat32Array()


func _init() -> void:
	name = "ClothSheet"
	skel = Skeleton3D.new()
	skel.name = "Skeleton"
	add_child(skel)
	mb = MeshBuilder.new()
	mb.skinned = true


## The sheet's points in the anchor's space: `rows` top to bottom, each the same count across. `closed` links the last
## column to the first (a ring). `cuts`: column c -> the first row with no link between columns c and c+1 (a vent).
func setup(rows: Array, is_closed: bool, cuts: Dictionary = {}) -> void:
	nr = rows.size()
	nc = (rows[0] as PackedVector3Array).size()
	closed = is_closed
	rest = PackedVector3Array()
	for r in rows:
		rest.append_array(r)
	var n := nr * nc
	pinned.resize(n)
	for i in range(n):
		pinned[i] = 1 if i < nc else 0
	x = rest.duplicate()
	v.resize(n)
	_p = rest.duplicate()
	var across := func(r: int, c: int) -> int:
		# the column right of c on row r, or -1 (the open edge, or a cut)
		var c2 := c + 1
		if c2 >= nc:
			if not closed:
				return -1
			c2 = 0
		if cuts.has(c) and r >= int(cuts[c]):
			return -1
		return r * nc + c2
	for r in range(nr):
		for c in range(nc):
			var i := r * nc + c
			var rt: int = across.call(r, c)
			if rt >= 0:
				_link(i, rt, k_struct)
				_ea.append(i)
				_eb.append(rt)
			if r + 1 < nr:
				_link(i, i + nc, k_struct)
				_ea.append(i)
				_eb.append(i + nc)
				var rt2: int = across.call(r + 1, c)
				if rt >= 0 and rt2 >= 0:
					_link(i, rt2, k_shear)
					_link(rt, i + nc, k_shear)
			if r + 2 < nr:
				_link(i, i + 2 * nc, k_bend)
			if rt >= 0:
				var rr: int = across.call(r, rt % nc)
				if rr >= 0 and rr != i:
					_link(i, rr, k_bend)
	# tethers: each point no further from its column's top than the column's length down to it
	_root.resize(n)
	_reach.resize(n)
	for c in range(nc):
		var acc := 0.0
		for r in range(nr):
			var i := r * nc + c
			if r > 0:
				acc += rest[i].distance_to(rest[i - nc])
			_root[i] = c
			_reach[i] = acc * 1.03
	# each point's neighbours for its frame
	for r in range(nr):
		for c in range(nc):
			var i := r * nc + c
			var l := r * nc + (c - 1 if c > 0 else (nc - 1 if closed else c))
			var rt := r * nc + (c + 1 if c + 1 < nc else (0 if closed else c))
			_nl.append(l)
			_nr.append(rt)
			_nu.append(i - nc if r > 0 else i)
			_nd.append(i + nc if r + 1 < nr else i)
	for i in range(n):
		skel.add_bone("p%d" % i)
		skel.set_bone_rest(i, Transform3D(Basis(), rest[i]))
		_rest_basis.append(_frame(rest, i))


func _link(a: int, b: int, k: float) -> void:
	_la.append(a)
	_lb.append(b)
	_ll.append(rest[a].distance_to(rest[b]))
	_lk.append(k)


## The sheet as a two-sided mesh (call after setup): a quad between every linked square, each vertex on its point's
## bone. `center` (anchor space) is what the outside faces away from; `u_span` the texture's width across.
func build_mesh(mat: Material, center: Vector3, uv_scale: float = 3.0, col: Color = Color.WHITE) -> void:
	var nrm_of := func(i: int) -> Vector3:
		var o := rest[i] - Vector3(center.x, rest[i].y, center.z)
		return o.normalized() if o.length_squared() > 1e-8 else Vector3.FORWARD
	var u := PackedFloat32Array()
	u.resize(nc + 1)
	for c in range(nc):
		var c2 := (c + 1) % nc
		u[c + 1] = u[c] + rest[c].distance_to(rest[c2]) * uv_scale
	for r in range(nr - 1):
		for c in range(nc):
			var i := r * nc + c
			var j := _right_of(r, c)
			var jd := _right_of(r + 1, c)
			if j < 0 or jd < 0:
				continue
			var a := i
			var b := j
			var cc := jd
			var d := i + nc
			var va := r * 0.12 * uv_scale
			var vb := (r + 1) * 0.12 * uv_scale
			var ua := Vector2(u[c], va)
			var ub := Vector2(u[c + 1], va)
			var uc := Vector2(u[c + 1], vb)
			var ud := Vector2(u[c], vb)
			var na: Vector3 = nrm_of.call(a)
			var nb: Vector3 = nrm_of.call(b)
			var nc_: Vector3 = nrm_of.call(cc)
			var nd: Vector3 = nrm_of.call(d)
			# (wound to face out: the side the normals point)
			var face := (rest[b] - rest[a]).cross(rest[d] - rest[a])
			var flip := face.dot(na + nb + nc_ + nd) < 0.0
			if flip:
				mb.add_tri(mat, rest[a], rest[cc], rest[b], na, nc_, nb, ua, uc, ub, col, na, PackedInt32Array([a, cc, b]))
				mb.add_tri(mat, rest[a], rest[d], rest[cc], na, nd, nc_, ua, ud, uc, col, na, PackedInt32Array([a, d, cc]))
				mb.add_tri(mat, rest[a], rest[b], rest[cc], -na, -nb, -nc_, ua, ub, uc, col * 0.78, -na, PackedInt32Array([a, b, cc]))
				mb.add_tri(mat, rest[a], rest[cc], rest[d], -na, -nc_, -nd, ua, uc, ud, col * 0.78, -na, PackedInt32Array([a, cc, d]))
			else:
				mb.add_tri(mat, rest[a], rest[b], rest[cc], na, nb, nc_, ua, ub, uc, col, na, PackedInt32Array([a, b, cc]))
				mb.add_tri(mat, rest[a], rest[cc], rest[d], na, nc_, nd, ua, uc, ud, col, na, PackedInt32Array([a, cc, d]))
				mb.add_tri(mat, rest[a], rest[cc], rest[b], -na, -nc_, -nb, ua, uc, ub, col * 0.78, -na, PackedInt32Array([a, cc, b]))
				mb.add_tri(mat, rest[a], rest[d], rest[cc], -na, -nd, -nc_, ua, ud, uc, col * 0.78, -na, PackedInt32Array([a, d, cc]))


func _right_of(r: int, c: int) -> int:
	# the point right of (r, c) if the square's top edge is linked (the mesh follows the links: a cut stays open)
	var i := r * nc + c
	var c2 := c + 1
	if c2 >= nc:
		if not closed:
			return -1
		c2 = 0
	var j := r * nc + c2
	for k in range(_ea.size()):
		if _ea[k] == i and _eb[k] == j:
			return j
	return -1


## Commit the skinned mesh to the skeleton (like SpringChains.finalize).
func finalize() -> void:
	if mb.is_empty():
		return
	skel.reset_bone_poses()
	var skin := Skin.new()
	for b in range(skel.get_bone_count()):
		skin.add_bind(b, skel.get_bone_global_rest(b).affine_inverse())
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mb.commit()
	mi.skin = skin
	skel.add_child(mi)
	mi.skeleton = NodePath("..")


func reset() -> void:
	_fresh = true


## A point's frame from its neighbours: across, out of the sheet, down.
func _frame(pts: PackedVector3Array, i: int) -> Basis:
	var t := pts[_nr[i]] - pts[_nl[i]]
	var d := pts[_nd[i]] - pts[_nu[i]]
	if t.length_squared() < 1e-10 or d.length_squared() < 1e-10:
		return Basis()
	t = t.normalized()
	var n := t.cross(d).normalized()
	if n.length_squared() < 1e-10:
		return Basis()
	var dd := n.cross(t)
	return Basis(t, n, dd)


func simulate(delta: float) -> void:
	if nr == 0 or not is_inside_tree():
		return
	var g := get_global_transform_interpolated()
	var n := x.size()
	if _fresh or g.origin.distance_to(_g_prev.origin) > 2.5:
		for i in range(n):
			x[i] = g * rest[i]
			v[i] = Vector3.ZERO
		_xl = x.duplicate()
		_g_prev = g
		_g_last = g
		_g_step = g
		_acc = 0.0
		_fresh = false
	# fixed 60 Hz steps against the body where it was at each step's moment, drawn blended between the last two (as
	# SpringChains' "n": smooth on any screen, and the same motion at 60 or 144 fps)
	var g0 := _g_prev
	var acc0 := _acc
	_acc = minf(_acc + delta, STEP * MAX_STEPS)
	var total := _acc - acc0
	var took := 0.0
	while _acc >= STEP:
		_acc -= STEP
		took += STEP
		var gs := g0.interpolate_with(g, clampf((took - acc0) / maxf(total, 1e-6), 0.0, 1.0)) if total > 0.0 else g
		_xl = x.duplicate()
		_g_last = _g_step
		_step(gs)
		_g_step = gs
	_g_prev = g
	_pose(g, _acc / STEP)


## One 60 Hz step against the body at `g`, in `substeps`.
func _step(g: Transform3D) -> void:
	var n := x.size()
	# the capsules where they're drawn this frame
	_ca.resize(0)
	_cb.resize(0)
	_cr.resize(0)
	for key in collide:
		if not colliders.has(key):
			continue
		var cd: Dictionary = colliders[key]
		var tt: Transform3D = (cd["node"] as Node3D).get_global_transform_interpolated()
		_ca.append(tt * (cd["a"] as Vector3))
		_cb.append(tt * (cd["b"] as Vector3))
		_cr.append(float(cd["r"]) * tt.basis.get_scale().x + thickness)
	# the body's motion this step, felt only by `inertia` of it: the rest rides along
	var follow := 1.0 - inertia
	if follow > 0.0:
		var m := g * _g_step.affine_inverse()
		for i in range(n):
			x[i] = x[i].lerp(m * x[i], follow)
	var h := STEP / substeps
	var keep := pow(1.0 - damping, 60.0 * h)
	var kr := 1.0 - pow(1.0 - rest_k, 60.0 * h)
	for s in range(substeps):
		var gi := _g_step.interpolate_with(g, float(s + 1) / substeps)
		for i in range(n):
			var home := gi * rest[i]
			if pinned[i]:
				_p[i] = home
				continue
			v[i] = (v[i] + gravity * h) * keep
			_p[i] = (x[i] + v[i] * h).lerp(home, kr)
		_solve_links()
		_tether()
		_collide_points()
		_collide_edges()
		for i in range(n):
			if not pinned[i]:
				v[i] = (_p[i] - x[i]) / h
			x[i] = _p[i]


func _solve_links() -> void:
	for k in range(_la.size()):
		var a := _la[k]
		var b := _lb[k]
		var wa := 0.0 if pinned[a] else 1.0
		var wb := 0.0 if pinned[b] else 1.0
		var w := wa + wb
		if w == 0.0:
			continue
		var d := _p[b] - _p[a]
		var l := d.length()
		if l < 1e-7:
			continue
		var corr := d * ((l - _ll[k]) / (l * w) * _lk[k])
		_p[a] += corr * wa
		_p[b] -= corr * wb


func _tether() -> void:
	for i in range(nc, _p.size()):
		var r := _p[_root[i]]
		var d := _p[i] - r
		var l := d.length()
		if l > _reach[i]:
			_p[i] = r + d * (_reach[i] / l)


func _collide_points() -> void:
	for ci in range(_ca.size()):
		var a := _ca[ci]
		var ab := _cb[ci] - a
		var l2 := ab.length_squared()
		var r := _cr[ci]
		for i in range(nc, _p.size()):
			var pt := _p[i]
			var t := clampf((pt - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-8 else 0.0
			var cl := a + ab * t
			var off := pt - cl
			var dd := off.length_squared()
			if dd >= r * r:
				continue
			var dist := sqrt(dd)
			var nn := off / dist if dist > 1e-6 else Vector3.FORWARD
			var np := cl + nn * r
			# friction: of the step taken this substep, the part along the surface is cut back
			var step := np - x[i]
			var tang := step - nn * step.dot(nn)
			_p[i] = np - tang * friction


func _collide_edges() -> void:
	for ci in range(_ca.size()):
		var a := _ca[ci]
		var b := _cb[ci]
		var r := _cr[ci]
		var ab := b - a
		var l2 := ab.length_squared()
		for k in range(_ea.size()):
			var i := _ea[k]
			var j := _eb[k]
			if i < nc and j < nc:
				continue
			# (a quick miss: the edge's middle further from the capsule's axis than its reach and half the edge)
			var mid := (_p[i] + _p[j]) * 0.5
			var tm := clampf((mid - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-8 else 0.0
			var reach := r + _p[i].distance_to(_p[j]) * 0.5
			if mid.distance_squared_to(a + ab * tm) > reach * reach:
				continue
			var st: Array = SpringChains._closest_segments(_p[i], _p[j], a, b)
			var on_e: Vector3 = st[0]
			var on_c: Vector3 = st[1]
			var off := on_e - on_c
			var dd := off.length_squared()
			if dd >= r * r:
				continue
			var dist := sqrt(dd)
			var nn := off / dist if dist > 1e-6 else Vector3.FORWARD
			var e := _p[j] - _p[i]
			var el2 := e.length_squared()
			var t := clampf((on_e - _p[i]).dot(e) / el2, 0.0, 1.0) if el2 > 1e-10 else 0.5
			var wi := 0.0 if pinned[i] else 1.0 - t
			var wj := 0.0 if pinned[j] else t
			if wi + wj < 1e-6:
				continue
			# (the contact moved out by the overlap; near a pinned end the free end's share is floored, or a touch
			# beside the waist row flung the hem point metres: one point shot up as a spike)
			var ws := maxf(wi * wi + wj * wj, 0.5)
			var push := nn * ((r - dist) / ws)
			_p[i] += push * wi
			_p[j] += push * wj


func _pose(g: Transform3D, f: float) -> void:
	# each step's points in the body's space as of that step, blended by how far the frame is into the next one
	var inv_a := _g_last.affine_inverse()
	var inv_b := _g_step.affine_inverse()
	var loc := PackedVector3Array()
	loc.resize(x.size())
	for i in range(x.size()):
		loc[i] = (inv_a * _xl[i]).lerp(inv_b * x[i], f)
	for i in range(x.size()):
		var b := _frame(loc, i) * (_rest_basis[i] as Basis).inverse()
		skel.set_bone_pose(i, Transform3D(b.orthonormalized(), loc[i]))
