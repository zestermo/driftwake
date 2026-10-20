extends Node
## Performance readout (autoload "Perf"), in every build. F8 toggles an
## overlay (frame times, CPU/GPU ms, draw calls, nodes, enemies). While in the
## world it writes a line to user://perf.log every 30 s, so a long session
## leaves a record, with a line for each hitch (> 50 ms) saying what was going on in it.
## The last LOG_KEEP sessions are kept (perf.log the newest, then perf_1.log ...). Tests and
## tools (Settings.tool_run()) write nothing unless they set log_dir.

const KEY := KEY_F8
const LOG_NAME := "perf"
const LOG_EVERY := 30.0
const LOG_KEEP := 5
## A frame this long is a visible hitch.
const HITCH_MS := 50.0
## Hitch lines written per log line at most (the rest are counted).
const HITCH_LINES := 10
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
var _pipes_at := PackedInt64Array()
var _nodes_at := 0
var _last_us := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000000
	if Settings.tool_run():
		log_dir = ""
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_pipes_at.resize(PIPES.size())
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY:
		Settings.set_value("video", "perf_overlay", not bool(Settings.get_value("video", "perf_overlay")))
		get_viewport().set_input_as_handled()


## Names something costly happening now (an island build step, a save, a body built), so a hitch's
## log line can say what was going on. Cheap: a string appended, cleared every frame.
func mark(what: String) -> void:
	if _marks.size() < 12 and OS.get_thread_caller_id() == OS.get_main_thread_id():
		_marks.append(what)


func _process(delta: float) -> void:
	# (real time: delta runs at Engine.time_scale, 0.05 in a hit-stop)
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0 if _last_us > 0 else delta * 1000.0
	_last_us = now
	_frames.append(ms)
	var pipes := _pipe_counts()
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if ms > HITCH_MS:
		_hitches += 1
		if _in_world():
			_note_hitch(ms, pipes, nodes)
	_pipes_at = pipes
	_nodes_at = nodes
	_marks_prev = _marks
	_marks = []
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


## A hitch's line: when, the frame's split (Godot's last process / physics times, render CPU / GPU),
## pipelines compiled in it (canvas / mesh / surface / draw / specialization), nodes made or freed, and the marks.
func hitch_line(ms: float, pipes: PackedInt64Array, nodes: int) -> String:
	var pd := []
	for i in range(PIPES.size()):
		pd.append(str(pipes[i] - _pipes_at[i]))
	var what: Array = _marks_prev + _marks
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return "    hitch %5.1f ms at %.2f min  process %.1f  physics %.1f  rcpu %.1f  gpu %.1f  pipelines %s  nodes %+d  state %s  at %s%s" % [
		ms, _session_t / 60.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), gpu_ms(),
		"/".join(pd), nodes - _nodes_at, p.call("current_state_name") if p and p.has_method("current_state_name") else "-",
		"(%.0f, %.0f)" % [p.global_position.x, p.global_position.z] if p else "-",
		("  marks: " + "; ".join(what)) if not what.is_empty() else ""]


func _note_hitch(ms: float, pipes: PackedInt64Array, nodes: int) -> void:
	if _hitch_lines.size() < HITCH_LINES:
		_hitch_lines.append(hitch_line(ms, pipes, nodes))
	elif _hitch_lines.size() == HITCH_LINES:
		_hitch_lines.append("    (more hitches in this half minute)")


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
	_log.store_line("%6.1f min  fps %5.1f  1%%low %5.1f  worst %5.1f ms  hitches %d  process %.1f  physics %.1f  gpu %.1f  draws %d  nodes %d  enemies %d (%d awake)  swimming %d  loot %d  at %s" % [
		_session_t / 60.0, s[0], s[1], s[2], _hitches,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		gpu_ms(), c["draws"], c["nodes"], c["enemies"], c["awake"], c["swimming"], c["loot"],
		"(%.0f, %.0f)" % [p.global_position.x, p.global_position.z] if p else "-"])
	for l in _hitch_lines:
		_log.store_line(l)
	_log.flush()
	_reset_window()


func _reset_window() -> void:
	_frames.clear()
	_hitches = 0
	_worst = 0.0
	_hitch_lines = []


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
	_log.store_line("(hitch lines: Godot's process / physics ms, render cpu / gpu, pipelines compiled canvas/mesh/surface/draw/specialization, nodes made)")
