extends SceneTree
## (1.31) Omni attacks: with a direction held, a light attack swings that way (camera-relative) and snaps onto the
## foe there, the camera unmoved; the crosshair stays hidden in melee.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": Vector3(-3.2, 0, 0.3), "weapon": "cutlass"})


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
			stage.camera_rig.rotation.y = 0.0
			p.player_model.rotation.y = 0.0
			until = TK.wait_ticks(4)
		1:
			TK.press("move_left")
			until = TK.wait_ticks(2)
		2:
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		3:
			TK.release("move_left")
			var d: Vector3 = stage.dummy.global_position - p.global_position
			var want := atan2(-d.x, -d.z)
			var off: float = absf(wrapf(p.player_model.rotation.y - want, -PI, PI))
			print("  off the dummy ", snappedf(off, 0.01), " rad, camera yaw ", snappedf(stage.camera_rig.rotation.y, 0.01))
			check("pushing left swings at the foe on the left", off < 0.25)
			check("the camera didn't turn", absf(stage.camera_rig.rotation.y) < 0.05)
			var hud = get_first_node_in_group("hud")
			check("no crosshair in melee", hud == null or not hud._reticle.visible)
			return TK.done(fails)
	step += 1
	return false
