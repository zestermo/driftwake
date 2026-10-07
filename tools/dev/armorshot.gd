extends SceneTree
## The new clothing and armour on bodies: cavalier hat + greatcoat, morion +
## cuirass + gauntlets + greaves, turban + brigandine + bandolier, mail +
## cape, and a feminine body in armour; front and back.
## Args: <out_prefix>
var f := 0
var out := ""
var models: Array = []
var cam: Camera3D
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.6, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.75
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-25), 0); sun.shadow_enabled = true; root.add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 20); ground.mesh = pm; root.add_child(ground)
	var C := CharacterLook.CLOTH
	var L := CharacterLook.LEATHER
	var sets := [
		{"hat": "cavalier", "hat_color": C[14], "coat": "greatcoat", "coat_color": C[6], "trim_color": CharacterLook.TRIM[1], "feet": "tall_boots"},
		{"hat": "morion", "vest": "cuirass", "vest_color": C[7], "gloves": true, "gloves_color": L[0], "gauntlets": true, "feet": "greaves", "feet_color": L[0], "coat": "none"},
		{"hat": "turban", "hat_color": C[0], "vest": "brigandine", "vest_color": L[2], "bandolier": true, "coat": "none", "top": "tunic"},
		{"hat": "none", "vest": "mail", "cape": true, "cape_color": C[13], "coat": "none", "belt": "belt"},
		{"body": "fem", "hat": "morion", "vest": "brigandine", "vest_color": L[1], "gloves": true, "gauntlets": true, "feet": "greaves", "cape": true, "cape_color": C[8], "coat": "none"},
		{"body": "fem", "hat": "cavalier", "hat_color": C[8], "coat": "greatcoat", "coat_color": C[13], "bandolier": true},
	]
	for i in range(sets.size()):
		var lk := CharacterLook.default_look()
		lk.merge(sets[i], true)
		var h := Humanoid.new()
		h.setup(lk)
		root.add_child(h)
		h.position = Vector3((i - (sets.size() - 1) * 0.5) * 1.15, 0, 0)
		h.rotation.y = deg_to_rad(155)
		models.append(h)
	cam = Camera3D.new(); root.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	cam.look_at_from_position(Vector3(0, 1.5, 7.2), Vector3(0, 0.95, 0))
	# a close look at two of them: arg 2 = "close <a> <b>"
	var a := OS.get_cmdline_user_args()
	if a.size() > 2 and a[1] == "close":
		var xa: float = models[int(a[2])].position.x
		var xb: float = models[int(a[3])].position.x
		cam.fov = 24.0
		cam.look_at_from_position(Vector3((xa + xb) * 0.5, 1.3, 4.6), Vector3((xa + xb) * 0.5, 1.0, 0))
func _process(_d):
	f += 1
	if f == 2:
		for h in models:
			for k in range(40): h._process(1.0 / 60.0)
	if f == 6:
		root.get_texture().get_image().save_png(out + "_front.png")
		for h in models:
			h.rotation.y = deg_to_rad(-25)
	if f == 12:
		root.get_texture().get_image().save_png(out + "_back.png")
		print("SAVED"); quit()
	return false
