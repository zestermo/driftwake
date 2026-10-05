extends SceneTree
## Treadmill gait viewer: three bodies at walk (1.3), jog (6) and sprint (12)
## seen from the side (or 3/4). Saves frames. Args: <outdir> <view: side|three>
var models: Array = []
var f := 0
var out := ""
var view := "side"
const SPEEDS := [1.3, 6.0, 9.0]
func _initialize():
	var a := OS.get_cmdline_user_args(); out = a[0]; view = a[1] if a.size() > 1 else "side"
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.42, 0.56, 0.72)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0); root.add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); floor.mesh = pm; root.add_child(floor)
	var looks := [CharacterLook.default_look(), CharacterLook.base_look(), CharacterLook.base_look()]
	looks[1]["body"] = "fem"; looks[1]["hair"] = "ponytail"
	looks[2]["hair"] = "wild"; looks[2]["top"] = "bare"
	for i in range(3):
		var h := Humanoid.new(); h.setup(looks[i]); root.add_child(h)
		h.position = Vector3((i - 1) * 1.6, 0, 0)
		h.rotation.y = -PI / 2.0 if view == "side" else -PI / 2.0 + 0.6
		h.ground_speed = SPEEDS[i]
		# the player's Lean node tilts the whole body with speed (0.28 rad at sprint)
		h.rotate_object_local(Vector3.RIGHT, -SPEEDS[i] / 12.0 * 0.28 if i > 0 else 0.0)
		models.append(h)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 34
	cam.look_at_from_position(Vector3(0, 1.1, 6.4), Vector3(0, 0.95, 0))
func _process(_d):
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for h in models:
			h.set_process(false)
			for k in range(90): h._process(1.0 / 60.0)
	if f >= 4:
		for h in models: h._process(1.0 / 30.0)
		root.get_texture().get_image().save_png("%s/f%03d.png" % [out, f - 4])
	if f >= 4 + 60:
		print("DONE"); quit()
	return false
