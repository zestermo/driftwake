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
## coiled left: its wind-up for free), the wrist cocks so the blade turns up, then it sweeps
## up across the front (round 9 C) and follows through out to the right and on behind the
## right side, the arm extended but not locked and low enough to keep clear of the head.
## Keys are spaced by distance so the hand speeds up once into contact and only slows after
## it (a "smooth" key mid-rise stopped the hand dead and read as a wobble).
const SLASH_L_SWING := {"center": Vector3(0.08, 1.32, -0.05), "lag": 0.02, "keys": [
	[0.0, {"dir": Vector3(-0.65, -0.55, 0.0), "r": 0.483, "break": 0.3}],
	[0.2, {"dir": Vector3(-0.75, -0.4, -0.3), "r": 0.56, "break": 1.0}, "smooth"],
	[0.34, {"dir": Vector3(-0.5, -0.2, -0.8), "r": 0.5, "break": 0.9}, "in"],
	[0.4, {"dir": Vector3(0.3, -0.05, -1.0), "r": 0.48, "break": 0.4}],
	[0.455, {"dir": Vector3(0.9, -0.02, -0.4), "r": 0.56, "break": 0.2}],
	[0.505, {"dir": Vector3(0.99, 0.02, 0.1), "r": 0.67, "break": 0.2}],
	[0.6, {"dir": Vector3(0.67, 0.04, 0.73), "r": 0.8, "break": 0.1}],
	[0.665, {"dir": Vector3(0.58, 0.05, 0.81), "r": 0.86, "break": 0.1}, "out"]]}
## The off hand from hit 1's tuck, coming forward as the body coils, then flung out to the
## side and back behind the chest against the cut, the arm near straight (the arm is ~0.35 +
## 0.35 m: 0.69 m from the shoulder bends ~0.4, 0.63 ~0.9), the elbow down and back so it
## can't roll over while the hand flies out. The 0.34 key keeps the hand on an arc out past
## the hip: a straight line from front to back runs through the shoulder and folds the elbow.
const SLASH_L_REACH := {"hand": "l", "follow": 1.0, "from_shoulder": true, "lag": 0.04, "pole": Vector3(-1.0, -0.35, 0.25),
	"center": Vector3.ZERO, "keys": [
	[0.0, {"dir": Vector3(0.0, -0.47, -0.28)}],
	[0.22, {"dir": Vector3(-0.2, -0.4, -0.45), "pole": Vector3(-0.3, -1.0, 0.3)}, "smooth"],
	[0.32, {"dir": Vector3(-0.47, -0.41, -0.11), "pole": Vector3(-0.2, -0.6, 1.0)}],
	[0.43, {"dir": Vector3(-0.53, -0.19, 0.29), "pole": Vector3(-0.3, -1.0, 0.3)}],
	[0.53, {"dir": Vector3(-0.48, -0.15, 0.45), "pole": Vector3(-0.3, -1.0, 0.3)}],
	[0.7, {"dir": Vector3(-0.47, -0.2, 0.42), "pole": Vector3(-0.3, -1.0, 0.3)}, "out"]]}


## Hit 3, the spinning finisher: chains from hit 2's follow-through (chest coiled right, the
## sword out behind the right shoulder: the wind-up), dips, unwinds through the front and hops
## into a full turn to the left with the arm out and the blade level, lands and sweeps across
## the front once more into a low wrap at the left. The points turn with the chest ("follow"),
## so in them the hand mostly stays out at the right side while the body carries it round;
## the plane is given (level, turning left) since the points alone sweep back and forth.
## Points are offsets from the sword shoulder in the chest's frame, so "r" is the reach (0.62
## ~ arm out, bent a little).
const SLASH_SPIN_SWING := {"from_shoulder": true, "center": Vector3.ZERO, "lag": 0.02, "follow": 1.0,
	"plane": Vector3.UP, "cut": Vector3.FORWARD, "keys": [
	[0.0, {"dir": Vector3(1.0, 0.05, 0.0), "r": 0.62, "break": 0.1}],
	[0.18, {"dir": Vector3(0.9, -0.05, 0.3), "r": 0.6, "break": 0.6}, "smooth"],
	[0.24, {"dir": Vector3(1.0, -0.2, -0.08), "r": 0.625, "break": 0.45}],
	[0.3, {"dir": Vector3(0.85, -0.25, -0.45), "r": 0.63, "break": 0.3}],
	[0.38, {"dir": Vector3(1.0, -0.3, -0.25), "r": 0.635, "break": 0.1}],
	[0.62, {"dir": Vector3(1.0, -0.3, -0.25), "r": 0.635, "break": 0.1}],
	[0.67, {"dir": Vector3(0.95, -0.28, -0.45), "r": 0.61, "break": 0.15}, "in"],
	[0.72, {"dir": Vector3(0.2, -0.25, -1.0), "r": 0.58, "break": 0.25}],
	[0.79, {"dir": Vector3(-0.7, -0.2, -0.55), "r": 0.56, "break": 0.2}],
	[0.84, {"dir": Vector3(-0.8, -0.2, -0.4), "r": 0.56, "break": 0.2}, "out"]]}
## The off hand: from hit 2's fling, pulled in to the chest for the spin (a tight turn), then
## flung out at the left for balance on the landing.
const SLASH_SPIN_REACH := {"hand": "l", "follow": 1.0, "from_shoulder": true, "lag": 0.04, "pole": Vector3(-1.0, -0.35, 0.25),
	"center": Vector3.ZERO, "keys": [
	[0.0, {"dir": Vector3(-0.47, -0.2, 0.42), "pole": Vector3(-0.3, -1.0, 0.3)}],
	[0.2, {"dir": Vector3(-0.4, -0.35, 0.1), "pole": Vector3(-0.3, -1.0, 0.3)}, "smooth"],
	[0.34, {"dir": Vector3(0.05, -0.42, -0.3)}],
	[0.6, {"dir": Vector3(0.05, -0.42, -0.3)}],
	[0.78, {"dir": Vector3(-0.5, -0.3, -0.1)}, "out"]]}


## Hit 3's body: [pose, mask, lift]. The turn itself is the pivot (a full turn left, eased in
## and out) on top of the keys; the hips and chest unwind hit 2's coil into it.
static func slash_spin(h, u: float) -> Array:
	var k := 1.6
	var p1 := _forehand(h)
	var p2 := _backhand(h)
	var gather := {"pivot": Vector3(0.04, 0, 0.04), "hips": Vector3(0, -0.38, 0) * k,
		"torso": Vector3(0.05, -0.42, 0.1) * k, "head": Vector3(0, 0.65, 0) * k,
		"leg_l": Vector3(0.55, 0, -0.16), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.35, 0, 0.16), "shin_r": Vector3(-1.0, 0, 0),
		"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.05, 0.93, 1.05), "_smear": Vector3.ZERO}
	var unwound := {"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.12, 0.08, 0), "head": Vector3(0.05, -0.1, 0),
		"leg_l": Vector3(0.6, 0, -0.1), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.2, 0, 0.1), "shin_r": Vector3(-0.5, 0, 0),
		"_lift": Vector3(0, -0.12, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}
	var whoosh := _with(_mix(gather, unwound, 0.5), Vector3(0.94, 1.0, 1.15), 0.7)
	# (in the air the legs tuck and the body leans into the turn)
	var air := unwound.merged({"pivot": Vector3(-0.1, 0, 0.08), "hips": Vector3.ZERO, "torso": Vector3(-0.12, 0.12, 0.05), "head": Vector3(0, -0.05, 0),
		"leg_l": Vector3(1.0, 0, -0.1), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.5, 0, 0.1), "shin_r": Vector3(-1.6, 0, 0),
		"_lift": Vector3(0, 0.1, 0), "_smear": Vector3(0.5, 0, 0)}, true)
	var drop := air.merged({"leg_l": Vector3(0.7, 0, -0.12), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.3, 0, 0.12), "shin_r": Vector3(-0.7, 0, 0),
		"_lift": Vector3(0, 0.05, 0), "_smear": Vector3.ZERO}, true)
	var land: Dictionary = p1["cut"].merged({"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.06, 0.92, 1.05)}, true)
	var finish := _mix(p1["cut"], p1["follow"], 0.6).merged({"_scale": Vector3.ONE}, true)
	# (the coil unwinds at a steady rate into the turn: eased keys peaked the chest at ~70 rad/s
	# for a frame and the blade flicked)
	var pose: Dictionary = h._keys(u, [[0.0, p2["follow"]], [0.18, gather, "out"], [0.26, whoosh, "linear"], [0.34, unwound, "linear"],
		[0.44, air, "out"], [0.58, drop], [0.68, land, "in"], [0.82, finish, "out"], [0.9, finish], [1.0, p1["g"]]])
	var s := smoothstep(0.22, 0.66, u)
	pose["pivot"] = (pose.get("pivot", Vector3.ZERO) as Vector3) + Vector3(0, TAU * s, 0)
	return [pose, "full", Vector3.ZERO]


## Hit 1's body: [pose, mask, lift].
static func slash_r(h, u: float) -> Array:
	var p := _forehand(h)
	return [h._keys(u, [[0.0, p["g"]], [0.32, p["load"], "out"], [0.42, p["cock"]], [0.47, p["whoosh"], "in"],
		[0.52, p["cut"], "out"], [0.66, p["follow"], "out"], [0.84, p["follow"]], [1.0, p["g"]]]), "full", Vector3.ZERO]


## Hit 2's body: [pose, mask, lift]. Starts on hit 1's follow-through pose (its chain point),
## dips and coils, steps through on the right foot into the cut, turns right after it.
static func slash_l(h, u: float) -> Array:
	var p := _backhand(h)
	return [h._keys(u, [[0.0, p["start"]], [0.22, p["gather"], "out"], [0.33, p["whoosh"], "in"], [0.41, p["cut"], "out"],
		[0.55, p["follow"], "out"], [0.74, p["follow"]], [1.0, p["g"]]]), "full", Vector3.ZERO]


## Hit 2's body poses.
static func _backhand(h) -> Dictionary:
	var k := 1.6
	var p := _forehand(h)
	var gather := {"pivot": Vector3(0.0, 0, 0.06) * k, "hips": Vector3(0, 0.45, 0) * k,
		"torso": Vector3(0.05, 0.5, 0.12) * k, "head": Vector3(0.0, -0.75, -0.05) * k,
		"leg_l": Vector3(0.8, 0, -0.14), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.5, 0, 0.14), "shin_r": Vector3(-0.5, 0, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.9, 1.05), "_smear": Vector3.ZERO}
	var cut := {"pivot": Vector3(-0.06, 0, -0.04), "hips": Vector3(0, -0.1, 0),
		"torso": Vector3(-0.15, -0.15, -0.08), "head": Vector3(0.08, 0.15, 0),
		"leg_r": Vector3(0.9, 0, 0.1), "shin_r": Vector3(-0.95, 0, 0), "leg_l": Vector3(-0.6, 0, -0.1), "shin_l": Vector3(-0.3, 0, 0),
		"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.03, 0.98, 1.03), "_smear": Vector3.ZERO}
	# (stretch along the cut, not up: the path rides the shoulders, and a vertical bob
	# under a sweeping cut made the blade wobble up and down)
	var whoosh := _with(_mix(gather, cut, 0.5), Vector3(0.94, 1.0, 1.15), 0.7)
	var follow := cut.merged({"pivot": Vector3(-0.1, 0, -0.06) * k, "hips": Vector3(0, -0.3, 0) * k,
		"torso": Vector3(-0.25, -0.33, -0.15) * k, "head": Vector3(0.1, 0.45, 0) * k, "_lift": Vector3(0, -0.15, 0),
		"_scale": Vector3.ONE}, true)
	return {"g": p["g"], "start": p["follow"], "gather": gather, "whoosh": whoosh, "cut": cut, "follow": follow}


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
