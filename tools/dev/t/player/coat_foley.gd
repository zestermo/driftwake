extends SceneTree
## Cloth foley (2026-11-06): with a coat on, a sharp turn swings it round (one rustle, then a short
## wait); with nothing that swings, turning makes no rustle.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var spin := false
var n0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if spin and p:
		p.body_model.global_rotation.y += 0.5
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.body_model.look["coat"] = "none"
			p.body_model.look["cape"] = false
			check("nothing that swings", not p.wears_cloth())
			n0 = p.foley_turns
			spin = true
			until = TK.wait_secs(1.0)
		1:
			check("no coat: turning makes no rustle", p.foley_turns == n0)
			p.body_model.look["coat"] = "long_coat"
			check("a coat swings", p.wears_cloth())
			n0 = p.foley_turns
			until = TK.wait_secs(1.0)
		2:
			var got: int = p.foley_turns - n0
			spin = false
			check("a coat rustles on sharp turns (%d in 1 s)" % got, got >= 1 and got <= 3)
			return TK.done(fails)
	step += 1
	return false
