class_name TechniquePoses
## Key poses for the weapon and unarmed techniques (TechniqueState), deflecting
## shots and Conqueror's Haki. Humanoid._action_pose falls through to pose() for
## names it doesn't know; the helpers it uses (_keys, _guard, _action, _t) are
## the Humanoid's own. Same conventions as humanoid.gd (see the
## driftwake-animation skill). Moves keyed in seconds read the played length
## from _action["dur"].


## [pose, mask, lift] for a technique action, or [] if `n` isn't one.
static func pose(h, n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	var g: Dictionary = h._guard()
	var T: float = float(h._action.get("dur", 1.0))
	var s := u * T
	match n:
		# --- any blade ---
		"deflect":
			# a snap of the blade across the front, the shot glancing off
			var flick := {"arm_r": Vector3(1.5, -0.6, -0.6), "fore_r": Vector3(0.3, 0, 0), "hand_r": Vector3(-0.4, 0, 0),
				"torso": Vector3(-0.1, -0.5, 0), "head": Vector3(0.06, 0.4, 0)}
			return [h._keys(u, [[0.0, {}], [0.25, flick, "out"], [0.6, flick], [1.0, {}]]), "upper", lift]
		# --- cutlass ---
		"riposte_guard":
			# side on, blade upright in front of the face, weight back, waiting
			var gd := {"hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.08, 0.3, 0.02 * sin(h._t * 6.0)), "head": Vector3(0.05, -0.3, 0),
				"arm_r": Vector3(1.3, -0.4, -0.1), "fore_r": Vector3(1.1, 0, 0), "hand_r": Vector3(-0.1, 0, 0),
				"arm_l": Vector3(0.6, 0.3, -0.5), "fore_l": Vector3(1.3, 0, 0),
				"leg_l": Vector3(0.35, 0, -0.15), "shin_l": Vector3(-0.55, 0, 0), "leg_r": Vector3(-0.3, 0, 0.15), "shin_r": Vector3(-0.45, 0, 0),
				"_lift": Vector3(0, -0.12, 0)}
			return [h._keys(u, [[0.0, {}], [0.15, gd, "out"], [0.85, gd], [1.0, g]]), "full", lift]
		"riposte_cut":
			# the blow turned aside to the left, then a flat backhand answer to the right
			var turn := {"hips": Vector3(0, -0.3, 0), "arm_r": Vector3(1.3, -0.75, -1.05), "fore_r": Vector3(1.6, 0, 0), "hand_r": Vector3(0.5, 0, 0),
				"torso": Vector3(0.0, -1.0, -0.1), "head": Vector3(0, 0.8, 0), "arm_l": Vector3(0.5, 0, -0.4), "fore_l": Vector3(1.4, 0, 0),
				"leg_l": Vector3(0.3, 0, -0.15), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.3, 0, 0.15), "shin_r": Vector3(-0.5, 0, 0),
				"_lift": Vector3(0, -0.1, 0)}
			var answer := {"hips": Vector3(0, 0.3, 0), "arm_r": Vector3(1.35, 0.0, 1.5), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.45, 0, 0),
				"torso": Vector3(-0.3, 1.05, 0.1), "head": Vector3(0.1, -0.8, 0), "arm_l": Vector3(0.6, 0, -0.9), "fore_l": Vector3(0.9, 0, 0),
				"leg_l": Vector3(-0.55, 0, -0.1), "shin_l": Vector3(-0.35, 0, 0), "leg_r": Vector3(0.9, 0, 0.1), "shin_r": Vector3(-0.85, 0, 0),
				"_lift": Vector3(0, -0.2, 0)}
			# the whip of the answer: stretched along the cut, the blade smeared
			var whip := answer.merged({"_scale": Vector3(1.07, 0.97, 1.0), "_smear": Vector3(0.7, 0, 0)}, true)
			var turn_sq := turn.merged({"_scale": Vector3(1.03, 0.95, 1.02)}, true)
			return [h._keys(u, [[0.0, g], [0.12, turn_sq, "out"], [0.18, turn_sq], [0.3, whip, "out"], [0.38, answer], [0.62, answer], [1.0, g]]), "full", lift]
		"swordfish":
			# a fencer's lunge held while the blade drives out five times (peaks at
			# 0.12 s + 0.12 s each), the body driving behind every thrust; the fifth
			# goes deepest
			var ext := 0.0
			if s > 0.06 and s < 0.7:
				var x := (s - 0.12) / 0.12
				ext = clampf(1.0 - absf(x - roundf(x)) * 2.2, 0.0, 1.0)
			var last := clampf((s - 0.5) / 0.08, 0.0, 1.0) * (1.0 - clampf((s - 0.66) / 0.08, 0.0, 1.0))
			var coil := {"arm_r": Vector3(0.4, 0.3, 0.4), "fore_r": Vector3(1.7, 0, 0), "hand_r": Vector3(-1.6, 0, 0),
				"hips": Vector3(0, 0.05, 0), "torso": Vector3(-0.25, 0.3, 0), "head": Vector3(0.18, -0.25, 0),
				"_scale": Vector3(1.02, 0.97, 0.97)}
			var drive := {"arm_r": Vector3(1.65, 0.1, 0.05), "fore_r": Vector3(0.0, 0, 0), "hand_r": Vector3(-1.55, 0, 0),
				"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.45, -0.05, 0), "head": Vector3(0.3, 0.02, 0),
				"_scale": Vector3(0.97, 1.0, 1.06)}
			var body := {"arm_l": Vector3(-0.5, 0, -0.7), "fore_l": Vector3(0.4, 0, 0),
				"leg_r": Vector3(1.0, 0, 0.06), "shin_r": Vector3(-1.1, 0, 0), "leg_l": Vector3(-0.8, 0, -0.08), "shin_l": Vector3(-0.15, 0, 0),
				"_lift": Vector3(0, -0.25 - 0.12 * last, 0)}
			for j in coil.keys():
				body[j] = (coil[j] as Vector3).lerp(drive[j], ext)
			body["torso"] = (body["torso"] as Vector3) + Vector3(-0.15, 0, 0) * last
			body["leg_r"] = (body["leg_r"] as Vector3) + Vector3(0.25, 0, 0) * last
			body["shin_r"] = (body["shin_r"] as Vector3) + Vector3(-0.3, 0, 0) * last
			body["_scale"] = (body["_scale"] as Vector3) + Vector3(-0.02, 0, 0.06) * last * ext
			body["_smear"] = Vector3(0.6 * ext * last, 0, 0)
			return [h._keys(u, [[0.0, g], [0.07 / T, body, "out"], [0.72 / T, body], [1.0, g]]), "full", lift]
		"kraken_cut":
			# coiled low gathering the sea (blade drawn back by the hip, the off hand
			# out), driving low between the victims, then a flick of the blade and
			# upright, back to them, as they're all torn open
			var k_go := 0.45 / T
			var gather := {"hips": Vector3(0, -0.5, 0), "torso": Vector3(-0.45, -0.75, -0.05), "head": Vector3(0.3, 0.65, 0),
				"arm_r": Vector3(-0.35, 0.3, 0.45), "fore_r": Vector3(0.7, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(1.35, 0.5, -0.2), "fore_l": Vector3(0.35, 0, 0),
				"leg_l": Vector3(1.0, 0, -0.2), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(-0.7, 0, 0.2), "shin_r": Vector3(-0.6, 0, 0),
				"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.05, 0.93, 1.03)}
			var low := {"hips": Vector3(0, -0.2, 0), "arm_r": Vector3(1.35, -0.9, -1.15), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.45, 0, 0),
				"arm_l": Vector3(-0.5, 0, -0.8), "fore_l": Vector3(0.3, 0, 0), "torso": Vector3(-0.5, -0.9, -0.08), "head": Vector3(0.35, 0.7, 0),
				"leg_l": Vector3(1.3, 0, -0.12), "shin_l": Vector3(-1.45, 0, 0), "leg_r": Vector3(-1.0, 0, 0.12), "shin_r": Vector3(-0.15, 0, 0),
				"_lift": Vector3(0, -0.35, 0), "_scale": Vector3(0.98, 0.98, 1.06)}
			var flick := {"hips": Vector3(0, -0.1, 0), "arm_r": Vector3(1.1, -0.2, 0.3), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(0.7, 0, 0),
				"torso": Vector3(-0.15, -0.6, 0), "head": Vector3(0.05, 0.5, 0), "arm_l": Vector3(0.3, 0, -0.4), "fore_l": Vector3(0.5, 0, 0),
				"leg_l": Vector3(0.3, 0, -0.15), "shin_l": Vector3(-0.4, 0, 0), "leg_r": Vector3(-0.2, 0, 0.15), "shin_r": Vector3(-0.35, 0, 0),
				"_lift": Vector3(0, -0.1, 0)}
			var flourish := {"hips": Vector3(0, 0.2, 0), "arm_r": Vector3(0.9, 0.3, 1.2), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.4, 0, 0),
				"torso": Vector3(-0.05, -0.4, 0), "head": Vector3(0.0, 0.35, 0), "arm_l": Vector3(0.2, 0, -0.35), "fore_l": Vector3(0.3, 0, 0),
				"leg_l": Vector3(0.15, 0, -0.15), "shin_l": Vector3(-0.2, 0, 0), "leg_r": Vector3(-0.1, 0, 0.15), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.03, 0), "_scale": Vector3(1.0, 1.03, 1.0)}
			var k_still := maxf((T - 0.75) / T, k_go + 0.05)
			var k_tear := maxf((T - 0.55) / T, k_still + 0.05)
			return [h._keys(u, [[0.0, g], [0.1, gather, "out"], [k_go - 0.02, gather], [k_go + 0.03, low, "out"], [k_still - 0.06, low],
				[k_still, flick, "out"], [k_tear - 0.02, flick], [k_tear + 0.05, flourish, "out"], [1.0 - 0.12 / T, flourish], [1.0, g]]), "full", lift]
		"flying_slash":
			# wound right with the blade drawn far back, a beat, then one huge flat
			# cut right to left that flings the crescent off the edge (u 0.42),
			# stepping through onto the left foot
			var wind := {"hips": Vector3(0, -0.55, 0), "torso": Vector3(-0.1, -1.1, -0.06), "head": Vector3(0.1, 0.85, 0),
				"arm_r": Vector3(0.75, 0.6, 1.35), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(0.85, 0, 0),
				"arm_l": Vector3(1.25, -0.2, -0.3), "fore_l": Vector3(0.7, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.2), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(-0.3, 0, 0.2), "shin_r": Vector3(-0.75, 0, 0),
				"_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.04, 0.94, 1.0)}
			var cut := {"hips": Vector3(0, 0.5, 0), "torso": Vector3(-0.3, 1.0, 0.08), "head": Vector3(0.18, -0.7, 0),
				"arm_r": Vector3(1.5, -0.95, -1.1), "fore_r": Vector3(0.08, 0, 0), "hand_r": Vector3(-1.4, 0, 0),
				"arm_l": Vector3(0.3, 0.2, -1.3), "fore_l": Vector3(0.45, 0, 0),
				"leg_l": Vector3(1.05, 0, -0.15), "shin_l": Vector3(-1.05, 0, 0), "leg_r": Vector3(-0.8, 0, 0.1), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.26, 0)}
			var whip := cut.merged({"_scale": Vector3(1.08, 0.97, 1.0), "_smear": Vector3(0.8, 0, 0)}, true)
			return [h._keys(u, [[0.0, g], [0.3, wind, "out"], [0.37, wind], [0.46, whip, "out"], [0.52, cut], [0.74, cut], [1.0, g]]), "full", lift]
		# --- katana ---
		"wind_sever":
			# blade low behind the right foot, chest wound round, then a rising cut
			# up across the body to overhead as the wave leaves (u 0.4)
			var low := {"hips": Vector3(0, 0.25, 0), "arm_r": Vector3(-0.2, 0.3, 0.5), "fore_r": Vector3(0.4, 0, 0), "hand_r": Vector3(0.3, 0, 0),
				"torso": Vector3(-0.4, 0.8, 0.1), "head": Vector3(0.3, -0.6, 0),
				"leg_l": Vector3(0.5, 0, -0.14), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.4, 0, 0.14), "shin_r": Vector3(-0.8, 0, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.04, 0.94, 1.0)}
			var rise := {"hips": Vector3(0, -0.2, 0), "arm_r": Vector3(2.7, -0.3, -0.4), "fore_r": Vector3(0.3, 0, 0), "hand_r": Vector3(-0.6, 0, 0),
				"torso": Vector3(0.15, -0.6, -0.1), "head": Vector3(-0.1, 0.4, 0),
				"leg_l": Vector3(1.0, 0, -0.14), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.8, 0, 0.14), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.06, 0)}
			# (stretched up along the cut, the blade smeared, on the one fast key)
			var whip := rise.merged({"_scale": Vector3(0.97, 1.07, 1.0), "_smear": Vector3(0.7, 0, 0)}, true)
			return [h._keys(u, [[0.0, g], [0.28, low, "out"], [0.36, low], [0.46, whip, "out"], [0.52, rise], [0.72, rise], [1.0, g]]), "full", lift]
		"phantom_cut":
			# arriving crouched behind them, then one flat cut round to the right
			var arrive := {"hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.4, -0.6, 0), "head": Vector3(0.3, 0.5, 0),
				"arm_r": Vector3(0.5, 1.0, -0.3), "fore_r": Vector3(1.3, 0, 0), "hand_r": Vector3.ZERO,
				"arm_l": Vector3(0.4, -0.2, -0.3), "fore_l": Vector3(1.0, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.25, 0, 0), "leg_r": Vector3(-0.2, 0, 0.15), "shin_r": Vector3(-1.2, 0, 0),
				"_lift": Vector3(0, -0.32, 0)}
			var cut := {"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.35, 0.9, 0.1), "head": Vector3(0.25, -0.7, 0),
				"arm_r": Vector3(1.4, -0.5, 1.2), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.25, 0, 0),
				"arm_l": Vector3(-0.4, 0, -0.8), "fore_l": Vector3(0.3, 0, 0),
				"leg_l": Vector3(1.1, 0, -0.14), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.85, 0, 0.16), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.26, 0)}
			var whip := cut.merged({"_scale": Vector3(1.07, 0.97, 1.0), "_smear": Vector3(0.7, 0, 0)}, true)
			var low := arrive.merged({"_scale": Vector3(1.04, 0.94, 1.02)}, true)
			return [h._keys(u, [[0.0, low], [0.12, low], [0.27, whip, "out"], [0.33, cut], [0.65, cut], [1.0, g]]), "full", lift]
		"petal_storm":
			# the blade slipped home, crouched low with the hand on the hilt while it
			# gathers, one wide drawing cut round to the right (0.46 s), held, then
			# slowly straightening as the blade slides home (sheathed with a click at
			# 1.4 s), head bowed, hand resting on the hilt as everything round you falls
			var ev: Dictionary = h._action["events"]
			if s >= 0.06 and h.weapon_in_hand and not ev.has("saya"):
				ev["saya"] = true
				h._attach_weapon(false)
			if s >= 0.44 and not ev.has("draw"):
				ev["draw"] = true
				h._attach_weapon(true)
			if s >= 1.38 and h.weapon_in_hand and not ev.has("home"):
				ev["home"] = true
				h._attach_weapon(false)
			var crouch: Dictionary = h._iai_pose().merged({"hips": Vector3(0, -0.35, 0),
				"leg_l": Vector3(0.95, 0, -0.16), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(-0.45, 0, 0.18), "shin_r": Vector3(-1.05, 0, 0),
				"_lift": Vector3(0, -0.36, 0), "_scale": Vector3(1.04, 0.94, 1.02)}, true)
			var flick := {"hips": Vector3(0, 0.3, 0), "arm_r": Vector3(1.45, -0.55, 1.3), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
				"torso": Vector3(-0.3, 0.9, 0.1), "head": Vector3(0.25, -0.7, 0), "arm_l": Vector3(-0.5, 0, -0.9), "fore_l": Vector3(0.35, 0, 0),
				"leg_l": Vector3(1.2, 0, -0.14), "shin_l": Vector3(-1.45, 0, 0), "leg_r": Vector3(-0.95, 0, 0.16), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.32, 0)}
			var whip := flick.merged({"_scale": Vector3(1.08, 0.97, 1.0), "_smear": Vector3(0.8, 0, 0)}, true)
			var home := {"hips": Vector3(0, -0.15, 0), "arm_r": Vector3(0.7, 0.9, -0.45), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3.ZERO,
				"arm_l": Vector3(0.25, -0.2, -0.15), "fore_l": Vector3(1.0, 0, 0),
				"torso": Vector3(-0.12, -0.25, 0.02), "head": Vector3(-0.35, 0.15, 0),
				"leg_l": Vector3(0.35, 0, -0.14), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.3, 0, 0.14), "shin_r": Vector3(-0.4, 0, 0),
				"_lift": Vector3(0, -0.1, 0)}
			return [h._keys(u, [[0.0, g], [0.12 / T, crouch, "out"], [0.42 / T, crouch], [0.48 / T, whip, "out"], [0.56 / T, flick], [0.75 / T, flick],
				[1.38 / T, home, "in"], [1.0 - 0.15 / T, home], [1.0, g]]), "full", lift]
		# --- axe ---
		"axe_throw":
			# the axe drawn back over the shoulder, the off hand pointing, then hurled
			# overhand (it leaves at u 0.4)
			var wind := {"hips": Vector3(0, 0.3, 0), "arm_r": Vector3(2.6, 0.3, 0.6), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"torso": Vector3(0.15, 0.8, 0.05), "head": Vector3(0, -0.6, 0), "arm_l": Vector3(1.3, 0, -0.4), "fore_l": Vector3(0.4, 0, 0),
				"leg_l": Vector3(0.5, 0, -0.14), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.4, 0, 0.14), "shin_r": Vector3(-0.45, 0, 0),
				"_lift": Vector3(0, -0.06, 0)}
			var hurl := {"hips": Vector3(0, -0.3, 0), "arm_r": Vector3(1.2, -0.4, -0.3), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.0, 0, 0),
				"torso": Vector3(-0.35, -0.6, -0.05), "head": Vector3(0.25, 0.5, 0), "arm_l": Vector3(-0.3, 0, -0.6), "fore_l": Vector3(0.6, 0, 0),
				"leg_l": Vector3(0.95, 0, -0.14), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(-0.7, 0, 0.14), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.16, 0)}
			return [h._keys(u, [[0.0, g], [0.3, wind, "out"], [0.34, wind], [0.42, hurl, "out"], [0.68, hurl], [1.0, g]]), "full", lift]
		"earthsplitter":
			# spring up with the axe raised two-handed, knees tucked, then crash it down
			# into the ground through a deep lunge (lands ~u 0.47)
			var raise := {"hips": Vector3.ZERO, "arm_r": Vector3(3.0, 0, 0.2), "fore_r": Vector3(1.2, 0, 0), "hand_r": Vector3(0.4, 0, 0),
				"arm_l": Vector3(2.9, 0, -0.2), "fore_l": Vector3(1.3, 0, 0), "torso": Vector3(0.35, 0, 0), "head": Vector3(0.0, 0, 0),
				"leg_l": Vector3(1.2, 0, -0.14), "shin_l": Vector3(-1.8, 0, 0), "leg_r": Vector3(0.6, 0, 0.14), "shin_r": Vector3(-1.2, 0, 0),
				"_lift": Vector3(0, 0.12, 0)}
			var slam := {"hips": Vector3.ZERO, "arm_r": Vector3(0.4, 0, 0.05), "fore_r": Vector3(0.0, 0, 0), "hand_r": Vector3(-1.2, 0, 0),
				"arm_l": Vector3(0.5, 0, -0.05), "fore_l": Vector3(0.1, 0, 0), "torso": Vector3(-0.9, 0, 0), "head": Vector3(0.5, 0, 0),
				"leg_l": Vector3(1.1, 0, -0.12), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.9, 0, 0.12), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.42, 0)}
			return [h._keys(u, [[0.0, g], [0.25, raise, "out"], [0.38, raise], [0.47, slam, "in"], [0.75, slam], [1.0, g]]), "full", lift]
		"berserk_roar":
			# arms flung out and down, chest up, the whole body shaking with the roar
			var shake := sin(h._t * 41.0) * 0.03
			var roar := {"hips": Vector3.ZERO, "arm_r": Vector3(0.6, 0, 1.3), "fore_r": Vector3(1.6, 0, 0), "hand_r": Vector3(0.5, 0, 0),
				"arm_l": Vector3(0.6, 0, -1.3), "fore_l": Vector3(1.6, 0, 0),
				"torso": Vector3(0.35, 0, shake), "head": Vector3(0.55, 0, -shake),
				"leg_l": Vector3(0.2, 0, -0.3), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(0.2, 0, 0.3), "shin_r": Vector3(-0.6, 0, 0),
				"_lift": Vector3(0, -0.16, 0)}
			return [h._keys(u, [[0.0, g], [0.3, roar, "out"], [0.85, roar], [1.0, g]]), "full", lift]
		"maelstrom":
			# the axe drawn back two-handed over the right shoulder, wound round and
			# sunk while the power gathers (0.38 s), then out at arm's length,
			# spinning seven times
			var wind := {"hips": Vector3(0, 0.5, 0), "arm_r": Vector3(2.4, 0.4, 0.7), "fore_r": Vector3(1.2, 0, 0), "hand_r": Vector3(0.5, 0, 0),
				"arm_l": Vector3(2.0, 0.2, 0.3), "fore_l": Vector3(1.4, 0, 0),
				"torso": Vector3(-0.15, 0.9, 0.08), "head": Vector3(0.15, -0.7, 0),
				"leg_l": Vector3(0.55, 0, -0.3), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.1, 0, 0.3), "shin_r": Vector3(-0.95, 0, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.93, 1.02)}
			var out := {"hips": Vector3.ZERO, "arm_r": Vector3(1.4, 0, 1.3), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.5, 0, 0),
				"arm_l": Vector3(1.3, 0.7, 0.4), "fore_l": Vector3(0.5, 0, 0),
				"torso": Vector3(-0.2, 0, 0.12), "head": Vector3(0.12, 0, 0),
				"leg_l": Vector3(0.4, 0, -0.3), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.1, 0, 0.3), "shin_r": Vector3(-0.7, 0, 0),
				"_lift": Vector3(0, -0.18, 0)}
			var p: Dictionary = h._keys(u, [[0.0, g], [0.12 / T, wind, "out"], [0.36 / T, wind], [0.44 / T, out, "out"], [0.95, out], [1.0, g]])
			p["pivot"] = Vector3(0, -TAU * 7.0 * _ease_io(clampf((s - 0.38) / 2.4, 0.0, 1.0)), 0)
			return [p, "full", lift]
		# --- dual swords ---
		"cross_guard":
			# both blades raised and crossed in an X in front of the face, elbows out,
			# weight sunk, waiting
			var gd := {"hips": Vector3.ZERO, "arm_r": Vector3(1.3, 0.55, -0.1), "fore_r": Vector3(1.2, 0, 0), "hand_r": Vector3(-0.1, 0, 0),
				"arm_l": Vector3(1.3, -0.55, 0.1), "fore_l": Vector3(1.2, 0, 0), "hand_l": Vector3(-0.1, 0, 0),
				"torso": Vector3(-0.1, 0.0, 0.02 * sin(h._t * 6.0)), "head": Vector3(0.08, 0, 0),
				"leg_l": Vector3(0.35, 0, -0.18), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.25, 0, 0.18), "shin_r": Vector3(-0.5, 0, 0),
				"_lift": Vector3(0, -0.14, 0)}
			return [h._keys(u, [[0.0, {}], [0.15, gd, "out"], [0.85, gd], [1.0, g]]), "full", lift]
		"blade_dance":
			# both blades out level, three turns while dancing forward, bobbing
			var out := {"hips": Vector3.ZERO, "arm_r": Vector3(1.4, 0.0, 1.5), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(1.4, 0.0, -1.5), "fore_l": Vector3(0.05, 0, 0),
				"hand_r": Vector3(-1.5, 0, 0), "hand_l": Vector3(-1.5, 0, 0), "torso": Vector3(-0.2, 0, 0), "head": Vector3(0.12, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.2), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.3, 0, 0.2), "shin_r": Vector3(-0.6, 0, 0),
				"_lift": Vector3(0, -0.08 + 0.1 * absf(sin(s * 9.0)), 0)}
			var p: Dictionary = h._keys(u, [[0.0, g], [0.08, out, "out"], [0.88, out], [1.0, g]])
			p["pivot"] = Vector3(0, -TAU * 3.0 * clampf((s - 0.08) / 0.8, 0.0, 1.0), 0)
			return [p, "full", lift]
		"cross_fang":
			# blades thrown up and apart with the knees tucked in the leap, then
			# crashing down crossed as you land in a lunge
			var up := {"hips": Vector3.ZERO, "arm_r": Vector3(2.5, 0.3, 0.9), "fore_r": Vector3(0.4, 0, 0), "arm_l": Vector3(2.5, -0.3, -0.9), "fore_l": Vector3(0.4, 0, 0),
				"hand_r": Vector3(0.6, 0, 0), "hand_l": Vector3(0.6, 0, 0), "torso": Vector3(0.3, 0, 0), "head": Vector3(0.0, 0, 0),
				"leg_l": Vector3(1.3, 0, -0.12), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(0.8, 0, 0.12), "shin_r": Vector3(-1.5, 0, 0),
				"_lift": Vector3(0, 0.1, 0)}
			var down := {"hips": Vector3.ZERO, "arm_r": Vector3(1.2, -0.9, -0.6), "fore_r": Vector3(0.1, 0, 0), "arm_l": Vector3(1.2, 0.9, 0.6), "fore_l": Vector3(0.1, 0, 0),
				"hand_r": Vector3(-1.3, 0, 0), "hand_l": Vector3(-1.3, 0, 0), "torso": Vector3(-0.55, 0, 0), "head": Vector3(0.35, 0, 0),
				"leg_l": Vector3(1.1, 0, -0.12), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.8, 0, 0.12), "shin_r": Vector3(-0.25, 0, 0),
				"_lift": Vector3(0, -0.36, 0)}
			return [h._keys(u, [[0.0, g], [0.15, up, "out"], [0.36, up], [0.46, down, "in"], [0.75, down], [1.0, g]]), "full", lift]
		"steel_tempest":
			# eight fast turns with both blades out, then both crossed and flung out
			var out := {"hips": Vector3.ZERO, "arm_r": Vector3(1.4, 0.0, 1.5), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(1.4, 0.0, -1.5), "fore_l": Vector3(0.05, 0, 0),
				"hand_r": Vector3(-1.5, 0, 0), "hand_l": Vector3(-1.5, 0, 0), "torso": Vector3(-0.15, 0, 0), "head": Vector3(0.1, 0, 0),
				"leg_l": Vector3(0.5, 0, -0.25), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.5, 0, 0.25), "shin_r": Vector3(-0.8, 0, 0),
				"_lift": Vector3(0, -0.12, 0)}
			var burst := {"hips": Vector3.ZERO, "arm_r": Vector3(1.5, 0.3, 1.2), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(1.5, -0.3, -1.2), "fore_l": Vector3(0.05, 0, 0),
				"hand_r": Vector3(-1.4, 0, 0), "hand_l": Vector3(-1.4, 0, 0), "torso": Vector3(-0.4, 0, 0), "head": Vector3(0.3, 0, 0),
				"leg_l": Vector3(1.0, 0, -0.15), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(-0.7, 0, 0.15), "shin_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.3, 0)}
			var k_burst := 1.9 / T
			var p: Dictionary = h._keys(u, [[0.0, g], [0.06, out, "out"], [k_burst - 0.03, out], [k_burst, burst, "out"], [0.95, burst], [1.0, g]])
			p["pivot"] = Vector3(0, -TAU * 8.0 * _ease_io(clampf((s - 0.1) / 1.8, 0.0, 1.0)), 0)
			return [p, "full", lift]
		# --- pistols (the arm aims; the wrist stays in its grip) ---
		"deadeye":
			# arm out straight, the off hand braced under it, head tilted down the sights,
			# held still; the shot (u 0.55) kicks the arm up
			var aim := {"hips": Vector3(0, 0.25, 0), "arm_r": Vector3(1.6, -0.1, 0.0), "fore_r": Vector3(0.02, 0, 0),
				"arm_l": Vector3(1.35, -0.55, 0.1), "fore_l": Vector3(0.9, 0, 0),
				"torso": Vector3(-0.05, 0.2, 0), "head": Vector3(0.05, -0.25, 0.08),
				"leg_l": Vector3(0.35, 0, -0.15), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(-0.3, 0, 0.15), "shin_r": Vector3(-0.25, 0, 0),
				"_lift": Vector3(0, -0.06, 0)}
			var kick := aim.merged({"arm_r": Vector3(2.1, -0.1, 0.0), "fore_r": Vector3(0.35, 0, 0), "torso": Vector3(0.08, 0.25, 0)}, true)
			return [h._keys(u, [[0.0, g], [0.25, aim, "out"], [0.53, aim], [0.58, kick, "out"], [0.75, aim], [1.0, g]]), "full", lift]
		"smoke_throw":
			# the bomb flicked down at your feet from shoulder height
			var lift_arm := {"hips": Vector3.ZERO, "arm_l": Vector3(2.0, 0, -0.4), "fore_l": Vector3(1.2, 0, 0), "torso": Vector3(0.05, -0.2, 0), "head": Vector3(0.0, 0.1, 0),
				"leg_l": Vector3(0.2, 0, -0.15), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(-0.2, 0, 0.15), "shin_r": Vector3(-0.3, 0, 0)}
			var toss := {"hips": Vector3.ZERO, "arm_l": Vector3(0.6, 0, -0.3), "fore_l": Vector3(0.2, 0, 0), "torso": Vector3(-0.3, 0.1, 0), "head": Vector3(-0.1, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.15), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.1, 0, 0.15), "shin_r": Vector3(-0.8, 0, 0),
				"_lift": Vector3(0, -0.2, 0)}
			return [h._keys(u, [[0.0, g], [0.22, lift_arm, "out"], [0.36, toss, "out"], [0.6, toss], [1.0, g]]), "full", lift]
		"point_blank":
			# a lunge in with the barrel jammed into them low, the shot (u 0.33) bucking it up
			var jam := {"hips": Vector3(0, 0.35, 0), "arm_r": Vector3(1.15, -0.2, 0.1), "fore_r": Vector3(0.45, 0, 0),
				"arm_l": Vector3(0.6, 0.35, -0.5), "fore_l": Vector3(1.4, 0, 0),
				"torso": Vector3(-0.4, 0.4, 0), "head": Vector3(0.3, -0.3, 0),
				"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.7, 0, 0.12), "shin_r": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, -0.26, 0)}
			var buck := jam.merged({"arm_r": Vector3(1.55, -0.2, 0.1), "fore_r": Vector3(0.7, 0, 0), "torso": Vector3(-0.25, 0.45, 0)}, true)
			return [h._keys(u, [[0.0, g], [0.22, jam, "out"], [0.31, jam], [0.38, buck, "out"], [0.7, jam], [1.0, g]]), "full", lift]
		"deaths_waltz":
			# both arms out to the sides, guns level, two slow elegant turns
			var arms := {"hips": Vector3.ZERO, "arm_r": Vector3(1.5, 0, 0.7), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(1.5, 0, -0.7), "fore_l": Vector3(0.05, 0, 0),
				"torso": Vector3(-0.05, 0, 0), "head": Vector3(0.05, 0, 0),
				"leg_l": Vector3(0.3, 0, -0.1), "shin_l": Vector3(-0.35, 0, 0), "leg_r": Vector3(-0.2, 0, 0.1), "shin_r": Vector3(-0.35, 0, 0),
				"_lift": Vector3(0, -0.05 + 0.04 * sin(s * 7.0), 0)}
			var p: Dictionary = h._keys(u, [[0.0, g], [0.08, arms, "out"], [0.92, arms], [1.0, g]])
			p["pivot"] = Vector3(0, -TAU * 2.0 * _ease_io(clampf((s - 0.15) / 1.7, 0.0, 1.0)), 0)
			return [p, "full", lift]
		# --- unarmed: grapples ---
		"suplex":
			# arms locked round their waist in a crouch, then the back arched into a
			# bridge carrying them overhead (slam at u 0.6), and up again
			var grab := {"hips": Vector3.ZERO, "pivot": Vector3.ZERO, "arm_r": Vector3(1.3, 0.5, -0.1), "fore_r": Vector3(1.3, 0, 0), "arm_l": Vector3(1.3, -0.5, 0.1), "fore_l": Vector3(1.3, 0, 0),
				"torso": Vector3(-0.35, 0, 0), "head": Vector3(0.3, 0, 0),
				"leg_l": Vector3(0.5, 0, -0.15), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(0.3, 0, 0.15), "shin_r": Vector3(-0.9, 0, 0),
				"_lift": Vector3(0, -0.26, 0)}
			var arch := {"hips": Vector3.ZERO, "pivot": Vector3(1.05, 0, 0), "arm_r": Vector3(2.8, 0.3, 0.1), "fore_r": Vector3(0.8, 0, 0), "arm_l": Vector3(2.8, -0.3, -0.1), "fore_l": Vector3(0.8, 0, 0),
				"torso": Vector3(0.55, 0, 0), "head": Vector3(0.6, 0, 0),
				"leg_l": Vector3(-0.55, 0, -0.15), "shin_l": Vector3(-1.6, 0, 0), "leg_r": Vector3(-0.55, 0, 0.15), "shin_r": Vector3(-1.6, 0, 0),
				"_lift": Vector3(0, -0.4, 0)}
			return [h._keys(u, [[0.0, g], [0.2, grab, "out"], [0.27, grab], [0.6, arch, "in"], [0.72, arch], [0.88, grab], [1.0, g]]), "full", lift]
		"shoulder_throw":
			# reach in and grab, turn your back into them bending low with their arm over
			# your shoulder, then heave them over in front (the throw at u 0.53)
			var grab := {"hips": Vector3(0, 0.3, 0), "torso": Vector3(-0.3, 0.6, 0), "head": Vector3(0.2, -0.4, 0),
				"arm_r": Vector3(1.6, 0.3, 0.1), "fore_r": Vector3(0.6, 0, 0), "arm_l": Vector3(1.4, -0.2, -0.1), "fore_l": Vector3(0.8, 0, 0),
				"leg_l": Vector3(0.5, 0, -0.15), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.1, 0, 0.15), "shin_r": Vector3(-0.7, 0, 0),
				"_lift": Vector3(0, -0.18, 0)}
			var load_ := {"hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.9, -0.5, 0), "head": Vector3(0.55, 0.3, 0),
				"arm_r": Vector3(2.6, 0.2, 0.3), "fore_r": Vector3(1.6, 0, 0), "arm_l": Vector3(1.8, -0.2, -0.2), "fore_l": Vector3(1.4, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(0.4, 0, 0.15), "shin_r": Vector3(-1.3, 0, 0),
				"_lift": Vector3(0, -0.36, 0)}
			var heave := {"hips": Vector3(0, 0.2, 0), "torso": Vector3(-1.0, 0.2, 0), "head": Vector3(0.6, -0.1, 0),
				"arm_r": Vector3(0.9, 0.0, 0.1), "fore_r": Vector3(0.1, 0, 0), "arm_l": Vector3(0.7, 0, -0.1), "fore_l": Vector3(0.2, 0, 0),
				"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(-0.6, 0, 0.12), "shin_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.3, 0)}
			return [h._keys(u, [[0.0, g], [0.2, grab, "out"], [0.26, grab], [0.42, load_], [0.53, heave, "out"], [0.75, heave], [1.0, g]]), "full", lift]
		"giant_swing":
			# leaning back against their weight, arms out low holding them, three turns,
			# then the arms flung forward as they go
			var hold := {"hips": Vector3.ZERO, "arm_r": Vector3(1.0, 0.2, 0.0), "fore_r": Vector3(0.2, 0, 0), "arm_l": Vector3(1.0, -0.2, 0.0), "fore_l": Vector3(0.2, 0, 0),
				"torso": Vector3(0.35, 0, 0), "head": Vector3(-0.1, 0, 0),
				"leg_l": Vector3(0.3, 0, -0.25), "shin_l": Vector3(-0.7, 0, 0), "leg_r": Vector3(0.3, 0, 0.25), "shin_r": Vector3(-0.7, 0, 0),
				"_lift": Vector3(0, -0.16, 0)}
			var fling := {"hips": Vector3.ZERO, "arm_r": Vector3(1.7, -0.3, 0.3), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(1.5, -0.4, -0.2), "fore_l": Vector3(0.1, 0, 0),
				"torso": Vector3(-0.3, -0.4, 0), "head": Vector3(0.2, 0.3, 0),
				"leg_l": Vector3(0.8, 0, -0.15), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.5, 0, 0.15), "shin_r": Vector3(-0.3, 0, 0),
				"_lift": Vector3(0, -0.18, 0)}
			var k_go := 1.6 / T
			var p: Dictionary = h._keys(u, [[0.0, g], [0.12, hold, "out"], [k_go - 0.02, hold], [k_go + 0.05, fling, "out"], [0.85, fling], [1.0, g]])
			var k := clampf((s - 0.3) / 1.3, 0.0, 1.0)
			p["pivot"] = Vector3(0, -TAU * 3.0 * (1.0 - pow(1.0 - k, 1.6)), 0)
			return [p, "full", lift]
		# --- unarmed: martial arts ---
		"hundred_fists":
			# a planted stance and a blur of alternating straights, then one big cross
			var ph := s * TAU / 0.14
			var el := maxf(sin(ph), 0.0)
			var er := maxf(-sin(ph), 0.0)
			var barrage := {"hips": Vector3(0, 0.08 * sin(ph), 0), "torso": Vector3(-0.25, 0.12 * sin(ph), 0), "head": Vector3(0.18, -0.1 * sin(ph), 0),
				"arm_l": Vector3(1.0, 0.5, -0.1).lerp(Vector3(1.55, 0.3, 0.0), el), "fore_l": Vector3(1.9, 0, 0).lerp(Vector3(0.05, 0, 0), el),
				"arm_r": Vector3(0.9, -0.5, 0.1).lerp(Vector3(1.55, -0.3, 0.0), er), "fore_r": Vector3(2.1, 0, 0).lerp(Vector3(0.05, 0, 0), er),
				"leg_l": Vector3(0.45, 0, -0.18), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.35, 0, 0.18), "shin_r": Vector3(-0.4, 0, 0),
				"_lift": Vector3(0, -0.15, 0)}
			var cross := {"hips": Vector3(0, 0.32, 0), "torso": Vector3(-0.35, 0.45, -0.06), "head": Vector3(0.15, -0.7, 0),
				"arm_r": Vector3(1.6, -0.72, 0.0), "fore_r": Vector3(0.02, 0, 0), "arm_l": Vector3(0.75, -0.55, -0.05), "fore_l": Vector3(2.35, 0, 0),
				"leg_l": Vector3(0.75, 0, -0.24), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(-0.7, 0, 0.26), "shin_r": Vector3(-0.12, 0, 0),
				"_lift": Vector3(0, -0.18, 0)}
			var k_x := 1.05 / T
			return [h._keys(u, [[0.0, g], [0.07, barrage, "out"], [k_x - 0.06, barrage], [k_x, cross, "out"], [k_x + 0.1, cross], [1.0, g]]), "full", lift]
		"rising_dragon":
			# crouched low, fist cocked by the hip, then exploding upward in an uppercut,
			# the right knee driving up (launch at 0.16 s)
			var crouch := {"hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.45, -0.4, 0), "head": Vector3(0.3, 0.3, 0),
				"arm_r": Vector3(0.2, 0.3, 0.3), "fore_r": Vector3(2.0, 0, 0), "arm_l": Vector3(1.0, 0.4, -0.2), "fore_l": Vector3(1.6, 0, 0),
				"leg_l": Vector3(0.95, 0, -0.12), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.5, 0, 0.12), "shin_r": Vector3(-1.4, 0, 0),
				"_lift": Vector3(0, -0.3, 0)}
			var rise := {"hips": Vector3(0, 0.4, 0), "torso": Vector3(0.35, 0.5, 0.1), "head": Vector3(0.45, -0.3, 0),
				"arm_r": Vector3(2.5, -0.35, 0.15), "fore_r": Vector3(0.5, 0, 0), "arm_l": Vector3(0.4, 0, -0.6), "fore_l": Vector3(1.0, 0, 0),
				"leg_r": Vector3(1.2, 0, 0.1), "shin_r": Vector3(-1.6, 0, 0), "leg_l": Vector3(-0.2, 0, -0.1), "shin_l": Vector3(-0.2, 0, 0),
				"_lift": Vector3(0, 0.08, 0)}
			var tuck := {"hips": Vector3.ZERO, "torso": Vector3(-0.1, 0, 0), "head": Vector3(0.1, 0, 0),
				"arm_r": Vector3(1.0, -0.2, 0.2), "fore_r": Vector3(1.6, 0, 0), "arm_l": Vector3(1.0, 0.2, -0.2), "fore_l": Vector3(1.6, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.12), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(0.6, 0, 0.12), "shin_r": Vector3(-1.2, 0, 0)}
			var k_up := 0.16 / T
			return [h._keys(u, [[0.0, g], [k_up * 0.8, crouch, "out"], [k_up, crouch], [k_up + 0.12, rise, "out"], [0.62, rise], [0.85, tuck], [1.0, g]]), "full", lift]
		"palm_strike":
			# wound back with the palm cocked by the ear, then the palm driven out
			# straight from the hip through a long step (u 0.36)
			var load_ := {"hips": Vector3(0, -0.6, 0), "torso": Vector3(-0.1, -0.5, 0), "head": Vector3(0.1, 0.6, 0),
				"arm_r": Vector3(0.4, 0.6, 0.3), "fore_r": Vector3(2.0, 0, 0), "hand_r": Vector3(0.9, 0, 0),
				"arm_l": Vector3(1.2, 0.4, -0.1), "fore_l": Vector3(1.0, 0, 0),
				"leg_l": Vector3(0.35, 0, -0.2), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.25, 0, 0.2), "shin_r": Vector3(-0.6, 0, 0),
				"_lift": Vector3(0, -0.16, 0)}
			var drive := {"hips": Vector3(0, 0.4, 0), "torso": Vector3(-0.35, 0.5, 0), "head": Vector3(0.2, -0.6, 0),
				"arm_r": Vector3(1.55, -0.4, 0.0), "fore_r": Vector3(0.02, 0, 0), "hand_r": Vector3(1.2, 0, 0),
				"arm_l": Vector3(0.5, 0, -0.6), "fore_l": Vector3(1.5, 0, 0),
				"leg_l": Vector3(1.0, 0, -0.14), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.8, 0, 0.14), "shin_r": Vector3(-0.15, 0, 0),
				"_lift": Vector3(0, -0.28, 0)}
			return [h._keys(u, [[0.0, g], [0.22, load_, "out"], [0.27, load_], [0.36, drive, "out"], [0.7, drive], [1.0, g]]), "full", lift]
		"sea_king_fist":
			# a deep horse stance, the right fist drawn back by the hip and the left arm
			# out sighting, trembling with the gathered force; then the punch (0.78 s)
			var tr := sin(h._t * 55.0) * 0.03
			var gather := {"hips": Vector3(0, -0.7, 0), "torso": Vector3(-0.15, -0.7, tr), "head": Vector3(0.15, 0.7, 0),
				"arm_r": Vector3(-0.3, 0.6, 0.45), "fore_r": Vector3(2.1, 0, 0), "arm_l": Vector3(1.5, 0.6, -0.2), "fore_l": Vector3(0.2, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.35), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.2, 0, 0.4), "shin_r": Vector3(-1.0, 0, 0),
				"_lift": Vector3(0, -0.36, 0)}
			var punch := {"hips": Vector3(0, 0.5, 0), "torso": Vector3(-0.45, 0.6, 0), "head": Vector3(0.3, -0.6, 0),
				"arm_r": Vector3(1.58, -0.6, 0.0), "fore_r": Vector3(0.0, 0, 0), "arm_l": Vector3(0.4, -0.4, -0.6), "fore_l": Vector3(1.8, 0, 0),
				"leg_l": Vector3(1.2, 0, -0.14), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(-1.0, 0, 0.14), "shin_r": Vector3(-0.1, 0, 0),
				"_lift": Vector3(0, -0.42, 0)}
			var k_p := 0.78 / T
			return [h._keys(u, [[0.0, g], [0.25, gather, "out"], [k_p - 0.03, gather], [k_p, punch, "out"], [0.85, punch], [1.0, g]]), "full", lift]
		# --- learned air attacks (PlungeState) ---
		"twin_cyclone":
			# dual swords: knees up, blades crossed at the chest (0.14 s), then flung
			# out wide and the body drills round three turns, tipped into the dive
			var k_out := 0.14 / T
			var crossed := {"arm_r": Vector3(1.1, 0.9, -0.35), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(1.15, -0.9, 0.35), "fore_l": Vector3(1.0, 0, 0), "hand_l": Vector3(0.6, 0, 0),
				"hips": Vector3.ZERO, "torso": Vector3(-0.3, 0, 0), "head": Vector3(0.15, 0, 0),
				"leg_l": Vector3(1.5, 0, -0.12), "shin_l": Vector3(-2.1, 0, 0), "leg_r": Vector3(1.2, 0, 0.12), "shin_r": Vector3(-1.9, 0, 0),
				"_scale": Vector3(1.04, 0.94, 1.04)}
			var wide := {"arm_r": Vector3(1.45, 0.0, 1.45), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.5, 0, 0),
				"arm_l": Vector3(1.45, 0.0, -1.45), "fore_l": Vector3(0.05, 0, 0), "hand_l": Vector3(-1.5, 0, 0),
				"hips": Vector3.ZERO, "torso": Vector3(-0.35, 0, 0), "head": Vector3(-0.2, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.2), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(0.3, 0, 0.2), "shin_r": Vector3(-0.6, 0, 0),
				"_scale": Vector3(0.96, 1.05, 0.96)}
			var whirl := wide.merged({"_smear": Vector3(0.5, 0, 0)}, true)
			var pose: Dictionary = h._keys(u, [[0.0, {}], [k_out * 0.8, crossed, "out"], [k_out, crossed], [k_out + 0.06, whirl, "out"], [0.85, wide], [1.0, wide]])
			var spin := 1.0 - pow(1.0 - clampf((s - 0.14) / (T * 0.85 - 0.14), 0.0, 1.0), 1.6)
			pose["pivot"] = Vector3(-0.35 * clampf((s - 0.14) / 0.1, 0.0, 1.0), -TAU * 3.0 * spin, 0)
			return [pose, "full", lift]
		"cyclone_land":
			# down low, both blades out wide by the ground, then up to guard
			var low := {"arm_r": Vector3(0.5, 0.0, 1.3), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.4, 0, 0),
				"arm_l": Vector3(0.5, 0.0, -1.3), "fore_l": Vector3(0.1, 0, 0), "hand_l": Vector3(-1.4, 0, 0),
				"hips": Vector3.ZERO, "torso": Vector3(-0.6, 0, 0), "head": Vector3(0.3, 0, 0),
				"leg_l": Vector3(1.3, 0, -0.3), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(-0.3, 0, 0.3), "shin_r": Vector3(-1.4, 0, 0),
				"_scale": Vector3(1.06, 0.92, 1.04)}
			lift.y = -0.45 * (1.0 - h._ease(clampf((u - 0.4) / 0.6, 0.0, 1.0)))
			return [h._keys(u, [[0.0, low], [0.4, low], [1.0, g]]), "full", lift]
		"meteor_kick":
			# unarmed: the right knee chambered to the chest (0.12 s), then the leg
			# shot out straight down the dive, leaning back behind it, arms flung back
			var k_go := 0.12 / T
			var chamber := {"hips": Vector3.ZERO, "torso": Vector3(-0.25, 0, 0), "head": Vector3(0.1, 0, 0),
				"leg_r": Vector3(1.7, 0, 0.1), "shin_r": Vector3(-2.3, 0, 0), "leg_l": Vector3(1.2, 0, -0.12), "shin_l": Vector3(-2.0, 0, 0),
				"arm_l": Vector3(1.1, 0, -0.4), "fore_l": Vector3(1.6, 0, 0), "arm_r": Vector3(0.9, 0, 0.4), "fore_r": Vector3(1.7, 0, 0),
				"_scale": Vector3(1.04, 0.94, 1.02)}
			var kick := {"pivot": Vector3(0.25, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.25, 0, 0), "head": Vector3(-0.45, 0, 0),
				"leg_r": Vector3(0.75, 0, 0.04), "shin_r": Vector3(-0.02, 0, 0), "leg_l": Vector3(1.3, 0, -0.12), "shin_l": Vector3(-2.2, 0, 0),
				"arm_l": Vector3(0.9, 0.3, -0.7), "fore_l": Vector3(1.2, 0, 0), "arm_r": Vector3(-0.8, 0, 0.6), "fore_r": Vector3(0.4, 0, 0),
				"_scale": Vector3(0.96, 1.0, 1.06)}
			return [h._keys(u, [[0.0, {}], [k_go * 0.85, chamber, "out"], [k_go, chamber], [k_go + 0.08, kick, "out"], [1.0, kick]]), "full", lift]
		"meteor_land":
			# the heel driven into the ground: crouched deep, a fist down by it
			var plant := {"hips": Vector3.ZERO, "torso": Vector3(-0.8, 0, 0), "head": Vector3(0.45, 0, 0),
				"arm_r": Vector3(0.75, 0, 0.25), "fore_r": Vector3(0.15, 0, 0), "arm_l": Vector3(-0.5, 0, -0.6), "fore_l": Vector3(0.6, 0, 0),
				"leg_l": Vector3(1.3, 0, -0.18), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(-0.35, 0, 0.18), "shin_r": Vector3(-1.5, 0, 0),
				"_scale": Vector3(1.05, 0.93, 1.03)}
			lift.y = -0.5 * (1.0 - h._ease(clampf((u - 0.35) / 0.65, 0.0, 1.0)))
			return [h._keys(u, [[0.0, plant], [0.35, plant], [1.0, g]]), "full", lift]
		"boarding_dive":
			# cutlass: the blade drawn back by the ear, the off hand pointing at the
			# target, knees up (0.16 s); then point-first down the dive, legs trailing
			var k_go := 0.16 / T
			var draw := {"hips": Vector3(0, -0.35, 0), "torso": Vector3(-0.1, -0.6, 0), "head": Vector3(0.0, 0.5, 0),
				"arm_r": Vector3(2.3, 0.3, 0.7), "fore_r": Vector3(1.5, 0, 0), "hand_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(1.5, 0.4, -0.15), "fore_l": Vector3(0.15, 0, 0),
				"leg_l": Vector3(1.4, 0, -0.12), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(0.9, 0, 0.12), "shin_r": Vector3(-1.6, 0, 0),
				"_scale": Vector3(1.03, 0.95, 1.02)}
			var lunge := {"pivot": Vector3(-0.45, 0, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.3, 0.25, 0), "head": Vector3(0.35, -0.2, 0),
				"arm_r": Vector3(1.4, 0.05, 0.1), "fore_r": Vector3(0.0, 0, 0), "hand_r": Vector3(-1.5, 0, 0),
				"arm_l": Vector3(-0.7, 0, -0.7), "fore_l": Vector3(0.3, 0, 0),
				"leg_l": Vector3(-0.5, 0, -0.1), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(0.35, 0, 0.1), "shin_r": Vector3(-0.5, 0, 0)}
			var thrust := lunge.merged({"_scale": Vector3(0.95, 1.0, 1.1), "_smear": Vector3(0.6, 0, 0)}, true)
			return [h._keys(u, [[0.0, {}], [k_go * 0.8, draw, "out"], [k_go, draw], [k_go + 0.07, thrust, "out"], [k_go + 0.16, lunge], [1.0, lunge]]), "full", lift]
		"vault_back":
			# off the one you hit: a tucked backflip
			var tuck := {"leg_l": Vector3(1.6, 0, -0.1), "shin_l": Vector3(-2.1, 0, 0), "leg_r": Vector3(1.5, 0, 0.1), "shin_r": Vector3(-2.0, 0, 0),
				"arm_l": Vector3(0.8, 0, -0.6), "fore_l": Vector3(1.2, 0, 0), "arm_r": Vector3(1.0, 0, 0.5), "fore_r": Vector3(0.9, 0, 0),
				"hips": Vector3.ZERO, "torso": Vector3(-0.4, 0, 0), "head": Vector3(-0.2, 0, 0)}
			var tw := sin(clampf(u, 0.0, 1.0) * PI)
			var pose := {}
			for j in tuck.keys():
				pose[j] = (tuck[j] as Vector3) * tw
			if h._guns_out():
				h._gun_tuck(pose, tw)
			pose["pivot"] = Vector3(TAU * h._ease(u), 0, 0)
			return [pose, "full", lift]
		"hang_shot":
			# one pistol: hanging side-on, one knee up, drawing a bead along the arm;
			# the shot (0.3 s) kicks the arm and the body back, legs dropping
			var k_f := 0.3 / T
			var ap: float = h.aim_pitch
			var bead := {"hips": Vector3(0, -0.4, 0), "torso": Vector3(ap * 0.3 - 0.1, -0.4, 0.08), "head": Vector3(-ap * 0.3, 0.35, 0),
				"arm_r": Vector3(1.5 + ap, 0.4, 0.05), "fore_r": Vector3.ZERO,
				"arm_l": Vector3(0.4, 0, -1.1), "fore_l": Vector3(0.6, 0, 0),
				"leg_l": Vector3(1.5, 0, -0.15), "shin_l": Vector3(-2.1, 0, 0), "leg_r": Vector3(0.6, 0, 0.18), "shin_r": Vector3(-1.2, 0, 0)}
			var recoil := bead.merged({"arm_r": Vector3(1.95 + ap, 0.4, 0.15), "fore_r": Vector3(0.35, 0, 0),
				"torso": Vector3(ap * 0.3 + 0.25, -0.3, 0.05), "head": Vector3(0.2, 0.3, 0),
				"leg_l": Vector3(0.8, 0, -0.1), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.2, 0, 0.12), "shin_r": Vector3(-0.6, 0, 0)}, true)
			# (the kick is short: the arm comes back down to the line, then away)
			var after := recoil.merged({"arm_r": Vector3(1.6 + ap, 0.4, 0.1), "fore_r": Vector3(0.15, 0, 0), "torso": Vector3(ap * 0.3 + 0.1, -0.35, 0.05)}, true)
			return [h._keys(u, [[0.0, {}], [0.12 / T, bead, "out"], [k_f, bead], [k_f + 0.04, recoil, "out"], [k_f + 0.16, after], [0.85, after], [1.0, g]]), "full", lift]
		# --- Conqueror's Haki ---
		"conqueror":
			# standing tall, fists clenched at the sides, chin up; the will lands (0.38 s)
			# as a jolt through the chest
			var stand := {"hips": Vector3.ZERO, "arm_r": Vector3(0.15, 0, 0.35), "fore_r": Vector3(0.5, 0, 0), "arm_l": Vector3(0.15, 0, -0.35), "fore_l": Vector3(0.5, 0, 0),
				"torso": Vector3(0.12, 0, 0), "head": Vector3(0.18, 0, 0),
				"leg_l": Vector3(0.05, 0, -0.2), "shin_l": Vector3(-0.15, 0, 0), "leg_r": Vector3(0.05, 0, 0.2), "shin_r": Vector3(-0.15, 0, 0),
				"_lift": Vector3.ZERO}
			var jolt := stand.merged({"torso": Vector3(0.3, 0, 0), "head": Vector3(0.3, 0, 0), "arm_r": Vector3(0.3, 0, 0.6), "arm_l": Vector3(0.3, 0, -0.6),
				"_lift": Vector3(0, -0.06, 0)}, true)
			var k_j := 0.38 / T
			return [h._keys(u, [[0.0, g], [k_j - 0.1, stand], [k_j, jolt, "out"], [0.8, jolt], [1.0, g]]), "full", lift]
	return []


static func _ease_io(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
