extends SceneTree
## A spear in hand: its own stance, both hands on it (no off hand), and from three paces off (past a cutlass's
## reach) the light combo's thrust, its rising cut and sweep, and the heavy (Skewer) all land on the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hc
var hp := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3.0), "weapon": "spear"})


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
			hc = stage.dummy.get_node("HealthComponent")
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.7)
		1:
			check("a spear fights as a polearm (%s)" % p.style(), p.style() == "polearm" and p.body_model.stance == "polearm")
			var dirk = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dirk, 1)
			check("two hands on it: nothing goes in the off hand", not p.set_offhand(dirk) and p.offhand_weapon == null)
			check("held at the guard: the spear turned along the shaft by the grip", p.body_model.pole_w > 0.9 and not p.body_model.weapon.quaternion.is_equal_approx(Quaternion.IDENTITY))
			var tip: Vector3 = p.body_model.weapon.global_transform * Vector3(0, 0, p.body_model.weapon.mesh.get_aabb().position.z)
			check("the point out ahead at the guard (%.2f m)" % -(tip - p.global_position).z, -(tip - p.global_position).z > 1.0)
			check("the dummy stands past a cutlass's reach (%.1f m)" % p.global_position.distance_to(stage.dummy.global_position),
				p.global_position.distance_to(stage.dummy.global_position) > 2.6)
			hp = hc.current_health
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		2:
			check("left click thrusts (%s)" % p.body_model.current_action(), p.body_model.current_action() == "pole_thrust")
			until = TK.wait_secs(0.45)
		3:
			check("the thrust lands at polearm reach (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			hp = hc.current_health
			TK.act("light_attack")
			until = TK.wait_secs(0.15)
		4:
			check("it chains into the rising cut (%s)" % p.body_model.current_action(), p.body_model.current_action() == "pole_rise")
			until = TK.wait_secs(0.4)
		5:
			check("the rising cut lands (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			hp = hc.current_health
			TK.act("light_attack")
			until = TK.wait_secs(0.15)
		6:
			check("then the sweep (%s)" % p.body_model.current_action(), p.body_model.current_action() == "pole_sweep")
			until = TK.wait_secs(0.5)
		7:
			check("the sweep lands (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			until = TK.wait_secs(1.2)
		8:
			if not p.is_free():
				return false
			hp = hc.current_health
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		9:
			check("right click: the Skewer (%s)" % p.body_model.current_action(), p.body_model.current_action() == "pole_heavy")
			until = TK.wait_secs(0.75)
		10:
			check("the heavy lands (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			until = TK.wait_secs(0.8)
		11:
			TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		12:
			var w = p.body_model.weapon
			var tip: Vector3 = w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z)
			check("put away, it's slung on the back (%s)" % w.get_parent().name, w.get_parent().name == "BackSocket")
			check("its head up over the shoulder (%.2f m up)" % (tip.y - p.global_position.y), tip.y - p.global_position.y > 1.9)
			check("the grip let go with it", p.body_model.pole_w < 0.01)
			return TK.done(fails)
	step += 1
	return false
