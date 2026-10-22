class_name DrawnFx
## A weapon's drawn look, shared by its combo, heavy, air attack and techniques: plain steel (the axe's iron) until
## its tree's mastery passive awakens it (Progression.elemental), then the element (the katana's cloud and sakura,
## the axe's fire, the dagger's shadow, dual wield's twin currents, the twin daggers' venom, the corsair's powder).
## A kind is its tree's id. Everything goes through Net.fx.

## kind -> [plain width, awakened width] (m) of the drawn slash.
const WIDTHS := {"katana": [0.32, 0.72], "axe": [0.44, 0.9], "dagger": [0.2, 0.46], "dual": [0.24, 0.5], "dual_dagger": [0.2, 0.44],
	"corsair": [0.28, 0.6]}
## Moves that cut with the off hand ("l") or both ("x"): a slash is laid along each blade that cuts.
const HANDS := {"dual_2": "l", "dual_cross": "x", "dual_spin": "x", "dual_heavy": "x", "dd_2": "l", "dd_3": "x", "dd_4": "x", "dd_heavy": "x"}
## Stabs: the slash is laid along the blade's line, reaching out past the point.
const THRUSTS := ["katana_stab", "dg_stab", "dd_2"]


static func net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


static func awake(player, kind: String) -> bool:
	return player.progression.elemental(kind)


## The drawn slash along the blade (the axe's along its bit) for `secs` (`thrust`: a stab, along its line); `big`
## scales it; `hand`: "r", the off hand's "l", or both "x".
static func slash(player, kind: String, secs: float, thrust: bool = false, big: float = 1.0, hand: String = "r") -> void:
	var a := awake(player, kind)
	for h in (["r", "l"] if hand == "x" else [hand]):
		net().fx("drawn_slash", [player.body_model, kind, secs, a, float(WIDTHS[kind][1 if a else 0]) * big, thrust, randi() % 1000, h == "l"])


## A combo blow's slash (LightAttackState / HeavyAttackState): the hands and the stab from the move's name.
static func blow(player, kind: String, anim: String, secs: float, big: float = 1.0) -> void:
	slash(player, kind, secs, anim in THRUSTS, big, str(HANDS.get(anim, "r")))
