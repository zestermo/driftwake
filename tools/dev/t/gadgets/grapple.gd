extends SceneTree
## The grappling hook (1.28): looking at nothing it hooks, it's refused (no cooldown spent); looking at the top of a
## 4 m block it bites, hauls the captain up the line and pops them up onto it, the line reeled back in.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var cam
var y0 := 0.0
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


func _block(at: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	b.add_child(mi)
	stage.add_child(b)
	b.global_position = at


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			cam = root.get_viewport().get_camera_3d()
			y0 = p.global_position.y
			p.gadgets.give("grapple", 0)
			cam.look_at(cam.global_position + Vector3(0, 1, -0.2), Vector3.UP)
			check("looking at the sky, nothing to hook", not p.gadgets.fire() and p.gadgets.cooldown_left("grapple") == 0.0)
			_block(p.global_position + Vector3(0, 2.0, -10.0), Vector3(4, 4, 4))
			until = TK.wait_ticks(3)
		1:
			cam.look_at(p.global_position + Vector3(0, 3.8, -8.1), Vector3.UP)
			check("looking at the block's top edge, the hook flies", p.gadgets.fire() and p.current_state_name() == "Gadget")
			check("...and its cooldown starts", p.gadgets.cooldown_left("grapple") > 0.0)
			until = TK.wait_ticks(6)
		2:
			check("a line runs out to it", root.find_child("GadgetRope", true, false) != null)
			until = TK.wait_secs(2.5)
		3:
			print("   up %.2f m, at z %.2f, %s" % [p.global_position.y - y0, p.global_position.z, p.current_state_name()])
			check("hauled up onto the block (%.2f m up)" % (p.global_position.y - y0), p.global_position.y - y0 > 3.5)
			check("...and done with the gadget", p.current_state_name() != "Gadget")
			until = TK.wait_secs(0.5)
		4:
			check("the line's reeled in", root.find_child("GadgetRope", true, false) == null)
			return TK.done(fails)
	step += 1
	return false
