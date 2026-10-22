class_name KatanaMoves
## The katana's light combo on swing paths (the cutlass's SwordMoves recipe, two-handed: the
## right hand rides the path, Humanoid._katana_hands puts the left on the hilt behind it).
## Points are offsets from the sword shoulder in the chest's frame (x+ right, y up, z+ back;
## "from_shoulder", "follow" 1), so "r" is the reach (~0.64 locked, 0.6 a little bent, 0.5
## ~1.1 rad) and the chest's turn carries the hands through the cut.
## Turns: y- faces right, y+ left; the head counters the chest to stay on the target.

## The mastered guard (Humanoid.guard2): the right hand and the blade held by PoleMoves.hands from its grips ([right
## hand, the blade's way, its edge's way, -1: one hand], the chest's frame), _katana_hands putting the left on the hilt
## behind it; the arms here only seed the IK. Two candidates for Zach's pick (`preview`): "a" hasso, the hilt by the
## right cheek and the blade standing up and back, left foot forward; "b" waki, side on, the blade low and back behind
## the right hip, its point trailing, its length hidden from the foe.
static var preview := "a"
const GUARD2 := {
	"a": {"hips": Vector3(0, -0.3, 0), "torso": Vector3(0.02, -0.25, 0), "head": Vector3(0.0, 0.4, 0),
		"arm_r": Vector3(1.6, 0.4, 0.5), "fore_r": Vector3(1.8, 0, 0), "hand_r": Vector3.ZERO,
		"arm_l": Vector3(1.4, -0.4, -0.1), "fore_l": Vector3(1.6, 0, 0)},
	"b": {"hips": Vector3(0, -0.55, 0), "torso": Vector3(-0.12, -0.45, 0), "head": Vector3(0.08, 0.75, 0),
		"arm_r": Vector3(-0.2, 0.0, 0.3), "fore_r": Vector3(0.6, 0, 0), "hand_r": Vector3.ZERO,
		"arm_l": Vector3(0.2, 0.3, -0.1), "fore_l": Vector3(1.2, 0, 0)}}
const LEGS2 := {
	"a": {"leg_l": Vector3(0.45, 0, -0.18), "leg_r": Vector3(-0.3, 0, 0.18), "shin_l": Vector3(-0.85, 0, 0), "shin_r": Vector3(-0.7, 0, 0), "_lift": Vector3(0, -0.2, 0)},
	"b": {"leg_l": Vector3(0.55, 0, -0.26), "leg_r": Vector3(-0.4, 0, 0.26), "shin_l": Vector3(-1.1, 0, 0), "shin_r": Vector3(-0.6, 0, 0), "_lift": Vector3(0, -0.27, 0)}}
## [guard, block, run] grips.
const GRIPS2 := {
	"a": [[Vector3(0.14, 0.06, -0.2), Vector3(0.12, 0.95, 0.28), Vector3(0, 0, -1), -1.0],
		[Vector3(0.1, 0.0, -0.4), Vector3(-0.9, 0.4, -0.1), Vector3(0, 1, 0), -1.0],
		[Vector3(0.14, 0.06, -0.2), Vector3(0.12, 0.95, 0.28), Vector3(0, 0, -1), -1.0]],
	"b": [[Vector3(0.22, -0.48, 0.08), Vector3(0.25, -0.45, 0.86), Vector3(0, 1, 0), -1.0],
		[Vector3(0.1, 0.0, -0.4), Vector3(-0.9, 0.4, -0.1), Vector3(0, 1, 0), -1.0],
		[Vector3(0.22, -0.48, 0.08), Vector3(0.25, -0.45, 0.86), Vector3(0, 1, 0), -1.0]]}


static func guard(h) -> Dictionary:
	return GUARD2[preview] if h.guard2 else Humanoid.KATANA_GUARD


static func legs(h) -> Dictionary:
	return LEGS2[preview] if h.guard2 else Humanoid.STANCE_LEGS["katana"]


static func grips2() -> Array:
	return GRIPS2[preview]


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


## Falling Moon (the air attack's second version): both hands raise the blade straight up overhead, then the body
## turns over forward once with the arms and blade held out along it, so the point draws a full circle (the moon),
## and opens out of the turn with the blade cut down ahead, knees tucked under, falling.
static func moon(h, u: float) -> Array:
	var tuck := {"leg_l": Vector3(1.4, 0, -0.14), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(1.2, 0, 0.14), "shin_r": Vector3(-1.9, 0, 0)}
	var raise := {"hips": Vector3.ZERO, "torso": Vector3(0.2, 0, 0), "head": Vector3(-0.2, 0, 0),
		"arm_r": Vector3(2.95, 0.1, 0.15), "fore_r": Vector3(0.25, 0, 0), "hand_r": Vector3(-0.35, 0, 0),
		"arm_l": Vector3(2.85, -0.15, -0.1), "fore_l": Vector3(0.35, 0, 0), "_scale": Vector3(0.96, 1.07, 0.98), "_smear": Vector3.ZERO}.merged(tuck)
	var out := raise.merged({"torso": Vector3(-0.1, 0, 0), "head": Vector3(0.1, 0, 0), "arm_r": Vector3(2.6, 0.05, 0.12),
		"arm_l": Vector3(2.5, -0.1, -0.1), "_scale": Vector3(1.0, 1.0, 1.0), "_smear": Vector3(0.5, 0, 0)}, true)
	var cut := {"hips": Vector3.ZERO, "torso": Vector3(-0.55, 0, 0), "head": Vector3(0.35, 0, 0),
		"arm_r": Vector3(1.35, 0.05, 0.1), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-0.7, 0, 0),
		"arm_l": Vector3(1.4, -0.1, -0.05), "fore_l": Vector3(0.25, 0, 0), "_scale": Vector3(1.03, 0.96, 1.04), "_smear": Vector3.ZERO,
		"leg_l": Vector3(1.0, 0, -0.14), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.5, 0, 0.14), "shin_r": Vector3(-1.2, 0, 0)}
	var pose: Dictionary = h._keys(u, [[0.0, {}], [0.18, raise, "out"], [0.26, raise], [0.5, out, "linear"], [0.72, cut, "in"], [1.0, cut]])
	pose["pivot"] = Vector3(-TAU * Humanoid._ease(clampf((u - 0.24) / 0.5, 0.0, 1.0)), 0, 0)
	return [pose, "full", Vector3.ZERO]


## Falling Moon's landing: down on one knee with the blade laid out low along the ground ahead (the crescent goes
## out from it), held, then up to the guard.
static func moon_land(h, u: float) -> Array:
	var kneel := {"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.45, 0.2, 0), "head": Vector3(0.35, -0.2, 0),
		"arm_r": Vector3(1.0, 0.1, 0.25), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
		"arm_l": Vector3(1.05, -0.15, -0.05), "fore_l": Vector3(0.35, 0, 0),
		"leg_l": Vector3(1.2, 0, -0.14), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(-0.2, 0, 0.14), "shin_r": Vector3(-2.0, 0, 0),
		"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.06, 0.9, 1.04)}
	var held := kneel.merged({"_scale": Vector3.ONE}, true)
	return [h._keys(u, [[0.0, kneel], [0.12, held], [0.55, held], [1.0, h._guard()]]), "full", Vector3.ZERO]


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


# --------------------------------------------------------------------------
# The techniques: each cut on a swing path (the follow-through held by a last key on the same
# point), the body keyed here
# --------------------------------------------------------------------------
## Tiger Rush (SkillState, 0.55 s; the dash runs to 0.38 s): run low with the hands drawn back by
## the right hip, the blade trailing level behind, then one drawing cut flat across the front to
## the left as the dash ends (u 0.6-0.76), held.
const TIGER_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.01, "plane": Vector3(0, 1, 0),
	"cut": Vector3.LEFT, "keys": [
	[0.0, {"dir": Vector3(-0.52, -0.34, -0.78), "r": 0.5, "break": 1.0}],
	[0.16, {"dir": Vector3(0.45, -0.75, 0.48), "r": 0.5, "break": 1.2}, "smooth"],
	[0.5, {"dir": Vector3(0.5, -0.7, 0.5), "r": 0.5, "break": 1.25}],
	[0.6, {"dir": Vector3(0.75, -0.3, -0.58), "r": 0.6, "break": 0.8}, "in"],
	[0.68, {"dir": Vector3(-0.1, -0.2, -0.97), "r": 0.63, "break": 0.35}],
	[0.76, {"dir": Vector3(-0.8, -0.25, -0.55), "r": 0.6, "break": 0.15}, "out"],
	[0.82, {"dir": Vector3(-0.8, -0.25, -0.55), "r": 0.6, "break": 0.15}]]}

## Wind Severer (0.75 s, the wave leaves at 0.34 s = u 0.45): the blade swung down low behind the
## right foot, a beat, then one rising cut up across the front to high on the left.
const SEVER_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.01, "plane_from": 1, "keys": [
	[0.0, {"dir": Vector3(-0.52, -0.34, -0.78), "r": 0.5, "break": 1.0}],
	[0.3, {"dir": Vector3(0.45, -0.8, 0.4), "r": 0.6, "break": 1.1}, "smooth"],
	[0.37, {"dir": Vector3(0.42, -0.82, 0.34), "r": 0.6, "break": 1.15}, "in"],
	[0.45, {"dir": Vector3(0.0, -0.45, -0.9), "r": 0.63, "break": 0.5}],
	[0.52, {"dir": Vector3(-0.4, 0.45, -0.8), "r": 0.6, "break": 0.2}],
	[0.6, {"dir": Vector3(-0.35, 0.85, -0.38), "r": 0.52, "break": 0.2}, "out"],
	[0.72, {"dir": Vector3(-0.35, 0.85, -0.38), "r": 0.52, "break": 0.2}]]}

## Phantom Step's cut (0.6 s, the cut at 0.16 s = u 0.27): arrived crouched behind them with the
## hands low at the left, then one flat cut round to the right.
const PHANTOM_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.01, "plane": Vector3(0, -1, 0),
	"cut": Vector3.RIGHT, "keys": [
	[0.0, {"dir": Vector3(-0.7, -0.5, -0.5), "r": 0.5, "break": 1.1}],
	[0.12, {"dir": Vector3(-0.75, -0.45, -0.45), "r": 0.5, "break": 1.2}, "smooth"],
	[0.2, {"dir": Vector3(-0.45, -0.25, -0.85), "r": 0.58, "break": 0.8}, "in"],
	[0.27, {"dir": Vector3(0.1, -0.2, -0.98), "r": 0.63, "break": 0.4}],
	[0.34, {"dir": Vector3(0.65, -0.2, -0.73), "r": 0.6, "break": 0.2}],
	[0.42, {"dir": Vector3(0.85, -0.2, -0.45), "r": 0.56, "break": 0.15}, "out"],
	[0.62, {"dir": Vector3(0.85, -0.2, -0.45), "r": 0.56, "break": 0.15}]]}

## The drawing cut (iai_slash: the heavy's release, Iai Counter's answer; played 0.6-0.78 s): out of
## the scabbard at the left hip and one flat cut round to the right (contact ~0.08 s).
const IAI_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.0, "plane": Vector3(0, -1, 0),
	"cut": Vector3.RIGHT, "keys": [
	[0.0, {"dir": Vector3(-0.7, -0.66, -0.25), "r": 0.6, "break": 1.3}],
	[0.06, {"dir": Vector3(-0.5, -0.45, -0.74), "r": 0.6, "break": 0.6}, "in"],
	[0.13, {"dir": Vector3(0.32, -0.25, -0.91), "r": 0.63, "break": 0.15}],
	[0.2, {"dir": Vector3(0.7, -0.2, -0.68), "r": 0.6, "break": 0.15}],
	[0.28, {"dir": Vector3(0.85, -0.18, -0.48), "r": 0.57, "break": 0.15}, "out"],
	[0.6, {"dir": Vector3(0.85, -0.18, -0.48), "r": 0.57, "break": 0.15}]]}

## Thousand Petals' drawing cut (petal_storm, 2.0 s: the blade leaves the scabbard at 0.44 s, cuts at
## 0.46 s; keys in u of the 2 s): out of the scabbard at the left hip and one flat cut round to the
## right, held a moment; then the arm turns back to the posed flick and the slow sheathe.
const PETAL_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.0, "plane": Vector3(0, -1, 0),
	"cut": Vector3.RIGHT, "keys": [
	[0.195, {"dir": Vector3(-0.7, -0.66, -0.25), "r": 0.6, "break": 1.3}],
	[0.215, {"dir": Vector3(-0.5, -0.42, -0.76), "r": 0.6, "break": 0.6}, "in"],
	[0.232, {"dir": Vector3(0.32, -0.22, -0.92), "r": 0.63, "break": 0.15}],
	[0.25, {"dir": Vector3(0.75, -0.16, -0.64), "r": 0.6, "break": 0.15}],
	[0.28, {"dir": Vector3(0.88, -0.12, -0.46), "r": 0.57, "break": 0.15}, "out"],
	[0.36, {"dir": Vector3(0.88, -0.12, -0.46), "r": 0.57, "break": 0.15}]]}


## Tiger Rush's body: dropped into a long low run-lunge, leaning in, the chest turned a little right
## over the trailing blade, then turned left through the drawing cut and held.
static func tiger(h, u: float) -> Array:
	var g: Dictionary = h._guard()
	var low := {"pivot": Vector3(-0.32, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.28, -0.3, 0.02), "head": Vector3(0.5, 0.28, 0),
		"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-1.25, 0, 0), "leg_r": Vector3(-0.8, 0, 0.12), "shin_r": Vector3(-0.45, 0, 0),
		"_lift": Vector3(0, -0.32, 0), "_scale": Vector3(1.03, 0.94, 1.08), "_smear": Vector3.ZERO}
	var cut := low.merged({"pivot": Vector3(-0.2, 0, 0), "hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.25, 0.35, 0.04), "head": Vector3(0.35, -0.3, 0),
		"_scale": Vector3(1.04, 0.95, 1.04)}, true)
	var whip := SwordMoves._with(SwordMoves._mix(low, cut, 0.5), Vector3(0.95, 1.0, 1.15), 0.7)
	return [h._keys(u, [[0.0, g], [0.14, low, "out"], [0.55, low], [0.63, whip, "in"], [0.7, cut, "out"], [0.86, cut], [1.0, g]]), "full", Vector3.ZERO]


## Wind Severer's body: coiled low over the right foot with the blade, then rising up onto the
## front foot and turning left with the cut.
static func sever(h, u: float) -> Array:
	var g: Dictionary = h._guard()
	var low := {"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, -0.35, 0), "torso": Vector3(-0.32, -0.42, 0.06), "head": Vector3(0.3, 0.4, 0),
		"leg_l": Vector3(0.5, 0, -0.14), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.4, 0, 0.14), "shin_r": Vector3(-0.85, 0, 0),
		"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.04, 0.93, 1.02), "_smear": Vector3.ZERO}
	var rise := {"pivot": Vector3(0.04, 0, 0), "hips": Vector3(0, 0.25, 0), "torso": Vector3(0.12, 0.3, -0.06), "head": Vector3(-0.1, -0.25, 0),
		"leg_l": Vector3(1.0, 0, -0.14), "shin_l": Vector3(-1.05, 0, 0), "leg_r": Vector3(-0.8, 0, 0.14), "shin_r": Vector3(-0.2, 0, 0),
		"_lift": Vector3(0, -0.06, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}
	# (stretched up along the cut, the blade smeared, on the one fast key)
	var whip := SwordMoves._with(SwordMoves._mix(low, rise, 0.5), Vector3(0.96, 1.07, 1.0), 0.7)
	return [h._keys(u, [[0.0, g], [0.28, low, "out"], [0.37, low], [0.44, whip, "in"], [0.5, rise, "out"], [0.74, rise], [1.0, g]]), "full", Vector3.ZERO]


## Phantom Step's body: arrived crouched low behind them, coiled left, then rising a little and
## turning right through the cut, held.
static func phantom(h, u: float) -> Array:
	var g: Dictionary = h._guard()
	var arrive := {"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.38, 0.35, 0.02), "head": Vector3(0.35, -0.35, 0),
		"leg_l": Vector3(0.65, 0, -0.15), "shin_l": Vector3(-1.25, 0, 0), "leg_r": Vector3(-0.2, 0, 0.15), "shin_r": Vector3(-1.2, 0, 0),
		"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.04, 0.93, 1.03), "_smear": Vector3.ZERO}
	var cut := {"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, -0.25, 0), "torso": Vector3(-0.3, -0.35, -0.05), "head": Vector3(0.25, 0.35, 0),
		"leg_l": Vector3(1.1, 0, -0.14), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.85, 0, 0.16), "shin_r": Vector3(-0.2, 0, 0),
		"_lift": Vector3(0, -0.26, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}
	var whip := SwordMoves._with(SwordMoves._mix(arrive, cut, 0.5), Vector3(0.95, 1.0, 1.15), 0.7)
	return [h._keys(u, [[0.0, arrive], [0.12, arrive], [0.22, whip, "in"], [0.28, cut, "out"], [0.65, cut], [1.0, g]]), "full", Vector3.ZERO]


## The drawing cut's body (iai_slash): from the drawing stance, driving forward low through the cut
## and turning right with it, the scabbard hand flung back; rising back to the guard at the end.
static func iai(h, u: float) -> Array:
	var cut := {"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.35, -0.35, 0.06), "head": Vector3(0.3, 0.3, 0),
		"arm_l": Vector3(-0.55, 0.0, -0.95), "fore_l": Vector3(0.35, 0, 0),
		"leg_l": Vector3(1.35, 0, -0.14), "shin_l": Vector3(-1.55, 0, 0), "leg_r": Vector3(-1.05, 0, 0.16), "shin_r": Vector3(-0.2, 0, 0),
		"_scale": Vector3.ONE, "_smear": Vector3.ZERO}
	var whip := cut.merged({"_scale": Vector3(0.95, 1.0, 1.14), "_smear": Vector3(0.7, 0, 0)}, true)
	var lift := Vector3(0, -0.4 * (1.0 - h._ease(clampf((u - 0.62) / 0.38, 0.0, 1.0))), 0)
	return [h._keys(u, [[0.0, h._iai_pose()], [0.08, whip, "in"], [0.16, cut, "out"], [0.62, cut], [1.0, h._guard()]]), "full", lift]
