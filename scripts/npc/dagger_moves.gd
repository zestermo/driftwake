class_name DaggerMoves
## Key poses for the daggers: one in the right hand (stance "dagger": a knife
## fighter's crouch, the open left hand out front, the blade back by the hip) and
## one in each (stance "dual_dagger": both low and forward, the left one reversed:
## Humanoid.REVERSE_GRIP, its wrist keyed with rev()). Reached from
## WieldMoves.pose for names it doesn't know; same conventions as humanoid.gd (the
## driftwake-animation skill). Moves keyed in seconds read the played length from
## _action["dur"]. Short blades: the strikes are short, close and quick; the body
## does the travelling (steps, turns, lunges), the arm only the last of it.

const GUARD := {"hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.2, 0.28, 0), "head": Vector3(0.12, -0.28, 0),
	"arm_r": Vector3(0.75, -0.1, 0.25), "fore_r": Vector3(1.2, 0, 0), "hand_r": Vector3(-1.45, 0, 0),
	"arm_l": Vector3(1.0, 0.25, -0.2), "fore_l": Vector3(1.3, 0, 0), "hand_l": Vector3.ZERO}
const DUAL_GUARD := {"hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.22, 0.08, 0), "head": Vector3(0.14, -0.08, 0),
	"arm_r": Vector3(0.85, -0.3, 0.25), "fore_r": Vector3(1.35, 0, 0), "hand_r": Vector3(-1.6, 0, 0),
	"arm_l": Vector3(1.0, 0.35, -0.22), "fore_l": Vector3(1.4, 0, 0), "hand_l": Vector3(-0.53, 0, 0)}

const SET := {"leg_l": Vector3(0.35, 0, -0.14), "shin_l": Vector3(-0.65, 0, 0), "leg_r": Vector3(-0.25, 0, 0.14), "shin_r": Vector3(-0.5, 0, 0)}
const STEP_L := {"leg_l": Vector3(0.8, 0, -0.12), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(-0.55, 0, 0.14), "shin_r": Vector3(-0.25, 0, 0)}
const STEP_R := {"leg_l": Vector3(-0.5, 0, -0.12), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(0.9, 0, 0.12), "shin_r": Vector3(-1.0, 0, 0)}
const LOW := {"leg_l": Vector3(0.75, 0, -0.18), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(-0.25, 0, 0.18), "shin_r": Vector3(-0.9, 0, 0)}
const TUCK := {"leg_l": Vector3(1.5, 0, -0.12), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(1.1, 0, 0.12), "shin_r": Vector3(-1.7, 0, 0)}

## The right-hand stab: coiled at the hip, then driven straight out (the arm a little
## above level in the chest's frame: the stab leans the chest forward ~0.35).
const COIL_R := {"arm_r": Vector3(0.3, 0.15, 0.45), "fore_r": Vector3(1.85, 0, 0), "hand_r": Vector3(-1.9, 0, 0)}
const REACH_R := {"arm_r": Vector3(1.78, 0.05, 0.08), "fore_r": Vector3(0.04, 0, 0), "hand_r": Vector3(-1.52, 0, 0)}


## The off hand's dagger is held reversed (Humanoid.REVERSE_GRIP): hand_l x that points
## its blade `theta` rad forward of straight down (in the chest's frame, arm swung
## forward `arm`, elbow bent `fore`). At ~-1.5 the blade lies back along the forearm.
static func rev(arm: float, fore: float, theta: float) -> float:
	return theta + PI * 0.5 - arm - fore


static func _p(parts: Array) -> Dictionary:
	var out := {}
	for d in parts:
		out.merge(d, true)
	return out


## Strike keys: the pose at contact made faster (stretched along the motion, the blade smeared).
static func _whip(p: Dictionary, sc: Vector3, smear: float = 0.6) -> Dictionary:
	return p.merged({"_scale": sc, "_smear": Vector3(smear, 0, 0)}, true)


## [pose, mask, lift] for a dagger move, or the next file's.
static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	var g: Dictionary = h._guard()
	var T: float = float(h._action.get("dur", 1.0))
	match n:
		# --- one dagger: the combo ---
		"dg_stab":
			# hit 1: drawn back by the hip, a beat, then stepped through and driven straight out
			var wind := _p([{"hips": Vector3(0, -0.45, 0), "torso": Vector3(-0.1, -0.35, 0.04), "head": Vector3(0.1, 0.35, 0),
				"arm_l": Vector3(1.1, 0.3, -0.15), "fore_l": Vector3(1.2, 0, 0), "hand_l": Vector3.ZERO,
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(1.03, 0.95, 0.98)}, COIL_R, SET])
			var reach := _p([{"hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.38, 0.35, -0.04), "head": Vector3(0.28, -0.32, 0),
				"arm_l": Vector3(-0.4, 0.1, -0.5), "fore_l": Vector3(0.6, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.26, 0)}, REACH_R, STEP_R])
			return [h._keys(u, [[0.0, g], [0.2, wind, "out"], [0.26, wind], [0.38, _whip(reach, Vector3(0.96, 0.99, 1.08)), "out"],
				[0.46, reach], [0.62, reach], [1.0, g]]), "full", lift]
		"dg_slash":
			# hit 2: the blade swept out to the right, then a flat forehand across the throat to the left
			var wind := _p([{"hips": Vector3(0, -0.5, 0), "torso": Vector3(0.0, -0.8, 0.06), "head": Vector3(0.05, 0.65, 0),
				"arm_r": Vector3(1.15, 0.55, 1.25), "fore_r": Vector3(1.15, 0, 0), "hand_r": Vector3(0.55, 0, 0),
				"arm_l": Vector3(0.9, 0.4, -0.3), "fore_l": Vector3(1.5, 0, 0), "hand_l": Vector3.ZERO,
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(1.03, 0.96, 1.0)}, SET])
			var cut := _p([{"hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.3, 0.65, -0.06), "head": Vector3(0.2, -0.55, 0),
				"arm_r": Vector3(1.25, -0.8, -0.75), "fore_r": Vector3(0.12, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(0.2, 0.1, -0.9), "fore_l": Vector3(0.7, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.2, 0)}, STEP_L])
			return [h._keys(u, [[0.0, g], [0.22, wind, "out"], [0.27, wind], [0.38, _whip(cut, Vector3(1.06, 0.97, 1.02)), "out"],
				[0.46, cut], [0.62, cut], [1.0, g]]), "full", lift]
		"dg_rise":
			# hit 3: dropped low with the blade cocked across the left hip, then ripped up to the high right
			var low := _p([{"hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.4, 0.75, -0.05), "head": Vector3(0.3, -0.6, 0),
				"arm_r": Vector3(0.45, -0.55, -0.7), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3(0.5, 0, 0),
				"arm_l": Vector3(0.8, 0.2, -0.6), "fore_l": Vector3(1.2, 0, 0), "hand_l": Vector3.ZERO,
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(1.04, 0.94, 1.0)}, LOW])
			var rise := _p([{"hips": Vector3(0, -0.4, 0), "torso": Vector3(0.08, -0.65, 0.06), "head": Vector3(-0.08, 0.55, 0),
				"arm_r": Vector3(2.4, 0.45, 0.95), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-1.2, 0, 0),
				"arm_l": Vector3(-0.2, -0.1, -0.8), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.04, 0)}, STEP_R])
			return [h._keys(u, [[0.0, g], [0.22, low, "out"], [0.27, low], [0.38, _whip(rise, Vector3(0.97, 1.07, 1.0)), "out"],
				[0.46, rise], [0.62, rise], [1.0, g]]), "full", lift]
		"dg_gut":
			# hit 4 (Gutting Strike): coiled low, a heel-pivot full turn with the blade
			# tucked, then the off hand seizes them and the blade goes in low
			var coil := _p([{"hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.25, 0.8, 0.05), "head": Vector3(0.15, -0.6, 0),
				"arm_r": Vector3(0.3, 0.4, 0.6), "fore_r": Vector3(1.7, 0, 0), "hand_r": Vector3(-1.6, 0, 0),
				"arm_l": Vector3(1.0, 0.3, -0.4), "fore_l": Vector3(1.4, 0, 0), "hand_l": Vector3.ZERO,
				"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.04, 0.94, 1.02)}, LOW])
			var turn := _p([{"hips": Vector3.ZERO, "torso": Vector3(-0.35, 0.0, 0.05), "head": Vector3(0.2, 0, 0),
				"arm_r": Vector3(0.6, 0.3, 0.6), "fore_r": Vector3(1.5, 0, 0), "hand_r": Vector3(-1.6, 0, 0),
				"arm_l": Vector3(0.8, 0.0, -1.2), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.2, 0)}, SET])
			var stab := _p([{"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.55, 0.3, -0.04), "head": Vector3(0.38, -0.3, 0),
				"arm_r": Vector3(1.85, 0.05, 0.1), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.45, 0, 0),
				"arm_l": Vector3(0.95, 0.4, -0.1), "fore_l": Vector3(0.75, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.36, 0)},
				{"leg_l": Vector3(-0.6, 0, -0.1), "shin_l": Vector3(-0.4, 0, 0), "leg_r": Vector3(1.1, 0, 0.1), "shin_r": Vector3(-1.2, 0, 0)}])
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.12, coil, "out"], [0.16, coil], [0.3, turn, "linear"], [0.44, turn],
				[0.52, _whip(stab, Vector3(0.95, 0.98, 1.1), 0.8), "out"], [0.6, stab], [0.82, stab], [1.0, g]])
			var k := clampf((u - 0.14) / 0.32, 0.0, 1.0)
			pz["pivot"] = Vector3(0, -TAU * (1.0 - pow(1.0 - k, 2.2)), 0)
			return [pz, "full", lift]
		# --- one dagger: the heavy (Shadow Lunge) ---
		"dg_shadow":
			# sunk low and still, then gone (the state blinks you behind them) and the
			# blade driven up into their back, the off hand on their shoulder
			var crouch := _p([{"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.5, 0.2, 0), "head": Vector3(0.4, -0.2, 0),
				"arm_r": Vector3(-0.2, 0.2, 0.45), "fore_r": Vector3(1.3, 0, 0), "hand_r": Vector3(-1.4, 0, 0),
				"arm_l": Vector3(0.6, 0.2, -0.5), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3.ZERO,
				"_lift": Vector3(0, -0.4, 0), "_scale": Vector3(1.05, 0.92, 1.0)}, LOW])
			var drive := _p([{"pivot": Vector3.ZERO, "hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.3, 0.25, 0), "head": Vector3(0.2, -0.25, 0),
				"arm_r": Vector3(1.75, 0.05, 0.1), "fore_r": Vector3(0.2, 0, 0), "hand_r": Vector3(-1.35, 0, 0),
				"arm_l": Vector3(1.3, 0.3, -0.05), "fore_l": Vector3(0.6, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.18, 0)}, STEP_R])
			return [h._keys(u, [[0.0, g], [0.22, crouch, "out"], [0.3, crouch], [0.42, _whip(drive, Vector3(0.96, 1.06, 1.04), 0.7), "out"],
				[0.5, drive], [0.72, drive], [1.0, g]]), "full", lift]
		# --- one dagger: the jump attack (Fang Dive) ---
		"fang_dive":
			# knees tucked, the blade drawn back over the shoulder and the off hand
			# pointing; then pitched over, point first down the dive
			var cock := _p([{"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.15, -0.35, 0), "head": Vector3(0.2, 0.3, 0),
				"arm_r": Vector3(2.3, 0.3, 0.7), "fore_r": Vector3(1.35, 0, 0), "hand_r": Vector3(0.7, 0, 0),
				"arm_l": Vector3(1.4, 0.2, -0.25), "fore_l": Vector3(0.2, 0, 0), "hand_l": Vector3.ZERO, "_scale": Vector3(1.03, 0.95, 1.0)}, TUCK])
			var dive := {"pivot": Vector3(-0.65, 0, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.25, 0.15, 0), "head": Vector3(0.4, -0.15, 0),
				"arm_r": Vector3(1.55, 0.05, 0.1), "fore_r": Vector3(0.02, 0, 0), "hand_r": Vector3(-1.52, 0, 0),
				"arm_l": Vector3(-0.5, 0, -0.7), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(-0.3, 0, -0.1), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(0.4, 0, 0.1), "shin_r": Vector3(-0.6, 0, 0)}
			return [h._keys(u, [[0.0, {}], [0.08 / T, cock, "out"], [0.13 / T, cock], [0.2 / T, _whip(dive, Vector3(0.95, 1.0, 1.1)), "out"],
				[0.28 / T, dive], [1.0, dive]]), "full", lift]
		# --- one dagger: techniques ---
		"dg_cutthroat":
			# arrived crouched behind them: the blade comes up and across their throat (0.14 s)
			var low := _p([{"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, -0.25, 0), "torso": Vector3(-0.45, -0.4, 0.04), "head": Vector3(0.35, 0.35, 0),
				"arm_r": Vector3(0.6, 0.5, 0.9), "fore_r": Vector3(1.3, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"arm_l": Vector3(1.35, 0.35, -0.05), "fore_l": Vector3(0.8, 0, 0), "hand_l": Vector3.ZERO,
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.04, 0.94, 1.0)}, LOW])
			var cut := _p([{"pivot": Vector3.ZERO, "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.25, 0.55, -0.05), "head": Vector3(0.15, -0.45, 0),
				"arm_r": Vector3(1.55, -0.75, -0.6), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(1.4, 0.3, -0.05), "fore_l": Vector3(0.9, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.14, 0)}, STEP_L])
			return [h._keys(u, [[0.0, low], [0.08 / T, low], [0.14 / T, _whip(cut, Vector3(1.06, 0.98, 1.02), 0.7), "out"], [0.2 / T, cut],
				[0.42 / T, cut], [1.0, g]]), "full", lift]
		"dg_fan":
			# the hand dips to the bandolier across the chest, then flings five knives out
			# backhand in a fan (0.26 s)
			var draw := _p([{"hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.15, 0.8, 0.05), "head": Vector3(0.1, -0.7, 0),
				"arm_r": Vector3(1.2, -0.6, -0.95), "fore_r": Vector3(1.6, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"arm_l": Vector3(0.7, 0.3, -0.4), "fore_l": Vector3(1.3, 0, 0), "hand_l": Vector3.ZERO,
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(1.03, 0.95, 1.0)}, SET])
			var fling := _p([{"hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.2, -0.6, -0.05), "head": Vector3(0.1, 0.5, 0),
				"arm_r": Vector3(1.45, 0.3, 1.35), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.2, 0, 0),
				"arm_l": Vector3(0.4, 0.1, -1.0), "fore_l": Vector3(0.6, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.16, 0)}, STEP_R])
			var k_f := 0.26 / T
			return [h._keys(u, [[0.0, g], [k_f - 0.14, draw, "out"], [k_f - 0.05, draw], [k_f, _whip(fling, Vector3(1.07, 0.97, 1.0), 0.6), "out"],
				[k_f + 0.08, fling], [0.75, fling], [1.0, g]]), "full", lift]
		"dg_slip_guard":
			# Slip: sunk low, the open hand out as bait, the blade hidden behind the hip
			var bait := _p([{"hips": Vector3(0, -0.45, 0), "torso": Vector3(-0.3, 0.4, 0.03 * sin(h._t * 7.0)), "head": Vector3(0.2, -0.35, 0),
				"arm_r": Vector3(-0.35, 0.2, 0.4), "fore_r": Vector3(1.2, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(1.2, 0.3, -0.2), "fore_l": Vector3(0.9, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.2, 0)}, LOW])
			return [h._keys(u, [[0.0, {}], [0.15, bait, "out"], [0.85, bait], [1.0, g]]), "full", lift]
		"dg_slip":
			# the blow slipped (you're behind them now): straight into the back, the off hand on their shoulder
			var low := _p([{"hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.45, -0.2, 0), "head": Vector3(0.35, 0.2, 0),
				"arm_l": Vector3(1.2, 0.3, -0.1), "fore_l": Vector3(0.7, 0, 0), "hand_l": Vector3.ZERO,
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.04, 0.94, 1.0)}, COIL_R, LOW])
			var drive := _p([{"hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.35, 0.3, 0), "head": Vector3(0.25, -0.3, 0),
				"arm_l": Vector3(1.4, 0.35, -0.05), "fore_l": Vector3(0.55, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.2, 0)}, REACH_R, STEP_R])
			return [h._keys(u, [[0.0, low], [0.06 / T, low], [0.11 / T, _whip(drive, Vector3(0.96, 0.99, 1.08), 0.7), "out"], [0.17 / T, drive],
				[0.38 / T, drive], [1.0, g]]), "full", lift]
		"red_eclipse":
			# the ultimate: crouched with the blade up by the face while the dark gathers
			# (0.35 s, then you're gone); back in sight with your back to them, the blade
			# flicked clean, and a beat later every wound opens
			var gather := _p([{"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.5, -0.3, 0), "head": Vector3(0.45, 0.3, 0),
				"arm_r": Vector3(1.9, 0.6, 0.5), "fore_r": Vector3(2.0, 0, 0), "hand_r": Vector3(-0.6, 0, 0),
				"arm_l": Vector3(0.4, 0.3, -0.6), "fore_l": Vector3(1.1, 0, 0), "hand_l": Vector3.ZERO,
				"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.05, 0.92, 1.0)}, LOW])
			var dash := _p([{"pivot": Vector3(-0.2, 0, 0), "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.45, 0.4, 0), "head": Vector3(0.35, -0.35, 0),
				"arm_r": Vector3(1.3, -0.7, -0.8), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.35, 0, 0),
				"arm_l": Vector3(-0.4, 0, -0.8), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.3, 0)}, STEP_L])
			var flick := _p([{"pivot": Vector3.ZERO, "hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.05, -0.3, 0), "head": Vector3(0.0, 0.3, 0),
				"arm_r": Vector3(0.3, 0.2, 0.9), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
				"arm_l": Vector3(0.1, 0, -0.25), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3.ZERO, "_lift": Vector3(0, -0.04, 0)},
				{"leg_l": Vector3(0.15, 0, -0.12), "shin_l": Vector3(-0.2, 0, 0), "leg_r": Vector3(-0.1, 0, 0.12), "shin_r": Vector3(-0.2, 0, 0)}])
			var k_out := maxf((T - 0.75) / T, 0.4)
			var k_open := maxf((T - 0.5) / T, k_out + 0.05)
			return [h._keys(u, [[0.0, g], [0.12 / T, gather, "out"], [0.33 / T, gather], [0.4 / T, dash, "out"], [k_out - 0.02, dash],
				[k_out + 0.04, _whip(flick, Vector3(1.0, 1.04, 1.0), 0.5), "out"], [k_open, flick], [k_open + 0.04, flick.merged({"_scale": Vector3(1.03, 0.96, 1.0)}, true)],
				[1.0 - 0.1 / T, flick], [1.0, g]]), "full", lift]
		# --- two daggers: the combo ---
		"dd_1":
			# hit 1: the right dagger swept out and slashed across, the left held up close
			var wind := _p([{"hips": Vector3(0, -0.45, 0), "torso": Vector3(0.0, -0.7, 0.06), "head": Vector3(0.05, 0.6, 0),
				"arm_r": Vector3(1.15, 0.55, 1.25), "fore_r": Vector3(1.15, 0, 0), "hand_r": Vector3(0.55, 0, 0),
				"arm_l": Vector3(1.05, 0.4, -0.25), "fore_l": Vector3(1.5, 0, 0), "hand_l": Vector3(rev(1.05, 1.5, 0.3), 0, 0),
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(1.03, 0.96, 1.0)}, SET])
			var cut := _p([{"hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.3, 0.6, -0.06), "head": Vector3(0.2, -0.5, 0),
				"arm_r": Vector3(1.25, -0.8, -0.75), "fore_r": Vector3(0.12, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(0.9, 0.35, -0.5), "fore_l": Vector3(1.3, 0, 0), "hand_l": Vector3(rev(0.9, 1.3, 0.3), 0, 0), "_lift": Vector3(0, -0.2, 0)}, STEP_L])
			return [h._keys(u, [[0.0, g], [0.2, wind, "out"], [0.25, wind], [0.36, _whip(cut, Vector3(1.06, 0.97, 1.02)), "out"],
				[0.44, cut], [0.6, cut], [1.0, g]]), "full", lift]
		"dd_2":
			# hit 2: the reversed left dagger raised by the ear (the chest turned away),
			# then hammered down and in, point first, the left shoulder driving through
			var wind := _p([{"hips": Vector3(0, 0.35, 0), "torso": Vector3(0.05, 0.5, -0.05), "head": Vector3(0.0, -0.4, 0),
				"arm_l": Vector3(2.5, 0.3, -0.35), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3(rev(2.5, 1.0, 1.4), 0, 0),
				"arm_r": Vector3(1.0, -0.2, 0.35), "fore_r": Vector3(1.6, 0, 0), "hand_r": Vector3(-1.4, 0, 0),
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.98, 1.04, 1.0)}, SET])
			var stab := _p([{"hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.35, -0.45, 0.05), "head": Vector3(0.25, 0.35, 0),
				"arm_l": Vector3(1.3, 0.2, -0.1), "fore_l": Vector3(0.35, 0, 0), "hand_l": Vector3(rev(1.3, 0.35, 0.95), 0, 0),
				"arm_r": Vector3(0.3, -0.1, 0.5), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3(-1.2, 0, 0), "_lift": Vector3(0, -0.26, 0)}, STEP_L])
			return [h._keys(u, [[0.0, g], [0.2, wind, "out"], [0.25, wind], [0.36, _whip(stab, Vector3(1.04, 0.94, 1.04)), "out"],
				[0.44, stab], [0.6, stab], [1.0, g]]), "full", lift]
		"dd_3":
			# hit 3: both blades flung wide, then scissored in across the front, crossing
			var open := _p([{"hips": Vector3.ZERO, "torso": Vector3(0.12, 0, 0), "head": Vector3(-0.08, 0, 0),
				"arm_r": Vector3(1.0, 0.6, 1.5), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(0.3, 0, 0),
				"arm_l": Vector3(1.0, -0.6, -1.5), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3(-1.5, 0, 0),
				"_lift": Vector3(0, -0.08, 0), "_scale": Vector3(1.06, 0.96, 1.0)}, SET])
			# (the reversed left blade lies along the forearm: its edge cuts as the arm sweeps in)
			var cross := _p([{"hips": Vector3.ZERO, "torso": Vector3(-0.42, 0, 0), "head": Vector3(0.28, 0, 0),
				"arm_r": Vector3(1.7, -0.95, -0.4), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-1.2, 0, 0),
				"arm_l": Vector3(1.7, 0.95, 0.4), "fore_l": Vector3(0.15, 0, 0), "hand_l": Vector3(-1.5, 0, 0), "_lift": Vector3(0, -0.24, 0)}, STEP_L])
			return [h._keys(u, [[0.0, g], [0.24, open, "out"], [0.3, open], [0.4, _whip(cross, Vector3(0.96, 0.97, 1.06)), "out"],
				[0.48, cross], [0.66, cross], [1.0, g]]), "full", lift]
		"dd_4":
			# hit 4 (Fang Whirl): coiled, a whirl with both blades out, then square to them
			# and both driven in together
			var coil := _p([{"hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.2, 0.7, 0.05), "head": Vector3(0.15, -0.5, 0),
				"arm_r": Vector3(0.9, 0.6, 1.2), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(0.5, 0, 0),
				"arm_l": Vector3(1.0, 0.5, -0.6), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3(-0.5, 0, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.04, 0.94, 1.02)}, LOW])
			var out := _p([{"hips": Vector3.ZERO, "torso": Vector3(-0.2, 0, 0.1), "head": Vector3(0.12, 0, 0),
				"arm_r": Vector3(1.4, 0.0, 1.45), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.45, 0, 0),
				"arm_l": Vector3(1.4, 0.0, -1.45), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(-1.5, 0, 0), "_lift": Vector3(0, -0.1, 0)},
				{"leg_l": Vector3(0.5, 0, -0.25), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.4, 0, 0.25), "shin_r": Vector3(-0.7, 0, 0)}])
			# (the right straight in, the reversed left hammered down beside it)
			var both := _p([{"hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.45, 0.1, 0), "head": Vector3(0.3, -0.1, 0),
				"arm_r": Vector3(1.85, -0.2, 0.05), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.5, 0, 0),
				"arm_l": Vector3(1.85, 0.2, -0.05), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(rev(1.85, 0.1, 1.05), 0, 0), "_lift": Vector3(0, -0.3, 0)}, STEP_R])
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.12, coil, "out"], [0.16, coil], [0.24, _whip(out, Vector3(1.03, 0.98, 1.03), 0.5), "out"], [0.5, out],
				[0.62, _whip(both, Vector3(0.95, 0.98, 1.1), 0.7), "out"], [0.68, both], [0.84, both], [1.0, g]])
			var k := clampf((u - 0.18) / 0.36, 0.0, 1.0)
			pz["pivot"] = Vector3(0, -TAU * (1.0 - pow(1.0 - k, 2.0)), 0)
			return [pz, "full", lift]
		# --- two daggers: the heavy (Scissor Rip) ---
		"dd_heavy":
			# both blades drawn back by the hips, a lunge driving both in side by side
			# (0.38 s), held, then ripped apart outward (0.6 s)
			var coil := _p([{"hips": Vector3.ZERO, "torso": Vector3(-0.15, 0, 0), "head": Vector3(0.1, 0, 0),
				"arm_r": Vector3(0.2, 0.2, 0.45), "fore_r": Vector3(1.8, 0, 0), "hand_r": Vector3(-1.8, 0, 0),
				"arm_l": Vector3(0.2, -0.2, -0.45), "fore_l": Vector3(1.8, 0, 0), "hand_l": Vector3(rev(0.2, 1.8, 1.5), 0, 0),
				"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.04, 0.94, 0.97)}, LOW])
			var drive := _p([{"hips": Vector3.ZERO, "torso": Vector3(-0.4, 0, 0), "head": Vector3(0.3, 0, 0),
				"arm_r": Vector3(1.85, -0.12, 0.08), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.5, 0, 0),
				"arm_l": Vector3(1.85, 0.12, -0.08), "fore_l": Vector3(0.05, 0, 0), "hand_l": Vector3(rev(1.85, 0.05, 1.3), 0, 0), "_lift": Vector3(0, -0.32, 0)}, STEP_R])
			var rip := _p([{"hips": Vector3.ZERO, "torso": Vector3(-0.2, 0, 0), "head": Vector3(0.15, 0, 0),
				"arm_r": Vector3(1.1, 0.3, 1.45), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-1.1, 0, 0),
				"arm_l": Vector3(1.1, -0.3, -1.45), "fore_l": Vector3(0.15, 0, 0), "hand_l": Vector3(-1.5, 0, 0), "_lift": Vector3(0, -0.22, 0)}, STEP_R])
			var k_d := 0.38 / T
			var k_r := 0.6 / T
			return [h._keys(u, [[0.0, g], [k_d - 0.16, coil, "out"], [k_d - 0.08, coil], [k_d, _whip(drive, Vector3(0.95, 0.98, 1.1), 0.7), "out"],
				[k_d + 0.06, drive], [k_r - 0.06, drive.merged({"_scale": Vector3(1.03, 0.95, 1.0)}, true)], [k_r, _whip(rip, Vector3(1.08, 0.96, 1.0), 0.7), "out"],
				[k_r + 0.07, rip], [0.86, rip], [1.0, g]]), "full", lift]
		# --- two daggers: the jump attack (Knife Rain) ---
		"knife_rain":
			# hanging, both hands go up behind the head for a fistful of knives, then
			# fling down and out together (0.22 s)
			var up := _p([{"pivot": Vector3(0.1, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.25, 0, 0), "head": Vector3(0.2, 0, 0),
				"arm_r": Vector3(2.8, 0.2, 0.5), "fore_r": Vector3(1.6, 0, 0), "hand_r": Vector3(0.5, 0, 0),
				"arm_l": Vector3(2.8, -0.2, -0.5), "fore_l": Vector3(1.6, 0, 0), "hand_l": Vector3(0.5, 0, 0), "_scale": Vector3(0.98, 1.04, 1.0)}, TUCK])
			var throw := {"pivot": Vector3(-0.45, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.4, 0, 0), "head": Vector3(0.35, 0, 0),
				"arm_r": Vector3(0.9, -0.3, 0.45), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.4, 0, 0),
				"arm_l": Vector3(0.9, 0.3, -0.45), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(-1.4, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.15), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.6, 0, 0.15), "shin_r": Vector3(-1.2, 0, 0)}
			return [h._keys(u, [[0.0, {}], [0.12 / T, up, "out"], [0.17 / T, up], [0.22 / T, _whip(throw, Vector3(1.04, 0.97, 1.04), 0.5), "out"],
				[0.3 / T, throw], [1.0, throw]]), "full", lift]
		# --- two daggers: techniques ---
		"viper_flurry":
			# a lunge held while the blades strike in turn (peaks every 0.09 s from 0.12 s,
			# right then left), then both driven in and ripped out (0.82 s)
			var s := u * T
			var body := _p([{"hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.42, 0.0, 0), "head": Vector3(0.3, 0, 0), "_lift": Vector3(0, -0.28, 0)}, STEP_R])
			for side in ["r", "l"]:
				var sgn := 1.0 if side == "r" else -1.0
				var phase := 0.0 if side == "r" else 0.09
				var ext := 0.0
				if s > 0.06 and s < 0.76:
					var x := fposmod(s - 0.12 - phase, 0.18) / 0.18
					ext = clampf(1.0 - absf(x - 0.0) * 4.0, 0.0, 1.0) + clampf(1.0 - absf(x - 1.0) * 4.0, 0.0, 1.0)
				var coil := Vector3(0.6, 0.3 * sgn, 0.4 * sgn)
				var reach := Vector3(1.85, -0.1 * sgn, 0.05 * sgn)
				body["arm_" + side] = coil.lerp(reach, ext)
				body["fore_" + side] = Vector3(lerpf(1.6, 0.05, ext), 0, 0)
				# (the reversed left pick-stabs down; the right drives straight in)
				body["hand_" + side] = Vector3(-1.5 if side == "r" else lerpf(-0.4, 0.8, ext), 0, 0)
				body["torso"] = (body["torso"] as Vector3) + Vector3(0, 0.12 * sgn * ext, 0)
			var fin := _p([{"hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.5, 0, 0), "head": Vector3(0.35, 0, 0),
				"arm_r": Vector3(1.1, 0.3, 1.4), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-1.1, 0, 0),
				"arm_l": Vector3(1.1, -0.3, -1.4), "fore_l": Vector3(0.15, 0, 0), "hand_l": Vector3(-1.1, 0, 0), "_lift": Vector3(0, -0.3, 0)}, STEP_R])
			return [h._keys(u, [[0.0, g], [0.06 / T, body, "out"], [0.76 / T, body], [0.82 / T, _whip(fin, Vector3(1.07, 0.96, 1.0), 0.7), "out"],
				[0.9 / T, fin], [1.0, g]]), "full", lift]
		"scissor_leap":
			# both blades crossed high as you leap (to 0.3 s), then flung apart and
			# scissored in through them as you land (0.4 s)
			var high := _p([{"pivot": Vector3(-0.1, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.2, 0, 0), "head": Vector3(-0.05, 0, 0),
				"arm_r": Vector3(2.7, -0.35, -0.3), "fore_r": Vector3(0.7, 0, 0), "hand_r": Vector3(0.3, 0, 0),
				"arm_l": Vector3(2.7, 0.35, 0.3), "fore_l": Vector3(0.7, 0, 0), "hand_l": Vector3(0.3, 0, 0), "_scale": Vector3(0.97, 1.05, 1.0)}, TUCK])
			var open := _p([{"pivot": Vector3(-0.2, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.0, 0, 0), "head": Vector3(0.1, 0, 0),
				"arm_r": Vector3(1.4, 0.5, 1.35), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"arm_l": Vector3(1.4, -0.5, -1.35), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3(0.4, 0, 0)},
				{"leg_l": Vector3(0.9, 0, -0.14), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(0.5, 0, 0.14), "shin_r": Vector3(-1.0, 0, 0)}])
			var shut := _p([{"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(-0.55, 0, 0), "head": Vector3(0.38, 0, 0),
				"arm_r": Vector3(1.75, -0.8, -0.6), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(1.75, 0.8, 0.6), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(-1.5, 0, 0), "_lift": Vector3(0, -0.42, 0)},
				{"leg_l": Vector3(1.2, 0, -0.15), "shin_l": Vector3(-1.6, 0, 0), "leg_r": Vector3(-0.4, 0, 0.15), "shin_r": Vector3(-1.2, 0, 0)}])
			return [h._keys(u, [[0.0, g], [0.12 / T, high, "out"], [0.28 / T, high], [0.34 / T, open, "out"], [0.37 / T, open],
				[0.42 / T, _whip(shut, Vector3(1.06, 0.92, 1.03), 0.7), "out"], [0.5 / T, shut], [0.66 / T, shut], [1.0, g]]), "full", lift]
		"edge_whet":
			# Bleeding Edge: both blades crossed before the face, then drawn apart along
			# each other (the edges catch the light), and lowered, ready
			var cross := {"hips": Vector3.ZERO, "torso": Vector3(0.05, 0, 0), "head": Vector3(0.05, 0, 0),
				"arm_r": Vector3(1.55, -0.55, -0.4), "fore_r": Vector3(1.3, 0, 0), "hand_r": Vector3(-0.4, 0, 0),
				"arm_l": Vector3(1.55, 0.55, 0.4), "fore_l": Vector3(1.3, 0, 0), "hand_l": Vector3(-0.4, 0, 0),
				"leg_l": Vector3(0.2, 0, -0.14), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(-0.15, 0, 0.14), "shin_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.05, 0)}
			var apart := cross.merged({"arm_r": Vector3(1.25, 0.3, 1.1), "fore_r": Vector3(0.5, 0, 0), "hand_r": Vector3(-1.0, 0, 0),
				"arm_l": Vector3(1.25, -0.3, -1.1), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3(-1.0, 0, 0),
				"torso": Vector3(-0.1, 0, 0), "_scale": Vector3(1.04, 0.97, 1.0), "_smear": Vector3(0.4, 0, 0)}, true)
			return [h._keys(u, [[0.0, g], [0.25, cross, "out"], [0.4, cross], [0.55, apart, "out"], [0.85, apart.merged({"_smear": Vector3.ZERO, "_scale": Vector3.ONE}, true)], [1.0, g]]), "full", lift]
		"hundred_fangs":
			# the ultimate: both blades drawn back low while it gathers (0.4 s), then cut
			# after cut from every side (you're blinking round them: held low and swept
			# through), then square to the middle, the blades crossed and flung apart (1.9 s)
			var gather := _p([{"pivot": Vector3(-0.1, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.5, 0, 0), "head": Vector3(0.4, 0, 0),
				"arm_r": Vector3(-0.2, 0.25, 0.5), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(-1.4, 0, 0),
				"arm_l": Vector3(-0.2, -0.25, -0.5), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3(-1.4, 0, 0),
				"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.05, 0.92, 1.0)}, LOW])
			var s := u * T
			var flip := 1.0 if int(maxf(s - 0.4, 0.0) / 0.13) % 2 == 0 else -1.0
			var cut := _p([{"pivot": Vector3(-0.2, 0, 0), "hips": Vector3(0, 0.3 * flip, 0), "torso": Vector3(-0.45, 0.45 * flip, 0), "head": Vector3(0.3, -0.35 * flip, 0),
				"arm_r": Vector3(1.3, -0.7, -0.8) if flip > 0.0 else Vector3(0.9, 0.5, 1.3), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.35, 0, 0),
				"arm_l": Vector3(0.9, -0.5, -1.3) if flip > 0.0 else Vector3(1.3, 0.7, 0.8), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(-1.5, 0, 0),
				"_lift": Vector3(0, -0.3, 0)}, STEP_L if flip > 0.0 else STEP_R])
			var cross := _p([{"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(0.1, 0, 0), "head": Vector3(-0.05, 0, 0),
				"arm_r": Vector3(1.6, -0.6, -0.45), "fore_r": Vector3(1.2, 0, 0), "hand_r": Vector3(-0.4, 0, 0),
				"arm_l": Vector3(1.6, 0.6, 0.45), "fore_l": Vector3(1.2, 0, 0), "hand_l": Vector3(-0.4, 0, 0), "_lift": Vector3(0, -0.1, 0)}, SET])
			var fling := _p([{"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(-0.3, 0, 0), "head": Vector3(0.2, 0, 0),
				"arm_r": Vector3(1.0, 0.4, 1.5), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.2, 0, 0),
				"arm_l": Vector3(1.0, -0.4, -1.5), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(-1.5, 0, 0), "_lift": Vector3(0, -0.32, 0)}, STEP_R])
			var k_x := 1.75 / T
			var k_f := 1.9 / T
			return [h._keys(u, [[0.0, g], [0.12 / T, gather, "out"], [0.38 / T, gather], [0.44 / T, cut, "out"], [k_x - 0.04, cut],
				[k_x, cross, "out"], [k_f - 0.02, cross], [k_f, _whip(fling, Vector3(1.08, 0.94, 1.0), 0.8), "out"], [k_f + 0.05, fling],
				[1.0 - 0.12 / T, fling], [1.0, g]]), "full", lift]
	return []
