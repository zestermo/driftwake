extends SceneTree
## Thunder is heard dist / 340 game seconds after the strike, on game time (not the wall clock: a test runs
## --fixed-fps, faster than real time, and slow motion or a hitch must not move it).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var wx
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weather": true, "hud": false})


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
			check("Weather has the stage as its world", wx._scene == stage)
			wx._thunder_q.clear()
			wx._thunder_q.append([340.0 / 340.0, false])
			until = TK.wait_secs(0.7)
		1:
			check("0.7 s after a strike 340 m off, its thunder is still on the way", wx._thunder_q.size() == 1)
			until = TK.wait_secs(0.5)
		2:
			check("1.2 s after it, the thunder has been heard", wx._thunder_q.is_empty())
			return TK.done(fails)
	step += 1
	return false
