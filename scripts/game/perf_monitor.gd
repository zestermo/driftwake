extends Node
## Performance readout (autoload "Perf"), in every build. F8 toggles an
## overlay (frame times, CPU/GPU ms, draw calls, nodes, enemies). While in the
## world it writes a line to user://perf.log every 30 s, so a long session
## leaves a record, with a line for each spike (> SPIKE_MS) saying what ran in it: the frame's split, the
## sections timed through add_us (animation, AI, island builds...) and the slowest named steps, what was
## spawned, who was awake, co-op. The last spikes are also kept for the F12 capture (recent).
## The last LOG_KEEP sessions are kept (perf.log the newest, then perf_1.log ...). Tests and
## tools (Settings.tool_run()) write nothing unless they set log_dir.

const KEY := KEY_F8
const LOG_NAME := "perf"
const LOG_EVERY := 30.0
const LOG_KEEP := 5
## A frame this long is a visible hitch (counted on the 30 s line).
const HITCH_MS := 50.0
## A frame this long is a spike: logged with what ran in it.
const SPIKE_MS := 25.0
## Spike lines written per log line at most (the rest are counted).
const HITCH_LINES := 20
## Spikes kept for the F12 capture.
const RECENT := 16
## Sections of the frame timed by the code that runs them (add_us).
enum {ANIM, AI, BUILD, SPAWN, SLEEP, FX, NET, MOVE}
const CATS := ["anim", "ai", "build", "spawn", "sleep", "fx", "net", "move"]
const STEPS_KEEP := 24
const PIPES := [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH,
	Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]

## Where the session logs go ("" = none: tool runs).
var log_dir := "user://"
var _layer: CanvasLayer
var _label: Label
var _frames := PackedFloat32Array()
var _log_t := 0.0
var _show_t := 0.0
var _hitches := 0
var _worst := 0.0
var _log: FileAccess
var _session_t := 0.0
## What happened since the last frame (mark()), and in the frame before it.
var _marks: Array = []
var _marks_prev: Array = []
var _hitch_lines: Array = []
var _spikes := 0
var _pipes_at := PackedInt64Array()
var _nodes_at := 0
var _ticks_at := 0
var _last_us := 0
## The newest spikes' lines, oldest first (the F12 capture's).
var recent: Array = []
## The crash trail (crumb()): user://crumbs.log, each line flushed as written, so a hard crash still leaves the last
## menus and clicks behind it (the previous session's trail is kept as crumbs_prev.log).
var _crumbs: FileAccess
var _crumb_n := 0
const CRUMBS_MAX := 4000
## Since the last frame: each section's us and calls, named steps [us, what], nodes added and by script.
var _cat_us := PackedInt64Array()
var _cat_n := PackedInt32Array()
var _steps: Array = []
var _added := 0
var _added_by := {}
## The frame's split (2026-11-10: the play logs' slow frames had 1-5 ms of 25-50 timed): when (us) this frame's first
## physics tick began, its process pass ended and its draw began and ended; 0 = not this frame. `split` is the last
## whole frame's [phys, proc, tail, draw, wait] ms; _split_sum adds them up for the half-minute line.
const SPLIT := ["phys", "proc", "tail", "draw", "wait"]
var _t_phys := 0
var _t_late := 0
var _t_pre := 0
var _t_post := 0
var split := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _split_sum := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])


## The last node of the process pass: stamps where the scripts end and the tail (timers, tweens, transform
## notifications, deferred calls) begins.
class Late extends Node:
	var perf: Node
	func _process(_d: float) -> void:
		perf._t_late = Time.get_ticks_usec()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000000
	process_physics_priority = -1000000
	var late := Late.new()
	late.perf = self
	late.name = "Late"
	late.process_priority = 1000000
	add_child(late)
	RenderingServer.frame_pre_draw.connect(func(): _t_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func(): _t_post = Time.get_ticks_usec())
	if Settings.tool_run():
		log_dir = ""
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_pipes_at.resize(PIPES.size())
	_cat_us.resize(CATS.size())
	_cat_n.resize(CATS.size())
	get_tree().node_added.connect(_on_added)
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_label = Label.new()
	_label.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(6, 40)
	_layer.add_child(_label)
	_layer.visible = bool(Settings.get_value("video", "perf_overlay"))
	Settings.changed.connect(func(section, key, value):
		if section == "video" and key == "perf_overlay":
			_layer.visible = bool(value))


## One line on the crash trail: the game minute, the physics frame, the open menu and `what`.
func crumb(what: String) -> void:
	if log_dir == "" or OS.get_thread_caller_id() != OS.get_main_thread_id():
		return
	if _crumbs == null or _crumb_n >= CRUMBS_MAX:
		var path := log_dir + "crumbs.log"
		if _crumbs == null and FileAccess.file_exists(path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(log_dir + "crumbs_prev.log"))
		_crumbs = FileAccess.open(path, FileAccess.WRITE)
		_crumb_n = 0
		if _crumbs == null:
			log_dir = ""
			return
		_crumbs.store_line("Driftwake %s" % ProjectSettings.get_setting("application/config/version"))
	var menu: String = str(GameMenu.get("_current")) if GameMenu.is_open() else "-"
	var co := "co-op %s %d" % ["host" if Net.hosting else "guest", multiplayer.get_peers().size() + 1] if Net.active else "solo"
	_crumbs.store_line("%6.2f min  f%d  %s  menu %s  %s" % [_session_t / 60.0, Engine.get_physics_frames(), co, menu, what])
	_crumbs.flush()
	_crumb_n += 1


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index <= MOUSE_BUTTON_MIDDLE and GameMenu.is_open():
		crumb("click %d%s at %v" % [mb.button_index, " double" if mb.double_click else "", mb.position.floor()])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY:
		Settings.set_value("video", "perf_overlay", not bool(Settings.get_value("video", "perf_overlay")))
		get_viewport().set_input_as_handled()


## Names something costly happening now (an island build step, a save, a body built), so a hitch's
## log line can say what was going on. Cheap: a string appended, cleared every frame.
func mark(what: String) -> void:
	if _marks.size() < 12 and OS.get_thread_caller_id() == OS.get_main_thread_id():
		_marks.append(what)


## Main thread only: `us` spent in a section (ANIM, AI, BUILD...) this frame.
func add_us(cat: int, us: int) -> void:
	_cat_us[cat] += us
	_cat_n[cat] += 1


## Main thread only: a named piece of work (an island's build step) and its us, also counted in `cat`.
func step(what: String, us: int, cat: int = BUILD) -> void:
	add_us(cat, us)
	if _steps.size() < STEPS_KEEP:
		_steps.append([us, what])


func _on_added(n: Node) -> void:
	_added += 1
	var s = n.get_script()
	if s != null:
		_added_by[s] = int(_added_by.get(s, 0)) + 1


## The first node of every physics tick: stamps where the frame's physics (scripts and Jolt, every tick) began.
func _physics_process(_d: float) -> void:
	if _t_phys == 0:
		_t_phys = Time.get_ticks_usec()


## The frame that just ended, from its process pass to this one: its scripts (to Late), the tail (to the draw), the
## draw, the wait after it (present, vsync, the OS), then this frame's physics ticks, which run before its process.
func _take_split(from: int, now: int) -> void:
	if from <= 0 or _t_late < from:
		return
	# (no draw this frame: headless, or the window minimised; the tail then counts as wait)
	var drew := _t_pre >= _t_late and _t_post >= _t_pre
	var after := _t_post if drew else _t_late
	var phys0 := _t_phys if _t_phys >= after else now
	split[0] = (now - phys0) / 1000.0
	split[1] = (_t_late - from) / 1000.0
	split[2] = (_t_pre - _t_late) / 1000.0 if drew else 0.0
	split[3] = (_t_post - _t_pre) / 1000.0 if drew else 0.0
	split[4] = (phys0 - after) / 1000.0
	for i in range(5):
		_split_sum[i] += split[i]


func _process(delta: float) -> void:
	# (real time: delta runs at Engine.time_scale, 0.05 in a hit-stop)
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0 if _last_us > 0 else delta * 1000.0
	_take_split(_last_us, now)
	_t_phys = 0
	_last_us = now
	_frames.append(ms)
	var pipes := _pipe_counts()
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var ticks := Engine.get_physics_frames()
	_cat_us[ANIM] += Humanoid.anim_us
	_cat_n[ANIM] += Humanoid.anim_n
	Humanoid.anim_us = 0
	Humanoid.anim_n = 0
	if ms > HITCH_MS:
		_hitches += 1
	if ms > SPIKE_MS:
		_note_spike(ms, pipes, nodes, ticks - _ticks_at)
	_pipes_at = pipes
	_nodes_at = nodes
	_ticks_at = ticks
	_marks_prev = _marks
	_marks = []
	_cat_us.fill(0)
	_cat_n.fill(0)
	if not _steps.is_empty():
		_steps = []
	_added = 0
	if not _added_by.is_empty():
		_added_by = {}
	_worst = maxf(_worst, ms)
	_show_t -= delta
	if _layer.visible and _show_t <= 0.0:
		_show_t = 0.25
		_label.text = _overlay_text()
	if not _in_world():
		_log_t = 0.0
		return
	_session_t += delta
	_log_t += delta
	if _log_t >= LOG_EVERY:
		_log_t = 0.0
		_write_line()


func _in_world() -> bool:
	var cs := get_tree().current_scene
	return cs != null and cs.name == "World"


func _pipe_counts() -> PackedInt64Array:
	var out := PackedInt64Array()
	for m in PIPES:
		out.append(int(Performance.get_monitor(m)))
	return out


## A spike's line (fields in the log's header): when, physics ticks run in it, the frame's split (Godot's last
## process / physics times, render CPU / GPU), pipelines compiled (canvas / mesh / surface / draw / specialization),
## nodes made or freed; then the timed sections, the slowest steps, what was spawned, who was awake, co-op, the marks.
func spike_line(ms: float, pipes: PackedInt64Array, nodes: int, ticks: int) -> String:
	var pd := []
	for i in range(PIPES.size()):
		pd.append(str(pipes[i] - _pipes_at[i]))
	var what: Array = _marks_prev + _marks
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var L := "    spike %5.1f ms at %.2f min  ticks %d  process %.1f  physics %.1f  rcpu %.1f  gpu %.1f  pipelines %s  nodes %+d" % [
		ms, _session_t / 60.0, ticks, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), gpu_ms(),
		"/".join(pd), nodes - _nodes_at]
	L += "  | split phys %.1f  proc %.1f  tail %.1f  draw %.1f  wait %.1f" % [split[0], split[1], split[2], split[3], split[4]]
	var secs := []
	for i in range(CATS.size()):
		if _cat_n[i] > 0:
			secs.append("%s %.1f/%d" % [CATS[i], _cat_us[i] / 1000.0, _cat_n[i]])
	L += "  | timed " + ("  ".join(secs) if not secs.is_empty() else "-")
	if not _steps.is_empty():
		var st := _steps.duplicate()
		st.sort_custom(func(a, b): return a[0] > b[0])
		L += "  | slowest " + "; ".join(st.slice(0, 5).map(func(s): return "%s %.1f" % [s[1], s[0] / 1000.0]))
	if _added > 0:
		var by := _added_by.keys()
		by.sort_custom(func(a, b): return _added_by[a] > _added_by[b])
		L += "  | spawned %d%s" % [_added, (" (" + ", ".join(by.slice(0, 5).map(func(s): return "%s %d" % [
			(s as Script).resource_path.get_file().get_basename(), _added_by[s]])) + ")") if not by.is_empty() else ""]
	var c := counts()
	var caps := 0
	for r in get_tree().get_nodes_in_group("rivals"):
		if r.can_process():
			caps += 1
	var t: Array = ActorSleep.tally()
	L += "  | awake: enemies %d/%d  ai captains %d  actors %d/%d (%d hidden)" % [c["awake"], c["enemies"], caps, t[0] - t[1], t[0], t[2]]
	var net := get_node_or_null("/root/Net")
	if net and net.active:
		var ping := 0
		for id in net.players.keys():
			ping = maxi(ping, int(net.ping_ms(id)))
		L += "  | co-op %s %d captains, worst ping %d" % ["host" if net.hosting else "guest", net.players.size(), ping]
	L += "  | state %s at %s" % [p.call("current_state_name") if p and p.has_method("current_state_name") else "-",
		"(%.0f, %.0f)" % [p.global_position.x, p.global_position.z] if p else "-"]
	if not what.is_empty():
		L += "  | marks: " + "; ".join(what)
	return L


## A run of slow frames writes a line every SPIKE_GAP s (each hitch over HITCH_MS always): a slow stretch
## mustn't pay for a line every frame.
const SPIKE_GAP_US := 250000
var _noted_us := 0
func _note_spike(ms: float, pipes: PackedInt64Array, nodes: int, ticks: int) -> void:
	_spikes += 1
	if ms <= HITCH_MS and _last_us - _noted_us < SPIKE_GAP_US:
		return
	_noted_us = _last_us
	var line := spike_line(ms, pipes, nodes, ticks)
	recent.append(line)
	if recent.size() > RECENT:
		recent.pop_front()
	if not (_in_world() or Settings.tool_run()):
		return
	if _hitch_lines.size() < HITCH_LINES:
		_hitch_lines.append(line)
	elif _hitch_lines.size() == HITCH_LINES:
		_hitch_lines.append("    (more spikes in this half minute)")


## Frame stats since the last log line: [avg fps, 1% low fps, worst ms].
func frame_stats() -> Array:
	if _frames.is_empty():
		return [0.0, 0.0, 0.0]
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in sorted:
		total += f
	var p99: float = sorted[mini(int(sorted.size() * 0.99), sorted.size() - 1)]
	return [1000.0 * sorted.size() / maxf(total, 0.001), 1000.0 / maxf(p99, 0.001), sorted[-1]]


func cpu_ms() -> float:
	return RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()) \
		+ Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0


func gpu_ms() -> float:
	return RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())


func counts() -> Dictionary:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var swimming := 0
	var awake := 0
	for e in enemies:
		var h = e.get("humanoid")
		if h and h.get("swimming"):
			swimming += 1
		# (asleep: ActorSleep's PROCESS_MODE_DISABLED or a creature's distance LOD)
		if e.can_process() and e.is_physics_processing():
			awake += 1
	return {"enemies": enemies.size(), "awake": awake, "swimming": swimming,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"loot": get_tree().get_nodes_in_group("loot_bags").size()}


func _overlay_text() -> String:
	var c := counts()
	return "%d fps  %.1f ms\nprocess %.1f  physics %.1f\nrender cpu %.1f  gpu %.1f\ndraws %d  prims %dk\nnodes %d\nenemies %d awake / %d asleep (%d swim)" % [
		Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), gpu_ms(),
		c["draws"], c["prims"] / 1000, c["nodes"], c["awake"], c["enemies"] - c["awake"], c["swimming"]]


func _write_line() -> void:
	if log_dir == "":
		_reset_window()
		return
	if _log == null:
		_open_log()
	var s := frame_stats()
	var c := counts()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var n := maxf(float(_frames.size()), 1.0)
	_log.store_line("%6.1f min  fps %5.1f  1%%low %5.1f  worst %5.1f ms  hitches %d  spikes %d  process %.1f  physics %.1f  gpu %.1f  draws %d  nodes %d  enemies %d (%d awake)  swimming %d  loot %d  at %s  | mean split phys %.1f  proc %.1f  tail %.1f  draw %.1f  wait %.1f" % [
		_session_t / 60.0, s[0], s[1], s[2], _hitches, _spikes,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		gpu_ms(), c["draws"], c["nodes"], c["enemies"], c["awake"], c["swimming"], c["loot"],
		"(%.0f, %.0f)" % [p.global_position.x, p.global_position.z] if p else "-",
		_split_sum[0] / n, _split_sum[1] / n, _split_sum[2] / n, _split_sum[3] / n, _split_sum[4] / n])
	for l in _hitch_lines:
		_log.store_line(l)
	_log.flush()
	_reset_window()


func _reset_window() -> void:
	_frames.clear()
	_hitches = 0
	_spikes = 0
	_worst = 0.0
	_hitch_lines = []
	_split_sum.fill(0.0)


func log_path(k: int = 0) -> String:
	return log_dir + LOG_NAME + ("_%d" % k if k > 0 else "") + ".log"


## The sessions before move down one (perf.log -> perf_1.log ... the oldest of LOG_KEEP dropped).
func _open_log() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(log_dir))
	for k in range(LOG_KEEP - 1, 0, -1):
		if FileAccess.file_exists(log_path(k - 1)):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(log_path(k - 1)), ProjectSettings.globalize_path(log_path(k)))
	_log = FileAccess.open(log_path(), FileAccess.WRITE)
	var psx := get_node_or_null("/root/PSX")
	_log.store_line("Driftwake %s  %s  %s  %s (%s)  window %s  preset %s  %s" % [
		str(ProjectSettings.get_setting("application/config/version", "")), Time.get_datetime_string_from_system(),
		OS.get_name(), RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(),
		str(get_tree().root.size), ("pixelated" if psx.pixelated() else "native") if psx else "?",
		"debug" if OS.is_debug_build() else "release"])
	_log.store_line("(split, ms: phys = every physics tick of the frame, scripts and Jolt; proc = the process pass's scripts; tail = timers, tweens, transform notifications, deferred calls; draw = the draw on the main thread; wait = present, vsync, the OS)")
	_log.store_line("(spike lines, frames over %d ms: physics ticks in it, Godot's process / physics ms, render cpu / gpu, pipelines compiled canvas/mesh/surface/draw/specialization, nodes made;" % int(SPIKE_MS))
	_log.store_line(" timed: section ms/calls (anim = rigs posed, ai, build = island steps and freeing, spawn, sleep, fx, net, move = enemies moved a tick); slowest: named steps ms; spawned: nodes added (by script);")
	_log.store_line(" awake: enemies awake/all, AI captains, ActorSleep's actors awake/all (hidden); co-op: host/guest, captains, worst ping; the captain's state and place; marks)")
