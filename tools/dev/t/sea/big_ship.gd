extends SceneTree
## The big named ships: a warlord's flagship is drawn half as big again with her men at their own size; she comes
## for the crew's ship; a captain on her deck stands on it and her crew turns to fight (at their own size); with them
## down her captain steps out on the quarterdeck after the intro and duels; beaten, the captain yields and she
## strikes: the captain's chest and a big bounty. An Admiralty warship: "Swing aboard" from the crew's deck alongside
## lands you on hers; sunk from afar she leaves no chest.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var big
var war
var step := 0
var until := 0
var fails := 0
var bounty0 := 0


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
	var SeaStops = load("res://scripts/sea/sea_stops.gd")
	match step:
		0:
			p = stage.player
			ship = stage.ship
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			big = SeaStops.big(stage, "flagship", ship.global_position + Vector3(120, 0, 0), 12, 4242)
			big.set_meta("no_sleep", true)
			until = TK.wait_secs(8.0)
		1:
			check("she's drawn half as big again (x%.2f)" % big.global_basis.x.length(), absf(big.global_basis.x.length() - 1.5) < 0.02)
			var man: Node3D = big._crew[1]["node"]
			check("...her men at their own size (x%.2f)" % man.global_basis.x.length(), absf(man.global_basis.x.length() - 1.0) < 0.05)
			check("she comes for the crew's ship (%s)" % big.S.keys()[big.state], big.state in [big.S.HUNT, big.S.BROADSIDE])
			var full: float = big._max_speed()
			big.hull = big.max_hull * 0.6
			check("battered, she loses way so the crew can come alongside (%.1f -> %.1f m/s)" % [full, big._max_speed()], big._max_speed() <= 2.5 and full > 6.0)
			big.hull = big.max_hull
			big._set_state(big.S.PATROL)
			big.speed = 0.0
			bounty0 = p.bounty
			p.global_position = big.to_global(Vector3(1.0, 0.6, -1.0))
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.0)
		2:
			check("a captain on her deck stands aboard her", big.aboard(p.global_position) and p.is_on_floor())
			check("...and her crew turns to fight (%d)" % big.deck_crew.size(), big.state == big.S.DECK and big.deck_crew.size() >= 6)
			var g: Node3D = big.deck_crew[0]
			var body: Node3D = big._crew[1]["node"]
			check("...at their own size (x%.2f)" % body.global_basis.x.length(), absf(body.global_basis.x.length() - 1.0) < 0.05)
			for gg in big.deck_crew:
				if is_instance_valid(gg):
					gg.health.take_damage(99999.0)
			until = TK.wait_secs(12.0)
		3:
			check("with her crew down her captain steps out and duels (%s)" % big.duel, big.duel == "duel" and is_instance_valid(big.captain))
			check("...on her quarterdeck", big.aboard(big.captain.global_position) and big.to_local(big.captain.global_position).y > 2.0)
			check("...tougher than a rival", big.captain.health_component.max_health > 400.0)
			big.captain.health_component.take_damage(1e9)
			until = TK.wait_secs(5.0)
		4:
			check("beaten, the captain yields and she strikes (%s)" % big.S.keys()[big.state], big.state == big.S.PRIZE and not is_instance_valid(big.captain))
			check("...the captain's chest aboard", big.get_node("Model").find_children("Prize_*", "LootBag", false, false).size() == 1)
			check("...a big bounty (%d -> %d)" % [bounty0, p.bounty], p.bounty >= bounty0 + 4000)
			p.global_position = ship.to_global(Vector3(2.5, 0.6, -1.0))
			p.reset_physics_interpolation()
			war = SeaStops.big(stage, "warship", ship.global_position + Vector3(400, 0, 400), 12, 777)
			war.set_meta("no_sleep", true)
			until = TK.wait_ticks(10)
		5:
			# (lying still alongside: PRIZE holds her where she is)
			war._set_state(war.S.PRIZE)
			war.speed = 0.0
			var side: Vector3 = ship.global_basis.x
			war._pos = ship.global_position + side * 15.0
			war._pos.y = 0.0
			war._heading = ship.global_rotation.y
			until = TK.wait_ticks(6)
		6:
			check("the warship is the Admiralty's", war.is_in_group("admiralty"))
			war._swing_aboard(p, -1.0)
			until = TK.wait_secs(1.5)
		7:
			check("'Swing aboard' from the crew's deck lands you on hers (%s, floor %s)" % [war.to_local(p.global_position), p.is_on_floor()],war.aboard(p.global_position) and p.is_on_floor())
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			war._start_sink()
			until = TK.wait_secs(3.0)
		8:
			check("sunk from afar she leaves no chest", stage.find_children("Flotsam_*", "LootBag", true, false).is_empty() and root.find_children("Flotsam_*", "LootBag", true, false).is_empty())
			return TK.done(fails)
	step += 1
	return false
