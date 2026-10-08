class_name AnimLab
## Animation training lab: alternative versions of an action, compared in game (F5 in a
## debug build cycles live -> a -> b -> c) and in tools/dev/animsheet.gd's lab mode.
## Humanoid._action_pose asks pose() first while a variant is picked; ActionSpecs reads
## spec() so a variant can bring its own length, hit window and feel settings ("lead",
## "sharp", "step", see ActionSpecs). Rankings and takeaways: docs/anim_lab.md. Winners
## move into humanoid.gd; this file then starts the next round.

## The action the current round is about (F5 cycles its variants).
const FOCUS := "slash_r"

## action -> variant -> {"note": what it tries, "spec": overrides of the ActionSpecs entry}
const VARIANTS := {
	"slash_r": {
		"a": {"note": "Whip: hips lead, hand trails, weight shift, all three axes",
			"spec": {"lead": {"pivot": 0.03, "hips": 0.045, "torso": 0.022, "arm_l": 0.01, "fore_r": -0.012, "hand_r": -0.03}}},
		"b": {"note": "Impact: whip + squash/stretch, blade smear, hard stop and hold",
			"spec": {"sharp": 60.0, "lead": {"pivot": 0.02, "hips": 0.03, "torso": 0.015, "hand_r": -0.015}}},
		"c": {"note": "On twos: stepped at 20 fps, snapped poses, smear drawing, big holds",
			"spec": {"len": 0.5, "hit": [0.36, 0.6], "step": 20.0, "sharp": 400.0}},
	},
}

## The variant shown ("" = the live animation).
static var pick: String = ""


static func cycle() -> String:
	var order: Array = [""] + (VARIANTS[FOCUS] as Dictionary).keys()
	pick = order[(order.find(pick) + 1) % order.size()]
	return label()


static func label() -> String:
	if pick == "":
		return "Anim lab %s: live" % FOCUS
	return "Anim lab %s: %s - %s" % [FOCUS, pick.to_upper(), VARIANTS[FOCUS][pick]["note"]]


## The ActionSpecs entry with the picked variant's overrides.
static func spec(n: String) -> Dictionary:
	var s: Dictionary = ActionSpecs.SPECS.get(n, {})
	if pick != "" and VARIANTS.has(n) and (VARIANTS[n] as Dictionary).has(pick):
		return s.merged(VARIANTS[n][pick].get("spec", {}), true)
	return s


## [pose, mask, lift] of the picked variant of `n`, or [] to use the live one.
static func pose(h, n: String, u: float) -> Array:
	if not VARIANTS.has(n) or not (VARIANTS[n] as Dictionary).has(pick):
		return []
	match n + "@" + pick:
		"slash_r@a":
			var p := _slash_r(h)
			return [h._keys(u, [[0.0, p["g"]], [0.2, p["load"], "out"], [0.27, p["cock"]], [0.38, p["cut"], "out"],
				[0.46, p["through"], "out"], [0.62, p["cut"]], [1.0, p["g"]]]), "full", Vector3.ZERO]
		"slash_r@b":
			var p := _slash_r(h)
			var load := _with(p["load"], Vector3(1.04, 0.92, 1.04), 0.0)
			var cock := _with(p["cock"], Vector3(1.05, 0.9, 1.05), 0.0)
			var swing := _with(_mix(p["cock"], p["cut"], 0.55), Vector3(0.94, 1.07, 1.1), 0.45)
			var hit := _with(p["cut"], Vector3(1.05, 0.94, 1.03), 0.1)
			var held := _with(p["cut"], Vector3.ONE, 0.0)
			return [h._keys(u, [[0.0, p["g"]], [0.18, load, "out"], [0.27, cock], [0.33, swing, "in"], [0.38, hit, "out"],
				[0.5, held], [0.62, held], [1.0, p["g"]]]), "full", Vector3.ZERO]
		"slash_r@c":
			# keyed on the 20 fps drawings (0.05 s each at the 0.5 s length)
			var p := _slash_r(h, 1.2)
			var load := _with(p["load"], Vector3(1.03, 0.94, 1.03), 0.0)
			var cock := _with(p["cock"], Vector3(1.06, 0.88, 1.06), 0.0)
			var smear := _with(_mix(p["cock"], p["through"], 0.5), Vector3(0.92, 1.08, 1.14), 0.7)
			var hit := _with(p["through"], Vector3(1.06, 0.93, 1.04), 0.0)
			var held := _with(p["cut"], Vector3.ONE, 0.0)
			return [h._keys(u, [[0.0, p["g"]], [0.2, load], [0.3, cock], [0.4, smear], [0.5, hit], [0.7, held],
				[0.9, _mix(held, p["g"], 0.6)], [1.0, p["g"]]]), "full", Vector3.ZERO]
	return []


## The diagonal forehand's key poses (`k` pushes the extremes further).
static func _slash_r(h, k: float = 1.0) -> Dictionary:
	var g: Dictionary = h._guard()
	# wind-up: weight back on the right leg, chest turned away, the blade cocked high
	# over the right shoulder, the off hand out sighting the target
	var load := {"pivot": Vector3(0.06, 0, 0.07) * k, "hips": Vector3(0, 0.4, 0) * k,
		"torso": Vector3(0.12, 0.75, 0.16) * k, "head": Vector3(-0.06, -0.85, -0.1) * k,
		"arm_r": Vector3(2.3, 0.55, 1.4), "fore_r": Vector3(1.05, 0, 0), "hand_r": Vector3(0.85, 0, 0) * k,
		"arm_l": Vector3(1.35, 0.25, -0.25), "fore_l": Vector3(0.25, 0, 0),
		"leg_l": Vector3(0.4, 0, -0.14), "shin_l": Vector3(-0.55, 0, 0), "leg_r": Vector3(-0.15, 0, 0.12), "shin_r": Vector3(-0.6, 0, 0),
		"_lift": Vector3(0, -0.1, 0) * k}
	# (still drifting back through the hold: never quite still)
	var cock := load.merged({"arm_r": Vector3(2.4, 0.6, 1.45), "hand_r": Vector3(0.95, 0, 0) * k, "torso": Vector3(0.14, 0.85, 0.18) * k}, true)
	# the cut: stepped through on the left foot, hips and chest whipped round, the blade
	# flung down and across, the off arm thrown back against it, head on the target
	# (hips + chest turn about as far as the live cut's chest alone: further shows the back)
	var cut := {"pivot": Vector3(-0.14, 0, -0.08) * k, "hips": Vector3(0, -0.35, 0) * k,
		"torso": Vector3(-0.38, -0.7, -0.2) * k, "head": Vector3(0.12, 0.7, 0.14) * k,
		"arm_r": Vector3(1.0, -0.9, -1.0), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.3, 0, 0),
		"arm_l": Vector3(-0.35, 0, -0.95), "fore_l": Vector3(0.95, 0, 0),
		"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.75, 0, 0.12), "shin_r": Vector3(-0.22, 0, 0),
		"_lift": Vector3(0, -0.22, 0) * k}
	# follow-through: the chest and blade carry on past the cut
	var through := cut.merged({"torso": Vector3(-0.42, -0.88, -0.24) * k, "arm_r": Vector3(0.75, -1.0, -1.15),
		"hand_r": Vector3(-1.55, 0, 0), "head": Vector3(0.12, 0.85, 0.15) * k}, true)
	return {"g": g, "load": load, "cock": cock, "cut": cut, "through": through}


## `p` with squash/stretch (body scale: x side, y up, z forward) and blade smear.
static func _with(p: Dictionary, scale: Vector3, smear: float) -> Dictionary:
	return p.merged({"_scale": scale, "_smear": Vector3(smear, 0, 0)}, true)


## A pose part way from `a` to `b` (joints in either).
static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for j in a.keys():
		out[j] = (a[j] as Vector3).lerp(b.get(j, a[j]), k)
	for j in b.keys():
		if not out.has(j):
			out[j] = b[j]
	return out
