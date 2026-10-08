class_name AnimLab
## Animation training lab: alternative versions of an action, compared in game and in
## tools/dev/animsheet.gd's lab mode. Debug build keys (player.gd): F5 cycles live -> a ->
## b -> c, Shift+F5 slow motion, Ctrl+F5 clean view (the arc effects hidden, the blade's
## own trail drawn). Humanoid._action_pose asks pose() first while a variant is picked;
## ActionSpecs reads spec() so a variant can bring its own length, hit window, swing path
## and feel settings (see ActionSpecs). Rankings and takeaways: docs/anim_lab.md. Winners
## move into humanoid.gd; this file then starts the next round.

## The action the current round is about (F5 cycles its variants).
const FOCUS := "slash_r"
const SLOW := 0.25

## Round 2: the hand on a swing path (arcs, IK arm, blade along the path), the body turning
## with the cut (right on the wind-up, left through it), squash and smear from round 1's B.
## Body-space swing points for the diagonal forehand: high behind the right shoulder ->
## through the space in front -> wrapped low round the left side.
const SLASH_SWING := [
	[0.12, {"dir": Vector3(0.6, 0.55, 0.55), "r": 0.42, "blade": Vector3(0.1, 0.35, 1.0), "pole": Vector3(0.9, -0.2, 0.4)}],
	[0.32, {"dir": Vector3(0.55, 0.75, 0.6), "r": 0.4, "blade": Vector3(-0.25, -0.1, 1.0), "pole": Vector3(0.9, 0.0, 0.5)}, "smooth"],
	[0.4, {"dir": Vector3(0.75, 0.6, -0.1), "r": 0.5, "blade": Vector3(0.3, 0.9, 0.2), "pole": Vector3(0.8, -0.4, 0.3)}, "in"],
	[0.5, {"dir": Vector3(0.05, -0.05, -1.0), "r": 0.62, "blade": Vector3(-0.45, -0.3, -0.85), "pole": Vector3(0.6, -0.9, 0.2)}],
	[0.62, {"dir": Vector3(-0.7, -0.45, -0.45), "r": 0.52, "blade": Vector3(-0.55, -0.55, 0.6), "pole": Vector3(0.3, -1.0, 0.2)}],
	[0.76, {"dir": Vector3(-0.65, -0.55, 0.0), "r": 0.42, "blade": Vector3(-0.3, -0.8, 0.5), "pole": Vector3(0.3, -1.0, 0.3)}, "out"],
]

## action -> variant -> {"note": what it tries, "spec": overrides of the ActionSpecs entry}
const VARIANTS := {
	"slash_r": {
		"a": {"note": "Arc, 0.6 s: the hand on a path, body turning with the cut",
			"spec": {"len": 0.6, "hit": [0.43, 0.6], "chain": 0.42, "sharp": 55.0,
				"lead": {"pivot": 0.03, "hips": 0.05, "torso": 0.025},
				"swing": {"center": Vector3(0.08, 1.3, -0.05), "keys": SLASH_SWING, "lag": 0.015}}},
		"b": {"note": "Big arc, 0.75 s: longer wind-up, more turn, wraps round the body",
			"spec": {"len": 0.75, "hit": [0.45, 0.6], "chain": 0.55, "sharp": 55.0,
				"lead": {"pivot": 0.04, "hips": 0.07, "torso": 0.035},
				"swing": {"center": Vector3(0.08, 1.32, -0.05), "keys": SLASH_SWING, "lag": 0.02, "scale_r": 1.15}}},
		"c": {"note": "Body-driven, 0.6 s: hand stays before the chest, hips and chest swing it",
			"spec": {"len": 0.6, "hit": [0.43, 0.6], "chain": 0.42, "sharp": 55.0,
				"lead": {"pivot": 0.03, "hips": 0.06, "torso": 0.03},
				"swing": {"space": "chest", "center": Vector3(0.1, 0.45, -0.08), "keys": [
					[0.12, {"dir": Vector3(0.7, 0.6, 0.3), "r": 0.42, "blade": Vector3(0.0, 0.4, 1.0), "pole": Vector3(0.9, -0.3, 0.3)}],
					[0.36, {"dir": Vector3(0.75, 0.65, 0.2), "r": 0.42, "blade": Vector3(-0.2, 0.1, 1.0), "pole": Vector3(0.9, 0.0, 0.4)}, "smooth"],
					[0.5, {"dir": Vector3(0.2, -0.15, -1.0), "r": 0.58, "blade": Vector3(-0.4, -0.3, -0.85), "pole": Vector3(0.6, -0.9, 0.2)}, "in"],
					[0.66, {"dir": Vector3(-0.35, -0.45, -0.8), "r": 0.52, "blade": Vector3(-0.6, -0.55, -0.1), "pole": Vector3(0.4, -1.0, 0.2)}],
					[0.78, {"dir": Vector3(-0.3, -0.5, -0.7), "r": 0.48, "blade": Vector3(-0.5, -0.7, 0.2), "pole": Vector3(0.4, -1.0, 0.3)}, "out"]]}}},
	},
}

## The variant shown ("" = the live animation).
static var pick: String = ""
## Clean view: FX.slash arcs skipped, BladeTrail drawn on the local captain.
static var clean: bool = false


static func cycle() -> String:
	var order: Array = [""] + (VARIANTS[FOCUS] as Dictionary).keys()
	pick = order[(order.find(pick) + 1) % order.size()]
	return label()


static func label() -> String:
	if pick == "":
		return "Anim lab %s: live" % FOCUS
	return "Anim lab %s: %s - %s" % [FOCUS, pick.to_upper(), VARIANTS[FOCUS][pick]["note"]]


static func toggle_slow() -> String:
	Engine.time_scale = SLOW if is_equal_approx(Engine.time_scale, 1.0) else 1.0
	return "Anim lab: %s" % ("slow motion" if Engine.time_scale < 1.0 else "normal speed")


static func toggle_clean() -> String:
	clean = not clean
	return "Anim lab: %s" % ("clean view (blade trail, no arcs)" if clean else "arcs back on")


## The ActionSpecs entry with the picked variant's overrides (a swing's "scale_r" widens
## its points).
static func spec(n: String) -> Dictionary:
	var s: Dictionary = ActionSpecs.SPECS.get(n, {})
	if pick == "" or not VARIANTS.has(n) or not (VARIANTS[n] as Dictionary).has(pick):
		return s
	var out := s.merged(VARIANTS[n][pick].get("spec", {}), true)
	if out.has("swing") and (out["swing"] as Dictionary).has("scale_r"):
		var sw: Dictionary = (out["swing"] as Dictionary).duplicate(true)
		for key in sw["keys"]:
			key[1]["r"] = float(key[1]["r"]) * float(sw["scale_r"])
		out["swing"] = sw
	return out


## [pose, mask, lift] of the picked variant of `n`, or [] to use the live one.
static func pose(h, n: String, u: float) -> Array:
	if not VARIANTS.has(n) or not (VARIANTS[n] as Dictionary).has(pick):
		return []
	match n + "@" + pick:
		"slash_r@a":
			var p := _slash_body(h, 1.0)
			return [h._keys(u, [[0.0, p["g"]], [0.3, p["load"], "out"], [0.4, p["cock"]], [0.46, p["whoosh"], "in"],
				[0.5, p["cut"], "out"], [0.62, p["follow"], "out"], [0.78, p["follow"]], [1.0, p["g"]]]), "full", Vector3.ZERO]
		"slash_r@b":
			var p := _slash_body(h, 1.35)
			return [h._keys(u, [[0.0, p["g"]], [0.32, p["load"], "out"], [0.42, p["cock"]], [0.47, p["whoosh"], "in"],
				[0.52, p["cut"], "out"], [0.66, p["follow"], "out"], [0.84, p["follow"]], [1.0, p["g"]]]), "full", Vector3.ZERO]
		"slash_r@c":
			var p := _slash_body(h, 1.6)
			return [h._keys(u, [[0.0, p["g"]], [0.3, p["load"], "out"], [0.4, p["cock"]], [0.46, p["whoosh"], "in"],
				[0.5, p["cut"], "out"], [0.66, p["follow"], "out"], [0.8, p["follow"]], [1.0, p["g"]]]), "full", Vector3.ZERO]
	return []


## The forehand's body (the arm rides the swing path): `k` scales the turn and lean.
## Turns: y- faces right (the wind-up loads away from the cut), y+ left (through it); the
## head counters the chest to stay on the target.
static func _slash_body(h, k: float) -> Dictionary:
	var g: Dictionary = h._guard()
	var load := {"pivot": Vector3(0.05, 0, -0.05) * k, "hips": Vector3(0, -0.4, 0) * k,
		"torso": Vector3(0.1, -0.55, -0.1) * k, "head": Vector3(-0.05, 0.75, 0.05) * k,
		"arm_l": Vector3(1.35, -0.2, -0.3), "fore_l": Vector3(0.3, 0, 0),
		"leg_l": Vector3(0.35, 0, -0.14), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.15, 0, 0.12), "shin_r": Vector3(-0.65, 0, 0),
		"_lift": Vector3(0, -0.1, 0) * k, "_scale": Vector3(1.05, 0.9, 1.05)}
	var cock := load.merged({"torso": Vector3(0.12, -0.62, -0.12) * k, "hips": Vector3(0, -0.44, 0) * k, "_scale": Vector3(1.06, 0.88, 1.06)}, true)
	var cut := {"pivot": Vector3(-0.12, 0, 0.06) * k, "hips": Vector3(0, 0.3, 0) * k,
		"torso": Vector3(-0.3, 0.35, 0.12) * k, "head": Vector3(0.1, -0.45, 0) * k,
		"arm_l": Vector3(-0.4, 0, -0.9), "fore_l": Vector3(0.9, 0, 0),
		"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.75, 0, 0.12), "shin_r": Vector3(-0.22, 0, 0),
		"_lift": Vector3(0, -0.22, 0) * k, "_scale": Vector3(1.06, 0.93, 1.06)}
	var whoosh := _with(_mix(cock, cut, 0.5), Vector3(0.92, 1.08, 1.15), 0.7)
	var follow := cut.merged({"pivot": Vector3(-0.16, 0, 0.08) * k, "hips": Vector3(0, 0.55, 0) * k,
		"torso": Vector3(-0.35, 0.75, 0.2) * k, "head": Vector3(0.1, -0.8, 0) * k, "_lift": Vector3(0, -0.25, 0) * k,
		"_scale": Vector3.ONE, "_smear": Vector3.ZERO}, true)
	return {"g": g, "load": load, "cock": cock, "whoosh": whoosh, "cut": cut, "follow": follow}


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
