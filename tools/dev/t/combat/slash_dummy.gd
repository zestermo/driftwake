extends SceneTree
## Armed, a left click slashes and the training dummy takes the hit.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hc
var hp0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": true, "weapon": "cutlass"})


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
			hc = stage.dummy.get_node("HealthComponent")
			hp0 = hc.current_health
			p.global_position = stage.dummy.global_position + Vector3(1.4, 0.05, 0)
			p.reset_physics_interpolation()
			stage.camera_rig.rotation.y = PI * 0.5
			until = TK.wait_secs(0.6)
		1:
			TK.act("light_attack")
			until = TK.wait_secs(0.15)
		2:
			check("left click attacks when armed", p.current_state_name() == "LightAttack")
			check("slash animation playing", p.body_model.current_action().begins_with("slash"))
			until = TK.wait_secs(0.6)
		3:
			# (the cutlass's cut and recovery run past 0.6 s)
			if not p.is_free() or p.body_model.current_action() != "":
				return false
			print("   dummy hp ", hp0, " -> ", hc.current_health)
			check("dummy took damage", hc.current_health < hp0)
			return TK.done(fails)
	step += 1
	return false
