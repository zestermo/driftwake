extends SceneTree
## The better strokes: a tap of Shift is a burst of speed (and costs stamina, not again at once), held under
## water it's the faster dolphin kick, Space at a sprint with nothing to climb leaps you out of the water and
## back in, and swimming into the ship's ladder takes hold of it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var x0 := 0.0
var st0 := 0.0
var top := -INF
var tracking := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(_d: float) -> bool:
	if tracking:
		top = maxf(top, p.global_position.y - float(p.water_surface()))
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			# (well clear of the ship, riding at z 0)
			p.global_position = Vector3(stage.SHORE_X + 4.0, 1.0, 30.0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(1.0)
		1:
			# along +x (the camera looks down -z: right is +x)
			TK.press("move_right")
			until = TK.wait_secs(0.8)
		2:
			x0 = p.global_position.x
			st0 = p.stamina
			TK.press("sprint")
			until = TK.wait_ticks(9)
		3:
			var v: float = Vector2(p.velocity.x, p.velocity.z).length()
			check("a tap of Shift: a burst (%.1f m/s)" % v, v > 6.5)
			check("...that costs stamina (%.0f -> %.0f)" % [st0, p.stamina], p.stamina < st0 - 8.0)
			until = TK.wait_secs(0.6)
		4:
			var v: float = Vector2(p.velocity.x, p.velocity.z).length()
			check("...then held, a sprint stroke (%.1f m/s)" % v, v > 4.0 and v < 5.0)
			TK.release("sprint")
			# under, at a sprint: the dolphin kick
			TK.press("dodge")
			until = TK.wait_secs(0.5)
		5:
			TK.release("dodge")
			TK.press("sprint")
			until = TK.wait_secs(1.2)
		6:
			var v: float = Vector2(p.velocity.x, p.velocity.z).length()
			check("under water at a sprint: the dolphin kick (%.1f m/s)" % v, p.body_model.diving and v > 4.7)
			TK.release("sprint")
			TK.press("jump")
			until = TK.wait_secs(2.0)
		7:
			TK.release("jump")
			# back on top, at a sprint, Space: a dolphin leap
			p.stamina = p.max_stamina
			TK.press("sprint")
			until = TK.wait_secs(1.0)
		8:
			top = -INF
			tracking = true
			TK.act("jump")
			until = TK.wait_secs(1.5)
		9:
			tracking = false
			print("   leap: feet up to ", snappedf(top, 0.01), " m over the water")
			check("Space at a sprint with nothing to climb: a leap clear of the water (feet %.2f m over it)" % top, top > 0.0)
			check("...and back in, swimming", p.current_state_name() == "Swim")
			TK.release("sprint")
			TK.release("move_right")
			# swim into the ship's ladder
			var lad = stage.ship.get_node("ShipModel/LadderStarboard")
			var at: Vector3 = lad.global_transform * Vector3(0, -1.6, 2.6)
			p.global_position = Vector3(at.x, 1.0, at.z)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		10:
			check("by the ladder, not touching it: still swimming", p.current_state_name() == "Swim")
			var lad = stage.ship.get_node("ShipModel/LadderStarboard")
			var to: Vector3 = lad.global_position - p.global_position
			# toward it, by the camera: point the rig at the ladder
			stage.camera_rig.rotation.y = atan2(-to.x, -to.z)
			TK.press("move_forward")
			until = TK.wait_secs(2.0)
		11:
			TK.release("move_forward")
			check("swum into the ladder: took hold (%s)" % p.current_state_name(), p.current_state_name() == "Climb")
			return TK.done(fails)
	step += 1
	return false
