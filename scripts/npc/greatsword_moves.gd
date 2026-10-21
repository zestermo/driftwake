class_name GreatswordMoves
## The greatsword (stance "greatsword"): a long two-handed blade, the right hand at the pommel end of the grip and
## the left above it toward the guard, resting on the right shoulder in the guard. Every move ("gs_*", reached from
## Humanoid._action_pose) keys the body plus the polearm's four grip channels (PoleMoves: "_gr" the right hand,
## "_gd" the blade's direction, "_ge" which way the edge faces, "_gs" the left hand's slide up the grip, < 0
## one-handed; the chest's frame: x right, y up, z back), solved each frame by PoleMoves.hands.
## The combo flows: each blow's follow-through is the next one's wind-up ("carry" in ActionSpecs: a chained blow
## starts from where the last one ended, Humanoid._begin_action), so the arcs run into each other: off the shoulder
## down to the left (C1), back up to high right (C2), down and flat round to the left (C3), and on round in a full
## turn. Same joint conventions as humanoid.gd.

## [right hand, blade, edge, left hand's slide] (chest frame). At rest: the flat of the blade on the right shoulder,
## the point back and up behind it, both hands up in front of the chest.
const GUARD_GRIP := [Vector3(0.12, -0.2, -0.45), Vector3(0.15, 0.5, 0.85), Vector3(1, 0, 0), 0.2]
## Sprinting: on the shoulder in the right hand alone.
const TRAIL_GRIP := [Vector3(0.16, -0.12, -0.36), Vector3(0.18, 0.42, 0.89), Vector3(1, 0, 0), -1.0]
## The guard (block, parry): the blade stood up in front, point high, the flat turned to them like a shield.
const BLOCK_GRIP := [Vector3(0.06, -0.42, -0.42), Vector3(-0.22, 0.96, 0.12), Vector3(1, 0, 0), 0.18]
const GRIPS := [GUARD_GRIP, BLOCK_GRIP, TRAIL_GRIP]

## The guard: a little side on under the blade's weight, chin down over the left shoulder. The arms seed the IK.
const GUARD := {"hips": Vector3(0, -0.25, 0), "torso": Vector3(-0.08, -0.2, 0.02), "head": Vector3(0.06, 0.3, 0),
	"arm_r": Vector3(1.0, 0.1, 0.3), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3.ZERO,
	"arm_l": Vector3(1.0, 0.5, -0.1), "fore_l": Vector3(1.4, 0, 0), "hand_l": Vector3.ZERO}
## The stance's feet (Humanoid.STANCE_LEGS): left foot forward, knees bent, driven off the back foot.
const LEGS := {"leg_l": Vector3(0.45, 0, -0.25), "leg_r": Vector3(-0.35, 0, 0.25), "shin_l": Vector3(-0.7, 0, 0), "shin_r": Vector3(-0.5, 0, 0),
	"_lift": Vector3(0, -0.15, 0)}
const BLOCK := {"hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.1, -0.08, 0), "head": Vector3(0.12, 0.1, 0),
	"arm_r": Vector3(1.0, 0.2, 0.3), "fore_r": Vector3(1.0, 0, 0), "arm_l": Vector3(1.1, -0.3, -0.3), "fore_l": Vector3(1.2, 0, 0)}

# action-key legs
const SET := {"leg_l": Vector3(0.45, 0, -0.25), "shin_l": Vector3(-0.7, 0, 0), "leg_r": Vector3(-0.35, 0, 0.25), "shin_r": Vector3(-0.5, 0, 0)}
const LUNGE := {"leg_l": Vector3(1.1, 0, -0.24), "shin_l": Vector3(-1.35, 0, 0), "leg_r": Vector3(-0.8, 0, 0.24), "shin_r": Vector3(-0.25, 0, 0)}
const STEP_R := {"leg_l": Vector3(-0.5, 0, -0.26), "shin_l": Vector3(-0.45, 0, 0), "leg_r": Vector3(0.9, 0, 0.26), "shin_r": Vector3(-1.05, 0, 0)}
const WIDE := {"leg_l": Vector3(0.5, 0, -0.48), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.32, 0, 0.48), "shin_r": Vector3(-0.9, 0, 0)}
const SQUAT := {"leg_l": Vector3(0.95, 0, -0.45), "shin_l": Vector3(-1.6, 0, 0), "leg_r": Vector3(0.2, 0, 0.45), "shin_r": Vector3(-1.4, 0, 0)}
const TUCK := {"leg_l": Vector3(1.5, 0, -0.15), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(1.1, 0, 0.15), "shin_r": Vector3(-1.7, 0, 0)}


static func _k(body: Dictionary, grip: Array) -> Dictionary:
	return PoleMoves._k(body, grip)


## The guard as an action key (every joint and channel).
static func _g() -> Dictionary:
	return _k(PoleMoves._p([GUARD, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.15, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), GUARD_GRIP)


static func pose(h, n: String, u: float) -> Array:
	return PoleMoves.take_grip(h, _pose(h, n, u))


# --------------------------------------------------------------------------
# The combo's carries: where each blow's follow-through ends and the next one starts
# --------------------------------------------------------------------------
## C1: off the shoulder and down across, the blade carried on round low past the left hip, the body wound left.
static func _c1() -> Dictionary:
	return _k({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.7, 0), "torso": Vector3(-0.3, 0.75, 0), "head": Vector3(0.22, -0.8, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.04, 0.95, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
		[Vector3(-0.2, -0.45, -0.28), Vector3(-0.8, -0.42, 0.42), Vector3(-0.25, -0.2, 0.95), 0.2])


## C2: swept back up through the front, the blade on up over the right shoulder, the body wound right.
static func _c2() -> Dictionary:
	return _k({"pivot": Vector3(0.04, 0, 0), "hips": Vector3(0, -0.55, 0), "torso": Vector3(0.1, -0.6, 0), "head": Vector3(-0.05, 0.62, 0),
		"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.97, 1.05, 1.0), "_smear": Vector3.ZERO}.merged(STEP_R),
		[Vector3(0.25, 0.05, -0.3), Vector3(0.45, 0.78, 0.43), Vector3(0.25, 0.4, 0.88), 0.2])


## C3: dropped and swept flat through the front, the blade on round out past the left side, the body wound left.
static func _c3() -> Dictionary:
	return _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.85, 0), "torso": Vector3(-0.12, 0.9, 0), "head": Vector3(0.08, -1.05, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.03, 0.97, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
		[Vector3(-0.1, -0.32, -0.38), Vector3(-0.86, -0.05, 0.5), Vector3(-0.5, 0, 0.86), 0.2])


## Raised for the cleave: both hands over the head, the blade hanging back behind it, the back arched.
static func _raised(body: Dictionary) -> Dictionary:
	return _k({"pivot": Vector3(0.1, 0, 0), "hips": Vector3(0, -0.08, 0), "torso": Vector3(0.25, -0.08, 0), "head": Vector3(-0.2, 0.08, 0),
		"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.96, 1.07, 1.0), "_smear": Vector3.ZERO}.merged(body, true),
		[Vector3(0.06, 0.4, -0.08), Vector3(0.05, -0.3, 0.95), Vector3(0, 0.95, 0.3), 0.2])


## The cleave driven down in front: bent deep over it, the point in the ground ahead.
static func _cleaved(body: Dictionary) -> Dictionary:
	return _k({"pivot": Vector3(-0.25, 0, 0), "hips": Vector3(0, 0.05, 0), "torso": Vector3(-0.45, 0.05, 0), "head": Vector3(0.42, -0.05, 0),
		"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.08, 0.9, 1.04), "_smear": Vector3.ZERO}.merged(LUNGE).merged(body, true),
		[Vector3(0.0, -0.3, -0.52), Vector3(0.0, -0.1, -0.99), Vector3(0, -1, 0.1), 0.2])


static func _pose(h, n: String, u: float) -> Array:
	var g := _g()
	match n:
		"gs_stance":
			return [g, "full", Vector3.ZERO]
		# --- the combo ---
		"gs_1":
			# hit 1: the blade lifted off the shoulder by the right ear, then one great diagonal from high right down
			# through the front to low left, the body turning after it, and carried on round past the left hip (C1)
			var wind := _k({"pivot": Vector3(0.06, 0, 0), "hips": Vector3(0, -0.45, 0), "torso": Vector3(0.1, -0.5, 0.04), "head": Vector3(-0.04, 0.55, 0),
				"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.98, 1.04, 1.0), "_smear": Vector3.ZERO}.merged(SET),
				[Vector3(0.25, 0.12, -0.15), Vector3(0.2, 0.75, 0.62), Vector3(-0.3, 0.3, -0.9), 0.2])
			var strike := _k({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.3, 0.4, 0), "head": Vector3(0.25, -0.4, 0),
				"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.05, 0.94, 1.02), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(-0.05, -0.35, -0.48), Vector3(-0.55, -0.32, -0.77), Vector3(-0.6, -0.75, 0.2), 0.2])
			var whoosh := PoleMoves._whip(wind, strike, 0.5, Vector3(0.97, 1.02, 1.08), 0.12)
			return [h._keys(u, [[0.0, g], [0.2, wind, "out"], [0.28, wind], [0.34, whoosh, "in"], [0.4, strike, "out"], [0.56, _c1(), "out"], [0.72, _c1()], [1.0, g]]), "full", Vector3.ZERO]
		"gs_2":
			# hit 2, out of C1: the blade's weight turned at the bottom, then swept back up through the front from low
			# left to high right, stepping through on the right foot, and on up over the right shoulder (C2)
			var c1 := _c1()
			var load := c1.merged({"hips": Vector3(0, 0.8, 0), "torso": Vector3(-0.35, 0.82, 0), "_lift": Vector3(0, -0.34, 0),
				"_gd": Vector3(-0.85, -0.4, 0.34)}, true)
			var strike := _k({"pivot": Vector3(-0.02, 0, 0), "hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.05, -0.25, 0), "head": Vector3(0.05, 0.25, 0),
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(0.96, 1.06, 1.0), "_smear": Vector3.ZERO}.merged(STEP_R),
				[Vector3(0.05, -0.25, -0.5), Vector3(0.3, 0.35, -0.89), Vector3(0.6, 0.75, 0.2), 0.2])
			var whoosh := PoleMoves._whip(load, strike, 0.5, Vector3(0.97, 1.07, 1.02), 0.12)
			return [h._keys(u, [[0.0, c1], [0.14, load, "out"], [0.24, whoosh, "in"], [0.32, strike, "out"], [0.5, _c2(), "out"], [0.68, _c2()], [1.0, g]]), "full", Vector3.ZERO]
		"gs_3":
			# hit 3, out of C2: the blade dropped behind to the right at the waist, then one flat sweep through the front
			# and on round to the left in a wide low stance (it breaks a guard), carried out past the left side (C3)
			var drop := _k({"pivot": Vector3(0.0, 0, 0), "hips": Vector3(0, -0.7, 0), "torso": Vector3(-0.05, -0.75, 0), "head": Vector3(0.1, 0.9, 0),
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(1.05, 0.94, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.3, -0.35, -0.05), Vector3(0.75, -0.05, 0.66), Vector3(0.66, 0, -0.75), 0.2])
			var strike := _k({"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.15, 0.5, 0), "head": Vector3(0.1, -0.6, 0),
				"_lift": Vector3(0, -0.32, 0), "_scale": Vector3(1.02, 0.98, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.0, -0.32, -0.46), Vector3(-0.15, -0.02, -0.99), Vector3(-1, 0, 0.1), 0.2])
			var whoosh := PoleMoves._whip(drop, strike, 0.5, Vector3(1.08, 0.97, 1.0), 0.14)
			return [h._keys(u, [[0.0, _c2()], [0.2, drop, "out"], [0.28, drop], [0.35, whoosh, "in"], [0.41, strike, "linear"], [0.56, _c3(), "out"], [0.74, _c3()], [1.0, g]]), "full", Vector3.ZERO]
		"gs_4":
			# hit 4 (Gale Turn), out of C3: the sweep's momentum let carry the whole body on round once more with the
			# blade out at arm's length, then brought through level in front and up onto the shoulder
			var c3 := _c3()
			var turn := _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.18, 0.15, 0), "head": Vector3(0.1, -0.1, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.97, 1.0), "_smear": Vector3(0.12, 0, 0)}.merged(WIDE),
				[Vector3(-0.05, -0.3, -0.45), Vector3(-0.72, -0.06, -0.69), Vector3(-0.66, 0, 0.75), 0.2])
			var finish := turn.merged({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.6, 0), "torso": Vector3(-0.25, 0.65, 0), "head": Vector3(0.2, -0.75, 0),
				"_lift": Vector3(0, -0.36, 0), "_scale": Vector3(1.06, 0.93, 1.02), "_smear": Vector3.ZERO,
				"_gd": Vector3(-0.92, -0.1, -0.38), "_ge": Vector3(-0.38, 0, 0.92)}, true)
			var pz: Dictionary = h._keys(u, [[0.0, c3], [0.12, turn, "in"], [0.6, turn, "linear"], [0.7, finish, "out"], [0.84, finish], [1.0, g]])
			var k := clampf((u - 0.08) / 0.56, 0.0, 1.0)
			pz["pivot"] = (pz["pivot"] as Vector3) + Vector3(-0.05 * sin(k * PI), TAU * k, 0)
			return [pz, "full", Vector3.ZERO]
		# --- the heavy: held raised while it charges (gs_charge, Humanoid.hold), then the cleave (gs_heavy) ---
		"gs_charge":
			var raise := _raised(SET.merged({"leg_r": Vector3(-0.5, 0, 0.3), "shin_r": Vector3(-0.75, 0, 0)}, true))
			var tremble := raise.merged({"_gr": (raise["_gr"] as Vector3) + Vector3(0.005 * sin(h._t * 61.0), 0.007 * sin(h._t * 83.0), 0)}, true)
			return [h._keys(u, [[0.0, g], [1.0, tremble, "out"]]), "full", Vector3.ZERO]
		"gs_heavy":
			# the cleave: from overhead, straight down through them into the ground ahead, deep in the lunge
			var raise := _raised(SET)
			var hit := _cleaved({})
			var whoosh := PoleMoves._whip(raise, hit, 0.5, Vector3(0.95, 1.05, 1.08), 0.18)
			return [h._keys(u, [[0.0, raise], [0.12, whoosh, "in"], [0.2, hit, "out"], [0.56, hit], [1.0, g]]), "full", Vector3.ZERO]
		# --- moving ---
		"gs_rush":
			# Running Cleave (attacked at a sprint): the blade trailed low behind on the right, then one flat sweep
			# through them driving forward in a long lunge, carried round to the left
			var drag := _k({"pivot": Vector3(-0.22, 0, 0), "hips": Vector3(0, -0.55, 0), "torso": Vector3(-0.3, -0.6, 0), "head": Vector3(0.3, 0.7, 0),
				"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.04, 0.93, 1.03), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.3, -0.42, 0.0), Vector3(0.65, -0.3, 0.7), Vector3(0.6, 0, -0.8), 0.2])
			var strike := _k({"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.3, 0.5, 0), "head": Vector3(0.25, -0.6, 0),
				"_lift": Vector3(0, -0.4, 0), "_scale": Vector3(1.03, 0.95, 1.06), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.0, -0.36, -0.48), Vector3(-0.15, -0.12, -0.98), Vector3(-1, 0, 0.1), 0.2])
			var whoosh := PoleMoves._whip(drag, strike, 0.5, Vector3(1.06, 0.97, 1.04), 0.14)
			return [h._keys(u, [[0.0, g], [0.16, drag, "out"], [0.3, drag], [0.38, whoosh, "in"], [0.44, strike, "linear"], [0.58, _c3(), "out"], [0.74, _c3()], [1.0, g]]), "full", Vector3.ZERO]
		"gs_dive":
			# Falling Cleave: knees tucked with the blade heaved up overhead, held there the whole way down
			var raise := _raised(TUCK)
			var fall := _raised({"torso": Vector3(0.15, 0, 0), "leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.0, 0, 0),
				"leg_r": Vector3(0.2, 0, 0.15), "shin_r": Vector3(-0.8, 0, 0), "_scale": Vector3(0.97, 1.05, 1.0)})
			return [h._keys(u, [[0.0, g], [0.3, raise, "out"], [0.55, raise], [0.75, fall], [1.0, fall]]), "full", Vector3.ZERO]
		"gs_land":
			# Falling Cleave's landing: the blade driven down into the ground on impact, crouched deep over it
			var hit := _cleaved(SQUAT)
			return [h._keys(u, [[0.0, hit], [0.55, hit.merged({"_scale": Vector3.ONE}, true)], [1.0, g]]), "full", Vector3.ZERO]
		# --- the guard: the flat of the blade as a shield ---
		"gs_block":
			return [_k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.2, 0)}]), BLOCK_GRIP), "full", Vector3.ZERO]
		"gs_parry":
			# the blade snapped up in front, its flat to them, braced, then back
			var blk := _k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.02, 0.97, 1.0), "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			return [h._keys(u, [[0.0, g], [0.12, blk, "out"], [0.6, blk], [1.0, g]]), "full", Vector3.ZERO]
		"gs_deflect":
			# the blow taken on the flat, then the blade shoved out into them with a step, turning it aside
			var blk := _k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.22, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			var shove := _k({"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.22, 0.25, 0), "head": Vector3(0.2, -0.25, 0),
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(0.97, 1.0, 1.07), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.0, -0.36, -0.52), Vector3(-0.6, 0.75, -0.28), Vector3(0.5, 0.2, -0.85), 0.18])
			return [h._keys(u, [[0.0, blk], [0.3, shove, "out"], [0.6, shove], [1.0, g]]), "full", Vector3.ZERO]
	push_error("GreatswordMoves: no pose for \"%s\"" % n)
	return [g, "full", Vector3.ZERO]
