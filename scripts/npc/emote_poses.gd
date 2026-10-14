class_name EmotePoses
extends RefCounted
## The emote wheel's emotes ("emote_<id>", Player.emote) and the talk / interact
## gestures ("gesture_<id>"), keyed poses for Humanoid._action_pose. Lengths are
## in ActionSpecs. Full-body emotes stop when you move (Player._emote_tick).

## The wheel's order (clockwise from the top), its labels, and each one's sound
## [name, at u, volume dB] ("sit" is the ground sit, not an action).
const ORDER := ["wave", "point", "salute", "laugh", "cheer", "dance", "sit", "shrug", "bow", "flex", "facepalm", "shanty"]
const LABELS := {"wave": "Wave", "point": "Point", "salute": "Salute", "laugh": "Laugh", "cheer": "Cheer", "dance": "Hornpipe",
	"sit": "Sit", "shrug": "Shrug", "bow": "Bow", "flex": "Flex", "facepalm": "Facepalm", "shanty": "Shanty"}
const SOUNDS := {"salute": ["heel_click", 0.08, -6.0], "laugh": ["laugh", 0.12, -2.0], "cheer": ["cheer", 0.28, -2.0],
	"dance": ["jig", 0.0, -6.0], "bow": ["whoosh", 0.2, -14.0], "flex": ["hup", 0.42, -4.0], "facepalm": ["slap", 0.18, -6.0],
	"shanty": ["shanty", 0.0, -6.0]}
const FULL := ["salute", "laugh", "cheer", "dance", "bow", "flex", "shanty"]

const HIP_L := {"arm_l": Vector3(-0.25, 0.35, -0.6), "fore_l": Vector3(1.75, 0, 0)}
## Arms folded high across the chest, the left over the right (the arm out sideways, then
## turned forward by y so the elbow folds it inward).
const FOLDED := {"arm_l": Vector3(0, -0.9, -1.25), "fore_l": Vector3(1.85, 0, 0), "arm_r": Vector3(0, 0.9, 1.4), "fore_r": Vector3(1.8, 0, 0)}


static func pose(h, n: String, u: float) -> Array:
	var t: float = h._t
	var dur: float = float(h._action["dur"])
	match n:
		"emote_wave":
			var wv := {"arm_r": Vector3(0.35, -0.2, 2.45 + sin(t * 11.0) * 0.25), "fore_r": Vector3(0.5 + sin(t * 11.0 + 0.8) * 0.3, 0, 0),
				"torso": Vector3(0.04, 0.12, -0.08), "head": Vector3(0.12, -0.12, 0.06), "arm_l": Vector3(0, 0, -0.12), "fore_l": Vector3(0.25, 0, 0)}
			return [h._keys(u, [[0.0, {}], [0.15, wv, "out"], [0.85, wv], [1.0, {}]]), "upper", Vector3.ZERO]
		"emote_point":
			var cock := {"arm_r": Vector3(1.1, 0.2, 0.3), "fore_r": Vector3(1.2, 0, 0), "torso": Vector3(0, 0.1, 0)}.merged(HIP_L)
			var pt := {"arm_r": Vector3(1.62, -0.05, 0.1), "fore_r": Vector3(0.06, 0, 0), "hand_r": Vector3(-0.3, 0, 0),
				"torso": Vector3(-0.06, -0.2, 0), "head": Vector3(0.05, 0.12, 0)}.merged(HIP_L)
			return [h._keys(u, [[0.0, {}], [0.12, cock], [0.22, pt, "out"], [0.8, pt], [1.0, {}]]), "upper", Vector3.ZERO]
		"emote_salute":
			# heels together, chest up, the right hand snapped to the brow
			var st := {"arm_r": Vector3(1.45, 0, 0.9), "fore_r": Vector3(2.3, 0, 0), "hand_r": Vector3(0.2, 0, 0),
				"arm_l": Vector3(0, 0, -0.06), "fore_l": Vector3(0.1, 0, 0), "torso": Vector3(0.06, 0, 0), "head": Vector3(0.06, 0, 0), "hips": Vector3.ZERO,
				"leg_l": Vector3(0, 0, 0.03), "leg_r": Vector3(0, 0, -0.03), "shin_l": Vector3(-0.04, 0, 0), "shin_r": Vector3(-0.04, 0, 0), "_lift": Vector3.ZERO}
			return [h._keys(u, [[0.0, {}], [0.12, st, "out"], [0.78, st], [1.0, {}]]), "full", Vector3.ZERO]
		"emote_laugh":
			var back := {"torso": Vector3(0.3, 0, 0), "head": Vector3(0.45, 0, 0), "hips": Vector3.ZERO,
				"arm_l": Vector3(0.35, 0, -0.25), "fore_l": Vector3(1.5, 0, 0), "arm_r": Vector3(0.35, 0, 0.25), "fore_r": Vector3(1.5, 0, 0),
				"leg_l": Vector3(0.05, 0, -0.06), "leg_r": Vector3(0.05, 0, 0.06), "shin_l": Vector3(-0.15, 0, 0), "shin_r": Vector3(-0.15, 0, 0), "_lift": Vector3(0, -0.03, 0)}
			var over := {"torso": Vector3(-0.55, 0.15, 0), "head": Vector3(0.2, -0.1, 0), "hips": Vector3(0, -0.1, 0),
				"arm_l": Vector3(0.45, 0, -0.2), "fore_l": Vector3(1.6, 0, 0), "arm_r": Vector3(0.75, 0, 0.15), "fore_r": Vector3(0.25, 0, 0),
				"leg_l": Vector3(-0.1, 0, -0.08), "leg_r": Vector3(0.4, 0, 0.08), "shin_l": Vector3(-0.3, 0, 0), "shin_r": Vector3(-0.65, 0, 0), "_lift": Vector3(0, -0.12, 0)}
			var p: Dictionary = h._keys(u, [[0.0, {}], [0.15, back, "out"], [0.4, back], [0.55, over, "out"], [0.85, over], [1.0, {}]])
			# shaking with it
			var shake := sin(t * 24.0) * 0.05 * (1.0 if u > 0.1 and u < 0.9 else 0.0)
			p["torso"] = (p.get("torso", h._base["torso"]) as Vector3) + Vector3(shake, 0, 0)
			p["head"] = (p.get("head", h._base["head"]) as Vector3) + Vector3(shake * 0.6, 0, 0)
			return [p, "full", Vector3.ZERO]
		"emote_cheer":
			var squat := {"torso": Vector3(-0.25, 0, 0), "head": Vector3(0.2, 0, 0), "hips": Vector3.ZERO,
				"arm_l": Vector3(-0.4, 0, -0.2), "fore_l": Vector3(0.4, 0, 0), "arm_r": Vector3(-0.4, 0, 0.2), "fore_r": Vector3(0.4, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.06), "leg_r": Vector3(0.6, 0, 0.06), "shin_l": Vector3(-1.1, 0, 0), "shin_r": Vector3(-1.1, 0, 0), "_lift": Vector3(0, -0.2, 0)}
			var leap := {"torso": Vector3(0.15, 0, 0), "head": Vector3(0.3, 0, 0), "hips": Vector3.ZERO,
				"arm_r": Vector3(2.95, 0, 0.25), "fore_r": Vector3(0.15, 0, 0), "arm_l": Vector3(2.6, 0, -0.55), "fore_l": Vector3(0.3, 0, 0),
				"leg_l": Vector3(0.5, 0, -0.06), "leg_r": Vector3(-0.1, 0, 0.06), "shin_l": Vector3(-1.0, 0, 0), "shin_r": Vector3(-0.5, 0, 0), "_lift": Vector3(0, 0.28, 0)}
			var land := leap.merged({"torso": Vector3(-0.1, 0, 0), "leg_l": Vector3(0.4, 0, -0.06), "leg_r": Vector3(0.4, 0, 0.06),
				"shin_l": Vector3(-0.7, 0, 0), "shin_r": Vector3(-0.7, 0, 0), "_lift": Vector3(0, -0.1, 0)}, true)
			var pump := {"torso": Vector3(0.05, 0, 0), "head": Vector3(0.25, 0, 0), "hips": Vector3.ZERO,
				"arm_r": Vector3(2.85 + sin(t * 14.0) * 0.18, 0, 0.3), "fore_r": Vector3(0.35 + maxf(0.0, sin(t * 14.0)) * 0.4, 0, 0),
				"arm_l": Vector3(0.9, 0, -0.5), "fore_l": Vector3(1.7, 0, 0),
				"leg_l": Vector3(0.05, 0, -0.08), "leg_r": Vector3(0.05, 0, 0.08), "shin_l": Vector3(-0.15, 0, 0), "shin_r": Vector3(-0.15, 0, 0), "_lift": Vector3.ZERO}
			return [h._keys(u, [[0.0, {}], [0.15, squat, "out"], [0.22, squat], [0.34, leap, "out"], [0.46, land, "in"], [0.56, pump], [0.9, pump], [1.0, {}]]), "full", Vector3.ZERO]
		"emote_dance":
			# a sailor's hornpipe: arms folded high, hopping from foot to foot, the free one kicking out
			var beat := u * dur * 2.4
			var ph := fmod(beat, 1.0)
			var s := 1.0 if int(beat) % 2 == 0 else -1.0
			var k := sin(ph * PI)
			var up := "l" if s > 0.0 else "r"
			var dn := "r" if s > 0.0 else "l"
			var out := 1.0 if up == "r" else -1.0
			var dp := {"hips": Vector3(0, 0, -0.06 * s * k), "torso": Vector3(0.05, 0.1 * s * k, 0.1 * s * k), "head": Vector3(0.1 + 0.05 * k, -0.08 * s * k, -0.06 * s * k),
				"leg_" + up: Vector3(0.95 * k, 0, 0.12 * out), "shin_" + up: Vector3(-1.3 * k * (1.0 - ph * 0.6), 0, 0),
				"leg_" + dn: Vector3(0.1, 0, -0.04 * out), "shin_" + dn: Vector3(-0.25, 0, 0),
				"_lift": Vector3(0.03 * s, -0.06 + 0.07 * k, 0)}.merged(FOLDED)
			return [h._keys(u, [[0.0, {}], [0.06, dp], [0.94, dp], [1.0, {}]]), "full", Vector3.ZERO]
		"emote_shrug":
			# elbows at the sides, forearms turned out (y) so the hands open out sideways, head cocked
			var sh := {"arm_l": Vector3(0, 1.0, -0.25), "fore_l": Vector3(1.4, 0, 0), "arm_r": Vector3(0, -1.0, 0.25), "fore_r": Vector3(1.4, 0, 0),
				"torso": Vector3(0.1, 0, 0), "head": Vector3(0.08, 0, 0.25)}
			return [h._keys(u, [[0.0, {}], [0.25, sh, "out"], [0.75, sh], [1.0, {}]]), "upper", Vector3.ZERO]
		"emote_bow":
			# a flourish of the right hand, then down low with it at the chest, the left swept out behind
			var legs := {"hips": Vector3.ZERO, "leg_r": Vector3(-0.35, 0, 0.05), "shin_r": Vector3(-0.25, 0, 0), "leg_l": Vector3(0.15, 0, -0.05), "shin_l": Vector3(-0.2, 0, 0)}
			var flo := {"arm_l": Vector3(0.3, 0, -1.3), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(1.2, 0.3, 0.1), "fore_r": Vector3(1.0, 0, 0),
				"torso": Vector3(0.05, 0, 0), "head": Vector3(0.05, 0, 0), "_lift": Vector3.ZERO}.merged(legs)
			var low := {"arm_l": Vector3(-0.6, 0, -0.9), "fore_l": Vector3(0.2, 0, 0), "arm_r": Vector3(0.45, 0, -0.15), "fore_r": Vector3(2.1, 0, 0),
				"torso": Vector3(-0.95, 0, 0), "head": Vector3(-0.25, 0, 0), "_lift": Vector3(0, -0.05, 0)}.merged(legs)
			low["shin_l"] = Vector3(-0.35, 0, 0)
			return [h._keys(u, [[0.0, {}], [0.2, flo, "out"], [0.32, flo], [0.5, low, "out"], [0.78, low], [1.0, {}]]), "full", Vector3.ZERO]
		"emote_flex":
			var crab := {"torso": Vector3(-0.3, 0, 0), "head": Vector3(0.25, 0, 0), "hips": Vector3.ZERO,
				"arm_l": Vector3(0.55, -0.4, -0.25), "fore_l": Vector3(1.4, 0, 0), "arm_r": Vector3(0.55, 0.4, 0.25), "fore_r": Vector3(1.4, 0, 0),
				"leg_l": Vector3(0.25, 0, -0.22), "leg_r": Vector3(0.25, 0, 0.22), "shin_l": Vector3(-0.55, 0, 0), "shin_r": Vector3(-0.55, 0, 0), "_lift": Vector3(0, -0.12, 0)}
			var tr := sin(t * 30.0) * 0.03
			var bic := {"torso": Vector3(0.12, 0, 0), "head": Vector3(0.15, 0, 0), "hips": Vector3.ZERO,
				"arm_l": Vector3(1.45, 0, -0.9), "fore_l": Vector3(2.15 + tr, 0, 0), "arm_r": Vector3(1.45, 0, 0.9), "fore_r": Vector3(2.15 - tr, 0, 0),
				"leg_l": Vector3(0.05, 0, -0.2), "leg_r": Vector3(0.05, 0, 0.2), "shin_l": Vector3(-0.2, 0, 0), "shin_r": Vector3(-0.2, 0, 0), "_lift": Vector3(0, -0.05, 0)}
			return [h._keys(u, [[0.0, {}], [0.2, crab, "out"], [0.35, crab], [0.45, bic, "back"], [0.85, bic], [1.0, {}]]), "full", Vector3.ZERO]
		"emote_facepalm":
			var fp := {"arm_r": Vector3(1.35, 0.5, -0.05), "fore_r": Vector3(2.3, 0, 0), "torso": Vector3(-0.15, 0, 0),
				"head": Vector3(-0.35, sin(t * 6.0) * 0.12, 0), "arm_l": Vector3(0.05, 0, -0.05), "fore_l": Vector3(0.1, 0, 0)}
			return [h._keys(u, [[0.0, {}], [0.18, fp, "out"], [0.8, fp], [1.0, {}]]), "upper", Vector3.ZERO]
		"emote_shanty":
			# swaying to a sea shanty, a (pretend) mug raised high, the other hand on the heart
			var sw := sin(u * dur * TAU * 0.55)
			var sp := {"arm_r": Vector3(2.3, 0, 0.35 + sw * 0.1), "fore_r": Vector3(1.0, 0, 0), "arm_l": Vector3(0.55, 0.3, -0.35), "fore_l": Vector3(1.2, 0, 0),
				"torso": Vector3(0.1, 0, sw * 0.12), "hips": Vector3(0, 0, -sw * 0.08), "head": Vector3(0.3, 0, sw * 0.15),
				"leg_l": Vector3(0.05, 0, -0.18), "leg_r": Vector3(0.05, 0, 0.18),
				"shin_l": Vector3(-0.2 - maxf(0.0, -sw) * 0.25, 0, 0), "shin_r": Vector3(-0.2 - maxf(0.0, sw) * 0.25, 0, 0), "_lift": Vector3(sw * 0.04, -0.05, 0)}
			return [h._keys(u, [[0.0, {}], [0.08, sp], [0.92, sp], [1.0, {}]]), "full", Vector3.ZERO]
	return [{}, "upper", Vector3.ZERO]
