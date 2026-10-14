extends SceneTree
## Holding L raises the log pose on the wrist: the ball up in front of the chest, below the chin, its face to the eyes.
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
			p.give_log_pose()
			Input.action_press("log_pose")
			until = TK.wait_secs(0.6)
		1:
			var b = p.body_model
			var lp: Node3D = b.fore_l.get_node("LogPose")
			var ball: Vector3 = lp.get_node("Ball").global_position
			var face: Vector3 = (-lp.global_basis.orthonormalized().z).normalized()
			var to_eyes: Vector3 = (b.head.global_position - ball).normalized()
			var front: float = (ball - b.torso.global_position).dot(-b.global_basis.orthonormalized().z)
			var below: float = b.head.global_position.y - ball.y
			print("   log pose: ball %.2f m below the head, %.2f m out in front, facing the eyes %.2f" % [below, front, face.dot(to_eyes)])
			check("holding L raises the wrist (%s)" % b.current_action(), b.current_action() == "log_pose")
			check("...the ball up in front of the chest, below the chin", front > 0.15 and below > 0.05 and below < 0.5)
			check("...its face turned to the eyes", face.dot(to_eyes) > 0.4)
			Input.action_release("log_pose")
			return TK.done(fails)
	step += 1
	return false
