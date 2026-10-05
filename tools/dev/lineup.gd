extends SceneTree
## Renders a lineup of character looks. Args: <out.png> <mode: full|heads|back> [seed]
var f := 0
var models: Array = []
var mode := "full"
var out := "res://tools/dev/out/lineup.png"
func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	var seed_base := int(a[2]) if a.size() > 2 else 1
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.6, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.75
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-25), 0); sun.shadow_enabled = true; root.add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 20); ground.mesh = pm; root.add_child(ground)
	var looks: Array = []
	looks.append(CharacterLook.default_look())
	looks.append({"skin": Color(0.72, 0.52, 0.38), "shirt": Color(0.85, 0.82, 0.72), "pants": Color(0.2, 0.22, 0.28),
			"coat": true, "coat_color": Color(0.16, 0.26, 0.36), "hat": "cap", "hat_color": Color(0.12, 0.16, 0.24),
			"hair_color": Color(0.12, 0.08, 0.06), "face": 4})
	looks.append({"skin": Color(0.9, 0.7, 0.56), "shirt": Color(0.92, 0.9, 0.84), "pants": Color(0.3, 0.24, 0.18),
			"apron": true, "hat": "bald", "face": 2, "width": 1.3, "height": 1.05})
	looks.append({"skin": Color(0.58, 0.4, 0.28), "shirt": Color(0.7, 0.2, 0.18), "pants": Color(0.25, 0.2, 0.18),
			"sash": true, "sash_color": Color(0.85, 0.65, 0.2), "hat": "bun", "hair_color": Color(0.1, 0.07, 0.05), "face": 1})
	var rng := RandomNumberGenerator.new()
	for i in range(4):
		rng.seed = seed_base * 100 + i
		looks.append(CharacterLook.random_look(rng))
	if OS.get_environment("LOOKS_FEM") != "":
		for i in range(looks.size()):
			looks[i]["body"] = "fem"
	for i in range(looks.size()):
		var h := Humanoid.new()
		h.setup(looks[i])
		root.add_child(h)
		h.position = Vector3((i - (looks.size() - 1) * 0.5) * 1.15, 0, 0)
		h.rotation.y = deg_to_rad(155 if mode != "back" else -25)
		h.set_weapon(Props.weapon_mesh("cutlass"))
		models.append(h)
	var cam := Camera3D.new(); root.add_child(cam)
	cam.current = true
	if mode == "heads":
		cam.fov = 22.0
		cam.look_at_from_position(Vector3(0, 1.75, 7.5), Vector3(0, 1.72, 0))
	else:
		cam.fov = 40.0
		cam.look_at_from_position(Vector3(0, 1.6, 7.6), Vector3(0, 0.95, 0))
func _process(_d):
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for h in models:
			for k in range(40): h._process(1.0 / 60.0)
			h.set_process(false)
	if f == 6:
		root.get_texture().get_image().save_png(out)
		print("SAVED"); quit()
	return false
