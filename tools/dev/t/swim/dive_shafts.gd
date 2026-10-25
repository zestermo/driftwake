extends SceneTree
## Light shafts under water (1.21 small fixes): with the camera under the waves by day the shafts are on (Weather's
## DiveShafts, placed on the GPU round the camera); back at the surface they're off, and under water at night too.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var p
var sw
var wx


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "weather": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _shafts_on() -> bool:
	var s = wx._shafts
	return s != null and is_instance_valid(s) and s.visible and float(wx._shaft_mat.get_shader_parameter("intensity")) > 0.0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			wx = root.get_node("Weather")
			wx.skip_to(12.0)
			wx.forced = 0
			wx.forced_at = wx.world_time() - 100.0
			sw = p.get_node("StateMachine/Swim")
			p.global_position = Vector3(stage.SHORE_X + 8.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(2.0)
		1:
			check("at the surface: no shafts", not _shafts_on())
			TK.press("dodge")
			until = TK.wait_secs(1.6)
		2:
			check("dived, the camera under the waves", sw.camera_under() and wx.under_water)
			check("...the light comes down in shafts at noon", _shafts_on())
			wx.skip_to(0.5)
			until = TK.wait_secs(1.0)
		3:
			check("...and not at night", not _shafts_on())
			TK.release("dodge")
			return TK.done(fails)
	step += 1
	return false
