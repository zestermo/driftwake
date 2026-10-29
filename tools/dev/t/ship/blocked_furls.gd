extends SceneTree
## Brought up short (1.26, docs/v1_26_plan.md): the crew's ship under sail runs into another ship lying across her bow
## and is stopped dead; she furls her sails (Ship._brought_up), so captains thrown off her or fighting aboard the other
## ship aren't left watching her sail away.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var ship
var es
var step := 0
var until := 0
var fails := 0
var v0 := 0.0


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
	match step:
		0:
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			ship = stage.ship
			ship.hull = 99999.0
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			ship.sail = 1.0
			ship.sail_shown = 1.0
			until = TK.wait_secs(12.0)
		1:
			v0 = ship.speed
			# a ship lying still across her bow, 30 m on
			var fwd: Vector3 = -ship.global_basis.z
			var ES = load("res://scripts/ship/enemy_ship.gd")
			es = ES.new().setup(ship.global_position + fwd * 30.0, 30.0, 0.0, 12, "sloop")
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			es.global_transform = Transform3D(Basis(Vector3.UP, ship.global_rotation.y + PI * 0.5), ship.global_position + fwd * 30.0 + Vector3(0, HullBuilder.FREEBOARD, 0))
			es._pos = Vector3(es.global_position.x, 0.0, es.global_position.z)
			es._heading = ship.global_rotation.y + PI * 0.5
			es.reset_physics_interpolation()
			es.set_physics_process(false)
			until = TK.wait_secs(10.0)
		2:
			print("   %.1f m/s -> %.1f m/s, sail %.2f" % [v0, ship.speed, ship.sail])
			check("under way at first (%.1f m/s)" % v0, v0 > ship.STOP_FROM)
			check("run into a ship across her bow: stopped (%.1f m/s)" % ship.speed, absf(ship.speed) < 1.5)
			check("...and her sails furled", ship.sail == 0.0)
			return TK.done(fails)
	step += 1
	return false
