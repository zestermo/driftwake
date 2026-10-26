extends SceneTree
## A jungle boss filmed in its arena on the first chain island (BeastArena.rebuild
## swaps in the kind asked for): the ground from the way in, the canopy from the
## floor, the arena from above, the beast asleep, then each of its moves filmed
## as a strip of frames (the captain standing in, invulnerable), and a sheet of
## everything. Out: <dir>/<shot>.png, <dir>/<move>_strip.png, <dir>/sheet.png.
## Args: <out_dir> <kind> [move,move,... | -] [variant] [chain seed: a theme's kind needs a chain whose first island is that theme]
##   kind: ape | serpent | stalker | mantis | boar | behemoth (the boss's FILM
##   const lists its moves and how long to film each; the ape's are below).
## Env BSHOT_HOUR (11), BSHOT_EYE=1 films from the captain's shoulder (how it reads in play).
## (1.23: "moment" the phase change, "reel" a poise break; barrage, pound and grab are phase 2-3 moves)
const APE_FILM := [["roar", 2.2], ["swipe", 1.0], ["slam", 1.6], ["leap", 2.0], ["throw", 1.8], ["moment", 2.8], ["barrage", 4.2],
	["pound", 3.4], ["grab", 3.4], ["reel", 2.4], ["climb", 22.0]]
const APE_PHASE := {"moment": 1, "barrage": 2, "climb": 2, "pound": 3, "grab": 3, "reel": 3}
const FRAMES := 8
var t := 0.0
var out := ""
var kind := ""
var moves: Array = []
var variant := 0
var cam: Camera3D
var isl
var arena
var boss
var p
var step := 0
var wait := 0.0
var shots: Array = []
var idx := 0
var settle := 0
var frames: Array = []
var caption: Label
var film: Array = []
var mv := 0
var strip: Array = []
var mv_t := 0.0
var next_t := 0.0


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	kind = a[1]
	if a.size() > 2 and a[2] != "-":
		moves = Array(a[2].split(","))
	variant = int(a[3]) if a.size() > 3 else 0
	if a.size() > 4:
		root.get_node("GameManager").chain_seed = int(a[4])
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if t > 240.0:
		print("TIMED OUT")
		quit()
		return false
	if wait > 0.0:
		wait -= d
		return false
	var w = root.get_node_or_null("World/Islands")
	if w == null:
		return false
	match step:
		0:
			var gm = root.get_node("GameManager")
			var want := int(w.chain().start_next[0])
			if gm.chain_at != want:
				gm.apply_chain(want, false, root.get_node("Weather").world_time())
				var wx = root.get_node("Weather")
				var hour := float(OS.get_environment("BSHOT_HOUR")) if OS.get_environment("BSHOT_HOUR") != "" else 11.0
				wx.set_world_time(wx.time_at(hour))
				gm.chain_since = wx.world_time()
			if t < 1.5 or not w.chain_ready() or not w.chain_islands.has(want):
				return false
			isl = w.chain_islands[want]
			arena = load("res://scripts/island/beast_arena.gd").rebuild(isl, kind, variant)
			boss = arena.boss
			_setup()
			step = 1
			wait = 1.0
		1:
			# the stills
			settle += 1
			if settle < 6:
				return false
			settle = 0
			_grab(shots[idx][0])
			idx += 1
			if idx >= shots.size():
				step = 2
				_start_film()
				return false
			_aim_still()
		2:
			_film(d)
	return false


func _setup() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
	var hud = get_first_node_in_group("hud")
	if hud: hud.visible = false
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	p = get_first_node_in_group("player")
	p.health_component.max_health = 999999.0
	p.health_component.current_health = 999999.0
	cam = Camera3D.new()
	cam.fov = 62
	cam.far = 2000
	root.add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	cl.layer = 100
	root.add_child(cl)
	caption = Label.new()
	caption.position = Vector2(12, 8)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	caption.add_theme_constant_override("outline_size", 6)
	cl.add_child(caption)
	_put_player(10.0)
	var c: Vector3 = arena.global_position
	var entry := _in_dir()
	var side := entry.cross(Vector3.UP)
	shots = [
		["ground", "the ground from the way in", c + entry * 30.0 + Vector3(0, 2.2, 0), c + Vector3(0, 3.0, 0)],
		["canopy", "the canopy from the floor", c + entry * 6.0 + Vector3(0, 1.6, 0), c - entry * 8.0 + Vector3(0, 16.0, 0)],
		["above", "the arena from above the trees", c + entry * 34.0 + side * 20.0 + Vector3(0, 40.0, 0), c],
		["asleep", "%s asleep" % boss.boss_name, c + entry * 9.0 + side * 4.0 + Vector3(0, 2.4, 0), c + Vector3(0, 1.4, 0)],
	]
	film = []
	var list: Array = APE_FILM if kind == "ape" else (boss.film_list() if boss.has_method("film_list") else boss.FILM)
	for f in list:
		if moves.is_empty() or moves.has(f[0]):
			film.append(f)
	_aim_still()


## From the arena toward the way in (flat).
func _in_dir() -> Vector3:
	var e: Vector2 = (isl.sites["village"] - isl.sites["boss"]).normalized()
	return Vector3(e.x, 0, e.y)


func _put_player(dist: float) -> void:
	var at: Vector3 = arena.global_position + _in_dir() * dist
	at = boss.ground_at(at) if boss.has_method("ground_at") else boss._ground_at(at)
	p.state_machine.force_state("Idle", {})
	p.global_position = at + Vector3.UP * 0.5
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO


func _aim_still() -> void:
	var s: Array = shots[idx]
	caption.text = "%s  -  %s" % [boss.boss_name, s[1]]
	cam.global_position = s[2]
	cam.look_at(s[3], Vector3.UP)


func _grab(name: String) -> Image:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	frames.append(img)
	return img


func _start_film() -> void:
	mv = 0
	if film.is_empty():
		_sheet()
		print("SAVED")
		quit()
		return
	# awake: the arena's wake check runs on its own once the captain's near
	boss.alert()
	wait = 3.0
	mv_t = -1.0


func _begin_move() -> void:
	var f: Array = film[mv]
	strip = []
	mv_t = 0.0
	next_t = 0.0
	p.health_component.current_health = 999999.0
	_put_player(9.0 if str(f[0]) != "leap" else 15.0)
	if kind == "ape":
		var m := str(f[0])
		boss._come_down()
		boss._special = ""
		boss._set_state(2)
		boss.humanoid.stop_action()
		boss._cd = {"swipe": 99.0, "slam": 99.0, "leap": 99.0, "throw": 99.0, "canopy": 99.0, "grab": 99.0, "barrage": 99.0, "pound": 99.0}
		boss.phase = int(APE_PHASE.get(m, 1))
		boss.health.current_health = boss.health.max_health * [0.9, 0.5, 0.2][boss.phase - 1]
		boss._apply_look()
		if m == "moment":
			_put_player(8.0)
		elif m == "reel":
			boss._poise_break(-boss._fwd())
		else:
			_put_player(4.5 if m == "grab" else (7.0 if m == "pound" else (15.0 if m == "leap" else 9.0)))
			boss._begin_special(m)
	else:
		boss.end_move()
		boss._set_state(1)
		boss.film(str(f[0]))


func _film(d: float) -> void:
	var f: Array = film[mv]
	var secs := float(f[1])
	# (each move begins once the wait before it is over: filmed from its first frame)
	if mv_t < 0.0:
		_begin_move()
	if kind == "ape" and mv_t == 0.0 and str(f[0]) == "moment":
		boss.health.current_health = boss.health.max_health * 0.55
	mv_t += d
	_frame_cam()
	caption.text = "%s  -  %s  %.1f s" % [boss.boss_name, f[0], mv_t]
	if mv_t >= next_t:
		next_t += secs / FRAMES
		var img := root.get_texture().get_image()
		strip.append(img)
	if mv_t >= secs + 0.05:
		_save_strip(str(f[0]))
		mv += 1
		if mv >= film.size():
			_sheet()
			print("SAVED")
			quit()
			return
		wait = 1.2
		mv_t = -1.0


## Side on to the line between the captain and the beast, both in frame (or from
## the captain's shoulder, BSHOT_EYE).
func _frame_cam() -> void:
	var bp: Vector3 = boss.global_position + Vector3(0, 1.8, 0)
	var pp: Vector3 = p.global_position + Vector3(0, 1.0, 0)
	if OS.get_environment("BSHOT_EYE") == "1" or (kind == "ape" and boss.up):
		var back := Vector3(pp.x - bp.x, 0, pp.z - bp.z).normalized()
		cam.global_position = pp + back * 4.5 + Vector3(0, 1.6, 0)
		cam.look_at(bp, Vector3.UP)
		return
	var mid := (bp + pp) * 0.5
	var across := Vector3(bp.x - pp.x, 0, bp.z - pp.z)
	var span := maxf(across.length(), 6.0)
	var side := across.normalized().cross(Vector3.UP)
	cam.global_position = mid + side * (span * 0.9 + 7.0) + Vector3(0, 3.5 + span * 0.15, 0)
	cam.look_at(mid + Vector3(0, 0.8, 0), Vector3.UP)


func _save_strip(name: String) -> void:
	var w: int = strip[0].get_width() / 3
	var h: int = strip[0].get_height() / 3
	var cols := 4
	var rows := ceili(strip.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for i in range(strip.size()):
		var fr: Image = strip[i]
		fr.convert(Image.FORMAT_RGB8)
		fr.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(fr, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png("%s/%s_strip.png" % [out, name])
	frames.append(strip[mini(strip.size() / 2, strip.size() - 1)])


func _sheet() -> void:
	var w: int = frames[0].get_width() / 2
	var h: int = frames[0].get_height() / 2
	var cols := 3
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for i in range(frames.size()):
		var fr: Image = frames[i]
		fr.convert(Image.FORMAT_RGB8)
		fr.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(fr, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png("%s/sheet.png" % out)
