extends SceneTree
## The perf log: a tool run writes none; a session's log keeps the last five sessions (perf.log, then perf_1.log ..
## perf_4.log, the oldest dropped) and writes a line for each hitch with what was marked in it.
const TK := preload("res://tools/dev/test_kit.gd")
const DIR := "user://t_perf_log/"
var stage
var step := 0
var until := 0
var fails := 0


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
			var perf = root.get_node("Perf")
			check("a tool run writes no perf log", perf.log_dir == "")
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
			perf.log_dir = DIR
			for k in range(5):
				var f := FileAccess.open(perf.log_path(k), FileAccess.WRITE)
				f.store_string("session %d" % k)
				f.close()
			perf.mark("test mark")
			perf._note_spike(80.0, perf._pipe_counts(), 100, 1)
			perf._write_line()
			var txt := FileAccess.get_file_as_string(perf.log_path())
			check("the new session's log has a header and a line", txt.begins_with("Driftwake") and txt.contains(" min  fps "))
			check("...and the spike, with what was marked in it", txt.contains("spike  80.0 ms") and txt.contains("marks: test mark"))
			check("the sessions before moved down one", FileAccess.get_file_as_string(perf.log_path(1)) == "session 0"
				and FileAccess.get_file_as_string(perf.log_path(4)) == "session 3")
			check("...and the oldest went", not FileAccess.file_exists(DIR + "perf_5.log"))
			# (the frame's split, 2026-11-10: what a slow frame was made of)
			check("the spike and the half-minute line say how the frame split", txt.contains("| split phys ") and txt.contains("| mean split phys "))
			var sp: PackedFloat32Array = perf.split
			var whole: float = sp[0] + sp[1] + sp[2] + sp[3] + sp[4]
			print("   split phys %.2f proc %.2f tail %.2f draw %.2f wait %.2f" % [sp[0], sp[1], sp[2], sp[3], sp[4]])
			check("a frame was split: scripts ran and the parts are a frame's worth (%.2f ms)" % whole, sp[1] > 0.0 and whole > 0.0 and whole < 2000.0)
			return TK.done(fails)
	step += 1
	return false
