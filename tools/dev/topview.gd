extends SceneTree
## High-angle and close views of a few looks to find holes. Args: <out.png> <cam: top|front|side>
var f := 0
var models: Array = []
var mode := "top"
var out := ""
func _initialize():
	var a := OS.get_cmdline_user_args(); out = a[0]; mode = a[1]
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(1.0, 0.0, 1.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-25), 0); root.add_child(sun)
	var looks := []
	var a1 := CharacterLook.default_look(); a1["hat"] = "none"; looks.append(a1)
	var b := CharacterLook.base_look(); b["sleeves"] = "none"; b["legs"] = "shorts"; looks.append(b)
	var c := CharacterLook.base_look(); c["body"] = "fem"; c["hair"] = "long"; looks.append(c)
	var d := CharacterLook.base_look(); d["top"] = "bare"; d["hair"] = "wild"; looks.append(d)
	for i in range(looks.size()):
		looks[i]["style"] = "shonen"
		var h := Humanoid.new(); h.setup(looks[i]); root.add_child(h)
		h.position = Vector3((i - 1.5) * 0.9, 0, 0); h.rotation.y = PI + 0.35
		models.append(h)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 40
	match mode:
		"top": cam.look_at_from_position(Vector3(0, 4.2, 2.6), Vector3(0, 1.2, 0))
		"front": cam.look_at_from_position(Vector3(0, 1.0, 4.4), Vector3(0, 1.0, 0))
		"low": cam.look_at_from_position(Vector3(0, 0.3, 3.4), Vector3(0, 1.0, 0))
		"face": cam.fov = 26; cam.look_at_from_position(Vector3(0, 1.75, 3.6), Vector3(0, 1.58, 0))
		"back": cam.fov = 26; cam.look_at_from_position(Vector3(0, 2.2, -3.4), Vector3(0, 1.5, 0))
		"crown": cam.fov = 26; cam.look_at_from_position(Vector3(0, 3.6, 1.6), Vector3(0, 1.55, 0))
func _process(_d):
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for h in models:
			for k in range(30): h._process(1.0 / 60.0)
			h.set_process(false)
	if f == 6:
		root.get_texture().get_image().save_png(out); print("SAVED"); quit()
	return false
