extends SceneTree
## Rows of heads for the look options (the 1.25 customization), one PNG per row. Args: <out_prefix> <set> [yaw_deg]
## Sets: faces (head shapes, eye types, marks), hair (the new styles, bare and under a tricorn), finishes (the hair
## finishes on three styles and the new colours). Writes <out_prefix>_<row>.png.
const GAP := 0.42
const ROW_X := 30.0
const PER := 4
var f := 0
var out := ""
var cam: Camera3D
var rows: Array = []
var models: Array = []
var row_i := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var which: String = a[1] if a.size() > 1 else "faces"
	var yaw := deg_to_rad(float(a[2]) if a.size() > 2 else 15.0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.42, 0.56, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.62, 0.68)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-25), 0)
	root.add_child(sun)
	rows = _rows(which)
	for r in range(rows.size()):
		var row: Array = rows[r]
		for i in range(row.size()):
			var h := Humanoid.new()
			h.setup(row[i])
			root.add_child(h)
			h.position = Vector3(r * ROW_X + (i - (row.size() - 1) * 0.5) * GAP, 0, 0)
			h.rotation.y = PI + yaw
			models.append(h)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL


func _look(over: Dictionary) -> Dictionary:
	var lk := CharacterLook.base_look()
	lk.merge({"hair": "crop", "hat": "none", "top": "shirt", "eye_color": CharacterLook.EYE_COLORS[3]}, true)
	lk.merge(over, true)
	return lk


func _rows(which: String) -> Array:
	var out_rows: Array = []
	match which:
		"faces":
			for body in ["masc", "fem"]:
				var heads: Array = []
				for hd in ["round", "square", "heart", "broad"]:
					heads.append(_look({"head": hd, "body": body, "hair": "crop" if body == "masc" else "ponytail"}))
				out_rows.append(heads)
			for body in ["masc", "fem"]:
				var eyes: Array = []
				for i in [0, 4, 6, 7]:
					eyes.append(_look({"eyes": i, "body": body, "hair": "crop" if body == "masc" else "ponytail",
						"eye_color": CharacterLook.EYE_COLORS[[3, 0, 2, 5][eyes.size()]]}))
				out_rows.append(eyes)
	var cut: Array = []
	for row in out_rows:
		for i in range(0, (row as Array).size(), PER):
			cut.append((row as Array).slice(i, i + PER))
	return cut


func _process(_d: float) -> bool:
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for h in models:
			h.set_process(false)
			for k in range(20):
				h._process(1.0 / 60.0)
			h.head.rotation = Vector3.ZERO
			h.neck.rotation = Vector3.ZERO
	if f >= 3 and (f - 3) % 4 == 0:
		if row_i > 0:
			var path := "%s_%d.png" % [out, row_i - 1]
			root.get_texture().get_image().save_png(path)
			print("SAVED ", path)
		if row_i >= rows.size():
			quit()
			return false
		var n: int = (rows[row_i] as Array).size()
		var vp := root.get_visible_rect().size
		cam.size = maxf(0.5, n * GAP * vp.y / vp.x + 0.05)
		var head_y := 1.66
		cam.look_at_from_position(Vector3(row_i * ROW_X, head_y, 5.0), Vector3(row_i * ROW_X, head_y, 0))
		row_i += 1
	return false
