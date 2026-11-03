class_name FoePoses
## (1.30 round 6) Key poses for the foes' personalities, jumping attacks and the riflemen's moves, every name "fo_".
## Humanoid._action_pose sends them here. Same conventions as humanoid.gd (driftwake-animation). The stances
## (fo_frenzy, fo_lurk, fo_en_garde, fo_guard_walk, fo_parry_ready) are upper-body holds: the legs keep circling.


static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	var t: float = h._t
	match n:
		"fo_frenzy":
			# Berserker: hunched in, blade low and out wide, the off hand clawing forward, breathing hard
			var heave := sin(t * 9.0) * 0.05
			var fr := {"torso": Vector3(-0.38 + heave, 0.15, 0), "head": Vector3(0.3 - heave, -0.1, 0),
				"arm_r": Vector3(0.25, 0, 0.75), "fore_r": Vector3(0.55, 0, 0), "hand_r": Vector3(0.35, 0, 0),
				"arm_l": Vector3(0.75, 0, -0.75), "fore_l": Vector3(0.95, 0, 0), "hand_l": Vector3(0.2, 0, 0)}
			return [h._keys(u, [[0.0, {}], [1.0, fr]]), "upper", lift]
		"fo_lurk":
			# Opportunist: low and coiled, side-on, blade drawn back by the hip, the off hand out feeling the distance
			var lk := {"torso": Vector3(-0.28, 0.35, 0), "head": Vector3(0.18, -0.35, 0),
				"arm_r": Vector3(-0.25, 0.2, 0.35), "fore_r": Vector3(0.95, 0, 0), "hand_r": Vector3(0.55, 0, 0),
				"arm_l": Vector3(0.95, -0.2, -0.3), "fore_l": Vector3(0.6, 0, 0), "hand_l": Vector3(0.1, 0, 0)}
			return [h._keys(u, [[0.0, {}], [1.0, lk]]), "upper", lift]
		"fo_en_garde":
			# Duelist: side-on, the sword shoulder leading, point level at the captain's chest, the off hand up behind
			var eg := {"torso": Vector3(0.05, 0.6, 0), "head": Vector3(-0.03, -0.55, 0),
				"arm_r": Vector3(1.25, -0.3, 0.1), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(0.25, 0, -1.55), "fore_l": Vector3(1.65, 0, 0), "hand_l": Vector3(0.3, 0, 0)}
			return [h._keys(u, [[0.0, {}], [1.0, eg]]), "upper", lift]
		"fo_guard_walk":
			# Bulwark: the guard up across the body (or the shield forward), hunched behind it
			var gw := {"torso": Vector3(-0.18, -0.35, 0), "head": Vector3(0.15, 0.3, 0),
				"arm_r": Vector3(1.35, -0.6, -0.15), "fore_r": Vector3(1.25, 0, 0), "hand_r": Vector3(0, 0, 1.2),
				"arm_l": Vector3(1.15, 0.5, -0.1), "fore_l": Vector3(1.6, 0, 0), "hand_l": Vector3(0.1, 0, 0)}
			return [h._keys(u, [[0.0, {}], [1.0, gw]]), "upper", lift]
		"fo_parry_ready":
			# Duelist reading a swing: the blade snapped up across the line, the point high, the weight back
			var tr := sin(t * 38.0) * 0.025
			var pr := {"torso": Vector3(0.08, 0.3, 0), "head": Vector3(-0.05, -0.25, 0),
				"arm_r": Vector3(1.65 + tr, -0.55, -0.05), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(0.1, 0, 1.0),
				"arm_l": Vector3(-0.2, 0, -0.65), "fore_l": Vector3(0.6, 0, 0), "hand_l": Vector3(0.1, 0, 0)}
			return [h._keys(u, [[0.0, {}], [1.0, pr]]), "upper", lift]
		"fo_parry":
			# the blow beaten aside: the blade sweeps out to the sword side, a half step back, then coiled to riposte
			var legs := {"leg_l": Vector3(0.35, 0, -0.12), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.45, 0, 0.12), "shin_r": Vector3(-0.6, 0, 0)}
			var ready := {"pivot": Vector3.ZERO, "hips": Vector3(0, 0.15, 0), "torso": Vector3(0.08, 0.3, 0), "head": Vector3(-0.05, -0.25, 0),
				"arm_r": Vector3(1.65, -0.55, -0.05), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(0.1, 0, 1.0),
				"arm_l": Vector3(-0.2, 0, -0.65), "fore_l": Vector3(0.6, 0, 0), "hand_l": Vector3(0.1, 0, 0), "_lift": Vector3(0, -0.06, 0)}.merged(legs)
			var beat := {"pivot": Vector3.ZERO, "hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.1, -0.55, 0), "head": Vector3(0.05, 0.5, 0),
				"arm_r": Vector3(1.25, 0.65, 0.95), "fore_r": Vector3(0.45, 0, 0), "hand_r": Vector3(-0.45, 0, 0),
				"arm_l": Vector3(0.35, 0, -1.05), "fore_l": Vector3(0.55, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(1.0, 1.0, 1.05)}.merged(legs)
			var coil: Dictionary = h.E_COIL.merged({"pivot": Vector3.ZERO, "hips": Vector3(0, 0.1, 0), "hand_l": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(1.02, 0.97, 1.0)})
			return [h._keys(u, [[0.0, ready], [0.22, beat, "out"], [0.5, beat], [1.0, coil]]), "full", lift]
	return []
