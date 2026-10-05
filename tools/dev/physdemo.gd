extends SceneTree
## Physics demo: three characters run, stop, idle, jump. Saves frames for a GIF.
## Args: <style> <outdir>
var models: Array = []
var t := 0.0
var frame := 0
var style := "shonen"
var outdir := ""
var cam: Camera3D
var x := 0.0
var vy := 0.0
var y := 0.0
var started := false
func _initialize():
	var a := OS.get_cmdline_user_args(); style = a[0]; outdir = a[1]
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.42, 0.58, 0.74)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-42), deg_to_rad(-25), 0); root.add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 20); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.55, 0.5, 0.42); pm.material = gm; root.add_child(ground)
	# posts for a sense of motion
	for i in range(-10, 30):
		var post := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.12, 0.6, 0.12); post.mesh = bm
		post.position = Vector3(i * 2.0, 0.3, -2.2); root.add_child(post)
	var looks := []
	var sk = load("res://tools/dev/mockup.gd")
	var all: Array = sk.cast()
	looks = [all[1], all[3], all[0]]
	for i in range(looks.size()):
		looks[i]["style"] = style
		var h := Humanoid.new(); h.setup(looks[i]); root.add_child(h)
		h.set_process(false)
		h.rotation.y = -PI / 2.0
		models.append(h)
	cam = Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 44
func _process(_d):
	if not started:
		started = true
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		return false
	if frame > 0:
		root.get_texture().get_image().save_png("%s/f%03d.png" % [outdir, frame - 1])
	if frame >= 96:
		print("DONE"); quit(); return false
	# advance 2 sim steps per captured frame (30 fps)
	for k in range(2):
		var dt := 1.0 / 60.0
		t += dt
		var spd := 0.0
		if t < 1.3: spd = 5.5
		elif t < 1.4: spd = 2.0
		x += spd * dt
		var air := false
		if t > 2.0 and t < 2.02 and y == 0.0:
			vy = 6.5
		if vy != 0.0 or y > 0.0:
			vy -= 20.0 * dt
			y = maxf(y + vy * dt, 0.0)
			if y == 0.0: vy = 0.0
			air = y > 0.0
		var yaw := -PI / 2.0
		if t > 1.75:
			yaw = lerpf(-PI / 2.0, PI / 2.0 - 0.6, clampf((t - 1.75) / 0.18, 0.0, 1.0))
		for i in range(models.size()):
			var h: Humanoid = models[i]
			h.rotation.y = yaw
			h.position = Vector3(x + (i - 1) * 1.35, y, 0.0)
			h.ground_speed = spd
			h.sprinting = spd > 5.0
			h.local_move = Vector2(0, 1)
			h.grounded = not air
			h.vertical_speed = vy
			h._process(dt)
	cam.look_at_from_position(Vector3(x + 0.2, 1.25, 5.6), Vector3(x + 0.2, 1.05, 0))
	frame += 1
	return false
