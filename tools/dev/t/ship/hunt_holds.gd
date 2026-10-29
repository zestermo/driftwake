extends SceneTree
## The hunt holds while the crew fights off their ship (1.26, docs/v1_26_plan.md): a captain swimming near her or
## fighting on a pursuer's own deck keeps the Admiralty after them, with no false "Escaped" (EnemyShip._crew_ship
## counts a captain within CREW_NEAR; a ship with captains on her deck is still pursuing). Once it truly ends, a
## patrol sunk to the last ship says so instead of "Escaped".
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var ship
var adm
var es
var step := 0
var until := 0
var fails := 0
var escaped := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
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
			adm.escaped.connect(func(): escaped += 1)
			es = adm._spawn("marine", ship.global_position + ship.global_basis.x * 60.0, ship.global_rotation.y, 1, "ring")
			es.set_meta("no_sleep", true)
			until = TK.wait_secs(3.0)
		1:
			check("hunted (%s)" % es.S.keys()[es.state], es.pursuing() and adm.hunted)
			# over the side: swimming 25 m off her
			p.global_position = ship.global_position + ship.global_basis.x * -25.0 + Vector3(0, 0.5, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_secs(5.0)
		2:
			check("a captain swimming by her: still hunted, no 'Escaped' (%s)" % es.S.keys()[es.state], es.pursuing() and adm.hunted and escaped == 0)
			# on the cutter's own deck: all hands repel boarders, and that's still the hunt
			p.global_position = es.to_global(Vector3(0.0, HullBuilder.DECK_Y + 0.6, 2.0))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.0)
		3:
			check("a captain fighting on her deck: still hunted (%s)" % es.S.keys()[es.state], es.state == es.S.DECK and es.pursuing() and adm.hunted and escaped == 0)
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			es._start_sink()
			until = TK.wait_secs(2.0)
		4:
			check("the last of the patrol sunk: not 'Escaped', and the sea goes quiet", not adm.hunted and escaped == 0 and adm._quiet_until > adm.clock + 60.0)
			return TK.done(fails)
	step += 1
	return false
