extends SceneTree
## A crewmate reading their map (their body holding map_hold, as it comes over the wire) has the sheet
## open between their hands on our screen, with the sketch on it, not our page; it goes when they stop.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var mate
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "crew": [{"name": "Rook", "at": Vector3(0, 0, -3)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _sheet():
	return mate.body_model.get_node_or_null("MapSheet")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			mate = stage.crew[0]
			mate.body_model.hold("map_hold")
			until = TK.wait_secs(0.4)
		1:
			var sh = _sheet()
			check("the crewmate's sheet is in their hands", sh != null and sh.visible)
			var hold = stage.player.get_node("MapHold")
			var m: ShaderMaterial = sh.get_node("Sheet").material_override if sh else null
			check("...with the sketch on it, not our page", m != null and m.get_shader_parameter("page") != hold._vp.get_texture())
			check("...open", m != null and float(m.get_shader_parameter("open")) > 0.6)
			var mid: Vector3 = (mate.body_model.hand_l.global_position + mate.body_model.hand_r.global_position) * 0.5
			check("...between the hands", sh != null and (sh.get_node("Sheet").global_position - mid).length() < 0.25)
			mate.body_model.stop_action()
			until = TK.wait_ticks(3)
		2:
			check("it goes when they put it away", _sheet() == null or not _sheet().visible)
			return TK.done(fails)
	step += 1
	return false
