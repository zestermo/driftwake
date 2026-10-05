extends SceneTree
## Out-of-combat start / stop / skid filmstrip: one body runs, then either
## reverses (skid) or lets go (stop), seen from the side. Args: <out_prefix> <skid|stop|start>
var h: Humanoid
var cam: Camera3D
var out := ""
var mode := "skid"
var f := 0
var mv := Vector2(0, 1)
var spd := 9.0


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	mode = a[1] if a.size() > 1 else "skid"
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.42, 0.56, 0.72)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0); root.add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(400, 400); floor.mesh = pm; root.add_child(floor)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.5, 0.45, 0.35); floor.material_override = mat
	h = Humanoid.new(); h.setup(CharacterLook.default_look()); root.add_child(h)
	h.grounded = true
	h.set_process(false)
	if mode == "start":
		spd = 0.0
	cam = Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 40


func _process(_d):
	f += 1
	var dt := 1.0 / 60.0
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# 1 s of the first motion, then the change at frame 61
	if f == 61:
		match mode:
			"skid": mv = Vector2(0, -1)
			"stop": spd = 0.0
			"start": spd = 6.0
	h.ground_speed = spd
	h.local_move = mv
	h.position += Vector3(mv.x, 0, -mv.y) * spd * dt
	h._process(dt)
	cam.look_at_from_position(h.position + Vector3(4.2, 1.2, 0.0), h.position + Vector3(0, 0.8, 0))
	if f >= 58 and f <= 58 + 3 * 9 and (f - 58) % 3 == 0:
		root.get_texture().get_image().save_png("%s_%02d.png" % [out, (f - 58) / 3])
	if f > 58 + 3 * 9:
		print("DONE")
		quit()
	return false
