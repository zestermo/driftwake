extends SceneTree
## A musket in hand: its own stance with both hands on it (no off hand), the low ready; a tapped left click shoulders it
## and fires a ball into the dummy down range, the empty gun reloads with the ramrod; held, the aim steadies and the
## shot let go hits harder and knocks down; put away it's slung on the back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var taken := 0.0
var last
var quick := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -9.0), "weapon": "musket"})


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
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a):
				hits += 1
				taken += h.damage
				last = h)
			# (the reticle laid on the dummy: at rest the camera looks down at the ground ahead, over the right shoulder)
			stage.camera_rig.rotation.y = 0.043
			stage.camera_rig.get_node("SpringArm3D").rotation.x = -0.06
			until = TK.wait_secs(0.7)
		1:
			check("a musket fights as a long gun (%s, %s)" % [p.style(), p.body_model.stance], p.style() == "long_gun" and p.body_model.stance == "long_gun")
			var dirk = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dirk, 1)
			check("two hands on it: nothing goes in the off hand", not p.set_offhand(dirk) and p.offhand_weapon == null)
			check("held at the low ready by the grip", p.body_model.pole_w > 0.9 and p.body_model.pole_lw > 0.9)
			check("one load (%d)" % p.ammo[0], p.ammo[0] == 1 and p.max_ammo() == 1)
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		2:
			check("left click shoulders it (%s, %s)" % [p.current_state_name(), p.body_model.current_action()], p.current_state_name() == "Shoot" and p.body_model.current_action() == "lg_aim")
			until = TK.wait_secs(0.5)
		3:
			check("a tap fires a ball into the dummy down range (%d, %.0f)" % [hits, taken], hits == 1 and taken > 20.0)
			check("it's a shot", last != null and last.ranged and not last.knockdown)
			quick = taken
			until = TK.wait_secs(0.4)
		4:
			check("empty, it's reloading with the ramrod (%s)" % p.body_model.current_action(), p.reloading() and p.body_model.current_action() == "lg_reload")
			until = TK.wait_secs(1.6)
		5:
			check("loaded again (%d)" % p.ammo[0], not p.reloading() and p.ammo[0] == 1)
			hits = 0
			taken = 0.0
			TK.press("light_attack")
			until = TK.wait_secs(1.0)
		6:
			var st = p.state_machine.current_state
			check("held: shouldered and steady (%s, %.2f)" % [p.body_model.current_action(), float(st.get("steady"))], p.body_model.current_action() == "lg_aim" and float(st.get("steady")) >= 1.0 and hits == 0)
			TK.release("light_attack")
			until = TK.wait_ticks(10)
		7:
			check("let go: a steady shot hits harder (%.0f against %.0f) and knocks down" % [taken, quick], hits == 1 and taken > quick * 1.3 and last.knockdown)
			until = TK.wait_secs(2.5)
		8:
			TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		9:
			var w = p.body_model.weapon
			check("put away, it's slung on the back (%s)" % w.get_parent().name, w.get_parent().name == "BackSocket")
			return TK.done(fails)
	step += 1
	return false
