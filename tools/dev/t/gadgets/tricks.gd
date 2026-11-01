extends SceneTree
## The rest of the combat tricks (1.28), each landing on a grunt of its own: the flash pellet stuns a grunt facing it
## (not one with his back to it), the burst star hurts (Mk III knocks down), the pepper bomb hurts over time and makes
## him break off coughing, caltrops slow and cut whoever stands on them.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g: Array = []
var hp: Array = []
var downed := false
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	var grunts := []
	for i in range(5):
		grunts.append({"post": Vector3(-16 + i * 8, 0, -10), "role": "sword", "seed": 40 + i})
	stage = TK.stage(self, {"hud": false, "grunts": grunts})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _zone(gid: String, tier: int, n) -> void:
	load("res://scripts/gadgets/gadget_zone.gd").spawn(self, gid, tier, n.global_position, p)


func _process(_d: float) -> bool:
	if g.size() > 2 and int(g[2].state) in [int(g[2].S.DOWN), int(g[2].S.GETUP)]:
		downed = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			g = stage.camp.grunts
			for i in range(g.size()):
				TK.calm(g[i])
				hp.append(g[i].health.current_health)
			# 0 faces the flash, 1 has his back to it
			var f0: Vector3 = -g[0].facing.global_basis.z
			var f1: Vector3 = -g[1].facing.global_basis.z
			f0.y = 0.0
			f1.y = 0.0
			load("res://scripts/gadgets/gadget_zone.gd").spawn(self, "flash", 0, g[0].global_position + f0.normalized() * 2.0, p)
			load("res://scripts/gadgets/gadget_zone.gd").spawn(self, "flash", 0, g[1].global_position - f1.normalized() * 2.0, p)
			_zone("star", 2, g[2])
			_zone("pepper", 1, g[3])
			_zone("caltrops", 2, g[4])
			until = TK.wait_ticks(4)
		1:
			check("the flash stuns a grunt facing it", g[0].blinded_at >= 0.0)
			check("...not one with his back to it", g[1].blinded_at < 0.0)
			check("the Mk III star hurts (%.0f -> %.0f)" % [hp[2], g[2].health.current_health], g[2].health.current_health < hp[2])
			TK.wake(g[2])
			until = TK.wait_secs(2.0)
		2:
			check("...and knocks down (state %d)" % int(g[2].state), downed)
			check("pepper hurts over time (%.0f -> %.0f)" % [hp[3], g[3].health.current_health], g[3].health.current_health < hp[3])
			check("...and he breaks off coughing", g[3].blinded_at >= 0.0)
			check("caltrops cut (%.0f -> %.0f)" % [hp[4], g[4].health.current_health], g[4].health.current_health < hp[4])
			check("...and slow him (%.2f)" % g[4].slow_k, g[4].slow_k < 1.0)
			return TK.done(fails)
	step += 1
	return false
