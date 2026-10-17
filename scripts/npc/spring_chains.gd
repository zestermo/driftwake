class_name SpringChains
extends Node3D
## Physics for hair and cloth. Each chain is a line of points simulated with
## verlet integration (so it keeps momentum when the body moves), pulled by
## gravity, eased back toward its rest shape, and pushed out of capsule
## colliders on the body (thighs, hips, torso, head). Every chain segment
## drives a bone of a Skeleton3D, and the hair/cloth mesh is skinned to those
## bones, so coat tails swing, skirts flare and ponytails bounce.
##
## Lives as a child of an anchor joint (head, hips or torso) with an identity
## transform, so mesh/rest coordinates are in the anchor's local space.

const STEP := 1.0 / 60.0
const MAX_STEPS := 4
## The cape variants test a segment against the legs here too, off to each side (the sheet is wider than its chain).
const PROBES := [Vector3.ZERO, Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0)]

var skel: Skeleton3D
## Skinned geometry is added here by BodyBuilder, then finalize() commits it.
var mb: MeshBuilder
## name -> {node, a, b, r} capsules in the given node's local space.
var colliders: Dictionary = {}
var gravity := Vector3(0, -9.8, 0)
var enabled := true

## The cape lab's variants (BodyBuilder.cape_mode) on a cape's own chains: "a0" today's solver, "a" the
## tuned one (use_tuned); "b", "bg" and "c" hand the chains to `motion` (CapeMotion).
var mode := "a0"
var motion: CapeMotion
var iters := 1
## Mode "a": anchor-local z every point stays behind (the back's plane).
var back_z := -INF

var _chains: Array = []
var _acc := 0.0
var _last_origin := Vector3.INF
var _g_step := Transform3D()
var _g_prev := Transform3D()
var _cw: Dictionary = {}


func _init() -> void:
	name = "SpringChains"
	skel = Skeleton3D.new()
	skel.name = "Skeleton"
	add_child(skel)
	mb = MeshBuilder.new()
	mb.skinned = true


## Add a chain through anchor-local rest points (root first). `stiffness` (0..1)
## pulls each point toward its rest pose every step, `damping` bleeds velocity,
## `collide` lists collider names. Returns a bone index per point (point i ->
## bone of segment min(i, n-1)) for skinning rings with MeshBuilder.add_loft.
func add_chain(points: PackedVector3Array, stiffness: float = 0.12, damping: float = 0.08,
		gravity_scale: float = 1.0, collide: Array = []) -> PackedInt32Array:
	var n := points.size() - 1
	var first := skel.get_bone_count()
	var parent := -1
	for i in range(n):
		var b := skel.add_bone("chain%d_%d" % [_chains.size(), i])
		skel.set_bone_parent(b, parent)
		var origin: Vector3 = points[i] if parent < 0 else points[i] - points[i - 1]
		skel.set_bone_rest(b, Transform3D(Basis(), origin))
		parent = b
	var per_point := PackedInt32Array()
	for i in range(points.size()):
		per_point.append(first + mini(i, n - 1))
	var bones := PackedInt32Array()
	for i in range(n):
		bones.append(first + i)
	_chains.append({"p": points, "bones": bones, "x": [], "px": [],
		"k": stiffness, "d": damping, "g": gravity_scale, "col": collide})
	return per_point


func chain_count() -> int:
	return _chains.size()


func chain(i: int) -> Dictionary:
	return _chains[i]


## Mode "a": heavier damping, a softer rest pull, `iters` constraint passes a step (lengths, then the
## body's capsules against whole segments, then the back plane), drawn between the last two steps.
func use_tuned(back: float, k: float, d: float, passes: int, collide: Array) -> void:
	mode = "a"
	back_z = back
	iters = passes
	for c in _chains:
		c["k"] = k
		c["d"] = d
		c["col"] = collide


## Commit the skinned mesh and bind it to the skeleton.
func finalize() -> void:
	if _chains.is_empty() or mb.is_empty():
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


## Snap every chain back to its rest pose (spawns, teleports, far away).
func reset() -> void:
	_last_origin = Vector3.INF


func simulate(delta: float) -> void:
	if not enabled or _chains.is_empty() or not is_inside_tree():
		return
	if motion != null:
		motion.update(self, delta)
		return
	if mode == "a":
		_simulate_tuned(delta)
		return
	# the body is drawn where physics interpolation puts it between ticks, not
	# where the last tick left it: simulating against the latter shook the
	# chains back and forth relative to the body every frame (a blurry haze on
	# coat tails and hair at high frame rates)
	var g := get_global_transform_interpolated()
	if _last_origin == Vector3.INF or g.origin.distance_to(_last_origin) > 2.5:
		_snap(g)
		_g_step = g
	_last_origin = g.origin
	_acc = minf(_acc + delta, STEP * MAX_STEPS)
	while _acc >= STEP:
		_acc -= STEP
		_step(g)
		_g_step = g
	# posed against the body as of the last step (against "now", a ship's speed snapped them back and forth between steps)
	_write_pose(_g_step)


func _snap(g: Transform3D) -> void:
	for c in _chains:
		var p: PackedVector3Array = c["p"]
		var x: Array = []
		for pt in p:
			x.append(g * pt)
		c["x"] = x
		c["px"] = x.duplicate()


func _world_colliders() -> void:
	_cw.clear()
	for key in colliders.keys():
		var c: Dictionary = colliders[key]
		var node: Node3D = c["node"]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var t := node.get_global_transform_interpolated()
		_cw[key] = [t * (c["a"] as Vector3), t * (c["b"] as Vector3), float(c["r"]) * t.basis.get_scale().x]


func _step(g: Transform3D) -> void:
	_world_colliders()
	var grav := gravity * STEP * STEP
	for c in _chains:
		var p: PackedVector3Array = c["p"]
		var x: Array = c["x"]
		var px: Array = c["px"]
		var k: float = c["k"]
		var keep: float = 1.0 - float(c["d"])
		var gs: float = c["g"]
		var col: Array = c["col"]
		x[0] = g * p[0]
		px[0] = x[0]
		for i in range(1, p.size()):
			var rest_vec := g.basis * (p[i] - p[i - 1])
			var seg := rest_vec.length()
			var prev: Vector3 = x[i - 1]
			var cur: Vector3 = x[i]
			var nx := cur + (cur - (px[i] as Vector3)) * keep + grav * gs
			nx = nx.lerp(prev + rest_vec, k)
			for name_ in col:
				if _cw.has(name_):
					nx = _push_out(nx, _cw[name_])
			var d := nx - prev
			if d.length_squared() > 1e-10:
				nx = prev + d.normalized() * seg
			px[i] = cur
			x[i] = nx


static func _push_out(pt: Vector3, cap: Array) -> Vector3:
	var a: Vector3 = cap[0]
	var b: Vector3 = cap[1]
	var r: float = cap[2]
	var ab := b - a
	var t := 0.0
	var l2 := ab.length_squared()
	if l2 > 1e-8:
		t = clampf((pt - a).dot(ab) / l2, 0.0, 1.0)
	var closest := a + ab * t
	var off := pt - closest
	var dist := off.length()
	if dist >= r:
		return pt
	if dist < 1e-5:
		return closest + Vector3(0, 0, r)
	return closest + off / dist * r


func _write_pose(g: Transform3D) -> void:
	var inv := g.affine_inverse()
	for c in _chains:
		var x: Array = c["x"]
		var loc := PackedVector3Array()
		for pt in x:
			loc.append(inv * (pt as Vector3))
		pose_local(c, loc)


## Bones from a chain's points in the anchor's space.
func pose_local(c: Dictionary, loc: PackedVector3Array) -> void:
	var p: PackedVector3Array = c["p"]
	var bones: PackedInt32Array = c["bones"]
	for i in range(bones.size()):
		var a := loc[i]
		var b := loc[i + 1]
		var rest_dir := (p[i + 1] - p[i]).normalized()
		var cur := b - a
		var q := Quaternion.IDENTITY
		if cur.length_squared() > 1e-10:
			cur = cur.normalized()
			if rest_dir.dot(cur) > -0.9999:
				q = Quaternion(rest_dir, cur)
			else:
				q = Quaternion(Vector3.RIGHT, PI)
		skel.set_bone_global_pose(bones[i], Transform3D(Basis(q), a))


# ---- mode "a" ----
func _simulate_tuned(delta: float) -> void:
	var g := get_global_transform_interpolated()
	if _last_origin == Vector3.INF or g.origin.distance_to(_last_origin) > 2.5:
		_snap(g)
		_g_prev = g
		for c in _chains:
			c["lp"] = (c["p"] as PackedVector3Array).duplicate()
			c["lc"] = (c["p"] as PackedVector3Array).duplicate()
	_last_origin = g.origin
	_acc = minf(_acc + delta, STEP * MAX_STEPS)
	while _acc >= STEP:
		_acc -= STEP
		# each step against the anchor where it was at that step's moment in the frame
		var gs := _g_prev.interpolate_with(g, clampf(1.0 - _acc / maxf(delta, 1e-6), 0.0, 1.0))
		_step_tuned(gs)
		var inv := gs.affine_inverse()
		for c in _chains:
			c["lp"] = c["lc"]
			var loc := PackedVector3Array()
			for pt in c["x"]:
				loc.append(inv * (pt as Vector3))
			c["lc"] = loc
	_g_prev = g
	# the shape blended between the last two steps, in the anchor's space: smooth on any refresh rate
	var w := _acc / STEP
	for c in _chains:
		var lp: PackedVector3Array = c["lp"]
		var lc: PackedVector3Array = c["lc"]
		var loc := PackedVector3Array()
		for i in range(lc.size()):
			loc.append(lp[i].lerp(lc[i], w))
		pose_local(c, loc)


func _step_tuned(g: Transform3D) -> void:
	_world_colliders()
	var inv := g.affine_inverse()
	var grav := gravity * STEP * STEP
	for c in _chains:
		var p: PackedVector3Array = c["p"]
		var x: Array = c["x"]
		var px: Array = c["px"]
		var k: float = c["k"]
		var keep: float = 1.0 - float(c["d"])
		var gs: float = c["g"]
		var col: Array = c["col"]
		x[0] = g * p[0]
		px[0] = x[0]
		for i in range(1, p.size()):
			var cur: Vector3 = x[i]
			var nx := cur + (cur - (px[i] as Vector3)) * keep + grav * gs
			px[i] = cur
			x[i] = nx.lerp((x[i - 1] as Vector3) + g.basis * (p[i] - p[i - 1]), k)
		for it in range(iters):
			for i in range(1, p.size()):
				var prev: Vector3 = x[i - 1]
				var seg := (g.basis * (p[i] - p[i - 1])).length()
				var d: Vector3 = (x[i] as Vector3) - prev
				var nx: Vector3 = prev + d.normalized() * seg if d.length_squared() > 1e-10 else x[i]
				for o in PROBES:
					var ow: Vector3 = g.basis * (o as Vector3)
					for name_ in col:
						if _cw.has(name_):
							nx = _push_segment(prev + ow, nx + ow, _cw[name_]) - ow
				var l := inv * nx
				if l.z < back_z:
					l.z = back_z
					nx = g * l
				x[i] = nx


## Moves `b` so the segment a-b clears the capsule (a, the point above, stays).
static func _push_segment(a: Vector3, b: Vector3, cap: Array) -> Vector3:
	var st := _closest_segments(a, b, cap[0], cap[1])
	var on_seg: Vector3 = st[0]
	var off: Vector3 = on_seg - (st[1] as Vector3)
	var dist := off.length()
	var r: float = cap[2]
	if dist >= r:
		return b
	var n := off / dist if dist > 1e-5 else Vector3.BACK
	var t := maxf(float(st[2]), 0.35)
	return b + n * minf((r - dist) / t, r * 2.0)


## Closest points of segments p1-q1 and p2-q2: [on the first, on the second, the first's parameter].
static func _closest_segments(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-10:
		t = clampf(f / e, 0.0, 1.0) if e > 1e-10 else 0.0
	else:
		var c := d1.dot(r)
		if e <= 1e-10:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-10 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return [p1 + d1 * s, p2 + d2 * t, s]
