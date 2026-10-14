extends SceneTree
## Armed, the dodge is a dash that sidesteps along the stick (~3 m camera-right, still facing ahead); with no input
## it backsteps; it kicks up dust.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var start := Vector3.ZERO
var yaw0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cam_axes() -> Array:
	var yaw: float = stage.camera_rig.global_rotation.y
	return [Vector3(-sin(yaw), 0, -cos(yaw)), Vector3(cos(yaw), 0, -sin(yaw))]


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			until = TK.wait_secs(0.3)
		1:
			start = p.global_position
			yaw0 = p.player_model.rotation.y
			TK.press("move_right")
			TK.act("dodge")
			until = TK.wait_ticks(8)
		2:
			if p.body_model.current_action() == "":
				return false
			check("dash action plays (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dash")
			var parts := 0
			for c in stage.get_children():
				if c is CPUParticles3D:
					parts += 1
			check("dodge spawns dust particles", parts > 0)
		3:
			if p.current_state_name() == "Dodge":
				return false
			TK.release("move_right")
			var ax := cam_axes()
			var moved: Vector3 = p.global_position - start
			var turned := absf(wrapf(p.player_model.rotation.y - yaw0, -PI, PI))
			print("   moved right %.2f m, forward %.2f m, turned %.1f deg" % [moved.dot(ax[1]), moved.dot(ax[0]), rad_to_deg(turned)])
			check("armed sidestep goes camera-right ~3 m", moved.dot(ax[1]) > 2.4 and absf(moved.dot(ax[0])) < 0.8)
			check("body keeps facing (no turn)", turned < 0.2)
			TK.act("ready_weapon")
			until = TK.wait_secs(0.8)
		4:
			start = p.global_position
			TK.act("dodge")
			until = TK.wait_secs(0.6)
		5:
			var moved: Vector3 = p.global_position - start
			print("   backstep %.2f m" % moved.dot(p.player_model.global_basis.z))
			check("no input = backstep", moved.dot(p.player_model.global_basis.z) > 2.0)
			return TK.done(fails)
	step += 1
	return false
