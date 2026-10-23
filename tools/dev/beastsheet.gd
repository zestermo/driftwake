extends SceneTree
## Every theme's beast bosses and roamers side by side, for picking which get rebuilt (docs/v1_20_plan.md "Boss
## bodies"): each built the way the world builds it (ThemeDef.beasts' script, setup at level 6), one at a time on the
## light stage, framed from the same three-quarter angle by its own size, a frame idle and two once it's fighting a
## stand-in captain (invulnerable); each frame captioned with its number, theme, kind, name and triangle count.
## A kind shared between themes (one script) is shown once. Out: <dir>/<nn>_<kind>.png (its three frames in a row)
## and <dir>/sheet_<theme>.png (that theme's rows).
## `& $env:GODOT --path . --script res://tools/dev/beastsheet.gd -- res://tools/dev/out/beasts [kind filter]`
const TK := preload("res://tools/dev/test_kit.gd")
const W := 1280
const H := 720
## Seconds after it's put down (idle), then after it's alerted (two fighting frames).
const IDLE_AT := 1.5
const FIGHT_AT := [2.2, 3.6]
const ROW_W := 480
const ROW_H := 270

var stage
var out := "res://tools/dev/out/beasts"
var filter := ""
var jobs: Array = []
var job := -1
var beast
var cam: Camera3D
var caption: Label
var t := 0.0
var phase := ""
var frames: Array = []
var rows := {}          # theme -> [Image row]
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		filter = a[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	DisplayServer.window_set_size(Vector2i(W, H))


func _jobs() -> Array:
	var seen := {}
	var list: Array = []
	var themes = load("res://scripts/island/themes/island_themes.gd")
	for th in themes.all():
		for k in th.bosses + th.roamers:
			var info: Dictionary = th.beasts.get(k, {})
			if not info.has("script"):
				continue
			var path: String = info["script"]
			if seen.has(path):
				seen[path]["themes"].append(th.name)
				continue
			var role := "roamer" if k in th.roamers else "boss"
			var j := {"theme": th.name, "themes": [th.name], "kind": k, "role": role, "script": path,
				"name": str((info.get("names", [k]) as Array)[0])}
			seen[path] = j
			list.append(j)
	return list.filter(func(j): return filter == "" or str(j["kind"]).contains(filter))


func _process(d: float) -> bool:
	# (a windowed first launch opens the character creator: accept the default captain)
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up:
		return false
	if not started:
		started = true
		_setup()
		jobs = _jobs()
		print("BS %d kinds" % jobs.size())
		_next()
		return false
	t += d
	match phase:
		"idle":
			_frame_it()
			if t >= IDLE_AT:
				frames.append(_grab("idle"))
				if beast.has_method("alert"):
					beast.alert()
				t = 0.0
				phase = "fight"
		"fight":
			_frame_it()
			var i := frames.size() - 1
			if i < FIGHT_AT.size() and t >= FIGHT_AT[i]:
				frames.append(_grab("fighting"))
			if frames.size() > FIGHT_AT.size():
				_save_row()
				_next()
	return false


func _setup() -> void:
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	var p = stage.player
	p.health_component.max_health = 999999.0
	p.health_component.current_health = 999999.0
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 600.0
	stage.add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	cl.layer = 100
	stage.add_child(cl)
	caption = Label.new()
	caption.position = Vector2(14, 10)
	caption.add_theme_font_size_override("font_size", 26)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	caption.add_theme_constant_override("outline_size", 7)
	cl.add_child(caption)


## The next kind: the last one gone, this one put down 9 m in front of the captain, facing them.
func _next() -> void:
	if beast and is_instance_valid(beast):
		beast.queue_free()
	beast = null
	frames = []
	job += 1
	if job >= jobs.size():
		_sheets()
		print("BS done")
		quit()
		return
	var j: Dictionary = jobs[job]
	var p = stage.player
	# (the stand-in captain beside it for scale, in shot from the camera's side)
	p.global_position = Vector3(3.5, p.global_position.y, -5.0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	var at := Vector3(0, p.global_position.y, -9.0)
	beast = load(j["script"]).new()
	if beast.has_method("setup"):
		beast.setup({"post": at, "yaw": 0.0, "level": 6, "name": j["name"]})
	beast.name = "Beast_%s" % j["kind"]
	stage.add_child(beast)
	beast.global_position = at
	t = 0.0
	phase = "idle"
	print("BS %02d %s %s" % [job + 1, j["theme"], j["kind"]])


## Every visible mesh under the beast: [their world AABB, triangles].
func _bounds() -> Array:
	var box := AABB()
	var first := true
	var tris := 0
	for m in beast.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b := mi.global_transform * mi.get_aabb()
		# (not an effect's or a decal's big quad: the body)
		if b.size.length() < 25.0:
			box = b if first else box.merge(b)
			first = false
		for s in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return [box, tris]


## The same three-quarter angle for every kind, back by its own size (the stand-in captain in shot for scale).
func _frame_it() -> void:
	if beast == null or not is_instance_valid(beast):
		return
	var bt: Array = _bounds()
	var box: AABB = bt[0]
	var size := maxf(maxf(box.size.x, box.size.z), box.size.y)
	var c := box.get_center() if box.size.length() > 0.1 else (beast.global_position as Vector3) + Vector3.UP
	var dir := Vector3(0.72, 0.0, 0.7).normalized()
	var want := c + dir * (size * 0.95 + 3.5) + Vector3.UP * (size * 0.2 + 1.0)
	cam.global_position = cam.global_position.lerp(want, 0.15) if t > 0.05 else want
	cam.look_at(c, Vector3.UP)
	var j: Dictionary = jobs[job]
	caption.text = "%d. %s %s: %s  (%s)  %s tris%s" % [job + 1, "/".join(j["themes"]), j["role"], j["kind"], j["name"],
		_k(bt[1]), "  - idle" if phase == "idle" else "  - fighting"]


func _k(n: int) -> String:
	return "%.1fk" % (n / 1000.0) if n >= 1000 else str(n)


func _grab(_what: String) -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save_row() -> void:
	var j: Dictionary = jobs[job]
	var row := Image.create(ROW_W * frames.size(), ROW_H, false, Image.FORMAT_RGB8)
	for i in range(frames.size()):
		var f: Image = frames[i].duplicate()
		f.resize(ROW_W, ROW_H, Image.INTERPOLATE_BILINEAR)
		row.blit_rect(f, Rect2i(0, 0, ROW_W, ROW_H), Vector2i(i * ROW_W, 0))
	row.save_png(ProjectSettings.globalize_path("%s/%02d_%s.png" % [out, job + 1, j["kind"]]))
	if not rows.has(j["theme"]):
		rows[j["theme"]] = []
	rows[j["theme"]].append(row)


func _sheets() -> void:
	for th in rows.keys():
		var rs: Array = rows[th]
		var sheet := Image.create(ROW_W * 3, ROW_H * rs.size(), false, Image.FORMAT_RGB8)
		for i in range(rs.size()):
			sheet.blit_rect(rs[i], Rect2i(0, 0, rs[i].get_width(), ROW_H), Vector2i(0, i * ROW_H))
		sheet.save_png(ProjectSettings.globalize_path("%s/sheet_%s.png" % [out, th]))
		print("BS sheet ", th)
