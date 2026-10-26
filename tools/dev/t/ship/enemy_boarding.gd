extends SceneTree
## A pirate ship that has been broadsiding the crew's sloop for a while closes alongside and boards, even when
## the crew sails faster than a plain pursuer could catch (the old gate: only a slower crew was ever boarded).
## The grapples fly first (the telegraph, >= 1 s), then the men leap across.
const TK := preload("res://tools/dev/test_kit.gd")
const BOARD_WITHIN := 60.0
var stage
var p
var ship
var es
var step := 0
var until := 0
var fails := 0
var fight_ticks := 0
var hook_tick := -1
var board_tick := -1
var gap := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(_d: float) -> bool:
	if step != 2:
		return false
	fight_ticks += 1
	if hook_tick < 0 and es._hook_t >= 0.0:
		hook_tick = fight_ticks
	if board_tick < 0 and es._crew_gone > 0:
		board_tick = fight_ticks
	return false


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
			ship.apply_kit({"sails": 5, "copper": 3})
			ship.sail = 1.0
			ship.sail_shown = 1.0
			es = load("res://scripts/ship/enemy_ship.gd").new().setup(ship.global_position, 90.0, 0.0, 7, "sloop")
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			until = TK.wait_secs(8.0)
		1:
			var right: Vector3 = ship.global_basis.x
			es._pos = ship.global_position + right * 34.0
			es._heading = ship.global_rotation.y
			es.speed = ship.speed
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), es._pos + Vector3(0, 1.45, 0))
			es._set_state(es.S.BROADSIDE)
			es._volleys = 1
			es._volley_cd = 1000.0
			es._board_cd = 0.0
			# (alongside with grapples, not a boat rowed over: t/ship/boarding_boat)
			es._boat_cd = 1000.0
			check("the crew sails too fast for the pirates to catch plainly (%.1f m/s, her top %.1f m/s)" % [ship.speed, es._max_speed()], ship.speed > es._max_speed() - 0.5)
			until = TK.wait_secs(BOARD_WITHIN)
		2:
			var secs := float(fight_ticks) / Engine.physics_ticks_per_second
			print("   grapples at %.1f s, men over at %.1f s, state %s, %.0f m off" % [float(hook_tick) / Engine.physics_ticks_per_second, float(board_tick) / Engine.physics_ticks_per_second, es.S.keys()[es.state], es.global_position.distance_to(ship.global_position)])
			check("she boards within %d s" % int(BOARD_WITHIN), board_tick > 0)
			check("...the grapples flew first, a second or more before the men leapt", hook_tick > 0 and board_tick - hook_tick >= int(Engine.physics_ticks_per_second))
			check("...the boarders are her own crewmen, over on the crew's deck side", es.boarders.size() >= 2)
			return TK.done(fails)
	step += 1
	return false
