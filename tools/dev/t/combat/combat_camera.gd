extends SceneTree
## (1.31) The combat camera: weapon out with foes about, the arm draws back to fit them and the view's centre leans
## toward them, the view's direction untouched; the "Combat camera" setting off, it settles back to the stance's own.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rig
var step := 0
var until := 0
var fails := 0
var yaw0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "cutlass", "grunts": [
		{"post": Vector3(-4.0, 0, -3.0), "role": "sword", "seed": 11},
		{"post": Vector3(-5.0, 0, 1.5), "role": "sword", "seed": 23},
		{"post": Vector3(-2.5, 0, -6.0), "role": "sword", "seed": 37}]})


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
			rig = stage.camera_rig
			for g in stage.camp.grunts:
				TK.calm(g, (p.global_position - g.global_position).normalized())
			rig.rotation.y = 0.0
			yaw0 = rig.rotation.y
			until = TK.wait_secs(2.0)
		1:
			var arm: float = rig.spring_arm.spring_length
			var lean: Vector3 = rig.global_position - (p.global_position + Vector3(0, 1.2, 0))
			print("  arm %.2f (stance %.2f), centre leaned %.2f m toward x %.2f" % [arm, rig.combat_zoom, lean.length(), lean.x])
			check("foes about: the arm draws back to fit them", arm > rig.combat_zoom + 0.8)
			check("...the centre leans toward them (they're to the left)", lean.x < -0.4)
			check("...the view's direction untouched", absf(rig.rotation.y - yaw0) < 0.01)
			root.get_node("Settings").set_value("gameplay", "combat_camera", false, false)
			until = TK.wait_secs(2.0)
		2:
			var arm2: float = rig.spring_arm.spring_length
			check("the setting off: back to the stance's own (%.2f)" % arm2, absf(arm2 - rig.combat_zoom) < 0.3)
			root.get_node("Settings").set_value("gameplay", "combat_camera", true, false)
			return TK.done(fails)
	step += 1
	return false
