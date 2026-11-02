extends SceneTree
## The Edy reading's dialogue tokens (the temple crash, 1.28): an AI captain made after the local one (its Progression
## registers the tokens too) and then freed leaves the tokens working - they read the local captain's type; and a
## token whose provider was bound to a node since freed fills in as nothing instead of calling into it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var dlg
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			dlg = root.get_node("Dialogue")
			p.progression.attune("ember")
			# another captain's Progression comes and goes (a rival, an officer)
			var other := Node.new()
			other.set_script(load("res://scripts/progression/progression.gd"))
			stage.add_child(other)
			until = TK.wait_ticks(2)
			step = 1
		1:
			for n in stage.get_children():
				if n.get_script() == load("res://scripts/progression/progression.gd"):
					n.free()
			var said: String = dlg._fill_tokens("{edy_says}")
			check("after another captain's gone, the reading still reads ours (%s)" % said, said.contains("Ember"))
			check("...and the read line", dlg._fill_tokens("{edy_read}") != "")
			# a provider bound to a node that's since been freed
			var n := Node3D.new()
			stage.add_child(n)
			dlg.register_token("test_gone", Callable(n, "get_name"))
			n.free()
			check("a token whose provider is gone fills in as nothing", dlg._fill_tokens("a{test_gone}b") == "ab")
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 2
	return false
