class_name AxeMoves
## The axe's light combo on swing paths (KatanaMoves' recipe): the right hand rides the path,
## the bit leading like a sword's edge; the off hand rides a reach path on the one-handed hacks,
## and Humanoid._axe_hands puts it on the haft for the two-handed split. Points are offsets from
## the shoulder in the chest's frame (x+ right, y up, z+ back; "from_shoulder", "follow" 1), so
## "r" is the reach. Heavier than the katana: deeper lunges, more squash, a longer hold.
## Turns: y- faces right, y+ left; the head counters the chest to stay on the target.

## The mastered guard (Humanoid.guard2), held in both hands by PoleMoves.hands from its grips ([right hand, haft
## toward the head, the bit's way, the left hand's slide], the chest's frame), the arms here only seeding the IK.
## The Bearded Guard (Zach's pick, 2026-10-22): square and compact, choked up two-handed across the front, the right
## hand low by the hip, the head up past the left shoulder with the bit out (so it shows from behind).
const GUARD2 := {"hips": Vector3(0, 0.12, 0), "torso": Vector3(-0.14, 0.08, 0), "head": Vector3(0.12, -0.12, 0),
	"arm_r": Vector3(0.4, 0.0, 0.3), "fore_r": Vector3(1.2, 0, 0), "hand_r": Vector3.ZERO,
	"arm_l": Vector3(1.2, 0.3, -0.2), "fore_l": Vector3(1.4, 0, 0), "hand_l": Vector3.ZERO}
const LEGS2 := {"leg_l": Vector3(0.3, 0, -0.26), "leg_r": Vector3(-0.15, 0, 0.26), "shin_l": Vector3(-0.7, 0, 0), "shin_r": Vector3(-0.6, 0, 0),
	"_lift": Vector3(0, -0.16, 0)}
## [guard, block, run] grips.
const GRIPS2 := [[Vector3(0.2, -0.32, -0.3), Vector3(-0.76, 0.65, 0.04), Vector3(-0.2, 0.2, -0.95), 0.46],
	[Vector3(0.3, -0.2, -0.4), Vector3(-0.82, 0.55, -0.15), Vector3(0, 0, -1), 0.45],
	[Vector3(0.26, -0.48, -0.22), Vector3(-0.74, 0.64, -0.18), Vector3(0, 0, -1), 0.5]]


static func guard(h) -> Dictionary:
	return GUARD2 if h.guard2 else Humanoid.AXE_GUARD


static func legs(h) -> Dictionary:
	return LEGS2 if h.guard2 else Humanoid.STANCE_LEGS["axe"]


## Hit 1, the hack: from the guard the axe is hauled up round the right side and over the right
## shoulder (the head laid back behind it), a beat, then hacked down through the front at a
## slant and on low past the left hip.
const HACK_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.02, "plane": Vector3(-0.8, 0.6, 0.0), "plane_from": 2, "keys": [
	[0.04, {"dir": Vector3(0.14, -0.68, -0.72), "r": 0.5, "break": 1.0}],
	[0.16, {"dir": Vector3(0.3, 0.3, -0.9), "r": 0.5, "break": 1.0}],
	[0.3, {"dir": Vector3(0.25, 0.9, -0.36), "r": 0.47, "break": 1.25}, "smooth"],
	[0.37, {"dir": Vector3(0.24, 0.88, -0.4), "r": 0.48, "break": 1.3}, "in"],
	[0.46, {"dir": Vector3(-0.25, -0.15, -0.95), "r": 0.63, "break": 0.35}],
	[0.53, {"dir": Vector3(-0.38, -0.7, -0.6), "r": 0.62, "break": 0.12}],
	[0.62, {"dir": Vector3(-0.42, -0.8, -0.42), "r": 0.6, "break": 0.15}, "out"]]}
## The off hand: from the guard out toward the target on the wind-up, then pulled back and out
## past the left hip against the cut.
const HACK_REACH := {"hand": "l", "follow": 1.0, "from_shoulder": true, "lag": 0.04, "pole": Vector3(-1.0, -0.35, 0.25),
	"center": Vector3.ZERO, "keys": [
	[0.04, {"dir": Vector3(-0.34, -0.33, -0.15)}],
	[0.3, {"dir": Vector3(-0.2, 0.05, -0.58)}, "smooth"],
	[0.38, {"dir": Vector3(-0.22, 0.02, -0.57)}],
	[0.5, {"dir": Vector3(-0.47, -0.3, -0.05)}],
	[0.6, {"dir": Vector3(-0.45, -0.35, 0.2), "pole": Vector3(-0.3, -1.0, 0.3)}],
	[0.7, {"dir": Vector3(-0.45, -0.35, 0.2), "pole": Vector3(-0.3, -1.0, 0.3)}, "out"]]}

## Hit 2, the hook: from hit 1's low finish the axe drops back low at the left (the beard
## cocked behind), then is ripped up across the front and out high on the right.
const HOOK_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.02, "plane_from": 1, "keys": [
	[0.0, {"dir": Vector3(-0.42, -0.8, -0.42), "r": 0.6, "break": 0.15}],
	[0.2, {"dir": Vector3(-0.75, -0.55, -0.2), "r": 0.55, "break": 1.15}, "smooth"],
	[0.3, {"dir": Vector3(-0.74, -0.58, -0.16), "r": 0.55, "break": 1.25}, "in"],
	[0.42, {"dir": Vector3(0.05, -0.3, -0.95), "r": 0.63, "break": 0.45}],
	[0.5, {"dir": Vector3(0.62, 0.25, -0.74), "r": 0.6, "break": 0.2}],
	[0.6, {"dir": Vector3(0.7, 0.6, -0.38), "r": 0.55, "break": 0.2}, "out"]]}
## The off hand from hit 1's fling, in toward the belly as the body coils, then flung out back
## at the left against the rising cut.
const HOOK_REACH := {"hand": "l", "follow": 1.0, "from_shoulder": true, "lag": 0.04, "pole": Vector3(-1.0, -0.35, 0.25),
	"center": Vector3.ZERO, "keys": [
	[0.0, {"dir": Vector3(-0.45, -0.35, 0.2), "pole": Vector3(-0.3, -1.0, 0.3)}],
	[0.2, {"dir": Vector3(-0.1, -0.45, -0.35)}, "smooth"],
	[0.3, {"dir": Vector3(-0.12, -0.45, -0.34)}],
	[0.42, {"dir": Vector3(-0.5, -0.3, 0.1), "pole": Vector3(-0.3, -1.0, 0.3)}],
	[0.52, {"dir": Vector3(-0.5, -0.25, 0.3), "pole": Vector3(-0.3, -1.0, 0.3)}],
	[0.66, {"dir": Vector3(-0.5, -0.25, 0.3), "pole": Vector3(-0.3, -1.0, 0.3)}, "out"]]}

## Hit 3, the split (two-handed): from hit 2's high finish the axe goes up over the head and is
## laid back behind it through the hop, a beat at the top, then smashed straight down through the
## front into the ground ahead and held there, bitten in.
const SPLIT_SWING := {"from_shoulder": true, "follow": 1.0, "center": Vector3.ZERO, "lag": 0.01, "plane": Vector3(-1, 0, 0),
	"cut": Vector3.DOWN, "keys": [
	[0.0, {"dir": Vector3(0.7, 0.6, -0.38), "r": 0.55, "break": 0.2}],
	[0.3, {"dir": Vector3(-0.05, 0.92, -0.38), "r": 0.48, "break": 1.3}, "smooth"],
	[0.42, {"dir": Vector3(-0.06, 0.9, -0.42), "r": 0.49, "break": 1.38}, "in"],
	[0.48, {"dir": Vector3(-0.18, 0.2, -0.96), "r": 0.62, "break": 0.7}],
	[0.53, {"dir": Vector3(-0.22, -0.6, -0.77), "r": 0.63, "break": 0.3}],
	[0.64, {"dir": Vector3(-0.22, -0.72, -0.65), "r": 0.6, "break": 0.25}, "out"],
	[0.72, {"dir": Vector3(-0.22, -0.72, -0.65), "r": 0.6, "break": 0.25}]]}


## Hit 1's body: rocked back and turned right under the raised axe, then driven down through
## the hack into a deep lunge on the front foot, the chest turning left after it.
static func hack(h, u: float) -> Array:
	var g: Dictionary = h._guard()
	var load := {"pivot": Vector3(0.08, 0, -0.04), "hips": Vector3(0, -0.3, 0), "torso": Vector3(0.18, -0.4, -0.08), "head": Vector3(-0.12, 0.35, 0.04),
		"leg_l": Vector3(0.4, 0, -0.14), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.25, 0, 0.14), "shin_r": Vector3(-0.7, 0, 0),
		"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(1.05, 0.9, 1.05), "_smear": Vector3.ZERO}
	var cock := load.merged({"torso": Vector3(0.22, -0.45, -0.1), "hips": Vector3(0, -0.34, 0), "_scale": Vector3(1.06, 0.88, 1.06)}, true)
	var cut := {"pivot": Vector3(-0.14, 0, 0.04), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.42, 0.12, 0.05), "head": Vector3(0.3, -0.12, 0),
		"leg_l": Vector3(1.15, 0, -0.12), "shin_l": Vector3(-1.25, 0, 0), "leg_r": Vector3(-0.9, 0, 0.14), "shin_r": Vector3(-0.2, 0, 0),
		"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.07, 0.91, 1.06), "_smear": Vector3.ZERO}
	var whoosh := SwordMoves._with(SwordMoves._mix(cock, cut, 0.5), Vector3(0.93, 1.07, 1.14), 0.7)
	var follow := cut.merged({"pivot": Vector3(-0.2, 0, 0.06), "hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.5, 0.45, 0.1),
		"head": Vector3(0.32, -0.4, 0), "_lift": Vector3(0, -0.36, 0), "_scale": Vector3.ONE}, true)
	return [h._keys(u, [[0.0, g], [0.3, load, "out"], [0.37, cock], [0.42, whoosh, "in"], [0.47, cut, "out"], [0.6, follow, "out"],
		[0.82, follow], [1.0, g]]), "full", Vector3.ZERO]


## Hit 2's body: from hit 1's follow-through, sunk low and coiled to the left over the dropped axe,
## then rising and turning right through the hook, stepping through on the right foot.
static func hook(h, u: float) -> Array:
	var g: Dictionary = h._guard()
	var start: Dictionary = hack(h, 0.82)[0]
	var gather := {"pivot": Vector3(0.02, 0, 0.06), "hips": Vector3(0, 0.5, 0), "torso": Vector3(-0.25, 0.55, 0.08), "head": Vector3(0.25, -0.55, 0),
		"leg_l": Vector3(0.6, 0, -0.14), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.35, 0, 0.14), "shin_r": Vector3(-0.8, 0, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.9, 1.05), "_smear": Vector3.ZERO}
	var cut := {"pivot": Vector3(0.04, 0, -0.04), "hips": Vector3(0, -0.15, 0), "torso": Vector3(0.05, -0.25, -0.06), "head": Vector3(-0.05, 0.25, 0),
		"leg_r": Vector3(1.0, 0, 0.12), "shin_r": Vector3(-1.0, 0, 0), "leg_l": Vector3(-0.7, 0, -0.12), "shin_l": Vector3(-0.3, 0, 0),
		"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(1.03, 0.98, 1.03), "_smear": Vector3.ZERO}
	var whoosh := SwordMoves._with(SwordMoves._mix(gather, cut, 0.5), Vector3(0.95, 1.06, 1.06), 0.7)
	var follow := cut.merged({"pivot": Vector3(0.08, 0, -0.06), "hips": Vector3(0, -0.4, 0), "torso": Vector3(0.12, -0.5, -0.1),
		"head": Vector3(-0.12, 0.45, 0), "_lift": Vector3(0, -0.1, 0), "_scale": Vector3.ONE}, true)
	return [h._keys(u, [[0.0, start], [0.22, gather, "out"], [0.3, gather], [0.37, whoosh, "in"], [0.43, cut, "out"], [0.55, follow, "out"],
		[0.78, follow], [1.0, g]]), "full", Vector3.ZERO]


## Hit 3's body: coiled under the axe as it goes up, a hop with the body stretched up and leaning
## back at the top, then folded down over the smash into a deep lunge, squashed on the bite,
## held, and back up.
static func split(h, u: float) -> Array:
	var g: Dictionary = h._guard()
	var start: Dictionary = hook(h, 0.78)[0]
	var raise := {"pivot": Vector3(0.1, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.3, -0.05, 0), "head": Vector3(-0.15, 0, 0),
		"leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(0.3, 0, 0.15), "shin_r": Vector3(-1.1, 0, 0),
		"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.06, 0.9, 1.04), "_smear": Vector3.ZERO}
	var air := raise.merged({"pivot": Vector3(0.12, 0, 0), "torso": Vector3(0.35, 0, 0), "head": Vector3(-0.2, 0, 0),
		"leg_l": Vector3(1.0, 0, -0.1), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(0.2, 0, 0.1), "shin_r": Vector3(-0.9, 0, 0),
		"_lift": Vector3(0, 0.18, 0), "_scale": Vector3(0.96, 1.06, 0.98)}, true)
	var smash := {"pivot": Vector3(-0.12, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.6, 0, 0), "head": Vector3(0.4, 0, 0),
		"leg_l": Vector3(1.15, 0, -0.1), "shin_l": Vector3(-1.25, 0, 0), "leg_r": Vector3(-0.85, 0, 0.1), "shin_r": Vector3(-0.15, 0, 0),
		"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.08, 0.88, 1.06), "_smear": Vector3.ZERO}
	var whoosh := SwordMoves._with(SwordMoves._mix(air, smash, 0.5), Vector3(0.95, 1.08, 1.08), 0.8)
	var held := smash.merged({"_scale": Vector3.ONE}, true)
	return [h._keys(u, [[0.0, start], [0.3, raise, "out"], [0.42, air], [0.48, whoosh, "in"], [0.53, smash, "out"], [0.62, held],
		[0.76, held], [1.0, g]]), "full", Vector3.ZERO]
