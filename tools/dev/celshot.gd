extends SceneTree
## Cel shading on and off: the same views rendered once per style (PSX.set_cel, the
## `psx_cel` shader global: 0 off, 1 dithered cel + ink),
## PSX pixelation and dither on. Views: day (Brinehollow, 10:30), night (the same at 21:30),
## fight (the captain against the smugglers' camp, a grunt winding up; the tree paused so every
## style sees the same frame), sea (the crew's ship from the water, 15:00). Saves
## <out>/<view>_<style>.png and <out>/sheet.png (a row per view, a column per style).
## Run at 1920x1080: & $env:GODOT --path . --resolution 1920x1080 --script res://tools/dev/celshot.gd -- res://tools/dev/out/cel
## Args: <out_dir> [styles "0,1"] [views "day,night,fight,sea"]
const NAMES := ["off", "cel"]

var t := 0.0
var out := ""
var styles: Array = [0, 1]
var views: Array = ["day", "night", "fight", "sea"]
var p
var w
var cam: Camera3D
var vi := 0
var si := -1
var wait := 0
var phase := 0
var t0 := 0.0
var g
var frames := {}


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1 and a[1] != "-":
		styles = Array(a[1].split(",")).map(func(s): return int(s))
	if a.size() > 2 and a[2] != "-":
		views = Array(a[2].split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	change_scene_to_file("res://scenes/world/world.tscn")


func _set_style(s: int) -> void:
	var psx = root.get_node("PSX")
	if psx.has_method("set_cel"):
		psx.set_cel(s == 1)


func _process(d: float) -> bool:
	t += d
	if t < 2.0:
		return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false):
			c._finish(true)
		var hud = get_first_node_in_group("hud")
		if hud:
			hud.visible = false
		var st = root.get_node("Settings")
		st.set_value("video", "perf_overlay", false, false)
		st.set_value("video", "pixelate", true, false)
		st.set_value("video", "dither", true, false)
		p = get_first_node_in_group("player")
		p.health_component.max_health = 99999.0
		p.health_component.current_health = 99999.0
		w = root.get_node("Weather")
		w.force(0)
		cam = Camera3D.new()
		cam.fov = 55
		cam.far = 3000
		root.add_child(cam)
		cam.current = true
		_start_view()
		return false
	if wait > 0:
		wait -= 1
		return false
	if phase == 0:
		if not _view_ready():
			return false
		phase = 1
		si = 0
		_set_style(styles[0])
		wait = 4
		return false
	# a style has settled: save it, next style or next view
	var img := root.get_texture().get_image()
	var v: String = views[vi]
	var nm := "%s_%s" % [v, NAMES[styles[si]]]
	img.save_png("%s/%s.png" % [out, nm])
	frames[nm] = img
	print("shot ", nm)
	si += 1
	if si < styles.size():
		_set_style(styles[si])
		wait = 4
		return false
	paused = false
	_set_style(0)
	vi += 1
	if vi >= views.size():
		_sheet()
		print("SAVED")
		quit()
		return false
	_start_view()
	return false


func _start_view() -> void:
	phase = 0
	t0 = t
	var v: String = views[vi]
	match v:
		"day":
			w.skip_to(10.5)
			wait = 40
		"night":
			w.skip_to(21.5)
			wait = 150  # lamps check the hour once a second
		"fight":
			w.skip_to(11.0)
			var camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			var guard = camp.grunts[2]
			p.global_position = guard.global_position + guard._fwd() * 4.0 + Vector3.UP * 0.5
			p.reset_physics_interpolation()
			g = null
			wait = 10
		"sea":
			w.skip_to(15.0)
			wait = 40
	_aim()


func _aim() -> void:
	var v: String = views[vi]
	match v:
		"day", "night":
			var b: Vector3 = p.global_position
			var f: Vector3 = p.global_transform.basis.z  # inland, at the village
			f.y = 0.0
			f = f.normalized()
			var side := Vector3.UP.cross(f)
			cam.global_position = b - f * 3.2 + side * 1.1 + Vector3(0, 1.9, 0)
			cam.look_at(b + f * 6.0 + Vector3(0, 1.4, 0), Vector3.UP)
		"sea":
			var s: Node3D = get_first_node_in_group("ship")
			var sb := s.global_transform.basis
			var at := s.global_position
			cam.global_position = at + sb.x.normalized() * 14.0 + sb.z.normalized() * 8.0 + Vector3(0, 4.5, 0)
			cam.look_at(at + Vector3(0, 3.0, 0), Vector3.UP)


func _view_ready() -> bool:
	if views[vi] != "fight":
		_aim()
		return true
	# wait for a grunt to wind up on the captain, then freeze that frame
	if g == null:
		var camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
		for x in camp.grunts:
			if is_instance_valid(x) and x.state == 5:
				g = x
				t0 = t
				break
		if g == null:
			if t - t0 < 12.0:
				return false
			g = camp.grunts[2]
	var mid: Vector3 = (g.global_position + p.global_position) * 0.5
	var side: Vector3 = Vector3.UP.cross((p.global_position - g.global_position).normalized())
	cam.global_position = mid + side * 3.4 + Vector3(0, 1.5, 0) - (g.global_position - p.global_position).normalized() * 1.2
	cam.look_at(mid + Vector3(0, 1.0, 0), Vector3.UP)
	if t - t0 < 0.45:
		return false
	paused = true
	return true


## A row per view, a column per style, each frame at a third of its size.
func _sheet() -> void:
	if frames.is_empty():
		return
	var any: Image = frames.values()[0]
	var fw: int = any.get_width() / 3
	var fh: int = any.get_height() / 3
	var sheet := Image.create((fw + 4) * styles.size(), (fh + 4) * views.size(), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for r in range(views.size()):
		for c in range(styles.size()):
			var f: Image = frames.get("%s_%s" % [views[r], NAMES[styles[c]]])
			if f == null:
				continue
			var s := f.duplicate()
			s.convert(Image.FORMAT_RGB8)
			s.resize(fw, fh, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(s, Rect2i(0, 0, fw, fh), Vector2i(c * (fw + 4), r * (fh + 4)))
	sheet.save_png("%s/sheet.png" % out)
