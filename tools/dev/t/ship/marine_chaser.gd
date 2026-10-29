extends SceneTree
## An Admiralty cutter running the crew down (1.26, docs/v1_26_plan.md "Marine chase"): she carries a bow chaser and
## fires it dead ahead on the way in, stays on the crew's wake instead of turning broadside while the crew makes way
## (turning bled her speed and the chase), and crowds on sail to the crew's own speed and a little more for a while.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var ship
var adm
var es
var step := 0
var until := 0
var fails := 0
var d0 := 0.0
var turned_far := false
var faster := 0
var samples := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	# (every frame of the chase: broadside while she's far and the crew's running, and her speed against theirs)
	if step == 3 and es and is_instance_valid(es):
		var d: float = es.global_position.distance_to(ship.global_position)
		if es.state == es.S.BROADSIDE and d > es.BROADSIDE_IN + 4.0 and ship.speed >= es.CHASE_SLOW:
			turned_far = true
		samples += 1
		if es.speed > ship.speed + 0.3:
			faster += 1
	if TK.ticking(until):
		return false
	var p = stage.player
	var A = load("res://scripts/ship/admiralty.gd")
	match step:
		0:
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			ship = stage.ship
			ship.hull = 99999.0
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			p.bounty = 70000
			adm = A.ensure(self)
			ship.sail = 1.0
			ship.sail_shown = 1.0
			until = TK.wait_secs(12.0)
		1:
			# a cutter 70 m astern on the same course (in her chaser's range), already on the hunt
			var back: Vector3 = ship.global_basis.z
			es = adm._spawn("marine", ship.global_position + back * 70.0, ship.global_rotation.y, 1, "ring")
			es.set_meta("no_sleep", true)
			check("a cutter carries a bow chaser on her centreline", es._chaser != null and absf(es._chaser.position.x) < 0.01)
			check("...and it never joins a broadside", not es._side_guns(1.0).has(es._chaser) and not es._side_guns(-1.0).has(es._chaser))
			until = TK.wait_ticks(2)
		2:
			d0 = es.global_position.distance_to(ship.global_position)
			until = TK.wait_secs(20.0)
		3:
			var d: float = es.global_position.distance_to(ship.global_position)
			print("   crew %.1f m/s, cutter %.1f m/s (own %.1f), %.0f m -> %.0f m, %s, chaser shots %d" % [ship.speed, es.speed, float(es.spec["speed"]), d0, d, es.S.keys()[es.state], es._chaser._shots])
			check("she closes on a crew under full sail (%.0f -> %.0f m)" % [d0, d], d < d0 - 8.0)
			check("...faster than the crew most of the chase (%d of %d frames)" % [faster, samples], faster > samples * 0.5)
			check("...her bow chaser fires on the way in (%d)" % es._chaser._shots, es._chaser._shots >= 1)
			check("...and she never turns broadside while the crew's running and she's far off", not turned_far)
			var spurt: float = es._max_speed()
			check("mid-chase she can make the crew's speed and more (%.1f vs %.1f)" % [spurt, ship.speed], spurt >= ship.speed + es.CHASE_EDGE - 0.05)
			es._chase_t = es.CHASE_SECS + 1.0
			var own: float = es._max_speed()
			check("...and after the spurt, only her own canvas (%.1f)" % own, own <= spurt and (own < spurt - 0.05 or own >= ship.speed + es.CHASE_EDGE - 0.05))
			return TK.done(fails)
	step += 1
	return false
