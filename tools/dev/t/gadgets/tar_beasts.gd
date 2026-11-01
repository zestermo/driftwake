extends SceneTree
## Tar and caltrops slow beasts and wildlife too (1.28), not only grunts: a wolf in a tar pool and a great serpent on
## caltrops each go at the zone's speed while they're in it; a wolf out of the tar isn't slowed.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var w: Array = []
var s
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
	if not stage.up or TK.ticking(until):
		return false
	var ground := Vector3(0, stage.GROUND_Y, 0)
	var Z = load("res://scripts/gadgets/gadget_zone.gd")
	match step:
		0:
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			for i in range(2):
				var x = load("res://scripts/enemies/fauna/wolf.gd").new()
				x.name = "wolf_%d" % i
				x.setup(ground + Vector3(-4.0 + i * 8.0, 0, -12.0), {"pack": 7 + i, "lead": true})
				x.position = ground + Vector3(-4.0 + i * 8.0, 0, -12.0)
				stage.add_child(x)
				w.append(x)
			s = load("res://scripts/enemies/beasts/strangler.gd").new()
			s.setup({"post": ground + Vector3(0, 0, 20.0), "yaw": 0.0, "level": 6, "name": "The Strangler"})
			stage.add_child(s)
			until = TK.wait_ticks(4)
		1:
			Z.spawn(self, "tar", 2, w[0].global_position, p)
			Z.spawn(self, "caltrops", 1, s.global_position, p)
			until = TK.wait_secs(0.6)
		2:
			check("a wolf in tar goes at the pool's speed (%.2f)" % w[0].slow_k, is_equal_approx(w[0].slow_k, GadgetData.tier_val("tar", "slow", 2)) and w[0]._slow_t > 0.0)
			check("...the one out of it doesn't", w[1]._slow_t <= 0.0)
			check("a beast on caltrops is slowed too (%.2f)" % s.slow_k, is_equal_approx(s.slow_k, GadgetData.tier_val("caltrops", "slow", 1)) and s._slow_t > 0.0)
			return TK.done(fails)
	step += 1
	return false
