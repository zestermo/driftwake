extends Node
## Dev capture (debug builds only): press F12 while playing to save exactly
## what's on screen plus a dump of the game state, so Claude can look at the
## moment you saw ("look at my last capture").
##
## Writes, in the project folder when run from the editor (user://captures in
## an exported debug build):
##   tools/dev/out/captures/cap_<date>_<time>.png / .txt
##   tools/dev/out/captures/last.png / last.txt   (always the newest)
## The .txt has the player (position, state, stats, the last few seconds of
## movement), camera, weather/time, sea, ship, co-op, nearby enemies, the
## video settings and the tail of the Godot log (errors and warnings).

const KEY := KEY_F12
const HISTORY_SECS := 5.0
const HISTORY_STEP := 0.1
const ENEMY_RANGE := 60.0
const LOG_LINES := 60

var _hist: Array = []   # [t, pos, state, hp, speed]
var _hist_t: float = 0.0
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		set_physics_process(false)


func dir_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://tools/dev/out/captures")
	return ProjectSettings.globalize_path("user://captures")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY:
		get_viewport().set_input_as_handled()
		capture()


func _physics_process(delta: float) -> void:
	_hist_t += delta
	if _hist_t < HISTORY_STEP:
		return
	_hist_t = 0.0
	var p := _player()
	if p == null:
		return
	var hp = _prop(p, "health_component")
	_hist.append([Time.get_ticks_msec() / 1000.0, p.global_position, _call(p, "current_state_name", ""),
		hp.current_health if hp else -1.0, Vector2(p.velocity.x, p.velocity.z).length()])
	while _hist.size() > int(HISTORY_SECS / HISTORY_STEP):
		_hist.pop_front()


## Save a screenshot + state dump. Returns the base path (without extension).
func capture() -> String:
	if _busy:
		return ""
	_busy = true
	var dir := dir_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var base := dir.path_join("cap_" + stamp)
	var text := state_text()
	_write(base + ".txt", text)
	_write(dir.path_join("last.txt"), text)
	# the frame as drawn (3D + PSX post + HUD), once this frame has finished
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img:
			img.save_png(base + ".png")
			img.save_png(dir.path_join("last.png"))
			text += "\n" + await _display_check(img, base)
			_write(base + ".txt", text)
			_write(dir.path_join("last.txt"), text)
	_busy = false
	print("DevCapture: ", base, ".png/.txt")
	var psx := get_node_or_null("/root/PSX")
	if psx and psx.has_method("_show_toast"):
		psx._show_toast("Captured " + base.get_file())
	return base


## What the drawn frame can't show: the screen's own pixels over the game
## window (anything the driver or Windows' compositor changes after Godot hands
## the frame over), saved as <base>_screen.png, and a few frames in a row (a
## picture that flickers between frames looks washed out but captures fine).
func _display_check(frame: Image, base: String) -> String:
	var L: Array[String] = ["## Display", "(the .png is Godot's frame; _screen.png is what the screen showed over the window)"]
	var screen := DisplayServer.window_get_current_screen()
	var shot := DisplayServer.screen_get_image(screen)
	if shot == null or shot.is_empty():
		L.append("screen grab: not available on this platform")
	else:
		var rect := Rect2i(DisplayServer.window_get_position() - DisplayServer.screen_get_position(screen), DisplayServer.window_get_size())
		rect = rect.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
		var win := shot.get_region(rect)
		win.save_png(base + "_screen.png")
		var f := frame.duplicate() as Image
		f.resize(win.get_width(), win.get_height(), Image.INTERPOLATE_NEAREST)
		L.append("screen grab %s: brightness  whole %.3f vs frame %.3f   lower half %.3f vs frame %.3f" % [str(rect.size),
			_brightness(win, 0.0), _brightness(f, 0.0), _brightness(win, 0.5), _brightness(f, 0.5)])
	var frames: Array[String] = ["%.3f" % _brightness(frame, 0.5)]
	for i in range(5):
		await RenderingServer.frame_post_draw
		frames.append("%.3f" % _brightness(get_viewport().get_texture().get_image(), 0.5))
	L.append("lower-half brightness, 6 frames in a row: %s" % "  ".join(frames))
	return "\n".join(L) + "\n"


## Mean brightness (0..1) of an image from `top` (fraction of the height) down,
## sampled on a coarse grid.
func _brightness(img: Image, top: float) -> float:
	var sum := 0.0
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	for gy in range(24):
		for gx in range(48):
			var c := img.get_pixel(int((gx + 0.5) / 48.0 * w), int(lerpf(top, 1.0, (gy + 0.5) / 24.0) * (h - 1)))
			sum += c.get_luminance()
			n += 1
	return sum / float(n)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _prop(o: Object, prop: String):
	if o == null:
		return null
	for p in o.get_property_list():
		if p["name"] == prop:
			return o.get(prop)
	return null


func _call(o: Object, method: String, fallback = null):
	if o and o.has_method(method):
		return o.call(method)
	return fallback


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


## Everything worth knowing about this moment, as plain text.
func state_text() -> String:
	var L: Array[String] = []
	L.append("# Driftwake capture %s" % Time.get_datetime_string_from_system())
	var vi := Engine.get_version_info()
	L.append("godot %s  fps %d  window %s  scene %s" % [vi.get("string", "?"), Engine.get_frames_per_second(),
		str(get_tree().root.size), get_tree().current_scene.scene_file_path if get_tree().current_scene else "-"])
	var modes := {DisplayServer.WINDOW_MODE_WINDOWED: "windowed", DisplayServer.WINDOW_MODE_MAXIMIZED: "maximized",
		DisplayServer.WINDOW_MODE_FULLSCREEN: "fullscreen", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: "exclusive fullscreen"}
	L.append("renderer: %s / %s  gpu %s (%s)  %s  vsync %d" % [RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_vendor(), modes.get(DisplayServer.window_get_mode(), "?"),
		DisplayServer.window_get_vsync_mode()])
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.has_method("get_value"):
		L.append("video: preset %s  warp %s  wobble %s  dither %s" % [str(settings.get_value("video", "psx_preset")),
			str(settings.get_value("video", "warp")), str(settings.get_value("video", "wobble")), str(settings.get_value("video", "dither"))])

	# --- player
	var p := _player()
	L.append("")
	L.append("## Player")
	if p == null:
		L.append("(no player in the scene)")
	else:
		var hp = _prop(p, "health_component")
		var pw = _prop(p, "power")
		L.append("pos %s  yaw %.0f deg  vel %s (%.2f m/s flat)" % [_v(p.global_position),
			rad_to_deg(_prop(p, "player_model").global_rotation.y) if _prop(p, "player_model") else 0.0,
			_v(p.velocity), Vector2(p.velocity.x, p.velocity.z).length()])
		var ctx_enum: Dictionary = p.get_script().get_script_constant_map().get("Context", {})
		var ctx = _prop(p, "context")
		L.append("state %s  on_floor %s  context %s  armed %s  sprinting %s" % [str(_call(p, "current_state_name", "?")),
			str(p.is_on_floor()), str(ctx_enum.find_key(ctx)) if ctx != null and ctx_enum.find_key(ctx) != null else str(ctx),
			str(_prop(p, "armed")), str(_prop(p, "sprinting"))])
		L.append("hp %s  stamina %s  energy %s  level %s" % [
			("%.0f/%.0f" % [hp.current_health, hp.max_health]) if hp else "?",
			("%.0f" % float(_prop(p, "stamina"))) if _prop(p, "stamina") != null else "?",
			("%.0f" % float(pw.energy)) if pw and _prop(pw, "energy") != null else "?",
			str(_prop(_prop(p, "progression"), "level"))])
		var bm = _prop(p, "body_model")
		if bm:
			L.append("body: stance %s  action %s  ragdoll %s  ground_speed %.2f  local_move %s" % [str(_prop(bm, "stance")),
				str(_call(bm, "current_action", "")), str(_prop(bm, "ragdoll") != null), float(_prop(bm, "ground_speed")), str(_prop(bm, "local_move"))])
		if p.has_method("water_depth"):
			L.append("water depth here %.2f m" % float(p.water_depth()))
		if _hist.size() > 0:
			L.append("last %.0f s (every %.1f s): t, pos, state, hp, speed" % [HISTORY_SECS, HISTORY_STEP])
			# every 0.5 s, plus every state change (marked <-) and the last sample
			var t_end: float = _hist[-1][0]
			var prev_state := ""
			for i in range(_hist.size()):
				var h: Array = _hist[i]
				var changed: bool = h[2] != prev_state
				prev_state = h[2]
				if changed or i % 5 == 0 or i == _hist.size() - 1:
					L.append("  %+.1f  %s  %s  %.0f  %.1f%s" % [h[0] - t_end, _v(h[1]), h[2], h[3], h[4], " <-" if changed else ""])

	# --- camera
	var cam := get_viewport().get_camera_3d()
	if cam:
		L.append("")
		L.append("## Camera")
		L.append("pos %s  looking %s  fov %.0f  path %s" % [_v(cam.global_position), _v(-cam.global_basis.z), cam.fov, str(cam.get_path())])

	# --- world: weather, time, sea
	var w := get_node_or_null("/root/Weather")
	if w:
		L.append("")
		L.append("## World")
		var names: Array = w.get_script().get_script_constant_map().get("NAMES", [])
		var st: int = int(w.state)
		L.append("time %s (hour %.2f, world_time %.0f s)  weather %s%s" % [str(_call(w, "clock_text", "")), float(w.hour()),
			float(w.world_time()), names[st] if st < names.size() else str(st), "  (forced)" if int(w.forced) >= 0 else ""])
		L.append("coverage %.2f  rain %.2f  storm %.2f  wind %.2f  fog %.2f  in_cloud %.2f  night %.2f" % [float(w.coverage),
			float(w.rain), float(w.storm), float(w.wind), float(w.fog), float(w.in_cloud), float(w.night)])
	var oc := get_node_or_null("/root/Ocean")
	if oc and p:
		L.append("sea: amp_mult %.2f  wave height at player %.2f  clock %.2f" % [float(oc.amp_mult),
			float(oc.get_wave_height(p.global_position)), float(oc.clock())])
		var om := get_tree().get_nodes_in_group("ocean_mesh")
		var mn = oc.get("_mesh_node")
		var m = oc.get("ocean_material")
		L.append("sea mesh: %d in group  followed %s  visible %s  pos %s  override is the sea's %s" % [om.size(),
			str(mn.get_path()) if is_instance_valid(mn) else "<gone>", str(mn.is_visible_in_tree()) if is_instance_valid(mn) else "-",
			_v(mn.global_position) if is_instance_valid(mn) else "-", str(is_instance_valid(mn) and mn.material_override == m)])
		if m:
			L.append("sea material: time %s  amp %s  deep %s  shallow %s  near_alpha %s" % [str(m.get_shader_parameter("time_val")),
				str(m.get_shader_parameter("amp_mult")), str(m.get_shader_parameter("deep_color")), str(m.get_shader_parameter("shallow_color")), str(m.get_shader_parameter("near_alpha"))])
			L.append("  storm_cells %s  whirls %s" % [str(m.get_shader_parameter("storm_cells")), str(m.get_shader_parameter("whirls"))])
			L.append("  wake_box %s  shoal_rect %s  fine_rect %s" % [str(m.get_shader_parameter("wake_box")), str(m.get_shader_parameter("shoal_rect")), str(m.get_shader_parameter("fine_rect"))])
		if w:
			L.append("haze: fog %.0f..%.0f m  haze_height %.2f  colour %s" % [float(w.fog_begin), float(w.fog_end), float(w.haze_height), str(w.fog_color)])

	# --- ship
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if ship:
		L.append("")
		L.append("## Ship")
		var dist := ship.global_position.distance_to(p.global_position) if p else -1.0
		L.append("pos %s  yaw %.0f deg  %.0f m from player  speed %s" % [_v(ship.global_position),
			rad_to_deg(ship.global_rotation.y), dist, str(_prop(ship, "current_speed") if _prop(ship, "current_speed") != null else _prop(ship, "speed"))])

	# --- co-op
	var net := get_node_or_null("/root/Net")
	if net and bool(net.active):
		L.append("")
		L.append("## Co-op")
		L.append("hosting %s  my_id %s  players %d" % [str(net.hosting), str(_call(net, "my_id", "?")), (net.players as Dictionary).size()])
		for id in (net.players as Dictionary).keys():
			var pl = net.players[id]
			var ping := int(net.ping_ms(id)) if net.has_method("ping_ms") else -1
			if is_instance_valid(pl):
				L.append("  peer %s  %s  state %s  ping %d ms" % [str(id), _v(pl.global_position), str(_call(pl, "current_state_name", "?")), ping])

	# --- enemies nearby
	if p:
		var near: Array = []
		for e in get_tree().get_nodes_in_group("enemies"):
			var n3 := e as Node3D
			if n3 == null or not is_instance_valid(n3):
				continue
			var d := n3.global_position.distance_to(p.global_position)
			if d <= ENEMY_RANGE:
				near.append([d, n3])
		near.sort_custom(func(a, b): return a[0] < b[0])
		L.append("")
		L.append("## Enemies within %d m (%d)" % [int(ENEMY_RANGE), near.size()])
		for it in near.slice(0, 12):
			var e: Node3D = it[1]
			var hp = _prop(e, "health")
			if hp == null:
				hp = _prop(e, "health_component")
			var scr: Script = e.get_script()
			L.append("  %s (%s) %.1f m  state %s  hp %s  at %s" % [e.name, scr.resource_path.get_file() if scr else e.get_class(),
				it[0], str(_call(e, "state_name", _prop(e, "state"))), ("%.0f" % hp.current_health) if hp else "?", _v(e.global_position)])

	# --- log tail
	L.append("")
	L.append("## Godot log (last %d lines)" % LOG_LINES)
	var log_path := str(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	var f := FileAccess.open(log_path, FileAccess.READ)
	if f:
		var lines := f.get_as_text().split("\n")
		f.close()
		for line in lines.slice(maxi(lines.size() - LOG_LINES, 0)):
			L.append("  " + line)
	else:
		L.append("  (log not readable: %s)" % log_path)
	return "\n".join(L) + "\n"
