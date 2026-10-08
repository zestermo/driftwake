class_name AnimLab
## Animation training lab: alternative versions of an action, compared in game and in
## tools/dev/animsheet.gd's lab mode. Debug build keys (player.gd): F5 cycles live -> a ->
## b -> c, Shift+F5 slow motion, Ctrl+F5 clean view (the arc effects hidden, the blade's
## own trail drawn). Humanoid._action_pose asks pose() first while a variant is picked;
## ActionSpecs reads spec() so a variant can bring its own length, hit window, swing path
## and feel settings (see ActionSpecs). Rankings and takeaways: docs/anim_lab.md. Winners
## move into the live moves (SwordMoves for swing-path moves); this file then starts the
## next round.

## The action the current round is about (F5 cycles its variants).
const FOCUS := "slash_l"
const SLOW := 0.25

## Round 9: combo hit 2 (slash_l, the rising backhand chained from hit 1, see SwordMoves).
## Live is the diagonal rise; what differs is how steep the cut climbs (the body is live).
const SLASH_L_STEEP := {"center": Vector3(0.08, 1.32, -0.05), "lag": 0.02, "keys": [
	[0.0, {"dir": Vector3(-0.65, -0.55, 0.0), "r": 0.483, "break": 0.3}],
	[0.2, {"dir": Vector3(-0.55, -0.75, -0.3), "r": 0.56, "break": 1.0}, "smooth"],
	[0.32, {"dir": Vector3(-0.2, -0.75, -0.6), "r": 0.66, "break": 1.2}, "in"],
	[0.44, {"dir": Vector3(0.15, 0.2, -1.0), "r": 0.71, "break": 0.6}],
	[0.56, {"dir": Vector3(0.55, 0.85, -0.15), "r": 0.6, "break": 0.2}],
	[0.74, {"dir": Vector3(0.6, 0.7, 0.35), "r": 0.52, "break": 0.35}, "out"]]}
const SLASH_L_FLAT := {"center": Vector3(0.08, 1.32, -0.05), "lag": 0.02, "keys": [
	[0.0, {"dir": Vector3(-0.65, -0.55, 0.0), "r": 0.483, "break": 0.3}],
	[0.2, {"dir": Vector3(-0.75, -0.4, -0.3), "r": 0.56, "break": 1.0}, "smooth"],
	[0.32, {"dir": Vector3(-0.5, -0.25, -0.8), "r": 0.66, "break": 1.2}, "in"],
	[0.44, {"dir": Vector3(0.3, -0.1, -1.0), "r": 0.71, "break": 0.6}],
	[0.56, {"dir": Vector3(0.9, 0.1, -0.35), "r": 0.6, "break": 0.2}],
	[0.74, {"dir": Vector3(0.8, 0.1, 0.55), "r": 0.52, "break": 0.35}, "out"]]}

## action -> variant -> {"note": what it tries, "spec": overrides of the ActionSpecs entry}
const VARIANTS := {
	"slash_l": {
		"a": {"note": "Diagonal rise (as live): low left up to high right"},
		"b": {"note": "Steep rise: nearly straight up the front, ending high",
			"spec": {"swing": SLASH_L_STEEP}},
		"c": {"note": "Flatter rise: a rising sweep, ending at shoulder height",
			"spec": {"swing": SLASH_L_FLAT}},
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


## The ActionSpecs entry with the picked variant's overrides.
static func spec(n: String) -> Dictionary:
	var s: Dictionary = ActionSpecs.SPECS.get(n, {})
	if pick == "" or not VARIANTS.has(n) or not (VARIANTS[n] as Dictionary).has(pick):
		return s
	return s.merged(VARIANTS[n][pick].get("spec", {}), true)


## [pose, mask, lift] of the picked variant of `n`, or [] to use the live one (this round's
## variants only change the swing path, so the body is always live).
static func pose(_h, _n: String, _u: float) -> Array:
	return []
