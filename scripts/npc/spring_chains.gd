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
## Mode "a"'s safety net (`net`), on the drawn chains only (the simulation never sees it, so a cape clear of the body
## moves exactly as without it): a segment whose sheet comes within `cushion` of the `net_soft` capsules is swung back,
## softly, so it eases off before it touches and never goes in; none goes into `net_hard`, ends in front of the back's
## plane or swings past `swing`. These are the cape's; use_net gives any other set its own.
const CUSHION := 0.025
const NET_LEGS := ["thigh_l", "thigh_r", "shin_l", "shin_r"]
## The most a drawn segment swings off its rest direction (rad): never up past level, the top one (from the shoulders)
## less; and the most the net turns one back.
const NET_SWING := 1.5
const NET_SWING_TOP := 1.0
const NET_TURN := 0.9
## How fast the net's turn follows its target (rad/s): into a correction, and letting it go.
const NET_IN := 40.0
const NET_OUT := 8.0
## How far in front of the plane the sheet's own probe lines may sit (its wrap toward the edges is shaped that way).
const NET_SHEET := 0.012
const NET_MID := 0.12
## Modes "a0" and "a" step in native code (native/src/chain_solver.cpp, ChainSolver) when its library is loaded and
## built from these sources' API; this file's solver is the fallback and the reference the native one is tested against.
const NATIVE_API := 4
static var native_ok: bool = ClassDB.class_exists("ChainSolver") and ClassDB.class_has_method("ChainSolver", "api") and ClassDB.class_call_static("ChainSolver", "api") == NATIVE_API

var skel: Skeleton3D
## Skinned geometry is added here by BodyBuilder, then finalize() commits it.
var mb: MeshBuilder
## name -> {node, a, b, r} capsules in the given node's local space.
var colliders: Dictionary = {}
var gravity := Vector3(0, -9.8, 0):
	set(v):
		gravity = v
		_nat = null
var enabled := true
var native := native_ok:
	set(v):
		native = v
		_nat = null

## How a set moves: "a0" the plain solver, "a" the tuned one (use_tuned: capes and cloaks) with its safety net, "n" the
## plain solver's steps drawn like "a"'s, through the net (use_net: everything else); "b" and "c" hand the chains to
## `motion` (CapeMotion, the cape lab's).
var mode := "a0"
var net_soft: Array = NET_LEGS
var net_hard: Array = ["hips"]
var cushion := CUSHION
var swing := NET_SWING
var swing_top := NET_SWING_TOP
## Where along a segment the net starts judging it (0 its root: the cape's). Cloth sewn on over a thigh's top and hair
## from the nape start inside their capsules: judged from the root, no turn ever cleared them and nothing below was helped.
var net_from := 0.0
## Whether a segment no turn clears is still turned as far as gets it furthest out (see _net_clear; not the cape's).
var net_best := false
var motion: CapeMotion
var iters := 1
## Mode "a": anchor-local z every point stays behind (the back's plane).
var back_z := -INF:
	set(v):
		back_z = v
		_nat = null
var net := false:
	set(v):
		net = v
		_nat = null

var _chains: Array = []
var _acc := 0.0
var _last_origin := Vector3.INF
var _g_step := Transform3D()
var _g_prev := Transform3D()
var _cw: Dictionary = {}
## Whether the net moved anything on the last frame (capelab reads it).
var _net_acted := false
## The native solver (a ChainSolver, untyped: the class is missing without the library), built on the first simulate
## after the chains or their settings change, and how many colliders it was built with.
var _nat = null
var _nat_cols := 0


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
		"k": stiffness, "d": damping, "g": gravity_scale, "col": collide, "probe": PackedVector3Array([Vector3.ZERO])})
	_nat = null
	return per_point


## The net's probe lines for chain `ci`: offsets from the chain across the sheet it carries (rest space).
func set_probes(ci: int, offsets: PackedVector3Array) -> void:
	_chains[ci]["probe"] = offsets
	_nat = null


## The net keeps chain `ci` on its side (`sign` -1 left, 1 right) of an earlier chain `of` of the same sheet, at least
## half their rest spacing apart across: drawn, a sheet's edge never folds in over its middle (and through the back).
func set_side(ci: int, of: int, sign: float) -> void:
	_chains[ci]["side_of"] = of
	_chains[ci]["side"] = sign
	_nat = null


func _net_side(c: Dictionary, loc: PackedVector3Array, mid: PackedVector3Array) -> PackedVector3Array:
	var p: PackedVector3Array = c["p"]
	var mp: PackedVector3Array = _chains[c["side_of"]]["p"]
	var s: float = c["side"]
	for i in range(1, loc.size()):
		var least := absf(p[i].x - mp[i].x) * 0.5
		if (loc[i].x - mid[i].x) * s < least:
			loc[i].x = mid[i].x + s * least
			_net_acted = true
	return loc


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
	_nat = null


## The cape's motion on any other set (hair, coat tails, skirts, sashes, ties: mode "n"): each chain keeps its own
## stiffness, damping and colliders, but steps against the anchor where it was at that step's moment and is drawn
## blended between the last two steps, through the net with this set's capsules (`soft` eased off by `cush`, `hard`
## only kept out of; the ones the body has), and no segment swings past `most` (`top` the root one) off its rest
## direction. Each chain turns its segments outward about their roots: away from the anchor's axis, where it hangs.
func use_net(soft: Array, hard: Array, cush: float, most: float, top: float) -> void:
	mode = "n"
	net_soft = soft.filter(func(k): return colliders.has(k))
	net_hard = hard.filter(func(k): return colliders.has(k))
	cushion = cush
	swing = most
	swing_top = top
	net_from = 0.5
	net_best = true
	for c in _chains:
		var mid := Vector3.ZERO
		for pt in c["p"]:
			mid += pt
		var out := Vector3(mid.x, 0, mid.z)
		c["axis"] = out.normalized().cross(Vector3.DOWN) if out.length_squared() > 1e-8 else Vector3.RIGHT
	net = true


## The net's slack (mode "n"): cloth is built round the legs inside their capsules' clearance and cushion, and a net
## judging it from there swung every coat tail and skirt panel out into a stiff A on a body standing still. Each segment
## is judged that much closer (as built against the legs at `bind`: collider name -> the collider's node in this anchor's
## space, the body unposed; at most `most`), so the net acts only on a leg come further in than the cloth was cut for.
func use_slack(bind: Dictionary, most: float) -> void:
	var caps: Array = []
	for key in net_soft:
		var cd: Dictionary = colliders[key]
		var t: Transform3D = bind[key]
		var a: Vector3 = t * (cd["a"] as Vector3)
		var b: Vector3 = t * (cd["b"] as Vector3)
		var r: float = float(cd["r"]) * t.basis.get_scale().x
		caps.append([a, b, r, a.min(b) - Vector3.ONE * (r + cushion), a.max(b) + Vector3.ONE * (r + cushion), false])
	for c in _chains:
		var p: PackedVector3Array = c["p"]
		var slack := PackedFloat32Array()
		for j in range(p.size() - 1):
			var g := _net_gap(p[j], p[j + 1] - p[j], (p[j + 1] - p[j]).normalized(), c["probe"], caps, j > 0)
			slack.append(clampf(cushion - g.x, 0.0, most))
		c["slack"] = slack
	_nat = null


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
	if _nat != null:
		_nat.reset()


## A drawn chain's last two steps in the anchor's space (mode "a"; capelab reads them): [previous, latest].
func steps_of(ci: int) -> Array:
	if _nat != null:
		return [_nat.get_lp(ci), _nat.get_lc(ci)]
	return [_chains[ci]["lp"], _chains[ci]["lc"]]


func simulate(delta: float) -> void:
	if not enabled or _chains.is_empty() or not is_inside_tree():
		return
	if motion != null:
		motion.update(self, delta)
		return
	if native:
		if _nat == null or _nat_cols != colliders.size():
			_nat_build()
		_nat.simulate(self, skel, delta)
		_acc = _nat.get_acc()
		_net_acted = _nat.get_net_acted()
		return
	if mode != "a0":
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


func _nat_build() -> void:
	_nat = ClassDB.instantiate("ChainSolver")
	_nat_cols = colliders.size()
	var names: Array = colliders.keys()
	var nodes: Array = []
	var ca := PackedVector3Array()
	var cb := PackedVector3Array()
	var cr := PackedFloat32Array()
	for key in names:
		var cd: Dictionary = colliders[key]
		nodes.append(cd["node"])
		ca.append(cd["a"])
		cb.append(cd["b"])
		cr.append(cd["r"])
	_nat.set_colliders(nodes, ca, cb, cr)
	_nat.set_gravity(gravity)
	for ci in range(_chains.size()):
		var c: Dictionary = _chains[ci]
		var col := PackedInt32Array()
		for key in c["col"]:
			if names.has(key):
				col.append(names.find(key))
		_nat.add_chain(c["p"], c["bones"], c["k"], c["d"], c["g"], col, c["probe"], c.get("side_of", -1), c.get("side", 0.0),
			c.get("axis", Vector3.RIGHT))
		if c.has("slack"):
			_nat.set_slack(ci, c["slack"])
	if mode != "a0":
		var caps := PackedInt32Array()
		var hard := PackedInt32Array()
		for key in net_soft + net_hard:
			caps.append(names.find(key))
			hard.append(1 if key in net_hard else 0)
		_nat.set_drawn(mode == "a", back_z, iters, net, caps, hard, cushion, swing, swing_top, net_from, net_best)


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


# ---- modes "a" and "n" ----
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
		if mode == "a":
			_step_tuned(gs)
		else:
			_step(gs)
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
	var caps := _net_caps(g) if net else []
	_net_acted = false
	var drawn: Array = []
	for c in _chains:
		var lp: PackedVector3Array = c["lp"]
		var lc: PackedVector3Array = c["lc"]
		var loc := PackedVector3Array()
		for i in range(lc.size()):
			loc.append(lp[i].lerp(lc[i], w))
		if net:
			loc = _net_clear(c, loc, caps, delta)
			if c.has("side_of"):
				loc = _net_side(c, loc, drawn[c["side_of"]])
		drawn.append(loc)
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


## The net's capsules in the anchor's space as drawn: [a, b, r, box min, box max, hard] (the box out to the cushion).
func _net_caps(g: Transform3D) -> Array:
	var inv := g.affine_inverse()
	var out: Array = []
	for key in net_soft + net_hard:
		var cd: Dictionary = colliders[key]
		var t := inv * (cd["node"] as Node3D).get_global_transform_interpolated()
		var a: Vector3 = t * (cd["a"] as Vector3)
		var b: Vector3 = t * (cd["b"] as Vector3)
		var r: float = float(cd["r"]) * t.basis.get_scale().x
		var reach := Vector3.ONE * (r + cushion)
		out.append([a, b, r, a.min(b) - reach, a.max(b) + reach, key in net_hard])
	return out


## The drawn chain (anchor space) with every segment that comes within the cushion of a capsule, or ends in front of
## the back's plane, swung back about its root (bisected) just enough; the rest of the chain rides on it. The turn
## follows that target at a limited rate (fast in, slower out), so a target that jumps doesn't pop the hem.
func _net_clear(c: Dictionary, loc: PackedVector3Array, caps: Array, delta: float) -> PackedVector3Array:
	var p: PackedVector3Array = c["p"]
	var probes: PackedVector3Array = c["probe"]
	var turns := PackedFloat32Array()
	if c.has("turn"):
		turns = c["turn"]
	else:
		turns.resize(p.size() - 1)
	var axis_c: Vector3 = c.get("axis", Vector3.RIGHT)
	var slack: PackedFloat32Array = c.get("slack", PackedFloat32Array())
	var a := loc[0]
	for j in range(loc.size() - 1):
		var sh := Vector3(slack[j], 0.0, 0.0) if j < slack.size() else Vector3.ZERO
		var rest := (p[j + 1] - p[j]).normalized()
		var d := loc[j + 1] - loc[j]
		# (the bone is posed at its rest length along the drawn direction: judged so, its end is where the skin is)
		var full := d.normalized() * (p[j + 1] - p[j]).length()
		# (a segment thrown up past level, a landing's top segment over the shoulder, turns its row of the sheet inside out)
		# (and the top one, held across the shoulders, swung far aside carries the sheet's wrapped edge in over the back)
		var most := swing_top if j == 0 else swing
		if full.angle_to(rest) > most:
			var axis := rest.cross(full)
			full = (rest.rotated(axis.normalized(), most) if axis.length_squared() > 1e-10 else rest) * full.length()
			d = full
			_net_acted = true
		var g0 := _net_gap(a, full, rest, probes, caps, j > 0) + sh
		var target := 0.0
		# (a point the step left on the back's plane comes back a hair in front of it)
		if g0.x < cushion or g0.y < 0.0 or g0.z < -0.0001:
			# the legs' gap kept: as it is past the cushion; inside, eased toward them but never reaching them (C1 at its
			# edge); off the hips and the back's plane, only out of them
			var want := Vector3(cushion * exp((g0.x - cushion) / cushion) if g0.x < cushion else g0.x, 0.0, 0.0)
			var hi := NET_TURN
			if not _net_ok(_net_gap(a, full.rotated(axis_c, -hi), rest, probes, caps, j > 0) + sh, want):
				want.x = minf(want.x, 0.0)
			# (no turn about the root clears it, a root already in the cushion: the cape's is left as it is, popping helps
			# no one; `net_best` turns it as far as helps most)
			if _net_ok(_net_gap(a, full.rotated(axis_c, -hi), rest, probes, caps, j > 0) + sh, want):
				var lo := 0.0
				for k in range(8):
					var mid := (lo + hi) * 0.5
					if _net_ok(_net_gap(a, full.rotated(axis_c, -mid), rest, probes, caps, j > 0) + sh, want):
						hi = mid
					else:
						lo = mid
				target = hi
			elif net_best:
				var best := _net_score(g0)
				for k in range(1, 5):
					var tk := NET_TURN * k / 4.0
					var sc := _net_score(_net_gap(a, full.rotated(axis_c, -tk), rest, probes, caps, j > 0) + sh)
					# (by a millimetre or more: near-ties flipping frame to frame shook the hem)
					if sc > best + 0.001:
						best = sc
						target = tk
		var turn := move_toward(turns[j], target, (NET_IN if target > turns[j] else NET_OUT) * delta)
		turns[j] = turn
		if turn > 0.0:
			d = full.rotated(axis_c, -turn)
			_net_acted = true
		# (a segment swung out sideways barely turns about x: its end goes onto the plane, the length kept)
		var need := back_z - a.z
		if a.z + d.z < back_z - 0.0001 and absf(need) < d.length():
			var side := Vector2(d.x, d.y).normalized() * sqrt(d.length_squared() - need * need)
			d = Vector3(side.x, side.y, need)
			_net_acted = true
		loc[j] = a
		a += d
	loc[loc.size() - 1] = a
	c["turn"] = turns
	return loc


static func _net_ok(g: Vector3, want: Vector3) -> bool:
	return g.x >= want.x and g.y >= want.y and g.z >= want.z


## How far out of everything a gap is (the least of the three).
static func _net_score(g: Vector3) -> float:
	return minf(g.x, minf(g.y, g.z))


## How far segment a-(a+d)'s probe lines (turned with it, as the skin is) are from the soft capsules (x: the cape's
## legs) and the hard ones (y: its hips) (INF
## past the cushion's reach), and its end (and the sheet across the middle; its root row too `below_root`, the collar's
## being under the yoke) from the back's plane (z); negative inside.
func _net_gap(a: Vector3, d: Vector3, rest: Vector3, probes: PackedVector3Array, caps: Array, below_root: bool) -> Vector3:
	var x := a + d
	var gap := INF
	var hips := INF
	var plane := x.z - back_z
	var dn := d.normalized()
	var q := Quaternion(rest, dn) if rest.dot(dn) > -0.9999 else Quaternion(Vector3.RIGHT, PI)
	for o in probes:
		var ow := q * o
		var pa := a + d * net_from + ow
		var pb := x + ow
		# (the sheet over the middle of the back may not cross the plane either: an edge wrapped round toward the
		# shoulders, swung in across the back by a turn, went into it)
		if absf(pb.x) <= NET_MID:
			plane = minf(plane, pb.z - back_z + NET_SHEET)
		if below_root and absf(pa.x) <= NET_MID:
			plane = minf(plane, pa.z - back_z + NET_SHEET)
		var lo := pa.min(pb)
		var hi := pa.max(pb)
		for ci in range(caps.size()):
			var cap: Array = caps[ci]
			var cl: Vector3 = cap[3]
			var ch: Vector3 = cap[4]
			if lo.x > ch.x or hi.x < cl.x or lo.y > ch.y or hi.y < cl.y or lo.z > ch.z or hi.z < cl.z:
				continue
			var st := _closest_segments(pa, pb, cap[0], cap[1])
			var gc: float = (st[0] as Vector3).distance_to(st[1]) - float(cap[2])
			if cap[5]:
				hips = minf(hips, gc)
			else:
				gap = minf(gap, gc)
	return Vector3(gap, hips, plane)


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
