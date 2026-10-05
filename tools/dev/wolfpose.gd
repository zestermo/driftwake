extends SceneTree
## Standalone Zoan hybrid: front, 3/4 and side views. Args: <out_prefix>
var f := 0
var h
var cam: Camera3D
var out := ""
var views := [Vector3(0, 1.6, -2.4), Vector3(-1.8, 1.6, -1.6), Vector3(-2.4, 1.5, 0.2), Vector3(0.6, 1.6, 2.4)]
var i := 0
var tt := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
func _process(d: float) -> bool:
	f += 1
	tt += d
	if f == 1:
		var w := Node3D.new(); get_root().add_child(w)
		var env := WorldEnvironment.new(); env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.55, 0.7, 0.85)
		env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		w.add_child(env)
		var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-0.9, 0.6, 0); w.add_child(sun)
		var lk := CharacterLook.default_look()
		var fur := Color(0.55, 0.5, 0.44)
		lk["skin"] = fur; lk["hair"] = "wild"; lk["hair_color"] = fur.darkened(0.25); lk["facial_hair"] = "beard"
		lk["eye_color"] = Color(0.95, 0.75, 0.2); lk["hat"] = "none"; lk["height"] = 1.1; lk["build"] = "broad"
		h = Humanoid.new(); h.setup(lk); w.add_child(h)
		h.set_beast(true, fur)
		h.stance = "claw"
		h.armed = true
		cam = Camera3D.new(); w.add_child(cam); cam.current = true; cam.fov = 40
		return false
	if tt < 0.8 + i * 0.4:
		return false
	if i >= views.size():
		return true
	cam.global_position = views[i]
	cam.look_at(Vector3(0, 1.3, 0), Vector3.UP)
	if tt > 1.0 + i * 0.4:
		get_root().get_texture().get_image().save_png("%s_%d.png" % [out, i])
		i += 1
	return false
