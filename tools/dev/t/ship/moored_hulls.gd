extends SceneTree
## A moored hull rides the swell with a captain within MooredHull.NEAR and holds still (no physics moves) past FAR;
## (moored_hull.gd loaded by path: it reads Ocean, which a SceneTree script can't name at compile time)
## it rides again once a captain comes back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var near
var far
var step := 0
var until := 0
var fails := 0
var xf_near: Transform3D
var xf_far: Transform3D


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func hull(at: Vector3) -> Node3D:
	var h = load("res://scripts/ship/moored_hull.gd").new()
	h.collision_layer = 1
	h.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(4.0, 1.0, 10.0)
	cs.shape = bx
	h.add_child(cs)
	h.position = at
	stage.add_child(h)
	return h


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			near = hull(Vector3(60.0, 1.0, 0.0))
			far = hull(Vector3(400.0, 1.0, 0.0))
			until = TK.wait_ticks(near.CHECK_TICKS + 2)
		1:
			xf_near = near.global_transform
			xf_far = far.global_transform
			until = TK.wait_ticks(40)
		2:
			check("a hull 60 m from the captain rides the swell", near.riding and not near.global_transform.is_equal_approx(xf_near))
			check("a hull 400 m away holds still", not far.riding and far.global_transform.is_equal_approx(xf_far))
			p.global_position = Vector3(380.0, 4.0, 0.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(far.CHECK_TICKS + 2)
		3:
			xf_far = far.global_transform
			until = TK.wait_ticks(40)
		4:
			check("the far hull rides again once a captain comes near", far.riding and not far.global_transform.is_equal_approx(xf_far))
			check("...and the one left behind holds still", not near.riding)
			return TK.done(fails)
	step += 1
	return false
