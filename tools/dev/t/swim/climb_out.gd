extends SceneTree
## Climbing out of the water onto a ledge: a rock standing 1.6 m out of the calm sea (up to 2.2 m over the
## passing wave is in reach) shows the climb-out prompt when you swim up facing it, and Space hauls you up.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rock: StaticBody3D
var step := 0
var until := 0
var fails := 0
var top_y := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true})


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
			# a flat-topped rock out in the water, its top 1.6 m over the calm sea
			rock = StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(3, 12, 3)
			cs.shape = bs
			rock.add_child(cs)
			stage.add_child(rock)
			top_y = 1.6
			rock.global_position = Vector3(stage.SHORE_X + 12.0, top_y - 6.0, 0)
			p.global_position = Vector3(stage.SHORE_X + 12.0 + 2.2, 1.0, 0)
			p.reset_physics_interpolation()
			p.player_model.rotation.y = PI * 0.5
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(1.2)
		1:
			p.player_model.rotation.y = PI * 0.5
			until = TK.wait_ticks(15)
		2:
			var h: float = top_y - float(p.water_surface())
			var prompt: String = stage.hud._prompt.text if stage.hud._prompt.visible else ""
			print("   ledge ", snappedf(h, 0.01), " m over the water; prompt '", prompt, "'")
			check("facing a rock %.1f m over the water: the climb-out prompt" % h, prompt.contains("climb out"))
			TK.act("jump")
			until = TK.wait_ticks(6)
		3:
			check("Space: hauls up onto it (Climb)", p.current_state_name() == "Climb")
			until = TK.wait_secs(1.6)
		4:
			print("   after the haul: y ", snappedf(p.global_position.y, 0.01), " ", p.current_state_name())
			check("standing on top of the rock", absf(p.global_position.y - top_y) < 0.2 and p.current_state_name() in ["Idle", "Move", "Fall"])
			check("...the prompt's gone", not stage.hud._prompt.visible or stage.hud._prompt.text == "")
			return TK.done(fails)
	step += 1
	return false
