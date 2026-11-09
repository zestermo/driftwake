extends SceneTree
## Cel shading's switch: the video setting "cel" drives the psx_cel shader global and the ink pass
## (PSX's CelInk quad, visible and following the camera only while on); off is plain lambert.
const TK := preload("res://tools/dev/test_kit.gd")
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
	var psx = root.get_node("PSX")
	var st = root.get_node("Settings")
	match step:
		0:
			st.set_value("video", "cel", true, false)
			until = TK.wait_ticks(3)
		1:
			check("the setting turns cel on", psx.cel)
			var ink = psx.get_node_or_null("CelInk")
			check("the ink pass is up", ink != null and ink.visible)
			var cam := root.get_viewport().get_camera_3d()
			check("the ink quad follows the camera", ink != null and cam != null and ink.global_position.distance_to(cam.global_position) < 0.01)
			st.set_value("video", "cel", false, false)
			until = TK.wait_ticks(2)
		2:
			check("the setting turns cel off", not psx.cel)
			var ink = psx.get_node_or_null("CelInk")
			check("the ink pass is hidden", ink == null or not ink.visible)
			check("PSX stops processing with cel off", not psx.is_processing())
			return TK.done(fails)
	step += 1
	return false
