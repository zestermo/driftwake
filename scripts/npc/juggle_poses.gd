class_name JugglePoses
extends RefCounted
## A foe thrown up by a launcher (1.23 juggling, Juggle): "jug_air" thrown off its feet and tumbling slowly back,
## arms flung up, legs trailing; "jug_hit" a hit in the air (jack-knifed round the blow, then back to the tumble);
## "jug_held" a captain grabbed by a brute, struggling (held).
## Both are played for the time left up there and keyed in seconds.


static func _air(s: float) -> Dictionary:
	var flail := sin(s * 7.0)
	return {"pivot": Vector3(0.55 + 0.35 * minf(s / 1.6, 1.0), 0, 0.08 * flail), "hips": Vector3.ZERO,
		"torso": Vector3(0.35, 0.1 * flail, 0), "head": Vector3(-0.25, -0.1 * flail, 0),
		"arm_l": Vector3(2.1 + 0.2 * flail, 0, -0.75), "fore_l": Vector3(0.45, 0, 0), "hand_l": Vector3(0.2, 0, 0),
		"arm_r": Vector3(1.9 - 0.2 * flail, 0, 0.8), "fore_r": Vector3(0.55, 0, 0), "hand_r": Vector3(0.2, 0, 0),
		"leg_l": Vector3(-0.25 + 0.15 * flail, 0, -0.12), "shin_l": Vector3(-0.85, 0, 0),
		"leg_r": Vector3(0.45 - 0.15 * flail, 0, 0.12), "shin_r": Vector3(-1.15, 0, 0),
		"_lift": Vector3.ZERO, "_scale": Vector3.ONE}


static func _jolt() -> Dictionary:
	return {"pivot": Vector3(0.95, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.45, 0, 0), "head": Vector3(0.3, 0, 0),
		"arm_l": Vector3(0.9, 0, -0.35), "fore_l": Vector3(1.4, 0, 0), "hand_l": Vector3(0.1, 0, 0),
		"arm_r": Vector3(0.8, 0, 0.35), "fore_r": Vector3(1.5, 0, 0), "hand_r": Vector3(0.1, 0, 0),
		"leg_l": Vector3(1.0, 0, -0.1), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(0.8, 0, 0.1), "shin_r": Vector3(-1.2, 0, 0),
		"_lift": Vector3.ZERO, "_scale": Vector3(1.05, 0.92, 1.05)}


## [pose, mask, lift].
static func pose(h, n: String, u: float) -> Array:
	var T: float = float(h._action.get("dur", 1.0))
	var s := u * T
	match n:
		"jug_air":
			# (off its feet: the blow's jolt, then the tumble)
			return [h._keys(u, [[0.0, {}], [0.08 / T, _jolt(), "out"], [0.22 / T, _air(s), "out"], [1.0, _air(s)]]), "full", Vector3.ZERO]
		"jug_hit":
			return [h._keys(u, [[0.0, _air(s)], [0.06 / T, _jolt(), "out"], [0.24 / T, _air(s)], [1.0, _air(s)]]), "full", Vector3.ZERO]
		"jug_held":
			# grabbed (GrabbedState, held): lifted a little, leaning back, both hands shoving at his chest, the feet
			# kicking for the ground
			var k := sin(float(h._t) * 11.0)
			return [{"pivot": Vector3(0.18, 0, 0.05 * k), "hips": Vector3.ZERO, "torso": Vector3(0.15, 0.1 * k, 0), "head": Vector3(-0.1, -0.1 * k, 0),
				"arm_l": Vector3(1.45 + 0.15 * k, 0.2, -0.25), "fore_l": Vector3(0.9, 0, 0), "hand_l": Vector3(-0.4, 0, 0),
				"arm_r": Vector3(1.45 - 0.15 * k, -0.2, 0.25), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(-0.4, 0, 0),
				"leg_l": Vector3(0.3 + 0.35 * k, 0, -0.1), "shin_l": Vector3(-0.7, 0, 0), "leg_r": Vector3(0.3 - 0.35 * k, 0, 0.1), "shin_r": Vector3(-0.7, 0, 0),
				"_lift": Vector3(0, 0.25, 0), "_scale": Vector3.ONE}, "full", Vector3.ZERO]
	push_error("JugglePoses: no pose for \"%s\"" % n)
	return [h._guard(), "full", Vector3.ZERO]
