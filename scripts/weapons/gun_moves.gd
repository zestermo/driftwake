class_name GunMoves
## The stances and moves of the 1.24 ranged kinds, reached from Humanoid._action_pose ("lg_*" long guns, "cn_*" the
## cannon). Both are held in both hands like the polearm: each move keys the body plus PoleMoves' four grip channels ("_gr" the right
## hand at the stock's wrist, "_gd" the barrel's direction, "_ge" which way its underside faces, "_gs" (x) how far up the
## forestock the left hand slides, < 0 one-handed), in the chest's frame (x right, y up, z back), solved each frame by
## PoleMoves.hands. The chest's turn and lean carry the gun, so aiming up and down is the chest's (aim_pitch).
## (No game classes here: the body's code reads this in --script tools before the autoloads exist.)

## A held weapon's kind -> the stance it's held in (GunKinds.STYLE, for the body's side).
const STANCE := {"longgun": "long_gun", "cannon": "cannon"}

# --------------------------------------------------------------------------
# Long guns (stance "long_gun")
# --------------------------------------------------------------------------
## The low ready: the stock's wrist by the right hip, the barrel slanting down and across to the front left, the left
## hand under the forestock.
const LG_GUARD_GRIP := [Vector3(0.15, -0.4, -0.22), Vector3(-0.38, -0.32, -0.87), Vector3(0, -1, 0), 0.42]
## Shouldered: the butt in the right shoulder's pocket, the barrel out straight at the target past the turned chest.
const LG_AIM_GRIP := [Vector3(0.06, 0.0, -0.32), Vector3(-0.42, 0.0, -0.91), Vector3(0, -1, 0), 0.34]
## The block (and parry): held level across the front in both hands, the barrel to the left.
const LG_BLOCK_GRIP := [Vector3(0.3, -0.14, -0.4), Vector3(-0.99, 0.1, -0.05), Vector3(0, 0, 1), 0.55]
## Sprinting: port arms, slanted up across the chest, the muzzle past the left shoulder.
const LG_PORT_GRIP := [Vector3(0.18, -0.32, -0.18), Vector3(-0.55, 0.68, -0.3), Vector3(0, 0, 1), 0.36]
const LG_GRIPS := [LG_GUARD_GRIP, LG_BLOCK_GRIP, LG_PORT_GRIP]

## The guard: side on, the chest turned right over the left foot, the head turned back to the front. Arms only seed the
## IK.
const LG_GUARD := {"hips": Vector3(0, -0.28, 0), "torso": Vector3(-0.08, -0.28, 0), "head": Vector3(0.06, 0.34, 0),
	"arm_r": Vector3(0.3, 0.1, 0.25), "fore_r": Vector3(1.1, 0, 0), "hand_r": Vector3.ZERO,
	"arm_l": Vector3(0.8, 0.4, -0.1), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3.ZERO}
## The stance's feet (Humanoid.STANCE_LEGS): the left well forward, knees easy.
const LG_LEGS := {"leg_l": Vector3(0.42, 0, -0.18), "leg_r": Vector3(-0.32, 0, 0.18), "shin_l": Vector3(-0.6, 0, 0), "shin_r": Vector3(-0.42, 0, 0),
	"_lift": Vector3(0, -0.11, 0)}
const LG_BLOCK := {"hips": Vector3(0, -0.12, 0), "torso": Vector3(-0.1, -0.1, 0), "head": Vector3(0.1, 0.15, 0),
	"arm_r": Vector3(1.0, 0.3, 0.3), "fore_r": Vector3(1.0, 0, 0), "arm_l": Vector3(1.2, -0.3, -0.3), "fore_l": Vector3(1.0, 0, 0)}

# action-key legs
const SET := {"leg_l": Vector3(0.42, 0, -0.18), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.32, 0, 0.18), "shin_r": Vector3(-0.42, 0, 0)}
const BRACE := {"leg_l": Vector3(0.6, 0, -0.22), "shin_l": Vector3(-0.75, 0, 0), "leg_r": Vector3(-0.45, 0, 0.22), "shin_r": Vector3(-0.3, 0, 0)}
const LUNGE := {"leg_l": Vector3(1.1, 0, -0.18), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.85, 0, 0.18), "shin_r": Vector3(-0.15, 0, 0)}
## Down on the right knee, the left foot planted ahead (the marksman's kneel).
const KNEEL := {"leg_l": Vector3(1.3, 0, -0.12), "shin_l": Vector3(-1.45, 0, 0), "leg_r": Vector3(-0.1, 0, 0.16), "shin_r": Vector3(-1.95, 0, 0)}
const KNEEL_LIFT := -0.5
const TUCK := {"leg_l": Vector3(1.4, 0, -0.15), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(0.9, 0, 0.15), "shin_r": Vector3(-1.6, 0, 0)}

## The chest's turn when shouldered (the aim grip's barrel is laid out for it).
const AIM_TURN := -0.45

# --------------------------------------------------------------------------
# The cannon (stance "cannon"): the barrel on the right shoulder, the right hand on the pistol grip under it and the
# left on the front grip (the channels as the long gun's; "_gs" the left hand's slide to the front grip)
# --------------------------------------------------------------------------
## On the shoulder, pointing ahead and a touch up.
const CN_GUARD_GRIP := [Vector3(0.2, -0.03, -0.24), Vector3(0.02, 0.1, -1.0), Vector3(0, -1, 0), 0.3]
## The block (and parry): held across the front like a bar, both hands on it.
const CN_BLOCK_GRIP := [Vector3(0.3, -0.12, -0.38), Vector3(-0.99, 0.1, -0.05), Vector3(0, 0, 1), 0.45]
## Sprinting: on the shoulder in the right hand, muzzle up behind, the left arm pumping.
const CN_RUN_GRIP := [Vector3(0.22, 0.0, -0.14), Vector3(0.05, 0.75, 0.66), Vector3(0, 0.66, -0.75), -1.0]
const CN_GRIPS := [CN_GUARD_GRIP, CN_BLOCK_GRIP, CN_RUN_GRIP]

## The guard: a little side on under the weight on the shoulder, chin down, sighting along the barrel.
const CN_GUARD := {"hips": Vector3(0, -0.18, 0), "torso": Vector3(-0.06, -0.16, 0.04), "head": Vector3(0.04, 0.2, 0.08),
	"arm_r": Vector3(0.6, 0.2, 0.4), "fore_r": Vector3(1.9, 0, 0), "hand_r": Vector3.ZERO,
	"arm_l": Vector3(1.0, 0.4, -0.1), "fore_l": Vector3(1.2, 0, 0), "hand_l": Vector3.ZERO}
## The stance's feet: wide and braced.
const CN_LEGS := {"leg_l": Vector3(0.4, 0, -0.28), "leg_r": Vector3(-0.32, 0, 0.28), "shin_l": Vector3(-0.72, 0, 0), "shin_r": Vector3(-0.55, 0, 0),
	"_lift": Vector3(0, -0.16, 0)}
const CN_BLOCK := {"hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.12, -0.05, 0), "head": Vector3(0.12, 0.1, 0),
	"arm_r": Vector3(1.0, 0.3, 0.3), "fore_r": Vector3(1.0, 0, 0), "arm_l": Vector3(1.2, -0.3, -0.3), "fore_l": Vector3(1.0, 0, 0)}
const CN_SET := {"leg_l": Vector3(0.4, 0, -0.28), "shin_l": Vector3(-0.72, 0, 0), "leg_r": Vector3(-0.32, 0, 0.28), "shin_r": Vector3(-0.55, 0, 0)}
const CN_BRACE := {"leg_l": Vector3(0.65, 0, -0.3), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(-0.55, 0, 0.3), "shin_r": Vector3(-0.35, 0, 0)}


static func _k(body: Dictionary, grip: Array) -> Dictionary:
	return PoleMoves._k(body, grip)


static func _full(body: Dictionary) -> Dictionary:
	return {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.12, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}.merged(body, true)


## The guard as an action key (every joint and channel).
static func _g() -> Dictionary:
	return _k(_full(PoleMoves._p([LG_GUARD, SET])), LG_GUARD_GRIP)


## Shouldered and aimed at `pitch` (rad, up +): the chest leans with the aim, the head down on the stock.
static func _aim(pitch: float, legs: Dictionary = SET, lift: float = -0.12) -> Dictionary:
	return _k(_full(PoleMoves._p([{"hips": Vector3(0, AIM_TURN + 0.1, 0), "torso": Vector3(pitch * 0.85 - 0.02, AIM_TURN, 0.05),
		"head": Vector3(-0.16 - pitch * 0.35, -AIM_TURN - 0.02, 0.22), "arm_r": Vector3(1.2, 0.3, 0.6), "fore_r": Vector3(1.6, 0, 0),
		"arm_l": Vector3(1.4, -0.2, -0.1), "fore_l": Vector3(0.6, 0, 0), "_lift": Vector3(0, lift, 0)}, legs])), LG_AIM_GRIP)


## The shot's kick: the chest rocked back, the muzzle up, the hands driven back into the shoulder.
static func _kick(a: Dictionary, k: float) -> Dictionary:
	return a.merged({"torso": (a["torso"] as Vector3) + Vector3(0.22 * k, 0, 0), "head": (a["head"] as Vector3) + Vector3(0.12 * k, 0, 0),
		"_gr": (a["_gr"] as Vector3) + Vector3(0, 0.02, 0.06) * k, "_gd": ((a["_gd"] as Vector3) + Vector3(0, 0.3 * k, 0)).normalized(),
		"_scale": Vector3(1.0, 1.0, 1.0 - 0.04 * k)}, true)


static func _cg() -> Dictionary:
	return _k(_full(PoleMoves._p([CN_GUARD, CN_SET, {"_lift": Vector3(0, -0.16, 0)}])), CN_GUARD_GRIP)


## Braced and sighting along the barrel at `pitch`.
static func _cn_aim(pitch: float, legs: Dictionary = CN_BRACE, lift: float = -0.2) -> Dictionary:
	return _k(_full(PoleMoves._p([{"pivot": Vector3(-0.05, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(pitch * 0.8 - 0.12, -0.2, 0.06),
		"head": Vector3(0.0 - pitch * 0.3, 0.24, 0.12), "_lift": Vector3(0, lift, 0)}, legs])), [Vector3(0.2, -0.02, -0.28), Vector3(0.0, 0.0, -1.0), Vector3(0, -1, 0), 0.3])


## The cannon's kick: the whole body rocked back, the muzzle thrown up.
static func _cn_kick(a: Dictionary, k: float) -> Dictionary:
	return a.merged({"pivot": (a["pivot"] as Vector3) + Vector3(0.14 * k, 0, 0), "torso": (a["torso"] as Vector3) + Vector3(0.18 * k, 0, 0),
		"head": (a["head"] as Vector3) + Vector3(0.12 * k, 0, 0), "_gr": (a["_gr"] as Vector3) + Vector3(0, 0.05, 0.12) * k,
		"_gd": ((a["_gd"] as Vector3) + Vector3(0, 0.28 * k, 0)).normalized(), "_lift": (a["_lift"] as Vector3) + Vector3(0, 0.05 * k, 0),
		"_scale": Vector3(1.0, 1.0, 1.0 - 0.06 * k)}, true)


static func pose(h, n: String, u: float) -> Array:
	return PoleMoves.take_grip(h, _pose(h, n, u))


static func _pose(h, n: String, u: float) -> Array:
	var g := _g()
	var ap: float = clampf(h.aim_pitch, -0.6, 0.6)
	match n:
		"lg_stance":
			return [g, "full", Vector3.ZERO]
		"lg_aim":
			# (held) shouldered from the low ready in one quick lift, the cheek down on the stock
			return [h._keys(u, [[0.0, g], [1.0, _aim(ap), "out"]]), "upper", Vector3.ZERO]
		"lg_fire":
			# the shot from the shoulder: the kick, then settled back on the aim and held a beat
			var a := _aim(ap)
			return [h._keys(u, [[0.0, a], [0.06, _kick(a, 1.0), "out"], [0.4, _kick(a, 0.15)], [0.55, a], [1.0, a]]), "upper", Vector3.ZERO]
		"lg_reload":
			# the butt down by the right hip, the muzzle up before the face; the left hand rams the charge down three
			# times, then the gun's back to the low ready
			var up := _k(_full(PoleMoves._p([{"hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.12, -0.1, 0), "head": Vector3(0.18, 0.05, 0),
				"arm_r": Vector3(0.4, 0.1, 0.2), "fore_r": Vector3(1.2, 0, 0)}, SET])),
				[Vector3(0.14, -0.38, -0.28), Vector3(-0.15, 0.96, -0.24), Vector3(0, 0, 1), -1.0])
			var ram := 0.5 + 0.5 * cos(clampf((u - 0.22) / 0.58, 0.0, 1.0) * TAU * 3.0)
			var body: Dictionary = h._keys(u, [[0.0, g], [0.16, up, "out"], [0.84, up], [1.0, g]])
			if u > 0.16 and u < 0.86:
				body["arm_l"] = Vector3(lerpf(1.9, 2.6, ram), 0.1, -0.15)
				body["fore_l"] = Vector3(lerpf(1.7, 1.0, ram), 0, 0)
				body["hand_l"] = Vector3.ZERO
			return [body, "upper", Vector3.ZERO]
		"lg_butt":
			# the butt stroke: the gun drawn back down the right side, muzzle back, then the stock driven up and
			# forward into their face stepping in on the left foot, and on through
			var wind := _k(_full(PoleMoves._p([{"hips": Vector3(0, -0.45, 0), "torso": Vector3(-0.05, -0.5, 0.02), "head": Vector3(0.05, 0.55, 0),
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(0.98, 1.03, 1.0)}, SET])),
				[Vector3(0.26, -0.26, 0.04), Vector3(0.18, -0.25, 0.95), Vector3(0, 1, 0), 0.3])
			var strike := _k(_full(PoleMoves._p([{"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.22, 0.25, 0), "head": Vector3(0.2, -0.25, 0),
				"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(0.98, 1.0, 1.06)}, LUNGE])),
				[Vector3(0.06, 0.0, -0.3), Vector3(0.05, -0.2, 0.98), Vector3(0, 0.98, 0.2), 0.3])
			var follow := strike.merged({"torso": Vector3(-0.18, 0.4, 0), "_gr": Vector3(-0.02, 0.06, -0.34), "_gd": Vector3(-0.15, 0.1, 0.98)}, true)
			var whoosh := PoleMoves._whip(wind, strike, 0.55, Vector3(0.97, 1.02, 1.08), 0.08)
			return [h._keys(u, [[0.0, g], [0.28, wind, "out"], [0.36, wind], [0.42, whoosh, "in"], [0.48, strike, "out"], [0.68, follow], [1.0, g]]), "full", Vector3.ZERO]
		"lg_rush":
			# Stock Rush (attacked at a sprint): the gun held crossways in both hands and driven into them with the shoulder
			var low := _k(_full(PoleMoves._p([{"pivot": Vector3(-0.2, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.3, -0.25, 0), "head": Vector3(0.3, 0.2, 0),
				"_lift": Vector3(0, -0.22, 0)}, LUNGE])), [Vector3(0.24, -0.3, -0.25), Vector3(-0.95, 0.25, -0.15), Vector3(0, 0, 1), 0.5])
			var ram := _k(_full(PoleMoves._p([{"pivot": Vector3(-0.28, 0, 0), "hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.35, 0.05, 0), "head": Vector3(0.35, -0.05, 0),
				"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.04, 0.96, 1.08)}, LUNGE])), [Vector3(0.28, -0.1, -0.52), Vector3(-0.98, 0.15, -0.05), Vector3(0, 0, 1), 0.55])
			return [h._keys(u, [[0.0, low], [0.3, low], [0.42, ram, "out"], [0.7, ram], [1.0, g]]), "full", Vector3.ZERO]
		"lg_air":
			# Sky Shot: knees drawn up in the air, the gun shouldered and drawn down onto them, the shot's kick at 0.55
			var a := _aim(ap, TUCK, 0.0)
			return [h._keys(u, [[0.0, g], [0.25, a, "out"], [0.55, a], [0.6, _kick(a, 1.2), "out"], [0.85, _kick(a, 0.3)], [1.0, a]]), "full", Vector3.ZERO]
		"lg_block":
			return [_k(_full(PoleMoves._p([LG_BLOCK, SET])), LG_BLOCK_GRIP), "full", Vector3.ZERO]
		"lg_parry":
			# the gun snapped up level across the front to take the blow on the barrel
			var b := _k(_full(PoleMoves._p([LG_BLOCK, SET])), LG_BLOCK_GRIP)
			var up := b.merged({"_gr": Vector3(0.3, 0.02, -0.42)}, true)
			return [h._keys(u, [[0.0, g], [0.14, up, "out"], [0.45, up], [1.0, g]]), "full", Vector3.ZERO]
		"lg_deflect":
			# and shoved out into them, the stock leading
			var b := _k(_full(PoleMoves._p([LG_BLOCK, SET])), LG_BLOCK_GRIP)
			var shove := _k(_full(PoleMoves._p([{"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.2, 0.15, 0), "head": Vector3(0.15, -0.1, 0)}, LUNGE])),
				[Vector3(0.3, -0.08, -0.6), Vector3(-0.98, 0.15, -0.1), Vector3(0, 0, 1), 0.55])
			return [h._keys(u, [[0.0, b], [0.3, shove, "out"], [0.6, shove], [1.0, g]]), "full", Vector3.ZERO]
		# --- the techniques ---
		"lg_kneel":
			# (held) down on one knee, shouldered: the marksman's rest (Pinning Shot, Hawkeye)
			return [h._keys(u, [[0.0, g], [1.0, _aim(ap, KNEEL, KNEEL_LIFT), "out"]]), "full", Vector3.ZERO]
		"lg_kneel_fire":
			var a := _aim(ap, KNEEL, KNEEL_LIFT)
			return [h._keys(u, [[0.0, a], [0.1, _kick(a, 1.0), "out"], [0.6, a], [1.0, a]]), "full", Vector3.ZERO]
		"lg_burst":
			# Powder Burst: the gun dropped to the hip and fired with a double charge; the blast throws you back a step
			var hip := _k(_full(PoleMoves._p([{"hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.15, -0.2, 0), "head": Vector3(0.15, 0.2, 0),
				"_lift": Vector3(0, -0.2, 0)}, BRACE])), [Vector3(0.1, -0.3, -0.3), Vector3(-0.2, 0.05, -0.98), Vector3(0, -1, 0), 0.38])
			var blown := hip.merged({"pivot": Vector3(0.15, 0, 0), "torso": Vector3(0.15, -0.2, 0), "head": Vector3(-0.05, 0.2, 0),
				"_gd": Vector3(-0.15, 0.55, -0.82), "_gr": Vector3(0.12, -0.24, -0.18), "_scale": Vector3(1.03, 0.97, 0.94)}, true)
			return [h._keys(u, [[0.0, g], [0.3, hip, "out"], [0.4, hip], [0.45, blown, "out"], [0.7, blown], [1.0, g]]), "full", Vector3.ZERO]
		"lg_sweep":
			# Stock Sweep: the gun let out at arm's length, butt first, and the whole body turned round once behind it
			var load := _k(_full(PoleMoves._p([{"hips": Vector3(0, -0.5, 0), "torso": Vector3(-0.1, -0.55, 0), "head": Vector3(0.1, 0.7, 0),
				"_lift": Vector3(0, -0.2, 0)}, BRACE])), [Vector3(0.25, -0.25, -0.25), Vector3(-0.9, -0.1, 0.4), Vector3(0, -1, 0), 0.3])
			var out := _k(_full(PoleMoves._p([{"pivot": Vector3(-0.05, 0, 0), "hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.15, 0.1, 0), "head": Vector3(0.1, -0.1, 0),
				"_lift": Vector3(0, -0.26, 0), "_smear": Vector3(0.1, 0, 0)}, BRACE])), [Vector3(0.4, -0.18, -0.32), Vector3(-0.95, 0.0, 0.3), Vector3(0, -1, 0), 0.3])
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.18, load, "out"], [0.25, load], [0.3, out, "in"], [0.7, out, "linear"], [0.85, out], [1.0, g]])
			var k := clampf((u - 0.25) / 0.45, 0.0, 1.0)
			pz["pivot"] = (pz["pivot"] as Vector3) + Vector3(0, -TAU * k, 0)
			return [pz, "full", Vector3.ZERO]
		# --- the cannon ---
		"cn_stance":
			return [_cg(), "full", Vector3.ZERO]
		"cn_fire":
			# braced low over the front foot, sighting along the barrel, the shot at 0.28: the whole body rocked back
			# under the kick and the muzzle thrown up, then settled back onto the shoulder
			var a := _cn_aim(ap)
			return [h._keys(u, [[0.0, _cg()], [0.22, a, "out"], [0.28, a], [0.33, _cn_kick(a, 1.0), "out"], [0.6, _cn_kick(a, 0.3)], [1.0, _cg()]]), "full", Vector3.ZERO]
		"cn_reload":
			# off the shoulder, the muzzle stood up in front; the left hand drops a ball in and rams it twice, then it's
			# heaved back up onto the shoulder
			var up := _k(_full(PoleMoves._p([{"hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.15, -0.05, 0), "head": Vector3(0.25, 0.0, 0),
				"_lift": Vector3(0, -0.18, 0)}, CN_SET])), [Vector3(0.16, -0.42, -0.3), Vector3(-0.1, 0.97, -0.2), Vector3(0, 0, 1), -1.0])
			var ram := 0.5 + 0.5 * cos(clampf((u - 0.3) / 0.45, 0.0, 1.0) * TAU * 2.0)
			var body: Dictionary = h._keys(u, [[0.0, _cg()], [0.18, up, "out"], [0.82, up], [1.0, _cg(), "in"]])
			if u > 0.18 and u < 0.84:
				body["arm_l"] = Vector3(lerpf(1.6, 2.2, ram), 0.15, -0.1)
				body["fore_l"] = Vector3(lerpf(1.5, 0.9, ram), 0, 0)
				body["hand_l"] = Vector3.ZERO
			return [body, "upper", Vector3.ZERO]
		"cn_bash":
			# the barrel swung like a club: heaved back up over the right shoulder, then brought down across the front
			var wind := _k(_full(PoleMoves._p([{"pivot": Vector3(0.06, 0, 0), "hips": Vector3(0, -0.45, 0), "torso": Vector3(0.12, -0.5, 0.05), "head": Vector3(-0.05, 0.6, 0),
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.98, 1.04, 1.0)}, CN_SET])),
				[Vector3(0.22, 0.1, -0.08), Vector3(0.25, 0.72, 0.64), Vector3(-0.2, 0.6, -0.77), 0.3])
			var strike := _k(_full(PoleMoves._p([{"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.32, 0.28, 0), "head": Vector3(0.3, -0.3, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.06, 0.92, 1.02)}, LUNGE])),
				[Vector3(0.02, -0.25, -0.45), Vector3(-0.3, 0.3, -0.9), Vector3(-0.1, -0.9, -0.3), 0.25])
			var whoosh := PoleMoves._whip(wind, strike, 0.55, Vector3(0.97, 1.02, 1.08), 0.1)
			return [h._keys(u, [[0.0, _cg()], [0.3, wind, "out"], [0.42, wind], [0.48, whoosh, "in"], [0.54, strike, "out"], [0.75, strike], [1.0, _cg()]]), "full", Vector3.ZERO]
		"cn_ram":
			# Cannon Ram: dropped off the shoulder to the hip, muzzle first, and driven into them at the run
			var low := _k(_full(PoleMoves._p([{"pivot": Vector3(-0.25, 0, 0), "hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.3, -0.2, 0), "head": Vector3(0.3, 0.15, 0),
				"_lift": Vector3(0, -0.24, 0)}, LUNGE])), [Vector3(0.18, -0.38, -0.3), Vector3(0.0, -0.1, -1.0), Vector3(0, -1, 0), 0.3])
			var drive := low.merged({"pivot": Vector3(-0.32, 0, 0), "_gr": Vector3(0.14, -0.3, -0.55), "_scale": Vector3(1.04, 0.95, 1.08)}, true)
			return [h._keys(u, [[0.0, low], [0.3, low], [0.4, drive, "out"], [0.7, drive], [1.0, _cg()]]), "full", Vector3.ZERO]
		"cn_air":
			# Recoil Leap: knees up, the cannon turned muzzle down between the feet, fired; the blast throws you up
			var down := _k(_full(PoleMoves._p([{"pivot": Vector3(-0.15, 0, 0), "torso": Vector3(-0.35, 0, 0), "head": Vector3(0.45, 0, 0), "_lift": Vector3.ZERO}, TUCK])),
				[Vector3(0.12, -0.32, -0.3), Vector3(0.0, -0.98, -0.18), Vector3(0, 0, 1), 0.28])
			var blown := down.merged({"pivot": Vector3(0.1, 0, 0), "torso": Vector3(0.1, 0, 0), "_gd": Vector3(0.0, -0.8, 0.6), "_scale": Vector3(0.95, 1.08, 1.0)}, true)
			return [h._keys(u, [[0.0, _cg()], [0.2, down, "out"], [0.26, down], [0.34, blown, "out"], [0.7, blown], [1.0, _cg()]]), "full", Vector3.ZERO]
		"cn_block":
			return [_k(_full(PoleMoves._p([CN_BLOCK, CN_SET])), CN_BLOCK_GRIP), "full", Vector3.ZERO]
		"cn_parry":
			var b := _k(_full(PoleMoves._p([CN_BLOCK, CN_SET])), CN_BLOCK_GRIP)
			return [h._keys(u, [[0.0, _cg()], [0.15, b, "out"], [0.5, b], [1.0, _cg()]]), "full", Vector3.ZERO]
		"cn_deflect":
			var b := _k(_full(PoleMoves._p([CN_BLOCK, CN_SET])), CN_BLOCK_GRIP)
			var shove := b.merged({"pivot": Vector3(-0.12, 0, 0), "torso": Vector3(-0.22, 0.12, 0), "_gr": Vector3(0.3, -0.08, -0.62)}, true).merged(LUNGE, true)
			return [h._keys(u, [[0.0, b], [0.3, shove, "out"], [0.6, shove], [1.0, _cg()]]), "full", Vector3.ZERO]
		"cn_brace":
			# (held) down on one knee, the cannon on the shoulder sighted out ahead: the Leviathan Shell's
			return [h._keys(u, [[0.0, _cg()], [1.0, _cn_aim(ap, KNEEL, KNEEL_LIFT), "out"]]), "full", Vector3.ZERO]
		"cn_lob":
			# Mortar Lob: the cannon tipped up high on the shoulder, three shells sent up with a kick each
			var hi := _k(_full(PoleMoves._p([{"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(0.25, -0.2, 0.05), "head": Vector3(-0.2, 0.2, 0.1),
				"_lift": Vector3(0, -0.22, 0)}, CN_BRACE])), [Vector3(0.2, -0.05, -0.2), Vector3(0.0, 0.8, -0.6), Vector3(0, -0.6, -0.8), 0.28])
			var keys: Array = [[0.0, _cg()], [0.22, hi, "out"]]
			for at in [0.29, 0.42, 0.54]:
				keys.append([at, hi])
				keys.append([at + 0.04, _cn_kick(hi, 0.6), "out"])
			keys.append_array([[0.75, hi], [1.0, _cg()]])
			return [h._keys(u, keys), "full", Vector3.ZERO]
		"cn_back":
			# Rocket Charge: the cannon swung round under the right arm to point behind, leaning hard forward, fired:
			# carried forward on the blast, then up out of it
			var aim_back := _k(_full(PoleMoves._p([{"pivot": Vector3(-0.35, 0, 0), "hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.35, -0.15, 0), "head": Vector3(0.5, 0.1, 0),
				"_lift": Vector3(0, -0.3, 0)}, LUNGE])), [Vector3(0.3, -0.35, 0.0), Vector3(0.1, -0.25, 0.96), Vector3(0, -1, 0), 0.25])
			var fly := aim_back.merged({"pivot": Vector3(-0.5, 0, 0), "_scale": Vector3(0.95, 0.96, 1.1), "_smear": Vector3(0.1, 0, 0)}, true)
			return [h._keys(u, [[0.0, _cg()], [0.16, aim_back, "out"], [0.2, aim_back], [0.26, fly, "out"], [0.66, fly], [1.0, _cg()]]), "full", Vector3.ZERO]
	return []
