class_name WieldMoves
## Key poses for the two-weapon movesets: sword + pistol (stance "sword_pistol":
## a one-handed blade in the right hand, a pistol in the left) and dual wield
## (stance "dual_sword": a blade in each hand; an axe or a dagger in the off hand
## changes the off hand's blows, see offhand_kind). Reached from
## TechniquePoses.pose for names it doesn't know; same conventions as humanoid.gd
## (the driftwake-animation skill). The left hand's pistol sits in a fixed grip
## along the forearm (Humanoid.point_guns), so hand_l is never keyed with it: the
## arm aims. Moves keyed in seconds read the played length from _action["dur"].


## The sword-and-pistol guard: side on as in the cutlass guard (the hips: StanceLife.HIPS), the cutlass forward,
## the pistol drawn back across the chest, muzzle up by the right shoulder.
const SP_GUARD := {"arm_r": Vector3(0.8, 0.0, 0.66), "fore_r": Vector3(0.45, 0, 0), "hand_r": Vector3(-1.0, 0, 0),
	"arm_l": Vector3(0.6, -0.9, 0.1), "fore_l": Vector3(1.9, 0, 0), "hand_l": Vector3.ZERO,
	"torso": Vector3(-0.06, 0.28, 0.04), "head": Vector3(0.04, -0.7, 0)}


## The dual guard: elbows in, the right blade a little above level, the left lower and out; an off-hand axe low, a dagger close.
static var _GUARD_R := DaggerMoves.wrist_to(Vector3(0.6, 0.05, 0.2), 1.0, Vector3(0.12, 0.3, -1.0))
static var _GUARD_L := DaggerMoves.wrist_to(Vector3(0.45, 0.1, -0.3), 0.85, Vector3(-0.25, -0.12, -1.0))


## The mastered guard (Humanoid.guard2), keyed (two blades: no held grips). Two candidates for Zach's pick
## (`preview`): "a" upper and lower, the right blade raised high over the head with its point hung forward at them, the
## left low ahead pointing at their belly; "b" wings, chest down and forward, both arms out wide to the sides, the
## blades swept out and back like wings.
static var preview := "a"
static var GUARD2 := {
	"a": {"hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.05, 0.3, 0.03), "head": Vector3(0.05, -0.45, 0),
		"arm_r": Vector3(2.6, 0.3, 0.35), "fore_r": Vector3(0.7, 0, 0), "hand_r": DaggerMoves.wrist_to(Vector3(2.6, 0.3, 0.35), 0.7, Vector3(-0.1, -0.35, -0.93)),
		"arm_l": Vector3(0.75, -0.1, -0.15), "fore_l": Vector3(0.45, 0, 0), "hand_l": DaggerMoves.wrist_to(Vector3(0.75, -0.1, -0.15), 0.45, Vector3(0.1, -0.15, -0.98))},
	"b": {"hips": Vector3.ZERO, "torso": Vector3(-0.35, 0, 0), "head": Vector3(0.35, 0, 0),
		"arm_r": Vector3(0.35, 0.0, 1.15), "fore_r": Vector3(0.4, 0, 0), "hand_r": DaggerMoves.wrist_to(Vector3(0.35, 0.0, 1.15), 0.4, Vector3(0.75, -0.35, 0.55)),
		"arm_l": Vector3(0.35, 0.0, -1.15), "fore_l": Vector3(0.4, 0, 0), "hand_l": DaggerMoves.wrist_to(Vector3(0.35, 0.0, -1.15), 0.4, Vector3(-0.75, -0.35, 0.55))}}
static var LEGS2 := {
	"a": {"leg_l": Vector3(-0.15, 0, -0.2), "leg_r": Vector3(0.35, 0, 0.2), "shin_l": Vector3(-0.55, 0, 0), "shin_r": Vector3(-0.65, 0, 0), "_lift": Vector3(0, -0.12, 0)},
	"b": {"leg_l": Vector3(0.55, 0, -0.3), "leg_r": Vector3(-0.3, 0, 0.3), "shin_l": Vector3(-1.0, 0, 0), "shin_r": Vector3(-0.75, 0, 0), "_lift": Vector3(0, -0.24, 0)}}


static func guard(h) -> Dictionary:
	return GUARD2[preview] if h.guard2 else dual_guard(offhand_kind(h))


static func legs(h) -> Dictionary:
	return LEGS2[preview] if h.guard2 else Humanoid.STANCE_LEGS["dual_sword"]


static func grips2() -> Array:
	return []


static func dual_guard(kind: String) -> Dictionary:
	var g := {"arm_r": Vector3(0.6, 0.05, 0.2), "fore_r": Vector3(1.0, 0, 0), "hand_r": _GUARD_R,
		"arm_l": Vector3(0.45, 0.1, -0.3), "fore_l": Vector3(0.85, 0, 0), "hand_l": _GUARD_L,
		"torso": Vector3(-0.08, 0.12, 0), "head": Vector3(0.05, -0.12, 0)}
	match kind:
		"axe":
			g["arm_l"] = Vector3(0.4, 0.25, -0.3)
			g["fore_l"] = Vector3(0.55, 0, 0)
			g["hand_l"] = Vector3(-0.95, 0, 0)
		"dagger":
			# (held reversed: the blade down out of the bottom of the fist, DaggerMoves.rev)
			g["arm_l"] = Vector3(0.95, 0.35, -0.2)
			g["fore_l"] = Vector3(1.45, 0, 0)
			g["hand_l"] = Vector3(DaggerMoves.rev(0.95, 1.45, 0.3), 0, 0)
	return g


## What the body holds in its off hand (from the weapon's model, so every screen agrees).
static func offhand_kind(h) -> String:
	var o: MeshInstance3D = h.offhand
	if o == null or not is_instance_valid(o) or o.mesh == null:
		return ""
	var k := str(o.mesh.get_meta("model", "")).get_slice(":", 0)
	return k if k in ["pistol", "axe", "dagger"] else "sword"


static func _with(p: Dictionary, extra: Dictionary) -> Dictionary:
	return p.merged(extra, true)


## Shot recoil on the pistol arm: up and the elbow giving.
static func _kick(p: Dictionary, k: float = 1.0) -> Dictionary:
	var out := p.duplicate()
	out["arm_l"] = (p["arm_l"] as Vector3) + Vector3(0.5 * k, 0, 0)
	out["fore_l"] = (p["fore_l"] as Vector3) + Vector3(0.4 * k, 0, 0)
	out["torso"] = (p["torso"] as Vector3) + Vector3(0.12 * k, 0.08 * k, 0)
	out["head"] = (p["head"] as Vector3) + Vector3(-0.07 * k, 0, 0)
	out["_scale"] = Vector3(1.02, 0.98, 0.97)
	return out


## The pistol thrust out at the chest of whoever's in front, the left shoulder
## driven forward, the cutlass carried low by the right hip, point forward.
const SP_AIM := {"hips": Vector3(0, -0.35, 0), "torso": Vector3(-0.22, -0.5, 0.05), "head": Vector3(0.14, 0.45, 0),
	"arm_l": Vector3(1.5, 0.55, 0.0), "fore_l": Vector3(0.05, 0, 0), "hand_l": Vector3.ZERO,
	"arm_r": Vector3(-0.1, 0.25, 0.5), "fore_r": Vector3(0.65, 0, 0), "hand_r": Vector3(-0.1, 0, 0),
	"leg_l": Vector3(0.85, 0, -0.12), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(-0.6, 0, 0.14), "shin_r": Vector3(-0.3, 0, 0),
	"_lift": Vector3(0, -0.2, 0)}


## [pose, mask, lift] for a two-weapon move, or [] if `n` isn't one.
static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	var g: Dictionary = h._guard()
	var T: float = float(h._action.get("dur", 1.0))
	var s := u * T
	match n:
		# --- sword + pistol: the combo ---
		"sp_cut":
			# hit 1: the cutlass hauled up behind the right shoulder (the pistol tucked to
			# the chest), a held beat, then a diagonal forehand down to the lower left,
			# stepping through, the pistol arm flung back
			var wind := {"hips": Vector3(0, -0.45, 0), "torso": Vector3(0.08, -0.75, 0.08), "head": Vector3(0.0, 0.6, 0),
				"arm_r": Vector3(2.35, 0.5, 1.25), "fore_r": Vector3(1.1, 0, 0), "hand_r": Vector3(0.7, 0, 0),
				"arm_l": Vector3(0.9, 0.35, -0.2), "fore_l": Vector3(1.6, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.35, 0, -0.14), "shin_l": Vector3(-0.7, 0, 0), "leg_r": Vector3(-0.25, 0, 0.14), "shin_r": Vector3(-0.5, 0, 0),
				"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(1.03, 0.95, 1.0)}
			var cut := {"hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.4, 0.7, -0.1), "head": Vector3(0.25, -0.55, 0),
				"arm_r": Vector3(0.85, -0.9, -0.9), "fore_r": Vector3(0.08, 0, 0), "hand_r": Vector3(-1.35, 0, 0),
				"arm_l": Vector3(-0.4, 0.2, -0.7), "fore_l": Vector3(0.5, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.75, 0, 0.14), "shin_r": Vector3(-0.25, 0, 0),
				"_lift": Vector3(0, -0.26, 0)}
			var whip := _with(cut, {"_scale": Vector3(1.06, 0.97, 1.03), "_smear": Vector3(0.7, 0, 0)})
			return [h._keys(u, [[0.0, g], [0.3, wind, "out"], [0.36, wind], [0.46, whip, "out"], [0.52, cut], [0.7, cut], [1.0, g]]), "full", lift]
		"sp_shot":
			# hit 2: the left shoulder driven in, the pistol punched out at their chest
			# and fired point-blank (0.2 s), the kick throwing the arm up
			var aim := SP_AIM.merged({"_scale": Vector3(0.97, 1.0, 1.06)}, true)
			var k_f := 0.2 / T
			return [h._keys(u, [[0.0, g], [k_f - 0.1, aim, "out"], [k_f, SP_AIM], [k_f + 0.06, _kick(SP_AIM), "out"], [0.7, SP_AIM], [1.0, g]]), "full", lift]
		"sp_rise":
			# hit 3: dropped low on the right with the blade cocked behind the hip, then a
			# rising cut up across to the high left, stretching up through it
			var low := {"hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.35, -0.7, 0.08), "head": Vector3(0.25, 0.55, 0),
				"arm_r": Vector3(-0.15, 0.3, 0.6), "fore_r": Vector3(0.5, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(0.8, 0.4, -0.2), "fore_l": Vector3(1.7, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.55, 0, -0.14), "shin_l": Vector3(-1.05, 0, 0), "leg_r": Vector3(-0.3, 0, 0.14), "shin_r": Vector3(-0.75, 0, 0),
				"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.04, 0.94, 1.0)}
			var rise := {"hips": Vector3(0, 0.4, 0), "torso": Vector3(0.1, 0.7, -0.08), "head": Vector3(-0.1, -0.5, 0),
				"arm_r": Vector3(2.6, -0.5, -0.5), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.2, 0, 0),
				"arm_l": Vector3(-0.3, -0.1, -0.9), "fore_l": Vector3(0.45, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.9, 0, -0.12), "shin_l": Vector3(-0.7, 0, 0), "leg_r": Vector3(-0.5, 0, 0.14), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.04, 0)}
			var whip := _with(rise, {"_scale": Vector3(0.97, 1.07, 1.0), "_smear": Vector3(0.7, 0, 0)})
			return [h._keys(u, [[0.0, g], [0.28, low, "out"], [0.34, low], [0.44, whip, "out"], [0.5, rise], [0.68, rise], [1.0, g]]), "full", lift]
		"sp_finale":
			# hit 4 (Powder Finale): coiled left, a full turn with the blade out level,
			# then square to them with the pistol thrust out and fired (0.62 s)
			var coil := {"hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.25, 0.8, 0.05), "head": Vector3(0.15, -0.6, 0),
				"arm_r": Vector3(0.9, 0.6, 1.3), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(1.0, 0.3, -0.4), "fore_l": Vector3(1.4, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.6, 0, -0.2), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.2, 0, 0.2), "shin_r": Vector3(-0.8, 0, 0),
				"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.04, 0.94, 1.02)}
			var out := {"hips": Vector3.ZERO, "torso": Vector3(-0.2, 0.0, 0.1), "head": Vector3(0.12, 0, 0),
				"arm_r": Vector3(1.4, 0.0, 1.5), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.5, 0, 0),
				"arm_l": Vector3(0.7, 0.0, -1.0), "fore_l": Vector3(0.8, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.5, 0, -0.25), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.2, 0, 0.25), "shin_r": Vector3(-0.6, 0, 0),
				"_lift": Vector3(0, -0.12, 0)}
			var whirl := _with(out, {"_smear": Vector3(0.5, 0, 0), "_scale": Vector3(1.03, 0.98, 1.03)})
			var k_f := 0.62 / T
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.1, coil, "out"], [0.14, coil], [0.22, whirl, "out"], [0.4, out],
				[k_f - 0.08, SP_AIM, "out"], [k_f, SP_AIM], [k_f + 0.05, _kick(SP_AIM, 1.2), "out"], [0.86, SP_AIM], [1.0, g]])
			var k := clampf((u - 0.14) / 0.3, 0.0, 1.0)
			pz["pivot"] = Vector3(0, -TAU * (1.0 - pow(1.0 - k, 2.2)), 0)
			return [pz, "full", lift]
		# --- sword + pistol: the heavy (Powder Lunge) ---
		"sp_lunge":
			# coiled back, a long fencing lunge that skewers them, then the pistol thrust
			# in beside the blade and fired into them as it comes out (0.57 s)
			var coil := {"hips": Vector3(0, -0.4, 0), "torso": Vector3(0.05, -0.55, 0.05), "head": Vector3(0.05, 0.5, 0),
				"arm_r": Vector3(0.15, 0.0, 0.5), "fore_r": Vector3(1.85, 0, 0), "hand_r": Vector3(-2.0, 0, 0),
				"arm_l": Vector3(0.9, 0.3, -0.3), "fore_l": Vector3(1.6, 0, 0), "hand_l": Vector3.ZERO,
				"leg_r": Vector3(0.3, 0, 0.05), "shin_r": Vector3(-0.55, 0, 0), "leg_l": Vector3(-0.35, 0, -0.08), "shin_l": Vector3(-0.7, 0, 0),
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(1.03, 0.95, 0.96)}
			var reach := {"hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.32, 0.5, -0.05), "head": Vector3(0.3, -0.45, 0),
				"arm_r": Vector3(1.5, 0.05, 0.12), "fore_r": Vector3(0.02, 0, 0), "hand_r": Vector3(-1.52, 0, 0),
				"arm_l": Vector3(-0.6, 0, -0.55), "fore_l": Vector3(0.35, 0, 0), "hand_l": Vector3.ZERO,
				"leg_r": Vector3(1.2, 0, 0.04), "shin_r": Vector3(-1.3, 0, 0), "leg_l": Vector3(-0.95, 0, -0.06), "shin_l": Vector3(-0.08, 0, 0),
				"_lift": Vector3(0, -0.32, 0)}
			var lunge := _with(reach, {"_scale": Vector3(0.96, 0.99, 1.1), "_smear": Vector3(0.8, 0, 0)})
			var shoot := {"hips": Vector3(0, 0.05, 0), "torso": Vector3(-0.3, -0.15, 0.03), "head": Vector3(0.2, 0.12, 0),
				"arm_r": Vector3(0.6, 0.2, 0.75), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(-0.4, 0, 0),
				"arm_l": Vector3(1.5, 0.35, 0.05), "fore_l": Vector3(0.05, 0, 0), "hand_l": Vector3.ZERO,
				"leg_r": Vector3(1.1, 0, 0.04), "shin_r": Vector3(-1.2, 0, 0), "leg_l": Vector3(-0.85, 0, -0.06), "shin_l": Vector3(-0.12, 0, 0),
				"_lift": Vector3(0, -0.28, 0)}
			var k_f := 0.57 / T
			return [h._keys(u, [[0.0, g], [0.25, coil, "out"], [0.3, coil], [0.38, lunge, "out"], [0.44, reach], [k_f - 0.1, reach],
				[k_f - 0.03, shoot, "out"], [k_f, shoot], [k_f + 0.05, _kick(shoot, 1.3), "out"], [0.84, shoot], [1.0, g]]), "full", lift]
		# --- sword + pistol: the jump attack (Dead Man's Drop) ---
		"sp_drop":
			# knees up, leaning over them with the pistol pointed down (fired at 0.14 s, the
			# kick lifting you), then point-first down the dive, legs trailing
			var aim := {"pivot": Vector3(-0.2, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.4, -0.4, 0), "head": Vector3(0.1, 0.35, 0),
				"arm_l": Vector3(0.65, 0.5, 0.0), "fore_l": Vector3(0.05, 0, 0), "hand_l": Vector3.ZERO,
				"arm_r": Vector3(2.2, 0.3, 0.7), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"leg_l": Vector3(1.4, 0, -0.12), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(0.9, 0, 0.12), "shin_r": Vector3(-1.6, 0, 0),
				"_scale": Vector3(1.03, 0.95, 1.02)}
			var kicked := _with(aim, {"pivot": Vector3(0.05, 0, 0), "arm_l": Vector3(1.15, 0.5, 0.0), "fore_l": Vector3(0.45, 0, 0),
				"torso": Vector3(-0.2, -0.4, 0), "_scale": Vector3(0.98, 1.03, 0.98)})
			var dive := {"pivot": Vector3(-0.5, 0, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.3, 0.2, 0), "head": Vector3(0.35, -0.2, 0),
				"arm_r": Vector3(1.4, 0.05, 0.1), "fore_r": Vector3(0.0, 0, 0), "hand_r": Vector3(-1.5, 0, 0),
				"arm_l": Vector3(-0.6, 0, -0.7), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(-0.4, 0, -0.1), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(0.3, 0, 0.1), "shin_r": Vector3(-0.5, 0, 0)}
			var thrust := _with(dive, {"_scale": Vector3(0.95, 1.0, 1.1), "_smear": Vector3(0.6, 0, 0)})
			return [h._keys(u, [[0.0, {}], [0.1 / T, aim, "out"], [0.14 / T, aim], [0.17 / T, kicked, "out"], [0.24 / T, kicked],
				[0.3 / T, thrust, "out"], [0.4 / T, dive], [1.0, dive]]), "full", lift]
		"sp_drop_land":
			# down in a crouch, the blade swept low across, the pistol arm out for balance
			var plant := {"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.6, 0.5, 0), "head": Vector3(0.4, -0.4, 0),
				"arm_r": Vector3(0.9, -0.8, -0.9), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(0.3, 0.2, -1.0), "fore_l": Vector3(0.6, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(1.3, 0, -0.18), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(-0.35, 0, 0.18), "shin_r": Vector3(-1.5, 0, 0),
				"_lift": Vector3(0, -0.45, 0), "_scale": Vector3(1.05, 0.93, 1.03)}
			return [h._keys(u, [[0.0, plant], [0.35, plant], [1.0, g]]), "full", lift]
		# --- sword + pistol: techniques ---
		"parley_shot":
			# Parley's answer: the blow turned aside on the blade, then the pistol jammed
			# into their chest and fired (0.3 s) while the blade still holds theirs off
			var turn := {"hips": Vector3(0, -0.3, 0), "torso": Vector3(0.0, -0.9, -0.1), "head": Vector3(0, 0.75, 0),
				"arm_r": Vector3(1.3, -0.75, -1.05), "fore_r": Vector3(1.6, 0, 0), "hand_r": Vector3(0.5, 0, 0),
				"arm_l": Vector3(0.8, 0.35, -0.25), "fore_l": Vector3(1.6, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.3, 0, -0.15), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.3, 0, 0.15), "shin_r": Vector3(-0.5, 0, 0),
				"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(1.03, 0.95, 1.02)}
			var jam := {"hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.25, -0.6, 0.05), "head": Vector3(0.15, 0.5, 0),
				"arm_r": Vector3(1.3, -0.75, -1.05), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"arm_l": Vector3(1.4, 0.6, 0.0), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.85, 0, -0.12), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(-0.6, 0, 0.14), "shin_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.2, 0)}
			var k_f := 0.3 / T
			return [h._keys(u, [[0.0, g], [0.12, turn, "out"], [0.2, turn], [k_f - 0.06, jam, "out"], [k_f, jam], [k_f + 0.06, _kick(jam, 1.2), "out"],
				[0.78, jam], [1.0, g]]), "full", lift]
		"grapeshot":
			# braced wide, the pistol out level in the off hand, the blade held low and
			# back; the blast (0.26 s) rocks the whole body back
			var brace := {"hips": Vector3(0, -0.45, 0), "torso": Vector3(-0.15, -0.65, 0.05), "head": Vector3(0.1, 0.5, 0),
				"arm_l": Vector3(1.35, 0.6, 0.0), "fore_l": Vector3(0.25, 0, 0), "hand_l": Vector3.ZERO,
				"arm_r": Vector3(-0.2, 0.2, 0.6), "fore_r": Vector3(0.6, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.25), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.45, 0, 0.25), "shin_r": Vector3(-0.6, 0, 0),
				"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.04, 0.94, 1.02)}
			var blast := _with(brace, {"arm_l": Vector3(2.15, 0.6, 0.0), "fore_l": Vector3(0.6, 0, 0), "torso": Vector3(0.08, -0.55, 0.05),
				"head": Vector3(-0.05, 0.45, 0), "_lift": Vector3(0, -0.16, 0), "_scale": Vector3(0.96, 1.03, 0.95)})
			var k_f := 0.26 / T
			return [h._keys(u, [[0.0, g], [k_f - 0.1, brace, "out"], [k_f, brace], [k_f + 0.05, blast, "out"], [0.65, blast], [0.8, brace], [1.0, g]]), "full", lift]
		"crossfire":
			# a crouch, a low cut driving through them (0.16 s), held while you turn
			# round behind them, then the pistol thrust out and fired into their back (0.5 s)
			var crouch := {"hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.4, -0.6, 0), "head": Vector3(0.3, 0.5, 0),
				"arm_r": Vector3(0.1, 0.4, 0.55), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(0.8, 0.3, -0.3), "fore_l": Vector3(1.6, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.7, 0, -0.1), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.4, 0, 0.1), "shin_r": Vector3(-0.6, 0, 0),
				"_lift": Vector3(0, -0.18, 0), "_scale": Vector3(1.04, 0.94, 1.0)}
			var through := {"hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.45, 0.7, -0.08), "head": Vector3(0.3, -0.5, 0),
				"arm_r": Vector3(1.35, -0.9, -1.15), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.45, 0, 0),
				"arm_l": Vector3(-0.5, 0, -0.8), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(1.3, 0, -0.12), "shin_l": Vector3(-1.45, 0, 0), "leg_r": Vector3(-1.0, 0, 0.12), "shin_r": Vector3(-0.15, 0, 0),
				"_lift": Vector3(0, -0.3, 0)}
			var whip := _with(through, {"_scale": Vector3(1.0, 0.98, 1.1), "_smear": Vector3(0.8, 0, 0)})
			var k_f := 0.5 / T
			return [h._keys(u, [[0.0, g], [0.1 / T, crouch, "out"], [0.13 / T, crouch], [0.19 / T, whip, "out"], [0.25 / T, through], [0.32 / T, through],
				[k_f - 0.07, SP_AIM, "out"], [k_f, SP_AIM], [k_f + 0.05, _kick(SP_AIM, 1.2), "out"], [0.8, SP_AIM], [1.0, g]]), "full", lift]
		"broadside":
			# the ultimate: the blade raised high, chin up, as if calling a broadside
			# (gathering to 0.5 s), then swept down to point at them as the pistol fans
			# across, a shot at each (0.6 s + 0.14 s each), the blade raised again for a
			# beat, then cut down hard as the broadside lands on every one of them (1.75 s)
			var raise := {"hips": Vector3(0, 0.15, 0), "torso": Vector3(0.12, 0.25, 0), "head": Vector3(-0.12, -0.2, 0),
				"arm_r": Vector3(2.9, 0.1, 0.35), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(-0.3, 0, 0),
				"arm_l": Vector3(0.4, 0.2, -0.3), "fore_l": Vector3(1.2, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.3, 0, -0.25), "shin_l": Vector3(-0.4, 0, 0), "leg_r": Vector3(-0.2, 0, 0.25), "shin_r": Vector3(-0.35, 0, 0),
				"_lift": Vector3(0, -0.08, 0), "_scale": Vector3(0.98, 1.04, 1.0)}
			var order := {"hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.15, -0.35, 0.03), "head": Vector3(0.1, 0.3, 0),
				"arm_r": Vector3(1.45, -0.3, 0.3), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.4, 0, 0),
				"arm_l": Vector3(1.5, 0.6, 0.0), "fore_l": Vector3(0.05, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(0.75, 0, -0.14), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.5, 0, 0.16), "shin_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.18, 0)}
			var sweep := _with(order, {"_smear": Vector3(0.5, 0, 0), "_scale": Vector3(1.03, 0.98, 1.04)})
			var high := _with(raise, {"arm_l": Vector3(0.8, 0.4, -0.5), "fore_l": Vector3(0.9, 0, 0), "_lift": Vector3(0, -0.14, 0)})
			var down := {"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.5, 0.45, -0.06), "head": Vector3(0.3, -0.35, 0),
				"arm_r": Vector3(0.8, -0.6, -0.5), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(-0.3, 0.1, -0.9), "fore_l": Vector3(0.4, 0, 0), "hand_l": Vector3.ZERO,
				"leg_l": Vector3(1.05, 0, -0.14), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.8, 0, 0.16), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.3, 0)}
			var crash := _with(down, {"_scale": Vector3(1.06, 0.93, 1.03), "_smear": Vector3(0.7, 0, 0)})
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.14 / T, raise, "out"], [0.5 / T, raise], [0.58 / T, sweep, "out"], [0.66 / T, order],
				[1.36 / T, order], [1.5 / T, high, "out"], [1.66 / T, high], [1.75 / T, crash, "in"], [1.82 / T, down], [1.0 - 0.3 / T, down], [1.0, g]])
			# (the pistol fans across them, kicking with each shot)
			if s > 0.55 and s < 1.45:
				var fan := clampf((s - 0.6) / 0.7, 0.0, 1.0)
				var al: Vector3 = pz["arm_l"]
				var kick := 0.0
				for i in range(6):
					kick = maxf(kick, 1.0 - absf(s - (0.62 + 0.14 * i)) / 0.06)
				pz["arm_l"] = Vector3(al.x + 0.45 * kick, lerpf(0.75, -0.15, fan), al.z)
				pz["torso"] = (pz["torso"] as Vector3) + Vector3(0, lerpf(0.15, -0.25, fan), 0)
			return [pz, "full", lift]
		# --- dual wield: the combo ---
		"dual_1":
			return [h._keys(u, _dual_keys(g, false, "")), "full", lift]
		"dual_2":
			return [h._keys(u, _dual_keys(g, true, offhand_kind(h))), "full", lift]
		"dual_cross":
			# both blades thrown up and apart (rising onto the toes), then crossed down
			# through the front in an X, crashing into a lunge
			var open_x := {"hips": Vector3.ZERO, "torso": Vector3(0.25, 0, 0), "head": Vector3(-0.15, 0, 0),
				"arm_r": Vector3(2.5, 0.3, 0.85), "fore_r": Vector3(0.45, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(2.5, -0.3, -0.85), "fore_l": Vector3(0.45, 0, 0), "hand_l": Vector3(0.6, 0, 0),
				"leg_l": Vector3(0.4, 0, -0.15), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.1, 0, 0.15), "shin_r": Vector3(-0.7, 0, 0),
				"_lift": Vector3(0, -0.06, 0), "_scale": Vector3(0.98, 1.05, 1.0)}
			var cross_x := {"hips": Vector3.ZERO, "torso": Vector3(-0.5, 0, 0), "head": Vector3(0.3, 0, 0),
				"arm_r": Vector3(1.15, -0.85, -0.6), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(1.15, 0.85, 0.6), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(-1.3, 0, 0),
				"leg_l": Vector3(0.95, 0, -0.12), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(-0.6, 0, 0.14), "shin_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.3, 0)}
			var crash := _with(cross_x, {"_scale": Vector3(1.05, 0.93, 1.03), "_smear": Vector3(0.6, 0, 0)})
			return [h._keys(u, [[0.0, g], [0.24, open_x, "out"], [0.3, open_x], [0.4, crash, "out"], [0.46, cross_x], [0.7, cross_x], [1.0, g]]), "full", lift]
		"dual_spin":
			# Twin Spin: coiled to the left, then both blades flung out level and the
			# body whirled round once, stretched out along the turn
			var coil := {"hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.2, 0.7, 0.05), "head": Vector3(0.15, -0.5, 0),
				"arm_r": Vector3(0.9, 0.6, 1.2), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(0.5, 0, 0),
				"arm_l": Vector3(1.0, 0.5, -0.6), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3(0.4, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.2), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.2, 0, 0.2), "shin_r": Vector3(-0.8, 0, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.04, 0.94, 1.02)}
			var out := {"hips": Vector3.ZERO, "torso": Vector3(-0.2, 0, 0.1), "head": Vector3(0.12, 0, 0),
				"arm_r": Vector3(1.4, 0.0, 1.5), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.5, 0, 0),
				"arm_l": Vector3(1.4, 0.0, -1.5), "fore_l": Vector3(0.05, 0, 0), "hand_l": Vector3(-1.5, 0, 0),
				"leg_l": Vector3(0.5, 0, -0.25), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.4, 0, 0.25), "shin_r": Vector3(-0.7, 0, 0),
				"_lift": Vector3(0, -0.08, 0)}
			var whirl := _with(out, {"_smear": Vector3(0.5, 0, 0), "_scale": Vector3(1.03, 0.98, 1.03)})
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.14, coil, "out"], [0.2, coil], [0.3, whirl, "out"], [0.78, out], [1.0, g]])
			var k := clampf((u - 0.22) / 0.5, 0.0, 1.0)
			pz["pivot"] = Vector3(0, -TAU * (1.0 - pow(1.0 - k, 2.0)), 0)
			return [pz, "full", lift]
		"dual_heavy":
			# both blades raised high (leaning back, a little hop), then crashing down
			# together in front through a deep lunge
			var raise := {"hips": Vector3.ZERO, "torso": Vector3(0.4, 0, 0), "head": Vector3(-0.2, 0, 0),
				"arm_r": Vector3(3.0, 0.2, 0.45), "fore_r": Vector3(0.7, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(3.0, -0.2, -0.45), "fore_l": Vector3(0.7, 0, 0), "hand_l": Vector3(0.6, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(0.3, 0, 0.15), "shin_r": Vector3(-1.0, 0, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.04, 0.94, 1.0)}
			var air := _with(raise, {"leg_l": Vector3(0.9, 0, -0.12), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(0.2, 0, 0.12), "shin_r": Vector3(-0.9, 0, 0),
				"_lift": Vector3(0, 0.12, 0), "_scale": Vector3(0.97, 1.06, 1.0)})
			var down := {"hips": Vector3.ZERO, "torso": Vector3(-0.85, 0, 0), "head": Vector3(0.45, 0, 0),
				"arm_r": Vector3(0.6, -0.4, 0.2), "fore_r": Vector3(0.0, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
				"arm_l": Vector3(0.6, 0.4, -0.2), "fore_l": Vector3(0.0, 0, 0), "hand_l": Vector3(-0.9, 0, 0),
				"leg_l": Vector3(1.1, 0, -0.1), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(-0.85, 0, 0.1), "shin_r": Vector3(-0.15, 0, 0),
				"_lift": Vector3(0, -0.4, 0)}
			var crash := _with(down, {"_scale": Vector3(1.07, 0.92, 1.03), "_smear": Vector3(0.6, 0, 0)})
			return [h._keys(u, [[0.0, g], [0.3, raise, "out"], [0.36, raise], [0.42, air], [0.48, crash, "in"], [0.54, down], [0.74, down], [1.0, g]]), "full", lift]
		# --- the dual parry (Humanoid "parry"), its flourish when it lands, previews ---
		"dual_parry":
			var rv := offhand_kind(h) == "dagger"
			var snap := DUAL_HANG.merged({"_scale": Vector3(1.03, 0.95, 1.0)}, true)
			return [h._keys(u, [[0.0, g], [0.1, DaggerMoves.aim(snap, rv), "out"], [0.17, DaggerMoves.aim(DUAL_HANG, rv)],
				[0.6, DaggerMoves.aim(DUAL_HANG, rv)], [1.0, g]]), "full", lift]
		"dual_deflect":
			# the blow swept aside and out to the right, the body turning with it, the left blade driven in to answer
			var rv := offhand_kind(h) == "dagger"
			var whip := DUAL_SWEEP.merged({"_scale": Vector3(1.05, 0.97, 1.03), "_smear": Vector3(0.6, 0, 0)}, true)
			return [h._keys(u, [[0.0, DaggerMoves.aim(DUAL_HANG, rv)], [0.3, DaggerMoves.aim(whip, rv), "out"], [0.4, DaggerMoves.aim(DUAL_SWEEP, rv)],
				[0.66, DaggerMoves.aim(DUAL_SWEEP, rv)], [1.0, g]]), "full", lift]
		"dual_stance":
			return [{}, "upper", lift]
		"dual_block":
			return h._action_pose("guard_block", u)
	return DaggerMoves.pose(h, n, u)


## Both blades crossed in an X in front of the face, hands apart at the chin (the held block).
const DUAL_X := {"torso": Vector3(-0.14, 0, 0), "head": Vector3(0.22, 0, 0),
	"arm_r": Vector3(1.0, 0.05, -0.15), "fore_r": Vector3(1.5, 0, 0), "blade_r": Vector3(-0.5, 0.8, -0.35),
	"arm_l": Vector3(1.0, -0.05, 0.15), "fore_l": Vector3(1.5, 0, 0), "blade_l": Vector3(0.5, 0.8, -0.35)}
## The parry: the right blade slanted up across the front, point over the left shoulder, the left one low and back.
const DUAL_HANG := {"hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.15, 0.25, 0), "head": Vector3(0.15, -0.25, 0),
	"arm_r": Vector3(1.15, 0.15, 0.3), "fore_r": Vector3(0.8, 0, 0), "blade_r": Vector3(-0.6, 0.6, -0.5),
	"arm_l": Vector3(-0.15, 0.0, -0.35), "fore_l": Vector3(0.7, 0, 0), "blade_l": Vector3(-0.2, -0.1, -1.0),
	"leg_l": Vector3(0.45, 0, -0.2), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.3, 0, 0.2), "shin_r": Vector3(-0.45, 0, 0),
	"_lift": Vector3(0, -0.16, 0)}
const DUAL_SWEEP := {"hips": Vector3(0, -0.25, 0), "torso": Vector3(-0.2, -0.4, -0.05), "head": Vector3(0.15, 0.35, 0),
	"arm_r": Vector3(1.15, -0.75, 1.15), "fore_r": Vector3(0.45, 0, 0), "blade_r": Vector3(0.9, -0.2, -0.35),
	"arm_l": Vector3(1.2, 0.3, -0.2), "fore_l": Vector3(0.8, 0, 0), "blade_l": Vector3(0.1, 0.2, -1.0),
	"leg_l": Vector3(0.8, 0, -0.15), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.5, 0, 0.18), "shin_r": Vector3(-0.3, 0, 0),
	"_lift": Vector3(0, -0.2, 0)}


static func dual_block(kind: String) -> Dictionary:
	return DaggerMoves.aim(DUAL_X, kind == "dagger")


## The dual combo's single-blade cuts. Hit 1: the right blade hauled high over the
## right shoulder, then a diagonal forehand down to the lower left, the left blade
## held up on guard. Hit 2 is its mirror with the off hand, unless that's an axe
## (a higher, heavier hack down in front) or a dagger (held reversed: a backhand
## slash swept out to the left, the blade along the forearm).
static func _dual_keys(g: Dictionary, left: bool, kind: String) -> Array:
	var wind := {"hips": Vector3(0, -0.35, 0), "torso": Vector3(0.05, -0.7, 0.06), "head": Vector3(0.0, 0.55, 0),
		"arm_r": Vector3(2.3, 0.45, 1.2), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(0.7, 0, 0),
		"arm_l": Vector3(1.15, 0.45, -0.25), "fore_l": Vector3(1.25, 0, 0), "hand_l": Vector3(-0.5, 0, 0),
		"leg_l": Vector3(0.3, 0, -0.14), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.2, 0, 0.14), "shin_r": Vector3(-0.5, 0, 0),
		"_lift": Vector3(0, -0.1, 0)}
	var cut := {"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.35, 0.6, -0.08), "head": Vector3(0.2, -0.45, 0),
		"arm_r": Vector3(0.8, -0.85, -0.85), "fore_r": Vector3(0.08, 0, 0), "hand_r": Vector3(-1.35, 0, 0),
		"arm_l": Vector3(0.9, 0.1, -0.75), "fore_l": Vector3(0.9, 0, 0), "hand_l": Vector3(-0.6, 0, 0),
		"leg_l": Vector3(0.85, 0, -0.12), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.6, 0, 0.14), "shin_r": Vector3(-0.25, 0, 0),
		"_lift": Vector3(0, -0.22, 0)}
	var hold := 0.66
	if left:
		wind = Humanoid._mirror(wind)
		cut = Humanoid._mirror(cut)
		match kind:
			"axe":
				# hauled up over the left shoulder, hacked straight down in front
				wind["arm_l"] = Vector3(2.65, -0.2, -0.6)
				wind["fore_l"] = Vector3(1.2, 0, 0)
				wind["hand_l"] = Vector3(0.5, 0, 0)
				wind["torso"] = Vector3(0.15, 0.6, -0.06)
				cut["arm_l"] = Vector3(0.9, 0.4, 0.3)
				cut["fore_l"] = Vector3(0.05, 0, 0)
				cut["hand_l"] = Vector3(-0.55, 0, 0)
				cut["torso"] = Vector3(-0.45, -0.45, 0.06)
				cut["head"] = Vector3(0.28, 0.35, 0)
				cut["_lift"] = Vector3(0, -0.28, 0)
				hold = 0.72
			"dagger":
				# held reversed, the blade along the forearm: the fist carried across to the
				# right shoulder, then a backhand slash swept out to the left, edge first
				wind["arm_l"] = Vector3(1.45, -0.55, 0.5)
				wind["fore_l"] = Vector3(1.7, 0, 0)
				wind["hand_l"] = Vector3(-1.5, 0, 0)
				wind["torso"] = Vector3(0.05, -0.6, 0.06)
				wind["head"] = Vector3(0.0, 0.5, 0)
				cut["arm_l"] = Vector3(1.35, 0.45, -1.3)
				cut["fore_l"] = Vector3(0.3, 0, 0)
				cut["hand_l"] = Vector3(-1.5, 0, 0)
				cut["torso"] = Vector3(-0.3, 0.5, -0.06)
				cut["head"] = Vector3(0.2, -0.4, 0)
	var sq := Vector3(1.03, 0.95, 1.0) if kind != "axe" else Vector3(1.05, 0.93, 1.0)
	wind["_scale"] = sq
	var whip := cut.merged({"_scale": Vector3(0.97, 1.0, 1.08) if kind == "dagger" else Vector3(1.05, 0.97, 1.03),
		"_smear": Vector3(0.6, 0, 0)}, true)
	return [[0.0, g], [0.22, wind, "out"], [0.28, wind], [0.38, whip, "out"], [0.44, cut], [hold, cut], [1.0, g]]
