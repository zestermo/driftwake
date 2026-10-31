class_name FruitPoses
## Key poses for the Driftfruit powers (1.27, FruitCastState plays them; TechniquePoses.pose hands every "df_" name
## here). Same conventions as humanoid.gd and the driftwake-animation skill: arm/leg x+ forward/up, shin x- the knee
## bent, *_l z- out left, *_r z+ out right, torso/pivot x- lean forward, torso y+ the right shoulder back; "_lift" the
## body down/up, "_scale" squash and stretch, "pivot" y a whole-body turn. Every main key sets every joint (the stance
## shows through a joint left out). Shonen, not cartoon: a wind-up you can read, a strike stretched along its line, a
## held follow-through, and the strike key at the u STRIKE gives (FruitCastState fires the power on it).

## The u of each pose's strike key (FruitCastState fires the power at STRIKE[pose] * dur).
const STRIKE := {"df_thrust": 0.38, "df_pull": 0.34, "df_slam": 0.5, "df_uppercut": 0.42, "df_roar": 0.34, "df_spin": 0.46,
	"df_stomp": 0.42, "df_sky": 0.46, "df_burst": 0.56, "df_dash": 0.3, "df_hug": 0.24, "df_self": 0.4, "df_leap": 0.36,
	"df_sweep": 0.4}


## A full body: every joint at rest, then `over` laid on it.
static func _b(over: Dictionary) -> Dictionary:
	var d := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3.ZERO, "head": Vector3.ZERO,
		"arm_l": Vector3.ZERO, "fore_l": Vector3.ZERO, "hand_l": Vector3.ZERO, "arm_r": Vector3.ZERO, "fore_r": Vector3.ZERO, "hand_r": Vector3.ZERO,
		"leg_l": Vector3.ZERO, "shin_l": Vector3.ZERO, "leg_r": Vector3.ZERO, "shin_r": Vector3.ZERO,
		"_lift": Vector3.ZERO, "_scale": Vector3.ONE, "_smear": Vector3.ZERO}
	d.merge(over, true)
	return d


## A shiver on a held key (the power straining in the body): small, fast, never on the strike.
static func _tremble(h, amt: float) -> Vector3:
	return Vector3(sin(h._t * 47.0), sin(h._t * 53.0 + 1.3), 0.0) * amt


## [pose, mask, lift] for a fruit power's action, or [] if `n` isn't one.
static func pose(h, n: String, u: float) -> Array:
	var g: Dictionary = h._guard()
	var lift := Vector3.ZERO
	match n:
		"df_thrust":
			# the palm drawn back by the hip, the body coiled away; then everything drives out along one line, the
			# rear arm flung back to balance it; held, the palm open at the foe
			var coil := _b({"hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.15, 0.75, 0.05), "head": Vector3(0.1, -0.6, 0),
				"arm_r": Vector3(-0.55, 0.2, 0.35), "fore_r": Vector3(1.9, 0, 0), "hand_r": Vector3(0.9, 0, 0),
				"arm_l": Vector3(1.2, 0.3, -0.25), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3(-0.6, 0, 0),
				"leg_l": Vector3(0.55, 0, -0.18), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(-0.35, 0, 0.18), "shin_r": Vector3(-0.9, 0, 0),
				"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.05, 0.93, 1.03)})
			var strike := _b({"hips": Vector3(0, -0.25, 0), "torso": Vector3(-0.45, -0.55, -0.05), "head": Vector3(0.3, 0.45, 0),
				"arm_r": Vector3(1.6, -0.15, 0.0), "fore_r": Vector3(0.0, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(-0.7, 0, -0.75), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3(0.3, 0, 0),
				"leg_l": Vector3(1.05, 0, -0.12), "shin_l": Vector3(-1.05, 0, 0), "leg_r": Vector3(-0.85, 0, 0.12), "shin_r": Vector3(-0.15, 0, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(0.95, 1.0, 1.1), "_smear": Vector3(0.6, 0, 0)})
			var hold: Dictionary = strike.merged({"_scale": Vector3.ONE, "_smear": Vector3.ZERO, "torso": Vector3(-0.38, -0.5, -0.05)}, true)
			return [h._keys(u, [[0.0, g], [0.26, coil, "out"], [0.32, coil], [0.38, strike, "out"], [0.46, hold], [0.78, hold], [1.0, g]]), "full", lift]
		"df_pull":
			# a hand flung out at the foe (fingers spread), a beat, then hauled back to the chest with the whole body
			# leaning away from it, the heels dug in
			var reach := _b({"hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.35, -0.45, 0), "head": Vector3(0.25, 0.35, 0),
				"arm_r": Vector3(1.55, -0.1, 0.05), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
				"arm_l": Vector3(-0.5, 0, -0.6), "fore_l": Vector3(0.4, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.12), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.6, 0, 0.12), "shin_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(0.96, 1.0, 1.08), "_smear": Vector3(0.4, 0, 0)})
			var haul := _b({"hips": Vector3(0, 0.3, 0), "torso": Vector3(0.35, 0.5, 0), "head": Vector3(-0.1, -0.35, 0),
				"arm_r": Vector3(0.2, 0.3, 0.45), "fore_r": Vector3(2.1, 0, 0), "hand_r": Vector3(0.7, 0, 0),
				"arm_l": Vector3(0.9, 0.2, -0.5), "fore_l": Vector3(1.0, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-0.2, 0, 0), "leg_r": Vector3(-0.2, 0, 0.15), "shin_r": Vector3(-1.2, 0, 0),
				"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.04, 0.95, 1.0)})
			return [h._keys(u, [[0.0, g], [0.22, reach, "out"], [0.34, reach], [0.48, haul, "out"], [0.8, haul], [1.0, g]]), "full", lift]
		"df_slam":
			# both fists up over the head, up on the toes and stretched tall; down with everything, a deep squat, the
			# fists driven into the ground; held low a moment, then up
			var up := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(0.3, 0, 0), "head": Vector3(0.4, 0, 0),
				"arm_l": Vector3(3.0, 0, -0.25), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3(0.3, 0, 0),
				"arm_r": Vector3(3.0, 0, 0.25), "fore_r": Vector3(0.5, 0, 0), "hand_r": Vector3(0.3, 0, 0),
				"leg_l": Vector3(0.1, 0, -0.08), "shin_l": Vector3(-0.1, 0, 0), "leg_r": Vector3(-0.1, 0, 0.08), "shin_r": Vector3(-0.1, 0, 0),
				"_lift": Vector3(0, 0.12, 0), "_scale": Vector3(0.94, 1.1, 0.94)})
			var slam := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(-1.0, 0, 0), "head": Vector3(-0.25, 0, 0),
				"arm_l": Vector3(0.25, 0, -0.2), "fore_l": Vector3(0.15, 0, 0), "hand_l": Vector3(-0.2, 0, 0),
				"arm_r": Vector3(0.25, 0, 0.2), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-0.2, 0, 0),
				"leg_l": Vector3(1.5, 0, -0.35), "shin_l": Vector3(-2.1, 0, 0), "leg_r": Vector3(-0.35, 0, 0.35), "shin_r": Vector3(-1.5, 0, 0),
				"_lift": Vector3(0, -0.48, 0), "_scale": Vector3(1.1, 0.88, 1.1)})
			var low: Dictionary = slam.merged({"_scale": Vector3(1.03, 0.97, 1.03), "torso": Vector3(-0.85, 0, 0)}, true)
			return [h._keys(u, [[0.0, g], [0.3, up, "out"], [0.42, up], [0.5, slam, "in"], [0.56, low], [0.82, low], [1.0, g]]), "full", lift]
		"df_uppercut":
			# sunk low, the fist cocked by the knee and the shoulder dropped; then the whole body rises behind it, the
			# fist straight up, up on the rear toe
			var sink := _b({"hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.55, 0.6, 0.1), "head": Vector3(0.3, -0.4, 0),
				"arm_r": Vector3(-0.3, 0.1, 0.3), "fore_r": Vector3(1.8, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"arm_l": Vector3(1.0, 0.3, -0.3), "fore_l": Vector3(1.4, 0, 0),
				"leg_l": Vector3(1.0, 0, -0.2), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(-0.2, 0, 0.2), "shin_r": Vector3(-1.4, 0, 0),
				"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.06, 0.9, 1.06)})
			var rise := _b({"hips": Vector3(0, -0.35, 0), "torso": Vector3(0.35, -0.45, -0.1), "head": Vector3(0.45, 0.3, 0),
				"arm_r": Vector3(3.05, 0.0, 0.2), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-0.3, 0, 0),
				"arm_l": Vector3(-0.4, 0, -0.8), "fore_l": Vector3(0.6, 0, 0),
				"leg_l": Vector3(0.3, 0, -0.1), "shin_l": Vector3(-0.2, 0, 0), "leg_r": Vector3(-0.7, 0, 0.1), "shin_r": Vector3(-0.1, 0, 0),
				"_lift": Vector3(0, 0.2, 0), "_scale": Vector3(0.93, 1.12, 0.93), "_smear": Vector3(0.5, 0, 0)})
			var top: Dictionary = rise.merged({"_scale": Vector3.ONE, "_smear": Vector3.ZERO, "_lift": Vector3(0, 0.1, 0)}, true)
			return [h._keys(u, [[0.0, g], [0.28, sink, "out"], [0.36, sink], [0.42, rise, "out"], [0.5, top], [0.78, top], [1.0, g]]), "full", lift]
		"df_roar":
			# hunched in, the arms crossed tight over the chest, the head down; then thrown open, the chest out, the
			# head back, the arms flung wide behind, the stance wide, shaking with it
			var hunch := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(-0.6, 0, 0), "head": Vector3(-0.45, 0, 0),
				"arm_l": Vector3(1.3, 0, 0.75), "fore_l": Vector3(1.9, 0, 0), "hand_l": Vector3(0.3, 0, 0),
				"arm_r": Vector3(1.3, 0, -0.75), "fore_r": Vector3(1.9, 0, 0), "hand_r": Vector3(0.3, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.25), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(0.6, 0, 0.25), "shin_r": Vector3(-1.2, 0, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.06, 0.9, 1.06)})
			var open := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(0.45, 0, 0), "head": Vector3(0.6, 0, 0),
				"arm_l": Vector3(0.5, 0, -1.55), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3(-0.5, 0, 0),
				"arm_r": Vector3(0.5, 0, 1.55), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(-0.5, 0, 0),
				"leg_l": Vector3(0.35, 0, -0.45), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(0.35, 0, 0.45), "shin_r": Vector3(-0.6, 0, 0),
				"_lift": Vector3(0, -0.15, 0), "_scale": Vector3(1.08, 1.04, 1.08)})
			var hold: Dictionary = open.merged({"_scale": Vector3(1.03, 1.0, 1.03), "torso": Vector3(0.4, 0, 0) + _tremble(h, 0.04),
				"head": Vector3(0.55, 0, 0) + _tremble(h, 0.06)}, true)
			return [h._keys(u, [[0.0, g], [0.24, hunch, "out"], [0.3, hunch], [0.34, open, "out"], [0.4, hold], [0.82, hold], [1.0, g]]), "full", lift]
		"df_spin":
			# wound right round (the arms in, the body coiled), then unwound in one full turn with the arms flung out
			# flat, the power whipping round; settled facing front again
			var wind := _b({"hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.2, 0.9, 0.05), "head": Vector3(0.1, -0.7, 0),
				"arm_l": Vector3(1.1, 0, 0.6), "fore_l": Vector3(1.6, 0, 0), "arm_r": Vector3(0.3, 0, 0.2), "fore_r": Vector3(1.8, 0, 0),
				"leg_l": Vector3(0.5, 0, -0.2), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.3, 0, 0.2), "shin_r": Vector3(-1.0, 0, 0),
				"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.05, 0.92, 1.05)})
			var flung := _b({"hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.1, -0.35, 0), "head": Vector3(0.05, 0.2, 0),
				"arm_l": Vector3(0.2, 0, -1.6), "fore_l": Vector3(0.05, 0, 0), "hand_l": Vector3(-0.4, 0, 0),
				"arm_r": Vector3(0.2, 0, 1.6), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-0.4, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.35), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.2, 0, 0.35), "shin_r": Vector3(-0.8, 0, 0),
				"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.1, 0.97, 1.1)})
			var settle: Dictionary = flung.merged({"_scale": Vector3.ONE, "arm_l": Vector3(0.4, 0, -1.2), "arm_r": Vector3(0.4, 0, 1.2)}, true)
			var pose: Dictionary = h._keys(u, [[0.0, g], [0.3, wind, "out"], [0.36, wind], [0.46, flung, "linear"], [0.6, settle, "out"], [0.82, settle], [1.0, g]])
			pose["pivot"] = (pose.get("pivot", Vector3.ZERO) as Vector3) + Vector3(0, TAU * smoothstep(0.34, 0.6, u), 0)
			return [pose, "full", lift]
		"df_stomp":
			# the knee driven high, the arms up for balance and the body leaning back over it; then the foot down
			# with everything on it, a crouch, the fists pressed down
			var knee := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(0.25, 0, 0), "head": Vector3(0.2, 0, 0),
				"arm_l": Vector3(1.6, 0, -0.9), "fore_l": Vector3(0.8, 0, 0), "arm_r": Vector3(1.6, 0, 0.9), "fore_r": Vector3(0.8, 0, 0),
				"leg_l": Vector3(-0.05, 0, -0.08), "shin_l": Vector3(-0.15, 0, 0), "leg_r": Vector3(1.85, 0, 0.1), "shin_r": Vector3(-2.0, 0, 0),
				"_lift": Vector3(0, 0.08, 0), "_scale": Vector3(0.96, 1.06, 0.96)})
			var down := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(-0.7, 0, 0), "head": Vector3(-0.1, 0, 0),
				"arm_l": Vector3(0.1, 0, -0.5), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3(-0.5, 0, 0),
				"arm_r": Vector3(0.1, 0, 0.5), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(-0.5, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.35), "shin_l": Vector3(-1.7, 0, 0), "leg_r": Vector3(0.8, 0, 0.35), "shin_r": Vector3(-1.5, 0, 0),
				"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.1, 0.88, 1.1)})
			var held: Dictionary = down.merged({"_scale": Vector3(1.03, 0.97, 1.03)}, true)
			return [h._keys(u, [[0.0, g], [0.3, knee, "out"], [0.38, knee], [0.42, down, "in"], [0.48, held], [0.8, held], [1.0, g]]), "full", lift]
		"df_sky":
			# crouched with the hand at the chest, gathering; then one arm straight up at the sky, the body stretched
			# after it, the head thrown back to look; the other arm out wide
			var crouch := _b({"hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.45, 0.25, 0), "head": Vector3(-0.3, 0, 0),
				"arm_r": Vector3(0.9, 0.3, -0.3), "fore_r": Vector3(2.2, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"arm_l": Vector3(0.3, 0, -0.5), "fore_l": Vector3(0.9, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.2), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(0.2, 0, 0.2), "shin_r": Vector3(-1.3, 0, 0),
				"_lift": Vector3(0, -0.35, 0), "_scale": Vector3(1.05, 0.92, 1.05)})
			var call := _b({"hips": Vector3(0, -0.1, 0), "torso": Vector3(0.35, -0.15, 0), "head": Vector3(0.75, 0, 0),
				"arm_r": Vector3(3.1, 0.0, 0.1), "fore_r": Vector3(0.0, 0, 0), "hand_r": Vector3(-0.2, 0, 0),
				"arm_l": Vector3(0.6, 0, -1.3), "fore_l": Vector3(0.2, 0, 0), "hand_l": Vector3(-0.6, 0, 0),
				"leg_l": Vector3(0.2, 0, -0.2), "shin_l": Vector3(-0.15, 0, 0), "leg_r": Vector3(-0.4, 0, 0.2), "shin_r": Vector3(-0.1, 0, 0),
				"_lift": Vector3(0, 0.1, 0), "_scale": Vector3(0.94, 1.1, 0.94), "_smear": Vector3(0.3, 0, 0)})
			var hold: Dictionary = call.merged({"_scale": Vector3.ONE, "_smear": Vector3.ZERO, "arm_r": Vector3(3.05, 0, 0.1) + _tremble(h, 0.03)}, true)
			return [h._keys(u, [[0.0, g], [0.3, crouch, "out"], [0.4, crouch], [0.46, call, "out"], [0.54, hold], [0.82, hold], [1.0, g]]), "full", lift]
		"df_burst":
			# the ultimates and awakenings: folded down small (the arms crossed, the head down, shaking with what's
			# building), then burst open, arms up and out, the chest to the sky, up on the toes, and held there
			var fold := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(-0.75, 0, 0) + _tremble(h, 0.03), "head": Vector3(-0.5, 0, 0),
				"arm_l": Vector3(1.0, 0, 0.85), "fore_l": Vector3(2.1, 0, 0), "hand_l": Vector3(0.4, 0, 0),
				"arm_r": Vector3(1.0, 0, -0.85), "fore_r": Vector3(2.1, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"leg_l": Vector3(1.0, 0, -0.3), "shin_l": Vector3(-1.8, 0, 0), "leg_r": Vector3(0.9, 0, 0.3), "shin_r": Vector3(-1.7, 0, 0),
				"_lift": Vector3(0, -0.5, 0), "_scale": Vector3(1.08, 0.86, 1.08)})
			var open := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(0.45, 0, 0), "head": Vector3(0.7, 0, 0),
				"arm_l": Vector3(2.4, 0, -0.95), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(-0.6, 0, 0),
				"arm_r": Vector3(2.4, 0, 0.95), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-0.6, 0, 0),
				"leg_l": Vector3(0.15, 0, -0.4), "shin_l": Vector3(-0.1, 0, 0), "leg_r": Vector3(0.15, 0, 0.4), "shin_r": Vector3(-0.1, 0, 0),
				"_lift": Vector3(0, 0.18, 0), "_scale": Vector3(0.93, 1.14, 0.93)})
			var hold: Dictionary = open.merged({"_scale": Vector3(1.0, 1.02, 1.0), "torso": Vector3(0.4, 0, 0) + _tremble(h, 0.025),
				"_lift": Vector3(0, 0.08, 0)}, true)
			return [h._keys(u, [[0.0, g], [0.32, fold, "out"], [0.5, fold], [0.56, open, "out"], [0.64, hold], [0.86, hold], [1.0, g]]), "full", lift]
		"df_dash":
			# a dip forward, the arms swept back like a sprinter off the block; the body stretched along the dash
			var dip := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(-0.7, 0, 0), "head": Vector3(0.45, 0, 0),
				"arm_l": Vector3(-0.9, 0, -0.35), "fore_l": Vector3(0.5, 0, 0), "arm_r": Vector3(-0.9, 0, 0.35), "fore_r": Vector3(0.5, 0, 0),
				"leg_l": Vector3(1.1, 0, -0.1), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(-0.5, 0, 0.1), "shin_r": Vector3(-0.8, 0, 0),
				"_lift": Vector3(0, -0.35, 0), "_scale": Vector3(1.05, 0.92, 1.0)})
			var go := dip.merged({"torso": Vector3(-0.85, 0, 0), "arm_l": Vector3(-1.3, 0, -0.3), "arm_r": Vector3(-1.3, 0, 0.3),
				"leg_l": Vector3(0.7, 0, -0.1), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.9, 0, 0.1), "shin_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.25, 0), "_scale": Vector3(0.92, 0.98, 1.16), "_smear": Vector3(0.7, 0, 0)}, true)
			return [h._keys(u, [[0.0, g], [0.2, dip, "out"], [0.3, go, "out"], [0.62, go], [1.0, g]]), "full", lift]
		"df_hug":
			# both arms out wide and forward to take hold; heaved up over the head, back arched; then flung forward and
			# down with the whole body over it
			var take := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(-0.45, 0, 0), "head": Vector3(0.3, 0, 0),
				"arm_l": Vector3(1.35, 0, -0.7), "fore_l": Vector3(0.6, 0, 0), "arm_r": Vector3(1.35, 0, 0.7), "fore_r": Vector3(0.6, 0, 0),
				"leg_l": Vector3(0.8, 0, -0.25), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.3, 0, 0.25), "shin_r": Vector3(-0.8, 0, 0),
				"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.05, 0.95, 1.05)})
			var heave := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(0.45, 0, 0), "head": Vector3(0.5, 0, 0),
				"arm_l": Vector3(2.9, 0, -0.35), "fore_l": Vector3(0.9, 0, 0), "arm_r": Vector3(2.9, 0, 0.35), "fore_r": Vector3(0.9, 0, 0),
				"leg_l": Vector3(0.35, 0, -0.3), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(0.0, 0, 0.3), "shin_r": Vector3(-0.4, 0, 0),
				"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.95, 1.08, 0.95)})
			var throw := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(-0.9, 0, 0), "head": Vector3(0.1, 0, 0),
				"arm_l": Vector3(0.8, 0, -0.3), "fore_l": Vector3(0.1, 0, 0), "arm_r": Vector3(0.8, 0, 0.3), "fore_r": Vector3(0.1, 0, 0),
				"leg_l": Vector3(1.1, 0, -0.25), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(-0.7, 0, 0.25), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.32, 0), "_scale": Vector3(0.95, 0.98, 1.12), "_smear": Vector3(0.5, 0, 0)})
			var after: Dictionary = throw.merged({"_scale": Vector3.ONE, "_smear": Vector3.ZERO}, true)
			return [h._keys(u, [[0.0, g], [0.18, take, "out"], [0.24, take], [0.5, heave, "out"], [0.62, heave], [0.72, throw, "in"], [0.78, after], [0.9, after], [1.0, g]]), "full", lift]
		"df_self":
			# the hands brought together at the chest, the head bowed, the knees soft; then opened out low, palms
			# out, the chest lifting with what's been called up
			var clasp := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(-0.3, 0, 0), "head": Vector3(-0.4, 0, 0),
				"arm_l": Vector3(1.1, 0, 0.55), "fore_l": Vector3(1.9, 0, 0), "hand_l": Vector3(0.2, 0, 0),
				"arm_r": Vector3(1.1, 0, -0.55), "fore_r": Vector3(1.9, 0, 0), "hand_r": Vector3(0.2, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.18), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.3, 0, 0.18), "shin_r": Vector3(-0.8, 0, 0),
				"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.04, 0.94, 1.04)})
			var open := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(0.2, 0, 0), "head": Vector3(0.25, 0, 0),
				"arm_l": Vector3(0.6, 0, -0.9), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3(-0.9, 0, 0),
				"arm_r": Vector3(0.6, 0, 0.9), "fore_r": Vector3(0.3, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
				"leg_l": Vector3(0.25, 0, -0.25), "shin_l": Vector3(-0.35, 0, 0), "leg_r": Vector3(0.1, 0, 0.25), "shin_r": Vector3(-0.35, 0, 0),
				"_lift": Vector3(0, -0.05, 0), "_scale": Vector3(1.04, 1.05, 1.04)})
			var held: Dictionary = open.merged({"_scale": Vector3.ONE}, true)
			return [h._keys(u, [[0.0, g], [0.28, clasp, "out"], [0.36, clasp], [0.4, open, "out"], [0.5, held], [0.8, held], [1.0, g]]), "full", lift]
		"df_leap":
			# down into a deep crouch, the arms swung back; then everything swung up and forward as the legs fire
			var load := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(-0.7, 0, 0), "head": Vector3(0.35, 0, 0),
				"arm_l": Vector3(-1.1, 0, -0.3), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(-1.1, 0, 0.3), "fore_r": Vector3(0.3, 0, 0),
				"leg_l": Vector3(1.4, 0, -0.2), "shin_l": Vector3(-2.1, 0, 0), "leg_r": Vector3(1.2, 0, 0.2), "shin_r": Vector3(-2.0, 0, 0),
				"_lift": Vector3(0, -0.55, 0), "_scale": Vector3(1.1, 0.85, 1.1)})
			var fire := _b({"hips": Vector3(0, 0, 0), "torso": Vector3(0.1, 0, 0), "head": Vector3(0.3, 0, 0),
				"arm_l": Vector3(2.6, 0, -0.3), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(2.6, 0, 0.3), "fore_r": Vector3(0.3, 0, 0),
				"leg_l": Vector3(-0.1, 0, -0.1), "shin_l": Vector3(-0.1, 0, 0), "leg_r": Vector3(-0.5, 0, 0.1), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, 0.05, 0), "_scale": Vector3(0.92, 1.14, 0.92)})
			var tuck := fire.merged({"leg_l": Vector3(1.2, 0, -0.1), "shin_l": Vector3(-1.8, 0, 0), "leg_r": Vector3(0.9, 0, 0.1), "shin_r": Vector3(-1.7, 0, 0),
				"torso": Vector3(-0.2, 0, 0), "_scale": Vector3.ONE}, true)
			return [h._keys(u, [[0.0, g], [0.28, load, "out"], [0.34, load], [0.38, fire, "out"], [0.55, tuck, "out"], [1.0, tuck]]), "full", lift]
		"df_sweep":
			# a claw or a hand swept low and wide across the front, the body dropping into it from the other side
			var cock := _b({"hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.3, 0.8, -0.1), "head": Vector3(0.2, -0.6, 0),
				"arm_r": Vector3(0.9, 0.0, 1.2), "fore_r": Vector3(0.6, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(0.9, 0.2, -0.5), "fore_l": Vector3(1.2, 0, 0),
				"leg_l": Vector3(0.7, 0, -0.25), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.3, 0, 0.25), "shin_r": Vector3(-1.0, 0, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.04, 0.94, 1.04)})
			var cut := _b({"hips": Vector3(0, -0.35, 0), "torso": Vector3(-0.65, -0.75, 0.15), "head": Vector3(0.3, 0.5, 0),
				"arm_r": Vector3(0.6, 0.0, -0.9), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
				"arm_l": Vector3(-0.4, 0, -1.0), "fore_l": Vector3(0.5, 0, 0),
				"leg_l": Vector3(1.2, 0, -0.3), "shin_l": Vector3(-1.6, 0, 0), "leg_r": Vector3(-0.6, 0, 0.3), "shin_r": Vector3(-0.6, 0, 0),
				"_lift": Vector3(0, -0.45, 0), "_scale": Vector3(1.08, 0.94, 1.0), "_smear": Vector3(0.7, 0, 0)})
			var held: Dictionary = cut.merged({"_scale": Vector3.ONE, "_smear": Vector3.ZERO}, true)
			return [h._keys(u, [[0.0, g], [0.3, cock, "out"], [0.36, cock], [0.4, cut, "out"], [0.48, held], [0.78, held], [1.0, g]]), "full", lift]
	return []
