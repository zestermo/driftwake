extends SceneTree
## The second wardrobe batch on a lineup of bodies, front and back: kettle helm,
## mail coif, fez, headband, crown; doublet, kimono; jerkin, padded jack, scale
## vest; haori, duster, frock coat; bracers, long gloves; hakama, leather
## trousers; sandals, sabatons; wide belt; tooth necklace, goggles, fur mantle.
## Args: <out_prefix> [close <a> <b>]
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
	var T := CharacterLook.TRIM
	var sets := [
		{"hat": "kettle", "vest": "scale", "vest_color": L[1], "gloves": false, "gloves_color": L[0], "bracers": true, "legs": "leathers", "legs_color": L[2],
			"feet": "sabatons", "feet_color": L[0], "belt": "wide_belt", "belt_color": L[0], "coat": "none"},
		{"hat": "coif", "vest": "padded", "vest_color": C[1], "gloves": true, "gloves_color": L[0], "long_gloves": true, "legs": "hakama", "legs_color": C[4],
			"feet": "sandals", "feet_color": L[2], "coat": "none", "belt": "belt"},
		{"hat": "fez", "hat_color": C[13], "top": "kimono", "top_color": C[16], "coat": "haori", "coat_color": C[5], "trim_color": T[2], "legs": "hakama", "legs_color": C[8],
			"feet": "sandals", "feet_color": L[2], "necklace": true, "belt": "sash", "sash_color": C[15]},
		{"hat": "headband", "hat_color": C[8], "top": "doublet", "top_color": C[11], "vest": "jerkin", "vest_color": L[2], "coat": "duster", "coat_color": C[12], "trim_color": T[3],
			"legs": "leathers", "legs_color": L[1], "feet": "boots", "goggles": true},
		{"body": "fem", "hair": "long", "hat": "crown", "coat": "frock", "coat_color": C[8], "trim_color": T[0], "gloves": true, "gloves_color": C[0], "long_gloves": true,
			"legs": "breeches", "legs_color": C[0], "feet": "sabatons", "feet_color": L[0], "mantle": true, "mantle_color": C[0]},
		{"body": "fem", "hair": "hime", "hat": "headband", "hat_color": C[13], "top": "kimono", "top_color": C[13], "coat": "haori", "coat_color": C[8], "trim_color": T[0],
			"legs": "hakama", "legs_color": C[5], "feet": "sandals", "feet_color": L[2], "belt": "wide_belt", "belt_color": L[1], "necklace": true},
		{"body": "fem", "hair": "ponytail", "hat": "kettle", "vest": "scale", "vest_color": L[0], "gloves": false, "bracers": true, "gloves_color": L[2], "legs": "leathers", "legs_color": L[0],
			"feet": "sabatons", "feet_color": L[0], "coat": "none", "goggles": true},
		{"hat": "fez", "hat_color": C[14], "top": "doublet", "top_color": C[9], "vest": "padded", "vest_color": C[3], "coat": "none", "mantle": true, "mantle_color": C[3],
			"belt": "wide_belt", "belt_color": L[1], "feet": "shoes", "legs": "breeches"},
	]
	for i in range(sets.size()):
		var lk := CharacterLook.default_look()
		lk.merge(sets[i], true)
		var h := Humanoid.new()
		h.setup(lk)
		root.add_child(h)
		h.position = Vector3((i - (sets.size() - 1) * 0.5) * 1.1, 0, 0)
		h.rotation.y = deg_to_rad(155)
		models.append(h)
	cam = Camera3D.new(); root.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	cam.look_at_from_position(Vector3(0, 1.5, 8.0), Vector3(0, 0.95, 0))
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
