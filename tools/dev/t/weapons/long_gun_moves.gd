extends SceneTree
## A long gun's other moves on a dummy close in front: right click drives the butt into it (a guard-breaking blow); a
## blunderbuss's load scatters, its pellets landing as one heavy blow that knocks down point-blank; the double fowler
## holds two loads; learned, Stock Rush at a sprint and Sky Shot in the air land too.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var taken := 0.0
var last
var aims := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.4), "weapon": "musket"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func equip(id: String) -> void:
	var it = ItemDB.get_item(id)
	p.inventory_component.add_item(it, 1)
	p.equip_weapon(it)
	p.draw_weapon(true)
	p._reset_ammo()


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
			stage.camera_rig.rotation.y = 0.12
			stage.camera_rig.get_node("SpringArm3D").rotation.x = -0.12
			until = TK.wait_secs(0.7)
		1:
			hits = 0
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		2:
			check("right click: the butt stroke (%s)" % p.body_model.current_action(), p.current_state_name() == "HeavyAttack" and p.body_model.current_action() == "lg_butt")
			until = TK.wait_secs(0.6)
		3:
			check("the stock lands, through a guard (%d)" % hits, hits >= 1 and last.breaker and not last.ranged)
			until = TK.wait_secs(0.8)
		4:
			equip("blunderbuss")
			hits = 0
			taken = 0.0
			until = TK.wait_secs(0.6)
		5:
			check("a blunderbuss is a long gun too (%s)" % p.style(), p.style() == "long_gun")
			TK.act("light_attack")
			until = TK.wait_secs(0.5)
		6:
			var pellet: float = load("res://scripts/weapons/long_gun_arts.gd").PELLET
			check("its load scatters: one blow for all the pellets that found it (%d, %.0f)" % [hits, taken], hits == 1 and taken > pellet * 2.5)
			check("most of a load point-blank knocks down", last.knockdown and last.ranged)
			until = TK.wait_secs(2.2)
		7:
			equip("fowling_piece")
			until = TK.wait_secs(0.5)
		8:
			check("the double fowler holds two loads (%d)" % p.ammo[0], p.max_ammo() == 2 and p.ammo[0] == 2)
			TK.act("light_attack")
			until = TK.wait_secs(0.8)
		9:
			check("one fired, one still in it (%d)" % p.ammo[0], p.ammo[0] == 1 and not p.reloading())
			p.progression.master_all()
			p._reset_ammo()
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 6.0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.4)
		10:
			hits = 0
			p.sprinting = true
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		11:
			var st = p.state_machine.current_state
			check("at a sprint: Stock Rush (%s)" % p.body_model.current_action(), p.body_model.current_action() == "lg_rush" and str(st.get("mode")) == "rush")
			until = TK.wait_secs(0.8)
		12:
			check("it drives into them and knocks them down (%d)" % hits, hits >= 1 and last.knockdown)
			until = TK.wait_secs(1.0)
		13:
			if not p.is_free():
				return false
			p._reset_ammo()
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5, 4.0)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			stage.camera_rig.rotation.y = 0.1
			stage.camera_rig.get_node("SpringArm3D").rotation.x = -0.45
			until = TK.wait_ticks(2)
		14:
			# (held up there while the reticle is laid on the dummy below, as a player aims)
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5, 4.0)
			p.velocity = Vector3.ZERO
			var ray: Array = p.reticle_ray()
			var r: Vector3 = ray[1]
			var d: Vector3 = (stage.dummy.get_node("Hurtbox").get_child(0).global_position - (ray[0] as Vector3)).normalized()
			stage.camera_rig.rotation.y += atan2(-d.x, -d.z) - atan2(-r.x, -r.z)
			stage.camera_rig.get_node("SpringArm3D").rotation.x += asin(d.y) - asin(r.y)
			aims += 1
			if aims < 12:
				until = TK.wait_ticks(1)
				return false
			hits = 0
			p.state_machine.force_state("Plunge", {})
			until = TK.wait_ticks(4)
		15:
			check("in the air: Sky Shot (%s, %s)" % [p.current_state_name(), p.body_model.current_action()], p.current_state_name() == "Plunge" and p.body_model.current_action() == "lg_air")
			until = TK.wait_secs(0.7)
		16:
			check("a steady shot down into them (%d)" % hits, hits >= 1 and last.ranged and last.knockdown)
			return TK.done(fails)
	step += 1
	return false
