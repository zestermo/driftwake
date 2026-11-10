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
			# (1.31) hauled up the line one-handed: the rope arm reaching up it and drawing in, the chest leaning after it,
			# the free arm out behind for balance, the legs trailing loose (mirrored for the left hand: Humanoid.rope_left)
			var haul := {"arm_l": Vector3(-0.6, 0.0, -0.55), "fore_l": Vector3(0.5, 0, 0), "arm_r": Vector3(2.5, -0.1, 0.15), "fore_r": Vector3(1.1 + 0.25 * sin(u * T * 9.0), 0, 0),
				"torso": Vector3(-0.2, 0.15, 0.05), "head": Vector3(-0.15, -0.1, 0), "hips": Vector3.ZERO,
				"leg_l": Vector3(-0.4, 0, -0.08), "shin_l": Vector3(-0.55, 0, 0), "leg_r": Vector3(-0.1, 0, 0.08), "shin_r": Vector3(-0.3, 0, 0),
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
		"gd_plant":
			# (1.30) down on the right knee, the satchel pressed to the spot with both hands, the head down to the fuse;
			# held, then up again
			var kneel := {"pivot": Vector3(-0.35, 0, 0), "torso": Vector3(0.05, 0, 0), "head": Vector3(0.05, 0, 0),
				"arm_l": Vector3(1.0, 0.1, -0.15), "fore_l": Vector3(0.7, 0, 0), "hand_l": Vector3(0.3, 0, 0),
				"arm_r": Vector3(1.0, -0.1, 0.15), "fore_r": Vector3(0.6, 0, 0), "hand_r": Vector3(0.3, 0, 0),
				"leg_l": Vector3(1.45, 0, -0.08), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.1, 0, 0.1), "shin_r": Vector3(-2.0, 0, 0),
				"_scale": Vector3(1.02, 0.98, 1.0)}
			var e := clampf(u / 0.3, 0.0, 1.0) * clampf((1.0 - u) / 0.25, 0.0, 1.0)
			lift = Vector3(0, -0.5 * smoothstep(0.0, 1.0, e), 0)
			return [h._keys(u, [[0.0, {}], [0.3, kneel, "out"], [0.75, kneel], [1.0, {}]]), "full", lift]
		"gd_skim":
			# side-on at the boom: feet wide along the board (the nose to the left), knees soft, both hands out on the
			# wishbone, hips and shoulders hung back against the sail's pull, the head turned to the nose; the knees
			# flex slowly with the swell
			var flex := sin(u * T * 2.3) * 0.08
			var ride := {"arm_l": Vector3(1.1, 0.1, -0.35), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3(0.2, 0, 0),
				"arm_r": Vector3(1.0, -0.1, 0.05), "fore_r": Vector3(0.45, 0, 0), "hand_r": Vector3(0.2, 0, 0),
				"pivot": Vector3(0.2, 0, 0), "torso": Vector3(-0.05, 0.15, 0), "head": Vector3(-0.1, 0.55, 0),
				"leg_l": Vector3(0.3 + flex, 0, -0.32), "shin_l": Vector3(-0.55 - flex * 2.0, 0, 0),
				"leg_r": Vector3(0.25 + flex, 0, 0.32), "shin_r": Vector3(-0.5 - flex * 2.0, 0, 0)}
			return [h._keys(minf(u * T / 0.25, 1.0), [[0.0, {}], [1.0, ride, "out"]]), "full", Vector3(0, -0.06 - flex * 0.3, 0)]
	return []
