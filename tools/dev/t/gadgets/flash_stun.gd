extends SceneTree
## (1.30) The flash pellet thrown at a grunt facing the captain stuns him for the tier's time (2 s at Mk I):
## Stealth.stunned reads it (the stronghold's takedowns land on a stunned foe from any side), and it wears off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -8), "role": "sword", "seed": 31}]})


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
			g = stage.camp.grunts[0]
			TK.calm(g, Vector3.BACK)
			check("not stunned to begin with", not Stealth.stunned(g))
			p.gadgets.give("flash", 0)
			check("the flash thrown", p.gadgets.fire())
			until = TK.wait_secs(1.2)
		1:
			check("the grunt facing it is stunned (%s)" % g.state, Stealth.stunned(g) and g.state == g.S.STAGGER)
			check("...for about the tier's time", g.stunned_until - g.blinded_at >= 1.9)
			until = TK.wait_secs(GadgetData.tier_val("flash", "stun", 0) + 0.3)
		2:
			check("it wears off", not Stealth.stunned(g))
			return TK.done(fails)
	step += 1
	return false
