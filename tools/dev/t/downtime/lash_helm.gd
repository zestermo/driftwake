extends SceneTree
## Lashing the helm: at the wheel the action wheel offers "Lash the helm"; picking it steps you off the wheel
## with a rope on it, and she holds her heading with nobody steering, even knocked off it by a wave (an unlashed
## ship stays wherever she was knocked). Taking the wheel casts the lashing off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var AW
var course := 0.0
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


func off_course() -> float:
	return absf(wrapf(ship._heading - course, -PI, PI))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			AW = load("res://scripts/game/action_wheel.gd")
			p.global_position = ship.global_transform * Vector3(0, ship.DECK_Y + 0.3, 2.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			ship.sail = 1.0 / 3.0
			ship.speed = 3.0
			until = TK.wait_ticks(5)
		2:
			check("at the wheel the wheel offers Lash the helm (%s)" % str(AW.entries_for(p)), AW.place(p) == "helm" and AW.entries_for(p) == ["lash"])
			course = ship._heading
			AW.run("lash", p)
			until = TK.wait_ticks(5)
		3:
			check("lashing steps you off the wheel (%s)" % p.current_state_name(), p.current_state_name() != "Helm" and not ship.is_player_steering)
			check("...the helm is lashed to her heading, a rope on the wheel", ship.lashed and is_equal_approx(ship.lash_heading, course) \
				and ship.ship_model.get_node("HelmLashing").visible)
			# a sea knocks her bow round
			ship._heading += 0.4
			until = TK.wait_secs(7.0)
		4:
			print("   off course after the knock: %.3f rad, sail %.2f, speed %.1f" % [off_course(), ship.sail, ship.speed])
			check("knocked off her course, the lashed helm brings her back (%.3f rad)" % off_course(), off_course() < 0.04)
			check("...still under the sail she had", is_equal_approx(ship.sail, 1.0 / 3.0) and ship.speed > 1.0)
			# unlashed, a knock stays
			load("res://scripts/ship/lashed_helm.gd").apply(ship, false, 0.0)
			course = ship._heading
			ship._heading += 0.4
			until = TK.wait_secs(4.0)
		5:
			check("unlashed, nobody steering: she stays where the sea put her (%.3f rad)" % off_course(), off_course() > 0.3)
			root.get_node("/root/Net").lash_helm(true, ship._heading)
			p.state_machine.force_state("Helm", {})
			until = TK.wait_ticks(3)
		6:
			check("taking the wheel casts the lashing off", p.current_state_name() == "Helm" and not ship.lashed \
				and not ship.ship_model.get_node("HelmLashing").visible)
			ship.sail = 0.0
			return TK.done(fails)
	step += 1
	return false
