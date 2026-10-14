class_name MovePoses
## Getting about: the take-offs (standing, running, sprinting), the double jump and the dash.

## How long each take-off's landing takes (s); a running jump (and a walk off a ledge) keeps
## Humanoid's staggered one-foot landing.
const LAND_SECS := {"stand": 0.32, "sprint": 0.2, "double": 0.42}


static func pose(h, n: String, u: float) -> Array:
	match n:
		"jump_stand", "jump_run", "jump_sprint", "double_jump":
			return _jump(h, n, u)
		"dash":
			return _dash(h, u)
		"log_pose":
			return _log_pose(h, u)
		"draw", "sheathe":
			return DrawMoves.pose(h, n, u)
	return []


## (held) The left wrist raised in front of the chin like a watch: the forearm angled up across
## the body from an elbow held out, so the ball on the back of the wrist faces the eyes; the chest
## turns a little into it and the head tips down to read it. It comes up quick, a touch past, and settles.
static func _log_pose(h, u: float) -> Array:
	var read := {"arm_l": Vector3(0.7, -0.7, -0.5), "fore_l": Vector3(1.5, 0, 0), "hand_l": Vector3(-0.2, 0, 0),
		"torso": Vector3(-0.06, 0.18, 0), "head": Vector3(-0.45, 0.2, 0)}
	var lift_up := read.duplicate()
	lift_up["arm_l"] = read["arm_l"] + Vector3(0.12, 0, 0)
	lift_up["fore_l"] = read["fore_l"] + Vector3(0.1, 0, 0)
	return [h._keys(u, [[0.0, {}], [0.6, lift_up, "out"], [1.0, read]]), "upper", Vector3.ZERO]


## The dash (sidestep / forward / backstep by `dash_dir`, blended on diagonals): a snap into the
## push-off, the body stretched along the move, then the plant, where it overshoots against the
## brake and the arms swing on through before it settles.
static func _dash(h, u: float) -> Array:
	var d: Vector2 = h.dash_dir.normalized() if h.dash_dir.length() > 0.1 else Vector2(0, -1)
	var sx := signf(d.x) if absf(d.x) > 0.01 else 1.0
	var w := [absf(d.x), maxf(d.y, 0.0), maxf(-d.y, 0.0)]
	var ld := "r" if sx > 0.0 else "l"
	var tr := "l" if sx > 0.0 else "r"
	var side := [
		# push: the trail leg drives off, the lead reaches out, the body tips in
		{"pivot": Vector3(0, 0, -0.38 * sx), "hips": Vector3(0, 0.1 * sx, 0), "torso": Vector3(-0.18, 0.2 * sx, 0.14 * sx), "head": Vector3(0.08, -0.1 * sx, 0.2 * sx),
			"leg_" + ld: Vector3(0.2, 0, 0.62 * sx), "shin_" + ld: Vector3(-0.45, 0, 0), "leg_" + tr: Vector3(-0.15, 0, -0.42 * sx), "shin_" + tr: Vector3(-0.12, 0, 0),
			"arm_" + tr: Vector3(0.2, 0, -1.25 * sx), "fore_" + tr: Vector3(0.35, 0, 0), "arm_" + ld: Vector3(0.7, 0, 0.2 * -sx), "fore_" + ld: Vector3(1.4, 0, 0),
			"_scale": Vector3(1.12, 0.94, 1.0), "_lift": Vector3(0, -0.18, 0)},
		# travel: low and long, the trail arm streaming behind
		{"pivot": Vector3(0, 0, -0.32 * sx), "hips": Vector3(0, 0.08 * sx, 0), "torso": Vector3(-0.15, 0.25 * sx, 0.1 * sx), "head": Vector3(0.05, -0.1 * sx, 0.18 * sx),
			"leg_" + ld: Vector3(0.25, 0, 0.75 * sx), "shin_" + ld: Vector3(-0.7, 0, 0), "leg_" + tr: Vector3(-0.1, 0, -0.35 * sx), "shin_" + tr: Vector3(-0.25, 0, 0),
			"arm_" + tr: Vector3(0.3, 0, -1.1 * sx), "fore_" + tr: Vector3(0.5, 0, 0), "arm_" + ld: Vector3(0.6, 0, 0.25 * -sx), "fore_" + ld: Vector3(1.3, 0, 0),
			"_scale": Vector3(1.05, 0.97, 1.0), "_lift": Vector3(0, -0.26, 0)},
		# plant: the lead knee takes it, the body rocks back past upright, the trail arm swings over
		{"pivot": Vector3(0, 0, 0.12 * sx), "hips": Vector3(0, -0.05 * sx, 0), "torso": Vector3(-0.2, -0.1 * sx, -0.1 * sx), "head": Vector3(0.12, 0.1 * sx, -0.08 * sx),
			"leg_" + ld: Vector3(0.35, 0, 0.42 * sx), "shin_" + ld: Vector3(-1.05, 0, 0), "leg_" + tr: Vector3(0.05, 0, -0.18 * sx), "shin_" + tr: Vector3(-0.5, 0, 0),
			"arm_" + tr: Vector3(0.75, 0, -0.45 * sx), "fore_" + tr: Vector3(0.9, 0, 0), "arm_" + ld: Vector3(0.25, 0, 0.7 * sx), "fore_" + ld: Vector3(0.6, 0, 0),
			"_scale": Vector3(1.04, 0.94, 1.04), "_lift": Vector3(0, -0.3, 0)}]
	var fwd := [
		{"pivot": Vector3(-0.42, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.4, 0, 0), "head": Vector3(0.35, 0, 0),
			"leg_r": Vector3(1.05, 0, 0.04), "shin_r": Vector3(-0.85, 0, 0), "leg_l": Vector3(-0.75, 0, -0.04), "shin_l": Vector3(-0.15, 0, 0),
			"arm_l": Vector3(-1.1, 0, -0.3), "fore_l": Vector3(0.25, 0, 0), "arm_r": Vector3(-1.1, 0, 0.3), "fore_r": Vector3(0.25, 0, 0),
			"_scale": Vector3(0.96, 0.95, 1.14), "_lift": Vector3(0, -0.2, 0)},
		{"pivot": Vector3(-0.3, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.25, 0, 0), "head": Vector3(0.22, 0, 0),
			"leg_r": Vector3(0.95, 0, 0.04), "shin_r": Vector3(-1.0, 0, 0), "leg_l": Vector3(-0.55, 0, -0.04), "shin_l": Vector3(-0.3, 0, 0),
			"arm_l": Vector3(-0.9, 0, -0.35), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(-0.9, 0, 0.35), "fore_r": Vector3(0.3, 0, 0),
			"_scale": Vector3(0.98, 0.97, 1.06), "_lift": Vector3(0, -0.26, 0)},
		{"pivot": Vector3(0.1, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.1, 0, 0), "head": Vector3(0.05, 0, 0),
			"leg_r": Vector3(0.7, 0, 0.06), "shin_r": Vector3(-1.2, 0, 0), "leg_l": Vector3(0.05, 0, -0.06), "shin_l": Vector3(-0.85, 0, 0),
			"arm_l": Vector3(0.65, 0, -0.4), "fore_l": Vector3(0.7, 0, 0), "arm_r": Vector3(0.65, 0, 0.4), "fore_r": Vector3(0.7, 0, 0),
			"_scale": Vector3(1.04, 0.94, 1.04), "_lift": Vector3(0, -0.3, 0)}]
	var back := [
		{"pivot": Vector3(0.28, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.15, 0, 0), "head": Vector3(-0.1, 0, 0),
			"leg_l": Vector3(-0.9, 0, -0.05), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(0.5, 0, 0.05), "shin_r": Vector3(-0.6, 0, 0),
			"arm_l": Vector3(0.95, 0, -0.4), "fore_l": Vector3(0.6, 0, 0), "arm_r": Vector3(0.95, 0, 0.4), "fore_r": Vector3(0.6, 0, 0),
			"_scale": Vector3(0.96, 0.95, 1.12), "_lift": Vector3(0, -0.18, 0)},
		{"pivot": Vector3(0.22, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.1, 0, 0), "head": Vector3(-0.05, 0, 0),
			"leg_l": Vector3(-0.75, 0, -0.05), "shin_l": Vector3(-0.35, 0, 0), "leg_r": Vector3(0.45, 0, 0.05), "shin_r": Vector3(-0.9, 0, 0),
			"arm_l": Vector3(0.7, 0, -0.45), "fore_l": Vector3(0.8, 0, 0), "arm_r": Vector3(0.7, 0, 0.45), "fore_r": Vector3(0.8, 0, 0),
			"_scale": Vector3(0.98, 0.97, 1.05), "_lift": Vector3(0, -0.24, 0)},
		# the rear foot catches it and the chest pitches on forward past it
		{"pivot": Vector3(-0.14, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.2, 0, 0), "head": Vector3(0.15, 0, 0),
			"leg_l": Vector3(-0.45, 0, -0.06), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(0.4, 0, 0.06), "shin_r": Vector3(-0.55, 0, 0),
			"arm_l": Vector3(0.3, 0, -0.3), "fore_l": Vector3(0.5, 0, 0), "arm_r": Vector3(0.3, 0, 0.3), "fore_r": Vector3(0.5, 0, 0),
			"_scale": Vector3(1.04, 0.94, 1.04), "_lift": Vector3(0, -0.28, 0)}]
	var phases := []
	for i in 3:
		var p := {}
		for ds in [[side, w[0]], [fwd, w[1]], [back, w[2]]]:
			var src: Dictionary = ds[0][i]
			for j in src.keys():
				p[j] = (p.get(j, Vector3.ZERO) as Vector3) + (src[j] as Vector3) * float(ds[1])
		var tot := float(w[0] + w[1] + w[2])
		p["_scale"] = Vector3.ONE + ((p["_scale"] as Vector3) / tot - Vector3.ONE)
		p["_lift"] = (p["_lift"] as Vector3) / tot
		_dash_arms(h, p, d, sx, ld, i)
		phases.append(p)
	var keys := [[0.0, {}], [0.12, phases[0], "out"], [0.42, phases[1]], [0.66, phases[2], "out"], [1.0, {}]]
	return [h._keys(u, keys), "full", Vector3.ZERO]


## Armed: the weapon hand stays at the guard (pistols tucked, the katana trailed behind), the
## free hand opens out for balance (reaching ahead going forward or left, flung out otherwise).
## Unarmed: the lead hand reaches out ahead on the push.
static func _dash_arms(h, p: Dictionary, d: Vector2, sx: float, ld: String, phase: int) -> void:
	if h._guns_out():
		h._gun_tuck(p, 1.0)
		return
	if not h.armed:
		if phase < 2:
			p["arm_" + ld] = Vector3(1.5, 0.0, -0.15 if ld == "r" else 0.15) * absf(d.x) + (p["arm_" + ld] as Vector3) * (1.0 - absf(d.x))
			p["fore_" + ld] = Vector3(0.15, 0, 0) * absf(d.x) + (p["fore_" + ld] as Vector3) * (1.0 - absf(d.x))
		return
	var g: Dictionary = h._guard()
	var wx := absf(d.x)
	p["arm_r"] = g["arm_r"] + Vector3(0.0, 0.0, 0.15 * sx * wx) + Vector3(0.25 if phase == 0 else 0.0, 0, 0)
	p["fore_r"] = g["fore_r"]
	if g.has("hand_r"):
		p["hand_r"] = g["hand_r"]
	var reach := clampf(maxf(d.y, 0.0) + (wx if sx < 0.0 else 0.0), 0.0, 1.0)
	var fling := clampf(maxf(-d.y, 0.0) + (wx if sx > 0.0 else 0.0), 0.0, 1.0)
	var off := Vector3(1.2, 0.0, -0.95) * reach + Vector3(0.35, 0.0, -1.35) * fling
	if reach + fling < 0.2:
		off = Vector3(0.9, 0.1, -1.0)
	# (the free arm overshoots on the plant: swung on a little further, then back)
	p["arm_l"] = off + (Vector3(0.3, 0, 0.25) if phase == 2 else Vector3.ZERO)
	p["fore_l"] = Vector3(0.1, 0, 0) * reach + Vector3(0.3, 0, 0) * fling + (Vector3(0.25, 0, 0) if phase == 2 else Vector3.ZERO)
	if h.stance == "katana":
		p["arm_r"] = h.KATANA_TRAIL["arm_r"]
		p["fore_r"] = h.KATANA_TRAIL["fore_r"]
		p["hand_r"] = h.KATANA_TRAIL["hand_r"]


static func _jump(h, n: String, u: float) -> Array:
	h._jkind = n.trim_prefix("jump_").trim_suffix("_jump")
	# a short hop lands before the take-off is through: let the landing have the body
	if h.grounded and float(h._action["t"]) > 0.1:
		h._action["dur"] = h._action["t"]
	var keys: Array
	match n:
		"jump_stand":
			# a two-footed spring: the gather, everything thrown up, then the knees tucked
			var crouch := {"pivot": Vector3(-0.1, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.35, 0, 0), "head": Vector3(0.25, 0, 0),
				"leg_l": Vector3(0.75, 0, -0.08), "shin_l": Vector3(-1.25, 0, 0), "leg_r": Vector3(0.75, 0, 0.08), "shin_r": Vector3(-1.25, 0, 0),
				"arm_l": Vector3(-0.6, 0, -0.25), "fore_l": Vector3(0.4, 0, 0), "arm_r": Vector3(-0.6, 0, 0.25), "fore_r": Vector3(0.4, 0, 0),
				"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.06, 0.9, 1.06)}
			var push := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(0.12, 0, 0), "head": Vector3(0.05, 0, 0),
				"leg_l": Vector3(0.05, 0, -0.05), "shin_l": Vector3(-0.1, 0, 0), "leg_r": Vector3(0.05, 0, 0.05), "shin_r": Vector3(-0.1, 0, 0),
				"arm_l": Vector3(2.5, 0, -0.35), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(2.5, 0, 0.35), "fore_r": Vector3(0.3, 0, 0),
				"_lift": Vector3(0, 0.05, 0), "_scale": Vector3(0.95, 1.08, 0.95)}
			var tuck := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(-0.2, 0, 0), "head": Vector3(0.15, 0, 0),
				"leg_l": Vector3(1.35, 0, -0.12), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(1.3, 0, 0.12), "shin_r": Vector3(-1.95, 0, 0),
				"arm_l": Vector3(0.9, 0, -1.1), "fore_l": Vector3(0.6, 0, 0), "arm_r": Vector3(0.9, 0, 1.1), "fore_r": Vector3(0.6, 0, 0),
				"_lift": Vector3(0, 0.1, 0), "_scale": Vector3.ONE}
			keys = [[0.0, crouch], [0.14, push, "out"], [0.3, push], [0.72, tuck, "out"], [1.0, tuck]]
		"jump_run":
			# a hurdle off the stride: the front knee drives on up, the back leg pushes off
			# and folds behind, the arms counter the legs
			var s := _side(h, "side")
			var ls := "l" if s > 0.0 else "r"
			var ts := "r" if s > 0.0 else "l"
			var lo := -1.0 if ls == "l" else 1.0
			var push := {"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, -0.12 * s, 0), "torso": Vector3(-0.22, 0.18 * s, 0), "head": Vector3(0.2, -0.15 * s, 0),
				"leg_" + ls: Vector3(1.2, 0, 0.06 * lo), "shin_" + ls: Vector3(-1.5, 0, 0), "leg_" + ts: Vector3(-0.55, 0, -0.04 * lo), "shin_" + ts: Vector3(-0.25, 0, 0),
				"arm_" + ts: Vector3(1.3, 0, -0.3 * lo), "fore_" + ts: Vector3(0.9, 0, 0), "arm_" + ls: Vector3(-0.7, 0, 0.25 * lo), "fore_" + ls: Vector3(0.5, 0, 0),
				"_scale": Vector3(0.96, 1.06, 0.98)}
			var stride := {"pivot": Vector3(-0.05, 0, 0), "hips": Vector3(0, -0.1 * s, 0), "torso": Vector3(-0.12, 0.12 * s, 0), "head": Vector3(0.12, -0.1 * s, 0),
				"leg_" + ls: Vector3(1.45, 0, 0.08 * lo), "shin_" + ls: Vector3(-0.65, 0, 0), "leg_" + ts: Vector3(-0.35, 0, -0.06 * lo), "shin_" + ts: Vector3(-1.5, 0, 0),
				"arm_" + ts: Vector3(1.55, 0, -0.45 * lo), "fore_" + ts: Vector3(0.6, 0, 0), "arm_" + ls: Vector3(-0.4, 0, 0.9 * lo), "fore_" + ls: Vector3(0.4, 0, 0),
				"_scale": Vector3.ONE}
			keys = [[0.0, push], [0.45, stride], [1.0, stride]]
		"jump_sprint":
			# a long bound: pitched forward, arms swept back, the front knee high, the back
			# leg stretched out behind; then the front leg reaches for the ground ahead
			var s := _side(h, "side")
			var ls := "l" if s > 0.0 else "r"
			var ts := "r" if s > 0.0 else "l"
			var lo := -1.0 if ls == "l" else 1.0
			var launch := {"pivot": Vector3(-0.3, 0, 0), "hips": Vector3(0, -0.08 * s, 0), "torso": Vector3(-0.25, 0.1 * s, 0), "head": Vector3(0.45, -0.1 * s, 0),
				"leg_" + ls: Vector3(1.5, 0, 0.06 * lo), "shin_" + ls: Vector3(-1.7, 0, 0), "leg_" + ts: Vector3(-0.8, 0, -0.04 * lo), "shin_" + ts: Vector3(-0.35, 0, 0),
				"arm_l": Vector3(-1.0, 0, -0.35), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(-1.0, 0, 0.35), "fore_r": Vector3(0.3, 0, 0),
				"_scale": Vector3(0.95, 1.0, 1.1)}
			var flight := {"pivot": Vector3(-0.18, 0, 0), "hips": Vector3(0, -0.06 * s, 0), "torso": Vector3(-0.2, 0.1 * s, 0), "head": Vector3(0.35, -0.08 * s, 0),
				"leg_" + ls: Vector3(1.3, 0, 0.08 * lo), "shin_" + ls: Vector3(-0.45, 0, 0), "leg_" + ts: Vector3(-0.2, 0, -0.06 * lo), "shin_" + ts: Vector3(-1.7, 0, 0),
				"arm_" + ts: Vector3(1.0, 0, -0.5 * lo), "fore_" + ts: Vector3(0.5, 0, 0), "arm_" + ls: Vector3(-0.5, 0, 0.7 * lo), "fore_" + ls: Vector3(0.35, 0, 0),
				"_scale": Vector3.ONE}
			keys = [[0.0, {}], [0.1, launch, "out"], [0.45, launch], [0.85, flight], [1.0, flight]]
		_:
			# kicking off the air: legs snap down, arms flung up, then a tucked forward somersault
			# that opens out with the feet under you
			var kick := {"hips": Vector3.ZERO, "torso": Vector3(0.15, 0, 0), "head": Vector3(0.1, 0, 0),
				"leg_l": Vector3(0.15, 0, -0.06), "shin_l": Vector3(-0.1, 0, 0), "leg_r": Vector3(-0.25, 0, 0.06), "shin_r": Vector3(-0.5, 0, 0),
				"arm_l": Vector3(2.4, 0, -0.4), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(2.4, 0, 0.4), "fore_r": Vector3(0.3, 0, 0),
				"_scale": Vector3(0.94, 1.1, 0.94)}
			var tuck := {"hips": Vector3.ZERO, "torso": Vector3(-0.6, 0, 0), "head": Vector3(-0.4, 0, 0),
				"leg_l": Vector3(1.9, 0, -0.1), "shin_l": Vector3(-2.3, 0, 0), "leg_r": Vector3(1.9, 0, 0.1), "shin_r": Vector3(-2.3, 0, 0),
				"arm_l": Vector3(1.0, 0, -0.3), "fore_l": Vector3(1.5, 0, 0), "arm_r": Vector3(1.0, 0, 0.3), "fore_r": Vector3(1.5, 0, 0),
				"_scale": Vector3(1.05, 0.95, 1.05)}
			var open := {"hips": Vector3.ZERO, "torso": Vector3(-0.1, 0, 0), "head": Vector3(0.1, 0, 0),
				"leg_l": Vector3(0.7, 0, -0.12), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(0.4, 0, 0.12), "shin_r": Vector3(-0.8, 0, 0),
				"arm_l": Vector3(0.6, 0, -1.2), "fore_l": Vector3(0.4, 0, 0), "arm_r": Vector3(0.6, 0, 1.2), "fore_r": Vector3(0.4, 0, 0),
				"_scale": Vector3.ONE}
			keys = [[0.0, kick], [0.1, kick], [0.24, tuck, "out"], [0.62, tuck], [0.85, open], [1.0, open]]
	if h.armed:
		# the weapon hand keeps the air pose's grip (pistols tucked, the katana trailed)
		for k in keys:
			var d: Dictionary = (k[1] as Dictionary).duplicate()
			for j in ["arm_r", "fore_r", "hand_r"] + (["arm_l", "fore_l"] if h._guns_out() else []):
				d.erase(j)
			k[1] = d
	var p: Dictionary = h._keys(u, keys)
	if n == "double_jump":
		p["pivot"] = Vector3(-TAU * Humanoid._ease((u - 0.12) / 0.66), 0, 0)
	return [p, "full", Vector3.ZERO]


## The landing for the jump just finished, added onto the ground pose `p` at strength `k`
## (1 at touch-down); returns how far the hips drop.
static func land(h, p: Dictionary, k: float) -> float:
	match h._land_kind:
		"stand":
			# square on both feet: knees give together, arms forward for balance
			for s in [-1.0, 1.0]:
				var side := "l" if s < 0.0 else "r"
				p["leg_" + side] += Vector3(0.6 * k, 0, 0.08 * k * s)
				p["shin_" + side] += Vector3(-1.25 * k, 0, 0)
				if side == "l" or not h.armed:
					p["arm_" + side] += Vector3(0.45 * k, 0, 0.35 * k * s)
			p["torso"] += Vector3(-0.35 * k, 0, 0)
			p["head"] += Vector3(0.2 * k, 0, 0)
			return 0.3 * k
		"sprint":
			# the reaching foot plants and the back leg is already coming through: barely a dip
			var ls := "l" if h._jside > 0.0 else "r"
			var ts := "r" if h._jside > 0.0 else "l"
			p["leg_" + ls] += Vector3(0.45 * k, 0, 0)
			p["shin_" + ls] += Vector3(-0.8 * k, 0, 0)
			p["leg_" + ts] += Vector3(0.35 * k, 0, 0)
			p["shin_" + ts] += Vector3(-0.9 * k, 0, 0)
			p["torso"] += Vector3(-0.3 * k, 0, 0)
			return 0.16 * k
	# down from the double jump: one knee to the deck, the free hand on the ground, chin up
	var fs := "r" if h.armed else "l"
	var bs := "l" if h.armed else "r"
	var fo := 1.0 if fs == "r" else -1.0
	p["leg_" + fs] += Vector3(1.0 * k, 0, 0.1 * k * fo)
	p["shin_" + fs] += Vector3(-1.5 * k, 0, 0)
	p["leg_" + bs] += Vector3(-0.15 * k, 0, -0.1 * k * fo)
	p["shin_" + bs] += Vector3(-2.0 * k, 0, 0)
	p["torso"] += Vector3(-0.6 * k, 0.15 * k * fo, 0)
	p["head"] += Vector3(0.45 * k, 0, 0)
	p["arm_" + bs] += Vector3(0.3 * k, 0, -0.3 * k * fo)
	p["arm_" + fs] += Vector3(-0.4 * k, 0, 1.0 * k * fo)
	return 0.42 * k


## Which leg leads a take-off off the stride (+1 = left): the one in front, fixed for the action.
static func _side(h, key: String) -> float:
	if not h._action["events"].has(key):
		h._action["events"][key] = 1.0 if sin(h._phase) > 0.0 else -1.0
	h._jside = h._action["events"][key]
	return h._jside
