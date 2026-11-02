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
## Where the weight flies in an action: [[u, body-space point], ...] ("H": in the left hand), or ["whirl", u0, u1, radius,
## height, turns] (spun round at full length).
const CHAIN := {
	"sk_3": [[0.0, "H"], [0.3, Vector3(-0.5, 1.6, 0.6)], [0.42, Vector3(0.0, 1.2, -2.5)], [0.5, Vector3(0.0, 1.1, -5.0)],
		[0.62, Vector3(0.1, 1.0, -4.6)], [0.85, Vector3(-0.3, 0.9, -1.2)], [1.0, "H"]],
	"sk_4": ["whirl", 0.2, 0.82, 4.6, 1.3, 1.5],
	"sk_heavy": ["whirl", 0.15, 0.85, 5.2, 0.9, 2.0],
	"sk_dash": [[0.0, "H"], [0.12, Vector3(0.2, 1.5, -3.0)], [0.25, Vector3(0.0, 1.1, -6.0)], [0.5, Vector3(0.0, 1.0, -2.0)], [0.75, "H"]],
	"sk_throw": [[0.0, "H"], [0.25, Vector3(0.0, 1.3, -3.0)], [0.4, Vector3(0.0, 1.1, -7.0)], [0.65, Vector3(0.0, 1.0, -3.5)], [0.9, "H"]],
}
const CHAIN_LINKS := 14
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
		"sk_4", "sk_heavy":
			# the whirl: the weight spun up over the head on the left arm and round at full length, the body turning
			# under it (the heavy: lower, two turns, the sickle cutting in at the end)
			var up := g.merged({"hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.1, -0.2, 0), "head": Vector3(0.05, 0.2, 0),
				"arm_l": Vector3(2.7, 0.0, -0.3), "fore_l": Vector3(0.3, 0, 0), "_lift": Vector3(0, -0.18 if n == "sk_4" else -0.32, 0)}.merged(PoleMoves.WIDE), true)
			var turns := 1.0 if n == "sk_4" else 2.0
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.16, up, "out"], [0.84, up, "linear"], [1.0, g]])
			var k := clampf((u - 0.18) / 0.64, 0.0, 1.0)
			pz["pivot"] = Vector3(0, TAU * turns * k, 0)
			return [pz, "full", Vector3.ZERO]
		"sk_dash":
			# at a sprint (Chain Rush): the weight thrown ahead, you reeled in after it, the sickle cut on arrival
			var throw: Dictionary = pose(h, "sk_3", 0.45)[0]
			var cut: Dictionary = DaggerMoves.pose(h, "dg_slash", 0.42)[0]
			return [h._keys(u, [[0.0, g], [0.12, throw, "out"], [0.42, throw], [0.55, cut, "out"], [0.75, cut], [1.0, g]]), "full", Vector3.ZERO]
	return [g, "full", Vector3.ZERO]


## Where the weight is now for `h` (world), and whether it's out on the chain (not in the hand).
static func weight_at(h) -> Array:
	var act: String = h.current_action()
	var hand: Vector3 = h.hand_l.global_position + Vector3(0, -0.12, 0)
	if not CHAIN.has(act):
		return [hand, false]
	var dur := maxf(float(h._action.get("dur", 1.0)), 0.001)
	var u := clampf(float(h._action.get("t", 0.0)) / dur, 0.0, 1.0)
	var b: Basis = h.global_basis
	var path: Array = CHAIN[act]
	if path[0] is String:
		var u0: float = path[1]
		var u1: float = path[2]
		if u < u0 or u > u1:
			return [hand, false]
		var k := (u - u0) / (u1 - u0)
		var a := TAU * float(path[5]) * k + PI * 0.5
		var r := float(path[3]) * smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.85, 1.0, k)) + 0.4
		return [h.global_position + b * Vector3(cos(a) * r, float(path[4]), -sin(a) * r), true]
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
static func chain(h, _delta: float) -> void:
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
	var to: Vector3 = w[0]
	ball.global_position = to
	var im: ImmediateMesh = line.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _link_mat)
	# (slack when it's in the hand, taut when it's thrown)
	var sag := 0.05 if bool(w[1]) else clampf(0.55 - from.distance_to(to) * 0.4, 0.05, 0.5)
	for i in range(CHAIN_LINKS + 1):
		var k := float(i) / CHAIN_LINKS
		im.surface_add_vertex(from.lerp(to, k) + Vector3.DOWN * sag * 4.0 * k * (1.0 - k))
	im.surface_end()


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
