class_name DrawnFx
## A weapon's drawn look (the katana's, the axe's), shared by its combo, heavy, air attack and
## techniques: plain steel until its tree's mastery passive awakens it (Progression.elemental),
## then the element (cloud and sakura; fire and embers). Everything goes through Net.fx.

## kind -> [plain width, awakened width] (m) of the drawn slash.
const WIDTHS := {"katana": [0.32, 0.72], "axe": [0.44, 0.9]}


static func net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


static func awake(player, kind: String) -> bool:
	return player.progression.elemental(kind)


## The drawn slash along the blade (the axe's along its bit) for `secs` (`thrust`: a stab, along
## its line); `big` scales it.
static func slash(player, kind: String, secs: float, thrust: bool = false, big: float = 1.0) -> void:
	var a := awake(player, kind)
	net().fx("drawn_slash",[player.body_model, kind, secs, a, float(WIDTHS[kind][1 if a else 0]) * big, thrust, randi() % 1000])
