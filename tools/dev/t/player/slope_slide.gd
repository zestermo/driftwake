extends SceneTree
## The slope slide (1.30.2, free for everyone, no key): running down steep hill ground (an island's Terrain) starts one
## by itself, a gentle hill doesn't; stood up side-on, it speeds up down the slope up to its top speed; jump launches
## out of it; a fall onto steep ground lands into one; C is still the sneak and does nothing mid-slide; at the bottom
## it hands back to a run. Co-op: the slide is an action, so puppets play it.
const TK := preload("res://tools/dev/test_kit.gd")
const STEEP := 0.6
const GENTLE := 0.38
## SlideState.TOP
const TOP := 11.0
var stage
var p
var step := 0
var until := 0
var fails := 0
var v1 := 0.0
var top_steep := Vector3.ZERO
var top_gentle := Vector3.ZERO
var slid := false
var deadline := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	top_steep = _ramp(STEEP, 0.0)
	top_gentle = _ramp(GENTLE, 24.0)


## A 60 m hill face (named Terrain like an island's) going down towards +x, at z; its top face's point above x = 20.
func _ramp(slope: float, z: float) -> Vector3:
	var ramp := StaticBody3D.new()
	ramp.name = "Terrain"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 12.0)
	cs.shape = box
	ramp.add_child(cs)
	ramp.rotation.z = -slope
	ramp.position = Vector3(40.0, stage.GROUND_Y + 2.0, z)
	stage.add_child(ramp)
	var n := Vector3.UP.rotated(Vector3.BACK, -slope)
	var along := Vector3.RIGHT.rotated(Vector3.BACK, -slope)
	return ramp.position + n * 0.5 + along * -20.0


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func hspeed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func put(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


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
			put(top_gentle + Vector3(0, 0.6, 0))
			until = TK.wait_secs(0.4)
		2:
			TK.press("move_right")
			slid = false
			deadline = TK.wait_secs(1.0)
			until = TK.wait_ticks(1)
		3:
			slid = slid or p.current_state_name() == "Slide"
			if TK.ticking(deadline):
				return false
			check("running down a gentle hill is just a run", not slid)
			TK.release("move_right")
			put(top_steep + Vector3(0, 0.6, 0))
			until = TK.wait_secs(0.4)
		4:
			TK.press("move_right")
			until = TK.wait_secs(0.5)
		5:
			check("running down a steep hill starts the slide by itself (%s)" % p.current_state_name(), p.current_state_name() == "Slide" and p.body_model.current_action() == "slide")
			TK.release("move_right")
			until = TK.wait_secs(0.3)
		6:
			var fwd: Vector3 = -p.player_model.global_basis.z
			check("stood side-on to the slide", absf(fwd.normalized().dot(p.velocity.normalized())) < 0.5)
			v1 = hspeed()
			TK.act("crouch")
			until = TK.wait_secs(0.6)
		7:
			print("   slide %.1f -> %.1f m/s" % [v1, hspeed()])
			check("C mid-slide does nothing (%s)" % p.current_state_name(), p.current_state_name() == "Slide")
			check("it speeds up down the slope (%.1f -> %.1f)" % [v1, hspeed()], hspeed() > v1 + 1.0)
			check("...but stays under its top speed", hspeed() <= TOP + 0.5)
			v1 = hspeed()
			TK.act("jump")
			until = TK.wait_ticks(3)
		8:
			check("jump launches out of it with its speed (%.1f of %.1f)" % [hspeed(), v1], p.current_state_name() == "Jump" and hspeed() >= v1 * 0.55)
			put(top_steep + Vector3(0, 5.0, 0))
			until = TK.wait_secs(1.5)
		9:
			check("a fall onto steep ground lands into a slide (%s)" % p.current_state_name(), p.current_state_name() == "Slide")
			until = TK.wait_secs(5.0)
		10:
			check("at the bottom it hands back to a run or a stand (%s)" % p.current_state_name(), p.current_state_name() in ["Move", "Idle"])
			return TK.done(fails)
	step += 1
	return false
