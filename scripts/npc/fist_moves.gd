class_name FistMoves
## Bare-handed boxing (stance "fist"): a boxer's guard, a combo of straight punches and hooks each carried out of the
## last one's turn (jab -> cross -> lead hook -> rear uppercut) and the overhand haymaker on right-click. The body is
## keyed here (the hips lead, the chest turns through, the head stays on the target); the punching hand rides a reach
## path (ActionSpecs "reach", Humanoid._reach) so a straight goes out straight and a hook swings round flat, the other
## hand keyed up by the face. Every "fs_*" move is reached from Humanoid._action_pose.
## Reach points are offsets from the punching shoulder in the body's own frame (follow 0: facing -Z, x+ right), so a
## straight is aimed at the target ahead whatever the chest's turn; their length sets the elbow (~0.66 m straight).

## Orthodox: bladed (the left side leads), chin down, the lead fist out at chin height, the rear by the cheek, elbows in.
const GUARD := {"hips": Vector3(0, -0.45, 0), "torso": Vector3(-0.12, -0.15, 0), "head": Vector3(0.16, 0.55, 0),
	"arm_l": Vector3(1.2, 0.45, -0.1), "fore_l": Vector3(1.55, 0, 0), "hand_l": Vector3.ZERO,
	"arm_r": Vector3(0.85, 0.7, 0.1), "fore_r": Vector3(2.25, 0, 0), "hand_r": Vector3.ZERO}
## The stance's feet (Humanoid.STANCE_LEGS): the lead foot ahead, knees soft.
const LEGS := {"leg_l": Vector3(0.3, 0, -0.14), "leg_r": Vector3(-0.25, 0, 0.14), "shin_l": Vector3(-0.42, 0, 0), "shin_r": Vector3(-0.48, 0, 0),
	"_lift": Vector3(0, -0.1, 0)}

## The off hand while the other punches: tucked to the chin, the elbow down over the ribs.
const L_UP := {"arm_l": Vector3(0.75, 0.4, -0.05), "fore_l": Vector3(2.25, 0, 0)}
const R_UP := {"arm_r": Vector3(0.85, 0.7, 0.1), "fore_r": Vector3(2.25, 0, 0)}

## Where each fist sits in the guard, from its shoulder (every reach starts and ends here, so the hand leaves and
## rejoins the keyed guard without a pop).
const AT_L := Vector3(0.04, 0.14, -0.41)
const AT_R := Vector3(-0.01, 0.09, -0.24)

const JAB_REACH := {"hand": "l", "from_shoulder": true, "center": Vector3.ZERO, "pole": Vector3(-0.6, -1.0, 0.2), "keys": [
	[0.0, {"dir": AT_L}],
	[0.1, {"dir": Vector3(0.05, 0.13, -0.37)}],
	[0.3, {"dir": Vector3(0.09, 0.17, -0.63)}, "out"],
	[0.44, {"dir": Vector3(0.09, 0.17, -0.62)}],
	[0.64, {"dir": AT_L}, "out"]]}
const CROSS_REACH := {"hand": "r", "from_shoulder": true, "center": Vector3.ZERO, "pole": Vector3(0.6, -1.0, 0.2), "keys": [
	[0.0, {"dir": AT_R}],
	[0.14, {"dir": Vector3(0.0, 0.07, -0.2)}],
	[0.34, {"dir": Vector3(-0.17, 0.18, -0.59)}, "out"],
	[0.48, {"dir": Vector3(-0.17, 0.17, -0.58)}],
	[0.7, {"dir": AT_R}, "out"]]}
const HOOK_REACH := {"hand": "l", "from_shoulder": true, "center": Vector3.ZERO, "pole": Vector3(-1.0, 0.5, 0.2), "keys": [
	[0.0, {"dir": AT_L}],
	[0.18, {"dir": Vector3(-0.28, 0.08, -0.3)}],
	[0.36, {"dir": Vector3(0.15, 0.12, -0.46)}, "out"],
	[0.46, {"dir": Vector3(0.33, 0.1, -0.3)}],
	[0.56, {"dir": Vector3(0.33, 0.1, -0.29)}],
	[0.76, {"dir": AT_L}, "out"]]}
const UPPER_REACH := {"hand": "r", "from_shoulder": true, "center": Vector3.ZERO, "pole": Vector3(0.3, -1.0, 0.2), "keys": [
	[0.0, {"dir": AT_R}],
	[0.24, {"dir": Vector3(-0.05, -0.25, -0.28)}],
	[0.42, {"dir": Vector3(-0.16, 0.03, -0.46)}, "out"],
	[0.5, {"dir": Vector3(-0.14, 0.13, -0.42)}],
	[0.6, {"dir": Vector3(-0.14, 0.14, -0.41)}],
	[0.8, {"dir": AT_R}, "out"]]}
const HAY_REACH := {"hand": "r", "from_shoulder": true, "center": Vector3.ZERO, "pole": Vector3(1.0, 0.3, 0.6), "keys": [
	[0.0, {"dir": AT_R}],
	[0.3, {"dir": Vector3(0.2, 0.45, 0.0)}],
	[0.36, {"dir": Vector3(0.21, 0.46, 0.02)}],
	[0.42, {"dir": Vector3(0.04, 0.5, -0.34), "pole": Vector3(1.0, 0.5, 0.2)}, "in"],
	[0.47, {"dir": Vector3(-0.15, 0.29, -0.57), "pole": Vector3(1.0, 0.0, 0.2)}],
	[0.53, {"dir": Vector3(-0.24, 0.2, -0.58), "pole": Vector3(1.0, -0.2, 0.2)}, "out"],
	[0.62, {"dir": Vector3(-0.42, -0.12, -0.38), "pole": Vector3(1.0, -0.5, 0.3)}],
	[0.74, {"dir": Vector3(-0.41, -0.13, -0.37), "pole": Vector3(1.0, -0.5, 0.3)}]]}
## Cannonball Fist: the right fist chambered low by the hip, then driven out dead straight and long (u: of CANNON_LEN).
const CANNON_REACH := {"hand": "r", "from_shoulder": true, "center": Vector3.ZERO, "pole": Vector3(0.6, -1.0, 0.3), "keys": [
	[0.0, {"dir": AT_R}],
	[0.28, {"dir": Vector3(0.08, -0.22, 0.02)}],
	[0.36, {"dir": Vector3(-0.1, 0.1, -0.66)}, "out"],
	[0.62, {"dir": Vector3(-0.1, 0.1, -0.65)}],
	[0.9, {"dir": AT_R}, "out"]]}
const CANNON_LEN := 0.8
const CANNON_AT := 0.29
## Meteor Fist, keyed in seconds: the crouch, the hop with the fist raised over the head, the overhand driven down
## (held until it lands: the move is played as long as the fall).
const METEOR_HOP := 0.12
const METEOR_TOP := 0.3
const METEOR_DRIVE := 0.42


static func _sq(p: Dictionary, sc: Vector3) -> Dictionary:
	return p.merged({"_scale": sc}, true)


## The jab's strike: the lead shoulder rolled forward (the chest turned on round to the right), a half step in on the
## lead foot, the chin behind the shoulder.
static func _jab_out() -> Dictionary:
	return {"pivot": Vector3(-0.05, 0, 0), "hips": Vector3(0, -0.62, 0), "torso": Vector3(-0.18, -0.28, 0.05), "head": Vector3(0.22, 0.85, -0.04),
		"leg_l": Vector3(0.5, 0, -0.14), "shin_l": Vector3(-0.42, 0, 0), "leg_r": Vector3(-0.38, 0, 0.14), "shin_r": Vector3(-0.3, 0, 0),
		"hand_l": Vector3(-0.5, 0, 0), "_lift": Vector3(0, -0.12, 0)}.merged(R_UP)


## The cross's strike: the back heel turned out, hips and chest whipped round to the left past square, the weight
## over the lead knee, the left fist back at the chin.
static func _cross_out() -> Dictionary:
	return {"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.22, 0), "torso": Vector3(-0.28, 0.16, -0.06), "head": Vector3(0.3, -0.36, 0.04),
		"leg_l": Vector3(0.62, 0, -0.16), "shin_l": Vector3(-0.75, 0, 0), "leg_r": Vector3(-0.55, 0.35, 0.16), "shin_r": Vector3(-0.15, 0, 0),
		"_lift": Vector3(0, -0.16, 0)}.merged(L_UP)


## Loaded for the lead hook: the cross's turn held, the weight settling onto the lead foot.
static func _hook_load() -> Dictionary:
	return {"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.2, 0.1, 0.08), "head": Vector3(0.26, -0.33, -0.04),
		"leg_l": Vector3(0.5, 0, -0.16), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.42, 0.2, 0.16), "shin_r": Vector3(-0.4, 0, 0),
		"_lift": Vector3(0, -0.16, 0)}.merged(R_UP)


## The hook's follow-through: the lead heel pivoted, hips and chest swung on round to the right.
static func _hook_out() -> Dictionary:
	return {"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, -0.6, 0), "torso": Vector3(-0.2, -0.3, -0.06), "head": Vector3(0.24, 0.85, 0.04),
		"leg_l": Vector3(0.38, -0.3, -0.16), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.32, 0, 0.16), "shin_r": Vector3(-0.5, 0, 0),
		"_lift": Vector3(0, -0.14, 0)}.merged(R_UP)


## Dipped for the uppercut: knees bent, the right shoulder dropped, the chest still turned from the hook.
static func _upper_load() -> Dictionary:
	return {"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, -0.55, 0), "torso": Vector3(-0.22, -0.25, 0.14), "head": Vector3(0.3, 0.75, -0.08),
		"leg_l": Vector3(0.55, 0, -0.16), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.15, 0, 0.16), "shin_r": Vector3(-1.0, 0, 0),
		"_lift": Vector3(0, -0.27, 0)}.merged(L_UP)


## The uppercut's strike: the legs driven straight, the hips turned round to the left, the chest rising up behind the fist.
static func _upper_out() -> Dictionary:
	return {"pivot": Vector3(0.02, 0, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(0.05, 0.15, -0.08), "head": Vector3(0.05, -0.35, 0.04),
		"leg_l": Vector3(0.35, 0, -0.16), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(-0.38, 0.3, 0.16), "shin_r": Vector3(-0.12, 0, 0),
		"_lift": Vector3(0, -0.03, 0)}.merged(L_UP)


## The haymaker cocked: the weight rocked back onto the rear foot, the chest turned far round to the right and leaning
## back, the right fist drawn up behind the head, the left arm out ahead measuring the target.
static func _hay_cock() -> Dictionary:
	return {"pivot": Vector3(0.12, 0, 0), "hips": Vector3(0, -0.7, 0), "torso": Vector3(0.12, -0.42, -0.1), "head": Vector3(0.05, 1.05, 0.08),
		"leg_l": Vector3(0.45, 0, -0.18), "shin_l": Vector3(-0.2, 0, 0), "leg_r": Vector3(-0.1, 0, 0.18), "shin_r": Vector3(-0.85, 0, 0),
		"arm_l": Vector3(1.45, 0.75, -0.1), "fore_l": Vector3(0.45, 0, 0),
		"_lift": Vector3(0, -0.16, 0)}


## The haymaker landing: a long step in on the lead foot, everything turned through to the left and dropped over the
## lead knee, the fist come over the top and down through them, the left fist yanked back to the chin.
static func _hay_out() -> Dictionary:
	return {"pivot": Vector3(-0.16, 0, 0), "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.3, 0.15, -0.1), "head": Vector3(0.32, -0.45, 0.05),
		"leg_l": Vector3(0.85, 0, -0.18), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(-0.65, 0.4, 0.18), "shin_r": Vector3(-0.2, 0, 0),
		"_lift": Vector3(0, -0.22, 0)}.merged(L_UP)


## [pose, mask, lift] for a fist move.
static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	var g: Dictionary = h._guard()
	match n:
		"fs_jab":
			var out := _jab_out()
			return [h._keys(u, [[0.0, g], [0.1, g.merged({"hips": Vector3(0, -0.4, 0), "_lift": Vector3(0, -0.13, 0)}, true)],
				[0.3, _sq(out, Vector3(0.99, 0.99, 1.03)), "out"], [0.46, out], [1.0, g]]), "full", lift]
		"fs_cross":
			var load_ := {"hips": Vector3(0, -0.6, 0), "torso": Vector3(-0.14, -0.22, 0), "head": Vector3(0.2, 0.8, 0), "_lift": Vector3(0, -0.14, 0),
				"shin_r": Vector3(-0.6, 0, 0)}.merged(L_UP)
			var out := _cross_out()
			return [h._keys(u, [[0.0, g], [0.14, load_], [0.34, _sq(out, Vector3(0.98, 0.99, 1.05)), "out"], [0.5, out], [1.0, g]]), "full", lift]
		"fs_hook":
			var out := _hook_out()
			return [h._keys(u, [[0.0, g], [0.18, _hook_load()], [0.4, _sq(out, Vector3(1.04, 0.98, 1.0)), "out"], [0.56, out], [1.0, g]]), "full", lift]
		"fs_upper":
			var out := _upper_out()
			return [h._keys(u, [[0.0, g], [0.24, _sq(_upper_load(), Vector3(1.03, 0.95, 1.0))], [0.44, _sq(out, Vector3(0.97, 1.06, 0.99)), "out"],
				[0.58, out], [1.0, g]]), "full", lift]
		"fs_hay":
			var cock := _hay_cock()
			var over := cock.merged({"pivot": Vector3(0.0, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.1, -0.1, -0.1), "head": Vector3(0.2, 0.35, 0.05),
				"leg_l": Vector3(0.75, 0, -0.18), "shin_l": Vector3(-0.6, 0, 0), "arm_l": Vector3(1.3, 0.6, -0.1), "fore_l": Vector3(1.0, 0, 0),
				"_lift": Vector3(0, -0.2, 0)}, true)
			var out := _hay_out()
			return [h._keys(u, [[0.0, g], [0.3, _sq(cock, Vector3(1.03, 0.96, 0.98)), "out"], [0.36, cock], [0.42, over, "in"],
				[0.47, _sq(out, Vector3(1.04, 0.94, 1.06))], [0.56, out.merged({"_scale": Vector3(1.02, 0.97, 1.02)}, true), "out"], [0.72, out], [1.0, g]]), "full", lift]
		"fs_catch":
			# Shoulder Throw's guard: sunk on the back foot, both hands open and out to catch the blow, the lead one high
			var c := {"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, -0.5, 0), "torso": Vector3(0.04, -0.3, 0.02 * sin(h._t * 6.0)),
				"head": Vector3(0.1, 0.45, 0),
				"arm_l": Vector3(1.45, 0.3, -0.2), "fore_l": Vector3(0.7, 0, 0), "hand_l": Vector3(-0.7, 0, 0),
				"arm_r": Vector3(1.0, 0.55, 0.15), "fore_r": Vector3(1.3, 0, 0), "hand_r": Vector3(-0.6, 0, 0),
				"leg_l": Vector3(0.4, 0, -0.16), "shin_l": Vector3(-0.35, 0, 0), "leg_r": Vector3(-0.18, 0, 0.16), "shin_r": Vector3(-0.85, 0, 0),
				"_lift": Vector3(0, -0.18, 0)}
			return [h._keys(u, [[0.0, g], [0.14, _sq(c, Vector3(1.03, 0.97, 1.0)), "out"], [0.22, c], [0.86, c], [1.0, g]]), "full", lift]
		"fs_cannon":
			# planted wide and low, turned away with the fist chambered by the hip; then everything driven through
			# to the left behind one long straight, the rear leg locked out
			var load_ := {"pivot": Vector3(0.04, 0, 0), "hips": Vector3(0, -0.75, 0), "torso": Vector3(-0.05, -0.35, 0.06), "head": Vector3(0.18, 1.0, -0.04),
				"leg_l": Vector3(0.55, 0, -0.3), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.35, 0, 0.3), "shin_r": Vector3(-0.9, 0, 0),
				"arm_l": Vector3(1.4, 0.5, -0.15), "fore_l": Vector3(0.4, 0, 0), "_lift": Vector3(0, -0.3, 0)}
			var out := {"pivot": Vector3(-0.14, 0, 0), "hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.25, 0.3, -0.08), "head": Vector3(0.3, -0.6, 0.05),
				"leg_l": Vector3(0.95, 0, -0.26), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.85, 0.35, 0.26), "shin_r": Vector3(-0.05, 0, 0),
				"_lift": Vector3(0, -0.36, 0)}.merged(L_UP)
			return [h._keys(u, [[0.0, g], [0.28, _sq(load_, Vector3(1.05, 0.94, 1.0)), "out"], [0.36, _sq(out, Vector3(0.96, 1.0, 1.08))],
				[0.42, out, "out"], [0.62, out], [1.0, g]]), "full", lift]
		"fs_meteor":
			# crouched, the hop with the right fist raised high over the head (the left out ahead sighting), then the
			# overhand brought over and driven straight down at the ground, the body pitched over behind it
			var T: float = float(h._action.get("dur", 1.0))
			var crouch := {"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.3, -0.3, 0), "head": Vector3(0.3, 0.3, 0),
				"arm_r": Vector3(0.3, 0.3, 0.35), "fore_r": Vector3(1.9, 0, 0), "arm_l": Vector3(1.2, 0.4, -0.2), "fore_l": Vector3(1.2, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.18), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.45, 0, 0.18), "shin_r": Vector3(-1.4, 0, 0),
				"_lift": Vector3(0, -0.32, 0)}
			var top := {"pivot": Vector3(0.15, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(0.2, -0.35, -0.05), "head": Vector3(0.0, 0.4, 0),
				"arm_r": Vector3(3.0, 0.2, 0.25), "fore_r": Vector3(0.9, 0, 0), "arm_l": Vector3(1.55, 0.3, -0.25), "fore_l": Vector3(0.2, 0, 0),
				"leg_l": Vector3(1.3, 0, -0.15), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(0.5, 0, 0.15), "shin_r": Vector3(-1.6, 0, 0)}
			var drive := {"pivot": Vector3(-0.55, 0, 0), "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.45, 0.3, -0.05), "head": Vector3(0.35, -0.35, 0),
				"arm_r": Vector3(0.7, -0.2, 0.05), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(-0.4, 0, -0.5), "fore_l": Vector3(0.9, 0, 0),
				"leg_l": Vector3(0.3, 0, -0.15), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.5, 0, 0.15), "shin_r": Vector3(-0.8, 0, 0)}
			return [h._keys(u, [[0.0, g], [METEOR_HOP / T, _sq(crouch, Vector3(1.05, 0.92, 1.03)), "out"],
				[METEOR_TOP / T, _sq(top, Vector3(0.96, 1.07, 0.98)), "out"], [(METEOR_DRIVE - 0.04) / T, top],
				[METEOR_DRIVE / T, _sq(drive, Vector3(0.95, 1.08, 1.0)), "in"], [1.0, drive]]), "full", lift]
		"fs_dive":
			# Diving Fist: knees tucked, the right fist drawn back by the ear (0.12 s), then the body pitched down the
			# dive behind the fist shot straight out, the left arm thrown back, the legs trailing
			var T: float = float(h._action.get("dur", 1.0))
			var k_go := 0.12 / T
			var cock := {"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, -0.35, 0), "torso": Vector3(-0.2, -0.4, 0), "head": Vector3(0.2, 0.4, 0),
				"arm_r": Vector3(0.6, 0.6, 0.6), "fore_r": Vector3(2.2, 0, 0), "arm_l": Vector3(1.4, 0.3, -0.2), "fore_l": Vector3(0.4, 0, 0),
				"leg_l": Vector3(1.5, 0, -0.12), "shin_l": Vector3(-2.1, 0, 0), "leg_r": Vector3(1.1, 0, 0.12), "shin_r": Vector3(-1.9, 0, 0),
				"_scale": Vector3(1.04, 0.94, 1.02)}
			var punch := {"pivot": Vector3(-0.6, 0, 0), "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.3, 0.35, 0), "head": Vector3(0.45, -0.3, 0),
				"arm_r": Vector3(1.75, -0.25, 0.0), "fore_r": Vector3(0.02, 0, 0), "arm_l": Vector3(-0.7, 0, -0.6), "fore_l": Vector3(0.5, 0, 0),
				"leg_l": Vector3(-0.3, 0, -0.1), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(0.1, 0, 0.1), "shin_r": Vector3(-0.9, 0, 0),
				"_scale": Vector3(0.95, 1.0, 1.08)}
			return [h._keys(u, [[0.0, g], [k_go * 0.85, cock, "out"], [k_go, cock], [k_go + 0.08, punch, "out"], [1.0, punch]]), "full", lift]
		"fs_meteor_land":
			# the fist sunk in the ground, crouched deep over it, then up to the guard
			var plant := {"pivot": Vector3(-0.25, 0, 0), "hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.85, 0.25, -0.05), "head": Vector3(0.6, -0.25, 0),
				"arm_r": Vector3(0.45, -0.1, 0.1), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(-0.3, 0, -0.6), "fore_l": Vector3(0.9, 0, 0),
				"leg_l": Vector3(1.25, 0, -0.25), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(-0.2, 0, 0.25), "shin_r": Vector3(-1.6, 0, 0),
				"_scale": Vector3(1.06, 0.9, 1.04)}
			lift.y = -0.55 * (1.0 - h._ease(clampf((u - 0.45) / 0.55, 0.0, 1.0)))
			return [h._keys(u, [[0.0, plant], [0.45, plant], [1.0, g]]), "full", lift]
	push_error("FistMoves: no pose for \"%s\"" % n)
	return [g, "full", lift]
