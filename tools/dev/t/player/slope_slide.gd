extends SceneTree
## The slope slide (1.30, free for everyone): C while running down a slope drops you into a slide that speeds up down
## it; jump launches out of it keeping some of its speed (Slide Jump: all of it); on the flat, C is still the sneak.
## C pressed on the way down lands you into one. Co-op: the slide is an action, so puppets play it.
const TK := preload("res://tools/dev/test_kit.gd")
const SLOPE := 0.38
var stage
var p
var step := 0
var until := 0
var fails := 0
var v1 := 0.0
var ramp_top := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	var ramp := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 12.0)
	cs.shape = box
	ramp.add_child(cs)
	ramp.rotation.z = -SLOPE
	ramp.position = Vector3(40.0, stage.GROUND_Y + 2.0, 0)
	stage.add_child(ramp)
	# (the top face's point above x = 20, uphill of the centre)
	var n := Vector3.UP.rotated(Vector3.BACK, -SLOPE)
	var along := Vector3.RIGHT.rotated(Vector3.BACK, -SLOPE)
	ramp_top = ramp.position + n * 0.5 + along * -20.0


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func hspeed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			TK.act("crouch")
			until = TK.wait_ticks(4)
		1:
			check("on the flat, C is the sneak (%s)" % p.current_state_name(), p.current_state_name() == "Crouch")
			TK.act("crouch")
			p.global_position = ramp_top + Vector3(0, 0.6, 0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.5)
		2:
			TK.press("move_right")
			until = TK.wait_secs(0.4)
		3:
			TK.act("crouch")
			until = TK.wait_ticks(4)
		4:
			check("running down the slope, C is the slide (%s)" % p.current_state_name(), p.current_state_name() == "Slide" and p.body_model.current_action() == "slide")
			TK.release("move_right")
			until = TK.wait_secs(0.4)
		5:
			v1 = hspeed()
			until = TK.wait_secs(0.8)
		6:
			print("   slide %.1f -> %.1f m/s" % [v1, hspeed()])
			check("it speeds up down the slope (%.1f -> %.1f)" % [v1, hspeed()], p.current_state_name() == "Slide" and hspeed() > v1 + 2.0)
			check("...faster than a run", hspeed() > p.move_speed)
			v1 = hspeed()
			TK.act("jump")
			until = TK.wait_ticks(3)
		7:
			check("jump launches out of it with its speed (%.1f of %.1f)" % [hspeed(), v1], p.current_state_name() == "Jump" and hspeed() >= v1 * 0.55)
			TK.act("crouch")
			until = TK.wait_secs(1.5)
		8:
			check("C on the way down lands into a slide (%s)" % p.current_state_name(), p.current_state_name() == "Slide")
			return TK.done(fails)
	step += 1
	return false
