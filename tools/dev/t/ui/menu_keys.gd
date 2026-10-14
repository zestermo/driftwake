extends SceneTree
## Tab opens and closes the inventory (pausing the game), Esc the pause menu and back out of options; the FOV option applies.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gm
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self)


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			gm = root.get_node("GameMenu")
			TK.act("inventory")
			until = TK.wait_ticks(6)
		1:
			check("Tab opens inventory + pauses", gm.is_open() and paused)
			TK.act("inventory")
			until = TK.wait_ticks(6)
		2:
			check("Tab closes inventory", not gm.is_open() and not paused)
			TK.act("pause")
			until = TK.wait_ticks(6)
		3:
			check("Esc opens pause menu", gm.is_open() and gm._current == "pause")
			gm.open("options")
			var settings = root.get_node("Settings")
			var old_fov = settings.get_value("video", "fov")
			settings.set_value("video", "fov", 90.0, false)
			check("FOV setting applies", is_equal_approx(root.get_viewport().get_camera_3d().fov, 90.0))
			settings.set_value("video", "fov", old_fov, false)
			TK.act("pause")
			until = TK.wait_ticks(6)
		4:
			check("Esc from options returns to pause", gm._current == "pause")
			TK.act("pause")
			until = TK.wait_ticks(12)
		5:
			check("Esc closes menu", not gm.is_open())
			return TK.done(fails)
	step += 1
	return false
