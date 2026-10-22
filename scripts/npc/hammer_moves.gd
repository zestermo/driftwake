class_name HammerMoves
## The hammer (stance "hammer"): a warhammer, kanabo, mallet, maul or anchor in both hands, the right low on the
## haft by the butt and the left above it. Every hammer move ("ham_*", reached from Humanoid._action_pose) keys
## the body plus the same four grip channels as the polearm (PoleMoves: "_gr" the right hand, "_gd" the haft's
## direction, "_ge" which way the striking face looks, "_gs" the left hand's slide up the haft, < 0 one-handed;
## the chest's frame: x right, y up, z back), solved each frame by PoleMoves.hands. A power swing slides the
## top hand down to meet the bottom one at contact. Same joint conventions as humanoid.gd.

## [right hand, haft, face, left hand's slide] (chest frame). At rest: the haft lying on top of the right shoulder
## (~0.1 m over the joint), angled out a little so the head sits up behind it clear of the head, both hands in front.
const GUARD_GRIP := [Vector3(0.1, -0.19, -0.3), Vector3(0.2, 0.78, 0.59), Vector3(0, 0.6, -0.8), 0.24]
## Sprinting: carried on the shoulder in the right hand, the left arm free.
const TRAIL_GRIP := [Vector3(0.17, -0.12, -0.22), Vector3(0.13, 0.7, 0.7), Vector3(0, 0.7, -0.7), -1.0]
## The guard (block, parry): the haft up across the front, the head high to the left, the hands wide.
const BLOCK_GRIP := [Vector3(0.3, -0.2, -0.4), Vector3(-0.82, 0.55, -0.15), Vector3(0, 0, -1), 0.55]
const GRIPS := [GUARD_GRIP, BLOCK_GRIP, TRAIL_GRIP]
## Where (u) each move's head meets the ground (the states throw dust and rock there: HammerArts.thud).
const THUD := {"ham_smash": 0.53, "ham_spin": 0.72}

## The guard: a little side on, chest turned right under the weight on the shoulder, chin down.
const GUARD := {"hips": Vector3(0, -0.22, 0), "torso": Vector3(-0.1, -0.22, 0.02), "head": Vector3(0.08, 0.3, 0),
	"arm_r": Vector3(0.4, 0.1, 0.2), "fore_r": Vector3(1.2, 0, 0), "hand_r": Vector3.ZERO,
	"arm_l": Vector3(0.9, 0.5, -0.1), "fore_l": Vector3(1.4, 0, 0), "hand_l": Vector3.ZERO}
## The stance's feet (Humanoid.STANCE_LEGS): wide and low, planted, the weight down in the hips.
const LEGS := {"leg_l": Vector3(0.38, 0, -0.3), "leg_r": Vector3(-0.3, 0, 0.3), "shin_l": Vector3(-0.8, 0, 0), "shin_r": Vector3(-0.6, 0, 0),
	"_lift": Vector3(0, -0.18, 0)}
const BLOCK := {"hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.12, -0.05, 0), "head": Vector3(0.12, 0.1, 0),
	"arm_r": Vector3(1.0, 0.3, 0.3), "fore_r": Vector3(1.0, 0, 0), "arm_l": Vector3(1.2, -0.3, -0.3), "fore_l": Vector3(1.0, 0, 0)}

# action-key legs
const SET := {"leg_l": Vector3(0.4, 0, -0.3), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.32, 0, 0.3), "shin_r": Vector3(-0.6, 0, 0)}
const LUNGE := {"leg_l": Vector3(1.05, 0, -0.26), "shin_l": Vector3(-1.35, 0, 0), "leg_r": Vector3(-0.75, 0, 0.26), "shin_r": Vector3(-0.3, 0, 0)}
const STEP_R := {"leg_l": Vector3(-0.5, 0, -0.26), "shin_l": Vector3(-0.45, 0, 0), "leg_r": Vector3(0.9, 0, 0.26), "shin_r": Vector3(-1.05, 0, 0)}
const WIDE := {"leg_l": Vector3(0.5, 0, -0.5), "shin_l": Vector3(-1.05, 0, 0), "leg_r": Vector3(-0.3, 0, 0.5), "shin_r": Vector3(-0.95, 0, 0)}
const SQUAT := {"leg_l": Vector3(0.95, 0, -0.45), "shin_l": Vector3(-1.6, 0, 0), "leg_r": Vector3(0.2, 0, 0.45), "shin_r": Vector3(-1.4, 0, 0)}
const TUCK := {"leg_l": Vector3(1.5, 0, -0.15), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(1.1, 0, 0.15), "shin_r": Vector3(-1.7, 0, 0)}


static func _k(body: Dictionary, grip: Array) -> Dictionary:
	return PoleMoves._k(body, grip)


## The guard as an action key (every joint and channel).
static func _g() -> Dictionary:
	return _k(PoleMoves._p([GUARD, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.16, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), GUARD_GRIP)


static func pose(h, n: String, u: float) -> Array:
	return PoleMoves.take_grip(h, _pose(h, n, u))


## The overhead raise shared by the heavy, the air slam and the ultimate: both hands up over the head, the head
## of the hammer hanging behind it, the back arched.
static func _raised(body: Dictionary, grip: Array = RAISE_GRIP) -> Dictionary:
	return _k({"pivot": Vector3(0.1, 0, 0), "hips": Vector3(0, -0.05, 0), "torso": Vector3(0.25, -0.05, 0), "head": Vector3(-0.2, 0.05, 0),
		"_lift": Vector3(0, -0.06, 0), "_scale": Vector3(0.96, 1.07, 1.0), "_smear": Vector3.ZERO}.merged(body, true), grip)


const RAISE_GRIP := [Vector3(0.02, 0.28, -0.08), Vector3(0.0, 0.55, 0.83), Vector3(0, 0.83, -0.55), 0.4]
## The Earthquake's heave: the hands higher and further out in front of the face, the haft steeper, so it passes
## over the head instead of through it; reached through HEAVE_GRIP, the haft stood up in front of the face first.
const QUAKE_GRIP := [Vector3(0.04, 0.42, -0.24), Vector3(0.0, 0.75, 0.66), Vector3(0, 0.66, -0.75), 0.12]
const HEAVE_GRIP := [Vector3(0.1, 0.22, -0.38), Vector3(0.15, 0.95, 0.25), Vector3(0, 0.25, -0.97), 0.2]


## The blow driven into the ground ahead: bent deep over it, the head flat on the ground.
static func _slammed(body: Dictionary) -> Dictionary:
	return _k({"pivot": Vector3(-0.25, 0, 0), "hips": Vector3(0, -0.05, 0), "torso": Vector3(-0.5, -0.05, 0), "head": Vector3(0.45, 0.05, 0),
		"_lift": Vector3(0, -0.45, 0), "_scale": Vector3(1.08, 0.88, 1.04), "_smear": Vector3.ZERO}.merged(WIDE).merged(body, true),
		[Vector3(0.0, -0.22, -0.5), Vector3(0.0, 0.56, -0.83), Vector3(0, -0.83, -0.56), 0.2])


## Anvil Counter's brace: the head on the ground ahead, the haft upright, both hands stacked on the butt.
static func _anvil_key(sc: Vector3) -> Dictionary:
	return _k({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0, 0), "torso": Vector3(-0.22, 0, 0), "head": Vector3(0.25, 0, 0),
		"_lift": Vector3(0, -0.26, 0), "_scale": sc, "_smear": Vector3.ZERO}.merged(WIDE),
		[Vector3(0.0, -0.08, -0.42), Vector3(0.05, -0.97, -0.22), Vector3(0, 0.2, -0.98), 0.12])


static func _pose(h, n: String, u: float) -> Array:
	var g := _g()
	match n:
		"ham_stance":
			return [g, "full", Vector3.ZERO]
		# --- the combo ---
		"ham_smash":
			# hit 1: heaved up off the shoulder, the hands sliding apart at the top, then brought down across
			# the front from high right to low left, the top hand sliding down to meet the bottom one
			var wind := _k({"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, -0.4, 0), "torso": Vector3(0.12, -0.45, 0.05), "head": Vector3(-0.05, 0.65, 0),
				"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.98, 1.04, 1.0), "_smear": Vector3.ZERO}.merged(SET),
				[Vector3(0.18, 0.12, -0.12), Vector3(0.3, 0.75, 0.6), Vector3(-0.2, 0.3, -0.93), 0.42])
			# (the grip's channels are in the chest's frame: the lean forward already points them down)
			var strike := _k({"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.3, 0.25, 0), "head": Vector3(0.28, -0.3, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.06, 0.92, 1.02), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.0, -0.32, -0.45), Vector3(-0.3, -0.03, -0.95), Vector3(-0.1, -0.92, -0.39), 0.2])
			var whoosh := PoleMoves._whip(wind, strike, 0.55, Vector3(0.97, 1.02, 1.08), 0.1)
			return [h._keys(u, [[0.0, g], [0.3, wind, "out"], [0.4, wind], [0.47, whoosh, "in"], [0.53, strike, "out"], [0.72, strike], [1.0, g]]), "full", Vector3.ZERO]
		"ham_upper":
			# hit 2: from low on the left, the head swung up through the front to high right (an uppercut that
			# lifts them), stepping through on the right foot, and on up over the shoulder
			var low := _k({"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.3, 0.32, 0.05), "head": Vector3(0.25, -0.4, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.93, 1.0), "_smear": Vector3.ZERO}.merged(SET),
				[Vector3(-0.05, -0.38, -0.3), Vector3(-0.5, -0.5, -0.4), Vector3(0.55, 0.65, -0.5), 0.36])
			var cut := _k({"pivot": Vector3(0.02, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(0.12, -0.35, -0.05), "head": Vector3(-0.1, 0.45, 0),
				"_lift": Vector3(0, -0.06, 0), "_scale": Vector3(0.96, 1.07, 1.0), "_smear": Vector3.ZERO}.merged(STEP_R),
				[Vector3(0.15, -0.08, -0.4), Vector3(0.45, 0.75, -0.48), Vector3(0.2, 0.55, 0.8), 0.22])
			var follow := cut.merged({"hips": Vector3(0, -0.38, 0), "torso": Vector3(0.15, -0.45, -0.06), "head": Vector3(-0.12, 0.55, 0),
				"_gd": Vector3(0.45, 0.85, 0.25), "_gs": Vector3(0.3, 0, 0)}, true)
			var whoosh := PoleMoves._whip(low, cut, 0.55, Vector3(0.97, 1.06, 1.02), 0.1)
			return [h._keys(u, [[0.0, g], [0.24, low, "out"], [0.32, low], [0.4, whoosh, "in"], [0.47, cut, "out"], [0.6, follow, "out"], [0.74, follow], [1.0, g]]), "full", Vector3.ZERO]
		"ham_sweep":
			# hit 3: wound far round to the right with the head out behind that hip, then one flat swing at the
			# waist through the front and on round to the left, in a wide low stance (it breaks a guard)
			var wind := _k({"pivot": Vector3(0.02, 0, 0), "hips": Vector3(0, -0.65, 0), "torso": Vector3(-0.05, -0.6, 0.0), "head": Vector3(0.1, 1.0, 0),
				"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.05, 0.94, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.25, -0.32, 0.0), Vector3(0.75, -0.05, 0.66), Vector3(0.66, 0, -0.75), 0.4])
			var cut := _k({"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.18, 0.45, 0.0), "head": Vector3(0.12, -0.65, 0),
				"_lift": Vector3(0, -0.32, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.0, -0.32, -0.42), Vector3(-0.2, 0.0, -0.98), Vector3(-1, 0, 0.2), 0.18])
			var follow := cut.merged({"hips": Vector3(0, 0.7, 0), "torso": Vector3(-0.15, 0.75, 0.0), "head": Vector3(0.1, -1.0, 0),
				"_gd": Vector3(-0.86, 0.0, -0.5), "_ge": Vector3(-0.5, 0, 0.86)}, true)
			var whoosh := PoleMoves._whip(wind, cut, 0.5, Vector3(1.07, 0.97, 1.0), 0.14)
			return [h._keys(u, [[0.0, g], [0.28, wind, "out"], [0.38, wind], [0.46, whoosh, "in"], [0.52, cut, "linear"], [0.62, follow, "out"], [0.78, follow], [1.0, g]]), "full", Vector3.ZERO]
		"ham_spin":
			# hit 4 (Wrecking Spin): wound right, the hammer let out at arm's length and the whole body turned round
			# once behind it, then the head brought down onto the ground at the end of the turn
			var load := _k({"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, -0.5, 0), "torso": Vector3(-0.05, -0.55, 0), "head": Vector3(0.1, 0.8, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.04, 0.94, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.22, -0.32, -0.1), Vector3(0.8, -0.05, 0.6), Vector3(0.6, 0, -0.8), 0.22])
			var turn := _k({"pivot": Vector3(-0.05, 0, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.2, 0.15, 0), "head": Vector3(0.1, -0.1, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.97, 1.0), "_smear": Vector3(0.1, 0, 0)}.merged(WIDE),
				[Vector3(0.0, -0.3, -0.42), Vector3(-0.75, -0.08, -0.65), Vector3(-0.65, 0, 0.75), 0.2])
			var land := turn.merged({"pivot": Vector3(-0.2, 0, 0), "hips": Vector3(0, 0.5, 0), "torso": Vector3(-0.4, 0.5, 0), "head": Vector3(0.3, -0.6, 0),
				"_lift": Vector3(0, -0.4, 0), "_scale": Vector3(1.08, 0.9, 1.03), "_smear": Vector3.ZERO,
				"_gd": Vector3(-0.55, 0.13, -0.82), "_ge": Vector3(0, -0.83, -0.56)}, true)
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.2, load, "out"], [0.28, load], [0.34, turn, "in"], [0.64, turn, "linear"], [0.72, land, "in"], [0.86, land], [1.0, g]])
			var k := clampf((u - 0.28) / 0.42, 0.0, 1.0)
			pz["pivot"] = (pz["pivot"] as Vector3) + Vector3(-0.06 * sin(k * PI), TAU * k, 0)
			return [pz, "full", Vector3.ZERO]
		# --- the heavy ---
		"ham_heavy":
			# Earthquake: heaved up over the head with the back arched, a beat (the arms shaking under the
			# weight), then slammed straight down into the ground ahead
			var raise := _raised(SET, QUAKE_GRIP)
			var heave := PoleMoves._whip(g, raise, 0.5, Vector3(0.98, 1.035, 1.0), 0.0).merged(_k({}, HEAVE_GRIP), true)
			var tremble := raise.merged({"_gr": (raise["_gr"] as Vector3) + Vector3(0.006 * sin(h._t * 64.0), 0.008 * sin(h._t * 81.0), 0)}, true)
			var slam := _slammed({})
			var whoosh := PoleMoves._whip(raise, slam, 0.55, Vector3(0.96, 1.04, 1.06), 0.16)
			return [h._keys(u, [[0.0, g], [0.14, heave, "linear"], [0.28, raise, "out"], [0.44, tremble], [0.5, whoosh, "in"], [0.55, slam, "out"], [0.8, slam], [1.0, g]]), "full", Vector3.ZERO]
		# --- moving ---
		"ham_rush":
			# Rising Crush (attacked at a sprint): the head dragged low behind, then swung up off the ground in
			# one great rising arc through them
			var drag := _k({"pivot": Vector3(-0.25, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.35, -0.35, 0), "head": Vector3(0.35, 0.5, 0),
				"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.04, 0.93, 1.03), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.28, -0.45, 0.0), Vector3(0.45, -0.78, 0.43), Vector3(0, -0.45, -0.85), 0.36])
			var up := _k({"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, 0.1, 0), "torso": Vector3(0.15, 0.05, 0), "head": Vector3(-0.2, 0.0, 0),
				"_lift": Vector3(0, -0.04, 0), "_scale": Vector3(0.95, 1.08, 1.0), "_smear": Vector3.ZERO}.merged(STEP_R),
				[Vector3(0.1, -0.08, -0.42), Vector3(0.1, 0.85, -0.5), Vector3(0, 0.5, 0.85), 0.2])
			var over := up.merged({"_gd": Vector3(0.15, 0.95, 0.25), "torso": Vector3(0.2, 0.0, 0)}, true)
			var whoosh := PoleMoves._whip(drag, up, 0.5, Vector3(0.96, 1.08, 1.0), 0.14)
			return [h._keys(u, [[0.0, g], [0.16, drag, "out"], [0.3, drag], [0.38, whoosh, "in"], [0.46, up, "out"], [0.58, over, "out"], [0.72, over], [1.0, g]]), "full", Vector3.ZERO]
		"ham_dive":
			# Hammerfall: knees tucked with the hammer heaved up overhead, held there the whole way down
			var raise := _raised(TUCK)
			var fall := _raised({"pivot": Vector3(0.0, 0, 0), "torso": Vector3(0.15, 0, 0), "leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.0, 0, 0),
				"leg_r": Vector3(0.2, 0, 0.15), "shin_r": Vector3(-0.8, 0, 0), "_scale": Vector3(0.97, 1.05, 1.0)})
			return [h._keys(u, [[0.0, g], [0.3, raise, "out"], [0.55, raise], [0.75, fall], [1.0, fall]]), "full", Vector3.ZERO]
		"ham_land":
			# Hammerfall's landing: the hammer driven into the ground on impact, crouched deep over it
			var hit := _slammed(SQUAT)
			return [h._keys(u, [[0.0, hit], [0.55, hit.merged({"_scale": Vector3.ONE}, true)], [1.0, g]]), "full", Vector3.ZERO]
		# --- the techniques (HammerArts; keyed in seconds of the length they're played at) ---
		"ham_skull":
			# Skullcracker: a crouch, a hop with the hammer heaved up overhead, the head brought straight down on
			# the one in front as the feet land (HammerArts.SKULL_AT), then on down into the ground
			var T: float = float(h._action.get("dur", 0.9))
			var crouch := _k({"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.25, -0.1, 0), "head": Vector3(0.2, 0.1, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.9, 1.0), "_smear": Vector3.ZERO}.merged(SQUAT), GUARD_GRIP)
			var up := _raised(TUCK)
			var smash := _k({"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, 0.05, 0), "torso": Vector3(-0.3, 0.05, 0), "head": Vector3(0.3, 0, 0),
				"leg_l": Vector3(0.8, 0, -0.3), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(0.1, 0, 0.3), "shin_r": Vector3(-1.1, 0, 0),
				"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.06, 0.9, 1.03), "_smear": Vector3(0.14, 0, 0)},
				[Vector3(0.0, -0.12, -0.5), Vector3(0.0, -0.3, -0.95), Vector3(0, -0.95, 0.3), 0.2])
			var land := _slammed(SQUAT)
			return [h._keys(u, [[0.0, g], [0.08 / T, crouch, "out"], [0.24 / T, up, "out"], [0.32 / T, up], [0.46 / T, smash, "in"],
				[0.6 / T, land, "out"], [0.74 / T, land], [1.0, g]]), "full", Vector3.ZERO]
		"ham_quakes":
			# Rolling Quake (slams at HammerArts.QUAKES_AT): three different blows. 1: wound right with the head
			# out low behind the hip, swept flat across the front and into the ground at the left. 2: ripped back up
			# off the ground through the front to high right (a backhand uppercut), looped over the right shoulder and
			# chopped into the ground at the right. 3: a hop with it heaved overhead, straight down on landing.
			var T: float = float(h._action.get("dur", 1.5))
			var wind := _k({"pivot": Vector3(0.02, 0, 0), "hips": Vector3(0, -0.6, 0), "torso": Vector3(-0.05, -0.6, 0.0), "head": Vector3(0.1, 0.9, 0),
				"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.05, 0.94, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.25, -0.32, 0.0), Vector3(0.75, -0.05, 0.66), Vector3(0.66, 0, -0.75), 0.4])
			var across := _k({"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.18, 0.3, 0.0), "head": Vector3(0.12, -0.45, 0),
				"_lift": Vector3(0, -0.32, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.0, -0.32, -0.42), Vector3(-0.2, 0.0, -0.98), Vector3(-1, 0, 0.2), 0.18])
			var slam_l := _k({"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.35, 0.5, 0), "head": Vector3(0.3, -0.55, 0),
				"_lift": Vector3(0, -0.38, 0), "_scale": Vector3(1.07, 0.9, 1.03), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(-0.05, -0.38, -0.45), Vector3(-0.6, -0.6, -0.53), Vector3(0.45, -0.8, 0.4), 0.2])
			var back := _k({"pivot": Vector3(0.02, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(0.12, -0.35, -0.05), "head": Vector3(-0.1, 0.45, 0),
				"_lift": Vector3(0, -0.08, 0), "_scale": Vector3(0.96, 1.07, 1.0), "_smear": Vector3(0.1, 0, 0)}.merged(STEP_R),
				[Vector3(0.15, -0.08, -0.4), Vector3(0.45, 0.75, -0.48), Vector3(0.2, 0.55, 0.8), 0.22])
			var over := _k({"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, -0.4, 0), "torso": Vector3(0.12, -0.45, 0.05), "head": Vector3(-0.05, 0.6, 0),
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.98, 1.04, 1.0), "_smear": Vector3.ZERO}.merged(SET),
				[Vector3(0.18, 0.12, -0.12), Vector3(0.3, 0.75, 0.6), Vector3(-0.2, 0.3, -0.93), 0.42])
			var slam_r := _k({"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.35, -0.35, 0), "head": Vector3(0.3, 0.35, 0),
				"_lift": Vector3(0, -0.38, 0), "_scale": Vector3(1.07, 0.9, 1.03), "_smear": Vector3.ZERO}.merged(STEP_R),
				[Vector3(0.12, -0.38, -0.45), Vector3(0.45, -0.6, -0.66), Vector3(-0.34, -0.8, 0.5), 0.2])
			var hop := _raised(TUCK)
			var slam := _slammed(SQUAT)
			return [h._keys(u, [[0.0, g], [0.2 / T, wind, "out"], [0.26 / T, wind], [0.31 / T, PoleMoves._whip(wind, across, 0.6, Vector3(1.06, 0.97, 1.0), 0.14), "in"],
				[0.36 / T, slam_l, "out"], [0.46 / T, slam_l], [0.56 / T, back, "out"], [0.64 / T, over, "out"], [0.69 / T, over], [0.76 / T, slam_r, "in"],
				[0.86 / T, slam_r], [0.96 / T, hop, "out"], [1.06 / T, hop], [1.16 / T, slam, "in"], [1.36 / T, slam], [1.0, g]]), "full", Vector3.ZERO]
		"ham_cyclone":
			# Cyclone Crusher: wound right, the hammer let out at arm's length and the body turned round three
			# times behind it, walking, then the head brought down onto the ground at the end of the last turn
			var T: float = float(h._action.get("dur", 1.7))
			var s := u * T
			var load := _k({"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, -0.5, 0), "torso": Vector3(-0.05, -0.55, 0), "head": Vector3(0.1, 0.8, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.04, 0.94, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.22, -0.32, -0.1), Vector3(0.8, -0.05, 0.6), Vector3(0.6, 0, -0.8), 0.22])
			var turn := _k({"pivot": Vector3(-0.05, 0, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.15, 0.15, 0), "head": Vector3(0.1, -0.1, 0),
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(1.04, 0.97, 1.0), "_smear": Vector3(0.1, 0, 0)}.merged(WIDE),
				[Vector3(0.0, -0.28, -0.42), Vector3(-0.8, 0.0, -0.6), Vector3(-0.6, 0, 0.8), 0.2])
			var land := turn.merged({"pivot": Vector3(-0.2, 0, 0), "hips": Vector3(0, 0.5, 0), "torso": Vector3(-0.4, 0.5, 0), "head": Vector3(0.3, -0.6, 0),
				"_lift": Vector3(0, -0.4, 0), "_scale": Vector3(1.08, 0.9, 1.03), "_smear": Vector3.ZERO,
				"_gd": Vector3(-0.55, 0.13, -0.82), "_ge": Vector3(0, -0.83, -0.56)}, true)
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.2 / T, load, "out"], [0.26 / T, load], [0.34 / T, turn, "in"], [1.28 / T, turn, "linear"],
				[1.38 / T, land, "in"], [1.56 / T, land], [1.0, g]])
			var k := clampf((s - 0.26) / 1.06, 0.0, 1.0)
			pz["pivot"] = (pz["pivot"] as Vector3) + Vector3(0, TAU * 3.0 * k, 0)
			# (the head's orbit tilted, rising behind and dipping in front of each turn, so the three turns read)
			var tilt := sin(TAU * 3.0 * k) * sin(k * PI)
			pz["_gd"] = ((pz["_gd"] as Vector3) + Vector3(0, 0.45 * tilt, 0)).normalized()
			pz["torso"] = (pz["torso"] as Vector3) + Vector3(0, 0, -0.12 * tilt)
			pz["_lift"] = (pz["_lift"] as Vector3) + Vector3(0, 0.04 * absf(tilt), 0)
			return [pz, "full", Vector3.ZERO]
		"ham_titan":
			# Titan's Fall, the way up: a deep crouch, then up with the knees tucked and the hammer heaved overhead,
			# held there (the landing plays ham_land)
			var crouch := _k({"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.3, -0.1, 0), "head": Vector3(0.25, 0.1, 0),
				"_lift": Vector3(0, -0.38, 0), "_scale": Vector3(1.07, 0.88, 1.0), "_smear": Vector3.ZERO}.merged(SQUAT), GUARD_GRIP)
			var up := _raised(TUCK)
			return [h._keys(u, [[0.0, g], [0.15, crouch, "out"], [0.2, crouch], [0.34, up, "out"], [1.0, up]]), "full", Vector3.ZERO]
		"ham_drive":
			# Cannonball Swing (contact at HammerArts.DRIVE_AT): turned away with the hammer taken back high behind
			# the right shoulder, swept down past the ground by the right foot and up through them at the waist (the
			# weight onto the front foot), on up over the left shoulder, the right heel up
			var T: float = float(h._action.get("dur", 1.1))
			var top := _k({"pivot": Vector3(0.0, 0, 0), "hips": Vector3(0, -0.5, 0), "torso": Vector3(0.05, -0.8, 0.05), "head": Vector3(0.15, 0.85, 0),
				"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.03, 0.95, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(0.3, 0.12, 0.0), Vector3(0.35, 0.3, 0.89), Vector3(0.9, 0.2, -0.4), 0.3])
			var low := _k({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.3, -0.2, 0), "head": Vector3(0.25, 0.3, 0),
				"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(0.97, 1.02, 1.06), "_smear": Vector3(0.14, 0, 0)}.merged(WIDE),
				[Vector3(0.15, -0.45, -0.2), Vector3(0.2, -0.95, -0.1), Vector3(0, 0.1, -1), 0.15])
			var hit := _k({"pivot": Vector3(-0.02, 0, 0), "hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.1, 0.4, 0), "head": Vector3(0.05, -0.4, 0),
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(0.97, 1.04, 1.02), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(-0.05, -0.3, -0.45), Vector3(-0.15, -0.1, -0.98), Vector3(0, 0.99, -0.1), 0.15])
			var follow := _k({"pivot": Vector3(0.06, 0, 0), "hips": Vector3(0, 0.6, 0), "torso": Vector3(0.15, 0.85, 0), "head": Vector3(-0.1, -0.8, 0),
				"leg_l": Vector3(0.3, 0, -0.26), "shin_l": Vector3(-0.4, 0, 0), "leg_r": Vector3(-0.4, 0, 0.26), "shin_r": Vector3(-0.9, 0, 0),
				"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.96, 1.06, 1.0), "_smear": Vector3.ZERO},
				[Vector3(-0.25, 0.2, -0.25), Vector3(-0.45, 0.8, 0.4), Vector3(-0.6, -0.1, -0.8), 0.15])
			return [h._keys(u, [[0.0, g], [0.3 / T, top, "out"], [0.38 / T, top], [0.45 / T, low, "in"], [0.5 / T, hit, "linear"], [0.66 / T, follow, "out"],
				[0.86 / T, follow], [1.0, g]]), "full", Vector3.ZERO]
		"ham_anvil":
			# Anvil Counter: the head dropped onto the ground ahead (HammerArts.ANVIL_PLANT), both hands stacked on the
			# butt, leaning on it in a wide stance with the chin up; held, then back up to the guard
			var T: float = float(h._action.get("dur", 1.25))
			var plant := _anvil_key(Vector3(1.05, 0.92, 1.0))
			var brace := _anvil_key(Vector3.ONE)
			return [h._keys(u, [[0.0, g], [0.16 / T, plant, "in"], [0.3 / T, brace, "out"], [(T - 0.25) / T, brace], [1.0, g]]), "full", Vector3.ZERO]
		"ham_rip":
			# the head ripped up out of the ground into their chin (HammerArts.RIP_AT), rising onto the toes and leaning
			# back, carried on up overhead, then back to the guard
			var T: float = float(h._action.get("dur", 0.62))
			var dip := _anvil_key(Vector3(1.06, 0.9, 1.0)).merged({"_lift": Vector3(0, -0.34, 0)}, true)
			var rip := _k({"pivot": Vector3(0.1, 0, 0), "hips": Vector3(0, 0.05, 0), "torso": Vector3(0.22, 0.05, 0), "head": Vector3(-0.15, 0, 0),
				"_lift": Vector3(0, -0.02, 0), "_scale": Vector3(0.95, 1.08, 1.0), "_smear": Vector3(0.12, 0, 0)}.merged(SET),
				[Vector3(0.0, 0.08, -0.45), Vector3(0.0, 0.75, -0.66), Vector3(0, 0.66, 0.75), 0.15])
			var up := rip.merged({"_gd": Vector3(0.0, 0.95, 0.3), "_ge": Vector3(0, 0.3, -0.95), "torso": Vector3(0.26, 0.05, 0), "_smear": Vector3.ZERO,
				"_scale": Vector3.ONE}, true)
			return [h._keys(u, [[0.0, dip], [0.06 / T, dip], [0.16 / T, rip, "out"], [0.3 / T, up, "out"], [0.42 / T, up], [1.0, g]]), "full", Vector3.ZERO]
		# --- the guard ---
		"ham_block":
			return [_k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.18, 0)}]), BLOCK_GRIP), "full", Vector3.ZERO]
		"ham_parry":
			# the haft snapped up across the front in both hands, held, then back
			var blk := _k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.02, 0.97, 1.0), "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			return [h._keys(u, [[0.0, g], [0.12, blk, "out"], [0.6, blk], [1.0, g]]), "full", Vector3.ZERO]
		"ham_deflect":
			# the blow caught on the haft, then the head's face shoved out into them, a step in
			var blk := _k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.2, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			var shove := _k({"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.25, 0.2, 0), "head": Vector3(0.2, -0.2, 0),
				"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(0.97, 1.0, 1.07), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.1, -0.28, -0.5), Vector3(-0.35, 0.15, -0.92), Vector3(0, 0, -1), 0.5])
			return [h._keys(u, [[0.0, blk], [0.3, shove, "out"], [0.6, shove], [1.0, g]]), "full", Vector3.ZERO]
	push_error("HammerMoves: no pose for \"%s\"" % n)
	return [g, "full", Vector3.ZERO]
