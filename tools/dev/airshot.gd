extends SceneTree
var f := 0
var hs: Array = []
func _initialize():
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.6, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-30), 0); root.add_child(sun)
	var vys := [6.0, 1.0, -3.0, -8.0]
	for i in range(4):
		var h := Humanoid.new(); h.setup(CharacterLook.base_look()); root.add_child(h)
		h.position = Vector3((i - 1.5) * 1.3, 0.4, 0); h.rotation.y = -PI / 2.0 + 0.3
		h.grounded = false; h.vertical_speed = vys[i]
		hs.append(h)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 40
	cam.look_at_from_position(Vector3(0, 1.3, 6.5), Vector3(0, 1.1, 0))
func _process(_d):
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for h in hs:
			h.set_process(false)
			for k in range(60): h._process(1.0 / 60.0)
	if f == 6:
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); print("SAVED"); quit()
	return false
