extends SceneTree
## The pocket glider (1.28): refused on the ground; opened falling from 12 m it sinks slowly at the tier's rate while
## carrying you ahead at its speed, the wing out over you; jump folds it (back to a fall, the wing gone).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var y0 := 0.0
var y1 := 0.0
var z1 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


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
			y0 = p.global_position.y
			p.gadgets.give("glider", 0)
			check("on the ground it won't open", not p.gadgets.fire() and p.current_state_name() != "Gadget")
			p.global_position += Vector3.UP * 12.0
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.state_machine.force_state("Fall", {})
			until = TK.wait_ticks(10)
		1:
			check("falling, it opens", p.gadgets.fire() and p.current_state_name() == "Gadget")
			until = TK.wait_secs(0.6)
		2:
			check("the wing is out over the captain", p.body_model.torso.find_child("GliderWing", false, false) != null)
			y1 = p.global_position.y
			z1 = p.global_position.z
			until = TK.wait_secs(1.0)
		3:
			var sink: float = y1 - p.global_position.y
			var ahead: float = absf(p.global_position.z - z1) + absf(p.global_position.x)
			print("   sank %.2f m, went %.2f m in 1 s" % [sink, ahead])
			check("it sinks slowly (%.2f m in 1 s)" % sink, sink > 1.0 and sink < 3.5)
			check("...and glides ahead (%.2f m)" % ahead, ahead > 6.0)
			TK.act("jump")
			until = TK.wait_ticks(4)
		4:
			check("jump folds it: falling again", p.current_state_name() == "Fall")
			until = TK.wait_ticks(2)
		5:
			check("...the wing put away", p.body_model.torso.find_child("GliderWing", false, false) == null)
			return TK.done(fails)
	step += 1
	return false
