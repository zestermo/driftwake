class_name BlackLegMoves
## Black-leg (stance "black_leg": empty hands, the kicks learned and chosen; Player.kicks). Kicks only: the hands
## never strike, but the arms work in every move, flung out and counter-turned against the kicking leg (the arm on
## the kicking side drives back as the leg comes through, both thrown wide on the spins), and in some moves the
## hands go down on the ground (planted by IK: hands()). The guard is light, upright and springy with the hands
## loose and up a little; once the Black Leg tree's Nonchalance is owned (`Humanoid.kick_pockets`, synced) the guard
## is hands in the pockets instead, out the moment a move starts and back in as it settles (every move starts and
## ends on _guard()). Every "bl_*" move is keyed here (reached from Humanoid._action_pose), the right leg's kicks
## authored once and mirrored for the left. Each kick turns the hips over the supporting foot (the whole body yaws
## on it: pivot y plus the hips) and leans away from the leg (pivot z), so the weight goes through the kick.
## Moves keyed in seconds read the played length from _action["dur"].

const GUARD := {"hips": Vector3(0, -0.35, 0), "torso": Vector3(-0.05, 0.14, 0.0), "head": Vector3(0.05, 0.2, 0),
	"arm_l": Vector3(0.55, 0.2, -0.34), "fore_l": Vector3(1.05, 0, 0), "hand_l": Vector3(0.25, 0, 0),
	"arm_r": Vector3(0.32, -0.15, 0.36), "fore_r": Vector3(0.95, 0, 0), "hand_r": Vector3(0.25, 0, 0)}
## Nonchalance: upright, chin up, both hands in the trouser pockets.
const POCKETS := {"hips": Vector3(0, -0.28, 0), "torso": Vector3(0.06, 0.12, 0.0), "head": Vector3(-0.06, 0.16, 0),
	"arm_l": Vector3(-0.1, -0.2, -0.24), "fore_l": Vector3(0.8, 0, 0), "hand_l": Vector3(0.3, 0, 0),
	"arm_r": Vector3(-0.1, 0.2, 0.24), "fore_r": Vector3(0.8, 0, 0), "hand_r": Vector3(0.3, 0, 0)}
## The stance's feet (Humanoid.STANCE_LEGS): close and light, the left a little ahead, up on the balls of the feet.
const LEGS := {"leg_l": Vector3(0.3, 0, -0.12), "leg_r": Vector3(-0.22, 0, 0.12), "shin_l": Vector3(-0.42, 0, 0), "shin_r": Vector3(-0.38, 0, 0),
	"_lift": Vector3(0, -0.07, 0)}
## Actions of every stance this file poses for black-leg (the held block is a raised shin, not the arms).
const OWN := ["guard_block", "guard_block_hit"]
## Moves upside down (no foot IK while they play).
const INVERTED := ["bl_4", "bl_wheel", "bl_mule", "bl_last"]
## Where the hands go down on the ground: action -> [[u from, u to, "l" / "r" / "lr", latched]]. A latched hand
## stays where it touched down; the others follow the posed hand along the ground (the spins).
const PLANTS := {
	"bl_4": [[0.17, 0.82, "lr", false]],
	"bl_air_land": [[0.0, 0.62, "r", true]],
	"bl_deflect": [[0.2, 0.74, "r", true]],
	"bl_mule": [[0.27, 0.66, "lr", true]],
}
static var WHEEL_PLANTS := _wheel_plants()
## Handstand Spin (bl_4): how far the split legs' plane tips off flat (rad) at the middle of the spin, and how fast
## the way it tips wanders round (turns of the tip per turn of the body, against the spin).
const SPIN_TILT := 0.24
const SPIN_PRECESS := -0.3

## The techniques' timings (s at the length they're played; BlackLegArts runs them): Hailstorm Heels' kicks and their
## heights (_kick_r k), Cartwheel Crescent's two turns and its heel, Last Course's heat spin, kicks and heel.
const HAIL_DUR := 1.3
const HAIL_KICKS := 9
const HAIL_FROM := 0.16
const HAIL_EVERY := 0.09
const HAIL_FINAL_AT := 1.08
const HAIL_HEIGHTS := [1.0, 2.0, 0.0, 1.0, 2.0, 1.0, 0.0, 2.0, 1.0]
const WHEEL_DUR := 1.45
const WHEEL_ROLL := Vector2(0.1, 0.95)
const WHEEL_HEEL := 1.15
const LAST_DUR := 2.7
const LAST_HEAT := Vector2(0.05, 0.6)
const LAST_KICKS := 7
const LAST_KICK_FROM := 0.7
const LAST_KICK_EVERY := 0.13
const LAST_HEEL := 1.95


static func guard(h) -> Dictionary:
	return POCKETS if h.kick_pockets else GUARD


static func _p(parts: Array) -> Dictionary:
	var out := {}
	for d in parts:
		out.merge(d, true)
	return out


## The same pose on the other side (Humanoid._mirror), its squash kept.
static func _mir(p: Dictionary) -> Dictionary:
	var out: Dictionary = Humanoid._mirror(p)
	if p.has("_scale"):
		out["_scale"] = p["_scale"]
	return out


static func _sq(p: Dictionary, sc: Vector3) -> Dictionary:
	return p.merged({"_scale": sc}, true)


# --------------------------------------------------------------------------
# The roundhouse, right leg, at a height `k` (0 the knee, 1 the ribs, 2 the head)
# --------------------------------------------------------------------------
## Chambered: the weight on the left foot, the hips starting to turn over it, the right knee up and out with the
## shin folded tight; the left arm comes up ahead, the right drawn back.
static func _chamber_r(k: float) -> Dictionary:
	return {"pivot": Vector3(0, 0.3, 0.04 * k), "hips": Vector3(0, 0.5, 0), "torso": Vector3(-0.06, -0.3, 0.1 + 0.05 * k),
		"head": Vector3(0.05, -0.42, -0.08 - 0.03 * k),
		"leg_r": Vector3(0.75 + 0.15 * k, 0, 0.55 + 0.25 * k), "shin_r": Vector3(-1.95, 0, 0),
		"leg_l": Vector3(0.1, 0, -0.08), "shin_l": Vector3(-0.45, 0, 0),
		"arm_l": Vector3(0.9, 0.35, -0.45), "fore_l": Vector3(1.2, 0, 0), "hand_l": Vector3(0.2, 0, 0),
		"arm_r": Vector3(-0.2, 0, 0.55), "fore_r": Vector3(0.8, 0, 0), "hand_r": Vector3(0.2, 0, 0),
		"_lift": Vector3(0, -0.05, 0), "_scale": Vector3(0.98, 1.02, 0.98)}


## Struck: the hips turned right over (the left foot pivoted under them), the body leaning away from the leg, the
## shin snapped out straight through them; the right arm flung down and back against the leg, the left out ahead.
static func _kick_r(k: float) -> Dictionary:
	return {"pivot": Vector3(0, 0.85 + 0.1 * k, 0.12 + 0.18 * k), "hips": Vector3(0, 0.55, 0), "torso": Vector3(0.02, -0.55, 0.22 + 0.12 * k),
		"head": Vector3(0.05, -0.8, -0.32 - 0.12 * k),
		"leg_r": Vector3(0.2, 0, 0.95 + 0.4 * k), "shin_r": Vector3(-0.08, 0, 0),
		"leg_l": Vector3(0.05, 0, -0.18 - 0.06 * k), "shin_l": Vector3(-0.28, 0, 0),
		"arm_l": Vector3(1.05, 0.55, -0.7 - 0.15 * k), "fore_l": Vector3(0.9, 0, 0), "hand_l": Vector3(0.1, 0, 0),
		"arm_r": Vector3(-0.9 - 0.1 * k, 0, 0.2 + 0.25 * k), "fore_r": Vector3(0.3, 0, 0), "hand_r": Vector3(0.1, 0, 0),
		"_lift": Vector3(0, -0.03 + 0.02 * k, 0), "_scale": Vector3(1.02, 0.99, 1.03)}


## Snapped back to the chamber, the hips still over (the recoil is as quick as the kick).
static func _recoil_r(k: float) -> Dictionary:
	return _chamber_r(k).merged({"pivot": Vector3(0, 0.6, 0.06 * k), "hips": Vector3(0, 0.45, 0), "_scale": Vector3.ONE}, true)


## A small skip onto the left foot (the high kick's step in).
static func _skip_r() -> Dictionary:
	return {"pivot": Vector3(0, 0.15, 0), "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.1, -0.15, 0.0), "head": Vector3(0.1, -0.2, 0),
		"leg_r": Vector3(0.1, 0, 0.12), "shin_r": Vector3(-0.9, 0, 0), "leg_l": Vector3(0.25, 0, -0.1), "shin_l": Vector3(-0.85, 0, 0),
		"arm_l": Vector3(0.6, 0.2, -0.5), "fore_l": Vector3(1.1, 0, 0), "hand_l": Vector3(0.2, 0, 0),
		"arm_r": Vector3(0.3, 0, 0.55), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(0.2, 0, 0),
		"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(1.03, 0.95, 1.0)}


static func _roundhouse(h, u: float, k: float, left: bool, at: Array) -> Dictionary:
	var c := _chamber_r(k)
	var s := _sq(_kick_r(k), Vector3(1.03, 0.98, 1.05))
	var r := _recoil_r(k)
	if left:
		c = _mir(c)
		s = _mir(s)
		r = _mir(r)
	var g: Dictionary = h._guard()
	var keys: Array = [[0.0, g]]
	if k >= 2.0:
		keys.append([at[0] * 0.5, _mir(_skip_r()) if left else _skip_r()])
	keys.append_array([[at[0], c, "out"], [at[1], s, "out"], [at[2], s.merged({"_scale": Vector3.ONE}, true)], [at[3], r], [1.0, g]])
	return h._keys(u, keys)


# --------------------------------------------------------------------------
# The handstand: dropped onto both hands, the body upside down with the legs split wide
# --------------------------------------------------------------------------
## Upside down on the hands (pivot x -PI: the arms "overhead" reach the ground), the legs split out flat.
static func _handstand(split: float) -> Dictionary:
	return {"hips": Vector3.ZERO, "torso": Vector3(0.0, 0, 0), "head": Vector3(0.55, 0, 0),
		"leg_l": Vector3(0.0, 0, -split), "shin_l": Vector3(-0.06, 0, 0), "leg_r": Vector3(0.0, 0, split), "shin_r": Vector3(-0.06, 0, 0),
		"arm_l": Vector3(2.85, 0, -0.32), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3(-0.6, 0, 0),
		"arm_r": Vector3(2.85, 0, 0.32), "fore_r": Vector3(0.3, 0, 0), "hand_r": Vector3(-0.6, 0, 0),
		"_lift": Vector3(0, -0.04, 0), "_scale": Vector3.ONE}


## Reaching down for the ground ahead, knees bent, about to go over.
static func _dip() -> Dictionary:
	return {"hips": Vector3.ZERO, "torso": Vector3(-0.55, 0, 0), "head": Vector3(0.45, 0, 0),
		"leg_l": Vector3(0.95, 0, -0.15), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.2, 0, 0.15), "shin_r": Vector3(-0.9, 0, 0),
		"arm_l": Vector3(1.6, 0, -0.3), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3(-0.3, 0, 0),
		"arm_r": Vector3(1.6, 0, 0.3), "fore_r": Vector3(0.3, 0, 0), "hand_r": Vector3(-0.3, 0, 0),
		"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.04, 0.94, 1.02)}


## Coming down onto the feet out of a walkover, knees soaking it up.
static func _walkover_land() -> Dictionary:
	return {"hips": Vector3.ZERO, "torso": Vector3(-0.35, 0, 0), "head": Vector3(0.3, 0, 0),
		"leg_l": Vector3(0.75, 0, -0.18), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(0.45, 0, 0.18), "shin_r": Vector3(-1.1, 0, 0),
		"arm_l": Vector3(0.9, 0, -1.0), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3(0.2, 0, 0),
		"arm_r": Vector3(0.9, 0, 1.0), "fore_r": Vector3(0.5, 0, 0), "hand_r": Vector3(0.2, 0, 0),
		"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.04, 0.95, 1.02)}


## The body's pitch through a handstand move: up to 0 standing, -PI on the hands by `down`, held to `up`, then on
## over the front (a walkover) to -TAU by the end (the action's finish wraps it back to 0).
static func _over(u: float, down: Array, up: Array) -> float:
	if u < down[0]:
		return -0.6 * Humanoid._ease(u / down[0])
	if u < down[1]:
		return lerpf(-0.6, -PI, Humanoid._shape((u - down[0]) / (down[1] - down[0]), "out"))
	if u < up[0]:
		return -PI
	return lerpf(-PI, -TAU, Humanoid._ease((u - up[0]) / (up[1] - up[0])))


# --------------------------------------------------------------------------
# The poses
# --------------------------------------------------------------------------
## [pose, mask, lift] for a black-leg move.
static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	var g: Dictionary = h._guard()
	var T: float = float(h._action.get("dur", 1.0))
	match n:
		# --- the combo: low (left), mid (right), high (left), the handstand spin ---
		"bl_1":
			return [_roundhouse(h, u, 0.0, true, [0.18, 0.32, 0.44, 0.6]), "full", lift]
		"bl_2":
			return [_roundhouse(h, u, 1.0, false, [0.2, 0.36, 0.48, 0.64]), "full", lift]
		"bl_3":
			return [_roundhouse(h, u, 2.0, true, [0.26, 0.4, 0.54, 0.7]), "full", lift]
		"bl_4":
			# Handstand Spin: down onto both hands, legs split flat, two turns sweeping everyone round, then on over
			# the front onto the feet
			var stand := _handstand(1.45)
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.12, _dip(), "out"], [0.24, stand, "out"], [0.76, stand],
				[0.9, _walkover_land(), "out"], [1.0, g]])
			var k := clampf((u - 0.22) / 0.56, 0.0, 1.0)
			var spin := -2.0 * TAU * (1.0 - pow(1.0 - k, 1.3))
			# the legs' plane tipped off flat (SPIN_TILT, eased in and out), the tip's direction held still against the
			# turn and itself wandering round (SPIN_PRECESS), so the feet never ride one flat circle
			var tilt := SPIN_TILT * sin(PI * k)
			var dir := SPIN_PRECESS * spin + spin
			pz["pivot"] = Vector3(_over(u, [0.12, 0.24], [0.76, 1.0]) + tilt * cos(dir), spin, -tilt * sin(dir))
			return [pz, "full", lift]
		# --- the heavy: the axe kick (Guillotine Heel) ---
		"bl_heavy":
			# a skip in, the right leg swung straight up over the head (leaning back, the arms flung wide and up), then
			# the heel brought down through them into the ground, crunched over it, the arms whipped down
			var load_ := _p([_skip_r(), {"arm_l": Vector3(0.3, 0, -0.35), "arm_r": Vector3(0.3, 0, 0.35), "fore_l": Vector3(1.4, 0, 0), "fore_r": Vector3(1.4, 0, 0)}])
			var up := _heel_up(0.05)
			var down := _heel_down()
			return [h._keys(u, [[0.0, g], [0.18, load_, "out"], [0.42, up, "out"], [0.47, up], [0.55, down, "in"],
				[0.72, down.merged({"_scale": Vector3.ONE}, true)], [1.0, g]]), "full", lift]
		# --- moving: the running attack, the air attack and its landing ---
		"bl_rush":
			# Arrow Kick (at a sprint): sunk low, launched with the body turned side-on, the right leg shot straight out
			# at them, the left knee tucked; landed crouched
			var low := {"pivot": Vector3(-0.25, 0.2, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.3, -0.1, 0), "head": Vector3(0.3, -0.2, 0),
				"leg_l": Vector3(0.9, 0, -0.15), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(-0.2, 0, 0.15), "shin_r": Vector3(-1.1, 0, 0),
				"arm_l": Vector3(-0.6, 0, -0.4), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(-0.6, 0, 0.4), "fore_r": Vector3(0.5, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.05, 0.93, 1.0)}
			var fly := {"pivot": Vector3(0, 1.45, 0.42), "hips": Vector3(0, 0.1, 0), "torso": Vector3(0.0, -0.35, 0.25), "head": Vector3(0.05, -1.1, -0.45),
				"leg_r": Vector3(0.1, 0, 1.5), "shin_r": Vector3(-0.04, 0, 0), "leg_l": Vector3(1.35, 0, -0.1), "shin_l": Vector3(-2.2, 0, 0),
				"arm_l": Vector3(0.9, 0.3, -1.1), "fore_l": Vector3(0.7, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(0.3, 0, 1.25), "fore_r": Vector3(0.2, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, 0.32, 0), "_scale": Vector3(1.0, 0.98, 1.06)}
			var land := _walkover_land()
			return [h._keys(u, [[0.0, g], [0.14, low, "out"], [0.3, fly, "out"], [0.58, fly.merged({"_scale": Vector3.ONE}, true)],
				[0.74, land, "in"], [1.0, g]]), "full", lift]
		"bl_air":
			# Cyclone Heel: tucked a beat, then turning flat in the air like a top with the right leg out straight and
			# the arms flung wide (played longer than it falls; the landing cuts it short)
			var tuck := {"hips": Vector3.ZERO, "torso": Vector3(-0.2, 0, 0), "head": Vector3(0.2, 0, 0),
				"leg_l": Vector3(1.5, 0, -0.12), "shin_l": Vector3(-2.2, 0, 0), "leg_r": Vector3(1.3, 0, 0.12), "shin_r": Vector3(-2.1, 0, 0),
				"arm_l": Vector3(0.6, 0, -0.5), "fore_l": Vector3(1.6, 0, 0), "hand_l": Vector3(0.2, 0, 0),
				"arm_r": Vector3(0.6, 0, 0.5), "fore_r": Vector3(1.6, 0, 0), "hand_r": Vector3(0.2, 0, 0),
				"_lift": Vector3.ZERO, "_scale": Vector3(0.96, 1.02, 0.96)}
			var top := {"hips": Vector3.ZERO, "torso": Vector3(0.05, 0, 0.3), "head": Vector3(0.0, 0, -0.3),
				"leg_r": Vector3(0.15, 0, 1.45), "shin_r": Vector3(-0.05, 0, 0), "leg_l": Vector3(0.9, 0, -0.15), "shin_l": Vector3(-1.8, 0, 0),
				"arm_l": Vector3(0.4, 0, -1.4), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(0.4, 0, 1.3), "fore_r": Vector3(0.3, 0, 0), "hand_r": Vector3(0.1, 0, 0),
				"_lift": Vector3.ZERO, "_scale": Vector3(1.03, 0.98, 1.03)}
			var pz: Dictionary = h._keys(u, [[0.0, {}], [0.1 / T, tuck, "out"], [0.18 / T, top, "out"], [1.0, top]])
			var s := maxf(u * T - 0.12, 0.0)
			pz["pivot"] = Vector3(0, TAU * 2.6 * s, 0.35 * minf(s / 0.1, 1.0))
			return [pz, "full", lift]
		"bl_air_land":
			# down in a crouch on one knee, the right hand planted on the ground, the left arm flung out behind
			var crouch := {"pivot": Vector3(-0.15, 0, -0.12), "hips": Vector3.ZERO, "torso": Vector3(-0.55, 0.15, -0.2), "head": Vector3(0.6, -0.1, 0.1),
				"leg_l": Vector3(1.1, 0, -0.25), "shin_l": Vector3(-1.85, 0, 0), "leg_r": Vector3(-0.15, 0, 0.3), "shin_r": Vector3(-1.9, 0, 0),
				"arm_r": Vector3(0.8, 0, 0.45), "fore_r": Vector3(0.25, 0, 0), "hand_r": Vector3(-0.8, 0, 0),
				"arm_l": Vector3(-0.3, 0, -1.25), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, -0.46, 0), "_scale": Vector3(1.05, 0.93, 1.03)}
			return [h._keys(u, [[0.0, crouch], [0.5, crouch.merged({"_scale": Vector3.ONE}, true)], [1.0, g]]), "full", lift]
		# --- the guard: the shin checks the blow; landed, a drop onto one hand and a sweep through their legs ---
		"bl_parry":
			return [h._keys(u, [[0.0, g], [0.12, _sq(_check(), Vector3(1.02, 0.97, 1.0)), "out"], [0.18, _check()], [0.6, _check()], [1.0, g]]), "full", lift]
		"bl_deflect":
			var low := {"pivot": Vector3(-0.25, 0.6, -0.3), "hips": Vector3.ZERO, "torso": Vector3(-0.35, 0.1, -0.25), "head": Vector3(0.4, -0.5, 0.2),
				"leg_r": Vector3(0.9, 0, 0.2), "shin_r": Vector3(-2.0, 0, 0), "leg_l": Vector3(0.1, 0, -1.4), "shin_l": Vector3(-0.1, 0, 0),
				"arm_r": Vector3(0.4, 0, 0.95), "fore_r": Vector3(0.2, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
				"arm_l": Vector3(0.9, 0.2, -0.9), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3(0.1, 0, 0),
				"_lift": Vector3(0, -0.48, 0), "_scale": Vector3(1.04, 0.94, 1.02)}
			var swept := low.merged({"pivot": Vector3(-0.25, -0.75, -0.3), "_scale": Vector3.ONE}, true)
			return [h._keys(u, [[0.0, _check()], [0.22, low, "out"], [0.5, swept, "out"], [0.68, swept], [1.0, g]]), "full", lift]
		"guard_block", "guard_block_hit", "bl_block":
			# the lead shin raised in a check and held, the hands loose and up for balance; the supporting leg keeps
			# shuffling with the gait
			var c := _check()
			for j in ["leg_r", "shin_r"]:
				c[j] = h._base.get(j, c[j])
			if n == "guard_block_hit":
				var rock := c.merged({"torso": (c["torso"] as Vector3) + Vector3(0.2, 0, 0), "head": (c["head"] as Vector3) + Vector3(-0.15, 0, 0)}, true)
				return [h._keys(u, [[0.0, c], [0.25, rock, "out"], [1.0, c]]), "full", lift]
			return [h._keys(u, [[0.0, {}], [1.0, c, "out"]]), "full", lift]
		"bl_stance":
			return [{}, "upper", lift]
		# --- the techniques (BlackLegArts; keyed in seconds of the length they're played at) ---
		"bl_mule":
			return [_mule(h, u, T), "full", lift]
		"bl_hail":
			return [_hail(h, u, T), "full", lift]
		"bl_wheel":
			return [_wheel(h, u, T), "full", lift]
		"bl_last":
			return [_last(h, u, T), "full", lift]
	push_error("BlackLegMoves: no pose for \"%s\"" % n)
	return [g, "full", lift]


## The shin check: the left knee up and turned out so the shin stands across the front, leaning back a little off
## the right foot, the arms out loose.
static func _check() -> Dictionary:
	return {"pivot": Vector3.ZERO, "hips": Vector3(0, -0.3, 0), "torso": Vector3(0.08, 0.2, -0.06), "head": Vector3(-0.04, 0.15, 0.05),
		"leg_l": Vector3(1.2, 0, -0.32), "shin_l": Vector3(-1.75, 0, 0), "leg_r": Vector3(0.05, 0, 0.1), "shin_r": Vector3(-0.35, 0, 0),
		"arm_l": Vector3(0.55, 0.1, -0.85), "fore_l": Vector3(0.7, 0, 0), "hand_l": Vector3(0.2, 0, 0),
		"arm_r": Vector3(0.6, -0.1, 0.8), "fore_r": Vector3(0.6, 0, 0), "hand_r": Vector3(0.2, 0, 0),
		"_lift": Vector3(0, -0.05, 0), "_scale": Vector3.ONE}


## The axe kick's top: the right leg straight up over the head, leaning back off the left foot, the arms flung wide
## and up (`rise`: the hips' lift, a leap in the ultimate).
static func _heel_up(rise: float) -> Dictionary:
	return {"pivot": Vector3(0.2, 0.1, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(0.22, -0.1, 0), "head": Vector3(-0.32, 0.0, 0),
		"leg_r": Vector3(2.55, 0, 0.12), "shin_r": Vector3(-0.04, 0, 0), "leg_l": Vector3(-0.05, 0, -0.05), "shin_l": Vector3(-0.12, 0, 0),
		"arm_l": Vector3(1.6, 0, -1.25), "fore_l": Vector3(0.35, 0, 0), "hand_l": Vector3(0.1, 0, 0),
		"arm_r": Vector3(1.35, 0, 1.35), "fore_r": Vector3(0.35, 0, 0), "hand_r": Vector3(0.1, 0, 0),
		"_lift": Vector3(0, rise, 0), "_scale": Vector3(0.97, 1.05, 0.98)}


## ...and the heel brought down through them into the ground, crunched over it, the arms whipped down and back.
static func _heel_down() -> Dictionary:
	return {"pivot": Vector3(-0.32, 0.05, 0), "hips": Vector3(0, 0.1, 0), "torso": Vector3(-0.45, -0.05, 0), "head": Vector3(0.5, 0.0, 0),
		"leg_r": Vector3(0.75, 0, 0.1), "shin_r": Vector3(-0.15, 0, 0), "leg_l": Vector3(0.2, 0, -0.12), "shin_l": Vector3(-1.05, 0, 0),
		"arm_l": Vector3(-0.55, 0, -0.65), "fore_l": Vector3(0.45, 0, 0), "hand_l": Vector3(0.1, 0, 0),
		"arm_r": Vector3(-0.55, 0, 0.65), "fore_r": Vector3(0.45, 0, 0), "hand_r": Vector3(0.1, 0, 0),
		"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(1.06, 0.92, 1.04)}


## Mule Kick: turned your back to them and down onto both hands, knees tucked (0.3 s), both heels driven back into
## them (0.42 s), held, then up and round to face them again.
static func _mule(h, u: float, T: float) -> Dictionary:
	var s := u * T
	var reach := _p([_dip(), {"arm_l": Vector3(1.85, 0, -0.35), "arm_r": Vector3(1.85, 0, 0.35)}])
	var tuck := {"hips": Vector3.ZERO, "torso": Vector3(-0.15, 0, 0), "head": Vector3(0.65, 0, 0),
		"leg_l": Vector3(1.55, 0, -0.1), "shin_l": Vector3(-2.15, 0, 0), "leg_r": Vector3(1.55, 0, 0.1), "shin_r": Vector3(-2.15, 0, 0),
		"arm_l": Vector3(1.75, 0, -0.3), "fore_l": Vector3(0.25, 0, 0), "hand_l": Vector3(-0.8, 0, 0),
		"arm_r": Vector3(1.75, 0, 0.3), "fore_r": Vector3(0.25, 0, 0), "hand_r": Vector3(-0.8, 0, 0),
		"_lift": Vector3(0, -0.36, 0), "_scale": Vector3(1.04, 0.95, 0.97)}
	var kick := tuck.merged({"torso": Vector3(-0.05, 0, 0), "head": Vector3(0.75, 0, 0),
		"leg_l": Vector3(-0.3, 0, -0.07), "shin_l": Vector3(-0.05, 0, 0), "leg_r": Vector3(-0.3, 0, 0.07), "shin_r": Vector3(-0.05, 0, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(0.98, 0.98, 1.07)}, true)
	var pz: Dictionary = h._keys(u, [[0.0, h._guard()], [0.16 / T, reach, "out"], [0.3 / T, tuck, "out"], [0.42 / T, kick, "out"],
		[0.6 / T, kick.merged({"_scale": Vector3.ONE}, true)], [0.82 / T, _walkover_land(), "out"], [1.0, h._guard()]])
	var yaw := PI * Humanoid._ease(s / 0.2) if s < 0.68 else lerpf(PI, TAU, Humanoid._ease((s - 0.68) / 0.24))
	var pitch := 0.0
	if s < 0.3:
		pitch = -1.2 * Humanoid._shape(s / 0.3, "out")
	elif s < 0.42:
		pitch = lerpf(-1.2, -1.5, Humanoid._shape((s - 0.3) / 0.12, "out"))
	elif s < 0.6:
		pitch = -1.5
	else:
		pitch = lerpf(-1.5, 0.0, Humanoid._ease((s - 0.6) / 0.25))
	pz["pivot"] = Vector3(pitch, yaw, 0)
	return pz


## A flurry kick: the right leg's roundhouse at height `k` with the hips only half over (it snaps out and back off
## the hip, the body staying on them).
static func _flick(k: float, out: bool) -> Dictionary:
	if out:
		return _sq(_kick_r(k).merged({"pivot": Vector3(0, 0.6, 0.1 + 0.15 * k), "hips": Vector3(0, 0.4, 0), "torso": Vector3(0.0, -0.4, 0.2 + 0.1 * k)}, true),
			Vector3(1.02, 0.99, 1.03))
	return _chamber_r(k).merged({"pivot": Vector3(0, 0.5, 0.06 * k), "hips": Vector3(0, 0.4, 0)}, true)


## Hailstorm Heels: up on the left foot, the right leg snapping out every HAIL_EVERY at the heights in HAIL_HEIGHTS,
## then a full roundhouse with the hips right over.
static func _hail(h, u: float, T: float) -> Dictionary:
	var keys: Array = [[0.0, h._guard()], [0.1 / T, _flick(1.0, false), "out"]]
	for i in HAIL_KICKS:
		var a: float = HAIL_FROM + HAIL_EVERY * i
		var k := float(HAIL_HEIGHTS[i])
		keys.append([(a - 0.045) / T, _flick(k, false)])
		keys.append([a / T, _flick(k, true), "out"])
	var fa: float = HAIL_FINAL_AT
	keys.append_array([[(fa - 0.1) / T, _chamber_r(1.0), "out"], [fa / T, _sq(_kick_r(1.0), Vector3(1.04, 0.97, 1.05)), "out"],
		[(fa + 0.1) / T, _kick_r(1.0)], [1.0, h._guard()]])
	return h._keys(u, keys)


## The cartwheel's star: arms up in a V overhead, legs out in a V.
const STAR := {"hips": Vector3.ZERO, "torso": Vector3.ZERO, "head": Vector3(0.0, 0, 0),
	"arm_l": Vector3(0.1, 0, -2.75), "fore_l": Vector3(0.15, 0, 0), "hand_l": Vector3(-0.5, 0, 0),
	"arm_r": Vector3(0.1, 0, 2.75), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-0.5, 0, 0),
	"leg_l": Vector3(0.0, 0, -0.8), "shin_l": Vector3(-0.08, 0, 0), "leg_r": Vector3(0.0, 0, 0.8), "shin_r": Vector3(-0.08, 0, 0),
	"_lift": Vector3.ZERO, "_scale": Vector3.ONE}


## Cartwheel Crescent: turned side-on, two cartwheels toward the right side (forward) hand over hand, the legs wheeling
## over (WHEEL_ROLL), then turned square and the heel brought down (WHEEL_HEEL).
static func _wheel(h, u: float, T: float) -> Dictionary:
	var s := u * T
	var roll_v: Vector2 = WHEEL_ROLL
	var heel: float = WHEEL_HEEL
	var pz: Dictionary = h._keys(u, [[0.0, h._guard()], [roll_v.x / T, STAR, "out"], [roll_v.y / T, STAR], [(heel - 0.12) / T, _heel_up(0.05), "out"],
		[heel / T, _heel_down(), "in"], [(heel + 0.15) / T, _heel_down().merged({"_scale": Vector3.ONE}, true)], [1.0, h._guard()]])
	var k := clampf((s - roll_v.x) / (roll_v.y - roll_v.x), 0.0, 1.0)
	var roll := -2.0 * TAU * k
	var side := PI * 0.5 * (Humanoid._ease(s / roll_v.x) if s < roll_v.x else 1.0 - Humanoid._ease((s - roll_v.y) / 0.1))
	var hp: Vector3 = pz.get("pivot", Vector3.ZERO)
	pz["pivot"] = Vector3(hp.x, hp.y + side, roll)
	if k > 0.0 and k < 1.0:
		pz["_lift"] = Vector3(0, 0.03 + 0.12 * (1.0 - cos(roll)), 0)
	return pz


## When Cartwheel Crescent's hands are down ([u from, u to, side, latched], at the played length WHEEL_DUR): each
## turn the right hand (the leading side) then the left.
static func _wheel_plants() -> Array:
	var out: Array = []
	var T: float = WHEEL_DUR
	var r: Vector2 = WHEEL_ROLL
	var turn := (r.y - r.x) * 0.5
	for i in 2:
		var a := r.x + turn * i
		out.append([(a + turn * 0.14) / T, (a + turn * 0.42) / T, "r", true])
		out.append([(a + turn * 0.36) / T, (a + turn * 0.64) / T, "l", true])
	return out


## Last Course: a spin on the left foot with the right leg dragged out low round you, quicker and quicker (heating it,
## LAST_HEAT); a storm of kicks high and mid (from LAST_KICK_FROM); a crouch, a leap with the leg up over the head and
## the heel down (LAST_HEEL); crouched over it, then up.
static func _last(h, u: float, T: float) -> Dictionary:
	var s := u * T
	var drag := {"hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.15, 0.0, -0.25), "head": Vector3(0.2, 0, 0.2),
		"leg_l": Vector3(0.25, 0, -0.05), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(0.1, 0, 1.05), "shin_r": Vector3(-0.25, 0, 0),
		"arm_l": Vector3(0.5, 0, -1.35), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3(0.1, 0, 0),
		"arm_r": Vector3(0.3, 0, 1.2), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(0.1, 0, 0),
		"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.03, 0.97, 1.03)}
	var heat: Vector2 = LAST_HEAT
	var keys: Array = [[0.0, h._guard()], [heat.x / T, drag, "out"], [heat.y / T, drag]]
	for i in LAST_KICKS:
		var a: float = LAST_KICK_FROM + LAST_KICK_EVERY * i
		var k := 2.0 if i % 2 == 0 else 1.0
		keys.append([(a - 0.06) / T, _chamber_r(k) if i % 2 == 0 else _mir(_chamber_r(k))])
		keys.append([a / T, _sq(_kick_r(k), Vector3(1.03, 0.98, 1.05)) if i % 2 == 0 else _mir(_sq(_kick_r(k), Vector3(1.03, 0.98, 1.05))), "out"])
	var heel: float = LAST_HEEL
	keys.append_array([[(heel - 0.3) / T, _p([_skip_r(), {"_lift": Vector3(0, -0.25, 0)}]), "out"], [(heel - 0.12) / T, _heel_up(0.45), "out"],
		[heel / T, _heel_down().merged({"_lift": Vector3(0, -0.34, 0)}, true), "in"], [(heel + 0.35) / T, _heel_down().merged({"_scale": Vector3.ONE}, true)],
		[1.0, h._guard()]])
	var pz: Dictionary = h._keys(u, keys)
	if s < heat.y + 0.05:
		var k := clampf((s - heat.x) / (heat.y - heat.x), 0.0, 1.0)
		var hp: Vector3 = pz.get("pivot", Vector3.ZERO)
		pz["pivot"] = Vector3(hp.x, hp.y + 3.0 * TAU * pow(k, 1.6), hp.z)
	return pz


# --------------------------------------------------------------------------
# Hands on the ground (Humanoid._process, after the arm solvers, on black-leg bodies)
# --------------------------------------------------------------------------
static func hands(h, _delta: float) -> void:
	var act: String = h.current_action()
	var wins: Array = WHEEL_PLANTS if act == "bl_wheel" else PLANTS.get(act, [])
	if wins.is_empty() or h.ragdoll != null:
		if h.has_meta("bl_latch"):
			h.remove_meta("bl_latch")
		return
	var latch: Dictionary = h.get_meta("bl_latch", {})
	var u: float = float(h._action["t"]) / maxf(float(h._action["dur"]), 0.001)
	var sc: float = h.global_basis.get_scale().x
	var floor_y: float = h.global_position.y + 0.05 * sc
	var body: Basis = h.global_basis.orthonormalized()
	for w in wins:
		var k := clampf(minf(u - float(w[0]), float(w[1]) - u) / 0.05, 0.0, 1.0)
		for side in str(w[2]):
			var key := "%s%.2f" % [side, float(w[0])]
			if k <= 0.0:
				latch.erase(key)
				continue
			var right: bool = side == "r"
			var hand: Node3D = h.hand_r if right else h.hand_l
			var at: Vector3 = hand.global_position
			var to := Vector3(at.x, floor_y, at.z)
			if bool(w[3]):
				if not latch.has(key):
					latch[key] = to
				to = latch[key]
			h.reach_hand(right, at.lerp(to, k), body * Vector3(1.0 if right else -1.0, 0.0, 0.4))
			var arm: Node3D = h.arm_r if right else h.arm_l
			arm.basis = arm.basis.orthonormalized()
	h.set_meta("bl_latch", latch)
