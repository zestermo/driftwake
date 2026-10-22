extends SceneTree
## The fists' Power branch: Cannonball Fist launches the grunt in front down the line into the dummy behind him;
## Meteor Fist on the ground hops, drives the overhand down (fs_meteor -> fs_meteor_land) and its shockwave hits the
## dummy beside you; cast in the air it dives, and from ~45 m it hits harder than from 5 m (the height fallen).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var grunt
var taken := 0.0
var hp_g := 0.0
var low := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -6.5),
		"grunts": [{"post": Vector3(0, 0, -2.2), "yaw": 0.0, "mode": "stand", "seed": 21}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cast(id: String) -> bool:
	p.power.equip(id, 0)
	p.power.cooldowns.clear()
	p.power.energy = p.power.max_energy()
	return p.power.try_cast(0)


func place(at: Vector3) -> void:
	p.global_position = at
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	p.player_model.rotation.y = 0.0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			for k in ["u_cannon", "u_meteor_fist"]:
				p.progression.owned[k] = true
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			grunt = stage.camp.grunts[0] if stage.camp else null
			check("a grunt", grunt != null)
			if grunt == null:
				return TK.done(fails)
			until = TK.wait_secs(0.8)
		1:
			place(Vector3(0, p.global_position.y, 0))
			hp_g = grunt.health.current_health
			taken = 0.0
			check("Cannonball Fist cast", cast("cannonball_fist"))
			until = TK.wait_ticks(4)
		2:
			check("the planted straight (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_cannon")
			until = TK.wait_secs(1.0)
		3:
			check("the grunt it meets is hit (%.0f -> %.0f)" % [hp_g, grunt.health.current_health], grunt.health.current_health < hp_g)
			check("...and launched down the line into the dummy behind him (%.0f)" % taken, taken > 0.0)
			until = TK.wait_secs(0.6)
		4:
			if not p.is_free():
				return false
			# (the grunt out of the way: the rest is on the dummy)
			grunt.global_position = Vector3(30, grunt.global_position.y, 30)
			place(stage.dummy.global_position + Vector3(0, 0.05, 1.8))
			taken = 0.0
			check("Meteor Fist cast", cast("meteor_fist"))
			until = TK.wait_ticks(4)
		5:
			check("the hop and overhand (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_meteor")
			until = TK.wait_secs(1.0)
		6:
			check("it comes down into the ground (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_meteor_land" or taken > 0.0)
			check("the shockwave hits the dummy (%.0f)" % taken, taken > 0.0)
			until = TK.wait_secs(0.6)
		7:
			if not p.is_free():
				return false
			place(stage.dummy.global_position + Vector3(0, 5.0, 1.2))
			until = TK.wait_ticks(2)
		8:
			taken = 0.0
			check("cast in the air from 5 m (%s)" % ("in the air" if not p.is_on_floor() else "on the floor"), cast("meteor_fist") and not p.is_on_floor())
			until = TK.wait_secs(1.6)
		9:
			low = taken
			check("the dive lands (%.0f)" % low, low > 0.0)
			until = TK.wait_secs(0.6)
		10:
			if not p.is_free():
				return false
			place(stage.dummy.global_position + Vector3(0, 45.0, 1.2))
			until = TK.wait_ticks(2)
		11:
			taken = 0.0
			check("cast in the air from 45 m", cast("meteor_fist"))
			until = TK.wait_secs(3.0)
		12:
			check("from 45 m it hits harder than from 5 m (%.0f vs %.0f)" % [taken, low], taken > low * 1.3)
			return TK.done(fails)
	step += 1
	return false
