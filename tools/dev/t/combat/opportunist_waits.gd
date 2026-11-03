extends SceneTree
## 1.30 the Opportunist: it hangs wider than the rest and goes in only once a mate is already on the captain (the crew's
## turns capped at two: all but its own slot), or after waiting long; it does get its turn.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var o
var G
var P
var step := 0
var until := 0
var fails := 0
var went := 0
var early := 0
var o_ring := 0.0
var o_n := 0
var b_ring := 0.0
var b_n := 0
var last_state := -1


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(0, 0, -6.0), "role": "sword", "seed": 41, "personality": "opportunist"},
		{"post": Vector3(3, 0, -6.0), "role": "sword", "seed": 42, "personality": "berserker"},
		{"post": Vector3(-3, 0, -6.0), "role": "sword", "seed": 43, "personality": "berserker"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if o and G and step == 2:
		var pl: Node3D = stage.player
		if o.state != last_state and o.state in [G.S.CLOSE, G.S.WIND] and last_state == G.S.CIRCLE:
			went += 1
			var busy := 0
			for x in stage.camp.grunts:
				if x != o and (x._has_token or x.state in o.ENGAGED):
					busy += 1
			if busy == 0 and o._wait_t <= P.OPP_WAIT:
				early += 1
		last_state = o.state
		# (where each settles while circling: a while after its last move)
		for x in stage.camp.grunts:
			if x.state == G.S.CIRCLE and x.st_t > 1.0:
				var d: float = x.global_position.distance_to(pl.global_position)
				if x == o:
					o_ring += d
					o_n += 1
				else:
					b_ring += d
					b_n += 1
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 3:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			P = load("res://scripts/enemies/personality.gd")
			o = stage.camp.grunts[0]
			stage.player.hurtbox.monitorable = false
			o.alert()
			until = TK.wait_secs(0.5)
		1:
			until = TK.wait_secs(20.0)
		2:
			check("it gets its turn (%d)" % went, went >= 1)
			check("never first in while nobody's on the captain (%d of %d)" % [early, went], early == 0)
			var orr := o_ring / maxf(o_n, 1)
			var brr := b_ring / maxf(b_n, 1)
			check("it hangs wider than the berserkers (%.1f vs %.1f m)" % [orr, brr], orr > brr + 0.4)
			return TK.done(fails)
	step += 1
	return false
