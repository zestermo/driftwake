extends SceneTree
## The head looks along the camera's aim while the camera is behind; swing the camera round in front and the face
## turns to it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
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
			until = TK.wait_secs(0.6)
		1:
			check("head looks along the camera aim when behind", p.body_model.look_weight > 0.9 and not p._looking_at_cam)
			stage.camera_rig.global_rotation.y = p.player_model.global_rotation.y + PI
			until = TK.wait_secs(0.4)
		2:
			check("camera in front -> face tracks the camera", p._looking_at_cam)
			var b = p.body_model
			var to_cam: Vector3 = root.get_viewport().get_camera_3d().global_position - b.head.global_position
			var face: Vector3 = -b.head.global_basis.z
			to_cam.y = 0
			face.y = 0
			check("face turned toward the camera (%.0f deg off)" % rad_to_deg(face.angle_to(to_cam)), face.angle_to(to_cam) < deg_to_rad(40))
			return TK.done(fails)
	step += 1
	return false
