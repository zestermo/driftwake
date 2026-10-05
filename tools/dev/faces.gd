extends SceneTree
var f := 0
var models: Array = []
func _initialize():
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.3, 0.4, 0.5)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-25), 0); root.add_child(sun)
	var looks := []
	var a := CharacterLook.default_look(); looks.append(a)
	var b := a.duplicate(); b["hat"] = "none"; looks.append(b)
	var c := a.duplicate(); c["hat"] = "none"; c["facial_hair"] = "none"; c["marks"] = "none"; c["eyes"] = 5; c["body"] = "fem"; c["hair"] = "long"; c["mouth"] = 1; looks.append(c)
	var d := a.duplicate(); d["hat"] = "bandana"; d["facial_hair"] = "beard"; d["eyes"] = 1; d["brows"] = 1; looks.append(d)
	for i in range(looks.size()):
		var h := Humanoid.new(); h.setup(looks[i]); root.add_child(h)
		h.position = Vector3((i - 1.5) * 0.55, 0, 0); h.rotation.y = PI + deg_to_rad(15)
		models.append(h)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 30
	cam.look_at_from_position(Vector3(0, 1.8, 3.2), Vector3(0, 1.8, 0))
func _process(_d):
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for h in models:
			for k in range(30): h._process(1.0 / 60.0)
			h.set_process(false)
	if f == 6:
		root.get_texture().get_image().save_png("res://tools/dev/out/faces.png"); print("SAVED"); quit()
	return false
