extends SceneTree
## Clothing / hair / hat combination sheets, to find clipping and layering
## problems. One image per sheet:
##   hats    <prefix>_hat_<hat>.png: every hair style under that hat (heads)
##   clothes <prefix>_coat_<coat>.png: every top x vest under that coat
##   extras  <prefix>_extras.png: belts, apron, scarf, pauldron, pouch over coats
## Args: <out_prefix> <mode: hats|clothes|extras|hair> [yaw_deg] [fem]
var f := 0
var out := ""
var mode := "hats"
var yaw := 25.0
var fem := false
var sheets: Array = []   # [name, [looks]]
var si := -1
var models: Array = []
var cam: Camera3D


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	mode = a[1] if a.size() > 1 else "hats"
	yaw = float(a[2]) if a.size() > 2 else 25.0
	fem = a.size() > 3 and a[3] == "fem"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1600, 900)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.6, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.62, 0.68)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-30), 0)
	root.add_child(sun)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var base := CharacterLook.base_look()
	base["body"] = "fem" if fem else "masc"
	base["hair_color"] = CharacterLook.HAIR_COLORS[3]
	match mode:
		"hats", "hair":
			var hats: Array = CharacterLook.HATS if mode == "hats" else ["none"]
			for hat in hats:
				var looks := []
				for hs in CharacterLook.HAIR:
					var lk := base.duplicate()
					lk["hair"] = hs
					lk["hat"] = hat
					lk["hat_color"] = CharacterLook.CLOTH[9]
					looks.append(lk)
				# four heads a sheet (big enough to see what pokes through)
				for c in range(0, looks.size(), 4):
					sheets.append(["hat_%s_%d" % [hat, c / 4], looks.slice(c, c + 4)])
		"clothes":
			for coat in CharacterLook.COATS:
				var looks := []
				for top in CharacterLook.TOPS:
					for vest in CharacterLook.VESTS:
						var lk := base.duplicate()
						lk["top"] = top
						lk["vest"] = vest
						lk["coat"] = coat
						lk["top_color"] = CharacterLook.CLOTH[0]
						lk["vest_color"] = CharacterLook.CLOTH[13]
						lk["coat_color"] = CharacterLook.CLOTH[8]
						looks.append(lk)
				for c in range(0, looks.size(), 6):
					sheets.append(["coat_%s_%d" % [coat, c / 6], looks.slice(c, c + 6)])
		"extras":
			var looks := []
			for coat in CharacterLook.COATS:
				for ex in ["belt_sash", "apron", "scarf", "pauldron", "pouch"]:
					var lk := base.duplicate()
					lk["coat"] = coat
					lk["vest"] = "vest"
					lk["coat_color"] = CharacterLook.CLOTH[8]
					lk["vest_color"] = CharacterLook.CLOTH[13]
					match ex:
						"belt_sash": lk["belt"] = "belt_sash"
						"apron": lk["apron"] = true
						"scarf": lk["scarf"] = true; lk["scarf_color"] = CharacterLook.CLOTH[15]
						"pauldron": lk["pauldron"] = true
						"pouch": lk["pouch"] = true
					looks.append(lk)
			for c in range(0, looks.size(), 5):
				sheets.append(["extras_%d" % (c / 5), looks.slice(c, c + 5)])


func _show(sheet: Array) -> void:
	for m in models:
		m.queue_free()
	models.clear()
	var looks: Array = sheet[1]
	var heads := mode in ["hats", "hair"]
	var gap := 0.46 if heads else 0.9
	for i in range(looks.size()):
		var h := Humanoid.new()
		h.setup(looks[i])
		root.add_child(h)
		h.position = Vector3((i - (looks.size() - 1) * 0.5) * gap, 0, 0)
		h.rotation.y = PI + deg_to_rad(yaw)
		models.append(h)
	if heads:
		cam.size = gap * looks.size() * 0.6
		cam.look_at_from_position(Vector3(0, 1.66, 6.0), Vector3(0, 1.66, 0))
	else:
		cam.size = maxf(gap * looks.size() * 0.56, 2.0)
		cam.look_at_from_position(Vector3(0, 1.0, 8.0), Vector3(0, 1.0, 0))


func _process(_d):
	f += 1
	if f == 2 or (f > 2 and f % 8 == 2):
		if si >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, sheets[si][0]])
			print("SAVED ", sheets[si][0])
		si += 1
		if si >= sheets.size():
			quit()
			return false
		_show(sheets[si])
	if f % 8 == 4:
		for h in models:
			h.set_process(false)
			for k in range(20):
				h._process(1.0 / 60.0)
			h.head.rotation = Vector3.ZERO
			if h.neck:
				h.neck.rotation = Vector3.ZERO
	return false
