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
const FOCUS := "slash_spin"
const SLOW := 0.25

## No round running (hits 1-3 live in SwordMoves).
## action -> variant -> {"note": what it tries, "spec": overrides of the ActionSpecs entry}
const VARIANTS := {
	"slash_spin": {},
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
	# (through CombatManager, so a hit-stop returns to slow motion, not full speed)
	var cm = Engine.get_main_loop().root.get_node("CombatManager")
	cm._set_base(SLOW if is_equal_approx(cm._base_scale, 1.0) else 1.0)
	return "Anim lab: %s" % ("slow motion" if cm._base_scale < 1.0 else "normal speed")


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
