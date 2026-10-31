extends SceneTree
## The tar bomb (1.28): thrown at a grunt it smashes into a black pool under him; standing in it he's slowed to the
## tier's speed (Mk II here), and once he's out of it he's back to full speed.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"grunts": [{"post": Vector3(0, 0, -7), "role": "sword", "seed": 32}]})


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
			p.gadgets.give("tar", 1)
			TK.act("gadget_fire")
			until = TK.wait_secs(1.6)
		1:
			var zs := get_nodes_in_group("gadget_zones")
			check("the jar smashes into a pool (%d)" % zs.size(), zs.size() == 1 and zs[0].kind == "tar")
			var k: float = GadgetData.tier_val("tar", "slow", 1)
			check("the grunt in it is slowed to %.2f (%.2f)" % [k, g.slow_k], is_equal_approx(g.slow_k, k) and g.humanoid.time_k < 1.0)
			TK.wake(g)
			g.global_position += Vector3(12, 0, 0)
			g.reset_physics_interpolation()
			until = TK.wait_secs(1.5)
		2:
			check("out of it, back to full speed (%.2f)" % g.slow_k, g.slow_k == 1.0)
			return TK.done(fails)
	step += 1
	return false
