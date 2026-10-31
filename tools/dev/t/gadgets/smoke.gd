extends SceneTree
## The smoke pellet (1.28): thrown at a grunt ahead it bursts on him into a cloud; he staggers coughing, and a captain
## standing in the cloud can't be noticed (Stealth) or picked as a target; out of it, they can again.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"grunts": [{"post": Vector3(0, 0, -8), "role": "sword", "seed": 31}]})


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
			p.gadgets.give("smoke", 0)
			TK.act("gadget_fire")
			until = TK.wait_secs(1.6)
		1:
			check("the cloud bursts (%d)" % GadgetVeil.clouds.size(), GadgetVeil.clouds.size() == 1)
			var z = GadgetVeil.clouds[0] if GadgetVeil.clouds.size() > 0 else null
			check("...on the grunt it was thrown at", z != null and z.inside(g.global_position))
			check("he staggers, blinded", g.blinded_at >= 0.0 and g.state == g.S.STAGGER)
			check("the captain outside it is seen", not GadgetVeil.veiled(p) and g._player_ok(p))
			p.global_position = g.global_position + Vector3(1.0, 0, 1.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(3)
		2:
			check("inside it the captain is veiled", GadgetVeil.veiled(p))
			check("...no foe picks them to fight", not g._player_ok(p))
			check("...nor notices them", Stealth.range_for(p, g.global_position, Vector3.BACK, 12.0) == 0.0)
			until = TK.wait_secs(GadgetData.tier_val("smoke", "secs", 0))
		3:
			check("once it thins the captain is seen again", not GadgetVeil.veiled(p) and g._player_ok(p))
			return TK.done(fails)
	step += 1
	return false
