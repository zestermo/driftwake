extends SceneTree
## Chain shot (docs/v1_23_plan.md, sea pursuit): a brig fires it at a crew getting away; through the mainsail it tears
## the canvas and the ship sails slower until a captain mends it at the foot of the mast (hold F).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var es
var step := 0
var until := 0
var fails := 0
var whole_speed := 0.0


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
	match step:
		0:
			p = stage.player
			ship = stage.ship
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			ship.sail = 1.0
			ship.sail_shown = 1.0
			es = load("res://scripts/ship/enemy_ship.gd").new().setup(ship.global_position + Vector3(0, 0, 400), 30.0, 0.0, 5, "brig")
			stage.add_child(es)
			# (she only fires the chain shot here: held where she is, or she'd come over and board)
			es.set_physics_process(false)
			until = TK.wait_secs(10.0)
		1:
			whole_speed = ship.speed
			check("a brig carries chain shot for a crew under full sail getting away", es._wants_chain(ship))
			var sloop = load("res://scripts/ship/enemy_ship.gd").KINDS["sloop"]
			check("...a plain sloop doesn't", not sloop.get("chain", false))
			# a chain ball across her beam, through the mainsail
			var CB = load("res://scripts/ship/cannonball.gd")
			# (through the canvas abaft the mast, so it flies on into the sea rather than bursting on the mast)
			var from: Vector3 = ship.to_global(Vector3(30.0, 11.5, -0.2))
			var to: Vector3 = ship.to_global(Vector3(-10.0, 10.0, -0.2))
			var b = CB.launch(self, from, (to - from).normalized() * 46.0 + ship.hull_velocity(), "enemy", true, es, es, "test#1", true)
			b.hull_damage = 7.0
			until = TK.wait_secs(1.5)
		2:
			check("through the sail: the canvas is torn (%d)" % ship.torn.size(), ship.torn.size() == 1)
			check("...a tear shows on the sail", ship._tears.size() == 1)
			until = TK.wait_secs(12.0)
		3:
			print("   whole %.2f m/s, torn %.2f m/s" % [whole_speed, ship.speed])
			check("torn, she sails slower (%.1f < %.1f)" % [ship.speed, whole_speed], ship.speed < whole_speed * 0.9)
			ship.sail = 0.0
			ship.speed = 0.0
			until = TK.wait_secs(2.0)
		4:
			var slot: int = ship.torn[0][1]
			p.global_position = ship.to_global(ship.MEND_AT[slot] + Vector3(0, 0.3, 0))
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.5)
		5:
			check("at the foot of the mast the job is mending the sail (%s at %s, %s)" % [ship.local_job, ship.to_local(p.global_position), ship.torn], ship.local_job == "mend")
			TK.press("interact")
			until = TK.wait_secs(ship.job_time("mend") + 1.0)
		6:
			TK.release("interact")
			check("held F long enough: the sail is mended (%s, %s, %s)" % [ship.torn, ship.local_job, p.current_state_name()], ship.torn.is_empty() and ship._tears.is_empty())
			check("...and she has her speed back", is_equal_approx(ship.sail_k(), 1.0))
			return TK.done(fails)
	step += 1
	return false
