extends SceneTree
## Rain on the roof (2026-11-06): in a storm, under a roof the rain is heard drumming on it (Weather's
## rain_roof_loop by its shelter ray) and the open rain turns down; out from under it the drumming stops.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var wx
var roof: StaticBody3D
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weather": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			wx = root.get_node("Weather")
			wx.force(3)
			until = TK.wait_secs(6.0)
		1:
			check("a storm rains (%.2f)" % wx.rain, wx.rain > 0.5)
			check("out in the open: no drumming", not wx._roof_snd.playing or wx._roof_snd.volume_db < -40.0)
			roof = StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(30, 0.4, 30)
			cs.shape = sh
			roof.add_child(cs)
			root.add_child(roof)
			roof.global_position = Vector3(0, 14.0, 0)
			until = TK.wait_secs(3.0)
		2:
			check("under a roof: the rain drums on it (%.1f dB)" % wx._roof_snd.volume_db, wx._roof_snd.playing and wx._roof_snd.volume_db > -20.0)
			roof.queue_free()
			until = TK.wait_secs(3.0)
		3:
			check("out again: the drumming stops (%.1f dB)" % wx._roof_snd.volume_db, wx._roof_snd.volume_db < -40.0)
			return TK.done(fails)
	step += 1
	return false
