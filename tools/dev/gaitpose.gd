extends SceneTree
## Armed gait frames for a given local_move. Args: <out_prefix> <mx> <my> [armed 1/0]
var f := 0
var h
var cam: Camera3D
var out := ""
var mv := Vector2(0, 1)
var armed := true
var tt := 0.0
var shots := 0
func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]; mv = Vector2(float(a[1]), float(a[2])).normalized()
	if a.size() > 3: armed = a[3] == "1"
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
		var floor_mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10, 10); floor_mi.mesh = pm; w.add_child(floor_mi)
		h = Humanoid.new(); h.setup(CharacterLook.default_look()); w.add_child(h)
		h.set_weapon(Props.weapon_mesh("cutlass")); h._attach_weapon(true)
		h.armed = armed
		h.grounded = true
		cam = Camera3D.new(); w.add_child(cam); cam.current = true; cam.fov = 40
		cam.global_position = Vector3(-3.2, 1.4, -2.4)
		cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
		return false
	h.ground_speed = 4.8
	h.local_move = mv
	tt += d
	if tt > 1.0 + shots * 0.12:
		get_root().get_texture().get_image().save_png("%s_%d.png" % [out, shots])
		shots += 1
		if shots >= 6: return true
	return false
