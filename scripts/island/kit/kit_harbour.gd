class_name KitHarbour
extends RefCounted
## A harbour town's waterfront along a straight-ish stretch of coast: the stone
## quay and sea wall (`plan` finds where the shore runs), the main pier where the
## ship ties up, side piers with trading ships, longboats, a row or two of houses
## shoulder to shoulder facing the water, the harbour front (the harbourmaster's
## booth, a boat on the stocks in the shipwright's yard, the net-mender's corner)
## and the quay's cargo, carts, lamps and stalls.
##
## Its frame: `out` is the way to the sea, `inland` the opposite, `along` the shore
## (out rotated so the frame never mirrors). Frame coordinates (s along, t inland)
## are measured from `origin`; Brinehollow's frame is the island's own axes (sea
## at -z), so its numbers come out exactly as they were. The island's height
## function calls `shape` (the quay ground lowered, the waterfront levelled) and
## its walk height `on_platform`, so plan it before the heights.

var origin := Vector2.ZERO
var out := Vector2(0, -1)
var inland := Vector2(0, 1)
var along := Vector2(1, 0)
## The frame's yaw (0 when along is +x).
var yaw := 0.0
var step := 2.0
var quay_y := 1.62
var quay_w := 11.0
var street_w := 4.5
## The paved platform's whole depth (quay and street), a curb at its back.
var plat_d := 15.5
var pier_hw := 3.0
var pier_len := 28.0
## The wooden piers' deck height and their posts' foot.
var deck_y := 1.7
var floor_y := -13.0
## The sea wall: its stations along the shore and its inland coordinate at each.
var wall_s := PackedFloat32Array()
var wall_t := PackedFloat32Array()
## The quay's ends (along), the pier's station, its root on the sea wall.
var s0 := 0.0
var s1 := 0.0
var dock_s := 0.0
var dock := Vector2.ZERO


## Where the quay runs (data only: a worker may call it): the shoreline either
## side of the pier's station `dock_s`, scanned from `scan[0]` toward `scan[1]`
## (frame t) for ground under `sea_h`, as far as it stays fairly straight (it
## stops where the coast turns away), smoothed. `height` is (x, z) -> ground.
## opts: out, origin, stations [first, last], step, scan, sea_h, dock_s, quay_y,
## quay_w, street_w, pier_hw, pier_len, deck_y, floor_y.
static func plan(height: Callable, opts: Dictionary) -> KitHarbour:
	var h := KitHarbour.new()
	h.out = opts.get("out", Vector2(0, -1))
	h.inland = Vector2(-h.out.x + 0.0, -h.out.y + 0.0)
	h.along = Vector2(h.inland.y + 0.0, -h.inland.x + 0.0)
	h.yaw = atan2(h.inland.x, h.inland.y)
	h.origin = opts.get("origin", Vector2.ZERO)
	h.step = float(opts.get("step", 2.0))
	h.dock_s = float(opts.get("dock_s", 0.0))
	for k in ["quay_y", "quay_w", "street_w", "pier_hw", "pier_len", "deck_y", "floor_y"]:
		if opts.has(k):
			h.set(k, float(opts[k]))
	h.plat_d = h.quay_w + h.street_w
	var stations: Array = opts.get("stations", [-34, 36])
	var scan: Array = opts.get("scan", [-96.0, -200.0])
	var sea_h := float(opts.get("sea_h", 0.6))
	var ss: Array = []
	var ts: Array = []
	for i in range(int(stations[0]), int(stations[1]) + 1):
		var s := i * h.step
		var t := float(scan[0])
		while t > float(scan[1]) and float(height.call(h.fx(s, t), h.fz(s, t))) > sea_h:
			t -= 0.5
		ss.append(s)
		ts.append(t)
	var mid := int(round(h.dock_s / h.step)) - int(stations[0])
	var lo := mid
	var hi := mid
	while lo > 0 and absf(float(ts[lo - 1]) - float(ts[lo])) < 5.0 and absf(float(ts[lo - 1]) - float(ts[mid])) < 40.0:
		lo -= 1
	while hi < ss.size() - 1 and absf(float(ts[hi + 1]) - float(ts[hi])) < 5.0 and absf(float(ts[hi + 1]) - float(ts[mid])) < 40.0:
		hi += 1
	# a few metres in from the turn
	lo = mini(lo + 2, mid)
	hi = maxi(hi - 2, mid)
	for pass_i in range(3):
		var sm: Array = ts.duplicate()
		for i in range(lo, hi + 1):
			sm[i] = (float(ts[maxi(i - 1, lo)]) + float(ts[i]) * 2.0 + float(ts[mini(i + 1, hi)])) * 0.25
		ts = sm
	for i in range(lo, hi + 1):
		h.wall_s.append(float(ss[i]))
		h.wall_t.append(float(ts[i]) - 2.0)
	h.s0 = h.wall_s[0]
	h.s1 = h.wall_s[h.wall_s.size() - 1]
	h.dock = h.quay_pt(h.dock_s, 0.0)
	return h


# --------------------------------------------------------------------------
# The frame (data)
# --------------------------------------------------------------------------
func fx(s: float, t: float) -> float:
	return origin.x + along.x * s + inland.x * t


func fz(s: float, t: float) -> float:
	return origin.y + along.y * s + inland.y * t


## Frame (s, t) to island space.
func pt(s: float, t: float) -> Vector2:
	return Vector2(fx(s, t), fz(s, t))


## Frame (s, y, t) to island space.
func fv(s: float, y: float, t: float) -> Vector3:
	return Vector3(fx(s, t), y, fz(s, t))


## A frame-local basis turned into island space.
func fb(b: Basis) -> Basis:
	return b if yaw == 0.0 else Basis(Vector3.UP, yaw) * b


func s_of(p: Vector2) -> float:
	return (p.x - origin.x) * along.x + (p.y - origin.y) * along.y


func t_of(p: Vector2) -> float:
	return (p.x - origin.x) * inland.x + (p.y - origin.y) * inland.y


## `base` moved s along the shore and t inland.
func off(base: Vector2, s: float, t: float) -> Vector2:
	return base + along * s + inland * t


## The sea wall's line (frame t) at s.
func wall(s: float) -> float:
	var f := clampf((s - wall_s[0]) / step, 0.0, float(wall_s.size() - 1))
	var i := mini(int(f), wall_s.size() - 2)
	return lerpf(wall_t[i], wall_t[i + 1], f - i)


## The point `in_m` metres in from the sea wall at s.
func quay_pt(s: float, in_m: float) -> Vector2:
	return pt(s, wall(s) + in_m)


## Along the main pier from its root on the sea wall.
func dock_point(d: float) -> Vector2:
	return dock + out * d


## On the quay's paving (quay and street), or out on the main pier?
func on_platform(p: Vector2) -> bool:
	var ps := s_of(p)
	var ptt := t_of(p)
	var ds := s_of(dock)
	var dt := t_of(dock)
	if absf(ps - ds) <= pier_hw and ptt <= dt + 0.5 and ptt >= dt - pier_len:
		return true
	if ps < s0 or ps > s1:
		return false
	var dz := ptt - wall(ps)
	return dz >= 0.0 and dz <= plat_d


## 0..1 how much of the harbour's stretch of shore s is on.
func weight(s: float) -> float:
	return _smooth(s0 - 6.0, s0, s) * (1.0 - _smooth(s1, s1 + 6.0, s))


## The island's height at (x, z) with the harbour in: the ground under the quay
## kept low (the quay is built over it), the waterfront behind levelled to its top.
func shape(x: float, z: float, h: float) -> float:
	var s := (x - origin.x) * along.x + (z - origin.y) * along.y
	var pw := weight(s)
	if pw > 0.0:
		var dz := (x - origin.x) * inland.x + (z - origin.y) * inland.y - wall(s)
		if dz > -6.0 and dz < plat_d:
			h = lerpf(h, minf(h, quay_y - 0.6), pw)
		elif dz >= plat_d:
			h = lerpf(h, quay_y - 0.2, pw * (1.0 - _smooth(28.0, 38.0, dz)))
	return h


## Packed earth behind the quay, among the waterfront houses (the terrain's dirt splat).
func earth(x: float, z: float) -> float:
	var s := (x - origin.x) * along.x + (z - origin.y) * along.y
	var pw := weight(s)
	var dz := (x - origin.x) * inland.x + (z - origin.y) * inland.y - wall(s)
	if pw > 0.0 and dz > plat_d - 1.0:
		return pw * (1.0 - _smooth(22.0, 32.0, dz))
	return 0.0


static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# --------------------------------------------------------------------------
# The main pier: a stone jetty out from the sea wall, flush with the quay
# --------------------------------------------------------------------------
## Coping and bollards along both sides, a timber fender down the +along side
## where the ship lies, ladders at the head and down the other side, a lamp at the
## end (lit) and halfway, cargo waiting to go aboard, the "Board ship" area.
func build_pier(ctx: KitContext) -> void:
	var body := StaticBody3D.new()
	body.name = "HarbourPier"
	body.collision_layer = 1
	body.collision_mask = 0
	var shell := MeshBuilder.new()
	var mb := MeshBuilder.new()
	var cob := PSXMat.lit(ctx.style["paving"], Color.WHITE, {"affine": 0.6})
	var wall_m := PSXMat.lit("stone_brick", ctx.style["quay_wall"], {"affine": 0.6})
	var cope := PSXMat.lit("stone_brick", ctx.style["quay_cope"])
	var iron := PSXMat.lit("metal", ctx.style["iron"])
	var wood := PSXMat.lit("planks_dark")
	var y := quay_y
	var bottom := -5.0
	var ds := s_of(dock)
	var dt := t_of(dock)
	var x0 := ds - pier_hw
	var x1 := ds + pier_hw
	var z0 := dt + 0.5
	var z1 := dt - pier_len
	# the top in four lengths (small texture warp), the sides and the head
	for k in range(4):
		var za := lerpf(z0, z1, k / 4.0)
		var zb := lerpf(z0, z1, (k + 1) / 4.0)
		shell.add_quad(cob, fv(x0, y, za), fv(x1, y, za), fv(x1, y, zb), fv(x0, y, zb),
			Vector2(x0, za) * 0.4, Vector2(x1, za) * 0.4, Vector2(x1, zb) * 0.4, Vector2(x0, zb) * 0.4, Color.WHITE, Vector3.UP)
		for s in [-1.0, 1.0]:
			var x: float = ds + s * pier_hw
			var nrm := fb(Basis()) * Vector3(s, 0, 0)
			shell.add_quad(wall_m, fv(x, y, za), fv(x, y, zb), fv(x, 0.4, zb), fv(x, 0.4, za),
				Vector2(za, 0) * 0.4, Vector2(zb, 0) * 0.4, Vector2(zb, 0.5), Vector2(za, 0.5), Color.WHITE, nrm)
			shell.add_quad(wall_m, fv(x, 0.4, za), fv(x, 0.4, zb), fv(x, bottom, zb), fv(x, bottom, za),
				Vector2(za, 0.5), Vector2(zb, 0.5), Vector2(zb, 2.6), Vector2(za, 2.6), Color(0.55, 0.6, 0.55), nrm)
	shell.add_quad(wall_m, fv(x0, y, z1), fv(x1, y, z1), fv(x1, bottom, z1), fv(x0, bottom, z1),
		Vector2(x0, 0) * 0.4, Vector2(x1, 0) * 0.4, Vector2(x1, 2.6), Vector2(x0, 2.6), Color(0.85, 0.85, 0.85), fb(Basis()) * Vector3.FORWARD)
	var shell_mesh := shell.commit()
	var shell_i := MeshInstance3D.new()
	shell_i.name = "PierShell"
	shell_i.mesh = shell_mesh
	shell_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(shell_i)
	var cs_shell := CollisionShape3D.new()
	cs_shell.shape = shell_mesh.create_trimesh_shape()
	body.add_child(cs_shell)
	# coping down both sides and across the head
	for s in [-1.0, 1.0]:
		var cx: float = ds + s * (pier_hw - 0.25)
		mb.add_box(cope, Transform3D(fb(Basis()), fv(cx, y + 0.06, (z0 + z1) * 0.5)), Vector3(0.62, 0.18, z0 - z1), 0.8, Color.WHITE, false)
	mb.add_box(cope, Transform3D(fb(Basis()), fv(ds, y + 0.06, z1 + 0.25)), Vector3(pier_hw * 2.0, 0.18, 0.62), 0.8, Color.WHITE, false)
	# bollards, both sides
	for d in [5.0, 12.0, 19.0, pier_len - 1.2]:
		for s in [-1.0, 1.0]:
			var q := off(dock_point(d), s * (pier_hw - 0.5), 0.0)
			mb.add_cylinder(iron, Transform3D(Basis(), Vector3(q.x, y + 0.1, q.y)), 0.16, 0.2, 0.42, 7, 1.0)
			mb.add_cylinder(iron, Transform3D(Basis(), Vector3(q.x, y + 0.52, q.y)), 0.24, 0.24, 0.07, 7, 1.0)
	# the timber fender where the ship lies, a rubbing strake along it
	var ffx := x1 + 0.12
	var ffz := z1 + 1.0
	while ffz < dt - 6.0:
		mb.add_box(wood, Transform3D(fb(Basis()), fv(ffx, (y - 0.6) * 0.5 + 0.1, ffz)), Vector3(0.24, y + 0.6, 0.26), 1.0)
		ffz += 1.6
	mb.add_box(wood, Transform3D(fb(Basis()), fv(ffx + 0.1, y - 0.25, (z1 + dt - 6.0) * 0.5)), Vector3(0.16, 0.22, dt - 6.0 - z1), 1.0, Color.WHITE, false)
	var dressing := mb.to_instance("PierDressing")
	body.add_child(dressing)
	ctx.add(body)
	# ladders for swimmers: at the head and down the other side
	var back := Vector2(-along.x + 0.0, -along.y + 0.0)
	for spec in [[dock_point(pier_len), out], [dock_point(pier_len - 4.0) - along * pier_hw, back],
			[dock_point(9.0) - along * pier_hw, back]]:
		var at: Vector2 = spec[0]
		var lad := Ladder.new()
		lad.length = quay_y + 1.2
		lad.rail = 0.0
		lad.deck_depth = 0.9
		ctx.put(lad, Vector3(at.x, quay_y, at.y), KitContext.face_yaw(spec[1]))
	for d in range(0, int(pier_len) + 4, 4):
		ctx.reserve(dock_point(d), pier_hw + 0.5)
	# lamps at the head (lit) and halfway, cargo waiting to go aboard
	for lp in [[dock_point(pier_len - 0.9) - along * (pier_hw - 0.6), 1.6], [dock_point(13.0) - along * (pier_hw - 0.6), 0.0]]:
		KitLights.post(ctx, lp[0], KitContext.face_yaw(along) - PI * 0.5, 0.0, lp[1])
	ctx.place(Props.barrel(), off(dock_point(15.0), -1.6, 0.2), yaw + 0.0)
	ctx.place(Props.barrel(), off(dock_point(15.6), -1.9, -0.5), yaw + 0.0)
	ctx.place(Props.crate(0.8), off(dock_point(16.6), -1.5, 0.0), yaw + 0.3)
	ctx.place(Props.rope_coil(), off(dock_point(pier_len - 2.5), 1.8, 0.0))
	ctx.place(Props.rope_coil(), off(dock_point(10.0), 1.9, 0.0))
	# board the ship at the end of the pier
	var area := Interactable.new()
	area.name = "DockingArea"
	area.collision_layer = 512
	area.collision_mask = 0
	area.prompt_text = "Board ship"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 4.0
	cs.shape = sph
	area.add_child(cs)
	ctx.put(area, KitContext.v3(dock_point(pier_len - 2.0)) + Vector3(0, quay_y + 1.0, 0))


# --------------------------------------------------------------------------
# The quay
# --------------------------------------------------------------------------
## A paved platform on a stone sea wall with coping, bollards and swimmers'
## ladders, closed at both ends; its shell is its collision. `gaps`: stations
## (along) kept clear of bollards (the piers).
func build_quay(ctx: KitContext, rng: RandomNumberGenerator, gaps: Array) -> void:
	var mb := MeshBuilder.new()
	var cob := PSXMat.lit(ctx.style["paving"], Color.WHITE, {"affine": 0.6})
	var wall_m := PSXMat.lit("stone_brick", ctx.style["quay_wall"], {"affine": 0.6})
	var cope := PSXMat.lit("stone_brick", ctx.style["quay_cope"])
	var iron := PSXMat.lit("metal", ctx.style["iron"])
	var body := StaticBody3D.new()
	body.name = "Quay"
	body.collision_layer = 1
	body.collision_mask = 0
	var n := wall_s.size()
	var bottom := -4.0
	var shell := MeshBuilder.new()
	var y := quay_y
	var v := func(q: Vector2, yy: float) -> Vector3: return fv(q.x, yy, q.y)
	# (every point's inland offset is the same, so neighbouring strips share edges)
	var mid_off := Vector2(0, quay_w)
	var in_off := Vector2(0, plat_d)
	for i in range(n - 1):
		var a := Vector2(wall_s[i], wall_t[i])
		var b := Vector2(wall_s[i + 1], wall_t[i + 1])
		var t := (b - a).normalized()
		var sea := Vector2(t.y, -t.x)
		if sea.y > 0.0:
			sea = -sea
		var nrm := fb(Basis()) * Vector3(sea.x, 0, sea.y)
		var a_m := a + mid_off
		var b_m := b + mid_off
		var a_in := a + in_off
		var b_in := b + in_off
		# paving (two strips so the texture warp stays small), the curb at the back
		shell.add_quad(cob, v.call(a, y), v.call(b, y), v.call(b_m, y), v.call(a_m, y), a * 0.4, b * 0.4, b_m * 0.4, a_m * 0.4, Color.WHITE, Vector3.UP)
		shell.add_quad(cob, v.call(a_m, y), v.call(b_m, y), v.call(b_in, y), v.call(a_in, y), a_m * 0.4, b_m * 0.4, b_in * 0.4, a_in * 0.4, Color(0.92, 0.92, 0.92), Vector3.UP)
		shell.add_quad(cope, v.call(a_in, y), v.call(b_in, y), v.call(b_in, y - 0.8), v.call(a_in, y - 0.8), Vector2(a.x, 0) * 0.5, Vector2(b.x, 0) * 0.5, Vector2(b.x, 0.4), Vector2(a.x, 0.4), Color(0.8, 0.8, 0.8), -nrm)
		# the sea wall (wet and dark below the tide line)
		var uva := Vector2(a.x + a.y, 0) * 0.4
		var uvb := Vector2(b.x + b.y, 0) * 0.4
		shell.add_quad(wall_m, v.call(a, y), v.call(b, y), v.call(b, 0.4), v.call(a, 0.4), uva, uvb, uvb + Vector2(0, 0.5), uva + Vector2(0, 0.5), Color.WHITE, nrm)
		shell.add_quad(wall_m, v.call(a, 0.4), v.call(b, 0.4), v.call(b, bottom), v.call(a, bottom), uva + Vector2(0, 0.5), uvb + Vector2(0, 0.5), uvb + Vector2(0, 2.2), uva + Vector2(0, 2.2), Color(0.55, 0.6, 0.55), nrm)
		# coping along the edge
		var mid := (a + b) * 0.5 + sea * 0.12
		mb.add_box(cope, Transform3D(fb(Basis(Vector3.UP, KitContext.face_yaw(t))), v.call(mid, y + 0.06)), Vector3(0.62, 0.18, a.distance_to(b) + 0.04), 0.8, Color(0.85 + rng.randf() * 0.15, 0.85, 0.85), false)
	# the two ends, closed with a wall and a stone pier-head
	for e in [[0, -1.0], [n - 1, 1.0]]:
		var q := Vector2(wall_s[e[0]], wall_t[e[0]])
		var q_in := q + in_off
		var nx := fb(Basis()) * Vector3(float(e[1]), 0, 0)
		shell.add_quad(wall_m, fv(q.x, quay_y, q.y), fv(q_in.x, quay_y, q_in.y), fv(q_in.x, bottom, q_in.y), fv(q.x, bottom, q.y),
			Vector2(q.y, 0) * 0.4, Vector2(q_in.y, 0) * 0.4, Vector2(q_in.y, 2.2) * 0.4, Vector2(q.y, 2.2) * 0.4, Color(0.8, 0.8, 0.8), nx)
		mb.add_box(cope, Transform3D(fb(Basis()), fv(q.x, quay_y + 0.45, q.y + 0.4)), Vector3(1.0, 0.9, 1.0), 0.8, Color.WHITE, true)
	var shell_mesh := shell.commit()
	var shell_i := MeshInstance3D.new()
	shell_i.name = "QuayShell"
	shell_i.mesh = shell_mesh
	shell_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(shell_i)
	var cs := CollisionShape3D.new()
	cs.shape = shell_mesh.create_trimesh_shape()
	body.add_child(cs)
	# bollards and ladders along the edge, clear of the piers
	var x := s0 + 3.0
	var k := 0
	while x < s1 - 2.0:
		var clear := true
		for g in gaps:
			if absf(x - float(g)) < 3.2:
				clear = false
		if clear:
			var q := quay_pt(x, 0.45)
			mb.add_cylinder(iron, Transform3D(Basis(), Vector3(q.x, quay_y + 0.1, q.y)), 0.16, 0.2, 0.42, 7, 1.0)
			mb.add_cylinder(iron, Transform3D(Basis(), Vector3(q.x, quay_y + 0.52, q.y)), 0.24, 0.24, 0.07, 7, 1.0)
			if k % 3 == 1:
				var lp := quay_pt(x + 1.6, 0.0)
				var lad := Ladder.new()
				lad.length = quay_y + 1.2
				lad.deck_depth = 0.9
				ctx.put(lad, Vector3(lp.x, quay_y, lp.y), KitContext.face_yaw(out))
			k += 1
		x += 7.0
	var mesh_i := mb.to_instance("QuayMesh")
	mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_i)
	ctx.add(body)
	for i in range(0, n, 3):
		ctx.reserve(pt(wall_s[i], wall_t[i] + plat_d * 0.5), plat_d * 0.5)


# --------------------------------------------------------------------------
# Side piers with their ships, longboats
# --------------------------------------------------------------------------
## `piers`: [station, length, ship kind (junk, merchant, sloop), ship on the +along side?],
## skipped where the quay doesn't reach.
func build_piers(ctx: KitContext, piers: Array) -> void:
	for pr in piers:
		var px: float = pr[0]
		if px < s0 + 4.0 or px > s1 - 2.0:
			continue
		var root := quay_pt(px, 1.0)
		var pier := Props.dock(float(pr[1]), 3.0, deck_y, floor_y)
		ctx.put(pier, Vector3(root.x, 0.0, root.y), KitContext.face_yaw(out))
		var lad := Ladder.new()
		lad.length = deck_y + 1.0
		lad.deck_depth = 0.9
		lad.position = Vector3(0, deck_y, float(pr[1]))
		pier.add_child(lad)
		var side := 1.0 if pr[3] else -1.0
		var sp := root + out * (float(pr[1]) - 10.0) + along * (side * (1.5 + HullBuilder.HALF_BEAM + 0.7))
		# (out along the pier until the whole hull is over open water: where the quay curves, a short pier's ship
		# stood with its side on the paving, 2026-10-22)
		for k in 16:
			if _hull_clear(ctx, sp):
				break
			sp += out
		var hull := MooredHull.new()
		hull.name = "Moored_" + str(pr[2])
		hull.collision_layer = 1
		hull.collision_mask = 0
		ctx.put(hull, Vector3(sp.x, HullBuilder.FREEBOARD, sp.y), KitContext.face_yaw(-out))
		match str(pr[2]):
			"junk":
				TraderShips.junk(hull)
			"merchant":
				TraderShips.merchantman(hull)
			_:
				TraderShips.sloop(hull)
		for k in range(3):
			var rc := Props.rope_coil() if k != 1 else Props.barrel()
			ctx.put(rc, Vector3(0, deck_y, 0) + KitContext.v3(root + out * (6.0 + k * 6.0) + along * (side * 1.0)))


## A moored ship's footprint centred at `c` (its keel along `out`), with a metre round it, all past the quay's edge and
## over water.
func _hull_clear(ctx: KitContext, c: Vector2) -> bool:
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			var p: Vector2 = c + out * (a * (HullBuilder.STERN_Z + 1.0)) + along * (b * (HullBuilder.HALF_BEAM + 1.0))
			if past_quay(p) < 1.0 or ctx.hv(p) > -0.3:
				return false
	return true


## How far `p` lies out to sea past the quay's edge, by its nearest station (m; < 0 on the quay or inland of it).
func past_quay(p: Vector2) -> float:
	var best := INF
	var off := 0.0
	var n := 96
	for i in n + 1:
		var s := lerpf(s0, s1, float(i) / n)
		var q := quay_pt(s, 0.0)
		var d2 := q.distance_squared_to(p)
		if d2 < best:
			best = d2
			off = (p - q).dot((quay_pt(s, -1.0) - q).normalized())
	return off


## Longboats tied along the quay at these stations.
func build_longboats(ctx: KitContext, stations: Array) -> void:
	for lx in stations:
		if lx < s0 + 3.0:
			continue
		var q := quay_pt(lx, -2.4)
		var boat := MooredHull.new()
		boat.name = "Longboat"
		boat.freeboard = 0.15
		boat.half_len = 2.4
		boat.collision_layer = 1
		boat.collision_mask = 0
		ctx.put(boat, Vector3(q.x, 0.15, q.y), KitContext.face_yaw(along + inland * 0.05))
		TraderShips.longboat(boat)


# --------------------------------------------------------------------------
# The waterfront: houses and shops shoulder to shoulder facing the harbour
# --------------------------------------------------------------------------
## Where the houses go (data: [spec, point, face]), reserving as it goes: `rows`
## rows behind the quay's street, keeping the road up from the pier open
## (`road_hw` + half a house either side of it) and away from the quay's end
## (`end_gap`). The style picks walls, roofs and the front row's awnings;
## `seed_base` seeds each house's own look.
func plan_waterfront(ctx: KitContext, rng: RandomNumberGenerator, rows := 2, road_hw := 6.5, end_gap := 9.0, seed_base := 900) -> Array:
	var st := ctx.style
	var walls: Array = st["row_walls"]
	var uppers: Array = st["row_upper"]
	var roofs: Array = st["row_roofs"]
	var awnings: Array = st["row_awnings"]
	var roof_tex: Array = st["row_roof_tex"]
	var front := plat_d + 0.15
	var plan: Array = []
	for row in range(rows):
		var x := s0 + 2.5
		var i := 0
		while x < s1 - 6.0:
			var w := rng.randf_range(4.5, 6.5)
			var d := rng.randf_range(4.5, 5.5)
			var cx := x + w * 0.5
			x += w + rng.randf_range(0.6, 1.4)
			if absf(cx - dock_s) < road_hw + w * 0.5 or cx > s1 - end_gap:
				continue
			var in_m := front + d * 0.5 + 0.4 + row * (d + 4.0)
			var p := quay_pt(cx, in_m)
			if ctx.excluded(p, maxf(w, d) * 0.55) or ctx.path_dist(p) < maxf(w, d) * 0.55:
				continue
			var spec := {"w": w, "d": d, "h": rng.randf_range(2.5, 2.9), "floors": 2 if rng.randf() < 0.7 else 1,
				"wall": walls[(i + row) % walls.size()], "wall2": uppers[rng.randi() % uppers.size()],
				"roof": roofs[rng.randi() % roofs.size()], "roof_tex": roof_tex[0] if rng.randf() < float(roof_tex[1]) else roof_tex[2],
				"pitch": rng.randf_range(0.5, 0.75), "chimney": rng.randf() < 0.6, "jetty": rng.randf_range(0.2, 0.45),
				"seed": seed_base + i + row * 50, "door_x": rng.randf_range(-0.8, 0.8)}
			if row == 0:
				spec["awning"] = awnings[i % awnings.size()]
			plan.append([spec, p, out])
			ctx.reserve(p, maxf(w, d) * 0.6 + 1.5)
			i += 1
	return plan


func build_waterfront(ctx: KitContext, plan: Array) -> Array:
	var out_n: Array = []
	for e in plan:
		out_n.append(ctx.house(e[0], e[1], e[2], false, false))
	return out_n


# --------------------------------------------------------------------------
# The quay's dressing
# --------------------------------------------------------------------------
## Cargo groups (crates, barrels and nets, a handcart) at `cargo` stations, lamps
## at `lamps`, stalls at `stalls` ([kind, station]); clear of what's there.
## Data: a plan_place list for KitContext.build_list.
func plan_dressing(ctx: KitContext, rng: RandomNumberGenerator, cargo: Array, lamps: Array, stalls: Array) -> Array:
	var plan: Array = []
	for sx in cargo:
		if sx < s0 + 3.0 or sx > s1 - 3.0:
			continue
		var q := quay_pt(sx, 6.5)
		if ctx.excluded(q, 1.0):
			continue
		match int(absf(sx - dock_s)) % 3:
			0:
				ctx.plan_place(plan, Props.crate.bind(0.9), q, rng.randf() * TAU, 0.8)
				ctx.plan_place(plan, Props.crate.bind(0.7), off(q, 1.0, 0.3), rng.randf() * TAU, 0.6)
				ctx.plan_place(plan, Props.crate.bind(0.6), q, rng.randf() * TAU, 0.0, 0.9)
			1:
				ctx.plan_place(plan, Props.barrel, q, yaw + 0.0, 0.5)
				ctx.plan_place(plan, Props.barrel, off(q, 0.8, 0.2), yaw + 0.0, 0.5)
				ctx.plan_place(plan, Props.net_pile, off(q, -1.2, 0.5), rng.randf() * TAU)
			_:
				ctx.plan_place(plan, KitVillage.handcart, q, KitContext.face_yaw(along * rng.randf_range(-1, 1) + inland), 1.2)
	for lx in lamps:
		if lx < s0 + 2.0 or lx > s1 - 2.0:
			continue
		var lq := quay_pt(lx, quay_w - 0.8)
		if ctx.excluded(lq, 0.5):
			continue
		ctx.plan_place(plan, Props.lantern_post, lq, KitContext.face_yaw(out) - PI * 0.5, 0.4, 0.0,
			func(n: Node3D): KitLights.light(ctx, n, Vector3(0.55, 2.0, 0.0), 1.6))
	for stl in stalls:
		var sp := quay_pt(float(stl[1]), quay_w - 2.0)
		if not ctx.excluded(sp, 1.5):
			ctx.plan_place(plan, Buildings.stall.bind(stl[0]), sp, KitContext.face_yaw(out), 1.8)
	return plan


# --------------------------------------------------------------------------
# The harbour front: where the harbour's people work, round the pier's root
# --------------------------------------------------------------------------
## The harbourmaster's booth beside the pier, the shipwright's yard (a boat on
## the stocks, timber, sawhorses, his bench) to one side, the net-mender's
## corner (bench, nets, an upturned boat, a fish rack, his net loft, floats) to
## the other. `mirror` -1 swaps the sides. Returns where the people stand:
## {"keeper", "keeper_face", "shipwright", "mender"} (island space).
func build_front(ctx: KitContext, rng: RandomNumberGenerator, mirror := 1.0) -> Dictionary:
	var r := dock
	var at := func(s: float, t: float) -> Vector2: return off(r, s * mirror, t)
	var to_pier := along * mirror
	var booth := ctx.place(booth_model(), at.call(-5.2, 4.0), KitContext.face_yaw(to_pier), 1.6)
	var who := {"keeper": ctx.marker_point(booth, "Keeper"), "keeper_face": to_pier}
	ctx.place(Props.crate(0.7), at.call(-5.0, 6.4), yaw + 0.4, 0.6)
	ctx.place(Props.barrel(), at.call(-6.2, 6.6), yaw + 0.0, 0.5)
	# the shipwright's yard
	ctx.place(boat_on_stocks(), at.call(11.0, 7.5), KitContext.face_yaw(to_pier), 4.6)
	var tmb := MeshBuilder.new()
	var timber := PSXMat.lit("planks", Color(0.95, 0.85, 0.7))
	var bark := PSXMat.lit("bark")
	for sx in [-1.2, 1.2]:
		tmb.add_box(bark, Transform3D(Basis(), Vector3(sx, 0.35, 0)), Vector3(0.15, 0.7, 1.0), 1.0)
	for i in range(5):
		tmb.add_box(timber, Transform3D(Basis(Vector3.UP, 0.04 * i), Vector3(0, 0.76 + i * 0.1, -0.3 + (i % 3) * 0.18)), Vector3(3.4, 0.09, 0.26), 1.0)
	ctx.place(tmb.to_instance("Timber"), at.call(12.0, 12.6), yaw + 0.0, 1.9)
	var saw := MeshBuilder.new()
	for sx in [-0.8, 0.8]:
		for sz in [-1.0, 1.0]:
			Buildings.beam_between(saw, bark, Vector3(sx, 0.0, sz * 0.3), Vector3(sx, 0.7, 0.0), 0.07)
		saw.add_box(bark, Transform3D(Basis(), Vector3(sx, 0.72, 0)), Vector3(0.12, 0.1, 0.8), 1.0)
	saw.add_box(timber, Transform3D(Basis(Vector3.UP, 0.1), Vector3(0, 0.82, 0)), Vector3(2.6, 0.07, 0.3), 1.0, Color.WHITE, false)
	ctx.place(saw.to_instance("Sawhorses"), at.call(6.8, 11.4), yaw + 0.2, 1.4)
	ctx.place(workbench(), at.call(17.4, 6.5), KitContext.face_yaw(-to_pier), 1.2)
	who["shipwright"] = at.call(5.6, 5.0)
	# the net-mender's corner
	var mender: Vector2 = at.call(-12.5, 1.8)
	who["mender"] = mender
	ctx.place(Props.bench(), mender, yaw + 0.0, 1.0)
	ctx.place(Props.net_pile(), off(mender, 1.6 * mirror, 0.6), yaw + 0.0)
	ctx.place(Props.net_pile(), off(mender, -1.4 * mirror, 1.0), yaw + 1.1)
	ctx.place(Props.upturned_boat(), at.call(-17.0, 6.0), yaw + 0.3, 2.0)
	ctx.place(Props.fish_rack(), at.call(-9.5, 7.0), KitContext.face_yaw(to_pier), 1.5)
	ctx.house({"w": 5.0, "d": 4.0, "h": 2.4, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch", "porch": 1.4,
		"flowers": false, "name": "NetLoft"}, at.call(-23.0, 10.5), out)
	for k in range(5):
		var fp: Vector2 = at.call(-20.5 + k * 0.5, 7.9)
		var mb := MeshBuilder.new()
		mb.add_blob(PSXMat.flat(Color(0.9, 0.55, 0.2) if k % 2 == 0 else Color(0.85, 0.85, 0.8)), Transform3D(), Vector3.ONE * 0.12, rng, 0.1, 2, 5)
		ctx.place(mb.to_instance("Float"), fp, 0.0, 0.0, 0.1)
	return who


## The harbourmaster's booth: a counter under a canvas awning, the harbour ledger
## and a slate of ships in port. Front +Z; "Keeper" stands behind the counter.
static func booth_model() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "HarbourBooth"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.55, 0.35)), Vector3(2.2, 1.1, 0.55), 1.0, Color.WHITE, true)
	mb.add_box(dark, Transform3D(Basis(), Vector3(0, 1.13, 0.38)), Vector3(2.4, 0.07, 0.75), 1.0, Color.WHITE, false)
	for x in [-1.15, 1.15]:
		for z in [-1.0, 0.65]:
			mb.add_box(dark, Transform3D(Basis(), Vector3(x, 1.2, z)), Vector3(0.1, 2.4, 0.1), 1.0)
	var canvas := PSXMat.lit("cloth_blue", Color.WHITE, {"affine": 0.6})
	mb.add_quad(canvas, Vector3(-1.35, 2.55, -1.15), Vector3(1.35, 2.55, -1.15), Vector3(1.35, 2.25, 0.95), Vector3(-1.35, 2.25, 0.95), Vector2.ZERO, Vector2(1.4, 0), Vector2(1.4, 1), Vector2(0, 1), Color.WHITE, Vector3(0, 1, 0.15).normalized())
	mb.add_quad(canvas, Vector3(-1.35, 2.55, -1.15), Vector3(-1.35, 2.25, 0.95), Vector3(1.35, 2.25, 0.95), Vector3(1.35, 2.55, -1.15), Vector2.ZERO, Vector2(0, 1), Vector2(1.4, 1), Vector2(1.4, 0), Color(0.6, 0.6, 0.6), Vector3(0, -1, -0.15).normalized())
	# the ledger, an inkpot, the slate of ships behind
	mb.add_box(PSXMat.lit("leather", Color(0.45, 0.22, 0.15)), Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.3, 1.19, 0.4)), Vector3(0.5, 0.06, 0.36), 1.0)
	mb.add_box(PSXMat.flat(Color(0.9, 0.86, 0.72)), Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.3, 1.225, 0.4)), Vector3(0.44, 0.015, 0.3), 1.0)
	mb.add_cylinder(PSXMat.flat(Color(0.1, 0.1, 0.12)), Transform3D(Basis(), Vector3(0.35, 1.165, 0.45)), 0.06, 0.05, 0.1, 6, 1.0)
	mb.add_box(dark, Transform3D(Basis(), Vector3(0, 1.75, -1.02)), Vector3(1.7, 1.0, 0.06), 1.0)
	mb.add_box(PSXMat.flat(Color(0.14, 0.16, 0.15)), Transform3D(Basis(), Vector3(0, 1.75, -0.98)), Vector3(1.5, 0.85, 0.02), 1.0)
	var chalk := PSXMat.flat(Color(0.88, 0.88, 0.84))
	for k in range(5):
		mb.add_box(chalk, Transform3D(Basis(), Vector3(-0.2 + (k % 2) * 0.1, 2.05 - k * 0.15, -0.965)), Vector3(0.9 - (k % 3) * 0.2, 0.03, 0.01), 1.0)
	Buildings.wall_lantern(mb, Vector3(1.15, 1.9, 0.65), dark)
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.15, 0.8)
	cs.shape = box
	cs.position = Vector3(0, 0.58, 0.35)
	body.add_child(cs)
	var m := Marker3D.new()
	m.name = "Keeper"
	m.position = Vector3(0, 0, -0.4)
	body.add_child(m)
	return body


## A boat being built on the stocks (bow -Z): keel on blocks, stem and
## sternpost, the frames up, the lower strakes planked, shores holding her.
static func boat_on_stocks() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "BoatOnStocks"
	var mb := MeshBuilder.new()
	var oak := PSXMat.lit("planks", Color(0.98, 0.88, 0.72))
	var dark := PSXMat.lit("planks_dark")
	var keel_y := 0.95
	var top_y := 2.35
	var half := 4.2
	var hw := func(z: float) -> float: return 1.35 * sqrt(maxf(1.0 - pow(z / (half + 0.5), 2.0), 0.05))
	var frame := func(z: float, t: float) -> Vector3:
		var w: float = hw.call(z)
		var a := Vector3(-w, top_y, z)
		var c := Vector3(0, keel_y * 2.0 - top_y, z)
		var b := Vector3(w, top_y, z)
		return a * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + b * t * t
	mb.add_box(dark, Transform3D(Basis(), Vector3(0, keel_y - 0.1, 0)), Vector3(0.2, 0.25, half * 2.0 + 0.3), 1.0, Color.WHITE, false)
	mb.add_tube(dark, MeshBuilder.curve_points(Vector3(0, keel_y, -half), Vector3(0, keel_y + 0.4, -half - 0.9), Vector3(0, top_y + 0.35, -half - 0.6), 6), 0.11, -1.0, 5)
	mb.add_tube(dark, PackedVector3Array([Vector3(0, keel_y, half), Vector3(0, top_y + 0.2, half + 0.35)]), 0.11, -1.0, 5)
	var zs: Array = []
	var z := -half + 0.6
	while z < half - 0.4:
		zs.append(z)
		var pts := PackedVector3Array()
		for k in range(9):
			pts.append(frame.call(z, k / 8.0))
		mb.add_tube(oak, pts, 0.06, -1.0, 4)
		z += 0.75
	# the lower strakes are on: planks between the frames either side
	for t in [0.3, 0.36, 0.42, 0.58, 0.64, 0.7]:
		for i in range(zs.size() - 1):
			Buildings.beam_between(mb, oak, frame.call(zs[i], t), frame.call(zs[i + 1], t), 0.04, 0.2)
	# gunwale lath along the frame heads
	for t in [0.0, 1.0]:
		for i in range(zs.size() - 1):
			Buildings.beam_between(mb, oak, frame.call(zs[i], t), frame.call(zs[i + 1], t), 0.07)
	# keel blocks and shores
	for bz in [-3.0, 0.0, 3.0]:
		mb.add_box(dark, Transform3D(Basis(), Vector3(0, (keel_y - 0.22) * 0.5, bz)), Vector3(0.6, keel_y - 0.22, 0.5), 1.0)
	for sz in [-2.0, 1.6]:
		for s in [-1.0, 1.0]:
			Buildings.beam_between(mb, dark, Vector3(s * 2.3, 0.0, sz), Vector3(s * float(hw.call(sz)) * 0.9, 1.75, sz), 0.1)
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, top_y, half * 2.0 + 1.0)
	cs.shape = box
	cs.position = Vector3(0, top_y * 0.5, 0)
	body.add_child(cs)
	return body


## The shipwright's bench: a plank top, a saw and mallet, an iron plane.
static func workbench() -> MeshInstance3D:
	var bench := MeshBuilder.new()
	var timber := PSXMat.lit("planks", Color(0.95, 0.85, 0.7))
	var bark := PSXMat.lit("bark")
	bench.add_box(timber, Transform3D(Basis(), Vector3(0, 0.85, 0)), Vector3(1.8, 0.1, 0.7), 1.0, Color.WHITE, false)
	for sx in [-0.8, 0.8]:
		for sz in [-0.28, 0.28]:
			bench.add_box(bark, Transform3D(Basis(), Vector3(sx, 0.42, sz)), Vector3(0.1, 0.85, 0.1), 1.0)
	var iron := PSXMat.lit("metal", Color(0.4, 0.4, 0.42))
	bench.add_box(iron, Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.4, 0.92, 0.05)), Vector3(0.55, 0.02, 0.14), 1.0)
	bench.add_box(bark, Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.12, 0.93, 0.13)), Vector3(0.14, 0.05, 0.06), 1.0)
	bench.add_box(bark, Transform3D(Basis(Vector3.UP, -0.5), Vector3(0.45, 0.93, -0.1)), Vector3(0.08, 0.05, 0.35), 1.0)
	bench.add_box(iron, Transform3D(Basis(Vector3.UP, -0.5), Vector3(0.52, 0.95, -0.25)), Vector3(0.16, 0.07, 0.07), 1.0)
	return bench.to_instance("Workbench")
