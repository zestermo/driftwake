extends SceneTree
## (1.31) Attack assist: a light attack with a foe 40 degrees off the camera's line turns onto it and steps in
## to reach it; with nobody in the cone it goes straight where the camera looks.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var d0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": Vector3(2.6, 0, -3.1)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _yaw_to(at: Vector3) -> float:
	var d: Vector3 = at - p.global_position
	return atan2(-d.x, -d.z)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		1:
			d0 = p.global_position.distance_to(stage.dummy.global_position)
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		2:
			var off: float = absf(wrapf(p.player_model.rotation.y - _yaw_to(stage.dummy.global_position), -PI, PI))
			print("  yaw off the dummy ", snappedf(off, 0.01), " rad")
			check("the attack turns onto the foe off to the side", off < 0.2)
			until = TK.wait_secs(0.4)
		3:
			var d: float = p.global_position.distance_to(stage.dummy.global_position)
			print("  distance ", snappedf(d0, 0.01), " -> ", snappedf(d, 0.01))
			check("the attack steps in toward it", d < d0 - 0.8)
			# nobody ahead: the dummy far behind
			stage.dummy.global_position = p.global_position + Vector3(0, 0, 12)
			until = TK.wait_secs(1.0)
		4:
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		5:
			var cam_yaw: float = stage.camera_rig.rotation.y
			var off: float = absf(wrapf(p.player_model.rotation.y - cam_yaw, -PI, PI))
			check("with nobody in the cone it goes where the camera looks", off < 0.1)
			return TK.done(fails)
	step += 1
	return false
