extends SceneTree
## The climbing spike (1.28): refused with no wall in front; driven into a wall from a jump, the captain hangs on it
## (not falling), forward climbs, and jump kicks off up and away.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var y0 := 0.0
var y1 := 0.0
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
			p.gadgets.give("spike", 0)
			check("no wall in front, no spike", not p.gadgets.fire())
			var b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(6, 10, 2)
			cs.shape = bs
			b.add_child(cs)
			stage.add_child(b)
			b.global_position = p.global_position + Vector3(0, 5, -1.6)
			until = TK.wait_ticks(3)
		1:
			p.global_position += Vector3.UP * 2.0
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.state_machine.force_state("Fall", {})
			check("against the wall, it's driven in", p.gadgets.fire() and p.current_state_name() == "Gadget")
			y1 = p.global_position.y
			until = TK.wait_secs(1.0)
		2:
			check("hanging on it, not falling (%.2f)" % (p.global_position.y - y1), absf(p.global_position.y - y1) < 0.3)
			TK.press("move_forward")
			until = TK.wait_secs(0.8)
		3:
			TK.release("move_forward")
			check("forward climbs (%.2f m)" % (p.global_position.y - y1), p.global_position.y - y1 > 0.6)
			TK.act("jump")
			until = TK.wait_ticks(3)
		4:
			check("jump kicks off up and away", p.current_state_name() == "Fall" and p.velocity.y > 3.0 and p.velocity.z > 0.5)
			return TK.done(fails)
	step += 1
	return false
