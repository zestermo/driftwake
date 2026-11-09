extends SceneTree
## (1.31) Deck jobs have bodies: holding F at the pump the captain heaves its handle (Humanoid.work "pump"), turned
## to it; beating out a fire is its own crouched pose ("douse"); letting go stands them up.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
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


func _facing(local_spot: Vector3) -> float:
	var to: Vector3 = ship.to_global(local_spot) - p.global_position
	to.y = 0.0
	return absf(wrapf(p.player_model.rotation.y - atan2(-to.x, -to.z), -PI, PI))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			ship.flood = 0.5
			var pa: Vector3 = ship.layout.pump_at
			p.global_position = ship.to_global(pa + Vector3(0.0, 0.6, 0.8))
			p.reset_physics_interpolation()
			p.player_model.rotation.y = PI * 0.5
			until = TK.wait_secs(1.0)
		1:
			check("by the pump the job is bailing (%s)" % ship.local_job, ship.local_job == "bail")
			TK.press("interact")
			until = TK.wait_secs(0.6)
		2:
			check("holding F: the pumping pose (%s)" % p.body_model.work, p.body_model.work == "pump")
			check("...turned to the pump (%.2f rad off)" % _facing(ship.layout.pump_at), _facing(ship.layout.pump_at) < 0.35)
			TK.release("interact")
			until = TK.wait_ticks(3)
		3:
			check("let go: standing again", p.body_model.work == "")
			ship.flood = 0.0
			var at := Vector3(-1.2, ship.DECK_Y, 1.5)
			ship.add_fire(at)
			p.global_position = ship.to_global(at + Vector3(0.0, 0.6, 0.9))
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.6)
		4:
			check("by the fire the job is beating it out (%s)" % ship.local_job, ship.local_job == "douse")
			TK.press("interact")
			until = TK.wait_secs(0.4)
		5:
			check("holding F: the dousing pose (%s)" % p.body_model.work, p.body_model.work == "douse")
			TK.release("interact")
			return TK.done(fails)
	step += 1
	return false
