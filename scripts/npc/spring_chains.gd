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

var skel: Skeleton3D
## Skinned geometry is added here by BodyBuilder, then finalize() commits it.
var mb: MeshBuilder
## name -> {node, a, b, r} capsules in the given node's local space.
var colliders: Dictionary = {}
var gravity := Vector3(0, -9.8, 0)
var enabled := true

var _chains: Array = []
var _acc := 0.0
var _last_origin := Vector3.INF
var _g_step := Transform3D()
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
		var p: PackedVector3Array = c["p"]
		var x: Array = c["x"]
		var bones: PackedInt32Array = c["bones"]
		for i in range(bones.size()):
			var a := inv * (x[i] as Vector3)
			var b := inv * (x[i + 1] as Vector3)
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
