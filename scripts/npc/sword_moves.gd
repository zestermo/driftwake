class_name SwordMoves
## The cutlass combo built with swing paths (see the driftwake-animation skill, "the
## reference moves"). Each move is three parts: the body keyed as poses here (hips, chest,
## legs, lift, squash; the arms ride paths), the sword hand's path (SLASH_*_SWING) and the
## free hand's path (SLASH_*_REACH), wired up in ActionSpecs. slash_r is the reference
## every new swing is built from (trained over 8 anim lab rounds, docs/anim_lab.md).
## Turns: y- faces right, y+ left; the head counters the chest to stay on the target.

## Hit 1, the diagonal forehand: from the guard the hand arcs out and up round the right
## shoulder (wide and high, so the elbow opens), cocks, then cuts down through the space in
## front and wraps low round the left side. Path points: centre + dir * r (body space at the
## guard, carried with the shoulders); "break" = the wrist cocked off the forearm's line.
const SLASH_R_SWING := {"center": Vector3(0.08, 1.32, -0.05), "lag": 0.02, "plane_from": 2, "keys": [
	[0.06, {"dir": Vector3(0.36, -0.24, -0.38), "r": 0.575, "break": 1.0}],
	[0.1, {"dir": Vector3(0.54, -0.02, -0.1), "r": 0.552, "break": 1.1}],
	[0.16, {"dir": Vector3(0.8, 0.55, 0.45), "r": 0.575, "break": 1.15}],
	[0.32, {"dir": Vector3(0.75, 0.8, 0.45), "r": 0.598, "break": 1.3}, "smooth"],
	[0.4, {"dir": Vector3(0.85, 0.6, -0.1), "r": 0.6325, "break": 1.35}, "in"],
	[0.5, {"dir": Vector3(0.05, -0.05, -1.0), "r": 0.713, "break": 0.7}],
	[0.62, {"dir": Vector3(-0.7, -0.45, -0.45), "r": 0.598, "break": 0.1}],
	[0.76, {"dir": Vector3(-0.65, -0.55, 0.0), "r": 0.483, "break": 0.3}, "out"]]}
## The off hand (offsets from the left shoulder in the chest's frame): from the guard (low,
## out at the left side) raised above the eyes reaching toward the target on the wind-up,
## pulled in to the chest through the cut and kept tucked.
const OFF_GUARD := Vector3(-0.34, -0.33, -0.15)
const SLASH_R_REACH := {"hand": "l", "follow": 1.0, "from_shoulder": true, "lag": 0.04, "pole": Vector3(-1.0, -0.35, 0.25),
	"center": Vector3.ZERO, "keys": [
	[0.06, {"dir": OFF_GUARD}],
	[0.32, {"dir": Vector3(-0.5, 0.34, -0.13)}, "smooth"],
	[0.42, {"dir": Vector3(-0.49, 0.36, -0.15)}],
	[0.5, {"dir": Vector3(0.11, -0.45, -0.3)}],
	[0.62, {"dir": Vector3(0.0, -0.47, -0.28)}],
	[0.78, {"dir": Vector3(0.0, -0.47, -0.28)}, "out"]]}

## Hit 2, the rising backhand: chains from hit 1's wrap (the hand low at the left, the chest
## coiled left: its wind-up for free), the wrist cocks so the blade turns up, then it cuts
## up across the front to the upper right and follows through past the right side.
const SLASH_L_SWING := {"center": Vector3(0.08, 1.32, -0.05), "lag": 0.02, "keys": [
	[0.0, {"dir": Vector3(-0.65, -0.55, 0.0), "r": 0.483, "break": 0.3}],
	[0.2, {"dir": Vector3(-0.6, -0.7, -0.35), "r": 0.56, "break": 1.0}, "smooth"],
	[0.32, {"dir": Vector3(-0.35, -0.6, -0.75), "r": 0.66, "break": 1.2}, "in"],
	[0.44, {"dir": Vector3(0.25, 0.0, -1.0), "r": 0.71, "break": 0.6}],
	[0.56, {"dir": Vector3(0.8, 0.45, -0.35), "r": 0.6, "break": 0.2}],
	[0.74, {"dir": Vector3(0.75, 0.4, 0.5), "r": 0.52, "break": 0.35}, "out"]]}
## The off hand from hit 1's tuck, coming forward as the body coils, then flung out to the
## side and back behind the chest against the cut, the arm near straight (the arm is ~0.35 +
## 0.35 m: 0.69 m from the shoulder bends ~0.4, 0.63 ~0.9), the elbow down and back so it
## can't roll over while the hand flies out. The 0.34 key keeps the hand on an arc out past
## the hip: a straight line from front to back runs through the shoulder and folds the elbow.
const SLASH_L_REACH := {"hand": "l", "follow": 1.0, "from_shoulder": true, "lag": 0.04, "pole": Vector3(-1.0, -0.35, 0.25),
	"center": Vector3.ZERO, "keys": [
	[0.0, {"dir": Vector3(0.0, -0.47, -0.28)}],
	[0.22, {"dir": Vector3(-0.2, -0.4, -0.45), "pole": Vector3(-0.3, -1.0, 0.3)}, "smooth"],
	[0.34, {"dir": Vector3(-0.47, -0.41, -0.11), "pole": Vector3(-0.2, -0.6, 1.0)}],
	[0.46, {"dir": Vector3(-0.53, -0.19, 0.29), "pole": Vector3(-0.3, -1.0, 0.3)}],
	[0.6, {"dir": Vector3(-0.48, -0.15, 0.45), "pole": Vector3(-0.3, -1.0, 0.3)}],
	[0.8, {"dir": Vector3(-0.47, -0.2, 0.42), "pole": Vector3(-0.3, -1.0, 0.3)}, "out"]]}


## Hit 1's body: [pose, mask, lift].
static func slash_r(h, u: float) -> Array:
	var p := _forehand(h)
	return [h._keys(u, [[0.0, p["g"]], [0.32, p["load"], "out"], [0.42, p["cock"]], [0.47, p["whoosh"], "in"],
		[0.52, p["cut"], "out"], [0.66, p["follow"], "out"], [0.84, p["follow"]], [1.0, p["g"]]]), "full", Vector3.ZERO]


## Hit 2's body: [pose, mask, lift]. Starts on hit 1's follow-through pose (its chain point),
## dips and coils, steps through on the right foot into the cut, turns right after it.
static func slash_l(h, u: float) -> Array:
	var k := 1.6
	var p := _forehand(h)
	var start: Dictionary = p["follow"]
	var gather := {"pivot": Vector3(0.0, 0, 0.06) * k, "hips": Vector3(0, 0.45, 0) * k,
		"torso": Vector3(0.05, 0.5, 0.12) * k, "head": Vector3(0.0, -0.75, -0.05) * k,
		"leg_l": Vector3(0.8, 0, -0.14), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.5, 0, 0.14), "shin_r": Vector3(-0.5, 0, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.9, 1.05), "_smear": Vector3.ZERO}
	var cut := {"pivot": Vector3(-0.06, 0, -0.04), "hips": Vector3(0, -0.1, 0),
		"torso": Vector3(-0.15, -0.15, -0.08), "head": Vector3(0.08, 0.15, 0),
		"leg_r": Vector3(0.9, 0, 0.1), "shin_r": Vector3(-0.95, 0, 0), "leg_l": Vector3(-0.6, 0, -0.1), "shin_l": Vector3(-0.3, 0, 0),
		"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.04, 0.95, 1.03), "_smear": Vector3.ZERO}
	var whoosh := _with(_mix(gather, cut, 0.5), Vector3(0.92, 1.08, 1.15), 0.7)
	var follow := cut.merged({"pivot": Vector3(-0.1, 0, -0.06) * k, "hips": Vector3(0, -0.45, 0) * k,
		"torso": Vector3(-0.25, -0.6, -0.15) * k, "head": Vector3(0.1, 0.7, 0) * k, "_lift": Vector3(0, -0.15, 0),
		"_scale": Vector3.ONE}, true)
	return [h._keys(u, [[0.0, start], [0.22, gather, "out"], [0.36, whoosh, "in"], [0.44, cut, "out"],
		[0.6, follow, "out"], [0.8, follow], [1.0, p["g"]]]), "full", Vector3.ZERO]


## Hit 1's body poses (the arms ride paths: arm keys here only seed the blend).
static func _forehand(h) -> Dictionary:
	var k := 1.6
	var g: Dictionary = h._guard()
	var load := {"pivot": Vector3(0.05, 0, -0.05) * k, "hips": Vector3(0, -0.4, 0) * k,
		"torso": Vector3(0.1, -0.55, -0.1) * k, "head": Vector3(-0.05, 0.75, 0.05) * k,
		"leg_l": Vector3(0.35, 0, -0.14), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.15, 0, 0.12), "shin_r": Vector3(-0.65, 0, 0),
		"_lift": Vector3(0, -0.1, 0) * k, "_scale": Vector3(1.05, 0.9, 1.05)}
	var cock := load.merged({"torso": Vector3(0.12, -0.62, -0.12) * k, "hips": Vector3(0, -0.44, 0) * k, "_scale": Vector3(1.06, 0.88, 1.06)}, true)
	# (at the strike the chest is about square to the target, the arm out in front of it:
	# turned further, the shoulder passes the hand and the blade points back across the body)
	var cut := {"pivot": Vector3(-0.08, 0, 0.04), "hips": Vector3(0, 0.12, 0),
		"torso": Vector3(-0.18, 0.12, 0.08), "head": Vector3(0.08, -0.15, 0),
		"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.75, 0, 0.12), "shin_r": Vector3(-0.22, 0, 0),
		"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.06, 0.93, 1.06)}
	var whoosh := _with(_mix(cock, cut, 0.5), Vector3(0.92, 1.08, 1.15), 0.7)
	var follow := cut.merged({"pivot": Vector3(-0.16, 0, 0.08) * k, "hips": Vector3(0, 0.55, 0) * k,
		"torso": Vector3(-0.35, 0.75, 0.2) * k, "head": Vector3(0.1, -0.8, 0) * k, "_lift": Vector3(0, -0.25, 0) * k,
		"_scale": Vector3.ONE, "_smear": Vector3.ZERO}, true)
	return {"g": g, "load": load, "cock": cock, "whoosh": whoosh, "cut": cut, "follow": follow}


## `p` with squash/stretch (body scale: x side, y up, z forward) and blade smear.
static func _with(p: Dictionary, scale: Vector3, smear: float) -> Dictionary:
	return p.merged({"_scale": scale, "_smear": Vector3(smear, 0, 0)}, true)


## A pose part way from `a` to `b` (joints in either).
static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for j in a.keys():
		out[j] = (a[j] as Vector3).lerp(b.get(j, a[j]), k)
	for j in b.keys():
		if not out.has(j):
			out[j] = b[j]
	return out
