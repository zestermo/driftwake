class_name DualAxeMoves
## Twin axes (stance "dual_axe": an axe in each hand, both in the normal grip, the bit on the knuckle side). A
## berserker's guard: low and wide, chest pitched over the axes, both heads up and forward. Every "dx_*" move is
## keyed here (reached from Humanoid._action_pose); same joint conventions as humanoid.gd. The chops are short and
## fast with the wrist thrown through them (the head leads), the hands trading off in a rhythm; the body does
## the travelling. Moves keyed in seconds read the played length from _action["dur"].

## The guard's wrists: the right head up by the cheek, the left lower and out ahead (chest frame).
static var _GR := DaggerMoves.wrist_to(Vector3(0.75, -0.05, 0.32), 1.25, Vector3(0.15, 0.9, -0.45))
static var _GL := DaggerMoves.wrist_to(Vector3(0.6, 0.1, -0.36), 1.1, Vector3(-0.15, 0.6, -0.8))

const GUARD_BODY := {"hips": Vector3(0, -0.12, 0), "torso": Vector3(-0.26, 0.1, 0), "head": Vector3(0.2, -0.1, 0),
	"arm_r": Vector3(0.75, -0.05, 0.32), "fore_r": Vector3(1.25, 0, 0),
	"arm_l": Vector3(0.6, 0.1, -0.36), "fore_l": Vector3(1.1, 0, 0)}
static var GUARD := GUARD_BODY.merged({"hand_r": _GR, "hand_l": _GL})
## The stance's feet (Humanoid.STANCE_LEGS): wide and low, the weight forward.
const LEGS := {"leg_l": Vector3(0.55, 0, -0.26), "leg_r": Vector3(-0.26, 0, 0.26), "shin_l": Vector3(-1.02, 0, 0), "shin_r": Vector3(-0.5, 0, 0),
	"_lift": Vector3(0, -0.17, 0)}
## The held block: both hafts crossed in an X before the face, the heads up and out, the chest down behind them.
const BLOCK_X := {"torso": Vector3(-0.18, 0, 0), "head": Vector3(0.24, 0, 0),
	"arm_r": Vector3(1.05, 0.05, -0.15), "fore_r": Vector3(1.45, 0, 0), "blade_r": Vector3(-0.45, 0.85, -0.3),
	"arm_l": Vector3(1.05, -0.05, 0.15), "fore_l": Vector3(1.45, 0, 0), "blade_l": Vector3(0.45, 0.85, -0.3)}

# action-key legs
const SET := {"leg_l": Vector3(0.45, 0, -0.22), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(-0.25, 0, 0.22), "shin_r": Vector3(-0.5, 0, 0)}
const STEP_L := {"leg_l": Vector3(1.0, 0, -0.16), "shin_l": Vector3(-1.05, 0, 0), "leg_r": Vector3(-0.65, 0, 0.18), "shin_r": Vector3(-0.25, 0, 0)}
const WIDE := {"leg_l": Vector3(0.5, 0, -0.32), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(0.35, 0, 0.32), "shin_r": Vector3(-0.75, 0, 0)}
const LOW := {"leg_l": Vector3(0.8, 0, -0.2), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.2, 0, 0.2), "shin_r": Vector3(-0.95, 0, 0)}


static func block() -> Dictionary:
	return DaggerMoves.aim(BLOCK_X, false)


static func _p(parts: Array) -> Dictionary:
	var out := {}
	for d in parts:
		out.merge(d, true)
	return out


## Strike keys: the pose at contact made faster (stretched along the motion, the heads smeared).
static func _whip(p: Dictionary, sc: Vector3, smear: float = 0.6) -> Dictionary:
	return p.merged({"_scale": sc, "_smear": Vector3(smear, 0, 0)}, true)


## The pose on the other side (Humanoid._mirror), its squash and smear kept as they are.
static func _mir(p: Dictionary) -> Dictionary:
	var out: Dictionary = Humanoid._mirror(p)
	for k in ["_scale", "_smear"]:
		if p.has(k):
			out[k] = p[k]
	return out


## The right-hand chop: hauled up behind the right shoulder (the head cocked back, the left axe held out on guard),
## then down across the front to the low left, the wrist flung through, stepping in on the left foot.
static func _wind_r() -> Dictionary:
	return _p([{"pivot": Vector3.ZERO, "hips": Vector3(0, -0.42, 0), "torso": Vector3(0.08, -0.75, 0.06), "head": Vector3(0.0, 0.6, 0),
		"arm_r": Vector3(2.45, 0.45, 1.15), "fore_r": Vector3(1.15, 0, 0), "hand_r": Vector3(0.95, 0, 0),
		"arm_l": Vector3(0.85, 0.3, -0.35), "fore_l": Vector3(1.2, 0, 0), "hand_l": Vector3(-0.6, 0, 0),
		"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(1.04, 0.95, 1.0), "_smear": Vector3.ZERO}, SET])


static func _chop_r() -> Dictionary:
	return _p([{"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.45, 0.62, -0.08), "head": Vector3(0.28, -0.5, 0),
		"arm_r": Vector3(0.75, -0.85, -0.85), "fore_r": Vector3(0.06, 0, 0), "hand_r": Vector3(-1.2, 0, 0),
		"arm_l": Vector3(0.7, 0.1, -0.4), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3(-0.65, 0, 0),
		"_lift": Vector3(0, -0.24, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}, STEP_L])


## [pose, mask, lift] for a twin-axe move.
static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	var g: Dictionary = h._guard()
	match n:
		# --- the combo: right, left, the hook, the whirl ---
		"dx_1":
			var wind := _wind_r()
			var cut := _chop_r()
			return [h._keys(u, [[0.0, g], [0.2, wind, "out"], [0.26, wind], [0.36, _whip(cut, Vector3(1.06, 0.95, 1.03)), "out"],
				[0.42, cut], [0.62, cut], [1.0, g]]), "full", lift]
		"dx_2":
			# the left axe, the same chop mirrored: up behind the left shoulder and down across to the low right
			var wind := _mir(_wind_r())
			var cut := _mir(_chop_r())
			return [h._keys(u, [[0.0, g], [0.2, wind, "out"], [0.26, wind], [0.36, _whip(cut, Vector3(1.06, 0.95, 1.03)), "out"],
				[0.42, cut], [0.62, cut], [1.0, g]]), "full", lift]
		"dx_3":
			# the hook: the left axe drawn across the chest, flung out round the far side of them, then yanked
			# back to the hip (the beard dragging them in) as the right axe goes up for the next chop
			var coil := _p([{"pivot": Vector3.ZERO, "hips": Vector3(0, -0.35, 0), "torso": Vector3(0.05, -0.55, 0.05), "head": Vector3(0.0, 0.45, 0),
				"arm_l": Vector3(1.2, -0.45, 0.45), "fore_l": Vector3(1.6, 0, 0), "hand_l": Vector3(-0.3, 0, 0),
				"arm_r": Vector3(0.6, -0.05, 0.4), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3(-0.4, 0, 0),
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(1.04, 0.95, 1.0), "_smear": Vector3.ZERO}, SET])
			var reach := _p([{"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.4, 0.45, -0.05), "head": Vector3(0.28, -0.4, 0),
				"arm_l": Vector3(1.6, 0.25, -0.45), "fore_l": Vector3(0.12, 0, 0), "blade_l": Vector3(0.55, -0.35, -0.75),
				"arm_r": Vector3(0.5, 0.0, 0.5), "fore_r": Vector3(1.5, 0, 0), "hand_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}, STEP_L])
			var yank := _p([{"pivot": Vector3(0.04, 0, 0), "hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.1, -0.5, 0.06), "head": Vector3(0.12, 0.4, 0),
				"arm_l": Vector3(0.1, 0.2, -0.55), "fore_l": Vector3(1.55, 0, 0), "blade_l": Vector3(0.35, 0.55, -0.75),
				"arm_r": Vector3(2.35, 0.4, 1.1), "fore_r": Vector3(1.15, 0, 0), "hand_r": Vector3(0.85, 0, 0),
				"_lift": Vector3(0, -0.16, 0), "_scale": Vector3(0.97, 1.04, 0.97), "_smear": Vector3.ZERO}, SET])
			return [h._keys(u, [[0.0, g], [0.18, coil, "out"], [0.24, coil], [0.34, DaggerMoves.aim(_whip(reach, Vector3(0.97, 1.0, 1.08)), false), "out"],
				[0.42, DaggerMoves.aim(reach, false)], [0.56, DaggerMoves.aim(yank, false), "out"], [0.74, DaggerMoves.aim(yank, false)], [1.0, g]]), "full", lift]
		"dx_4":
			# Reaping Whirl: coiled left, both axes flung out level at arm's length and the body whirled round
			# twice behind them, stretched out along the turn
			var coil := _p([{"pivot": Vector3.ZERO, "hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.22, 0.7, 0.05), "head": Vector3(0.15, -0.5, 0),
				"arm_r": Vector3(0.9, 0.6, 1.2), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(1.0, 0.5, -0.6), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3(0.5, 0, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.05, 0.93, 1.02), "_smear": Vector3.ZERO}, LOW])
			var out := _p([{"pivot": Vector3(-0.08, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.25, 0, 0.1), "head": Vector3(0.15, 0, 0),
				"arm_r": Vector3(1.4, 0.0, 1.45), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.45, 0, 0),
				"arm_l": Vector3(1.4, 0.0, -1.45), "fore_l": Vector3(0.05, 0, 0), "hand_l": Vector3(-1.45, 0, 0),
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(1.04, 0.97, 1.03), "_smear": Vector3(0.5, 0, 0)}, WIDE])
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.12, coil, "out"], [0.18, coil], [0.26, out, "out"], [0.76, out.merged({"_smear": Vector3.ZERO}, true)], [1.0, g]])
			var k := clampf((u - 0.18) / 0.6, 0.0, 1.0)
			pz["pivot"] = (pz["pivot"] as Vector3) + Vector3(0, -2.0 * TAU * (1.0 - pow(1.0 - k, 1.6)), 0)
			return [pz, "full", lift]
		# --- the heavy (Berserker Frenzy): right, left, right, then both up and crashed down crossed ---
		"dx_heavy":
			var wr := _wind_r()
			var cr := _chop_r()
			var wl := _mir(wr)
			var cl := _mir(cr)
			var up := _p([{"pivot": Vector3(0.08, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.38, 0, 0), "head": Vector3(-0.22, 0, 0),
				"arm_r": Vector3(2.95, 0.25, 0.5), "fore_r": Vector3(0.8, 0, 0), "hand_r": Vector3(0.8, 0, 0),
				"arm_l": Vector3(2.95, -0.25, -0.5), "fore_l": Vector3(0.8, 0, 0), "hand_l": Vector3(0.8, 0, 0),
				"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.96, 1.07, 1.0), "_smear": Vector3.ZERO}, SET])
			var cross := _p([{"pivot": Vector3(-0.15, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.62, 0, 0), "head": Vector3(0.38, 0, 0),
				"arm_r": Vector3(1.1, -0.8, -0.55), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"arm_l": Vector3(1.1, 0.8, 0.55), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(-1.3, 0, 0),
				"_lift": Vector3(0, -0.36, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}, STEP_L])
			var sq := Vector3(1.06, 0.95, 1.03)
			return [h._keys(u, [[0.0, g], [0.13, wr, "out"], [0.16, wr], [0.2, _whip(cr, sq), "out"], [0.24, cr],
				[0.3, wl, "out"], [0.32, wl], [0.36, _whip(cl, sq), "out"], [0.4, cl],
				[0.46, wr, "out"], [0.48, wr], [0.52, _whip(cr, sq), "out"], [0.56, cr],
				[0.66, up, "out"], [0.69, up], [0.74, _whip(cross, Vector3(1.08, 0.9, 1.04), 0.7), "in"], [0.8, cross], [0.9, cross], [1.0, g]]), "full", lift]
		# (previews: the stance itself and the held block)
		"dx_stance":
			return [{}, "upper", lift]
		"dx_block":
			return h._action_pose("guard_block", u)
	push_error("DualAxeMoves: no pose for \"%s\"" % n)
	return [g, "full", lift]
