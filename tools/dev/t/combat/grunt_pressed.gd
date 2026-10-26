extends SceneTree
## 1.23 (Zach: grunts "sit there and spam the parry/block"): a camp hands out only max_attackers turns to attack, and a
## sword grunt without one used to circle and block whoever was hitting it until a turn came. Now a grunt being
## fought up close answers back without a turn: with both turns held by others, the one you hit still comes at you.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var g
var attacked := false
var hits := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(3.0, 0, -3.0), "role": "sword", "seed": 31},
		{"post": Vector3(20.0, 0, 20.0), "role": "sword", "seed": 32},
		{"post": Vector3(-20.0, 0, 20.0), "role": "sword", "seed": 33}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func light() -> HitData:
	var h := HitData.new()
	h.damage = 1.0
	h.knockback_force = 1.0
	h.impact = "slice"
	return h


func _process(_d: float) -> bool:
	var G = load("res://scripts/enemies/pirate_grunt.gd")
	if g and g.state in [G.S.CLOSE, G.S.WIND, G.S.SWING]:
		attacked = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var camp = stage.camp
			if camp.grunts.size() < 3:
				return false
			g = camp.grunts[0]
			# the other two hold the camp's turns and stand still
			for o in [camp.grunts[1], camp.grunts[2]]:
				o.process_mode = Node.PROCESS_MODE_DISABLED
			camp._tokens = [camp.grunts[1], camp.grunts[2]]
			g.alert()
			until = TK.wait_secs(1.5)
		1:
			check("(no turn to attack is free: %d held)" % stage.camp._tokens.size(), not stage.camp.request_token(g))
			attacked = false
			until = TK.wait_secs(0.3)
		2, 3, 4, 5, 6, 7:
			# hit it from the front, lightly, a few times
			var pl: Node3D = stage.player
			g.facing.rotation.y = atan2(-(pl.global_position.x - g.global_position.x), -(pl.global_position.z - g.global_position.z))
			g._on_hit(light(), pl)
			hits += 1
			until = TK.wait_secs(0.35)
		8:
			# (past any counter-slash straight off its guard: that one it always had)
			until = TK.wait_secs(0.6)
		9:
			attacked = false
			until = TK.wait_secs(4.0)
		10:
			check("the grunt you were fighting comes at you after, without a turn of its own (after %d hits)" % hits, attacked)
			return TK.done(fails)
	step += 1
	return false
