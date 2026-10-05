extends SceneTree
## Renders a lineup of player poses for animation tuning.
var shots := []
var f := 0
var models: Array = []
const LOOK := {
	"skin": Color(0.87, 0.67, 0.5), "shirt": Color(0.88, 0.85, 0.76), "pants": Color(0.22, 0.2, 0.18),
	"boots": Color(0.16, 0.1, 0.07), "coat": true, "coat_color": Color(0.16, 0.22, 0.42), "sash": true,
	"sash_color": Color(0.72, 0.14, 0.1), "hat": "tricorn", "hat_color": Color(0.1, 0.08, 0.07),
	"hair_color": Color(0.25, 0.15, 0.08), "face": 6}
var specs := []
func _initialize():
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.6, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6, 0.6, 0.65); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-30), 0); sun.shadow_enabled = true; root.add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 20); ground.mesh = pm; root.add_child(ground)
	var arg := OS.get_cmdline_user_args()
	var set_name := arg[0] if arg.size() > 0 else "a"
	if set_name == "a":
		specs = [["idle", {}], ["armed", {"armed": true}], ["walk", {"speed": 6.0, "steps": 7}], ["sprint", {"speed": 14.0, "steps": 9}],
			["jump", {"air": 6.0}], ["fall", {"air": -12.0}], ["land", {"land": true}], ["strafe", {"armed": true, "speed": 5.0, "lm": Vector2(1, 0), "steps": 5}]]
	elif set_name == "d":
		specs = [["dash R", {"act": "dash", "dur": 0.3, "u": 0.35, "dd": Vector2(1, 0), "rot": 125}],
			["dash L", {"act": "dash", "dur": 0.3, "u": 0.35, "dd": Vector2(-1, 0), "rot": 125}],
			["dash fwd", {"act": "dash", "dur": 0.3, "u": 0.35, "dd": Vector2(0, 1), "rot": 125}],
			["backstep", {"act": "dash", "dur": 0.3, "u": 0.35, "dd": Vector2(0, -1), "rot": 125}],
			["armed R", {"armed": true, "act": "dash", "dur": 0.3, "u": 0.35, "dd": Vector2(1, 0), "rot": 125}],
			["armed L", {"armed": true, "act": "dash", "dur": 0.3, "u": 0.35, "dd": Vector2(-1, 0), "rot": 125}]]
	elif set_name == "c":
		specs = [["slash_r wind", {"armed": true, "act": "slash_r", "dur": 0.48, "u": 0.18}], ["slash_r hit", {"armed": true, "act": "slash_r", "dur": 0.48, "u": 0.5}],
			["slash_l wind", {"armed": true, "act": "slash_l", "dur": 0.48, "u": 0.18}], ["slash_l hit", {"armed": true, "act": "slash_l", "dur": 0.48, "u": 0.5}],
			["spin .35", {"armed": true, "act": "spin_slash", "dur": 0.62, "u": 0.35}], ["spin .6", {"armed": true, "act": "spin_slash", "dur": 0.62, "u": 0.6}],
			["heavy coil", {"armed": true, "act": "heavy", "dur": 0.8, "u": 0.2}], ["heavy hop", {"armed": true, "act": "heavy", "dur": 0.8, "u": 0.45}],
			["heavy slam", {"armed": true, "act": "heavy", "dur": 0.8, "u": 0.62}], ["run stride", {"speed": 12.0, "steps": 11}]]
	else:
		specs = [["draw .4", {"act": "draw", "dur": 0.35, "u": 0.4}], ["slash_r .2", {"armed": true, "act": "slash_r", "dur": 0.35, "u": 0.2}],
			["slash_r .6", {"armed": true, "act": "slash_r", "dur": 0.35, "u": 0.6}], ["slash_dn .2", {"armed": true, "act": "slash_down", "dur": 0.4, "u": 0.2}],
			["heavy .3", {"armed": true, "act": "heavy", "dur": 0.8, "u": 0.33}], ["heavy .6", {"armed": true, "act": "heavy", "dur": 0.8, "u": 0.6}],
			["roll .4", {"act": "roll", "dur": 0.4, "u": 0.4}], ["parry", {"armed": true, "act": "parry", "dur": 0.6, "u": 0.35}],
			["drink", {"act": "drink", "dur": 1.0, "u": 0.5}], ["stagger", {"armed": true, "act": "stagger", "dur": 0.4, "u": 0.4}]]
	for i in range(specs.size()):
		var h := Humanoid.new()
		h.setup(LOOK)
		root.add_child(h)
		var cols := int(ceil(specs.size() / 2.0))
		var row := i / cols
		var col := i % cols
		h.position = Vector3((col - (cols - 1) * 0.5) * 2.0, 0, -row * 3.4 + 1.7)
		h.rotation.y = deg_to_rad(125)
		h.set_weapon(Props.weapon_mesh("cutlass"))
		var lbl := Label3D.new(); lbl.text = specs[i][0]; lbl.position = Vector3(0, 2.3, 0); lbl.pixel_size = 0.004; lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = h.position + Vector3(0, 2.25, 0); root.add_child(lbl)
		models.append(h)
	var cam := Camera3D.new(); root.add_child(cam)
	cam.fov = 38.0
	cam.position = Vector3(0, 3.6, 11.5); cam.rotation = Vector3(deg_to_rad(-12), 0, 0); cam.current = true
func _process(_d):
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for i in range(models.size()):
			var h: Humanoid = models[i]; var o: Dictionary = specs[i][1]
			h.armed = o.get("armed", false)
			if h.armed: h._attach_weapon(true)
			h.ground_speed = o.get("speed", 0.0); h.sprinting = h.ground_speed > 10
			h.local_move = o.get("lm", Vector2(0, 1))
			if o.has("air"):
				h.grounded = false; h.vertical_speed = o["air"]
			var dt := 1.0 / 60.0
			for k in range(60): h._process(dt)
			if o.has("steps"):
				for k in range(o["steps"]): h._process(dt)
			if o.has("land"):
				h.grounded = false; h.vertical_speed = -14.0
				for k in range(20): h._process(dt)
				h.grounded = true
				for k in range(4): h._process(dt)
			if o.has("rot"): h.rotation.y = deg_to_rad(o["rot"])
			if o.has("dd"): h.dash_dir = o["dd"]
			if o.has("act"):
				h.play(o["act"], o["dur"])
				var steps := int(o["dur"] * o["u"] * 60.0)
				for k in range(steps): h._process(dt)
			h.set_process(false)
	if f == 6:
		root.get_texture().get_image().save_png("res://tools/dev/out/poses_%s_angle.png" % (OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "a"))
		print("SAVED"); quit()
	return false
