extends SceneTree
## A punching loadout and a kicking loadout, set up the way a player does it: taught black-leg, the bag's empty hand
## slot clicked to fists in loadout 1, X onto loadout 2 (set up with what's in the hands), the hand slot clicked to
## kicks there; then X goes back and forth between fists and kicks, the light attack punching or kicking to match.
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
			p.unequip_weapon()
			p.learn_black_leg()
			check("taught: loadout 1 kicks (%s)" % str(p.loadouts), p.loadout_at == 0 and p.loadouts[0] == ["black_leg", ""])
			_hand_slot()
			check("the bag's empty hand slot: fists in loadout 1 (%s)" % str(p.loadouts), p.style() == "fist" and p.loadouts[0] == ["", ""])
			TK.act("loadout")
			until = TK.wait_secs(0.4)
		1:
			check("X: loadout 2 set up with the fists in hand (%s, at %d)" % [str(p.loadouts), p.loadout_at], p.loadout_at == 1 and p.loadouts[1] == ["", ""])
			_hand_slot()
			check("the hand slot there: kicks in loadout 2, loadout 1 still fists (%s)" % str(p.loadouts),
				p.style() == "black_leg" and p.loadouts[1] == ["black_leg", ""] and p.loadouts[0] == ["", ""])
			TK.act("loadout")
			until = TK.wait_secs(0.4)
		2:
			check("X: back to the fists (%s, at %d)" % [p.style(), p.loadout_at], p.loadout_at == 0 and p.style() == "fist")
			TK.act("ready_weapon")
			until = TK.wait_secs(0.5)
		3:
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		4:
			check("...and they punch (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_jab")
			until = TK.wait_secs(1.0)
		5:
			TK.act("loadout")
			until = TK.wait_secs(0.4)
		6:
			check("X again: the kicks (%s, at %d)" % [p.style(), p.loadout_at], p.loadout_at == 1 and p.style() == "black_leg")
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		7:
			check("...and they kick, the combo starting over (%s)" % p.body_model.current_action(), p.body_model.current_action() == "bl_1")
			return TK.done(fails)
	step += 1
	return false


## What a click on the bag's main hand slot does (InventoryScreen._put_away with the hand empty).
func _hand_slot() -> void:
	p.set_kicks(not p.kicks)
