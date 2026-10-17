class_name KatanaFx
## The katana's drawn look, shared by the combo, the heavy (iai), the air slash and the
## techniques: plain steel until the tree's mastery passive awakens it (Progression.elemental
## "katana"), then cloud and sakura. Everything goes through Net.fx (every screen).

const PLAIN_W := 0.32
const AWAKE_W := 0.72


static func awake(player) -> bool:
	return player.progression.elemental("katana")


## The drawn slash along the blade for `secs` (`thrust`: a stab, along its line); `big` scales it.
static func slash(player, secs: float, thrust: bool = false, big: float = 1.0) -> void:
	var a := awake(player)
	Net.fx("katana_slash", [player.body_model, secs, a, (AWAKE_W if a else PLAIN_W) * big, thrust, randi() % 1000])
