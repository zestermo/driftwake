class_name KatanaMoves
## The katana's light combo on swing paths (the cutlass's SwordMoves recipe, two-handed: the
## right hand rides the path, Humanoid._katana_hands puts the left on the hilt behind it).
## Points are offsets from the sword shoulder in the chest's frame (x+ right, y up, z+ back;
## "from_shoulder", "follow" 1), so "r" is the reach (~0.64 locked, 0.6 a little bent, 0.5
## ~1.1 rad) and the chest's turn carries the hands through the cut.
## Turns: y- faces right, y+ left; the head counters the chest to stay on the target.

## Hit 1, the overhead diagonal (kesa-giri): from the guard the hands rise up over the right
## shoulder, the blade laid back over it, a beat, then one long cut down through the front at a
## slant (arms out, the blade on their line) and on low past the left hip.
## (the cut's plane is given: the diagonal through the front, so the cocked blade lies back over
## the right shoulder in it and the follow-through runs down to the lower left, not flat across)
const KR_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.02, "plane": Vector3(-0.8, 0.6, 0.0), "plane_from": 2, "keys": [
	[0.06, {"dir": Vector3(-0.52, -0.34, -0.78), "r": 0.5, "break": 1.0}],
	[0.18, {"dir": Vector3(-0.1, 0.3, -0.93), "r": 0.5, "break": 1.0}],
	[0.32, {"dir": Vector3(0.2, 0.9, -0.38), "r": 0.46, "break": 1.2}, "smooth"],
	[0.4, {"dir": Vector3(0.2, 0.88, -0.42), "r": 0.47, "break": 1.25}, "in"],
	[0.5, {"dir": Vector3(-0.25, -0.15, -0.95), "r": 0.63, "break": 0.35}],
	[0.6, {"dir": Vector3(-0.38, -0.7, -0.6), "r": 0.62, "break": 0.12}],
	[0.72, {"dir": Vector3(-0.42, -0.8, -0.42), "r": 0.6, "break": 0.15}, "out"]]}

## Hit 2, the side cut, left to right: from hit 1's low finish the hands come up to the left
## shoulder (the blade laid back level behind it), then sweep flat across the front at chest
## height and on out past the right side.
const KL_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.02, "plane": Vector3(0, -1, 0),
	"cut": Vector3.RIGHT, "keys": [
	[0.0, {"dir": Vector3(-0.58, -0.72, -0.36), "r": 0.58, "break": 0.25}],
	[0.2, {"dir": Vector3(-0.9, -0.05, -0.42), "r": 0.44, "break": 1.0}, "smooth"],
	[0.3, {"dir": Vector3(-0.88, 0.0, -0.46), "r": 0.45, "break": 1.2}, "in"],
	[0.4, {"dir": Vector3(-0.42, -0.08, -0.9), "r": 0.56, "break": 0.75}],
	[0.47, {"dir": Vector3(0.1, -0.1, -0.99), "r": 0.61, "break": 0.4}],
	[0.55, {"dir": Vector3(0.55, -0.1, -0.83), "r": 0.6, "break": 0.2}],
	[0.66, {"dir": Vector3(0.72, -0.12, -0.68), "r": 0.56, "break": 0.15}, "out"]]}

## Hit 3, the stab: from hit 2's finish the hands draw back to the right hip with the point
## toward the target, then drive it straight out through a long lunge, the edge down.
const KS_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.01, "plane": Vector3(-1, 0, 0),
	"cut": Vector3.FORWARD, "keys": [
	[0.0, {"dir": Vector3(0.72, -0.12, -0.68), "r": 0.56, "break": 0.15}],
	[0.25, {"dir": Vector3(0.05, -0.92, -0.1), "r": 0.42, "break": 0.55}, "smooth"],
	[0.36, {"dir": Vector3(0.05, -0.9, -0.2), "r": 0.43, "break": 0.5}, "in"],
	[0.46, {"dir": Vector3(0.12, -0.3, -0.95), "r": 0.6, "break": 0.1}],
	[0.53, {"dir": Vector3(0.14, -0.2, -0.97), "r": 0.63, "break": 0.05}, "out"]]}


## The air slash (one-handed, PlungeState): the blade whipped up over the left shoulder, a beat,
## then one big arc down through the front, under the drawn-up knees and up out to the right.
const AIR_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.02, "plane_from": 2, "keys": [
	[0.0, {"dir": Vector3(-0.52, -0.34, -0.78), "r": 0.5, "break": 1.0}],
	[0.2, {"dir": Vector3(-0.92, 0.22, 0.12), "r": 0.56, "break": 1.2}],
	[0.3, {"dir": Vector3(-0.94, 0.18, 0.2), "r": 0.57, "break": 1.25}, "smooth"],
	[0.38, {"dir": Vector3(-0.55, -0.3, -0.78), "r": 0.62, "break": 0.5}, "in"],
	[0.46, {"dir": Vector3(-0.05, -0.95, -0.3), "r": 0.64, "break": 0.3}],
	[0.54, {"dir": Vector3(0.75, -0.6, -0.25), "r": 0.63, "break": 0.3}],
	[0.62, {"dir": Vector3(0.92, -0.22, 0.1), "r": 0.6, "break": 0.2}, "out"]]}


## The air slash's body: knees drawn up unevenly, the chest wound a little left under the raised
## blade, then pitched forward over the cut and turned right after it (a small turn: the path
## rides the chest), the free arm flung out for balance.
static func air(h, u: float) -> Array:
	var knees := {"leg_l": Vector3(1.45, 0, -0.16), "shin_l": Vector3(-2.05, 0, 0), "leg_r": Vector3(0.95, 0, 0.18), "shin_r": Vector3(-1.45, 0, 0)}
	var wind := {"pivot": Vector3(0.06, 0, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(0.1, 0.4, 0.05), "head": Vector3(0.0, -0.3, 0),
		"arm_l": Vector3(0.3, 0, -1.2), "fore_l": Vector3(0.5, 0, 0), "_scale": Vector3(1.04, 0.93, 1.04), "_smear": Vector3.ZERO}.merged(knees)
	var under := {"pivot": Vector3(-0.3, 0, 0.1), "hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.35, -0.22, 0.1), "head": Vector3(0.15, 0.18, 0),
		"arm_l": Vector3(0.9, 0, -1.3), "fore_l": Vector3(0.4, 0, 0), "_scale": Vector3(0.96, 1.04, 1.08), "_smear": Vector3(0.6, 0, 0)}.merged(knees)
	var after := under.merged({"pivot": Vector3(-0.16, 0, 0.1), "torso": Vector3(-0.22, -0.38, 0.12), "head": Vector3(0.1, 0.32, 0),
		"_scale": Vector3.ONE, "_smear": Vector3.ZERO}, true)
	var settle := {"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.6, 0, 0.14), "shin_r": Vector3(-1.1, 0, 0)}.merged(h._guard())
	return [h._keys(u, [[0.0, {}], [0.2, wind, "out"], [0.3, wind], [0.44, under, "in"], [0.5, under, "out"], [0.64, after, "out"],
		[0.78, after], [1.0, settle]]), "full", Vector3.ZERO]


## Hit 1's body: load right with the blade overhead, then turn left down through the cut onto the
## front foot.
static func kesa(h, u: float) -> Array:
	var p := _kesa(h)
	return [h._keys(u, [[0.0, p["g"]], [0.32, p["load"], "out"], [0.42, p["cock"]], [0.47, p["whoosh"], "in"],
		[0.52, p["cut"], "out"], [0.66, p["follow"], "out"], [0.84, p["follow"]], [1.0, p["g"]]]), "full", Vector3.ZERO]


## Hit 2's body: from hit 1's follow-through, coiled to the left, then turning right through the
## level cut, stepping through on the right foot.
static func side(h, u: float) -> Array:
	var p := _side(h)
	return [h._keys(u, [[0.0, p["start"]], [0.24, p["gather"], "out"], [0.32, p["gather"]], [0.4, p["whoosh"], "in"],
		[0.47, p["cut"], "out"], [0.58, p["follow"], "out"], [0.8, p["follow"]], [1.0, p["g"]]]), "full", Vector3.ZERO]


## Hit 3's body: drawn back and coiled over the right hip, then a long lunge, the chest driven
## in behind the point.
static func stab(h, u: float) -> Array:
	var p := _side(h)
	var g: Dictionary = h._guard()
	var coil := {"pivot": Vector3(0.04, 0, 0), "hips": Vector3(0, -0.4, 0), "torso": Vector3(0.06, -0.55, 0.02), "head": Vector3(0.05, 0.5, 0),
		"leg_r": Vector3(0.3, 0, 0.1), "shin_r": Vector3(-0.85, 0, 0), "leg_l": Vector3(-0.35, 0, -0.1), "shin_l": Vector3(-0.85, 0, 0),
		"_lift": Vector3(0, -0.18, 0), "_scale": Vector3(1.05, 0.91, 1.04), "_smear": Vector3.ZERO}
	var drive := {"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.05, 0), "torso": Vector3(-0.4, 0.1, 0), "head": Vector3(0.38, -0.12, 0),
		"leg_r": Vector3(1.3, 0, 0.08), "shin_r": Vector3(-1.4, 0, 0), "leg_l": Vector3(-1.0, 0, -0.1), "shin_l": Vector3(-0.12, 0, 0),
		"_lift": Vector3(0, -0.36, 0), "_scale": Vector3(1.04, 0.95, 1.06), "_smear": Vector3.ZERO}
	var whoosh := SwordMoves._with(SwordMoves._mix(coil, drive, 0.6), Vector3(0.95, 1.0, 1.16), 0.6)
	return [h._keys(u, [[0.0, p["follow"]], [0.26, coil, "out"], [0.36, coil], [0.43, whoosh, "in"], [0.5, drive, "out"],
		[0.76, drive], [1.0, g]]), "full", Vector3.ZERO]


static func _kesa(h) -> Dictionary:
	var g: Dictionary = h._guard()
	var load := {"pivot": Vector3(0.06, 0, -0.04), "hips": Vector3(0, -0.22, 0), "torso": Vector3(0.14, -0.22, -0.06), "head": Vector3(-0.1, 0.3, 0.04),
		"leg_l": Vector3(0.45, 0, -0.14), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.3, 0, 0.14), "shin_r": Vector3(-0.55, 0, 0),
		"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(1.04, 0.92, 1.04), "_smear": Vector3.ZERO}
	var cock := load.merged({"torso": Vector3(0.16, -0.26, -0.08), "hips": Vector3(0, -0.25, 0), "_scale": Vector3(1.05, 0.9, 1.05)}, true)
	var cut := {"pivot": Vector3(-0.1, 0, 0.04), "hips": Vector3(0, 0.05, 0), "torso": Vector3(-0.32, 0.05, 0.04), "head": Vector3(0.2, -0.06, 0),
		"leg_l": Vector3(1.2, 0, -0.14), "shin_l": Vector3(-1.35, 0, 0), "leg_r": Vector3(-0.9, 0, 0.16), "shin_r": Vector3(-0.2, 0, 0),
		"_lift": Vector3(0, -0.32, 0), "_scale": Vector3(1.05, 0.94, 1.05), "_smear": Vector3.ZERO}
	var whoosh := SwordMoves._with(SwordMoves._mix(cock, cut, 0.5), Vector3(0.93, 1.06, 1.14), 0.7)
	# (a two-handed cut turns the chest less than a one-handed one: turned further, the hands ran
	# out to the left and the blade lay flat across the body instead of down through the front)
	var follow := cut.merged({"pivot": Vector3(-0.14, 0, 0.06), "hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.4, 0.2, 0.08),
		"head": Vector3(0.22, -0.3, 0), "_lift": Vector3(0, -0.34, 0), "_scale": Vector3.ONE}, true)
	return {"g": g, "load": load, "cock": cock, "whoosh": whoosh, "cut": cut, "follow": follow}


static func _side(h) -> Dictionary:
	var p := _kesa(h)
	var gather := {"pivot": Vector3(0.02, 0, 0.05), "hips": Vector3(0, 0.55, 0), "torso": Vector3(0.04, 0.6, 0.08), "head": Vector3(0.0, -0.6, -0.04),
		"leg_r": Vector3(0.45, 0, 0.14), "shin_r": Vector3(-0.85, 0, 0), "leg_l": Vector3(-0.3, 0, -0.14), "shin_l": Vector3(-0.6, 0, 0),
		"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.05, 0.91, 1.05), "_smear": Vector3.ZERO}
	var cut := {"pivot": Vector3(-0.06, 0, -0.04), "hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.22, -0.18, -0.05), "head": Vector3(0.12, 0.18, 0),
		"leg_r": Vector3(1.2, 0, 0.14), "shin_r": Vector3(-1.35, 0, 0), "leg_l": Vector3(-0.9, 0, -0.16), "shin_l": Vector3(-0.2, 0, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.04, 0.95, 1.04), "_smear": Vector3.ZERO}
	# (stretch along the cut, not up: the path rides the shoulders, a vertical bob under a level
	# cut makes it wobble)
	var whoosh := SwordMoves._with(SwordMoves._mix(gather, cut, 0.5), Vector3(0.94, 1.0, 1.15), 0.7)
	var follow := cut.merged({"pivot": Vector3(-0.08, 0, -0.06), "hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.28, -0.32, -0.1),
		"head": Vector3(0.15, 0.36, 0), "_lift": Vector3(0, -0.28, 0), "_scale": Vector3.ONE}, true)
	return {"g": p["g"], "start": p["follow"], "gather": gather, "whoosh": whoosh, "cut": cut, "follow": follow}
