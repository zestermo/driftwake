class_name FishPoses
extends RefCounted
## Fishing's body ("rod_*", FishState plays them; FishRod holds the rod and puts both hands on it by IK after
## this pose, in time with it, so the arms here only seed the blend). A fisher's stance: the left foot
## forward, the rod's butt at the right hip, the eyes on the bobber.
##   rod_cast   (played, CAST_LEN) the rod back over the right shoulder, the weight back, a snap forward onto
##              the front foot (the bobber flies at Fishing.RELEASE), the follow-through low, settle
##   rod_wait   (held) still, breathing, watching the float
##   rod_reel   (played, REEL_LEN) the strike up and back, reeling in hard (the left hand on the crank), the lift
##   rod_strike (played, STRIKE_LEN) a strike at nothing, a quick reel in
##   rod_land   (played, LAND_LEN) the rod high, the catch swung in to the left hand and held up to look at

const STANCE := {"pivot": Vector3.ZERO, "hips": Vector3(0, -0.14, 0), "torso": Vector3(-0.05, 0.12, 0), "head": Vector3(-0.2, -0.04, 0),
	"leg_l": Vector3(0.24, 0, -0.12), "shin_l": Vector3(-0.24, 0, 0), "leg_r": Vector3(-0.15, 0, 0.13), "shin_r": Vector3(-0.2, 0, 0),
	"arm_r": Vector3(0.6, 0, 0.25), "fore_r": Vector3(1.3, 0, 0), "hand_r": Vector3(-0.3, 0, 0),
	"arm_l": Vector3(0.5, 0.4, -0.15), "fore_l": Vector3(1.2, 0, 0), "hand_l": Vector3(-0.2, 0, 0)}
## The cast: loaded back (the rod over the shoulder, the weight on the back foot), the snap onto the front
## foot, the follow-through leaning after the line.
const CAST_BACK := {"hips": Vector3(0, -0.32, 0), "torso": Vector3(0.12, -0.34, 0.05), "head": Vector3(-0.02, 0.3, 0),
	"leg_l": Vector3(0.3, 0, -0.12), "shin_l": Vector3(-0.1, 0, 0), "leg_r": Vector3(-0.1, 0, 0.13), "shin_r": Vector3(-0.4, 0, 0),
	"arm_r": Vector3(1.9, 0, 0.3), "fore_r": Vector3(1.9, 0, 0), "arm_l": Vector3(1.2, 0.5, -0.1), "fore_l": Vector3(1.5, 0, 0),
	"_lift": Vector3(0, -0.04, 0)}
const CAST_SNAP := {"hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.22, 0.14, 0), "head": Vector3(-0.08, -0.1, 0),
	"leg_l": Vector3(0.36, 0, -0.12), "shin_l": Vector3(-0.52, 0, 0), "leg_r": Vector3(-0.3, 0, 0.13), "shin_r": Vector3(-0.1, 0, 0),
	"arm_r": Vector3(1.4, 0, 0.25), "fore_r": Vector3(0.9, 0, 0), "arm_l": Vector3(0.9, 0.4, -0.1), "fore_l": Vector3(1.2, 0, 0),
	"_lift": Vector3(0, -0.07, 0)}
const CAST_FOLLOW := {"hips": Vector3(0, 0.02, 0), "torso": Vector3(-0.27, 0.08, 0), "head": Vector3(-0.12, -0.06, 0),
	"leg_l": Vector3(0.34, 0, -0.12), "shin_l": Vector3(-0.46, 0, 0), "leg_r": Vector3(-0.26, 0, 0.13), "shin_r": Vector3(-0.12, 0, 0),
	"arm_r": Vector3(0.9, 0, 0.25), "fore_r": Vector3(0.8, 0, 0), "_lift": Vector3(0, -0.06, 0)}
## The reel: the strike leaning back, then hunched over the reel, the head down to the line.
const STRIKE := {"hips": Vector3(0, -0.2, 0), "torso": Vector3(0.16, 0.0, 0), "head": Vector3(-0.05, 0.05, 0),
	"leg_l": Vector3(0.3, 0, -0.12), "shin_l": Vector3(-0.12, 0, 0), "leg_r": Vector3(-0.08, 0, 0.13), "shin_r": Vector3(-0.38, 0, 0),
	"arm_r": Vector3(1.4, 0, 0.3), "fore_r": Vector3(1.6, 0, 0), "_lift": Vector3(0, -0.05, 0)}
const REELING := {"hips": Vector3(0, -0.16, 0), "torso": Vector3(-0.02, 0.16, 0), "head": Vector3(-0.28, -0.06, 0),
	"leg_l": Vector3(0.26, 0, -0.12), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(-0.14, 0, 0.13), "shin_r": Vector3(-0.3, 0, 0),
	"arm_r": Vector3(1.0, 0, 0.3), "fore_r": Vector3(1.5, 0, 0), "arm_l": Vector3(0.8, 0.3, -0.2), "fore_l": Vector3(1.6, 0, 0),
	"_lift": Vector3(0, -0.06, 0)}
const LIFT := {"hips": Vector3(0, -0.22, 0), "torso": Vector3(0.12, 0.08, 0), "head": Vector3(0.1, 0.0, 0),
	"leg_l": Vector3(0.28, 0, -0.12), "shin_l": Vector3(-0.14, 0, 0), "leg_r": Vector3(-0.1, 0, 0.13), "shin_r": Vector3(-0.32, 0, 0),
	"arm_r": Vector3(1.5, 0, 0.3), "fore_r": Vector3(1.5, 0, 0), "_lift": Vector3(0, -0.03, 0)}
## Landed: turned to the catch in the left hand, held up to look at.
const LOOK := {"hips": Vector3(0, -0.05, 0), "torso": Vector3(0.04, 0.3, 0), "head": Vector3(-0.08, 0.42, 0),
	"leg_l": Vector3(0.2, 0, -0.12), "shin_l": Vector3(-0.18, 0, 0), "leg_r": Vector3(-0.12, 0, 0.13), "shin_r": Vector3(-0.16, 0, 0),
	"arm_r": Vector3(0.9, 0, 0.3), "fore_r": Vector3(1.0, 0, 0), "arm_l": Vector3(1.1, 0.4, -0.3), "fore_l": Vector3(1.7, 0, 0),
	"_lift": Vector3(0, -0.02, 0)}


static func pose(h, n: String, u: float) -> Array:
	var t: float = float(h._action["t"])
	var st := STANCE.duplicate()
	st["torso"] = (STANCE["torso"] as Vector3) + Vector3(0.015 * sin(t * 1.6), 0, 0)
	match n:
		"rod_cast":
			return [h._keys(u, [[0.0, {}], [0.08, st], [0.28, CAST_BACK], [0.4, CAST_BACK], [0.52, CAST_SNAP, "out"], [0.68, CAST_FOLLOW], [1.0, st]]), "full", Vector3.ZERO]
		"rod_wait":
			return [h._keys(minf(t / 0.35, 1.0), [[0.0, {}], [1.0, st]]), "full", Vector3.ZERO]
		"rod_reel":
			var pump := REELING.duplicate()
			pump["torso"] = (REELING["torso"] as Vector3) + Vector3(0.05 * sin(t * 9.0), 0, 0)
			pump["head"] = (REELING["head"] as Vector3) + Vector3(0.03 * sin(t * 9.0 + 1.0), 0, 0)
			return [h._keys(u, [[0.0, st], [0.1, STRIKE, "out"], [0.22, pump], [0.8, pump], [1.0, LIFT]]), "full", Vector3.ZERO]
		"rod_strike":
			var pump := REELING.duplicate()
			pump["torso"] = (REELING["torso"] as Vector3) + Vector3(0.04 * sin(t * 12.0), 0, 0)
			return [h._keys(u, [[0.0, st], [0.18, STRIKE, "out"], [0.4, pump], [0.8, pump], [1.0, st]]), "full", Vector3.ZERO]
		"rod_land":
			return [h._keys(u, [[0.0, LIFT], [0.3, LIFT], [0.45, LOOK, "out"], [0.85, LOOK], [1.0, st]]), "full", Vector3.ZERO]
	return []
