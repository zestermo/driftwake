extends SceneTree
## The fruit stance (1.27, PowerComponent.set_fruit_stance, V): no stance without a fruit; with one, the bar swaps to
## the fruit's powers and back; saving in stance keeps each loadout as what it is; a load comes back out of stance.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var pw = stage.player.power
	pw.fruit = ""
	pw.loadout[0] = "flying_slash"
	pw.other_loadout[0] = "fire_fist"
	pw.set_fruit_stance(true)
	check("no fruit: no stance", not pw.fruit_stance and pw.loadout[0] == "flying_slash")
	pw.fruit = "ember"
	pw.set_fruit_stance(true)
	check("V with a fruit: the bar is the fruit's powers", pw.fruit_stance and pw.loadout[0] == "fire_fist" and pw.other_loadout[0] == "flying_slash")
	var d: Dictionary = pw.to_dict()
	check("saved in stance: each loadout as what it is", d["loadout"][0] == "flying_slash" and d["fruit_loadout"][0] == "fire_fist")
	pw.set_fruit_stance(false)
	check("V again: back to the weapon's", not pw.fruit_stance and pw.loadout[0] == "flying_slash")
	pw.set_fruit_stance(true)
	pw.from_dict(d)
	check("a load comes back out of stance, both loadouts kept", not pw.fruit_stance and pw.loadout[0] == "flying_slash" and pw.other_loadout[0] == "fire_fist")
	return TK.done(fails)
