class_name ApePoses
extends RefCounted
## The silverback's moves (JungleApe; Humanoid._action_pose asks here before
## the techniques). Keys start and end on {} = its knuckle-walk (stance "ape").
## Every main key sets the whole body (a joint left out takes the gait's).

## Reared up on its short legs: knees bent and wide (keys using it drop the hips ~0.1).
const STRONG_LEGS := {"leg_l": Vector3(0.38, 0, -0.3), "shin_l": Vector3(-0.55, 0, 0), "leg_r": Vector3(0.38, 0, 0.3), "shin_r": Vector3(-0.55, 0, 0)}
const DEEP_LEGS := {"leg_l": Vector3(1.25, 0, -0.26), "shin_l": Vector3(-1.75, 0, 0), "leg_r": Vector3(1.25, 0, 0.26), "shin_r": Vector3(-1.75, 0, 0)}


static func pose(h, n: String, u: float) -> Array:
	match n:
		"ape_beat":
			# reared up, fists drumming the chest left-right-left..., then arms
			# flung wide and a roar at the sky (the shockwave at u 0.8)
			var up := {"pivot": Vector3(0.12, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.22, 0, 0), "head": Vector3(0.15, 0, 0),
				"_lift": Vector3(0, -0.11, 0)}.merged(STRONG_LEGS)
			var beat_l := up.merged({"arm_l": Vector3(1.5, 0, 0.45), "fore_l": Vector3(1.75, 0, 0), "arm_r": Vector3(1.0, 0, 0.7), "fore_r": Vector3(2.2, 0, 0)})
			var beat_r := up.merged({"arm_r": Vector3(1.5, 0, -0.45), "fore_r": Vector3(1.75, 0, 0), "arm_l": Vector3(1.0, 0, -0.7), "fore_l": Vector3(2.2, 0, 0)})
			var roar := up.merged({"torso": Vector3(0.35, 0, 0), "head": Vector3(0.55, 0, 0),
				"arm_l": Vector3(1.3, 0, -1.35), "fore_l": Vector3(0.35, 0, 0), "arm_r": Vector3(1.3, 0, 1.35), "fore_r": Vector3(0.35, 0, 0)})
			return [h._keys(u, [[0.0, {}], [0.18, beat_l, "out"], [0.28, beat_r, "out"], [0.38, beat_l, "out"], [0.48, beat_r, "out"],
				[0.58, beat_l, "out"], [0.68, beat_r, "out"], [0.8, roar, "out"], [0.92, roar], [1.0, {}]]), "full", Vector3.ZERO]
		"ape_swipe":
			# a backhand: the right arm cocked out wide behind, the chest wound
			# right, then the whole body unwinds and the arm sweeps across the
			# front (hits u 0.42-0.6) and on round past the left
			var base := {"pivot": Vector3(-0.3, 0, 0), "hips": Vector3(0, -0.2, 0), "head": Vector3(0.6, 0, 0),
				"arm_l": Vector3(0.6, 0.1, -0.35), "fore_l": Vector3(0.3, 0, 0), "_lift": Vector3(0, -0.28, 0),
				"leg_l": Vector3(0.9, 0, -0.25), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(0.5, 0, 0.3), "shin_r": Vector3(-1.0, 0, 0)}
			# (1.23: it sinks and squats into the cock, stretches along the blow, and the arm carries on round past)
			var cock := base.merged({"torso": Vector3(-0.25, -0.75, 0), "arm_r": Vector3(0.35, 0.2, 1.5), "fore_r": Vector3(0.75, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"_lift": Vector3(0, -0.36, 0), "_scale": Vector3(1.05, 0.93, 1.0)})
			var hit := base.merged({"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.3, 0.6, 0), "arm_r": Vector3(1.45, 0.65, -0.15), "fore_r": Vector3(0.25, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_scale": Vector3(0.98, 1.02, 1.07)})
			var past := base.merged({"hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.32, 0.95, 0.06), "arm_r": Vector3(1.0, 0.95, -0.6), "fore_r": Vector3(0.5, 0, 0)})
			return [h._keys(u, [[0.0, {}], [0.38, cock], [0.5, hit, "in"], [0.62, past, "out"], [0.78, past], [1.0, {}]]), "full", Vector3.ZERO]
		"ape_slam_wind":
			# (held) up on its legs, back arched, both fists high overhead
			# (a dip first, then up and stretched tall)
			var high := {"pivot": Vector3(0.05, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.3, 0, 0), "head": Vector3(0.15, 0, 0),
				"arm_l": Vector3(2.85, 0, -0.2), "fore_l": Vector3(0.65, 0, 0), "arm_r": Vector3(2.85, 0, 0.2), "fore_r": Vector3(0.65, 0, 0),
				"hand_l": Vector3.ZERO, "hand_r": Vector3.ZERO, "_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.97, 1.05, 1.0)}.merged(STRONG_LEGS)
			var dip := {"pivot": Vector3(-0.5, 0, 0), "torso": Vector3(-0.3, 0, 0), "head": Vector3(0.8, 0, 0), "_lift": Vector3(0, -0.4, 0),
				"_scale": Vector3(1.04, 0.94, 1.0)}.merged(DEEP_LEGS)
			return [h._keys(u, [[0.0, {}], [0.3, dip], [1.0, high, "out"]]), "full", Vector3.ZERO]
		"ape_slam":
			# both fists driven down into the ground in front (impact u 0.25), a deep crouch, back up
			var high := {"pivot": Vector3(0.05, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.3, 0, 0), "head": Vector3(0.15, 0, 0),
				"arm_l": Vector3(2.85, 0, -0.2), "fore_l": Vector3(0.65, 0, 0), "arm_r": Vector3(2.85, 0, 0.2), "fore_r": Vector3(0.65, 0, 0),
				"hand_l": Vector3.ZERO, "hand_r": Vector3.ZERO, "_lift": Vector3(0, -0.1, 0)}.merged(STRONG_LEGS)
			var down := {"pivot": Vector3(-0.7, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.55, 0, 0), "head": Vector3(0.9, 0, 0),
				"arm_l": Vector3(1.55, 0, -0.18), "fore_l": Vector3(0.1, 0, 0), "arm_r": Vector3(1.55, 0, 0.18), "fore_r": Vector3(0.1, 0, 0),
				"hand_l": Vector3(0.7, 0, 0), "hand_r": Vector3(0.7, 0, 0), "_lift": Vector3(0, -0.45, 0), "_scale": Vector3(1.06, 0.92, 1.0)}.merged(DEEP_LEGS)
			# (1.23: a rebound off the ground after the impact, then it hauls its fists out)
			var bounce := down.merged({"pivot": Vector3(-0.6, 0, 0), "torso": Vector3(-0.45, 0, 0), "_lift": Vector3(0, -0.4, 0), "_scale": Vector3(1.0, 1.0, 1.0)})
			return [h._keys(u, [[0.0, high], [0.25, down, "in"], [0.33, bounce, "out"], [0.42, down], [0.62, down], [1.0, {}]]), "full", Vector3.ZERO]
		"ape_crouch":
			# (held) gathering for the leap: low, arms swept back
			var low := {"pivot": Vector3(-0.6, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.5, 0, 0), "head": Vector3(1.0, 0, 0),
				"arm_l": Vector3(-0.6, 0, -0.4), "fore_l": Vector3(0.4, 0, 0), "arm_r": Vector3(-0.6, 0, 0.4), "fore_r": Vector3(0.4, 0, 0),
				"_lift": Vector3(0, -0.55, 0), "_scale": Vector3(1.05, 0.92, 1.0),
				"leg_l": Vector3(1.4, 0, -0.28), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(1.4, 0, 0.28), "shin_r": Vector3(-2.0, 0, 0)}
			return [h._keys(u, [[0.0, {}], [1.0, low]]), "full", Vector3.ZERO]
		"ape_air":
			# (held) in the air: fists up over the head, knees tucked
			var air := {"pivot": Vector3(-0.1, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.1, 0, 0), "head": Vector3(0.3, 0, 0),
				"arm_l": Vector3(2.6, 0, -0.3), "fore_l": Vector3(0.9, 0, 0), "arm_r": Vector3(2.6, 0, 0.3), "fore_r": Vector3(0.9, 0, 0),
				"leg_l": Vector3(1.2, 0, -0.25), "shin_l": Vector3(-1.6, 0, 0), "leg_r": Vector3(1.2, 0, 0.25), "shin_r": Vector3(-1.6, 0, 0),
				"_scale": Vector3(0.96, 1.06, 1.0)}
			return [h._keys(u, [[0.0, {}], [1.0, air, "out"]]), "full", Vector3.ZERO]
		"ape_lift":
			# (held) squats, hands down to the ground, then hauls a boulder up over its head
			var reach := {"pivot": Vector3(-0.6, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.7, 0, 0), "head": Vector3(0.9, 0, 0),
				"arm_l": Vector3(1.6, 0, -0.25), "fore_l": Vector3(0.15, 0, 0), "arm_r": Vector3(1.6, 0, 0.25), "fore_r": Vector3(0.15, 0, 0),
				"_lift": Vector3(0, -0.5, 0)}.merged(DEEP_LEGS)
			var over := {"pivot": Vector3(0.0, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.2, 0, 0), "head": Vector3(0.2, 0, 0),
				"arm_l": Vector3(2.75, 0, -0.28), "fore_l": Vector3(0.75, 0, 0), "arm_r": Vector3(2.75, 0, 0.28), "fore_r": Vector3(0.75, 0, 0),
				"_lift": Vector3(0, -0.1, 0)}.merged(STRONG_LEGS)
			return [h._keys(u, [[0.0, {}], [0.35, reach], [0.6, reach], [0.9, over, "out"], [1.0, over]]), "full", Vector3.ZERO]
		"ape_hurl":
			# the boulder overhead hurled forward (it leaves the hands at u 0.25)
			var over := {"pivot": Vector3(0.0, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.2, 0, 0), "head": Vector3(0.2, 0, 0),
				"arm_l": Vector3(2.75, 0, -0.28), "fore_l": Vector3(0.75, 0, 0), "arm_r": Vector3(2.75, 0, 0.28), "fore_r": Vector3(0.75, 0, 0),
				"_lift": Vector3(0, -0.1, 0)}.merged(STRONG_LEGS)
			var thrown := {"pivot": Vector3(-0.35, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.6, 0, 0), "head": Vector3(0.7, 0, 0),
				"arm_l": Vector3(1.15, 0, -0.2), "fore_l": Vector3(0.2, 0, 0), "arm_r": Vector3(1.15, 0, 0.2), "fore_r": Vector3(0.2, 0, 0),
				"_lift": Vector3(0, -0.25, 0), "leg_l": Vector3(0.9, 0, -0.25), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(0.1, 0, 0.25), "shin_r": Vector3(-0.7, 0, 0)}
			return [h._keys(u, [[0.0, over], [0.28, thrown, "out"], [0.55, thrown], [1.0, {}]]), "full", Vector3.ZERO]
		"ape_perch":
			# (held) crouched on a limb up in the canopy: one fist gripping a branch
			# overhead, the other knuckles down on the limb, head low and forward
			var perch := {"pivot": Vector3(-0.45, 0, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.3, -0.15, 0), "head": Vector3(0.75, 0.2, 0),
				"arm_l": Vector3(2.7, 0, -0.45), "fore_l": Vector3(0.9, 0, 0), "hand_l": Vector3(0.5, 0, 0),
				"arm_r": Vector3(1.35, 0, 0.3), "fore_r": Vector3(0.2, 0, 0), "_lift": Vector3(0, -0.5, 0)}.merged(DEEP_LEGS)
			return [h._keys(u, [[0.0, {}], [1.0, perch, "out"]]), "full", Vector3.ZERO]
		"ape_dive":
			# (held) flung down out of the canopy: arms spread wide, then both fists drawn up for the landing
			var spread := {"pivot": Vector3(-0.5, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.25, 0, 0), "head": Vector3(0.6, 0, 0),
				"arm_l": Vector3(1.6, 0, -1.4), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(1.6, 0, 1.4), "fore_r": Vector3(0.3, 0, 0),
				"leg_l": Vector3(0.7, 0, -0.35), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(0.7, 0, 0.35), "shin_r": Vector3(-1.1, 0, 0),
				"_scale": Vector3(1.04, 0.98, 1.0)}
			var fists := spread.merged({"pivot": Vector3(-0.2, 0, 0), "arm_l": Vector3(2.8, 0, -0.25), "fore_l": Vector3(0.7, 0, 0),
				"arm_r": Vector3(2.8, 0, 0.25), "fore_r": Vector3(0.7, 0, 0)})
			return [h._keys(u, [[0.0, {}], [0.45, spread, "out"], [1.0, fists, "in"]]), "full", Vector3.ZERO]
		"ape_reel":
			# (held, 1.23: its poise broken) half up, rocked back on its heels, head lolling, arms hanging loose, swaying
			var t: float = h._t
			var reel := {"pivot": Vector3(0.12 + sin(t * 1.9) * 0.07, 0, sin(t * 1.3) * 0.1), "hips": Vector3(0, sin(t * 0.8) * 0.1, 0),
				"torso": Vector3(0.18, sin(t * 1.1) * 0.15, sin(t * 1.7) * 0.08), "head": Vector3(0.35 + sin(t * 2.3) * 0.18, sin(t * 0.9) * 0.45, sin(t * 1.6) * 0.22),
				"arm_l": Vector3(0.35 + sin(t * 1.5) * 0.1, 0, -0.32), "fore_l": Vector3(0.35, 0, 0), "arm_r": Vector3(0.3 - sin(t * 1.4) * 0.1, 0, 0.36), "fore_r": Vector3(0.4, 0, 0),
				"hand_l": Vector3(0.3, 0, 0), "hand_r": Vector3(0.3, 0, 0), "_lift": Vector3(0, -0.2, 0),
				"leg_l": Vector3(0.6, 0, -0.32), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(0.3, 0, 0.3), "shin_r": Vector3(-0.6, 0, 0)}
			return [h._keys(u, [[0.0, {}], [1.0, reel, "out"]]), "full", Vector3.ZERO]
		"ape_grab":
			# a low lunge, both arms flung forward to catch
			var lunge := {"pivot": Vector3(-0.8, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.3, 0, 0), "head": Vector3(0.95, 0, 0),
				"arm_l": Vector3(1.55, 0, -0.42), "fore_l": Vector3(0.35, 0, 0), "arm_r": Vector3(1.55, 0, 0.42), "fore_r": Vector3(0.35, 0, 0),
				"hand_l": Vector3(0.2, 0, 0), "hand_r": Vector3(0.2, 0, 0), "_lift": Vector3(0, -0.42, 0), "_scale": Vector3(0.98, 0.98, 1.08),
				"leg_l": Vector3(1.2, 0, -0.25), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(0.2, 0, 0.25), "shin_r": Vector3(-0.6, 0, 0)}
			return [h._keys(u, [[0.0, {}], [0.4, lunge, "out"], [1.0, lunge]]), "full", Vector3.ZERO]
		"ape_grab_hold":
			# (held) up on its legs, the captain crushed in both fists against its chest, shaken like a doll
			var t: float = h._t
			var hold := {"pivot": Vector3(-0.15 + sin(t * 9.0) * 0.05, 0, sin(t * 7.0) * 0.06), "hips": Vector3.ZERO,
				"torso": Vector3(0.1, sin(t * 13.0) * 0.16, 0), "head": Vector3(0.3, -sin(t * 13.0) * 0.1, 0),
				"arm_l": Vector3(1.3, 0, 0.1), "fore_l": Vector3(1.0 + sin(t * 13.0) * 0.15, 0, 0), "arm_r": Vector3(1.3, 0, -0.1), "fore_r": Vector3(1.0 - sin(t * 13.0) * 0.15, 0, 0),
				"_lift": Vector3(0, -0.12, 0)}.merged(STRONG_LEGS)
			return [h._keys(u, [[0.0, {}], [1.0, hold]]), "full", Vector3.ZERO]
		"ape_pound_l", "ape_pound_r":
			# (phase 3's Berserk Pound) one fist hauled up overhead as it steps in, then hammered down (impact u 0.5)
			var s := 1.0 if n == "ape_pound_r" else -1.0
			var arm := "arm_r" if s > 0.0 else "arm_l"
			var fore := "fore_r" if s > 0.0 else "fore_l"
			var hand := "hand_r" if s > 0.0 else "hand_l"
			var other := "arm_l" if s > 0.0 else "arm_r"
			var up := {"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, s * 0.15, 0), "torso": Vector3(0.15, s * 0.35, 0), "head": Vector3(0.45, -s * 0.2, 0),
				arm: Vector3(2.85, 0, s * 0.3), fore: Vector3(0.6, 0, 0), hand: Vector3.ZERO, other: Vector3(1.25, 0, -s * 0.3),
				"_lift": Vector3(0, -0.15, 0), "_scale": Vector3(0.98, 1.04, 1.0)}.merged(STRONG_LEGS)
			var down := {"pivot": Vector3(-0.65, 0, 0), "hips": Vector3(0, -s * 0.2, 0), "torso": Vector3(-0.55, -s * 0.3, 0), "head": Vector3(0.95, s * 0.1, 0),
				arm: Vector3(1.6, 0, s * 0.05), fore: Vector3(0.1, 0, 0), hand: Vector3(0.7, 0, 0), other: Vector3(1.1, 0, -s * 0.35),
				"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.06, 0.92, 1.0),
				"leg_l": Vector3(1.1, 0, -0.26), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(1.1, 0, 0.26), "shin_r": Vector3(-1.5, 0, 0)}
			return [h._keys(u, [[0.0, {}], [0.36, up, "out"], [0.5, down, "in"], [0.78, down], [1.0, {}]]), "full", Vector3.ZERO]
	return []
