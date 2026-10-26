extends SceneTree
## The spike logger: a frame forced over Perf.SPIKE_MS (a build step timed into it, a node spawned in it) is kept in
## Perf.recent and written to the perf log with its cause; the F12 capture's text lists it.
const TK := preload("res://tools/dev/test_kit.gd")
const DIR := "user://t_spike_log/"
var stage
var step := 0
var until := 0
var fails := 0
var perf
var before := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			perf = root.get_node("Perf")
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
			perf.log_dir = DIR
			before = perf._spikes
			perf.step("Isle9 'test beasts'", 31000)
			var s := GDScript.new()
			s.source_code = "extends Node3D\n"
			s.reload()
			s.resource_path = "res://spike_probe.gd"
			var n := Node3D.new()
			n.set_script(s)
			root.add_child(n)
			OS.delay_msec(int(perf.HITCH_MS) + 10)
			until = TK.wait_ticks(3)
		1:
			check("the slow frame was counted", perf._spikes > before)
			var line: String = perf.recent[-1] if not perf.recent.is_empty() else ""
			for l in perf.recent:
				if l.contains("test beasts"):
					line = l
			print(line)
			check("it's kept for the capture with its slowest step", line.contains("slowest Isle9 'test beasts' 31.0"))
			check("...the build section timed", line.contains("build 31.0/1"))
			check("...what was spawned in it", line.contains("spawned") and line.contains("spike_probe 1"))
			check("...who was awake", line.contains("awake: enemies"))
			perf._write_line()
			var txt := FileAccess.get_file_as_string(perf.log_path())
			check("the perf log has the spike line", txt.contains("slowest Isle9 'test beasts'"))
			check("...and the half minute's spike count", txt.contains("spikes "))
			check("the F12 capture's text lists it", root.get_node("DevCapture").state_text().contains("test beasts"))
			return TK.done(fails)
	step += 1
	return false
