extends SceneTree
## The learned air attacks: without the move a style plunges; Twin Cyclone (dual
## swords: several cuts on the way down, a burst on landing that knocks flat),
## Meteor Kick (unarmed: knocks flat, bounces you up, a second kick allowed
## after the bounce), Hang Shot (one pistol: hangs, one heavy shot knocks flat,
## uses a ball), Boarding Dive (cutlass: a point-first dive that lands, a
## backflip off them).
const STAGGER := 9; const DOWN := 11; const DEAD := 14
var t := 0.0
var step := 0
var wait := 0.0
var p
var camp
var g
var fails := 0
var saw := {}
var hp0 := 0.0
var downed := false
var drops := 0
var last_hp := 0.0
var bounced := false
var plunges := 0
var last_state := ""
var y0 := 0.0
var case_i := 0
const CASES := [
	{"name": "Twin Cyclone", "node": "d_cyclone", "items": ["cutlass", "cutlass"], "style": "dual_sword", "anim": "twin_cyclone", "off": 2.2, "up": 2.0},
	{"name": "Meteor Kick", "node": "u_meteor", "items": [], "style": "fist", "anim": "meteor_kick", "off": 3.5, "up": 3.0},
	{"name": "Hang Shot", "node": "g_hangshot", "items": ["pistol"], "style": "pistol", "anim": "hang_shot", "off": 9.0, "up": 2.5},
	{"name": "Boarding Dive", "node": "s_dive", "items": ["cutlass"], "style": "sword", "anim": "boarding_dive", "off": 3.5, "up": 3.0},
]


func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1


func rig():
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	return cam.get_parent().get_parent() as Node3D


func face(target: Vector3) -> void:
	var d: Vector3 = target - p.global_position; d.y = 0
	rig().rotation.y = atan2(-d.x, -d.z)
	p.player_model.rotation.y = atan2(-d.x, -d.z)


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func park(x, at: Vector3) -> void:
	x.humanoid.seated = false
	x.global_position = at + Vector3.UP * 0.3
	x.velocity = Vector3.ZERO
	x.reset_physics_interpolation()


## A fresh grunt at `at`, held reeling; the rest well away.
func target_grunt(at: Vector3) -> void:
	for x in camp.grunts:
		if is_instance_valid(x) and x != g and x.state != DEAD and x.state != DOWN:
			g = x
			break
	var i := 0
	for x in camp.grunts:
		if is_instance_valid(x) and x != g and x.state != DEAD:
			i += 1
			park(x, ground(p.global_position + Vector3(40 + i * 3, 0, 40)))
	park(g, at)
	g._stagger_len = 30.0
	g._set_state(STAGGER)
	g.health.current_health = 400.0
	hp0 = 400.0
	last_hp = 400.0
	drops = 0
	downed = false


func item(id: String):
	return load("res://resources/items/%s.tres" % id)


func arm(c: Dictionary) -> void:
	p.state_machine.force_state("Idle", {})
	p.set_offhand(null)
	p.unequip_weapon()
	var items: Array = c["items"]
	if items.size() > 0:
		p.inventory_component.add_item(item(items[0]), items.size())
		p.equip_weapon(item(items[0]), false)
	if items.size() > 1:
		p.set_offhand(item(items[1]))
	p.draw_weapon(true)
	p._reset_ammo()


func _physics_process(_d: float) -> bool:
	if p:
		saw[p.body_model.current_action()] = true
		if int(p.air_uses.get("bounce", 0)) > 0:
			bounced = true
		var st: String = p.current_state_name()
		if st == "Plunge" and last_state != "Plunge":
			plunges += 1
		last_state = st
	if g and is_instance_valid(g):
		if g.state == DOWN:
			downed = true
		if g.health.current_health < last_hp - 0.5:
			drops += 1
		last_hp = g.health.current_health
	return false


func _process(d: float) -> bool:
	t += d
	if t > 90.0:
		check("timed out at step %d" % step, false)
		print("RESULT FAILED (%d)" % fails)
		quit()
		return true
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.progression.level = 10
			p.global_position = ground(camp.grunts[1].global_position + Vector3(14, 0, 0)) + Vector3.UP * 0.2
			set_meta("home", p.global_position)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			# --- without the move: the plain plunge
			arm(CASES[0])
			check("two cutlasses: dual swords (%s)" % p.style(), p.style() == "dual_sword")
			wait = 0.6
			step = 1
		1:
			face(p.global_position + Vector3(0, 0, -10))
			p.global_position += Vector3.UP * 2.5
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			p.stamina = p.max_stamina
			saw = {}
			wait = 0.12
			step = 2
		2:
			p.input_buffer.buffer_action("light_attack")
			wait = 0.15
			step = 3
		3:
			check("not learned: the plain plunge (%s)" % p.body_model.current_action(), p.body_model.current_action() == "plunge_air")
			wait = 1.2
			step = 10
		# --- each learned move in turn
		10:
			var c: Dictionary = CASES[case_i]
			p.state_machine.force_state("Idle", {})
			p.global_position = get_meta("home")
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			arm(c)
			p.progression._own(c["node"])
			check("%s: style %s" % [c["name"], p.style()], p.style() == c["style"])
			wait = 0.6
			step = 11
		11:
			var c: Dictionary = CASES[case_i]
			face(p.global_position + Vector3(0, 0, -10))
			p.global_position += Vector3.UP * float(c["up"])
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			target_grunt(ground(p.global_position + Vector3(0, 0, -float(c["off"]))))
			p.stamina = p.max_stamina
			saw = {}
			bounced = false
			plunges = 0
			y0 = p.global_position.y
			wait = 0.12
			step = 12
		12:
			if CASES[case_i]["anim"] == "hang_shot":
				# (the reticle on the grunt, as you'd aim it)
				var arm: Node3D = root.get_viewport().get_camera_3d().get_parent()
				var to: Vector3 = g.hurtbox.global_position - arm.global_position
				arm.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
			p.input_buffer.buffer_action("light_attack")
			wait = 0.15
			step = 13
		13:
			var c: Dictionary = CASES[case_i]
			check("%s: played (%s / %s)" % [c["name"], p.current_state_name(), p.body_model.current_action()],
				p.current_state_name() == "Plunge" and p.body_model.current_action() == c["anim"])
			if c["anim"] == "hang_shot":
				check("...hanging, not falling (%.2f m dropped)" % (y0 - p.global_position.y), y0 - p.global_position.y < 0.6)
			wait = 0.5 if c["anim"] == "meteor_kick" else 1.3
			step = 14
		14:
			var c: Dictionary = CASES[case_i]
			match c["anim"]:
				"twin_cyclone":
					check("...cuts on the way down and a burst on landing (%d hits, %.0f -> %.0f)" % [drops, hp0, g.health.current_health], drops >= 2)
					check("...the landing burst knocks them flat", downed)
				"meteor_kick":
					check("...kicks them flat (%.0f -> %.0f)" % [hp0, g.health.current_health], downed and g.health.current_health < hp0)
					check("...and bounces you back up (%s)" % str(saw.keys()), bounced and saw.has("vault_back"))
					# another kick off the bounce
					p.input_buffer.buffer_action("light_attack")
					wait = 0.2
					step = 15
					return false
				"hang_shot":
					check("...one heavy shot knocks them flat (%.0f -> %.0f)" % [hp0, g.health.current_health], downed and g.health.current_health < hp0)
					check("...using a ball (%s)" % str(p.ammo), p.ammo[0] < p.max_ammo() or p.reloading())
				"boarding_dive":
					check("...the point lands (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
					check("...and you flip back off them (%s)" % str(saw.keys()), saw.has("vault_back"))
			step = 16
		15:
			check("...a second kick off the bounce (%d air attacks)" % plunges, plunges >= 2)
			wait = 1.2
			step = 16
		16:
			case_i += 1
			if case_i < CASES.size():
				wait = 1.0
				step = 10
				return false
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
			return true
	return false
