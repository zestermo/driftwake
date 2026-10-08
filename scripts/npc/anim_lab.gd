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

## Body-space hand points for the diagonal forehand (round 2's B path): high behind the
## right shoulder -> through the space in front -> wrapped low round the left side.
const SLASH_PATH := [
	[0.12, Vector3(0.6, 0.55, 0.55), 0.42],
	[0.32, Vector3(0.55, 0.75, 0.6), 0.4, "smooth"],
	[0.4, Vector3(0.75, 0.6, -0.1), 0.5, "in"],
	[0.5, Vector3(0.05, -0.05, -1.0), 0.62],
	[0.62, Vector3(-0.7, -0.45, -0.45), 0.52],
	[0.76, Vector3(-0.65, -0.55, 0.0), 0.42, "out"],
]
## The same with the wind-up and cock held further out and higher, so the elbow opens
## instead of folding the hand in by the head.
const SLASH_PATH_WIDE := [
	[0.12, Vector3(0.8, 0.55, 0.45), 0.5],
	[0.32, Vector3(0.75, 0.8, 0.45), 0.52, "smooth"],
	[0.4, Vector3(0.85, 0.6, -0.1), 0.55, "in"],
	[0.5, Vector3(0.05, -0.05, -1.0), 0.62],
	[0.62, Vector3(-0.7, -0.45, -0.45), 0.52],
	[0.76, Vector3(-0.65, -0.55, 0.0), 0.42, "out"],
]

## Round 6: round 5's C (wide, high cock, the wrist eased there, whippy through the strike)
## with the off arm's elbow bent: it was near straight reaching on the wind-up and flung
## out through the follow-through. Wrist break per key (radians off the forearm's line,
## ~1.5 square to it, 0 in line): wind start, cock, launch, strike, follow, wrap.
const R6 := {"len": 0.75, "hit": [0.45, 0.6], "chain": 0.55, "sharp": 55.0,
	"lead": {"pivot": 0.02, "hips": 0.04, "torso": 0.02, "arm_l": -0.04, "fore_l": -0.06}}
const SLASH_BREAKS := [1.15, 1.3, 1.35, 0.7, 0.1, 0.3]
## Off-arm elbow (fore_l, rad) on the wind-up reach, through the cut, in the follow-through.
const ELBOWS := {"a": [0.6, 1.2, 0.9], "b": [0.9, 1.4, 1.2], "c": [1.2, 1.6, 1.5]}

## action -> variant -> {"note": what it tries, "spec": overrides of the ActionSpecs entry}
const VARIANTS := {
	"slash_r": {
		"a": {"note": "Round 5 C, the off arm's elbow bent a little"},
		"b": {"note": "Round 5 C, the off arm's elbow bent more"},
		"c": {"note": "Round 5 C, the off arm's elbow bent a lot"},
	},
}

## The variant shown ("" = the live animation).
static var pick: String = ""
## Clean view: FX.slash arcs skipped, BladeTrail drawn on the local captain.
static var clean: bool = false
## Humanoid._swing prints each frame's solve (animsheet: AS_DEBUG=<variant>).
static var debug: bool = false


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


## The ActionSpecs entry with the picked variant's overrides and its swing.
static func spec(n: String) -> Dictionary:
	var s: Dictionary = ActionSpecs.SPECS.get(n, {})
	if pick == "" or not VARIANTS.has(n) or not (VARIANTS[n] as Dictionary).has(pick):
		return s
	var out := s.merged(R6, true).merged(VARIANTS[n][pick].get("spec", {}), true)
	if n == "slash_r":
		out["swing"] = _path(SLASH_PATH_WIDE, SLASH_BREAKS, 1.15, {"center": Vector3(0.08, 1.32, -0.05), "lag": 0.02})
	return out


## A swing from [u, dir, r, mode?] points, a wrist break per point and a radius scale.
static func _path(points: Array, breaks: Array, scale_r: float, extra: Dictionary) -> Dictionary:
	var keys := []
	for i in points.size():
		var p: Array = points[i]
		var key := [p[0], {"dir": p[1], "r": float(p[2]) * scale_r, "break": breaks[i]}]
		if p.size() > 3:
			key.append(p[3])
		keys.append(key)
	return extra.merged({"keys": keys}, true)


## [pose, mask, lift] of the picked variant of `n`, or [] to use the live one.
static func pose(h, n: String, u: float) -> Array:
	if not VARIANTS.has(n) or not (VARIANTS[n] as Dictionary).has(pick):
		return []
	match n + "@" + pick:
		"slash_r@a", "slash_r@b", "slash_r@c":
			var p := _slash_body(h, 1.6, 1.6, ELBOWS[pick])
			return [h._keys(u, [[0.0, p["g"]], [0.32, p["load"], "out"], [0.42, p["cock"]], [0.47, p["whoosh"], "in"],
				[0.52, p["cut"], "out"], [0.66, p["follow"], "out"], [0.84, p["follow"]], [1.0, p["g"]]]), "full", Vector3.ZERO]
	return []


## The forehand's body (the arm rides the swing path): `k` scales the turn and lean, `off`
## the off arm's reach forward on the wind-up and fling back through the cut, `elbow` its
## elbow bend [wind-up reach, cut, follow-through] (a limb is never quite straight).
## Turns: y- faces right (the wind-up loads away from the cut), y+ left (through it); the
## head counters the chest to stay on the target.
static func _slash_body(h, k: float, off: float = 1.0, elbow: Array = [0.3, 0.9, 0.9]) -> Dictionary:
	var g: Dictionary = h._guard()
	# (the more the elbow bends, the higher the upper arm lifts to keep the hand out front)
	var load := {"pivot": Vector3(0.05, 0, -0.05) * k, "hips": Vector3(0, -0.4, 0) * k,
		"torso": Vector3(0.1, -0.55, -0.1) * k, "head": Vector3(-0.05, 0.75, 0.05) * k,
		"arm_l": Vector3(1.35 + float(elbow[0]) * 0.25, -0.2 * off, -0.3 * off), "fore_l": Vector3(float(elbow[0]), 0, 0),
		"leg_l": Vector3(0.35, 0, -0.14), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.15, 0, 0.12), "shin_r": Vector3(-0.65, 0, 0),
		"_lift": Vector3(0, -0.1, 0) * k, "_scale": Vector3(1.05, 0.9, 1.05)}
	var cock := load.merged({"torso": Vector3(0.12, -0.62, -0.12) * k, "hips": Vector3(0, -0.44, 0) * k, "_scale": Vector3(1.06, 0.88, 1.06)}, true)
	# (at the strike the chest is about square to the target, the arm out in front of it:
	# turned further, the shoulder passes the hand and the blade points back across the body)
	var cut := {"pivot": Vector3(-0.08, 0, 0.04), "hips": Vector3(0, 0.12, 0),
		"torso": Vector3(-0.18, 0.12, 0.08), "head": Vector3(0.08, -0.15, 0),
		"arm_l": Vector3(-0.4, 0, -0.9) * off, "fore_l": Vector3(float(elbow[1]), 0, 0),
		"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.75, 0, 0.12), "shin_r": Vector3(-0.22, 0, 0),
		"_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.06, 0.93, 1.06)}
	var whoosh := _with(_mix(cock, cut, 0.5), Vector3(0.92, 1.08, 1.15), 0.7)
	var follow := cut.merged({"pivot": Vector3(-0.16, 0, 0.08) * k, "hips": Vector3(0, 0.55, 0) * k,
		"torso": Vector3(-0.35, 0.75, 0.2) * k, "head": Vector3(0.1, -0.8, 0) * k, "_lift": Vector3(0, -0.25, 0) * k,
		"arm_l": Vector3(-0.5, 0.15, -1.25) * Vector3(1.0, 1.0, off / 1.6), "fore_l": Vector3(float(elbow[2]), 0, 0),
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
