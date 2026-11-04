class_name SickleMoves
extends RefCounted
## The chain sickle (1.28, stance "sickle"): a sickle in the right hand and a weighted chain off its pommel, the weight
## held in the left. Close cuts with the sickle (the dagger's keys: BORROW) and long chain blows: the lash (the weight
## thrown straight out along the line), the whirl (spun round you at full length), the reaping heavy. The chain and its
## weight are drawn here every frame (`chain`): from the pommel to the weight, which sits in the left hand unless the
## action's CHAIN path says where it flies (body space, -z ahead). Same conventions as humanoid.gd.

const GUARD := {"hips": Vector3(0, -0.35, 0), "torso": Vector3(-0.2, -0.3, 0), "head": Vector3(0.15, 0.35, 0),
	"arm_r": Vector3(1.0, -0.2, 0.35), "fore_r": Vector3(1.2, 0, 0), "hand_r": Vector3(-0.3, 0, 0),
	"arm_l": Vector3(0.5, 0.2, -0.45), "fore_l": Vector3(0.9, 0, 0), "hand_l": Vector3.ZERO}
const LEGS := {"leg_l": Vector3(0.5, 0, -0.22), "leg_r": Vector3(-0.25, 0, 0.22), "shin_l": Vector3(-0.95, 0, 0), "shin_r": Vector3(-0.7, 0, 0),
	"_lift": Vector3(0, -0.2, 0)}
## The sickle's own close cuts and guard actions: the dagger's.
const BORROW := {"sk_1": "dg_slash", "sk_2": "dg_rise", "sk_parry": "dg_parry", "sk_deflect": "dg_deflect"}
## Where the weight flies in an action: [[u, body-space point], ...] ("H": in the left hand), or ["whirl", u_out, u_full,
## u_reel, u_in, radius, height, twirls]: let out of the hand at u_out and twirled `twirls` extra turns overhead on a short
## chain, paid out to full length from u_full, reeled back in from u_reel, in the hand at u_in; out at length it trails
## the body's turn (the pivot's), on a disc tilted low in front.
const CHAIN := {
	"sk_3": [[0.0, "H"], [0.3, Vector3(-0.5, 1.6, 0.6)], [0.42, Vector3(0.0, 1.2, -2.5)], [0.5, Vector3(0.0, 1.1, -5.0)],
		[0.62, Vector3(0.1, 1.0, -4.6)], [0.85, Vector3(-0.3, 0.9, -1.2)], [1.0, "H"]],
	"sk_4": ["whirl", 0.04, 0.2, 0.74, 0.86, 4.6, 1.2, 1.0],
	"sk_heavy": ["whirl", 0.03, 0.24, 0.7, 0.82, 5.2, 1.0, 2.0],
	"sk_dash": [[0.0, "H"], [0.12, Vector3(0.2, 1.5, -3.0)], [0.25, Vector3(0.0, 1.1, -6.0)], [0.5, Vector3(0.0, 1.0, -2.0)], [0.75, "H"]],
	"sk_throw": [[0.0, "H"], [0.25, Vector3(0.0, 1.3, -3.0)], [0.4, Vector3(0.0, 1.1, -7.0)], [0.65, Vector3(0.0, 1.0, -3.5)], [0.9, "H"]],
}
const CHAIN_LINKS := 14
## The overhead twirl's chain (m), how far the weight trails the arm round a whirl (rad), the disc's tilt (m lower in
## front than behind).
const TWIRL_R := 0.8
const TRAIL := 0.45
const TILT := 0.35
## The weight's give when its path jumps (an action cut short, another begun): a spring, a little under-damped (a whip).
const GIVE_K := 240.0
const GIVE_C := 17.0
## The wide spinning stance under a whirl.
const SPIN_LEGS := {"leg_l": Vector3(0.45, 0, -0.45), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(-0.3, 0, 0.45), "shin_r": Vector3(-0.85, 0, 0)}
## The weight's colour, the chain's.
const IRON := Color(0.32, 0.32, 0.34)

static var _link_mat: StandardMaterial3D
static var _ball: Mesh


static func _g(h) -> Dictionary:
	return (h._guard() as Dictionary).merged(LEGS, false)


static func pose(h, n: String, u: float) -> Array:
	if BORROW.has(n):
		return DaggerMoves.pose(h, BORROW[n], u)
	var g := _g(h)
	match n:
		"sk_stance":
			return [g, "full", Vector3.ZERO]
		"sk_3", "sk_throw":
			# the lash: the left arm drawn back and up, then thrown straight out, the body turning in behind it
			var wind := g.merged({"hips": Vector3(0, -0.6, 0), "torso": Vector3(0.05, -0.6, 0.05), "head": Vector3(0, 0.6, 0),
				"arm_l": Vector3(2.0, 0.3, -0.9), "fore_l": Vector3(1.4, 0, 0), "_lift": Vector3(0, -0.12, 0), "_scale": Vector3(1.03, 0.96, 1.0)}, true)
			var throw := g.merged({"hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.3, 0.5, -0.05), "head": Vector3(0.2, -0.45, 0),
				"arm_l": Vector3(1.45, 0.0, -0.15), "fore_l": Vector3(0.1, 0, 0), "_lift": Vector3(0, -0.24, 0), "_scale": Vector3(0.97, 1.0, 1.06),
				"_smear": Vector3(0.12, 0, 0)}.merged(PoleMoves.LUNGE), true)
			return [h._keys(u, [[0.0, g], [0.26, wind, "out"], [0.32, wind], [0.42, throw, "out"], [0.66, throw], [1.0, g]]), "full", Vector3.ZERO]
		"sk_4":
			# the whirl: the weight spun up over the head on the left arm and round at full length, the body turning under it
			var up := g.merged({"hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.1, -0.2, 0), "head": Vector3(0.05, 0.2, 0),
				"arm_l": Vector3(2.7, 0.0, -0.3), "fore_l": Vector3(0.3, 0, 0), "_lift": Vector3(0, -0.18, 0)}.merged(PoleMoves.WIDE), true)
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.16, up, "out"], [0.84, up, "linear"], [1.0, g]])
			var k := clampf((u - 0.18) / 0.64, 0.0, 1.0)
			pz["pivot"] = Vector3(0, TAU * k, 0)
			return [pz, "full", Vector3.ZERO]
		"sk_heavy":
			return _reap(h, g, u)
		"sk_dash":
			# at a sprint (Chain Rush): the weight thrown ahead, you reeled in after it, the sickle cut on arrival
			var throw: Dictionary = pose(h, "sk_3", 0.45)[0]
			var cut: Dictionary = DaggerMoves.pose(h, "dg_slash", 0.42)[0]
			return [h._keys(u, [[0.0, g], [0.12, throw, "out"], [0.42, throw], [0.55, cut, "out"], [0.75, cut], [1.0, g]]), "full", Vector3.ZERO]
	return [g, "full", Vector3.ZERO]


## The heavy (Reaping Whirl): sunk low and wound right with the weight twirled over the head, then let go into two
## turns at full length, stepping round under the chain, and the last half-turn a low reap with the sickle into a lunge.
static func _reap(h, g: Dictionary, u: float) -> Array:
	var coil := g.merged({"hips": Vector3(0, -0.55, 0), "torso": Vector3(-0.22, -0.5, 0.12), "head": Vector3(0.2, 0.75, -0.05),
		"arm_l": Vector3(2.75, 0.2, -0.35), "fore_l": Vector3(0.55, 0, 0), "hand_l": Vector3(0.3, 0, 0),
		"arm_r": Vector3(-0.35, 0.2, 0.55), "fore_r": Vector3(1.5, 0, 0), "hand_r": Vector3(0.5, 0, 0),
		"leg_l": Vector3(0.75, 0, -0.42), "shin_l": Vector3(-1.35, 0, 0), "leg_r": Vector3(-0.1, 0, 0.45), "shin_r": Vector3(-1.2, 0, 0),
		"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.06, 0.91, 1.0), "_smear": Vector3.ZERO}, true)
	var deep := coil.merged({"hips": Vector3(0, -0.65, 0), "torso": Vector3(-0.28, -0.58, 0.15), "_lift": Vector3(0, -0.4, 0),
		"_scale": Vector3(1.08, 0.89, 1.0)}, true)
	var whirl := g.merged({"hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.15, 0.3, -0.18), "head": Vector3(0.1, 0.45, 0.1),
		"arm_l": Vector3(0.25, 0.0, -1.45), "fore_l": Vector3(0.25, 0, 0), "hand_l": Vector3.ZERO,
		"arm_r": Vector3(0.5, 0.0, 1.2), "fore_r": Vector3(0.7, 0, 0), "hand_r": Vector3(-0.4, 0, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.03, 0.96, 1.0), "_smear": Vector3.ZERO}.merged(SPIN_LEGS), true)
	var burst := whirl.merged({"torso": Vector3(-0.05, 0.5, -0.22), "head": Vector3(0.0, 0.6, 0.1), "_lift": Vector3(0, -0.16, 0),
		"_scale": Vector3(0.94, 1.09, 1.0), "_smear": Vector3(0.1, 0, 0)}, true)
	var reap := g.merged({"hips": Vector3(0, 0.55, 0), "torso": Vector3(-0.45, 0.6, -0.1), "head": Vector3(0.35, -0.5, 0),
		"arm_r": Vector3(1.35, 0.0, -0.35), "fore_r": Vector3(0.5, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
		"arm_l": Vector3(0.6, 0.0, -1.0), "fore_l": Vector3(1.3, 0, 0), "hand_l": Vector3.ZERO,
		"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(0.96, 0.98, 1.1), "_smear": Vector3(0.15, 0, 0)}.merged(PoleMoves.LUNGE), true)
	# (the sickle drawn back up out of the cut as the body lands, so the return to the guard is short)
	var land := reap.merged({"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.35, 0.25, -0.05), "head": Vector3(0.3, -0.4, 0), "_lift": Vector3(0, -0.4, 0),
		"arm_r": Vector3(1.15, 0.0, -0.1), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(-0.4, 0, 0),
		"_scale": Vector3(1.06, 0.92, 1.0), "_smear": Vector3.ZERO}, true)
	var pz: Dictionary = h._keys(u, [[0.0, g], [0.17, coil, "out"], [0.25, deep], [0.33, burst], [0.42, whirl, "out"],
		[0.68, whirl, "linear"], [0.76, reap, "out"], [0.83, land], [1.0, g]])
	var yaw := reap_yaw(u)
	# (two steps a turn round under the chain, a dip and a lean on each)
	var w := smoothstep(0.3, 0.38, u) * (1.0 - smoothstep(0.64, 0.72, u))
	var s := sin(yaw * 2.0) * w
	pz["leg_l"] = (pz["leg_l"] as Vector3) + Vector3(0.45 * maxf(s, 0.0), 0, 0)
	pz["shin_l"] = (pz["shin_l"] as Vector3) + Vector3(-0.7 * maxf(s, 0.0), 0, 0)
	pz["leg_r"] = (pz["leg_r"] as Vector3) + Vector3(0.5 * maxf(-s, 0.0), 0, 0)
	pz["shin_r"] = (pz["shin_r"] as Vector3) + Vector3(-0.7 * maxf(-s, 0.0), 0, 0)
	pz["torso"] = (pz["torso"] as Vector3) + Vector3(0, 0, 0.07 * s)
	pz["_lift"] = (pz["_lift"] as Vector3) + Vector3(0, -0.05 * absf(s), 0)
	pz["pivot"] = Vector3(-0.08 * w, yaw, 0)
	return [pz, "full", Vector3.ZERO]


## The heavy's turn (rad, y+ = turning left): wound back right, then two turns and a little past, settling square.
static func reap_yaw(u: float) -> float:
	const BACK := 0.75
	const PAST := 0.2
	if u < 0.25:
		return -BACK * smoothstep(0.0, 0.25, u)
	if u < 0.8:
		return -BACK + (2.0 * TAU + BACK + PAST) * _trap((u - 0.25) / 0.55, 0.18, 0.28)
	return 2.0 * TAU + PAST * (1.0 - smoothstep(0.8, 1.0, u))


## Where a move with trapezoidal speed is at `k` (0..1): speeding up over `a` of it, steady, slowing over the last `d`.
static func _trap(k: float, a: float, d: float) -> float:
	k = clampf(k, 0.0, 1.0)
	var v := 1.0 / (1.0 - a * 0.5 - d * 0.5)
	if k < a:
		return 0.5 * v * k * k / a
	if k > 1.0 - d:
		return 1.0 - 0.5 * v * (1.0 - k) * (1.0 - k) / d
	return v * (a * 0.5 + k - a)


## Where the weight is now for `h` (world), and whether it's out on the chain (not in the hand).
static func weight_at(h) -> Array:
	var act: String = h.current_action()
	var hand: Vector3 = h.hand_l.global_position + Vector3(0, -0.12, 0)
	if not CHAIN.has(act):
		return [hand, false]
	var u: float = h._sample_u(float(h._action.get("t", 0.0)), h._action["spec"])
	var b: Basis = h.global_basis
	var path: Array = CHAIN[act]
	if path[0] is String:
		var u_out: float = path[1]
		var u_full: float = path[2]
		var u_reel: float = path[3]
		var u_in: float = path[4]
		var big: float = path[5]
		if u <= u_out or u >= u_in:
			return [hand, false]
		var r := TWIRL_R * smoothstep(u_out, u_out + 0.06, u)
		r = lerpf(r, big, 1.0 - pow(1.0 - clampf((u - u_full) / 0.1, 0.0, 1.0), 2.0))
		r *= 1.0 - smoothstep(u_reel, u_in, u)
		var e := clampf((r - TWIRL_R) / (big - TWIRL_R), 0.0, 1.0) if u > u_full else 0.0
		var tw := TAU * float(path[7]) * (1.0 - pow(1.0 - clampf((u - u_out) / (u_full + 0.08 - u_out), 0.0, 1.0), 2.0))
		var d: Vector3 = h.pivot.global_basis * Vector3(-cos(TRAIL), 0, -sin(TRAIL))
		d.y = 0.0
		d = Basis(Vector3.UP, tw) * d.normalized()
		var fwd := -b.z
		fwd.y = 0.0
		var p := hand + d * r
		p.y = lerpf(hand.y + 0.2 * minf(r / TWIRL_R, 1.0), h.global_position.y + float(path[6]) - TILT * d.dot(fwd.normalized()), e)
		return [p, true]
	var i := 0
	while i < path.size() - 2 and u > float(path[i + 1][0]):
		i += 1
	var a0: Array = path[i]
	var a1: Array = path[i + 1]
	var p0: Vector3 = hand if a0[1] is String else h.global_position + b * (a0[1] as Vector3)
	var p1: Vector3 = hand if a1[1] is String else h.global_position + b * (a1[1] as Vector3)
	var t := clampf((u - float(a0[0])) / maxf(float(a1[0]) - float(a0[0]), 0.001), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return [p0.lerp(p1, t), not (a0[1] is String and a1[1] is String)]


## Every frame on a body holding a chain sickle: the chain from the pommel to the weight, the weight.
static func chain(h, delta: float) -> void:
	var on: bool = h.stance == "sickle" and h.armed and h.weapon_in_hand and h.weapon != null and is_instance_valid(h.weapon) \
		and Humanoid.kind_of(h.weapon) == "sickle" and h.ragdoll == null and h.visible
	var parts: Array = h.get_meta("sickle_chain", [])
	if parts.is_empty() or not is_instance_valid(parts[0]):
		if not on:
			return
		parts = _make(h)
		h.set_meta("sickle_chain", parts)
	var line: MeshInstance3D = parts[0]
	var ball: MeshInstance3D = parts[1]
	line.visible = on
	ball.visible = on
	if not on:
		return
	var from: Vector3 = (h.weapon as Node3D).global_transform * Vector3(0, 0, 0.16)
	var w: Array = weight_at(h)
	var to := _give(h, w[0], delta)
	ball.global_position = to
	var im: ImmediateMesh = line.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _link_mat)
	if not bool(w[1]) and to.distance_to(w[0]) < 0.3:
		var sag := clampf(0.55 - from.distance_to(to) * 0.4, 0.05, 0.5)
		for i in range(CHAIN_LINKS + 1):
			var k := float(i) / CHAIN_LINKS
			im.surface_add_vertex(from.lerp(to, k) + Vector3.DOWN * sag * 4.0 * k * (1.0 - k))
	else:
		# out on the line: a slack loop from the pommel to the left hand, then the run to the weight bowed back
		# against its swing (the chain whips after it)
		var hand: Vector3 = h.hand_l.global_position
		for i in range(4):
			var k := float(i) / 4.0
			im.surface_add_vertex(from.lerp(hand, k) + Vector3.DOWN * 0.6 * k * (1.0 - k))
		var run := hand.distance_to(to)
		var vel: Vector3 = h.get_meta("sickle_wv", Vector3.ZERO)
		var bow := -vel * 0.03
		bow = bow.limit_length(run * 0.35) + Vector3.DOWN * minf(run * 0.04, 0.15)
		var mid := hand.lerp(to, 0.5) + bow
		for i in range(CHAIN_LINKS + 1):
			var k := float(i) / CHAIN_LINKS
			im.surface_add_vertex(hand.lerp(mid, k).lerp(mid.lerp(to, k), k))
	im.surface_end()


## The weight shown: on its path, plus whatever's left of a jump in that path (an action begun or cut short) springing
## out. Keeps the weight's speed for the chain's bow.
static func _give(h, target: Vector3, delta: float) -> Vector3:
	var st: Array = h.get_meta("sickle_give", [])
	var key := "%d:%s" % [h._action_id, h.current_action()]
	if st.is_empty():
		st = [target, Vector3.ZERO, Vector3.ZERO, key]
	var shown: Vector3 = st[0]
	var off: Vector3 = st[1]
	var ov: Vector3 = st[2]
	if st[3] != key:
		off = shown - target
		if off.length() > 8.0:
			off = Vector3.ZERO
			ov = Vector3.ZERO
	if delta > 0.0:
		var dt := minf(delta, 0.05)
		ov += (-GIVE_K * off - GIVE_C * ov) * dt
		off += ov * dt
	var now := target + off
	if delta > 0.0:
		h.set_meta("sickle_wv", (now - shown) / delta)
	h.set_meta("sickle_give", [now, off, ov, key])
	return now


static func _make(h) -> Array:
	if _link_mat == null:
		_link_mat = StandardMaterial3D.new()
		_link_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_link_mat.albedo_color = Color(0.55, 0.55, 0.58)
		var mb := MeshBuilder.new()
		mb.add_cylinder(PSXMat.lit("metal", IRON), Transform3D(Basis(), Vector3(0, -0.06, 0)), 0.06, 0.06, 0.12, 6, 2.0, Color.WHITE, true, true)
		mb.add_cone(PSXMat.lit("metal", IRON), Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.03, 0.05, 4)
		_ball = mb.commit()
	var line := MeshInstance3D.new()
	line.name = "SickleChain"
	line.mesh = ImmediateMesh.new()
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.extra_cull_margin = 8.0
	line.top_level = true
	h.add_child(line)
	var ball := MeshInstance3D.new()
	ball.name = "SickleWeight"
	ball.mesh = _ball
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.top_level = true
	h.add_child(ball)
	return [line, ball]
