class_name MapPoses
## The held map's body (upper body only: the legs keep walking). MapHold puts the sheet between the
## hands, so its width follows them: the hands meeting is the map rolled up, apart it's open.
##   map_open  (played) the scroll comes up to the chest in both hands, then the left hand draws it open
##   map_hold  (held) holding it open at the chest, the head down reading it, a slow breath
##   map_away  (played) the hands roll it shut, then drop back

## Both hands on the rolled scroll in front of the chest.
const SHUT := {"arm_r": Vector3(0.95, 0.0, -0.32), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(-0.25, 0, 0),
	"arm_l": Vector3(0.95, 0.0, 0.32), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3(-0.25, 0, 0),
	"torso": Vector3(-0.06, 0, 0), "head": Vector3(-0.35, 0, 0)}
## Holding it open: forearms level, hands a sheet's width apart, the chest over it, the head down.
const OPEN := {"arm_r": Vector3(1.0, 0.0, 0.14), "fore_r": Vector3(0.75, 0, 0), "hand_r": Vector3(-0.3, 0, 0),
	"arm_l": Vector3(1.0, 0.0, -0.14), "fore_l": Vector3(0.75, 0, 0), "hand_l": Vector3(-0.3, 0, 0),
	"torso": Vector3(-0.1, 0, 0), "head": Vector3(-0.55, 0, 0)}


static func pose(h, n: String, u: float) -> Array:
	match n:
		"map_open":
			var wide := OPEN.duplicate()
			wide["arm_l"] = OPEN["arm_l"] + Vector3(0, 0, -0.06)
			return [h._keys(u, [[0.0, {}], [0.38, SHUT, "out"], [0.8, wide, "out"], [1.0, OPEN]]), "upper", Vector3.ZERO]
		"map_hold":
			var b := sin(float(h._t) * 1.7) * 0.025
			var p := OPEN.duplicate()
			for j in ["arm_r", "arm_l"]:
				p[j] = OPEN[j] + Vector3(b, 0, 0)
			p["head"] = OPEN["head"] + Vector3(-b, 0, 0)
			return [h._keys(u, [[0.0, {}], [1.0, p]]), "upper", Vector3.ZERO]
		"map_away":
			return [h._keys(u, [[0.0, {}], [0.45, SHUT, "out"], [1.0, {}]]), "upper", Vector3.ZERO]
	return []
