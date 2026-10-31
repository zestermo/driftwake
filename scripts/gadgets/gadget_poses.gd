class_name GadgetPoses
extends RefCounted
## The gadgets' poses ("gd_*", reached through TechniquePoses.pose). Humanoid conventions (driftwake-animation).
##   gd_lob   an overhand lob from the off hand (upper body: the legs keep running): the arm cocked back over the
##            shoulder, the chest turned away, then whipped through with the wrist flicked (release at u 0.52)


static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
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
	return []
