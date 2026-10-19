extends SceneTree
## A rip current carries a swimmer treading water straight out to sea, swimming against it barely gains,
## and swimming along the shore takes you out of it (then the drift stops).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var x0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


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
			var sc = load("res://scripts/swim/sea_currents.gd").new()
			sc.name = "SeaCurrents"
			stage.add_child(sc)
			# a rip running out from the shore along +x
			sc.rips["test"] = [[Vector2(stage.SHORE_X, 0.0), Vector2(stage.SHORE_X + 50.0, 0.0), 8.0]]
			p.global_position = Vector3(stage.SHORE_X + 8.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(0.6)
		1:
			x0 = p.global_position.x
			until = TK.wait_secs(2.0)
		2:
			var moved: float = p.global_position.x - x0
			print("   treading in the rip: carried ", snappedf(moved, 0.01), " m out in 2 s")
			check("treading water in a rip: carried out to sea (%.1f m in 2 s)" % moved, moved > 3.0)
			check("...still swimming", p.current_state_name() == "Swim")
			# head for the beach against it
			p.global_position = Vector3(stage.SHORE_X + 10.0, p.global_position.y, 0)
			p.reset_physics_interpolation()
			x0 = p.global_position.x
			TK.press("move_left")
			until = TK.wait_secs(2.0)
		3:
			var gained: float = x0 - p.global_position.x
			print("   against it: gained ", snappedf(gained, 0.01), " m in 2 s")
			check("swimming straight against it: barely gains (%.1f m in 2 s)" % gained, gained < 2.5)
			TK.release("move_left")
			TK.press("move_forward")
			until = TK.wait_secs(3.0)
		4:
			TK.release("move_forward")
			check("swum along the shore: out of it (%.1f m off its line)" % absf(p.global_position.z), absf(p.global_position.z) > 6.0)
			x0 = p.global_position.x
			until = TK.wait_secs(1.5)
		5:
			var drift: float = p.global_position.x - x0
			check("...and no longer carried (%.2f m in 1.5 s)" % drift, absf(drift) < 0.6)
			return TK.done(fails)
	step += 1
	return false
