extends SceneTree
## Co-op renders: a crewmate's puppet (nameplate, crew list), knocked out
## with the revive prompt. Args: <out_prefix>
var t := 0.0
var step := 0
var wait := 0.0
var p
var net
var out := ""
var pup
var pup_pos := Vector3.ZERO
var pup_state := "Idle"
var pup_flags := 4
var pup_hp := 140.0
var pup_yaw := 0.0
var pup_armed := false
var shot_cam: Camera3D


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func cam() -> Camera3D:
	return root.get_node("World/CameraRig/SpringArm3D/Camera3D") as Camera3D


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)


func feed() -> void:
	if pup == null:
		return
	var hum: Array = load("res://scripts/net/humanoid_sync.gd").pack(pup.body_model)
	hum[0] = 0.0
	hum[4] = pup_armed
	hum[6] = "sword"
	var n: int = hum.size() - 4
	hum[n] = "cutlass"
	hum[n + 2] = pup_armed
	var snap := [pup_pos, false, Vector3.ZERO, pup_yaw, Basis(), pup_state, pup_hp, 160.0, pup_flags, hum, Vector3.INF]
	net._push("P2", net.time() - 0.05, snap)
	net._push("P2", net.time(), snap)


func _process(d: float) -> bool:
	t += d
	feed()
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0:
				return false
			for n in root.find_children("*", "CharacterCreator", true, false):
				n._finish(true)
			p = get_first_node_in_group("player")
			net = root.get_node("Net")
			net.my_info = {"name": "Captain"}
			net.host_game(24999)
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			var lk: Dictionary = load("res://scripts/npc/character_look.gd").random_look(rng)
			lk["name"] = "Mara"
			lk["hat"] = "tricorn"
			net.roster[2] = {"name": "Mara", "look": lk}
			net._spawn_puppet(2, {"name": "Mara", "look": lk})
			pup = net.players[2]
			# a quiet spot on the beach by the village
			var spot: Vector3 = ground(p.global_position + Vector3(6, 0, 4))
			p.global_position = spot + Vector3.UP * 0.2
			p.reset_physics_interpolation()
			pup_pos = ground(spot + Vector3(1.6, 0, -0.6))
			var rig = cam().get_parent().get_parent()
			rig.rotation.y = deg_to_rad(200)
			p.player_model.rotation.y = deg_to_rad(200)
			pup_yaw = deg_to_rad(215)
			wait = 2.5
			step += 1
		1:
			shot("crewmate")
			# draw swords together
			p.draw_weapon()
			pup_armed = true
			wait = 1.0
			step += 1
		2:
			shot("crew_armed")
			# Mara is knocked out; we kneel in to help
			pup_state = "Downed"
			pup_flags = 2 | 4
			pup_hp = 0.0
			pup.body_model.start_ragdoll(Vector3(1.5, 2.0, 0.5), Vector3.ZERO, false)
			p.sheathe_weapon(true)
			wait = 2.0
			step += 1
		3:
			p.global_position = pup_pos + Vector3(-1.0, 0.3, 0.6)
			p.reset_physics_interpolation()
			Input.action_press("interact")
			wait = 1.3
			step += 1
		4:
			shot("revive")
			Input.action_release("interact")
			net.leave()
			quit()
	return false
