extends SceneTree
## Inventory overlay screenshots. Args: <out_prefix>
var t := 0.0
var stage := 0
var out := ""
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	var gm = root.get_node_or_null("GameMenu")
	match stage:
		0:
			if t > 1.5:
				pass
				for n in root.get_children():
					if n is CharacterCreator: n._finish(true)
				var p = root.get_tree().get_first_node_in_group("player")
				# a few extra items to show off
				p.inventory_component.add_item(ItemDB.get_item("boarding_axe"), 1)
				p.inventory_component.add_item(Gear.make("hands", "gloves", {"gloves": true, "gloves_color": CharacterLook.LEATHER[2]}), 1)
				p.inventory_component.add_item(Gear.make("head", "bandana", {"hat": "bandana", "hat_color": CharacterLook.CLOTH[13]}), 1)
				p.inventory_component.add_item(Gear.make("accessory", "pauldron", {"pauldron": true}, "Ruin-Warden's Pauldron"), 1)
				gm.open("inventory")
				stage = 1; t = 0
		1:
			if t > 1.6:
				root.get_texture().get_image().save_png(out + "_inv.png")
				var cam: Camera3D = root.get_viewport().get_camera_3d()
				var rig = cam.get_parent().get_parent()
				var p2 = root.get_tree().get_first_node_in_group("player")
				print("rig show=", rig._show, " len=", rig.spring_arm.spring_length, " hit=", rig.spring_arm.get_hit_length(), " mask=", rig.spring_arm.collision_mask, " h_off=", cam.h_offset, " cam->player=", cam.global_position.distance_to(p2.global_position + Vector3(0, 0.9, 0)), " yaw=", rig.rotation.y, " model=", p2.player_model.global_rotation.y, " fov=", cam.fov, " keep=", cam.keep_aspect, " head_px=", cam.unproject_position(p2.body_model.head.global_position), " feet_px=", cam.unproject_position(p2.global_position), " vp=", root.get_viewport().get_visible_rect().size, " cam_y=", cam.global_position.y - p2.global_position.y, " rig_y=", rig.global_position.y - p2.global_position.y)
				for yy in [0.0, 1.0, 2.0]:
					var wp: Vector3 = p2.global_position + Vector3(0, yy, 0)
					print("  y=", yy, " px=", cam.unproject_position(wp), " depth=", -(cam.global_transform.affine_inverse() * wp).z)
				print("  body scale ", p2.body_model.scale, " lean ", p2.lean.basis.get_scale(), " model ", p2.player_model.scale, " head ", p2.body_model.head.global_position - p2.global_position)
				gm._inventory.show_tab("character")
				stage = 2; t = 0
		2:
			if t > 0.3:
				root.get_texture().get_image().save_png(out + "_char.png")
				print("SAVED"); quit()
	return false
