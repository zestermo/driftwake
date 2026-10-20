class_name BenchBoot
extends SceneTree
## Runs a tools/dev SceneTree script in an exported build, where --script isn't honoured: the bench build's
## override.cfg (bench.ps1 -Exe writes it beside the exe) makes this the main loop, and it becomes the script
## named by `boot=res://...` (after `--`) on the first frame. Unused by the game itself.

func _initialize() -> void:
	var path := "res://tools/dev/bench_brinehollow.gd"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("boot="):
			path = a.substr(5)
	BenchBoot._become.call_deferred(self, load(path))


func _process(_d: float) -> bool:
	return false


func _physics_process(_d: float) -> bool:
	return false


static func _become(tree: SceneTree, script: Script) -> void:
	if script == null:
		push_error("BenchBoot: the script didn't load")
		tree.quit(1)
		return
	tree.set_script(script)
	tree.call("_initialize")
