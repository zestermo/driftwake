extends SceneTree
## A JungleBeast boss's moves filmed on the light stage (no island needed: bossshot wants a chain whose first island is
## the kind's theme): put down at level 6 in front of a stand-in captain (invulnerable), each move begun at its phase
## (1.23 beast pass: the phase its _pass_moves lists it in; "moment" is the phase change, "reel" a poise break) and
## filmed as FRAMES frames from a three-quarter view framed by its size. Out: <dir>/<move>_strip.png, <dir>/sheet.png.
## Args: <out_dir> <theme> <kind> [move,move,... | -: its film_list() or FILM]
## `& $env:GODOT --path . --script res://tools/dev/beastfilm.gd -- res://tools/dev/out/beast/bear snow great_bear`
const TK := preload("res://tools/dev/test_kit.gd")
const FRAMES := 8
const VIEW := Vector3(0.72, 0.0, 0.7) / 1.004
var stage
var out := ""
var theme := ""
var kind := ""
var moves: Array = []
var film: Array = []
var mv := -1
var beast
var cam: Camera3D
var caption: Label
var t := 0.0
var next_t := 0.0
var wait := 0.0
var strip: Array = []
var mids: Array = []
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	theme = a[1]
	kind = a[2]
	if a.size() > 3 and a[3] != "-":
		moves = Array(a[3].split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	DisplayServer.window_set_size(Vector2i(1280, 720))


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
		return false
	if wait > 0.0:
		wait -= d
		_frame_it()
		if wait <= 0.0:
			_begin()
		return false
	if mv < 0 or mv >= film.size():
		return false
	t += d
	_frame_it()
	var f: Array = film[mv]
	caption.text = "%s  -  %s  %.1f s  (phase %d)" % [beast.boss_name, f[0], t, beast.phase]
	if t >= next_t:
		next_t += float(f[1]) / FRAMES
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		strip.append(img)
	if t >= float(f[1]) + 0.05:
		_save_strip(str(f[0]))
		mv += 1
		if mv >= film.size():
			_sheet()
			print("SAVED")
			quit()
			return false
		wait = 1.0
	return false


func _setup() -> void:
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
	cam.fov = 55.0
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
	var th = load("res://scripts/island/themes/island_themes.gd").of(theme)
	var info: Dictionary = th.beasts[kind]
	var at := Vector3(0, p.global_position.y, -9.0)
	beast = load(info["script"]).new()
	beast.setup({"post": at, "yaw": 0.0, "level": 6, "name": str((info.get("names", [kind]) as Array)[0])})
	stage.add_child(beast)
	beast.global_position = at
	var list: Array = beast.film_list() if beast.has_method("film_list") else beast.FILM
	for f in list:
		if moves.is_empty() or moves.has(f[0]):
			film.append(f)
	if beast.bp == null:
		print("not a beast-pass kind: its moves filmed at phase 1")
	beast.alert()
	mv = 0
	wait = 3.0


## The move's phase: where its kind lists it (the phase change from phase 1; a poise break in its last).
func _phase_of(m: String) -> int:
	if beast.bp == null or m == "moment":
		return 1
	if m == "reel":
		return 3
	var by: Array = beast._pass_moves()
	for i in range(by.size()):
		if m in by[i]:
			return i + 1
	return 1


func _begin() -> void:
	var m := str(film[mv][0])
	t = 0.0
	next_t = 0.0
	strip = []
	var p = stage.player
	p.health_component.current_health = 999999.0
	p.global_position = beast.global_position + beast._fwd() * 7.0
	p.reset_physics_interpolation()
	beast.end_move()
	beast._set_state(1)
	beast.phase = _phase_of(m)
	beast.health.current_health = beast.health.max_health * [0.9, 0.5, 0.2][beast.phase - 1]
	if beast.bp:
		beast.bp.chain_over()
		beast._on_look()
	if m == "moment":
		beast.health.current_health = beast.health.max_health * 0.55
		beast._phase_check()
	elif m == "reel":
		beast.poise_break()
	else:
		beast.film(m)


func _frame_it() -> void:
	var c: Vector3 = (beast.global_position as Vector3) + Vector3.UP * 2.0
	var pp: Vector3 = stage.player.global_position
	var mid := c.lerp(pp, 0.35)
	var want := mid + VIEW * 11.0 + Vector3.UP * 3.5
	cam.global_position = cam.global_position.lerp(want, 0.2)
	cam.look_at(mid + Vector3.UP * 1.0, Vector3.UP)


func _save_strip(name: String) -> void:
	var w: int = strip[0].get_width() / 3
	var h: int = strip[0].get_height() / 3
	var sheet := Image.create(w * 4, h * ceili(strip.size() / 4.0), false, Image.FORMAT_RGB8)
	for i in range(strip.size()):
		var fr: Image = strip[i]
		fr.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(fr, Rect2i(0, 0, w, h), Vector2i((i % 4) * w, (i / 4) * h))
	sheet.save_png(ProjectSettings.globalize_path("%s/%s_strip.png" % [out, name]))
	mids.append(strip[mini(strip.size() / 2, strip.size() - 1)])


func _sheet() -> void:
	var w: int = mids[0].get_width()
	var h: int = mids[0].get_height()
	var cols := 3
	var sheet := Image.create(w * cols, h * ceili(mids.size() / float(cols)), false, Image.FORMAT_RGB8)
	for i in range(mids.size()):
		sheet.blit_rect(mids[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(ProjectSettings.globalize_path("%s/sheet.png" % out))
