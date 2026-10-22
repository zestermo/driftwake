class_name KatanaFx
## The katana's drawn look (DrawnFx "katana"), shared by the combo, the heavy (iai), the air
## slash and the techniques: plain steel until the tree's mastery passive awakens it
## (Progression.elemental "katana"), then cloud and sakura. Everything goes through Net.fx.


static func awake(player) -> bool:
	return DrawnFx.awake(player, "katana")


## The drawn slash along the blade for `secs` (`thrust`: a stab, along its line); `big` scales it.
static func slash(player, secs: float, thrust: bool = false, big: float = 1.0) -> void:
	DrawnFx.slash(player, "katana", secs, thrust, big)
