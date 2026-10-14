extends SceneTree
## Copy me to tools/dev/t/<group>/<behaviour>.gd. One behaviour (or a few tightly related checks) on the
## light stage (tools/dev/stage.gd: ask only for what the test needs). Run: run_tests.ps1 t/<group>/<behaviour>
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": true})


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
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		1:
			check("R draws the weapon", p.armed)
			return TK.done(fails)
	step += 1
	return false
