extends SceneTree
## Acrobatics' dodge style (a variant at 7): Roll turns you into a tumbling roll the way you go (~4.6 m, untouchable
## longer); switched to Sidestep, the dodge is a short slip aside (~2.1 m) that keeps you facing and costs 30% less.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var start := Vector3.ZERO
var yaw0 := 0.0
var stam0 := 0.0
var touchable_mid := true
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
			pr = p.progression
			check("the dodge style node has Roll and Sidestep", SkillTrees.node_def("ac_dodge")["versions"].size() == 2)
			pr.owned["ac_dodge"] = true
			pr._own("ac_roll")
			until = TK.wait_secs(0.3)
		1:
			start = p.global_position
			TK.press("move_right")
			TK.act("dodge")
			until = TK.wait_ticks(6)
		2:
			check("Roll plays the roll (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dodge_roll")
			until = TK.wait_secs(0.2)
		3:
			touchable_mid = p.hurtbox.monitorable
			check("untouchable through the tuck", not touchable_mid)
			var ax := cam_axes()
			var fwd: Vector3 = -p.player_model.global_basis.z
			check("turned into the roll (facing camera-right: %.2f)" % fwd.dot(ax[1]), fwd.dot(ax[1]) > 0.9)
		4:
			if p.current_state_name() == "Dodge":
				return false
			TK.release("move_right")
			var ax := cam_axes()
			var moved: Vector3 = p.global_position - start
			print("   rolled right %.2f m" % moved.dot(ax[1]))
			check("the roll carries you ~4.6 m", moved.dot(ax[1]) > 3.9 and moved.dot(ax[1]) < 5.4)
			pr._switch("ac_dodge", 1)
			check("switched to Sidestep", pr.has_flag("dodge_sidestep") and not pr.has_flag("dodge_roll"))
			until = TK.wait_secs(0.8)
		5:
			face_ahead()
			start = p.global_position
			yaw0 = p.player_model.rotation.y
			stam0 = p.stamina
			TK.press("move_right")
			TK.act("dodge")
			until = TK.wait_ticks(4)
		6:
			check("Sidestep plays the slip (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sidestep")
			check("it costs 30%% less (%.1f)" % (stam0 - p.stamina), absf((stam0 - p.stamina) - p.DODGE_COST * 0.7) < 0.6)
		7:
			if p.current_state_name() == "Dodge":
				return false
			TK.release("move_right")
			var ax := cam_axes()
			var moved: Vector3 = p.global_position - start
			var turned := absf(wrapf(p.player_model.rotation.y - yaw0, -PI, PI))
			print("   slipped right %.2f m, turned %.1f deg" % [moved.dot(ax[1]), rad_to_deg(turned)])
			check("the sidestep is short (~2.1 m)", moved.dot(ax[1]) > 1.6 and moved.dot(ax[1]) < 2.7)
			check("still facing ahead", turned < 0.25)
			return TK.done(fails)
	step += 1
	return false


func face_ahead() -> void:
	p.player_model.rotation.y = stage.camera_rig.global_rotation.y
