extends SceneTree
## The held map: M unrolls it at the chest (quick: held open well under a second), the camera tilts
## down onto it and the page draws only while it's out; the captain walks slowly with it; M again rolls
## it up fast; a hit knocks it away at once.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hold
var rig
var step := 0
var until := 0
var fails := 0
var _z := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _sheet():
	return p.body_model.get_node_or_null("MapSheet")


func _shown() -> bool:
	return _sheet() != null and _sheet().visible


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			hold = p.get_node("MapHold")
			rig = stage.camera_rig
			check("(the page sleeps while the map's away)", hold._vp.render_target_update_mode == SubViewport.UPDATE_DISABLED)
			TK.act("sea_chart")
			until = TK.wait_ticks(2)
		1:
			check("M: the captain takes the map out", p.current_state_name() == "Map" and p.body_model.current_action() == "map_open")
			check("...the sheet's in their hands", _shown())
			until = TK.wait_secs(0.5)
		2:
			check("held open in under a second", p.body_model.current_action() == "map_hold")
			var sh = _sheet()
			check("...the sheet open between the hands", sh != null and float(sh.get_node("Sheet").material_override.get_shader_parameter("open")) > 0.8)
			check("...the camera down on it", rig.map_blend() > 0.99 and rig.spring_arm.spring_length < 1.5)
			check("...the page drawing", hold._vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
			var to_sheet: Vector3 = sh.global_position - rig.camera.global_position
			check("...in front of the camera, looking down", (-rig.camera.global_basis.z).dot(to_sheet.normalized()) > 0.9 and to_sheet.y < -0.2)
			_z = p.global_position.z
			Input.action_press("move_forward")
			until = TK.wait_secs(1.0)
		3:
			var walked := absf(p.global_position.z - _z)
			check("walking with it out is slow (%.2f m in 1 s)" % walked, walked > 1.2 and walked < 3.0 and p.current_state_name() == "Map")
			Input.action_release("move_forward")
			TK.act("sea_chart")
			until = TK.wait_secs(0.3)
		4:
			check("M again puts it away quickly", p.current_state_name() in ["Idle", "Move"] and not _shown())
			check("...the camera's back", rig.map_blend() < 0.01)
			check("...the page sleeps", hold._vp.render_target_update_mode == SubViewport.UPDATE_DISABLED)
			TK.act("sea_chart")
			until = TK.wait_secs(0.5)
		5:
			check("(out again)", p.current_state_name() == "Map")
			var hd := HitData.new()
			hd.damage = 1.0
			p.hurtbox.hit_received.emit(hd, null)
			until = TK.wait_ticks(2)
		6:
			check("a hit knocks it away", p.current_state_name() != "Map" and not _shown() and not hold.is_up())
			return TK.done(fails)
	step += 1
	return false
