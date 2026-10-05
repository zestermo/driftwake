extends SceneTree
var t := 0.0
var step := 0
var p
var fr := 0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	fr += 1
	if step == 0 and t > 1.5:
		p = root.get_tree().get_first_node_in_group("player")
		var isl = root.get_node("World/Islands/Brinehollow")
		var v = isl.VILLAGE + Vector2(0, 6)
		p.global_position = Vector3(150 + v.x, isl.hv(v) + 0.3, 150 + v.y)
		p.reset_physics_interpolation()
		step = 1; t = 0
		for pth in OS.get_environment("HIDE").split(",", false):
			var nd = root.get_node_or_null(pth)
			if nd: nd.visible = false
			else: print("no node ", pth)
	elif step == 1 and t > 0.5:
		var fx = root.get_node("FX")
		fx.slash(p.player_model, "right", 3.0)
		fx.dust_ring(p.global_position, 14, 0.7)
		fx.sparkle(p.global_position + Vector3(0, 2, 0), 12)
		step = 2; t = 0; fr = 0
		print("player_model scale ", p.player_model.global_basis.get_scale(), " vis ", p.player_model.is_visible_in_tree())
	elif step == 2:
		print("frame ", fr, " dt ", d)
		if fr >= 1:
			for c in p.player_model.get_children():
				if c is MeshInstance3D: print("trail ", c.get_instance_shader_parameter("progress"), " ", c.global_position, " layers ", c.layers)
			for c in root.get_tree().current_scene.get_children():
				if c is CPUParticles3D: print("parts ", c.global_position, " emit ", c.emitting, " vis ", c.is_visible_in_tree(), " mode ", c.process_mode, " amt ", c.amount, " ", c.mesh.material.albedo_texture)
			print("world process_mode ", root.get_tree().current_scene.process_mode, " paused ", root.get_tree().paused, " cam ", root.get_viewport().get_camera_3d().global_position)
			root.get_texture().get_image().save_png("res://tools/dev/out/fxdbg_%s.png" % OS.get_environment("TAG")); print("SAVED"); quit()
	return false
