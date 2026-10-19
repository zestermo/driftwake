class_name DowntimePoses
extends RefCounted
## Sailing downtime's loops ("dt_*", held by DowntimeState; Downtime.pose_of picks one). Each loops on the
## action's own clock and eases in from whatever the body was doing over the hold's blend.
##   dt_train_blade  suburi: the blade raised overhead in both hands, a stepping vertical cut, back to guard
##   dt_train_fist   shadowboxing: a jab, a cross, bouncing on the toes
##   dt_train_gun    a dry-fire drill: aim, a kick, the next mark across the bow
##   dt_startle      (played) roused: the head snaps up and round, the hands come up

## Seconds to ease into a loop (the hold's blend: ActionSpecs len).
const BLEND := 0.4
const TRAIN_LOOP := 2.2
const FIST_LOOP := 2.0
const GUN_LOOP := 3.0

const BLADE_READY := {"pivot": Vector3.ZERO, "hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.05, 0.1, 0), "head": Vector3(0.05, -0.1, 0),
	"arm_r": Vector3(0.8, 0.35, -0.05), "fore_r": Vector3(0.8, 0, 0), "hand_r": Vector3(-1.0, 0, 0),
	"arm_l": Vector3(0.75, -0.3, 0.05), "fore_l": Vector3(1.1, 0, 0), "hand_l": Vector3(-1.0, 0, 0),
	"leg_l": Vector3(0.22, 0, -0.1), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(-0.18, 0, 0.1), "shin_r": Vector3(-0.28, 0, 0)}
## Raised: the hands over the brow, the blade up and back (arm + fore + 1.57 + hand ~ 3.9 from straight down).
const BLADE_UP := {"pivot": Vector3.ZERO, "hips": Vector3(0, 0.05, 0), "torso": Vector3(0.08, 0.05, 0), "head": Vector3(0.0, -0.05, 0),
	"arm_r": Vector3(2.65, 0.3, -0.2), "fore_r": Vector3(0.95, 0, 0), "hand_r": Vector3(-1.25, 0, 0),
	"arm_l": Vector3(2.6, -0.3, 0.05), "fore_l": Vector3(1.1, 0, 0), "hand_l": Vector3(-1.25, 0, 0),
	"leg_l": Vector3(0.1, 0, -0.1), "shin_l": Vector3(-0.12, 0, 0), "leg_r": Vector3(-0.1, 0, 0.1), "shin_r": Vector3(-0.12, 0, 0)}
## The cut: stepped in on the left foot, the blade stopped level at the chest.
const BLADE_CUT := {"pivot": Vector3.ZERO, "hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.18, 0.08, 0), "head": Vector3(0.14, -0.08, 0),
	"arm_r": Vector3(1.4, 0.3, -0.05), "fore_r": Vector3(0.18, 0, 0), "hand_r": Vector3(-1.5, 0, 0),
	"arm_l": Vector3(1.35, -0.3, 0.05), "fore_l": Vector3(0.35, 0, 0), "hand_l": Vector3(-1.5, 0, 0),
	"leg_l": Vector3(0.6, 0, -0.1), "shin_l": Vector3(-0.55, 0, 0), "leg_r": Vector3(-0.42, 0, 0.1), "shin_r": Vector3(-0.15, 0, 0)}

const FIST_READY := {"pivot": Vector3.ZERO, "hips": Vector3(0, -0.5, 0), "torso": Vector3(-0.14, -0.12, 0), "head": Vector3(0.14, 0.58, 0),
	"arm_l": Vector3(1.15, 0.5, -0.12), "fore_l": Vector3(1.45, 0, 0), "arm_r": Vector3(0.75, 0.75, 0.12), "fore_r": Vector3(2.3, 0, 0),
	"leg_l": Vector3(0.3, 0, -0.14), "shin_l": Vector3(-0.38, 0, 0), "leg_r": Vector3(-0.22, 0, 0.14), "shin_r": Vector3(-0.4, 0, 0)}
const FIST_JAB := {"pivot": Vector3.ZERO, "hips": Vector3(0, -0.68, 0), "torso": Vector3(-0.2, -0.3, 0.05), "head": Vector3(0.12, 0.95, 0),
	"arm_l": Vector3(1.55, 1.0, 0.0), "fore_l": Vector3(0.1, 0, 0), "arm_r": Vector3(0.8, 0.95, 0.15), "fore_r": Vector3(2.35, 0, 0),
	"leg_l": Vector3(0.5, 0, -0.2), "shin_l": Vector3(-0.48, 0, 0), "leg_r": Vector3(-0.38, 0, 0.2), "shin_r": Vector3(-0.25, 0, 0)}
const FIST_CROSS := {"pivot": Vector3.ZERO, "hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.28, 0.38, -0.05), "head": Vector3(0.12, -0.62, 0),
	"arm_r": Vector3(1.55, -0.68, 0.0), "fore_r": Vector3(0.1, 0, 0), "arm_l": Vector3(0.75, -0.5, -0.05), "fore_l": Vector3(2.3, 0, 0),
	"leg_l": Vector3(0.55, 0, -0.22), "shin_l": Vector3(-0.65, 0, 0), "leg_r": Vector3(-0.52, 0, 0.24), "shin_r": Vector3(-0.16, 0, 0)}

const GUN_AIM := {"pivot": Vector3.ZERO, "hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.04, 0.1, 0), "head": Vector3(0.0, 0.05, 0),
	"arm_r": Vector3(1.5, 0.05, 0.05), "fore_r": Vector3(0.12, 0, 0),
	"leg_l": Vector3(0.2, 0, -0.14), "shin_l": Vector3(-0.22, 0, 0), "leg_r": Vector3(-0.15, 0, 0.14), "shin_r": Vector3(-0.25, 0, 0)}


static func pose(h, n: String, u: float) -> Array:
	var t: float = float(h._action["t"])
	var into := minf(t / BLEND, 1.0)
	match n:
		"dt_train_blade":
			var k := fposmod(t, TRAIN_LOOP) / TRAIN_LOOP
			var loop: Dictionary = h._keys(k, [[0.0, BLADE_READY], [0.34, BLADE_UP], [0.48, BLADE_UP], [0.6, BLADE_CUT, "out"], [0.74, BLADE_CUT], [1.0, BLADE_READY]])
			var lift := Vector3(0, -0.07 * _bump(k, 0.6, 0.2), 0)
			return [h._keys(into, [[0.0, {}], [1.0, loop]]), "full", lift * into]
		"dt_train_fist":
			var k := fposmod(t, FIST_LOOP) / FIST_LOOP
			var loop: Dictionary = h._keys(k, [[0.0, FIST_READY], [0.1, FIST_READY], [0.2, FIST_JAB, "out"], [0.3, FIST_JAB], [0.45, FIST_READY],
				[0.55, FIST_READY], [0.66, FIST_CROSS, "out"], [0.76, FIST_CROSS], [0.92, FIST_READY], [1.0, FIST_READY]])
			var lift := Vector3(0, -0.04 + 0.025 * absf(sin(t * TAU * 2.0 / FIST_LOOP)), 0)
			return [h._keys(into, [[0.0, {}], [1.0, loop]]), "full", lift * into]
		"dt_train_gun":
			var k := fposmod(t, GUN_LOOP) / GUN_LOOP
			var aim := GUN_AIM.duplicate()
			if h.stance == "dual_pistol":
				aim["arm_l"] = Vector3(1.5, -0.05, -0.05)
				aim["fore_l"] = Vector3(0.12, 0, 0)
			else:
				aim["arm_l"] = Vector3(0.1, 0, -0.15)
				aim["fore_l"] = Vector3(1.6, 0, 0)
			# three marks across the bow, a kick at each
			var turn: Dictionary = h._keys(k, [[0.0, {"torso": Vector3(0, 0.55, 0)}], [0.2, {"torso": Vector3(0, 0.55, 0)}], [0.33, {"torso": Vector3(0, -0.1, 0)}, "out"],
				[0.53, {"torso": Vector3(0, -0.1, 0)}], [0.66, {"torso": Vector3(0, -0.6, 0)}, "out"], [0.86, {"torso": Vector3(0, -0.6, 0)}], [1.0, {"torso": Vector3(0, 0.55, 0)}]])
			aim["torso"] = (GUN_AIM["torso"] as Vector3) + (turn["torso"] as Vector3)
			aim["head"] = (GUN_AIM["head"] as Vector3) + Vector3(0, (turn["torso"] as Vector3).y * 0.3, 0)
			var kick := 0.35 * (_bump(k, 0.12, 0.06) + _bump(k, 0.45, 0.06) + _bump(k, 0.78, 0.06))
			aim["arm_r"] = (aim["arm_r"] as Vector3) + Vector3(kick, 0, 0)
			if h.stance == "dual_pistol":
				aim["arm_l"] = (aim["arm_l"] as Vector3) + Vector3(kick, 0, 0)
			return [h._keys(into, [[0.0, {}], [1.0, aim]]), "full", Vector3.ZERO]
		"dt_startle":
			var up := {"torso": Vector3(0.12, 0, 0), "head": Vector3(0.3, 0.5, 0), "arm_r": Vector3(0.6, 0, 0.35), "fore_r": Vector3(1.1, 0, 0),
				"arm_l": Vector3(0.6, 0, -0.35), "fore_l": Vector3(1.1, 0, 0)}
			var look := up.merged({"head": Vector3(0.2, -0.5, 0)}, true)
			return [h._keys(u, [[0.0, {}], [0.2, up, "out"], [0.6, look], [1.0, {}]]), "upper", Vector3.ZERO]
	return []


## 0..1..0 over `w` either side of `at` (a quick bump in a loop's phase).
static func _bump(k: float, at: float, w: float) -> float:
	return Humanoid._ease(1.0 - absf(k - at) / w)
