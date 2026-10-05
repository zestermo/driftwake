extends SceneTree
## Round 7 renders: loot window, pickup feed, wolf stance + claw rake.
## Args: <out_prefix>
var t := 0.0
var step := 0
var wait := 0.0
var p
var out := ""
var shot_cam: Camera3D
var r2: Node3D
var side := Vector3(-2.4, 0.6, -2.4)
var look_off := Vector3(0, 0.9, 0)
var follow := false


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func cam() -> Camera3D:
	return root.get_node("World/CameraRig/SpringArm3D/Camera3D") as Camera3D


func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)


func _process(d: float) -> bool:
	t += d
	if p and shot_cam and follow:
		var b: Basis = p.player_model.global_basis
		var foc: Vector3 = p.global_position + look_off
		shot_cam.global_position = foc + b * side
		shot_cam.look_at(foc, Vector3.UP)
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
			var rig = cam().get_parent().get_parent()
			rig.rotation.y = deg_to_rad(200)
			p.player_model.rotation.y = deg_to_rad(200)
			wait = 1.5
			step += 1
		1:
			# pickups stream into the corner
			for e in [["gold", 3], ["treasure", 1], ["rum", 2], ["pistol", 1]]:
				p.inventory_component.add_item(load("res://resources/items/%s.tres" % e[0]), e[1])
			wait = 0.5
			step += 1
		2:
			shot("feed")
			# a chest
			var bag = (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate()
			var items: Array[ItemStack] = []
			for e in [["gold", 12], ["treasure", 3], ["rum", 2], ["vine_fruit", 1], ["cutlass", 1]]:
				var st := ItemStack.new()
				st.item = load("res://resources/items/%s.tres" % e[0])
				st.quantity = e[1]
				items.append(st)
			bag.setup(items, false)
			bag.save_id = "shot_chest"
			current_scene.add_child(bag)
			bag.global_position = p.global_position + Vector3(1.2, 0, 0)
			root.get_node("GameMenu").open_container(bag)
			wait = 1.2
			step += 1
		3:
			shot("loot_window")
			root.get_node("GameMenu").close()
			# the wolf
			p.set_hybrid(true)
			r2 = Node3D.new()
			root.add_child(r2)
			shot_cam = Camera3D.new()
			shot_cam.fov = 50
			r2.add_child(shot_cam)
			shot_cam.current = true
			follow = true
			wait = 1.2
			step += 1
		4:
			shot("wolf_stance")
			side = Vector3(-3.0, 0.4, 0.2)
			wait = 0.4
			step += 1
		5:
			shot("wolf_side")
			side = Vector3(-2.6, 0.7, -2.0)
			p.state_machine.force_state("LightAttack", {})
			wait = 0.13
			step += 1
		6:
			shot("wolf_rake")
			quit()
	return false
