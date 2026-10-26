class_name CrewPoses
## Key poses for the crew techniques (CrewTechniqueState), every name "ct_". Humanoid._action_pose sends them here.
## Same conventions as humanoid.gd (driftwake-animation): every joint keyed on the main keys, start and end on the
## guard, squash on the gather and stretch along the motion on the strike.


## [pose, mask, lift] for a crew technique action.
static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	var g: Dictionary = h._guard()
	var T: float = float(h._action.get("dur", 1.0))
	match n:
		"ct_kick_launch":
			# Skyward Kick: the right foot raised flat ahead as a step (the crewmate stands on it), a dip as their
			# weight comes on, then the leg whipped up overhead (at KICK_AT), held, and down to the guard
			var k := 0.42 / T
			var brace := {"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, 0.1, 0), "torso": Vector3(0.12, -0.1, 0), "head": Vector3(-0.08, 0.1, 0),
				"leg_r": Vector3(1.45, 0, 0.12), "shin_r": Vector3(-1.35, 0, 0), "leg_l": Vector3(-0.05, 0, -0.1), "shin_l": Vector3(-0.35, 0, 0),
				"arm_l": Vector3(0.5, 0, -1.0), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(0.3, 0, 1.05), "fore_r": Vector3(0.5, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, -0.06, 0), "_scale": Vector3.ONE}
			var dip := brace.merged({"torso": Vector3(-0.15, -0.15, 0), "head": Vector3(0.12, 0.12, 0),
				"leg_r": Vector3(1.1, 0, 0.12), "shin_r": Vector3(-1.6, 0, 0), "shin_l": Vector3(-0.7, 0, 0),
				"arm_l": Vector3(0.2, 0, -1.2), "arm_r": Vector3(0.1, 0, 1.2),
				"_lift": Vector3(0, -0.18, 0), "_scale": Vector3(1.04, 0.93, 1.02)}, true)
			var kick := {"pivot": Vector3(0.12, 0, 0), "hips": Vector3(0, -0.15, 0), "torso": Vector3(0.38, 0.15, 0), "head": Vector3(-0.25, -0.1, 0),
				"leg_r": Vector3(2.55, 0, 0.1), "shin_r": Vector3(-0.06, 0, 0), "leg_l": Vector3(-0.1, 0, -0.08), "shin_l": Vector3(-0.15, 0, 0),
				"arm_l": Vector3(-0.45, 0, -0.75), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(-0.5, 0, 0.7), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, 0.06, 0), "_scale": Vector3(0.96, 1.07, 0.98)}
			var held := kick.merged({"leg_r": Vector3(2.35, 0, 0.12), "shin_r": Vector3(-0.2, 0, 0), "_scale": Vector3.ONE}, true)
			return [h._keys(u, [[0.0, g], [0.14, brace, "out"], [k - 0.1, brace], [k - 0.03, dip], [k + 0.03, kick, "out"],
				[0.78, held], [1.0, g]]), "full", lift]
		"ct_perch":
			# crouched on a crewmate's raised foot (or blade, or pole), arms out for balance, waiting for the throw
			var perch := {"pivot": Vector3(-0.15, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.35, 0, 0), "head": Vector3(0.28, 0, 0),
				"leg_l": Vector3(1.15, 0, -0.18), "shin_l": Vector3(-1.95, 0, 0), "leg_r": Vector3(1.0, 0, 0.18), "shin_r": Vector3(-1.8, 0, 0),
				"arm_l": Vector3(0.8, 0, -0.75), "fore_l": Vector3(0.6, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(0.8, 0, 0.75), "fore_r": Vector3(0.6, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.03, 0.95, 1.02)}
			return [h._keys(u, [[0.0, {}], [1.0, perch]]), "full", lift]
		"ct_launched":
			# flung skyward: stretched out along the throw, then tucked tight for the flight
			var stretch := {"pivot": Vector3(0.1, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.15, 0, 0), "head": Vector3(-0.1, 0, 0),
				"leg_l": Vector3(-0.15, 0, -0.06), "shin_l": Vector3(-0.25, 0, 0), "leg_r": Vector3(0.1, 0, 0.06), "shin_r": Vector3(-0.35, 0, 0),
				"arm_l": Vector3(2.6, 0, -0.25), "fore_l": Vector3(0.25, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(2.6, 0, 0.25), "fore_r": Vector3(0.25, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3.ZERO, "_scale": Vector3(0.95, 1.08, 0.95)}
			var tuck := {"pivot": Vector3(-0.2, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.5, 0, 0), "head": Vector3(0.3, 0, 0),
				"leg_l": Vector3(1.55, 0, -0.15), "shin_l": Vector3(-2.1, 0, 0), "leg_r": Vector3(1.45, 0, 0.15), "shin_r": Vector3(-2.0, 0, 0),
				"arm_l": Vector3(1.0, 0, -0.35), "fore_l": Vector3(1.4, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(1.0, 0, 0.35), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, 0.1, 0), "_scale": Vector3(1.03, 0.96, 1.03)}
			return [h._keys(u, [[0.0, {}], [0.15, stretch, "out"], [0.4, stretch], [0.7, tuck], [1.0, {}]]), "full", lift]
		"ct_wall_kick":
			# Wall Kick: down into a crouch, arms swung back, then sprung up with the arms flung overhead
			var crouch := {"pivot": Vector3(-0.15, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.45, 0, 0), "head": Vector3(0.35, 0, 0),
				"leg_l": Vector3(1.05, 0, -0.15), "shin_l": Vector3(-1.7, 0, 0), "leg_r": Vector3(0.95, 0, 0.15), "shin_r": Vector3(-1.6, 0, 0),
				"arm_l": Vector3(-0.7, 0, -0.35), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(-0.7, 0, 0.35), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, -0.35, 0), "_scale": Vector3(1.05, 0.92, 1.03)}
			var spring := {"pivot": Vector3(0.1, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.15, 0, 0), "head": Vector3(-0.15, 0, 0),
				"leg_l": Vector3(-0.2, 0, -0.06), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(1.7, 0, 0.1), "shin_r": Vector3(-0.2, 0, 0),
				"arm_l": Vector3(2.5, 0, -0.3), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(2.5, 0, 0.3), "fore_r": Vector3(0.3, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, 0.08, 0), "_scale": Vector3(0.96, 1.07, 0.97)}
			return [h._keys(u, [[0.0, g], [0.22, crouch, "out"], [0.28, crouch], [0.36, spring, "out"], [0.6, spring], [1.0, {}]]), "full", lift]
	return []
