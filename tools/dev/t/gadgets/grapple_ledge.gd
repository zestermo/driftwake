extends SceneTree
## (1.30) Marked ledges (GrapplePoints.add_ledge, a ring bolted on): the Mk I hook (14 m on its own) bites one atop a
## 9 m tower 20 m off when the aim is near it (not dead on), and hauls the captain up onto the tower; looking well away
## from it, it isn't picked.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var cam
var y0 := 0.0
var top := Vector3.ZERO
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
	var GS = load("res://scripts/player_states/gadget_state.gd")
	match step:
		0:
			p = stage.player
			cam = root.get_viewport().get_camera_3d()
			y0 = p.global_position.y
			var b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(5, 9, 5)
			cs.shape = bs
			cs.position = Vector3(0, 4.5, 0)
			b.add_child(cs)
			stage.add_child(b)
			b.global_position = p.global_position + Vector3(0, 0, -22.5)
			GrapplePoints.add_ledge(b, Vector3(0, 9.0, 2.3))
			top = b.to_global(Vector3(0, 9.0, 2.3))
			p.gadgets.give("grapple", 0)
			until = TK.wait_ticks(3)
		1:
			check("a ring marks the ledge", root.find_child("HookRing", true, false) != null)
			cam.look_at(cam.global_position + Vector3(1, 0.1, 0), Vector3.UP)
			check("looking away, no ledge", GS.hook_point(p, 14.0) == Vector3.INF)
			cam.look_at(top + Vector3(1.5, 1.0, 0), Vector3.UP)
			var at: Vector3 = GS.hook_point(p, 14.0)
			check("aimed near it, the ledge 20 m off is picked (%s)" % str(at), at.distance_to(top) < 0.01)
			check("the hook flies", p.gadgets.fire() and p.current_state_name() == "Gadget")
			until = TK.wait_secs(3.5)
		2:
			print("   up %.2f m, %s" % [p.global_position.y - y0, p.current_state_name()])
			check("hauled up onto the tower (%.2f m up)" % (p.global_position.y - y0), p.global_position.y - y0 > 8.5)
			return TK.done(fails)
	step += 1
	return false
