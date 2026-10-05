extends SceneTree
## Combat-stance strafing: bodies facing -Z, moving in different directions
## at combat speed (6 x 0.8). Prints how much the planted foot slides, and
## saves a filmstrip of one of them. Args: <out_prefix> [dir index for frames, -1 = none]
const DIRS := [Vector2(0.7071, 0.7071), Vector2(1, 0), Vector2(0.7071, -0.7071), Vector2(0, -1), Vector2(-0.7071, 0.7071), Vector2(0, 1)]
const SPEED := 4.8
var hs: Array = []
var f := 0
var out := ""
var frames := true
var only := -1
var cam: Camera3D
var slip := {}
var prev := {}
var low := {}
var flips := {}
var last_sign := {}
var t := 0.0


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	only = int(a[1]) if a.size() > 1 else -1
	frames = only >= 0
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.42, 0.56, 0.72)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0); root.add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); floor.mesh = pm; root.add_child(floor)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.5, 0.45, 0.35); floor.material_override = mat
	for i in range(DIRS.size()):
		var h := Humanoid.new(); h.setup(CharacterLook.default_look()); root.add_child(h)
		h.position = Vector3((i - 2.5) * 2.2, 0, 0)
		h.armed = true
		h.stance = "sword"
		h.grounded = true
		h.ground_speed = SPEED
		h.local_move = DIRS[i]
		h.set_process(false)
		hs.append(h)
		slip[i] = 0.0
		low[i] = 0
		flips[i] = 0
	cam = Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 40


func _ankle(sh: Node3D) -> Vector3:
	return sh.global_transform * Vector3(0, sh.position.y, 0)


func _process(_d):
	f += 1
	var dt := 1.0 / 60.0
	t += dt
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for i in range(hs.size()):
		var h: Humanoid = hs[i]
		var v := Vector3(DIRS[i].x, 0, -DIRS[i].y) * SPEED
		h.position += v * dt
		h._process(dt)
		# the planted (lower) foot shouldn't slide over the ground
		if f > 60:
			for side in ["l", "r"]:
				var sh: Node3D = h.get("shin_" + side)
				var other: Node3D = h.get("shin_" + ("r" if side == "l" else "l"))
				var a := _ankle(sh)
				var key := "%d%s" % [i, side]
				if prev.has(key) and a.y < 0.04 and a.y < _ankle(other).y - 0.01:
					var dvv := Vector2(a.x - prev[key].x, a.z - prev[key].z) / dt
					slip[i] += dvv.length()
					flips[i] += dvv.dot(Vector2(DIRS[i].x, -DIRS[i].y))
					low[i] += 1
				prev[key] = a
	if only >= 0:
		var hp: Vector3 = hs[only].position
		for j in range(hs.size()):
			hs[j].visible = j == only
		cam.look_at_from_position(hp + Vector3(3.2, 1.9, 4.2), hp + Vector3(0, 0.75, 0))
	if frames and f > 60 and f % 4 == 0 and f <= 60 + 4 * 12:
		_shot((f - 60) / 4)
	if f >= 60 + 180:
		for i in range(hs.size()):
			print("dir %s: planted-foot slide %.2f m/s (along travel %.2f; body %.1f m/s)" % [str(DIRS[i]), slip[i] / maxf(low[i], 1), flips[i] / maxf(low[i], 1), SPEED])
		print("DONE")
		quit()
	return false


func _shot(n: int) -> void:
	# one frame per direction pair: the camera follows body 0 (fwd-right diagonal)
	root.get_texture().get_image().save_png("%s_%02d.png" % [out, n])
