extends SceneTree
## Spring boots (1.28): U jumps far higher than legs alone (Mk I over 2.5 m, Mk III higher still), cooldown only (no
## charges), and a use in the cooldown is refused.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var y0 := 0.0
var top := 0.0
var top1 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if p:
		top = maxf(top, p.global_position.y - y0)
	if TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			y0 = p.global_position.y
			p.gadgets.give("spring_boots", 0)
			check("Mk I fires", p.gadgets.fire())
			check("...no charges, just the cooldown", p.gadgets.max_charges("spring_boots") == 0 and p.gadgets.cooldown_left("spring_boots") > 0.0)
			until = TK.wait_secs(0.2)
		1:
			check("a use in the cooldown is refused", not p.gadgets.fire())
			until = TK.wait_secs(2.0)
		2:
			top1 = top
			check("Mk I springs over 2.5 m (%.2f)" % top1, top1 > 2.5)
			check("...and lands again", p.is_on_floor())
			top = 0.0
			p.gadgets.give("spring_boots", 2)
			p.gadgets.ready_at.clear()
			check("Mk III fires", p.gadgets.fire())
			until = TK.wait_secs(2.5)
		3:
			check("Mk III springs higher (%.2f > %.2f)" % [top, top1], top > top1 + 1.0)
			return TK.done(fails)
	step += 1
	return false
