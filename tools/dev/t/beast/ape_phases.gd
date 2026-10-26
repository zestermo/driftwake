extends SceneTree
## 1.23 beast pass: the Silverback's phases escalate. Phase 1 has its four moves and none of the later ones; dropping
## below 60% is a moment (it reels, rears up roaring, a ring pushes the captain 7 m off back and the look changes:
## steam on its breath) and adds the canopy and the Rock Barrage; below 30% adds the Grab and the Berserk Pound, and it
## chains three moves; its openings shorten phase by phase; the pound cracks the floor four times walking in.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ape
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _hp() -> float:
	return p.get_node("HealthComponent").current_health


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			var at: Vector3 = p.global_position + Vector3(0, 0, -12.0)
			ape = load("res://scripts/enemies/jungle_ape.gd").new()
			ape.setup({"post": at, "mode": "stand", "seed": 3})
			ape.level = 6
			stage.add_child(ape)
			ape.global_position = at + Vector3.UP * 0.3
			until = TK.wait_ticks(10)
		1:
			var m: Array = ape.moves()
			check("phase 1: swipe, slam, leap and throw, nothing later (%s)" % str(m), m.size() == 4 and "swipe" in m and "throw" in m and not "pound" in m and not "climb" in m)
			ape.alert()
			until = TK.wait_secs(2.5)
		2:
			ape._special = ""
			ape._set_state(2)
			p.global_position = ape.global_position + Vector3(0, 0, 6.0)
			p.reset_physics_interpolation()
			hp0 = _hp()
			ape.health.current_health = ape.health.max_health * 0.55
			ape._phase_check()
			check("below 60%: phase 2 and its moment (it reels first)", ape.phase == 2 and ape._special == "roar" and ape._moment and ape.humanoid.current_action() == "ape_reel")
			until = TK.wait_secs(2.6)
		3:
			var m: Array = ape.moves()
			check("...the moment's ring pushes the captain back (%.0f)" % (hp0 - _hp()), _hp() < hp0)
			check("...its breath steams now", ape._steam.size() == 1)
			check("phase 2 adds the canopy and the Rock Barrage (%s)" % str(m), "climb" in m and "barrage" in m and not "grab" in m)
			check("openings shorten: %.1f s, then %.1f, then %.1f" % [ape.OPEN[0], ape.OPEN[1], ape.OPEN[2]], ape.OPEN[0] > ape.OPEN[1] and ape.OPEN[1] > ape.OPEN[2])
			ape.health.current_health = ape.health.max_health * 0.25
			ape._phase_check()
			until = TK.wait_secs(2.8)
		4:
			var m: Array = ape.moves()
			check("phase 3 adds the Grab and the Berserk Pound (%s)" % str(m), ape.phase == 3 and "grab" in m and "pound" in m)
			check("...steam off its back too", ape._steam.size() == 2)
			ape._special = ""
			ape._set_state(2)
			ape._cd = {"swipe": 99.0, "slam": 99.0, "leap": 99.0, "throw": 99.0, "canopy": 99.0, "grab": 99.0, "barrage": 99.0, "pound": 0.0}
			ape._last_pick = ""
			var pick: String = ape._choose(8.0)
			check("...and chains three: '%s' then %d more" % [pick, ape._chain_left], pick == "pound" and ape._chain_left == 2)
			hp0 = _hp()
			p.global_position = ape.global_position + ape._fwd() * 7.0
			p.reset_physics_interpolation()
			ape._begin_special("pound")
			until = TK.wait_secs(4.0)
		5:
			check("the pound walks in and lands on the captain (%.0f)" % (hp0 - _hp()), _hp() < hp0)
			check("...then the chain goes on or the opening comes ('%s' %.1f s, state %d)" % [ape._special, ape._sp_t, ape.state], ape._special != "pound")
			return TK.done(fails)
	step += 1
	return false
