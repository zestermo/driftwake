class_name MovePoses
## Getting about: the take-offs (standing, running, sprinting), the air step and the dash.

## How long each take-off's landing takes (s); a running jump (and a walk off a ledge) keeps
## Humanoid's staggered one-foot landing.
const LAND_SECS := {"stand": 0.32, "sprint": 0.2, "double": 0.42, "leap": 0.55}


static func pose(h, n: String, u: float) -> Array:
	match n:
		"jump_stand", "jump_run", "jump_sprint", "double_jump":
			return _jump(h, n, u)
		"dash":
			return _dash(h, u)
		"dodge_roll":
			return _roll(h, u)
		"sidestep":
			return _sidestep(h, u)
		"moonstep":
			return _moonstep(h, u)
		"crash_land":
			return _crash_land(h, u)
		"parry_disarm":
			return _parry_disarm(h, u)
		"parry_shove":
			return _parry_shove(h, u)
		"guard_roll":
			return _guard_roll(h, u)
		"breakfall":
			return _breakfall(h, u)
		"sky_leap_charge":
			return _leap_charge(h, u)
		"sky_leap":
			return _leap(h, u)
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


## Roll (Acrobatics): turned into it, a dive onto the leading shoulder, tucked tight over the top in one full turn of
## the pivot, up into a crouch with the feet under you and the arms out ahead, then standing. The pivot is keyed to
## -TAU at the end (wrapped to 0 when the action finishes), so there's no unspin.
static func _roll(h, u: float) -> Array:
	var dive := {"pivot": Vector3(-0.75, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.55, 0, 0), "head": Vector3(-0.3, 0, 0),
		"leg_l": Vector3(1.1, 0, -0.08), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.45, 0, 0.08), "shin_r": Vector3(-0.25, 0, 0),
		"arm_l": Vector3(1.55, 0, -0.25), "fore_l": Vector3(0.45, 0, 0), "arm_r": Vector3(1.55, 0, 0.25), "fore_r": Vector3(0.45, 0, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(0.95, 0.95, 1.14)}
	var tuck := {"pivot": Vector3(-2.3, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.75, 0, 0), "head": Vector3(-0.6, 0, 0),
		"leg_l": Vector3(1.75, 0, -0.1), "shin_l": Vector3(-2.25, 0, 0), "leg_r": Vector3(1.65, 0, 0.1), "shin_r": Vector3(-2.2, 0, 0),
		"arm_l": Vector3(1.0, 0, -0.3), "fore_l": Vector3(1.75, 0, 0), "arm_r": Vector3(1.0, 0, 0.3), "fore_r": Vector3(1.75, 0, 0),
		"_lift": Vector3(0, -0.52, 0), "_scale": Vector3(1.05, 0.92, 1.05)}
	var over := tuck.duplicate()
	over["pivot"] = Vector3(-4.3, 0, 0)
	var up := {"pivot": Vector3(-5.95, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.5, 0, 0), "head": Vector3(0.05, 0, 0),
		"leg_l": Vector3(1.35, 0, -0.12), "shin_l": Vector3(-2.05, 0, 0), "leg_r": Vector3(1.2, 0, 0.12), "shin_r": Vector3(-2.1, 0, 0),
		"arm_l": Vector3(0.8, 0, -0.35), "fore_l": Vector3(0.9, 0, 0), "arm_r": Vector3(0.8, 0, 0.35), "fore_r": Vector3(0.9, 0, 0),
		"_lift": Vector3(0, -0.46, 0), "_scale": Vector3(1.05, 0.93, 1.05)}
	var rise := {"pivot": Vector3(-TAU, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.28, 0, 0), "head": Vector3(0.18, 0, 0),
		"leg_l": Vector3(0.8, 0, -0.1), "shin_l": Vector3(-1.15, 0, 0), "leg_r": Vector3(0.15, 0, 0.1), "shin_r": Vector3(-0.95, 0, 0),
		"arm_l": Vector3(0.65, 0, -0.45), "fore_l": Vector3(0.6, 0, 0), "arm_r": Vector3(0.5, 0, 0.45), "fore_r": Vector3(0.7, 0, 0),
		"_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.04, 0.95, 1.04)}
	var keys := [[0.0, {}], [0.14, dive, "out"], [0.3, tuck], [0.5, over, "linear"], [0.68, up, "linear"], [0.84, rise, "out"],
		[1.0, {"pivot": Vector3(-TAU, 0, 0)}]]
	return [h._keys(u, _unarmed_keys(h, keys)), "full", Vector3.ZERO]


## Sidestep (Acrobatics): a boxer's slip off the line, still facing them: the body tips and drops away over the lead
## leg, the trail foot pushing off, the head ducked off the line and the hands up (or the weapon kept at the guard),
## then a quick settle. Forward or back on the stick it ducks in or sways back instead.
static func _sidestep(h, u: float) -> Array:
	var d: Vector2 = h.dash_dir.normalized() if h.dash_dir.length() > 0.1 else Vector2(1, 0)
	var sx := signf(d.x) if absf(d.x) > 0.05 else 1.0
	var w := absf(d.x)
	var fy := d.y
	var ld := "r" if sx > 0.0 else "l"
	var tr := "l" if sx > 0.0 else "r"
	var guard := {"arm_l": Vector3(1.15, 0, -0.15), "fore_l": Vector3(2.05, 0, 0), "arm_r": Vector3(1.15, 0, 0.15), "fore_r": Vector3(2.05, 0, 0)}
	var slip := {"pivot": Vector3(-0.22 * fy, 0, -0.58 * sx * w), "hips": Vector3(0, 0.12 * sx * w, 0),
		"torso": Vector3(-0.2 - 0.2 * maxf(fy, 0.0), 0.22 * sx * w, 0.18 * sx * w), "head": Vector3(0.15, -0.15 * sx * w, 0.32 * sx * w),
		"leg_" + ld: Vector3(0.25 + 0.4 * maxf(fy, 0.0), 0, 0.5 * sx * w), "shin_" + ld: Vector3(-0.7, 0, 0),
		"leg_" + tr: Vector3(-0.2 - 0.3 * maxf(-fy, 0.0), 0, -0.3 * sx * w), "shin_" + tr: Vector3(-0.2, 0, 0),
		"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.08, 0.95, 1.0)}
	var dip := {"pivot": Vector3(-0.16 * fy, 0, -0.3 * sx * w), "hips": Vector3(0, 0.08 * sx * w, 0),
		"torso": Vector3(-0.25 - 0.15 * maxf(fy, 0.0), 0.12 * sx * w, 0.06 * sx * w), "head": Vector3(0.2, -0.08 * sx * w, 0.16 * sx * w),
		"leg_" + ld: Vector3(0.4 + 0.3 * maxf(fy, 0.0), 0, 0.38 * sx * w), "shin_" + ld: Vector3(-1.0, 0, 0),
		"leg_" + tr: Vector3(0.0, 0, -0.18 * sx * w), "shin_" + tr: Vector3(-0.5, 0, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.03, 0.95, 1.03)}
	if not h._weapon_out():
		slip.merge(guard)
		dip.merge(guard)
	var keys := [[0.0, {}], [0.22, slip, "out"], [0.5, dip], [1.0, {}]]
	return [h._keys(u, _unarmed_keys(h, keys)), "full", Vector3.ZERO]


## Moonstep (Acrobatics): both knees snatched up to the chest, then both feet stamped straight down on the air
## together (JumpState's ring goes under them on that key, MOON_STAMP), the arms flung up overhead and the body
## stretched tall as it shoots up, then the rise: one knee carried up, arms opening out wide.
static func _moonstep(h, u: float) -> Array:
	h._jkind = "double"
	var gather := {"pivot": Vector3(0.05, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.3, 0, 0), "head": Vector3(0.25, 0, 0),
		"leg_l": Vector3(1.75, 0, -0.12), "shin_l": Vector3(-2.15, 0, 0), "leg_r": Vector3(1.65, 0, 0.12), "shin_r": Vector3(-2.15, 0, 0),
		"arm_l": Vector3(-0.65, 0, -0.35), "fore_l": Vector3(0.45, 0, 0), "arm_r": Vector3(-0.65, 0, 0.35), "fore_r": Vector3(0.45, 0, 0),
		"_scale": Vector3(1.07, 0.88, 1.07)}
	var stamp := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(0.12, 0, 0), "head": Vector3(0.32, 0, 0),
		"leg_l": Vector3(0.02, 0, -0.07), "shin_l": Vector3(-0.08, 0, 0), "leg_r": Vector3(0.02, 0, 0.07), "shin_r": Vector3(-0.08, 0, 0),
		"arm_l": Vector3(2.65, 0, -0.38), "fore_l": Vector3(0.25, 0, 0), "arm_r": Vector3(2.65, 0, 0.38), "fore_r": Vector3(0.25, 0, 0),
		"_scale": Vector3(0.9, 1.16, 0.9)}
	var rise := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(-0.05, 0, 0), "head": Vector3(0.18, 0, 0),
		"leg_l": Vector3(0.25, 0, -0.08), "shin_l": Vector3(-0.45, 0, 0), "leg_r": Vector3(1.2, 0, 0.1), "shin_r": Vector3(-1.7, 0, 0),
		"arm_l": Vector3(0.9, 0, -1.25), "fore_l": Vector3(0.35, 0, 0), "arm_r": Vector3(0.9, 0, 1.25), "fore_r": Vector3(0.35, 0, 0),
		"_scale": Vector3.ONE}
	var keys := [[0.0, {}], [0.14, gather, "out"], [0.2, gather], [0.28, stamp, "out"], [0.5, stamp], [0.78, rise], [1.0, rise]]
	return [h._keys(u, _unarmed_keys(h, keys)), "full", Vector3.ZERO]


## Crash Landing (Acrobatics): slammed down onto one knee and a fist (the three-point landing), head up and the free
## arm flung out behind, held while the dust goes out, then up. Snaps in on its first key (spec "snap").
static func _crash_land(h, u: float) -> Array:
	var slam := {"pivot": Vector3(-0.32, 0, 0), "hips": Vector3(0, 0.12, 0), "torso": Vector3(-0.7, -0.12, 0), "head": Vector3(0.6, 0.08, 0),
		"leg_r": Vector3(1.3, 0, 0.18), "shin_r": Vector3(-2.0, 0, 0), "leg_l": Vector3(-0.35, 0, -0.22), "shin_l": Vector3(-2.15, 0, 0),
		"arm_l": Vector3(0.75, 0, -0.3), "fore_l": Vector3(0.15, 0, 0), "arm_r": Vector3(-0.55, 0, 1.0), "fore_r": Vector3(0.35, 0, 0),
		"_lift": Vector3(0, -0.44, 0), "_scale": Vector3(1.1, 0.88, 1.1)}
	var held := slam.duplicate()
	held["_scale"] = Vector3(1.04, 0.95, 1.04)
	held["torso"] = Vector3(-0.6, -0.1, 0)
	var keys := [[0.0, slam], [0.16, held, "out"], [0.58, held], [1.0, {}]]
	return [h._keys(u, _unarmed_keys(h, keys)), "full", Vector3.ZERO]


## Disarm (Defense): out of the parry the weapon hand binds their blade, winds it round low (wrist cocked, chest
## turned away), then whips up and out across the body, flinging it from their grip; the free arm swings out against
## it. A beat held at the top so the flick reads, then back to the guard.
static func _parry_disarm(h, u: float) -> Array:
	var bind := {"torso": Vector3(-0.15, -0.35, 0), "head": Vector3(0.1, 0.3, 0),
		"arm_r": Vector3(1.2, -0.35, 0.15), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(0.6, 0, 0),
		"arm_l": Vector3(0.9, 0.3, -0.2), "fore_l": Vector3(1.2, 0, 0), "_scale": Vector3(1.04, 0.95, 1.04)}
	var flick := {"torso": Vector3(0.12, 0.35, 0), "head": Vector3(-0.1, -0.25, 0),
		"arm_r": Vector3(2.25, 0.35, 0.35), "fore_r": Vector3(0.3, 0, 0), "hand_r": Vector3(-0.85, 0, 0),
		"arm_l": Vector3(0.35, 0, -1.2), "fore_l": Vector3(0.35, 0, 0), "_scale": Vector3(0.96, 1.06, 0.96)}
	var keys := [[0.0, {}], [0.22, bind, "out"], [0.42, flick, "out"], [0.62, flick], [1.0, h._guard()]]
	if h._guns_out():
		for k in keys:
			var d: Dictionary = (k[1] as Dictionary).duplicate()
			for j in ["arm_r", "fore_r", "hand_r"]:
				d.erase(j)
			k[1] = d
	return [h._keys(u, keys), "upper", Vector3.ZERO]


## Shove (Defense): out of the parry a step in on the front foot and the free palm driven straight into their chest,
## the chest turned into it and the weapon arm pulled back, stretched along the push; held, then back to the guard.
static func _parry_shove(h, u: float) -> Array:
	var load := {"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(0.05, -0.4, 0), "head": Vector3(0.0, 0.35, 0),
		"leg_l": Vector3(0.35, 0, -0.08), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.15, 0, 0.1), "shin_r": Vector3(-0.45, 0, 0),
		"arm_l": Vector3(0.9, 0.2, -0.1), "fore_l": Vector3(1.9, 0, 0), "hand_l": Vector3(0.9, 0, 0),
		"arm_r": Vector3(0.6, 0, 0.35), "fore_r": Vector3(1.3, 0, 0),
		"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(1.05, 0.95, 1.0)}
	var push := {"pivot": Vector3(-0.18, 0, 0), "hips": Vector3(0, 0.15, 0), "torso": Vector3(-0.3, 0.35, 0), "head": Vector3(0.22, -0.3, 0),
		"leg_l": Vector3(0.9, 0, -0.08), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(-0.55, 0, 0.1), "shin_r": Vector3(-0.2, 0, 0),
		"arm_l": Vector3(1.55, 0, 0.12), "fore_l": Vector3(0.12, 0, 0), "hand_l": Vector3(1.1, 0, 0),
		"arm_r": Vector3(-0.3, 0, 0.45), "fore_r": Vector3(1.1, 0, 0),
		"_lift": Vector3(0, -0.16, 0), "_scale": Vector3(0.96, 0.97, 1.1)}
	var keys := [[0.0, {}], [0.2, load, "out"], [0.36, push, "out"], [0.62, push], [1.0, {}]]
	return [h._keys(u, _unarmed_keys(h, keys)), "full", Vector3.ZERO]


## Rolling Guard (Defense): a roll out of the block with the guard kept up (forearms crossed before the face, or the
## weapon held tight), still facing them: tucked over forward, backward, or sideways over a shoulder by `dash_dir`,
## one keyed turn of the pivot ending at a full turn (wrapped at the finish), up into the guard.
static func _guard_roll(h, u: float) -> Array:
	var d: Vector2 = h.dash_dir.normalized() if h.dash_dir.length() > 0.1 else Vector2(0, -1)
	var side := absf(d.x) > absf(d.y)
	var s := (signf(d.x) if side else signf(d.y))
	# forward rolls pitch the pivot over x-, back rolls x+, a roll to the right tips over z- (the dash's lean)
	var axis := Vector3(0, 0, -s) if side else Vector3(-s, 0, 0)
	var tuck := {"hips": Vector3.ZERO, "torso": Vector3(-0.7, 0, 0), "head": Vector3(-0.5, 0, 0),
		"leg_l": Vector3(1.7, 0, -0.12), "shin_l": Vector3(-2.2, 0, 0), "leg_r": Vector3(1.6, 0, 0.12), "shin_r": Vector3(-2.2, 0, 0),
		"arm_l": Vector3(1.4, -0.4, -0.05), "fore_l": Vector3(2.1, 0, 0), "arm_r": Vector3(1.4, 0.4, 0.05), "fore_r": Vector3(2.1, 0, 0),
		"_lift": Vector3(0, -0.5, 0), "_scale": Vector3(1.05, 0.92, 1.05)}
	var k1 := tuck.duplicate()
	k1["pivot"] = axis * 1.1
	var k2 := tuck.duplicate()
	k2["pivot"] = axis * 3.3
	var k3 := tuck.duplicate()
	k3["pivot"] = axis * 5.4
	k3["_lift"] = Vector3(0, -0.4, 0)
	var up: Dictionary = h._guard().merged({"pivot": axis * TAU, "hips": Vector3.ZERO, "leg_l": Vector3(0.7, 0, -0.15), "shin_l": Vector3(-1.1, 0, 0),
		"leg_r": Vector3(0.2, 0, 0.15), "shin_r": Vector3(-0.9, 0, 0), "_lift": Vector3(0, -0.2, 0)}, true)
	var keys := [[0.0, {}], [0.16, k1, "out"], [0.42, k2, "linear"], [0.66, k3, "linear"], [0.86, up, "out"], [1.0, {"pivot": axis * TAU}]]
	return [h._keys(u, _unarmed_keys(h, keys)), "full", Vector3.ZERO]


## (held) Planted (Defense): the stance's block `bp` over a wide, deep stance, front knee bent over the toes, the
## back leg braced long behind, the hips low and square, so the whole body is behind the guard. Settles in.
static func planted(h, u: float, bp: Dictionary) -> Array:
	var root := bp.merged({"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, -0.15, 0),
		"leg_l": Vector3(0.75, 0, -0.32), "shin_l": Vector3(-1.05, 0, 0), "leg_r": Vector3(-0.45, 0, 0.36), "shin_r": Vector3(-0.35, 0, 0),
		"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(1.04, 0.96, 1.04)}, true)
	return [h._keys(u, [[0.0, {}], [1.0, root, "out"]]), "full", Vector3.ZERO]


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
			keys = _air_step(h)
	if h._weapon_out():
		# the weapon hand keeps the air pose's grip (pistols tucked, the katana trailed)
		for k in keys:
			var d: Dictionary = (k[1] as Dictionary).duplicate()
			for j in ["arm_r", "fore_r", "hand_r"] + (["arm_l", "fore_l"] if h._guns_out() else []):
				d.erase(j)
			k[1] = d
	return [h._keys(u, keys), "full", Vector3.ZERO]


## Breakfall: thrown limp through the air, the body snaps into a tuck and rolls upright from the sprawl the ragdoll
## left (the pivot from there to level), then opens out, arms wide, feet under it to land.
static func _breakfall(h, u: float) -> Array:
	if not h._action["events"].has("p0"):
		h._action["events"]["p0"] = h._cur["pivot"]
	var p0: Vector3 = h._action["events"]["p0"]
	var tuck := {"pivot": p0 * 0.4, "hips": Vector3.ZERO, "torso": Vector3(-0.55, 0, 0), "head": Vector3(-0.25, 0, 0),
		"leg_l": Vector3(1.75, 0, -0.1), "shin_l": Vector3(-2.2, 0, 0), "leg_r": Vector3(1.65, 0, 0.1), "shin_r": Vector3(-2.15, 0, 0),
		"arm_l": Vector3(1.0, 0, -0.3), "fore_l": Vector3(1.7, 0, 0), "arm_r": Vector3(1.0, 0, 0.3), "fore_r": Vector3(1.7, 0, 0),
		"_scale": Vector3(1.06, 0.92, 1.06)}
	var open := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(0.05, 0, 0), "head": Vector3(0.05, 0, 0),
		"leg_l": Vector3(0.55, 0, -0.16), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(0.3, 0, 0.16), "shin_r": Vector3(-0.65, 0, 0),
		"arm_l": Vector3(0.65, 0, -1.35), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(0.65, 0, 1.35), "fore_r": Vector3(0.3, 0, 0),
		"_scale": Vector3(0.96, 1.06, 0.96)}
	var keys := [[0.0, {"pivot": p0}], [0.28, tuck, "out"], [0.6, open, "out"], [1.0, open]]
	if h.armed:
		for k in keys:
			var d: Dictionary = (k[1] as Dictionary).duplicate()
			for j in ["arm_r", "fore_r", "hand_r"] + (["arm_l", "fore_l"] if h._guns_out() else []):
				d.erase(j)
			k[1] = d
	return [h._keys(u, keys), "full", Vector3.ZERO]


## (held) Sky Leap's charge: sunk into a deep wide squat, chest over the knees, arms swept back, chin up at the sky,
## the whole body trembling a little more as the charge builds.
static func _leap_charge(h, u: float) -> Array:
	var shake: float = sin(h._t * 47.0) * 0.025 * u
	var squat := {"pivot": Vector3(-0.08, 0, shake), "hips": Vector3.ZERO, "torso": Vector3(-0.5, 0, shake), "head": Vector3(0.42, 0, 0),
		"leg_l": Vector3(1.05, 0, -0.2), "shin_l": Vector3(-1.8, 0, 0), "leg_r": Vector3(1.05, 0, 0.2), "shin_r": Vector3(-1.8, 0, 0),
		"arm_l": Vector3(-0.85, 0, -0.35), "fore_l": Vector3(0.5, 0, 0), "arm_r": Vector3(-0.85, 0, 0.35), "fore_r": Vector3(0.5, 0, 0),
		"_lift": Vector3(0, -0.36 - 0.03 * u, 0), "_scale": Vector3(1.04 + 0.04 * u, 0.94 - 0.05 * u, 1.04 + 0.04 * u)}
	return [h._keys(u, _unarmed_keys(h, [[0.0, {}], [0.35, squat, "out"], [1.0, squat]])), "full", Vector3.ZERO]


## (held through the rise) Sky Leap: everything thrown up out of the squat, arms overhead and the body stretched,
## then the rocket: one knee drawn up, the other leg trailing straight, the arms swept down and back, chin up.
static func _leap(h, u: float) -> Array:
	h._jkind = "leap"
	var burst := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(0.12, 0, 0), "head": Vector3(0.3, 0, 0),
		"leg_l": Vector3(0.05, 0, -0.05), "shin_l": Vector3(-0.05, 0, 0), "leg_r": Vector3(0.05, 0, 0.05), "shin_r": Vector3(-0.05, 0, 0),
		"arm_l": Vector3(2.7, 0, -0.3), "fore_l": Vector3(0.2, 0, 0), "arm_r": Vector3(2.7, 0, 0.3), "fore_r": Vector3(0.2, 0, 0),
		"_lift": Vector3(0, 0.05, 0), "_scale": Vector3(0.9, 1.16, 0.9)}
	var rocket := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(0.08, 0, 0), "head": Vector3(0.35, 0, 0),
		"leg_l": Vector3(-0.1, 0, -0.05), "shin_l": Vector3(-0.25, 0, 0), "leg_r": Vector3(1.35, 0, 0.08), "shin_r": Vector3(-1.9, 0, 0),
		"arm_l": Vector3(-0.55, 0, -0.3), "fore_l": Vector3(0.35, 0, 0), "arm_r": Vector3(-0.55, 0, 0.3), "fore_r": Vector3(0.35, 0, 0),
		"_lift": Vector3.ZERO, "_scale": Vector3(0.97, 1.05, 0.97)}
	return [h._keys(u, _unarmed_keys(h, [[0.0, {}], [0.12, burst, "out"], [0.55, rocket], [1.0, rocket]])), "full", Vector3.ZERO]


## Armed: the weapon hand keeps its grip (pistols tucked too).
static func _unarmed_keys(h, keys: Array) -> Array:
	if not h._weapon_out():
		return keys
	for k in keys:
		var d: Dictionary = (k[1] as Dictionary).duplicate()
		for j in ["arm_r", "fore_r", "hand_r"] + (["arm_l", "fore_l"] if h._guns_out() else []):
			d.erase(j)
		k[1] = d
	return keys


## When the air step's foot stamps down (s into the action): the puff goes under it then.
const STAMP_S := 0.15


## The air walk (Geppo, Sky Walk): upright, the knee driven high, then the foot stamped straight down onto the air
## while the other knee comes up for the next step, the arms pumping against the legs. No flip. Each step takes the
## other foot; the pivot eases in from wherever the body was (a tumble's sprawl, righted).
static func _air_step(h) -> Array:
	if not h._action["events"].has("side"):
		h.air_foot = -h.air_foot
		h._action["events"]["side"] = h.air_foot
		h._action["events"]["p0"] = h._cur["pivot"]
	var s: float = h._action["events"]["side"]
	h._jside = s
	var ls := "l" if s > 0.0 else "r"
	var ts := "r" if s > 0.0 else "l"
	var lo := -1.0 if ls == "l" else 1.0
	var to := -lo
	var start := {"pivot": h._action["events"]["p0"]}
	var knee := {"pivot": Vector3(0.06, 0, 0), "hips": Vector3(0, 0.1 * s, 0), "torso": Vector3(-0.12, -0.12 * s, 0), "head": Vector3(0.12, 0.08 * s, 0),
		"leg_" + ls: Vector3(1.8, 0, 0.06 * lo), "shin_" + ls: Vector3(-2.15, 0, 0), "leg_" + ts: Vector3(-0.2, 0, 0.05 * to), "shin_" + ts: Vector3(-0.55, 0, 0),
		"arm_" + ts: Vector3(1.35, 0, 0.2 * to), "fore_" + ts: Vector3(1.25, 0, 0), "arm_" + ls: Vector3(-0.75, 0, 0.3 * lo), "fore_" + ls: Vector3(0.45, 0, 0),
		"_scale": Vector3(1.05, 0.92, 1.05)}
	var stamp := {"pivot": Vector3(-0.04, 0, 0), "hips": Vector3(0, -0.08 * s, 0), "torso": Vector3(0.06, 0.1 * s, 0), "head": Vector3(-0.02, -0.06 * s, 0),
		"leg_" + ls: Vector3(0.02, 0, 0.04 * lo), "shin_" + ls: Vector3(-0.1, 0, 0), "leg_" + ts: Vector3(1.3, 0, 0.06 * to), "shin_" + ts: Vector3(-1.7, 0, 0),
		"arm_" + ls: Vector3(1.2, 0, 0.25 * lo), "fore_" + ls: Vector3(1.15, 0, 0), "arm_" + ts: Vector3(-0.65, 0, 0.3 * to), "fore_" + ts: Vector3(0.5, 0, 0),
		"_scale": Vector3(0.94, 1.1, 0.94)}
	var drift := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(-0.08, 0.04 * s, 0), "head": Vector3(0.08, 0, 0),
		"leg_" + ls: Vector3(0.55, 0, 0.08 * lo), "shin_" + ls: Vector3(-0.95, 0, 0), "leg_" + ts: Vector3(1.05, 0, 0.08 * to), "shin_" + ts: Vector3(-1.5, 0, 0),
		"arm_" + ls: Vector3(0.7, 0, 0.75 * lo), "fore_" + ls: Vector3(0.6, 0, 0), "arm_" + ts: Vector3(0.4, 0, 0.85 * to), "fore_" + ts: Vector3(0.5, 0, 0),
		"_scale": Vector3.ONE}
	return [[0.0, start], [0.1, knee, "out"], [0.17, knee], [0.3, stamp, "out"], [0.46, stamp], [0.8, drift], [1.0, drift]]


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
				if side == "l" or not h._weapon_out():
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
	var fs := "r" if h._weapon_out() else "l"
	var bs := "l" if h._weapon_out() else "r"
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
