extends SceneTree
## R draws the weapon into the right hand and puts it away; a click while sheathed draws instead of attacking.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		1:
			check("R draws weapon (armed)", p.armed)
			check("weapon in right hand", p.body_model.weapon_in_hand and p.body_model.weapon.get_parent() == p.body_model.hand_r)
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		2:
			check("R sheathes", not p.armed and not p.body_model.weapon_in_hand)
			TK.act("light_attack")
			until = TK.wait_secs(0.5)
		3:
			check("click while sheathed draws instead of attacking", p.armed and p.current_state_name() != "LightAttack")
			return TK.done(fails)
	step += 1
	return false
