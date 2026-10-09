extends SceneTree
## Axe moveset: its own style; the three-hit combo (hack, hook, splitter - the
## splitter knocks flat); the whirlwind heavy (hits all round, the second turn
## knocks flat); Skybreaker, the jump attack (somersault, dive, the ground split
## in a line ahead knocking flat whoever's along it).
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
## The grunt `off` metres along the player's facing (negative: behind), the rest well away.
func target_grunt(off: float) -> void:
	# (a fresh one each time: one that's been knocked flat is still getting up)
	for x in camp.grunts:
		if is_instance_valid(x) and x != g and x.state != DEAD and x.state != DOWN:
			g = x
			break
	var i := 0
	for x in camp.grunts:
		if is_instance_valid(x) and x != g and x.state != DEAD:
			i += 1
			park(x, ground(p.global_position + Vector3(40 + i * 3, 0, 40)))
	park(g, ground(p.global_position - p.player_model.global_basis.z * off))
	g._stagger_len = 30.0
	g._set_state(STAGGER)
	g.health.current_health = 400.0
	hp0 = 400.0
	downed = false
func attack(action: String) -> void:
	p.input_buffer.buffer_action(action)
func _physics_process(_d: float) -> bool:
	if p:
		saw[p.body_model.current_action()] = true
	if g and is_instance_valid(g) and g.state == DOWN:
		downed = true
	return false
func _process(d: float) -> bool:
	t += d
	if t > 60.0:
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
			# moveset unlocks: Skybreaker (axe tree), Running Cut (cutlass tree)
			for nid in ["a_sky", "s_dash"]:
				p.progression._own(nid)
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.global_position = ground(camp.grunts[1].global_position + Vector3(12, 0, 0)) + Vector3.UP * 0.2
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			var axe = load("res://resources/items/boarding_axe.tres")
			p.inventory_component.add_item(axe, 1)
			p.equip_weapon(axe, false)
			check("the axe is its own style (%s)" % p.style(), p.style() == "axe")
			p.draw_weapon()
			g = camp.grunts[1]
			wait = 0.8
			step += 1
		1:
			face(p.global_position + Vector3(0, 0, -10))
			target_grunt(1.6)
			saw = {}
			attack("light_attack")
			wait = 0.7
			step += 1
		2:
			attack("light_attack")
			wait = 0.7
			step += 1
		3:
			check("hacks land (%.0f -> %.0f) without putting them down" % [hp0, g.health.current_health], g.health.current_health < hp0 and not downed)
			attack("light_attack")
			wait = 1.1
			step += 1
		4:
			check("the combo: hack, hook, splitter (%s)" % str(saw.keys()), saw.has("axe_hack") and saw.has("axe_hook") and saw.has("axe_split"))
			check("...the splitter knocks them flat", downed)
			p.state_machine.force_state("Idle", {})
			wait = 1.0
			step += 1
		5:
			# the whirlwind, with the grunt behind you
			face(p.global_position + Vector3(0, 0, -10))
			target_grunt(-1.6)
			p.stamina = p.max_stamina
			saw = {}
			attack("heavy_attack")
			wait = 0.5
			step += 1
		6:
			check("right click: the whirlwind (%s / %s)" % [p.current_state_name(), p.body_model.current_action()], p.body_model.current_action() == "axe_whirl")
			check("...the first turn catches someone behind you (%.0f -> %.0f), standing" % [hp0, g.health.current_health], g.health.current_health < hp0 and not downed)
			hp0 = g.health.current_health
			wait = 0.6
			step += 1
		7:
			check("...the second turn hits again (%.0f -> %.0f) and knocks them flat" % [hp0, g.health.current_health], g.health.current_health < hp0 and downed)
			p.state_machine.force_state("Idle", {})
			wait = 1.0
			step += 1
		8:
			# Skybreaker: from the air, the grunt 3.5 m ahead along the line
			face(p.global_position + Vector3(0, 0, -10))
			target_grunt(3.6)
			p.global_position += Vector3.UP * 2.5
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			p.stamina = p.max_stamina
			saw = {}
			wait = 0.12
			step += 1
		9:
			attack("light_attack")
			wait = 0.15
			step += 1
		10:
			check("jump attack: Skybreaker's somersault (%s / %s)" % [p.current_state_name(), p.body_model.current_action()], p.current_state_name() == "Plunge" and p.body_model.current_action() == "axe_flip")
			wait = 1.2
			step += 1
		11:
			check("...comes down and splits the ground (%s seen)" % str(saw.keys()), saw.has("axe_land"))
			check("...and the split runs out to the grunt ahead (%.0f -> %.0f), knocked flat" % [hp0, g.health.current_health], g.health.current_health < hp0 and downed)
			# --- the cutlass: its combo lands, and a sprint attack is the running cut
			var cutlass = load("res://resources/items/cutlass.tres")
			p.inventory_component.add_item(cutlass, 1)
			p.state_machine.force_state("Idle", {})
			p.equip_weapon(cutlass)
			p.set_offhand(null)
			check("one cutlass: the sword style (%s)" % p.style(), p.style() == "sword")
			face(p.global_position + Vector3(0, 0, -10))
			target_grunt(1.6)
			saw = {}
			attack("light_attack")
			wait = 0.75
			step += 1
		12:
			attack("light_attack")
			wait = 0.75
			step += 1
		13:
			attack("light_attack")
			wait = 0.8
			step += 1
		14:
			check("cutlass combo: forehand, backhand, spin (%s)" % str(saw.keys()), saw.has("slash_r") and saw.has("slash_l") and saw.has("slash_spin"))
			check("...its cuts land (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			check("the cutlass guards side on, blade angled forward", p.body_model._guard().get("hand_r", Vector3.ZERO).x < -0.3)
			p.state_machine.force_state("Idle", {})
			face(p.global_position + Vector3(0, 0, -10))
			target_grunt(3.0)
			p.stamina = p.max_stamina
			p.sprinting = true
			saw = {}
			attack("light_attack")
			wait = 0.6
			step += 1
		15:
			check("attacking at a sprint: the running cut (%s)" % str(saw.keys()), saw.has("dash_cut"))
			check("...drives through and cuts (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
