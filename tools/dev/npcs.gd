extends SceneTree
var t := 0.0
var step := 0
var f := 0
var models: Array = []
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if step == 0 and t > 1.5:
		var looks := []
		var names := []
		for n in root.find_children("*", "Humanoid", true, false):
			var par = n.get_parent()
			if par and "humanoid" in par and par.humanoid == n:
				looks.append(n.look.duplicate(true)); names.append(str(par.get("npc_name")) if par.get("npc_name") else par.name)
		current_scene.queue_free()
		paused = false
		var studio := Node3D.new(); root.add_child(studio)
		var env := WorldEnvironment.new(); var e := Environment.new()
		e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.6, 0.75)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.75
		env.environment = e; studio.add_child(env)
		var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-25), 0); sun.shadow_enabled = true; studio.add_child(sun)
		var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 20); ground.mesh = pm; studio.add_child(ground)
		for i in range(looks.size()):
			var h := Humanoid.new(); h.setup(looks[i]); studio.add_child(h)
			h.position = Vector3((i - (looks.size() - 1) * 0.5) * 1.0, 0, 0); h.rotation.y = deg_to_rad(160)
			models.append(h)
			var l := Label3D.new(); l.text = names[i]; l.pixel_size = 0.0025; l.position = h.position + Vector3(0, 2.25, 0); studio.add_child(l)
		var cam := Camera3D.new(); studio.add_child(cam); cam.current = true; cam.fov = 40
		cam.look_at_from_position(Vector3(0, 1.5, 7.2), Vector3(0, 1.0, 0))
		print("npcs: ", names)
		step = 1
		return false
	if step == 1:
		f += 1
		if f == 2:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for h in models:
				for k in range(30): h._process(1.0 / 60.0)
				h.set_process(false)
		if f == 6:
			root.get_texture().get_image().save_png("res://tools/dev/out/npcs.png"); print("SAVED"); quit()
	return false
