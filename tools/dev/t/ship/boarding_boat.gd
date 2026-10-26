extends SceneTree
## Boarding boats (docs/v1_23_plan.md, sea pursuit): a pirate that can't catch the crew's ship lowers a longboat with
## the next men of her crew at the oars; they row for the crew's side while she sails and leap aboard as boarders.
## A crew ball splashing down by a boat sinks it, men and all.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var es
var boat
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
			es = load("res://scripts/ship/enemy_ship.gd").new().setup(ship.global_position, 90.0, 0.0, 7, "brig")
			es.name = "Brig"
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			until = TK.wait_secs(6.0)
		1:
			var right: Vector3 = ship.global_basis.x
			es._pos = ship.global_position + right * 55.0 + ship.global_basis.z * 20.0
			es._heading = ship.global_rotation.y
			es.speed = 2.0
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), es._pos + Vector3(0, 1.45, 0))
			es.reset_physics_interpolation()
			es._set_state(es.S.BROADSIDE)
			es._volleys = 1
			es._volley_cd = 1000.0
			es._ram_cd = 1000.0
			es._board_cd = 1000.0
			es._boat_cd = 0.0
			until = TK.wait_secs(3.0)
		2:
			var boats: Array = get_nodes_in_group("boarding_boats")
			check("she can't catch them: a boat is lowered (%d)" % boats.size(), boats.size() == 1)
			if boats.is_empty():
				return TK.done(fails)
			boat = boats[0]
			check("...her own men in it, at the oars (%d)" % boat.men.size(), boat.men.size() >= 2 and boat._bodies.all(func(h): return h.get_parent() == boat and h.seated))
			until = TK.wait_secs(25.0)
		3:
			var aboard: Array = es.boarders.filter(func(g): return is_instance_valid(g) and ship.aboard(g.global_position))
			print("   boat %s, boarders %d (%d on her deck)" % [boat.B.keys()[boat.state] if is_instance_valid(boat) else "gone", es.boarders.size(), aboard.size()])
			check("the boat reached her side: the men leapt aboard (%d)" % aboard.size(), aboard.size() >= 2)
			# a second ship's boat, holed by a crew ball before it gets there
			var es2 = load("res://scripts/ship/enemy_ship.gd").new().setup(ship.global_position, 90.0, 0.0, 8, "brig")
			es2.name = "Brig2"
			stage.add_child(es2)
			es2.set_meta("no_sleep", true)
			var left: Vector3 = -ship.global_basis.x
			es2._pos = ship.global_position + left * 60.0 + ship.global_basis.z * 15.0
			es2._heading = ship.global_rotation.y
			es2.global_transform = Transform3D(Basis(Vector3.UP, es2._heading), es2._pos + Vector3(0, 1.45, 0))
			es2.reset_physics_interpolation()
			es2._set_state(es2.S.BROADSIDE)
			es2._volleys = 1
			es2._volley_cd = 1000.0
			es2._ram_cd = 1000.0
			es2._board_cd = 1000.0
			es2._boat_cd = 0.0
			until = TK.wait_secs(2.0)
		4:
			var boats: Array = get_nodes_in_group("boarding_boats").filter(func(b): return b.state == b.B.ROWING)
			check("another boat on the water", boats.size() == 1)
			if boats.is_empty():
				return TK.done(fails)
			boat = boats[0]
			load("res://scripts/ship/boarding_boat.gd").near_splash(self, boat.global_position + Vector3(2.0, 0, 0), 30.0, ship)
			until = TK.wait_secs(1.0)
		5:
			check("a crew ball splashing down beside it sinks it (%s)" % boat.B.keys()[boat.state], boat.state == boat.B.SUNK)
			return TK.done(fails)
	step += 1
	return false
