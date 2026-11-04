extends SceneTree
## The 1.30 creatures (scripts/enemies/fauna/) on the light stage, one at a time, each against a stand-in captain
## (invulnerable) from the same three-quarter angle: a frame as it stands, one in its tell (S.TELL, the red glow) and
## one as it strikes (S.ATTACK), captioned with its theme, kind, state and triangles. Night kinds at 22:00.
## Out: <dir>/<kind>.png (its three frames in a row) and <dir>/sheet.png.
## Args: <out_dir> [theme:kind,theme:kind...]
## `& $env:GODOT --path . --script res://tools/dev/creaturesheet.gd -- res://tools/dev/out/creatures fog:zombie`
const TK := preload("res://tools/dev/test_kit.gd")
const W := 1280
const H := 720
const ROW_W := 480
const ROW_H := 270
const KINDS := ["fog:zombie", "fog:pale_stalker", "fog:bog_hound", "fog:grave_moth", "forest:shroom_crawler", "forest:thorn_boar", "forest:owl_beast"]
const NIGHT := ["grave_moth", "owl_beast"]
const GIVE_UP := 16.0

var stage
var out := "res://tools/dev/out/creatures"
var jobs: Array = []
var job := -1
var c
var cam: Camera3D
var caption: Label
var t := 0.0
var got := {}
var rows: Array = []
var started := false
var S: Dictionary


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	jobs = (a[1].split(",") as Array) if a.size() > 1 else KINDS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	DisplayServer.window_set_size(Vector2i(W, H))


func _process(d: float) -> bool:
	for n in root.find_children("*", "CharacterCreator", true, false):
		n._finish(true)
	if not stage.up:
		return false
	if not started:
		started = true
		_setup()
		_next()
		return false
	t += d
	_frame_it()
	if not got.has("idle") and t > 1.2 and c.state != S.TELL:
		got["idle"] = _grab()
	if c.state == S.TELL and c.st_t > 0.18 and not got.has("tell"):
		got["tell"] = _grab()
	# (a grab that lands goes straight on to holding: S.SPECIAL)
	if (c.state == S.ATTACK and c.st_t > 0.06 or c.state == S.SPECIAL and c.st_t > 0.15) and got.has("tell") and not got.has("attack"):
		got["attack"] = _grab()
	if got.size() >= 3 or t > GIVE_UP:
		_save_row()
		_next()
	return false


func _setup() -> void:
	S = load("res://scripts/enemies/fauna/creature.gd").S
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	for g in stage.find_children("Ground*", "StaticBody3D", false, false):
		for mi in g.find_children("*", "MeshInstance3D", true, false):
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.33, 0.36, 0.3)
			(mi as MeshInstance3D).material_override = m
	var p = stage.player
	p.health_component.max_health = 999999.0
	p.health_component.current_health = 999999.0
	cam = Camera3D.new()
	cam.fov = 50.0
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


func _next() -> void:
	if c and is_instance_valid(c):
		c.queue_free()
	c = null
	got = {}
	t = 0.0
	job += 1
	if job >= jobs.size():
		_sheet()
		print("CS done")
		quit()
		return
	var tk: PackedStringArray = str(jobs[job]).split(":")
	var wx = root.get_node("Weather")
	wx.set_world_time(wx.time_at(22.0 if tk[1] in NIGHT else 11.0))
	var p = stage.player
	var ground := Vector3(0, stage.GROUND_Y, 0)
	p.global_position = ground + Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	c = load("res://scripts/island/fauna_spawner.gd").make(tk[0], tk[1])
	var at := ground + Vector3(0, 0, -5.0)
	c.setup(at, {"lead": true, "pack": 900 + job, "anchor": at + Vector3(0, 3.0, 0)})
	c.name = "C_" + tk[1]
	c.position = at + Vector3.UP * 0.2
	stage.add_child(c)
	if c.has_method("rise"):
		c.rise.call_deferred()
	if c.has_method("provoke"):
		c.provoke.call_deferred(p)
	print("CS %s" % jobs[job])


func _frame_it() -> void:
	var p = stage.player
	var mid: Vector3 = c.global_position.lerp(p.global_position, 0.3) + Vector3.UP * 0.8
	var along: Vector3 = c.global_position - p.global_position
	along.y = 0.0
	var side := along.cross(Vector3.UP).normalized()
	cam.global_position = mid + side * 3.6 + Vector3.UP * 0.9 - along.normalized() * 1.2
	cam.look_at(mid, Vector3.UP)
	caption.text = "%s  -  %s  (%s tris)" % [jobs[job], S.keys()[c.state], _tris()]


func _tris() -> int:
	var n := 0
	for mi in c._parts:
		for s in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func _grab() -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save_row() -> void:
	var row := Image.create(ROW_W * 3, ROW_H, false, Image.FORMAT_RGB8)
	var i := 0
	for k in ["idle", "tell", "attack"]:
		if got.has(k):
			var f: Image = got[k].duplicate()
			f.resize(ROW_W, ROW_H, Image.INTERPOLATE_BILINEAR)
			row.blit_rect(f, Rect2i(0, 0, ROW_W, ROW_H), Vector2i(i * ROW_W, 0))
		else:
			print("CS %s: no %s frame" % [jobs[job], k])
		i += 1
	row.save_png(ProjectSettings.globalize_path("%s/%s.png" % [out, str(jobs[job]).split(":")[1]]))
	rows.append(row)


func _sheet() -> void:
	var sheet := Image.create(ROW_W * 3, ROW_H * rows.size(), false, Image.FORMAT_RGB8)
	for i in range(rows.size()):
		sheet.blit_rect(rows[i], Rect2i(0, 0, ROW_W * 3, ROW_H), Vector2i(0, i * ROW_H))
	sheet.save_png(ProjectSettings.globalize_path("%s/sheet.png" % out))
