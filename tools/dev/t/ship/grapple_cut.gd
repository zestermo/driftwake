extends SceneTree
## Grapples (docs/v1_23_plan.md, sea pursuit): a pirate alongside lashes the crew's ship to hers; lashed, the ship
## barely makes way and the pirate holds alongside; cutting every line at the rail (hold F, or a crewmate's cut sent
## through Net.ship_work) frees her and the pirate breaks off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var es
var step := 0
var until := 0
var fails := 0


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
			es = load("res://scripts/ship/enemy_ship.gd").new().setup(ship.global_position, 90.0, 0.0, 7, "sloop")
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			until = TK.wait_secs(6.0)
		1:
			var right: Vector3 = ship.global_basis.x
			es._pos = ship.global_position + right * es.ALONGSIDE
			es._heading = ship.global_rotation.y
			es.speed = ship.speed
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), es._pos + Vector3(0, 1.45, 0))
			es.reset_physics_interpolation()
			# (her men stay aboard: this is about the lines)
			es._crew_gone = es._crew.size() - 1
			es._set_state(es.S.BOARD)
			es._board(ship)
			check("the grapples bite: three lines on the starboard rail (%d)" % ship.lines.size(), ship.lines.size() == 3 and ship.lines.all(func(l): return l[1].x > 0.0))
			check("...she's held alongside (%s)" % es.S.keys()[es.state], es.state == es.S.HOLD)
			until = TK.wait_secs(10.0)
		2:
			check("lashed, the crew's ship barely makes way (%.1f m/s)" % ship.speed, ship.speed <= ship.LASHED_SPEED + 0.3)
			check("...the pirate still alongside (%.0f m, %s)" % [es.global_position.distance_to(ship.global_position), es.S.keys()[es.state]],
				es.state == es.S.HOLD and es.global_position.distance_to(ship.global_position) < ship.LINE_SNAP)
			check("...a rope runs to her rail", ship._ropes.size() == 3)
			p.global_position = ship.to_global(ship.lines[0][1] + Vector3(-0.3, 0.3, 0))
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.5)
		3:
			check("at the rail the job is cutting the line (%s)" % ship.local_job, ship.local_job == "cut")
			TK.press("interact")
			until = TK.wait_secs(ship.job_time("cut") + 0.8)
		4:
			TK.release("interact")
			check("held F: a line cut (%d left, %.0f m off)" % [ship.lines.size(), es.global_position.distance_to(ship.global_position)], ship.lines.size() == 2)
			for l in ship.lines.duplicate():
				root.get_node("Net").ship_work("cut", int(l[0]), 0.0)
			until = TK.wait_secs(1.0)
		5:
			check("every line cut: free", ship.lines.is_empty() and ship._ropes.is_empty())
			check("...the pirate breaks off (%s)" % es.S.keys()[es.state], es.state != es.S.HOLD)
			until = TK.wait_secs(8.0)
		6:
			check("free, she makes way again (%.1f m/s)" % ship.speed, ship.speed > ship.LASHED_SPEED + 2.0)
			return TK.done(fails)
	step += 1
	return false
