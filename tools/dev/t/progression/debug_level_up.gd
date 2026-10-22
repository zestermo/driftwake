extends SceneTree
## Debug F9 (a Captain level, plus a mastery level of the weapon in hand) must not crash, at level 1 and across the
## levels where points arrive, and the level and points rise.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func f9() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_F9
	ev.pressed = true
	p._unhandled_input(ev)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			var l0: int = pr.level
			f9()
			check("F9 at level 1 grants a level (%d -> %d)" % [l0, pr.level], pr.level == l0 + 1)
			until = TK.wait_ticks(2)
		1:
			for i in 12:
				f9()
			check("twelve more F9s (level %d) survive" % pr.level, pr.level >= 13)
			until = TK.wait_ticks(2)
		2:
			return TK.done(fails)
	step += 1
	return false
