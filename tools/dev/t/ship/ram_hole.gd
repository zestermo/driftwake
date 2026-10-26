extends SceneTree
## Rams (docs/v1_23_plan.md, sea pursuit): a pirate's bow driven into the crew's hull holes her at the waterline
## where it struck (she floods until it's patched), on top of the hull damage and the jolt.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var es
var step := 0
var until := 0
var fails := 0
var hull0 := 0.0


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
			p.global_position = ship.to_global(Vector3(-1.5, 0.6, 6.0))
			p.reset_physics_interpolation()
			var right: Vector3 = ship.global_basis.x
			es = load("res://scripts/ship/enemy_ship.gd").new().setup(ship.global_position + right * 40.0, 90.0, 0.0, 9, "brig")
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			# bow on to her starboard beam
			var at: Vector3 = ship.global_position + right * 30.0
			es._pos = Vector3(at.x, 0, at.z)
			es._heading = atan2(right.x, right.z)
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), es._pos + Vector3(0, 1.45, 0))
			es.reset_physics_interpolation()
			es.speed = 8.0
			es._set_state(es.S.RAM)
			hull0 = ship.hull
			until = TK.wait_secs(8.0)
		1:
			print("   hull %.0f -> %.0f, breaches %s" % [hull0, ship.hull, ship.breaches])
			check("rammed: her hull took it", ship.hull < hull0 - 10.0)
			check("...and a brig's bow holed her: two holes (or three, if the blow itself holed her too)", ship.breaches.size() >= 2)
			check("...on the side she was struck (starboard)", ship.breaches.all(func(b): return b[1].x > 0.0))
			until = TK.wait_secs(6.0)
		2:
			check("holed, she takes on water (%.3f)" % ship.flood, ship.flood > 0.0)
			return TK.done(fails)
	step += 1
	return false
