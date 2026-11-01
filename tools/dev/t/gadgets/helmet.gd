extends SceneTree
## The diving helmet (1.28): put on while swimming (a charge), it sits on the head and a dive spends breath at a third
## the rate (Mk III x3): 1.5 s under costs well under a second of breath.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sw
var b0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


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
			sw = p.get_node("StateMachine/Swim")
			p.global_position = Vector3(stage.SHORE_X + 8.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			p.gadgets.give("diving_helmet", 2)
			until = TK.wait_secs(1.0)
		1:
			TK.act("gadget_fire")
			until = TK.wait_ticks(3)
		2:
			check("put on in the water: a charge spent", p.gadgets.charges("diving_helmet") == GadgetData.tier_val("diving_helmet", "charges", 2) - 1)
			check("...it sits on the head", p.body_model.head.get_node_or_null("DivingHelmet") != null)
			check("...breath lasts x3 (%.1f)" % p.gadgets.breath_k(), is_equal_approx(p.gadgets.breath_k(), 3.0))
			b0 = sw.breath
			TK.press("dodge")
			until = TK.wait_secs(1.5)
		3:
			TK.release("dodge")
			var spent: float = b0 - sw.breath
			check("a 1.5 s dive spends a third the breath (%.2f s)" % spent, spent > 0.05 and spent < 0.6)
			return TK.done(fails)
	step += 1
	return false
