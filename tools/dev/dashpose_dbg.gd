extends SceneTree
## Standalone dash poses (armed): forward, left, right, back.
var f := 0
var h
var cam: Camera3D
var dirs := [Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]
var names := ["fwd", "left", "right", "back"]
var i := 0
var out := ""
var tt := 0.0
var t_play := -1.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
func _process(d: float) -> bool:
	f += 1
	if f == 1:
		var w := Node3D.new(); get_root().add_child(w)
		var env := WorldEnvironment.new(); env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.55, 0.7, 0.85)
		env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		w.add_child(env)
		var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-0.9, 0.6, 0); w.add_child(sun)
		h = Humanoid.new(); h.setup(CharacterLook.default_look()); w.add_child(h)
		h.set_weapon(Props.weapon_mesh("cutlass")); h._attach_weapon(true)
		h.armed = true
		cam = Camera3D.new(); w.add_child(cam); cam.current = true; cam.fov = 40
		return false
	if f == 3:
		cam.global_position = Vector3(-2.2, 1.6, -3.2)
		cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	tt += d
	if f > 3 and t_play < 0.0:
		if i >= dirs.size(): return true
		h.dash_dir = dirs[i]
		h.play("dash", 1.2)
		t_play = tt
	if t_play >= 0.0 and tt - t_play > 0.3:
		t_play = -1.0
		# view from the front-left (the off hand side), slightly above
		cam.global_position = Vector3(-2.2, 1.6, -3.2)
		cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
		print(names[i], " arm_l ", h.arm_l.rotation, " fore_l ", h.fore_l.rotation, " act ", h.current_action(), " armed ", h.armed)
		i += 1
	return false
