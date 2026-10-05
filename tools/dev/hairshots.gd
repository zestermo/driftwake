extends SceneTree
## Close head shots of every hair style. Args: <out.png> <yaw_deg>
var f := 0
var out := ""
var models: Array = []
func _initialize():
	var a := OS.get_cmdline_user_args(); out = a[0]; var yaw := deg_to_rad(float(a[1]) if a.size() > 1 else 25.0); var set_i := int(a[2]) if a.size() > 2 else 0
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.6, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-30), 0); root.add_child(sun)
	var styles := ["short", "crop", "wild", "long", "ponytail", "bun", "braids", "short"]
	var fem := [false, false, false, true, true, true, true, false]
	for i in range(set_i * 4, set_i * 4 + 4):
		var lk := CharacterLook.base_look()
		lk["hair"] = styles[i]
		if fem[i]: lk["body"] = "fem"
		if i == 7: lk["hat"] = "tricorn"
		lk["hair_color"] = [Color(0.3, 0.18, 0.1), Color(0.1, 0.08, 0.07), Color(0.15, 0.2, 0.55), Color(0.55, 0.3, 0.12), Color(0.85, 0.7, 0.35), Color(0.6, 0.1, 0.1), Color(0.1, 0.08, 0.07), Color(0.3, 0.18, 0.1)][i]
		var h := Humanoid.new(); h.setup(lk); root.add_child(h)
		h.position = Vector3((i % 4 - 1.5) * 0.44, 0, 0)
		h.rotation.y = PI + yaw
		models.append(h)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0
	cam.look_at_from_position(Vector3(0, 1.45, 5.0), Vector3(0, 1.45, 0))
func _process(_d):
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for h in models:
			h.set_process(false)
			for k in range(20): h._process(1.0 / 60.0)
			h.head.rotation = Vector3.ZERO; h.neck.rotation = Vector3.ZERO
	if f == 6:
		root.get_texture().get_image().save_png(out); print("SAVED"); quit()
	return false
