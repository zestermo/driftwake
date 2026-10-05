extends SceneTree
## Dev capture (F12): writes a state dump (and, with a real display, a
## screenshot) to tools/dev/out/captures/, including last.txt / last.png.
var t := 0.0
var step := 0
var fails := 0
var base := ""


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 2.5:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			step = 1
			_go()
		2:
			var dc = root.get_node("DevCapture")
			var dir: String = dc.dir_path()
			check("capture returns a path", base != "")
			check("the state dump is written", FileAccess.file_exists(base + ".txt") and FileAccess.file_exists(dir.path_join("last.txt")))
			var txt := FileAccess.get_file_as_string(dir.path_join("last.txt"))
			for sec in ["## Player", "## Camera", "## World", "## Enemies within", "## Godot log"]:
				check("dump has " + sec, txt.find(sec) >= 0)
			check("dump has the player's state and position", txt.find("state ") >= 0 and txt.find("pos (") >= 0)
			check("dump has the recent movement history", txt.find("last 5 s") >= 0)
			if DisplayServer.get_name() != "headless":
				check("screenshot saved", FileAccess.file_exists(base + ".png") and FileAccess.file_exists(dir.path_join("last.png")))
			print(txt.substr(0, 1400))
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false


func _go() -> void:
	# let the movement history fill a little first
	await create_timer(1.0).timeout
	base = await root.get_node("DevCapture").capture()
	step = 2
