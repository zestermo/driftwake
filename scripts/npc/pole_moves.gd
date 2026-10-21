class_name PoleMoves
## The polearm (stance "polearm"): a spear held in both hands, the right at the rear by the hip and the left
## forward on the shaft. Every pole move ("pole_*", reached from Humanoid._action_pose) keys the body as usual
## and the grip as four extra channels that hands() solves each frame after posing: "_gr" where the right hand
## is, "_gd" which way the shaft points, "_ge" which way the head's edge faces (it leads a sweep), "_gs" (x) how
## far up the shaft the left hand slides (< 0: one hand). All four are in the chest's frame (the torso's basis,
## from the middle of the shoulders: x right, y up, z back), so the chest's turn and lean carry the spear.
## The right arm reaches its hand by IK, the weapon is turned along the shaft, and the left hand takes the
## shaft at its slide, or as far up it as the arm reaches. Same joint conventions as humanoid.gd.

## [right hand, shaft, edge, left hand's slide] (chest frame).
const GUARD_GRIP := [Vector3(0.05, -0.44, -0.3), Vector3(-0.5, 0.36, -0.79), Vector3(0, -1, 0), 0.46]
## Sprinting: the spear trailed low behind in the right hand, the head back, the left arm free.
const TRAIL_GRIP := [Vector3(0.3, -0.5, 0.02), Vector3(0.12, -0.3, 0.95), Vector3(0, -1, 0), -1.0]
## The guard (block, parry): the shaft held level across the front in both hands, the edge out.
const BLOCK_GRIP := [Vector3(0.34, -0.14, -0.4), Vector3(-0.99, 0.12, -0.05), Vector3(0, 0, -1), 0.62]

## The guard: side on, the chest turned right (left shoulder and foot forward), the point at their face.
## The arms only seed the IK.
const GUARD := {"hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.12, -0.3, 0), "head": Vector3(0.1, 0.5, 0),
	"arm_r": Vector3(0.3, 0.2, 0.25), "fore_r": Vector3(1.3, 0, 0), "hand_r": Vector3.ZERO,
	"arm_l": Vector3(1.0, 0.4, -0.1), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3.ZERO}
## The stance's feet (Humanoid.STANCE_LEGS: added to the idle): left foot well forward, knees soft.
const LEGS := {"leg_l": Vector3(0.5, 0, -0.2), "leg_r": Vector3(-0.38, 0, 0.2), "shin_l": Vector3(-0.75, 0, 0), "shin_r": Vector3(-0.45, 0, 0),
	"_lift": Vector3(0, -0.15, 0)}
const BLOCK := {"hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.1, -0.1, 0), "head": Vector3(0.1, 0.2, 0),
	"arm_r": Vector3(1.0, 0.3, 0.3), "fore_r": Vector3(1.0, 0, 0), "arm_l": Vector3(1.0, -0.3, -0.3), "fore_l": Vector3(1.0, 0, 0)}

## Actions the grip holds through (anything else: the hands do what that action keys, the spear in the right).
const HELD := ["parry", "guard_block", "guard_block_hit", "hit", "stagger", "dash", "roll", "flip", "jump_stand", "jump_run", "jump_sprint",
	"double_jump", "plunge_air", "plunge_land"]
## The actions played one-handed (the left arm keys its own).
const ONE_HAND := ["pole_vault"]
## How hard the grip chases its keys (the guard's softer).
const SHARP := 34.0
const SHARP_IDLE := 16.0

# action-key legs
const SET := {"leg_l": Vector3(0.5, 0, -0.18), "shin_l": Vector3(-0.75, 0, 0), "leg_r": Vector3(-0.4, 0, 0.18), "shin_r": Vector3(-0.45, 0, 0)}
const LUNGE := {"leg_l": Vector3(1.15, 0, -0.16), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.9, 0, 0.16), "shin_r": Vector3(-0.12, 0, 0)}
const DEEP := {"leg_l": Vector3(1.3, 0, -0.16), "shin_l": Vector3(-1.55, 0, 0), "leg_r": Vector3(-1.05, 0, 0.16), "shin_r": Vector3(-0.1, 0, 0)}
const STEP_R := {"leg_l": Vector3(-0.6, 0, -0.16), "shin_l": Vector3(-0.35, 0, 0), "leg_r": Vector3(0.95, 0, 0.16), "shin_r": Vector3(-1.05, 0, 0)}
const WIDE := {"leg_l": Vector3(0.45, 0, -0.4), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(-0.25, 0, 0.4), "shin_r": Vector3(-0.85, 0, 0)}


## A key: body joints plus the grip [right hand, shaft, edge, slide].
static func _k(body: Dictionary, grip: Array) -> Dictionary:
	var out := body.duplicate()
	out["_gr"] = grip[0]
	out["_gd"] = grip[1]
	out["_ge"] = grip[2]
	out["_gs"] = Vector3(float(grip[3]), 0, 0)
	return out


static func _p(parts: Array) -> Dictionary:
	var out := {}
	for d in parts:
		out.merge(d, true)
	return out


## The guard as an action key (every joint and channel, so keys that blend from it are whole).
static func _g() -> Dictionary:
	return _k(_p([GUARD, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.14, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), GUARD_GRIP)


## The strike's whoosh: a key part way into it, stretched along the motion, the head smeared a little.
static func _whip(a: Dictionary, b: Dictionary, k: float, sc: Vector3, smear: float = 0.12) -> Dictionary:
	var out := {}
	for j in b.keys():
		out[j] = (a.get(j, b[j]) as Vector3).lerp(b[j], k)
	out["_scale"] = sc
	out["_smear"] = Vector3(smear, 0, 0)
	return out


## [pose, mask, lift] for a pole move (the grip taken off into the body's pole_grip).
static func pose(h, n: String, u: float) -> Array:
	var res := _pose(h, n, u)
	var p: Dictionary = res[0]
	h.pole_grip = [p["_gr"], p["_gd"], p["_ge"], (p["_gs"] as Vector3).x]
	h.pole_set = true
	for c in ["_gr", "_gd", "_ge", "_gs"]:
		p.erase(c)
	return res


static func _pose(h, n: String, u: float) -> Array:
	var g := _g()
	match n:
		"pole_stance":
			return [g, "full", Vector3.ZERO]
		# --- the combo ---
		"pole_thrust":
			# hit 1: drawn back by the hip, coiled right, then driven straight out through a lunge, the left hand
			# letting the shaft slide through it to full reach
			var wind := _k({"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, -0.45, 0), "torso": Vector3(-0.02, -0.45, 0.03), "head": Vector3(0.0, 0.8, 0),
				"leg_l": Vector3(0.45, 0, -0.18), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(-0.3, 0, 0.18), "shin_r": Vector3(-0.7, 0, 0),
				"_lift": Vector3(0, -0.18, 0), "_scale": Vector3(1.03, 0.95, 0.97), "_smear": Vector3.ZERO},
				[Vector3(0.14, -0.38, 0.04), Vector3(-0.55, 0.26, -0.8), Vector3(0, -1, 0), 0.52])
			var strike := _k({"pivot": Vector3(-0.14, 0, 0), "hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.28, -0.25, 0), "head": Vector3(0.3, 0.3, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(-0.04, -0.27, -0.56), Vector3(-0.33, 0.42, -0.88), Vector3(0, -1, 0), 0.2])
			var whoosh := _whip(wind, strike, 0.6, Vector3(0.96, 1.0, 1.1))
			return [h._keys(u, [[0.0, g], [0.28, wind, "out"], [0.34, wind], [0.4, whoosh, "in"], [0.46, strike, "out"], [0.66, strike], [1.0, g]]), "full", Vector3.ZERO]
		"pole_rise":
			# hit 2: the head dropped low to the left, then swept up across the front to high right, stepping
			# through on the right foot (the edge leading up)
			var low := _k({"pivot": Vector3(-0.05, 0, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.25, 0.25, 0.05), "head": Vector3(0.2, -0.4, 0),
				"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.04, 0.94, 1.0), "_smear": Vector3.ZERO}.merged(SET),
				[Vector3(0.1, -0.36, -0.22), Vector3(-0.62, -0.22, -0.75), Vector3(0.66, 0.75, 0), 0.42])
			var cut := _k({"pivot": Vector3(-0.04, 0, 0), "hips": Vector3(0, -0.25, 0), "torso": Vector3(0.06, -0.3, -0.05), "head": Vector3(-0.08, 0.5, 0),
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}.merged(STEP_R),
				[Vector3(0.14, -0.22, -0.36), Vector3(0.45, 0.6, -0.66), Vector3(0.55, 0.75, 0.35), 0.38])
			var follow := cut.merged({"hips": Vector3(0, -0.3, 0), "torso": Vector3(0.08, -0.42, -0.06), "head": Vector3(-0.1, 0.6, 0),
				"_gd": Vector3(0.55, 0.7, -0.45)}, true)
			var whoosh := _whip(low, cut, 0.55, Vector3(0.96, 1.06, 1.02))
			return [h._keys(u, [[0.0, g], [0.26, low, "out"], [0.32, low], [0.4, whoosh, "in"], [0.47, cut, "out"], [0.6, follow, "out"], [0.74, follow], [1.0, g]]), "full", Vector3.ZERO]
		"pole_sweep":
			# hit 3: wound far round to the right, the head out behind that shoulder, then one flat sweep through
			# the front at the waist and on round to the left, in a wide low stance
			var wind := _k({"pivot": Vector3(0.0, 0, 0), "hips": Vector3(0, -0.55, 0), "torso": Vector3(-0.08, -0.5, 0.0), "head": Vector3(0.1, 0.9, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.04, 0.94, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.16, -0.32, -0.24), Vector3(0.38, 0.06, -0.92), Vector3(-0.93, 0, -0.35), 0.42])
			var cut := _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.2, 0.4, 0.0), "head": Vector3(0.15, -0.65, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.04, -0.3, -0.36), Vector3(-0.22, 0.14, -0.97), Vector3(-0.97, 0, 0.22), 0.42])
			var follow := cut.merged({"hips": Vector3(0, 0.55, 0), "torso": Vector3(-0.22, 0.6, 0.0), "head": Vector3(0.15, -0.95, 0)}, true)
			var whoosh := _whip(wind, cut, 0.5, Vector3(1.06, 0.98, 1.0))
			return [h._keys(u, [[0.0, g], [0.26, wind, "out"], [0.32, wind], [0.42, whoosh, "in"], [0.5, cut, "linear"], [0.62, follow, "out"], [0.76, follow], [1.0, g]]), "full", Vector3.ZERO]
		"pole_wheel":
			# hit 4 (Wheel Sweep): the spear laid out to the left at the waist and the whole body turned round
			# once to the left behind it, low and wide, clearing everyone about you
			var load := _k({"hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.2, -0.35, 0), "head": Vector3(0.12, 0.45, 0),
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(1.05, 0.93, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.0, -0.3, -0.3), Vector3(-0.85, 0.12, -0.5), Vector3(-0.5, 0, 0.85), 0.4])
			var turn := load.merged({"hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.25, 0.1, 0), "head": Vector3(0.15, 0.0, 0),
				"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.06, 0.97, 1.0), "_smear": Vector3(0.1, 0, 0)}, true)
			var land := load.merged({"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.22, 0.3, 0), "head": Vector3(0.12, -0.5, 0), "_scale": Vector3.ONE,
				"_smear": Vector3.ZERO, "_gd": Vector3(-0.6, 0.1, -0.79)}, true)
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.18, load, "out"], [0.24, load], [0.3, turn, "in"], [0.62, turn, "linear"], [0.72, land, "out"], [0.84, land], [1.0, g]])
			var k := clampf((u - 0.24) / 0.46, 0.0, 1.0)
			pz["pivot"] = Vector3(-0.08 * sin(k * PI), TAU * k, 0)
			return [pz, "full", Vector3.ZERO]
		# --- the heavy ---
		"pole_heavy":
			# Skewer: sunk deep and coiled far round with the point held level at them, a beat, then a lunge
			# that drives the whole shaft through the line and out the other side
			var coil := _k({"pivot": Vector3(0.08, 0, 0), "hips": Vector3(0, -0.6, 0), "torso": Vector3(0.0, -0.55, 0.04), "head": Vector3(-0.02, 1.05, 0),
				"leg_l": Vector3(0.55, 0, -0.2), "shin_l": Vector3(-1.05, 0, 0), "leg_r": Vector3(-0.2, 0, 0.2), "shin_r": Vector3(-1.0, 0, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.92, 0.96), "_smear": Vector3.ZERO},
				[Vector3(0.2, -0.36, 0.14), Vector3(-0.66, 0.2, -0.72), Vector3(0, -1, 0), 0.55])
			var drive := _k({"pivot": Vector3(-0.2, 0, 0), "hips": Vector3(0, -0.05, 0), "torso": Vector3(-0.32, -0.15, 0), "head": Vector3(0.38, 0.2, 0),
				"_lift": Vector3(0, -0.42, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}.merged(DEEP),
				[Vector3(-0.08, -0.26, -0.6), Vector3(-0.22, 0.48, -0.85), Vector3(0, -1, 0), 0.16])
			var whoosh := _whip(coil, drive, 0.6, Vector3(0.95, 1.0, 1.14), 0.18)
			var tremble := coil.merged({"_gr": (coil["_gr"] as Vector3) + Vector3(0, 0.006 * sin(h._t * 70.0), 0)}, true)
			return [h._keys(u, [[0.0, g], [0.22, coil, "out"], [0.4, tremble], [0.45, whoosh, "in"], [0.52, drive, "out"], [0.78, drive], [1.0, g]]), "full", Vector3.ZERO]
		# --- the guard ---
		"pole_block":
			return [_k(_p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.16, 0)}]), BLOCK_GRIP), "full", Vector3.ZERO]
		"pole_parry":
			# the shaft snapped level across the front, both hands on it, held, then back
			var blk := _k(_p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.18, 0), "_scale": Vector3(1.02, 0.97, 1.0), "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			return [h._keys(u, [[0.0, g], [0.12, blk, "out"], [0.6, blk], [1.0, g]]), "full", Vector3.ZERO]
		"pole_deflect":
			# the blow caught on the shaft and turned aside: the head wheeled over to the left, the butt shoving
			# them off, a step back
			var blk := _k(_p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.18, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			var shove := _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.15, 0.35, 0), "head": Vector3(0.1, -0.45, 0),
				"leg_l": Vector3(0.2, 0, -0.18), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.6, 0, 0.18), "shin_r": Vector3(-0.35, 0, 0),
				"_lift": Vector3(0, -0.16, 0), "_scale": Vector3(0.98, 1.0, 1.05), "_smear": Vector3.ZERO},
				[Vector3(0.2, -0.2, -0.5), Vector3(-0.75, 0.55, -0.37), Vector3(-0.3, 0.3, -0.9), 0.5])
			return [h._keys(u, [[0.0, blk], [0.3, shove, "out"], [0.6, shove], [1.0, g]]), "full", Vector3.ZERO]
	push_error("PoleMoves: no pose for \"%s\"" % n)
	return [g, "full", Vector3.ZERO]


# --------------------------------------------------------------------------
# The grip, solved each frame
# --------------------------------------------------------------------------
static func hands(h, delta: float) -> void:
	var act: String = h.current_action()
	var on: bool = h.stance == "polearm" and h.ragdoll == null and h.armed and h.weapon_in_hand and h.weapon != null \
		and is_instance_valid(h.weapon) and h.weapon.get_parent() == h.hand_r and Humanoid.kind_of(h.weapon) == "polearm" \
		and (act == "" or act.begins_with("pole_") or act in HELD)
	var want: Array = GUARD_GRIP
	if h.pole_set:
		want = h.pole_grip
	elif act in ["guard_block", "guard_block_hit"]:
		want = BLOCK_GRIP
	elif h.sprinting and act == "":
		want = TRAIL_GRIP
	h.pole_set = false
	h.pole_w = move_toward(h.pole_w, 1.0 if on else 0.0, delta / 0.12)
	if h.pole_cur.is_empty():
		h.pole_cur = want.duplicate()
	if on:
		var k := 1.0 - exp(-(SHARP if act != "" else SHARP_IDLE) * delta)
		var cur: Array = h.pole_cur
		cur[0] = (cur[0] as Vector3).lerp(want[0], k)
		cur[1] = (cur[1] as Vector3).lerp(want[1], k).normalized()
		cur[2] = (cur[2] as Vector3).lerp(want[2], k)
		cur[3] = lerpf(float(cur[3]), float(want[3]), k) if float(want[3]) > 0.0 and float(cur[3]) > 0.0 else float(want[3])
	var w: float = h.pole_w
	if h.weapon == null or not is_instance_valid(h.weapon) or h.weapon.get_parent() != h.hand_r:
		return
	if w <= 0.0:
		h.weapon.quaternion = Quaternion.IDENTITY
		return
	var sc: float = h.global_basis.get_scale().x
	var body: Basis = h.global_basis.orthonormalized()
	var b: Basis = h.torso.global_basis.orthonormalized()
	var o: Vector3 = (h.arm_r.global_position + h.arm_l.global_position) * 0.5
	var g: Array = h.pole_cur
	if not (act in ONE_HAND):
		h.reach_hand(true, h.hand_r.global_position.lerp(o + b * ((g[0] as Vector3) * sc), w), body * Vector3(0.7, -1.0, 0.45))
		h.arm_r.basis = h.arm_r.basis.orthonormalized()
	var d: Vector3 = (b * (g[1] as Vector3)).normalized()
	var e: Vector3 = b * (g[2] as Vector3)
	e -= d * e.dot(d)
	if e.length() < 0.05:
		e = body * Vector3.DOWN
		e -= d * e.dot(d)
	e = e.normalized()
	var y := -e
	var z := -d
	var want_b := Basis(y.cross(z).normalized(), y, z)
	var local: Basis = h.hand_r.global_basis.orthonormalized().inverse() * want_b
	h.weapon.quaternion = Quaternion.IDENTITY.slerp(Quaternion(local.orthonormalized()), w)
	var s := float(g[3])
	if s > 0.0 and not (act in ONE_HAND):
		var a: Vector3 = h.hand_r.global_position
		var grip := a + d * _slide(h, a, d, s * sc)
		h.reach_hand(false, h.hand_l.global_position.lerp(grip, w), body * Vector3(-0.7, -1.0, 0.45))
		h.arm_l.basis = h.arm_l.basis.orthonormalized()


## How far up the shaft (from the right hand `a`, along `d`) the left hand takes it: `s`, or as far as the left
## arm reaches if that's short of it (never under 0.18 m: the hands don't meet).
static func _slide(h, a: Vector3, d: Vector3, s: float) -> float:
	var sc: float = h.global_basis.get_scale().x
	var reach: float = (h.fore_l.position.length() + (h.hand_l.position + Vector3(0, -0.05, 0)).length()) * sc * 0.97
	var to: Vector3 = a - h.arm_l.global_position
	if (to + d * s).length() <= reach:
		return s
	var bb := d.dot(to)
	var disc := bb * bb - (to.length_squared() - reach * reach)
	if disc < 0.0:
		return maxf(-bb, 0.18)
	return clampf(-bb + sqrt(disc), 0.18, s)
