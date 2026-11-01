class_name GadgetPoses
extends RefCounted
## The gadgets' poses ("gd_*", reached through TechniquePoses.pose). Humanoid conventions (driftwake-animation).
##   gd_lob   an overhand lob from the off hand (upper body: the legs keep running): the arm cocked back over the
##            shoulder, the chest turned away, then whipped through with the wrist flicked (release at u 0.52)


static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	var T: float = float(h._action.get("dur", 1.0))
	match n:
		"gd_lob":
			var cock := {"arm_l": Vector3(2.7, 0.2, -0.55), "fore_l": Vector3(1.7, 0, 0), "hand_l": Vector3(-0.7, 0, 0),
				"torso": Vector3(0.14, -0.4, 0.04), "head": Vector3(-0.08, 0.3, 0), "arm_r": Vector3(0.7, 0, 0.35), "fore_r": Vector3(0.6, 0, 0),
				"_scale": Vector3(0.98, 1.03, 1.0)}
			var whip := {"arm_l": Vector3(1.55, 0.0, -0.1), "fore_l": Vector3(0.15, 0, 0), "hand_l": Vector3(0.6, 0, 0),
				"torso": Vector3(-0.22, 0.38, -0.03), "head": Vector3(0.12, -0.32, 0), "arm_r": Vector3(-0.2, 0, 0.25), "fore_r": Vector3(0.4, 0, 0),
				"_scale": Vector3(1.03, 0.97, 1.0)}
			var follow := whip.merged({"arm_l": Vector3(1.2, 0.0, 0.05), "hand_l": Vector3(0.9, 0, 0), "_scale": Vector3.ONE}, true)
			return [h._keys(u, [[0.0, {}], [0.36, cock, "out"], [0.46, cock], [0.56, whip, "out"], [0.78, follow], [1.0, {}]]), "upper", lift]
		"gd_grapple":
			# hauled up the line: both arms up it, the body stretched after them, legs trailing
			var haul := {"arm_l": Vector3(2.7, 0.15, -0.15), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(2.6, -0.1, 0.2), "fore_r": Vector3(0.5, 0, 0),
				"torso": Vector3(0.15, 0.1, 0), "head": Vector3(0.25, 0, 0), "hips": Vector3.ZERO,
				"leg_l": Vector3(-0.3, 0, -0.1), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(0.2, 0, 0.1), "shin_r": Vector3(-0.9, 0, 0),
				"_scale": Vector3(0.97, 1.04, 1.0)}
			return [h._keys(minf(u * T / 0.25, 1.0), [[0.0, {}], [1.0, haul, "out"]]), "full", lift]
		"gd_glide":
			# hanging under the wing from its bar: arms up, legs together and swept back
			var glide := {"arm_l": Vector3(2.9, 0.0, -0.25), "fore_l": Vector3(0.2, 0, 0), "arm_r": Vector3(2.9, 0.0, 0.25), "fore_r": Vector3(0.2, 0, 0),
				"torso": Vector3(-0.25, 0, 0), "head": Vector3(-0.35, 0, 0), "hips": Vector3(-0.2, 0, 0),
				"leg_l": Vector3(-0.35, 0, 0.0), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(-0.3, 0, 0.0), "shin_r": Vector3(-0.4, 0, 0)}
			return [h._keys(minf(u * T / 0.2, 1.0), [[0.0, {}], [1.0, glide, "out"]]), "full", lift]
		"gd_spy":
			# the glass snapped up to the eye in the off hand, the chin dipped to it, a beat held, then down
			var look := {"arm_l": Vector3(2.0, 0.55, 0.25), "fore_l": Vector3(2.1, 0, 0), "hand_l": Vector3(-0.3, 0, 0),
				"torso": Vector3(-0.06, 0.12, 0), "head": Vector3(-0.08, -0.12, 0.08), "arm_r": Vector3(0.25, 0, 0.3), "fore_r": Vector3(0.9, 0, 0)}
			return [h._keys(u, [[0.0, {}], [0.2, look, "out"], [0.8, look], [1.0, {}]]), "upper", lift]
		"gd_hang":
			# one hand on the spike over the head, the other reaching, feet against the wall
			var hang := {"arm_r": Vector3(2.9, 0.0, 0.1), "fore_r": Vector3(0.3, 0, 0), "arm_l": Vector3(1.6, 0.3, -0.35), "fore_l": Vector3(0.9, 0, 0),
				"torso": Vector3(0.1, 0.15, 0), "head": Vector3(-0.3, -0.1, 0), "hips": Vector3.ZERO,
				"leg_l": Vector3(0.7, 0, -0.1), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(0.3, 0, 0.1), "shin_r": Vector3(-0.7, 0, 0)}
			return [h._keys(minf(u * T / 0.15, 1.0), [[0.0, {}], [1.0, hang, "out"]]), "full", lift]
	return []
