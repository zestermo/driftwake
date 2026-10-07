extends Node
## Performance readout (autoload "Perf"), in every build. F8 toggles an
## overlay (frame times, CPU/GPU ms, draw calls, nodes, enemies). While in the
## world it writes a line to user://perf.log every 30 s, so a long session
## leaves a record (the previous session's log is kept as perf_prev.log).

const KEY := KEY_F8
const LOG_PATH := "user://perf.log"
const LOG_PREV := "user://perf_prev.log"
const LOG_EVERY := 30.0
## A frame this long is a visible hitch.
const HITCH_MS := 50.0

var _layer: CanvasLayer
var _label: Label
var _frames := PackedFloat32Array()
var _log_t := 0.0
var _show_t := 0.0
var _hitches := 0
var _worst := 0.0
var _log: FileAccess
var _session_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
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


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	_frames.append(ms)
	if ms > HITCH_MS:
		_hitches += 1
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
	for e in enemies:
		var h = e.get("humanoid")
		if h and h.get("swimming"):
			swimming += 1
	return {"enemies": enemies.size(), "swimming": swimming,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"loot": get_tree().get_nodes_in_group("loot_bags").size()}


func _overlay_text() -> String:
	var c := counts()
	return "%d fps  %.1f ms\nprocess %.1f  physics %.1f\nrender cpu %.1f  gpu %.1f\ndraws %d  prims %dk\nnodes %d  enemies %d (%d swim)" % [
		Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), gpu_ms(),
		c["draws"], c["prims"] / 1000, c["nodes"], c["enemies"], c["swimming"]]


func _write_line() -> void:
	if _log == null:
		_open_log()
		if _log == null:
			return
	var s := frame_stats()
	var c := counts()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	_log.store_line("%6.1f min  fps %5.1f  1%%low %5.1f  worst %5.1f ms  hitches %d  process %.1f  physics %.1f  gpu %.1f  draws %d  nodes %d  enemies %d  swimming %d  loot %d  at %s" % [
		_session_t / 60.0, s[0], s[1], s[2], _hitches,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		gpu_ms(), c["draws"], c["nodes"], c["enemies"], c["swimming"], c["loot"],
		"(%.0f, %.0f)" % [p.global_position.x, p.global_position.z] if p else "-"])
	_log.flush()
	_frames.clear()
	_hitches = 0
	_worst = 0.0


func _open_log() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(LOG_PATH), ProjectSettings.globalize_path(LOG_PREV))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _log == null:
		return
	var psx := get_node_or_null("/root/PSX")
	_log.store_line("Driftwake %s  %s  %s  %s (%s)  window %s  preset %s" % [
		str(ProjectSettings.get_setting("application/config/version", "")), Time.get_datetime_string_from_system(),
		OS.get_name(), RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(),
		str(get_tree().root.size), str(psx.PRESETS[psx.preset_index()]["name"]) if psx else "?"])
